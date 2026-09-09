from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    PROJECT_NAME: str = "Crop Health Intelligence System"
    API_V1_STR: str = "/api/v1"
    ENVIRONMENT: str = "development"
    
    DATABASE_URL: str = "postgresql://postgres:postgres@localhost:5432/cropdect_db"
    REDIS_URL: str = "redis://localhost:6379/0"

    SECRET_KEY: str = "09d25e094faa6ca2556c818166b7a9563b93f7099f6f0f4caa6cf63b88e8d3e7"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 10080  # 7 days
    BACKEND_CORS_ORIGINS: list[str] = ["*"]
    GEMINI_API_KEY: str | None = None
    ADMIN_SECRET_KEY: str = "cropdect-admin-2026"  # Override in .env for production
    CLOUDINARY_CLOUD_NAME: str | None = None
    CLOUDINARY_API_KEY: str | None = None
    CLOUDINARY_API_SECRET: str | None = None

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", case_sensitive=True, extra="ignore")

settings = Settings()
