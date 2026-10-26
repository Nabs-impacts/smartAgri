import hashlib
import os
import sys
import time
from io import BytesIO
from urllib.parse import urlsplit, urlunsplit

import httpx
from PIL import Image

from app.core.config import settings

API_URL = os.environ.get("API_URL", "http://localhost:8000").rstrip("/")
API_PREFIX = "/api/v1"
FARMER_PHONE = os.environ.get("DEMO_PHONE", "+22790000001")
ADMIN_PHONE = os.environ.get("ADMIN_PHONE", "+22790000100")
POLL_INTERVAL_SECONDS = 2.0
POLL_TIMEOUT_SECONDS = 60.0


class DemoError(RuntimeError):
    pass


def _required_env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise DemoError(
            f"La variable d'environnement {name} est obligatoire."
        )
    return value


def _request(
    client: httpx.Client,
    method: str,
    path: str,
    expected: int | tuple[int, ...],
    token: str | None = None,
    **kwargs: object,
) -> object:
    headers = dict(kwargs.pop("headers", {}) or {})
    if token is not None:
        headers["Authorization"] = f"Bearer {token}"
    expected_codes = (expected,) if isinstance(expected, int) else expected
    try:
        response = client.request(
            method,
            f"{API_URL}{API_PREFIX}{path}",
            headers=headers,
            **kwargs,
        )
    except httpx.HTTPError as error:
        raise DemoError(
            f"{method} {path} n'a pas pu joindre l'API : {error}."
        ) from error
    if response.status_code not in expected_codes:
        raise DemoError(
            f"{method} {path} a renvoyé {response.status_code} "
            f"au lieu de {expected_codes}."
        )
    if not response.content:
        return None
    try:
        return response.json()
    except ValueError as error:
        raise DemoError(f"{method} {path} n'a pas renvoyé du JSON.") from error


def _login(client: httpx.Client, phone: str, password: str) -> str:
    data = _request(
        client,
        "POST",
        "/auth/login",
        expected=200,
        json={"phone": phone, "password": password},
    )
    if not isinstance(data, dict) or not data.get("access_token"):
        raise DemoError("La connexion n'a pas renvoyé de jeton d'accès.")
    return str(data["access_token"])


def _build_jpeg() -> bytes:
    buffer = BytesIO()
    Image.new("RGB", (16, 16), (34, 139, 34)).save(
        buffer, format="JPEG", quality=80
    )
    data = buffer.getvalue()
    if not data.startswith(b"\xff\xd8\xff"):
        raise DemoError("L'image générée n'est pas un JPEG valide.")
    return data


def _internal_storage_url(url: str) -> tuple[str, dict[str, str]]:
    public = urlsplit(url)
    internal = urlsplit(settings.S3_ENDPOINT_URL)
    if public.netloc == internal.netloc:
        return url, {}
    rewritten = urlunsplit(
        (
            internal.scheme,
            internal.netloc,
            public.path,
            public.query,
            public.fragment,
        )
    )
    return rewritten, {"Host": public.netloc}


def _upload_image(
    client: httpx.Client, token: str, image: bytes
) -> str:
    sha256 = hashlib.sha256(image).hexdigest()
    data = _request(
        client,
        "POST",
        "/media/uploads",
        expected=(200, 201),
        token=token,
        json={
            "kind": "image",
            "mime_type": "image/jpeg",
            "size_bytes": len(image),
            "sha256": sha256,
            "width": 16,
            "height": 16,
        },
    )
    if not isinstance(data, dict):
        raise DemoError("La création du média n'a pas renvoyé d'objet.")
    media = data.get("media")
    upload = data.get("upload")
    if not isinstance(media, dict) or not media.get("id"):
        raise DemoError("La création du média n'a pas renvoyé d'identifiant.")
    if not isinstance(upload, dict) or not upload.get("url"):
        if data.get("already_uploaded"):
            return str(media["id"])
        raise DemoError("Les instructions d'envoi du média sont incomplètes.")
    if upload.get("method") != "PUT":
        raise DemoError("La méthode d'envoi du média n'est pas PUT.")
    headers = dict(upload.get("headers") or {})
    url, extra_headers = _internal_storage_url(str(upload["url"]))
    headers.update(extra_headers)
    if url != upload["url"]:
        print(
            "    URL présignée réécrite vers l'adresse interne de RustFS "
            "pour l'envoi depuis le conteneur."
        )
    try:
        storage = httpx.put(url, content=image, headers=headers, timeout=60.0)
    except httpx.HTTPError as error:
        raise DemoError(
            f"L'envoi vers le stockage a échoué : {error}."
        ) from error
    if storage.status_code not in (200, 204):
        raise DemoError(
            "L'envoi vers le stockage a renvoyé le statut "
            f"{storage.status_code}."
        )
    _request(
        client,
        "POST",
        f"/media/{media['id']}/complete",
        expected=200,
        token=token,
        json={},
    )
    return str(media["id"])


def _pick_crop(client: httpx.Client, token: str) -> int:
    crops = _request(client, "GET", "/crops", expected=200, token=token)
    if not isinstance(crops, list) or not crops:
        raise DemoError("Aucune culture n'est disponible dans le catalogue.")
    for code in ("sorghum", "millet"):
        for crop in crops:
            if isinstance(crop, dict) and crop.get("code") == code:
                return int(crop["id"])
    return int(crops[0]["id"])


def _create_and_wait(
    client: httpx.Client, token: str, media_id: str, crop_id: int
) -> dict[str, object]:
    created = _request(
        client,
        "POST",
        "/diagnostics",
        expected=202,
        token=token,
        json={"media_ids": [media_id], "crop_id": crop_id},
    )
    if not isinstance(created, dict) or not created.get("id"):
        raise DemoError("La création du diagnostic n'a pas renvoyé d'identifiant.")
    diagnostic_id = str(created["id"])
    deadline = time.monotonic() + POLL_TIMEOUT_SECONDS
    last_status = "inconnu"
    while True:
        diagnostic = _request(
            client,
            "GET",
            f"/diagnostics/{diagnostic_id}",
            expected=200,
            token=token,
        )
        if not isinstance(diagnostic, dict):
            raise DemoError("La lecture du diagnostic n'a pas renvoyé d'objet.")
        last_status = str(diagnostic.get("status"))
        if last_status in ("done", "needs_review"):
            return diagnostic
        if last_status == "failed":
            raise DemoError(
                "Le worker a marqué le diagnostic comme échoué."
            )
        if time.monotonic() >= deadline:
            raise DemoError(
                "Le diagnostic est resté au statut "
                f"{last_status} après {int(POLL_TIMEOUT_SECONDS)} secondes."
            )
        time.sleep(POLL_INTERVAL_SECONDS)


def _print_diagnostic(diagnostic: dict[str, object]) -> None:
    predictions = diagnostic.get("predictions") or []
    top = predictions[0] if isinstance(predictions, list) and predictions else None
    label = None
    confidence = None
    if isinstance(top, dict):
        label_data = top.get("label")
        if isinstance(label_data, dict):
            label = label_data.get("name") or label_data.get("code")
        confidence = top.get("confidence")
    recommendation = diagnostic.get("recommendation")
    title = None
    if isinstance(recommendation, dict):
        title = recommendation.get("title")
    print(f"    Statut : {diagnostic.get('status')}")
    print(f"    Label principal : {label or 'aucun'}")
    print(f"    Confiance : {confidence if confidence is not None else 'aucune'}")
    print(f"    Recommandation : {title or 'aucune'}")


def _print_stats(yields: object, overview: object) -> None:
    items = yields.get("items", []) if isinstance(yields, dict) else []
    visible = [
        item
        for item in items
        if isinstance(item, dict) and not item.get("masked")
    ]
    masked = [
        item
        for item in items
        if isinstance(item, dict) and item.get("masked")
    ]
    print(f"    Cellules visibles : {len(visible)}")
    print(f"    Cellules masquées : {len(masked)}")
    if isinstance(overview, dict):
        print(
            "    Utilisateurs actifs (30 jours) : "
            f"{overview.get('active_users_30d')}"
        )
        print(f"    Surface suivie : {overview.get('tracked_area_ha')} ha")
        print(
            "    Diagnostics (30 jours) : "
            f"{overview.get('diagnostics_30d')}"
        )


def _expect_forbidden(
    client: httpx.Client, token: str, path: str
) -> None:
    response = client.get(
        f"{API_URL}{API_PREFIX}{path}",
        headers={"Authorization": f"Bearer {token}"},
    )
    if response.status_code != 403:
        raise DemoError(
            f"{path} devrait renvoyer 403 pour l'agriculteur, "
            f"reçu {response.status_code}."
        )


def _run() -> None:
    demo_password = _required_env("DEMO_PASSWORD")
    admin_password = _required_env("ADMIN_PASSWORD")

    with httpx.Client(timeout=30.0) as client:
        print("1/5 Connexion de l'agriculteur de démonstration")
        farmer_token = _login(client, FARMER_PHONE, demo_password)
        profile = _request(
            client, "GET", "/users/me", expected=200, token=farmer_token
        )
        user = profile.get("user", {}) if isinstance(profile, dict) else {}
        print(
            f"    Connecté : {user.get('full_name', 'inconnu')} "
            f"({user.get('role', 'inconnu')})"
        )

        print("2/5 Envoi d'une image JPEG de test")
        image = _build_jpeg()
        print(f"    Image de {len(image)} octets")
        media_id = _upload_image(client, farmer_token, image)
        print(f"    Média envoyé et complété : {media_id}")

        print("3/5 Diagnostic et attente du worker")
        crop_id = _pick_crop(client, farmer_token)
        diagnostic = _create_and_wait(
            client, farmer_token, media_id, crop_id
        )
        _print_diagnostic(diagnostic)

        print("4/5 Statistiques du compte super administrateur")
        admin_token = _login(client, ADMIN_PHONE, admin_password)
        admin_profile = _request(
            client, "GET", "/users/me", expected=200, token=admin_token
        )
        admin_user = (
            admin_profile.get("user", {})
            if isinstance(admin_profile, dict)
            else {}
        )
        admin_role = (
            admin_user.get("role") if isinstance(admin_user, dict) else None
        )
        if admin_role != "super_admin":
            raise DemoError(
                "Le compte administrateur de démonstration doit avoir "
                f"le rôle super_admin, reçu {admin_role}."
            )
        yields = _request(
            client,
            "GET",
            "/admin/stats/yields",
            expected=200,
            token=admin_token,
        )
        overview = _request(
            client,
            "GET",
            "/admin/stats/overview",
            expected=200,
            token=admin_token,
        )
        _print_stats(yields, overview)

        print("5/5 Contrôle des droits de l'agriculteur")
        _expect_forbidden(client, farmer_token, "/admin/stats/yields")
        _expect_forbidden(client, farmer_token, "/admin/stats/overview")
        print("    Accès refusé (403) confirmé sur les deux routes de stats.")


def main() -> int:
    try:
        _run()
    except DemoError as error:
        print(f"Échec : {error}", file=sys.stderr)
        return 1
    except Exception as error:
        print(f"Échec inattendu : {error}", file=sys.stderr)
        return 1
    print("Démo de bout en bout réussie.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
