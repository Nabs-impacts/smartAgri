from typing import Any

from app.db.models.media_ai import DiagnosisLabel

_CATEGORIES = ("cultural", "biological", "chemical", "prevention")
_TECHNICIAN_STEP = (
    "Consultez un technicien agricole avant tout traitement."
)
_GENERIC_MONITORING_STEP = (
    "Surveillez régulièrement la parcelle et notez l'évolution des symptômes."
)


def _localized_name(label: DiagnosisLabel, user_language: str) -> str:
    if user_language == "ha" and label.name_ha:
        return label.name_ha
    if user_language == "dje" and label.name_dje:
        return label.name_dje
    return label.name_fr


def _step_texts(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    texts: list[str] = []
    for item in value:
        if isinstance(item, str):
            texts.append(item)
        elif isinstance(item, dict):
            text = item.get("text")
            if isinstance(text, str) and text:
                texts.append(text)
    return texts


def _steps_for(guideline: dict[str, Any]) -> list[dict[str, str]]:
    steps: list[dict[str, str]] = []
    for category in _CATEGORIES:
        for text in _step_texts(guideline.get(category)):
            steps.append({"category": category, "text": text})
    return steps


def build_recommendation(
    label: DiagnosisLabel,
    user_language: str,
) -> dict[str, Any]:
    name = _localized_name(label, user_language)
    if label.kind == "healthy":
        return {
            "title": "Culture en bonne santé",
            "body": (
                f"Votre {name.lower()} ne montre aucun signe de maladie ou de "
                "ravageur. Continuez à surveiller la parcelle et à appliquer "
                "les bonnes pratiques agricoles."
            ),
            "steps": [],
            "citations": None,
        }

    guideline = label.guideline if isinstance(label.guideline, dict) else {}
    validated = guideline.get("validated") is True

    if validated:
        steps = _steps_for(guideline)
        body = (
            label.description
            or f"Suivez les étapes recommandées pour traiter {name.lower()}."
        )
    else:
        steps = [
            step
            for step in _steps_for(guideline)
            if step["category"] in ("cultural", "prevention")
        ]
        if not steps:
            steps.append(
                {
                    "category": "prevention",
                    "text": _GENERIC_MONITORING_STEP,
                }
            )
        steps.append(
            {
                "category": "prevention",
                "text": _TECHNICIAN_STEP,
            }
        )
        body = (
            f"Aucun traitement chimique n'est recommandé pour {name.lower()} "
            "sans validation par un technicien."
        )

    return {
        "title": f"Recommandation pour {name}",
        "body": body,
        "steps": steps,
        "citations": None,
    }
