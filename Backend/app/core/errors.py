from typing import Any
from fastapi import FastAPI, HTTPException, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from app.core.logging import get_logger

logger = get_logger("errors")


class ErrorDetail(BaseModel):
    code: str
    message: str
    details: Any = None


class ErrorResponse(BaseModel):
    error: ErrorDetail


class AppException(Exception):
    def __init__(
        self,
        code: str,
        message: str,
        status_code: int = status.HTTP_500_INTERNAL_SERVER_ERROR,
        details: Any = None,
    ) -> None:
        self.code = code
        self.message = message
        self.status_code = status_code
        self.details = details
        super().__init__(message)


class ValidationException(AppException):
    def __init__(
        self,
        message: str = "Erreur de validation des données.",
        details: Any = None,
    ) -> None:
        super().__init__(
            code="VALIDATION_ERROR",
            message=message,
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            details=details,
        )


class UnauthorizedException(AppException):
    def __init__(
        self,
        message: str = "Authentification requise ou jeton invalide.",
        details: Any = None,
    ) -> None:
        super().__init__(
            code="UNAUTHORIZED",
            message=message,
            status_code=status.HTTP_401_UNAUTHORIZED,
            details=details,
        )


class ForbiddenException(AppException):
    def __init__(
        self,
        message: str = "Accès refusé à cette ressource.",
        details: Any = None,
    ) -> None:
        super().__init__(
            code="FORBIDDEN",
            message=message,
            status_code=status.HTTP_403_FORBIDDEN,
            details=details,
        )


class NotFoundException(AppException):
    def __init__(
        self,
        message: str = "Ressource introuvable.",
        details: Any = None,
    ) -> None:
        super().__init__(
            code="NOT_FOUND",
            message=message,
            status_code=status.HTTP_404_NOT_FOUND,
            details=details,
        )


class ConflictException(AppException):
    def __init__(
        self,
        message: str = "Conflit avec l'état actuel de la ressource.",
        details: Any = None,
    ) -> None:
        super().__init__(
            code="CONFLICT",
            message=message,
            status_code=status.HTTP_409_CONFLICT,
            details=details,
        )


class RateLimitedException(AppException):
    def __init__(
        self,
        message: str = "Trop de requêtes, veuillez réessayer plus tard.",
        details: Any = None,
    ) -> None:
        super().__init__(
            code="RATE_LIMITED",
            message=message,
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            details=details,
        )


class QuotaExceededException(AppException):
    def __init__(
        self,
        message: str = "Quota mensuel dépassé pour votre forfait.",
        details: Any = None,
    ) -> None:
        super().__init__(
            code="QUOTA_EXCEEDED",
            message=message,
            status_code=status.HTTP_403_FORBIDDEN,
            details=details,
        )


class UploadInvalidException(AppException):
    def __init__(
        self,
        message: str = "Fichier ou métadonnées de téléversement invalides.",
        details: Any = None,
    ) -> None:
        super().__init__(
            code="UPLOAD_INVALID",
            message=message,
            status_code=status.HTTP_400_BAD_REQUEST,
            details=details,
        )


class PaymentFailedException(AppException):
    def __init__(
        self,
        message: str = "Le paiement a échoué ou a été refusé.",
        details: Any = None,
    ) -> None:
        super().__init__(
            code="PAYMENT_FAILED",
            message=message,
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            details=details,
        )


class InvalidSignatureException(AppException):
    def __init__(
        self,
        message: str = "Signature de webhook ou de requête invalide.",
        details: Any = None,
    ) -> None:
        super().__init__(
            code="INVALID_SIGNATURE",
            message=message,
            status_code=status.HTTP_401_UNAUTHORIZED,
            details=details,
        )


class InternalErrorException(AppException):
    def __init__(
        self,
        message: str = "Une erreur interne inattendue est survenue.",
        details: Any = None,
    ) -> None:
        super().__init__(
            code="INTERNAL_ERROR",
            message=message,
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            details=details,
        )


async def app_exception_handler(request: Request, exc: AppException) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": {
                "code": exc.code,
                "message": exc.message,
                "details": exc.details,
            }
        },
    )


async def validation_exception_handler(
    request: Request, exc: RequestValidationError
) -> JSONResponse:
    details = exc.errors()
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "error": {
                "code": "VALIDATION_ERROR",
                "message": "Erreur de validation des données d'entrée.",
                "details": details,
            }
        },
    )


async def http_exception_handler(request: Request, exc: HTTPException) -> JSONResponse:
    code_map = {
        400: "UPLOAD_INVALID",
        401: "UNAUTHORIZED",
        403: "FORBIDDEN",
        404: "NOT_FOUND",
        409: "CONFLICT",
        429: "RATE_LIMITED",
    }
    code = code_map.get(exc.status_code, "INTERNAL_ERROR")
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": {
                "code": code,
                "message": str(exc.detail),
                "details": None,
            }
        },
    )


async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    logger.exception("unhandled_server_error", exc_info=exc)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "error": {
                "code": "INTERNAL_ERROR",
                "message": "Une erreur interne inattendue est survenue.",
                "details": None,
            }
        },
    )


def register_error_handlers(app: FastAPI) -> None:
    app.add_exception_handler(AppException, app_exception_handler)
    app.add_exception_handler(RequestValidationError, validation_exception_handler)
    app.add_exception_handler(HTTPException, http_exception_handler)
    app.add_exception_handler(Exception, unhandled_exception_handler)
