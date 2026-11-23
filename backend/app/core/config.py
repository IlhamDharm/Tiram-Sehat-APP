from __future__ import annotations

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application-wide configuration loaded from environment / .env file."""

    APP_ENV: str = "development"
    PORT: int = 8000

    # ── Database (Neon PostgreSQL) ───────────────────
    DATABASE_URL: str = ""
    DATABASE_URL_POOLED: str = ""
    NEON_DATABASE_URL: str = ""

    # ── Auth ─────────────────────────────────────────
    JWT_SECRET: str = "change-me"
    JWT_ACCESS_TTL_SECONDS: int = 900        # 15 minutes
    REFRESH_TTL_SECONDS: int = 2_592_000     # 30 days
    PIN_HASH_ROUNDS: int = 12

    # ── Cloudinary ───────────────────────────────────
    CLOUDINARY_CLOUD_NAME: str = ""
    CLOUDINARY_API_KEY: str = ""
    CLOUDINARY_API_SECRET: str = ""
    CLOUDINARY_UPLOAD_PRESET: str = "tiramsehat_uploads"
    CLOUDINARY_FOLDER: str = "tiramsehat"

    # ── Hugging Face Space (ML Inference) ────────────
    HF_SPACE_URL: str = ""
    HF_INTERNAL_SECRET: str = ""
    HF_TIMEOUT_SECONDS: int = 60
    HF_MAX_RETRIES: int = 3

    # ── Local TFLite Model ───────────────────────────
    ML_MODEL_PATH: str = ""
    ML_MODEL_VERSION: str = "mobilenetv2-end2end-v7"

    # ── CORS ─────────────────────────────────────────
    CORS_ORIGINS: str = "*"

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()
