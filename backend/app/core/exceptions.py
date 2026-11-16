"""Global exception handling and standard JSON envelope."""
from __future__ import annotations

import logging
import uuid
from typing import Any

from fastapi import FastAPI, Request
from fastapi.encoders import jsonable_encoder
from fastapi.responses import JSONResponse

logger = logging.getLogger(__name__)


# ── Custom exception ────────────────────────────────────────────────────────


class AppException(Exception):
    """Application-level error that maps to a specific HTTP status."""

    def __init__(
        self,
        status_code: int = 400,
        code: str = "VALIDATION_ERROR",
        message: str = "Bad request",
        details: list[dict[str, Any]] | None = None,
    ) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.code = code
        self.message = message
        self.details = details


# ── Envelope helpers ────────────────────────────────────────────────────────


def success_response(
    data: Any,
    meta: dict[str, Any] | None = None,
    status_code: int = 200,
) -> JSONResponse:
    """Wrap ``data`` in the standard ``{data, meta}`` envelope."""
    body: dict[str, Any] = {"data": data}
    body["meta"] = {
        "request_id": (meta or {}).get("request_id", uuid.uuid4().hex),
        **(meta or {}),
    }
    return JSONResponse(content=jsonable_encoder(body), status_code=status_code)


def error_response(
    status_code: int,
    code: str,
    message: str,
    details: list[dict[str, Any]] | None = None,
) -> JSONResponse:
    """Build an error envelope ``{error: {code, message, details}}``."""
    body: dict[str, Any] = {
        "error": {
            "code": code,
            "message": message,
        }
    }
    if details:
        body["error"]["details"] = details
    return JSONResponse(content=jsonable_encoder(body), status_code=status_code)


# ── Registration ────────────────────────────────────────────────────────────


def register_exception_handlers(app: FastAPI) -> None:
    """Attach global exception handlers to the FastAPI app."""

    @app.exception_handler(AppException)
    async def handle_app_exception(_request: Request, exc: AppException) -> JSONResponse:
        return error_response(exc.status_code, exc.code, exc.message, exc.details)

    @app.exception_handler(Exception)
    async def handle_generic_exception(_request: Request, exc: Exception) -> JSONResponse:
        logger.exception("Unhandled exception: %s", exc)
        return error_response(500, "INTERNAL_ERROR", "Internal server error")
