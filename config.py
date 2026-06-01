from typing import Optional

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "backend"
    env: str = "dev"

    database_url: str = "sqlite:///./app.db"
    jwt_secret_key: str = "dev-secret-change-me"
    access_token_expire_minutes: int = 60 * 24 * 30

    gemini_api_key: Optional[str] = None
    gemini_base_url: str = "https://generativelanguage.googleapis.com/v1beta"
    gemini_model: str = "gemini-2.5-flash"
    llm_timeout_seconds: int = 180
    openai_api_key: Optional[str] = None
    openai_base_url: str = "https://api.openai.com/v1"
    openai_text_model: str = "gpt-4.1-mini"
    openai_transcription_model: str = "gpt-4o-mini-transcribe"
    openai_transcription_fallback_models: str = "whisper-1"
    openai_transcription_language: str = ""
    openai_transcription_prompt: str = ""
    openai_transcription_timeout_seconds: int = 900
    openai_transcription_upload_limit_bytes: int = 26214400
    lecture_storage_dir: str = "storage/lectures"
    whisper_python_bin: str = ""
    whisper_ffmpeg_bin: str = "ffmpeg"
    whisper_path_prefix: str = ""
    whisper_model: str = "tiny"
    whisper_language: str = ""
    whisper_device: str = ""
    whisper_model_dir: str = ""
    whisper_timeout_ms: int = 900000
    whisper_total_timeout_ms: int = 7200000
    whisper_chunk_seconds: int = 600
    max_audio_bytes: int = 314572800


settings = Settings()
