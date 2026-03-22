import sys

from pydantic import model_validator
from pydantic_settings import BaseSettings

_INSECURE_DEFAULTS = {
    "super-secret-key-change-in-production",
    "changeme",
    "secret",
    "",
}


class Settings(BaseSettings):
    DATABASE_URL: str = "postgresql+asyncpg://meepo:changeme@localhost:5432/meepo"
    SECRET_KEY: str = "super-secret-key-change-in-production"
    OPENAI_API_KEY: str = ""
    CORS_ORIGINS: str = "http://localhost:3000"

    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    UPLOAD_DIR: str = "uploads"
    MAX_AVATAR_SIZE: int = 5 * 1024 * 1024  # 5 MB

    COOKIE_SECURE: bool | None = None

    SMTP_HOST: str = ""
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_FROM: str = ""

    SENTRY_DSN: str = ""

    # Google OAuth
    GOOGLE_CLIENT_ID: str = ""
    GOOGLE_CLIENT_SECRET: str = ""

    # Apple Sign In
    APPLE_CLIENT_ID: str = ""
    APPLE_TEAM_ID: str = ""
    APPLE_KEY_ID: str = ""
    APPLE_PRIVATE_KEY: str = ""

    # Meta
    META_APP_ID: str = ""
    META_APP_SECRET: str = ""
    META_WEBHOOK_VERIFY_TOKEN: str = ""
    META_API_VERSION: str = "v21.0"

    # APNs Push
    APNS_KEY_ID: str = ""
    APNS_TEAM_ID: str = ""
    APNS_AUTH_KEY_PATH: str = ""

    # Alerts
    ALERT_EMAIL: str = ""
    ALERT_SLACK_WEBHOOK: str = ""

    model_config = {"env_file": ".env"}

    @model_validator(mode="after")
    def _validate_secrets(self) -> "Settings":
        if self.SECRET_KEY in _INSECURE_DEFAULTS:
            print(
                "FATAL: SECRET_KEY is not set or uses a default value. "
                "Set a strong SECRET_KEY in .env before starting.",
                file=sys.stderr,
            )
            sys.exit(1)
        if self.COOKIE_SECURE is None:
            self.COOKIE_SECURE = any(
                o.strip().startswith("https://")
                for o in self.CORS_ORIGINS.split(",")
            )
        return self


settings = Settings()
