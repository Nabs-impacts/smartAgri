import hashlib
from typing import Any

_MAX_PREDICTIONS = 3
_BASE_CONFIDENCE = 0.40
_CONFIDENCE_RANGE = 0.55


def _digest(
    media_sha256s: list[str],
    crop_id: int | None,
) -> str:
    material = "".join(sorted(media_sha256s))
    if crop_id is not None:
        material += str(crop_id)
    return hashlib.sha256(material.encode()).hexdigest()


def _weight(digest: str, code: str) -> int:
    value = hashlib.sha256(f"{digest}:{code}".encode()).hexdigest()
    return int(value[:8], 16) + 1


def predict_stub(
    media_sha256s: list[str],
    crop_id: int | None,
    labels: list[tuple[int, str]],
) -> list[dict[str, Any]]:
    ordered = sorted(labels, key=lambda item: item[0])
    if not ordered:
        return []

    digest = _digest(media_sha256s, crop_id)
    first = round(
        _BASE_CONFIDENCE
        + (int(digest[:8], 16) / 0xFFFFFFFF) * _CONFIDENCE_RANGE,
        3,
    )
    selected = ordered[:_MAX_PREDICTIONS]
    predictions: list[dict[str, Any]] = [
        {"label_id": selected[0][0], "confidence": first}
    ]
    if len(selected) == 1:
        predictions[0]["rank"] = 1
        return predictions

    remaining = round(1.0 - first, 3)
    followers = selected[1:]
    weights = [_weight(digest, code) for _, code in followers]
    total_weight = sum(weights)
    allocated = 0.0
    for index, (label_id, _) in enumerate(followers):
        if index == len(followers) - 1:
            confidence = round(remaining - allocated, 3)
        else:
            confidence = round(remaining * weights[index] / total_weight, 3)
            allocated += confidence
        predictions.append({"label_id": label_id, "confidence": confidence})

    predictions.sort(key=lambda item: (-item["confidence"], item["label_id"]))
    if sum(item["confidence"] for item in predictions) > 1:
        predictions[-1]["confidence"] = round(
            predictions[-1]["confidence"] - 0.001,
            3,
        )
    for rank, prediction in enumerate(predictions, start=1):
        prediction["rank"] = rank
    return predictions
