from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    DATABASE_URL: str = "postgresql+asyncpg://meepo:changeme@localhost:5432/meepo"
    OPENAI_API_KEY: str = ""
    OPENAI_BASE_URL: str = ""
    CF_AIG_TOKEN: str = ""
    SECRET_KEY: str = "super-secret-key-change-in-production"

    META_APP_ID: str = ""
    META_APP_SECRET: str = ""
    META_API_VERSION: str = "v21.0"

    ALERT_EMAIL: str = ""
    ALERT_SLACK_WEBHOOK: str = ""
    SENTRY_DSN: str = ""

    model_config = {"env_file": ".env"}


settings = Settings()
