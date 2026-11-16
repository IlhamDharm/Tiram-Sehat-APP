"""FastAPI application factory for TiramSehat backend."""
from __future__ import annotations

import asyncio
import logging
import sys
from contextlib import asynccontextmanager

if sys.platform == "win32":
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.core.database import close_pool, open_pool
from app.core.exceptions import register_exception_handlers

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup / shutdown hooks — open and close the DB pool."""
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    logger.info("Starting TiramSehat backend (env=%s)", settings.APP_ENV)
    await open_pool()
    yield
    await close_pool()
    logger.info("TiramSehat backend stopped")


def create_app() -> FastAPI:
    """Build and return a fully-configured FastAPI instance."""
    app = FastAPI(
        title="TiramSehat API",
        version="1.0.0",
        lifespan=lifespan,
    )

    # ── CORS ────────────────────────────────────────
    origins = [o.strip() for o in settings.CORS_ORIGINS.split(",")]
    # `allow_credentials=True` + wildcard origin tidak aman dan ditolak browser.
    allow_credentials = "*" not in origins
    app.add_middleware(
        CORSMiddleware,
        allow_origins=origins,
        allow_credentials=allow_credentials,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # ── Global exception handlers ───────────────────
    register_exception_handlers(app)

    # ── Module routers ──────────────────────────────
    from app.modules.auth.router import router as auth_router
    from app.modules.uploads.router import router as uploads_router
    from app.modules.scans.router import router as scans_router
    from app.modules.harvests.router import router as harvests_router
    from app.modules.baglogs.router import router as baglogs_router
    from app.modules.diseases.router import router as diseases_router  # noqa: F811
    from app.modules.home.router import router as home_router
    from app.modules.reports.router import router as reports_router

    app.include_router(auth_router, prefix="/api/v1/auth", tags=["Auth"])
    app.include_router(uploads_router, prefix="/api/v1/uploads", tags=["Uploads"])
    app.include_router(scans_router, prefix="/api/v1/scans", tags=["Scans"])
    app.include_router(harvests_router, prefix="/api/v1/harvests", tags=["Harvests"])
    app.include_router(baglogs_router, prefix="/api/v1/baglogs", tags=["Baglogs"])
    app.include_router(diseases_router, prefix="/api/v1/diseases", tags=["Diseases"])
    app.include_router(home_router, prefix="/api/v1/home", tags=["Home"])
    app.include_router(reports_router, prefix="/api/v1/reports", tags=["Reports"])

    # ── Health check ────────────────────────────────
    @app.get("/health")
    async def health():
        return {"data": {"status": "ok", "version": "1.0.0"}}

    return app


app = create_app()
