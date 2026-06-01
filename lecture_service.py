import subprocess
import tempfile
import uuid
from datetime import datetime
from pathlib import Path
from typing import Generator, Iterable, List

from fastapi import UploadFile
from openai import APIConnectionError, APIStatusError, APITimeoutError, OpenAI, RateLimitError

from config import settings
from gemini_api import generate_json


TRANSCRIPTION_NORMALIZATION_BITRATES = ("64k", "48k", "32k", "24k")
SUMMARY_LANGUAGE_CODES = ("en", "ko", "ru", "zh")
TARGET_QUIZ_COUNT = 10


class AudioTranscriptionError(Exception):
    def __init__(self, message: str, status: int = 400):
        super().__init__(message)
        self.status = status


def _storage_root() -> Path:
    return (Path(__file__).resolve().parent / settings.lecture_storage_dir).resolve()


def _audio_extension(filename: str, content_type: str) -> str:
    lower_name = filename.lower()
    mime_type = (content_type or "").split(";")[0].strip().lower()

    if lower_name.endswith(".mp3") or mime_type in {"audio/mp3", "audio/mpeg"}:
        return ".mp3"
    if lower_name.endswith(".mp4") or mime_type == "video/mp4":
        return ".mp4"
    if lower_name.endswith(".mpeg") or lower_name.endswith(".mpga"):
        return ".mpeg"
    if lower_name.endswith(".aac") or mime_type == "audio/aac":
        return ".aac"
    if lower_name.endswith(".ac3") or mime_type == "audio/ac3":
        return ".ac3"
    if lower_name.endswith(".m4a") or mime_type in {"audio/mp4", "audio/x-m4a"}:
        return ".m4a"
    if lower_name.endswith(".ogg") or lower_name.endswith(".oga") or mime_type == "audio/ogg":
        return ".ogg"
    if lower_name.endswith(".flac") or mime_type == "audio/flac":
        return ".flac"
    if lower_name.endswith(".aiff") or lower_name.endswith(".aif") or mime_type == "audio/aiff":
        return ".aiff"
    if lower_name.endswith(".webm") or mime_type == "audio/webm":
        return ".webm"
    return ".wav"


def _safe_segment(value: str) -> str:
    cleaned = "".join(char if char.isalnum() or char in {"-", "_"} else "-" for char in value)
    return cleaned.strip("-")[:96] or "unknown"


def _transcription_client() -> OpenAI:
    if not settings.openai_api_key:
        raise AudioTranscriptionError(
            "OPENAI_API_KEY is missing. Add it before using hosted lecture transcription.",
            503,
        )
    return OpenAI(
        api_key=settings.openai_api_key,
        base_url=settings.openai_base_url.rstrip("/"),
        timeout=float(settings.openai_transcription_timeout_seconds),
    )


def _transcription_request_options(model: str) -> dict:
    options = {
        "model": model,
        "response_format": "json",
    }
    if settings.openai_transcription_language:
        options["language"] = settings.openai_transcription_language
    if settings.openai_transcription_prompt:
        options["prompt"] = settings.openai_transcription_prompt
    return options


def _transcription_models() -> List[str]:
    models: List[str] = []
    primary_model = settings.openai_transcription_model.strip()
    if primary_model:
        models.append(primary_model)

    fallback_models = [
        model.strip()
        for model in settings.openai_transcription_fallback_models.split(",")
        if model.strip()
    ]
    for model in fallback_models:
        if model not in models:
            models.append(model)

    if not models:
        raise AudioTranscriptionError(
            "No hosted transcription model is configured.",
            503,
        )
    return models


def hosted_transcription_upload_limit_bytes() -> int:
    return int(settings.openai_transcription_upload_limit_bytes)


def _extract_transcript_text(payload: object) -> str:
    text = getattr(payload, "text", None)
    if isinstance(text, str):
        return text.strip()
    if isinstance(payload, dict):
        value = payload.get("text")
        if isinstance(value, str):
            return value.strip()
    return ""


def _error_message(error: Exception) -> str:
    return (getattr(error, "message", None) or str(error)).strip()


def _should_retry_with_fallback(error: Exception) -> bool:
    if not isinstance(error, APIStatusError):
        return False
    lower_message = _error_message(error).lower()
    if "corrupted" in lower_message or "unsupported" in lower_message:
        return True
    return "invalid_value" in lower_message and "file" in lower_message


def _normalize_audio_for_hosted_upload(input_path: Path, output_dir: Path) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / "transcription-input.m4a"

    last_error: AudioTranscriptionError | None = None
    for bitrate in TRANSCRIPTION_NORMALIZATION_BITRATES:
        command = [
            settings.whisper_ffmpeg_bin,
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            "-i",
            str(input_path),
            "-vn",
            "-ac",
            "1",
            "-ar",
            "16000",
            "-c:a",
            "aac",
            "-b:a",
            bitrate,
            str(output_path),
        ]
        try:
            subprocess.run(
                command,
                check=True,
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=max(60, int(settings.openai_transcription_timeout_seconds)),
            )
        except FileNotFoundError as error:
            raise AudioTranscriptionError(
                "ffmpeg is required to normalize lecture recordings before hosted transcription.",
                501,
            ) from error
        except subprocess.TimeoutExpired as error:
            raise AudioTranscriptionError(
                "Audio normalization timed out before transcription could start.",
                504,
            ) from error
        except subprocess.CalledProcessError as error:
            detail = (error.stderr or error.stdout or "").strip()
            last_error = AudioTranscriptionError(
                f"Audio normalization failed before transcription. {detail}".strip(),
                502,
            )
            continue

        if output_path.exists() and output_path.stat().st_size <= hosted_transcription_upload_limit_bytes():
            return output_path

    if last_error is not None:
        raise last_error
    raise AudioTranscriptionError(
        "The normalized recording is still above the hosted transcription upload limit. Please trim the audio or lower the recording bitrate before uploading.",
        413,
    )


def _map_transcription_error(error: Exception) -> AudioTranscriptionError:
    if isinstance(error, AudioTranscriptionError):
        return error
    if isinstance(error, APITimeoutError):
        return AudioTranscriptionError("Hosted transcription timed out.", 504)
    if isinstance(error, RateLimitError):
        return AudioTranscriptionError(
            "The transcription provider rate limit was reached. Please try again shortly.",
            503,
        )
    if isinstance(error, APIConnectionError):
        return AudioTranscriptionError(
            "Could not reach the transcription provider. Check the network and try again.",
            502,
        )
    if isinstance(error, APIStatusError):
        message = _error_message(error)
        lower_message = message.lower()
        if "25 mb" in lower_message or "25mb" in lower_message or "too large" in lower_message:
            return AudioTranscriptionError(
                "Hosted transcription accepts a single audio upload up to 25 MB even after normalization. Trim the recording and try again.",
                413,
            )
        if "corrupted" in lower_message or "unsupported" in lower_message:
            return AudioTranscriptionError(
                "The hosted transcription providers could not decode this recording even after normalization. Re-export it as M4A, MP3, or WAV and try again.",
                400,
            )
        status_code = getattr(error, "status_code", None) or 502
        if status_code >= 500:
            status_code = 502
        return AudioTranscriptionError(
            message or "Hosted transcription rejected the request.",
            status_code,
        )
    return AudioTranscriptionError(str(error), 502)


def stream_transcription(audio_path: str) -> Generator[dict, None, None]:
    transcript = transcribe_audio(audio_path)
    yield {
        "index": 0,
        "total": 1,
        "transcript": transcript,
    }


def transcribe_audio(audio_path: str) -> str:
    file_path = Path(audio_path)
    if not file_path.exists():
        raise AudioTranscriptionError("Audio file could not be found for transcription.", 404)

    if file_path.stat().st_size > settings.max_audio_bytes:
        raise AudioTranscriptionError(
            "Audio file is too large for this workspace upload limit.",
            413,
        )

    try:
        client = _transcription_client()
        transcription_models = _transcription_models()
        with tempfile.TemporaryDirectory(prefix="lecture-transcription-") as temp_dir:
            prepared_path = _normalize_audio_for_hosted_upload(
                file_path,
                Path(temp_dir),
            )
            transcript = None
            for index, model in enumerate(transcription_models):
                try:
                    with prepared_path.open("rb") as audio_file:
                        transcript = client.audio.transcriptions.create(
                            file=audio_file,
                            **_transcription_request_options(model),
                        )
                    break
                except Exception as error:
                    has_fallback = index < len(transcription_models) - 1
                    if has_fallback and _should_retry_with_fallback(error):
                        continue
                    raise
    except Exception as error:
        raise _map_transcription_error(error) from error

    text = _extract_transcript_text(transcript)
    if not text:
        raise AudioTranscriptionError("Hosted transcription returned an empty transcript.", 502)
    return text


def store_uploaded_audio(upload: UploadFile, user_id: int) -> str:
    storage_root = _storage_root()
    date_prefix = datetime.utcnow().strftime("%Y-%m-%d")
    relative_dir = Path(_safe_segment(str(user_id))) / date_prefix
    extension = _audio_extension(upload.filename or "lecture.wav", upload.content_type or "")
    target_dir = storage_root / relative_dir
    target_dir.mkdir(parents=True, exist_ok=True)
    relative_path = relative_dir / f"{uuid.uuid4()}{extension}"
    absolute_path = storage_root / relative_path

    total_bytes = 0
    with absolute_path.open("wb") as file_handle:
        while True:
            chunk = upload.file.read(1024 * 1024)
            if not chunk:
                break
            total_bytes += len(chunk)
            if total_bytes > settings.max_audio_bytes:
                absolute_path.unlink(missing_ok=True)
                raise AudioTranscriptionError(
                    "Audio file is too large for this workspace upload limit.",
                    413,
                )
            file_handle.write(chunk)

    return str((Path(settings.lecture_storage_dir) / relative_path).as_posix())


def save_temporary_upload(upload: UploadFile) -> str:
    extension = _audio_extension(upload.filename or "lecture.wav", upload.content_type or "")
    temp_dir = tempfile.mkdtemp(prefix="lecture-upload-")
    temp_path = Path(temp_dir) / f"upload{extension}"
    total_bytes = 0
    with temp_path.open("wb") as file_handle:
        while True:
            chunk = upload.file.read(1024 * 1024)
            if not chunk:
                break
            total_bytes += len(chunk)
            if total_bytes > settings.max_audio_bytes:
                raise AudioTranscriptionError(
                    "Audio file is too large for this workspace upload limit.",
                    413,
                )
            file_handle.write(chunk)
    return str(temp_path)


def cleanup_temporary_upload(audio_path: str) -> None:
    path = Path(audio_path)
    try:
        if path.exists():
            path.unlink()
        if path.parent.exists():
            path.parent.rmdir()
    except OSError:
        pass


def resolve_audio_path(stored_path: str) -> str:
    return str((Path(__file__).resolve().parent / stored_path).resolve())


def _normalize_localized_text_map(raw_value: object) -> dict[str, str]:
    translations = {language_code: "" for language_code in SUMMARY_LANGUAGE_CODES}
    if isinstance(raw_value, dict):
        for language_code in translations:
            translations[language_code] = _normalize_summary_text(raw_value.get(language_code))
    return translations


def _normalize_key_terms(raw_terms: object) -> list[dict]:
    normalized_terms: list[dict] = []
    if not isinstance(raw_terms, list):
        return normalized_terms

    for item in raw_terms:
        if not isinstance(item, dict):
            continue
        term = str(item.get("term") or "").strip()
        explanations = _normalize_localized_text_map(item.get("explanations"))
        additional_notes = _normalize_localized_text_map(item.get("additionalNotes"))
        original_explanation = str(item.get("originalExplanation") or "").strip()
        russian_explanation = str(item.get("russianExplanation") or "").strip()
        additional_context = str(item.get("additionalContext") or "").strip()

        if original_explanation and not explanations["ko"]:
            explanations["ko"] = original_explanation
        if russian_explanation and not explanations["ru"]:
            explanations["ru"] = russian_explanation
        if additional_context and not additional_notes["ko"]:
            additional_notes["ko"] = additional_context

        if not term or not any(explanations.values()):
            continue
        normalized_terms.append(
            {
                "term": term,
                "originalExplanation": explanations["ko"] or explanations["en"] or original_explanation,
                "russianExplanation": explanations["ru"] or russian_explanation,
                "additionalContext": additional_notes["ko"] or additional_notes["en"] or additional_context,
                "explanations": {key: value for key, value in explanations.items() if value},
                "additionalNotes": {key: value for key, value in additional_notes.items() if value},
            }
        )

    return normalized_terms


def _normalize_summary_text(raw_value: object) -> str:
    if isinstance(raw_value, str):
        return raw_value.strip()
    if isinstance(raw_value, dict):
        sections: list[str] = []
        for key, value in raw_value.items():
            heading = str(key).strip()
            content = _normalize_summary_text(value)
            if not heading or not content:
                continue
            sections.append(f"{heading}\n{content}")
        return "\n\n".join(sections).strip()
    if isinstance(raw_value, list):
        lines = []
        for item in raw_value:
            line = _normalize_summary_text(item)
            if line:
                lines.append(f"- {line}" if "\n" not in line else line)
        return "\n".join(lines).strip()
    return ""


def _normalize_summary_translations(raw_value: object) -> dict[str, str]:
    translations = {language_code: "" for language_code in SUMMARY_LANGUAGE_CODES}
    if isinstance(raw_value, dict):
        for language_code in translations:
            translations[language_code] = _normalize_summary_text(raw_value.get(language_code))
    return translations


def _normalize_localized_list_map(raw_value: object) -> dict[str, list[str]]:
    localized_lists = {language_code: [] for language_code in SUMMARY_LANGUAGE_CODES}
    if isinstance(raw_value, dict):
        for language_code in localized_lists:
            localized_lists[language_code] = [
                str(item).strip()
                for item in list(raw_value.get(language_code) or [])
                if str(item).strip()
            ]
    return localized_lists


def _log_material_warning(stage: str, error: Exception) -> None:
    print(f"[lecture-materials] {stage} failed: {error}")


def _seed_study_materials(raw_value: object) -> dict:
    payload = raw_value if isinstance(raw_value, dict) else {}
    summary_translations = _normalize_summary_translations(payload.get("summaryTranslations"))
    if not summary_translations.get("en", "").strip():
        summary_translations["en"] = _normalize_summary_text(payload.get("summaryOriginal"))
    if not summary_translations.get("ru", "").strip():
        summary_translations["ru"] = _normalize_summary_text(payload.get("summaryRussian"))

    return {
        "summaryTranslations": summary_translations,
        "summaryOriginal": summary_translations.get("en", "").strip(),
        "summaryRussian": summary_translations.get("ru", "").strip(),
        "keyTerms": _normalize_key_terms(payload.get("keyTerms") or []),
        "quizzes": _normalize_quizzes(payload.get("quizzes") or []),
    }


def _key_terms_multilingual_complete(key_terms: list[dict]) -> bool:
    if not key_terms:
        return True
    for item in key_terms:
        explanations = _normalize_localized_text_map(item.get("explanations"))
        if not all(explanations.get(language_code, "").strip() for language_code in SUMMARY_LANGUAGE_CODES):
            return False
    return True


def _summary_translations_complete(translations: dict[str, str]) -> bool:
    return all(translations.get(language_code, "").strip() for language_code in SUMMARY_LANGUAGE_CODES)


def generate_summary_translations(
    title: str,
    course_name: str,
    transcript: str,
    existing_translations: dict[str, str] | None = None,
) -> dict[str, str]:
    normalized_existing = _normalize_summary_translations(existing_translations or {})
    if _summary_translations_complete(normalized_existing):
        return normalized_existing

    system = (
        "You create lecture summaries for international students. Return strict JSON only."
    )
    user = (
        f"course: {course_name}\n"
        f"lecture_title: {title}\n"
        f"transcript:\n{transcript}\n\n"
        f"existing_summary_translations: {normalized_existing}\n\n"
        'Return JSON: {"summaryTranslations":{"en":"...","ko":"...","ru":"...","zh":"..."}}. '
        "Write structured lecture-note summaries for English (`en`), Korean (`ko`), Russian (`ru`), and Chinese (`zh`). "
        "Each summary should include the three section headings `Core takeaway`, `Main flow`, and `Additional notes`, translated naturally into that language where appropriate. "
        "If an existing summary translation is already good, you may keep its meaning while still returning all four language keys. "
        "Use only facts supported by the transcript."
    )
    data = generate_json(system=system, user=user)
    if not isinstance(data, dict):
        raise ValueError("Gemini returned an invalid summary-translation payload")
    generated = _normalize_summary_translations(data.get("summaryTranslations"))
    merged = dict(normalized_existing)
    for language_code in SUMMARY_LANGUAGE_CODES:
        if generated.get(language_code, "").strip():
            merged[language_code] = generated[language_code].strip()
    return merged


def generate_text_translations(
    *,
    title: str,
    course_name: str,
    source_text: str,
    field_name: str,
) -> dict[str, str]:
    normalized_source = str(source_text or "").strip()
    if not normalized_source:
        return {language_code: "" for language_code in SUMMARY_LANGUAGE_CODES}

    system = "You translate lecture quiz content for international students. Return strict JSON only."
    user = (
        f"course: {course_name}\n"
        f"lecture_title: {title}\n"
        f"field_name: {field_name}\n"
        f"source_text: {normalized_source}\n\n"
        'Return JSON: {"translations":{"en":"...","ko":"...","ru":"...","zh":"..."}}. '
        "Translate the source text into English (`en`), Korean (`ko`), Russian (`ru`), and Chinese (`zh`). "
        "For English, Russian, and Chinese outputs, do not leave Korean text unchanged except for quoted terms that must remain in the original form. "
        "Translate surrounding prose even when technical labels like IEEE 754 or Single Precision stay in English."
    )
    data = generate_json(system=system, user=user)
    if not isinstance(data, dict):
        raise ValueError("Gemini returned an invalid text-translation payload")
    return _normalize_summary_translations(data.get("translations"))


def generate_list_translations(
    *,
    title: str,
    course_name: str,
    values: list[str],
    field_name: str,
) -> dict[str, list[str]]:
    normalized_values = [str(value).strip() for value in values if str(value).strip()]
    if not normalized_values:
        return {language_code: [] for language_code in SUMMARY_LANGUAGE_CODES}

    system = "You translate ordered lecture quiz lists for international students. Return strict JSON only."
    user = (
        f"course: {course_name}\n"
        f"lecture_title: {title}\n"
        f"field_name: {field_name}\n"
        f"source_values: {normalized_values}\n\n"
        'Return JSON: {"translations":{"en":["..."],"ko":["..."],"ru":["..."],"zh":["..."]}}. '
        "Preserve the order and list length exactly. "
        "Translate the list items into English (`en`), Korean (`ko`), Russian (`ru`), and Chinese (`zh`). "
        "Do not leave Korean text unchanged in English, Russian, or Chinese outputs unless the item is a quoted technical term."
    )
    data = generate_json(system=system, user=user)
    if not isinstance(data, dict):
        raise ValueError("Gemini returned an invalid list-translation payload")
    return _normalize_localized_list_map(data.get("translations"))


def generate_multilingual_key_terms(
    title: str,
    course_name: str,
    transcript: str,
    key_terms: list[dict],
) -> list[dict]:
    normalized_terms = _normalize_key_terms(key_terms)
    if _key_terms_multilingual_complete(normalized_terms):
        return normalized_terms

    system = (
        "You localize lecture key-term explanations for international students. Return strict JSON only."
    )
    user = (
        f"course: {course_name}\n"
        f"lecture_title: {title}\n"
        f"transcript:\n{transcript}\n\n"
        f"existing_key_terms: {normalized_terms}\n\n"
        'Return JSON: {"keyTerms":[{"term":"...","explanations":{"en":"...","ko":"...","ru":"...","zh":"..."},"additionalNotes":{"en":"...","ko":"...","ru":"...","zh":"..."}}]}. '
        "Preserve the existing term order and meaning. "
        "For each key term, provide complete explanation text in English, Korean, Russian, and Chinese. "
        "If there is an extra note such as an example, importance, or common mistake, put it in `additionalNotes` for the same four languages. "
        "Use only facts supported by the transcript and the provided existing key-term content."
    )
    data = generate_json(system=system, user=user)
    if not isinstance(data, dict):
        raise ValueError("Gemini returned an invalid key-term localization payload")
    generated_terms = _normalize_key_terms(data.get("keyTerms") or [])
    if generated_terms:
        return generated_terms
    return normalized_terms


def _normalize_quiz_localized_entry(raw_entry: object, fallback: dict) -> dict:
    question = str(fallback.get("question") or "").strip()
    options = [
        str(option).strip()
        for option in list(fallback.get("options") or [])
        if str(option).strip()
    ]
    answer = str(fallback.get("answer") or "").strip()
    explanation = str(fallback.get("explanation") or "").strip()
    review_hint = str(fallback.get("reviewHint") or "").strip()
    follow_up_prompt = str(fallback.get("followUpPrompt") or "").strip()
    skill_tag = str(fallback.get("skillTag") or "").strip()
    concept_refs = [
        str(value).strip()
        for value in list(fallback.get("conceptRefs") or [])
        if str(value).strip()
    ]

    if isinstance(raw_entry, dict):
        question = str(raw_entry.get("question") or question).strip()
        options = [
            str(option).strip()
            for option in list(raw_entry.get("options") or options)
            if str(option).strip()
        ]
        answer = str(raw_entry.get("answer") or answer).strip()
        explanation = str(raw_entry.get("explanation") or explanation).strip()
        review_hint = str(raw_entry.get("reviewHint") or review_hint).strip()
        follow_up_prompt = str(raw_entry.get("followUpPrompt") or follow_up_prompt).strip()
        skill_tag = str(raw_entry.get("skillTag") or skill_tag).strip()
        concept_refs = [
            str(value).strip()
            for value in list(raw_entry.get("conceptRefs") or concept_refs)
            if str(value).strip()
        ]

    if skill_tag and skill_tag not in concept_refs:
        concept_refs.insert(0, skill_tag)

    return {
        "question": question,
        "options": options,
        "answer": answer,
        "explanation": explanation,
        "reviewHint": review_hint,
        "followUpPrompt": follow_up_prompt,
        "skillTag": skill_tag,
        "conceptRefs": concept_refs,
    }


def _normalize_quiz_localizations(raw_value: object, fallback: dict) -> dict[str, dict]:
    localized_content: dict[str, dict] = {}
    if not isinstance(raw_value, dict):
        return localized_content

    for language_code in SUMMARY_LANGUAGE_CODES:
        normalized_entry = _normalize_quiz_localized_entry(raw_value.get(language_code), fallback)
        if normalized_entry["question"] and normalized_entry["answer"]:
            localized_content[language_code] = normalized_entry
    return localized_content


def _contains_hangul(text: str) -> bool:
    return any("\uac00" <= char <= "\ud7a3" for char in text)


def _contains_cyrillic(text: str) -> bool:
    return any("\u0400" <= char <= "\u04ff" for char in text)


def _contains_cjk(text: str) -> bool:
    return any("\u4e00" <= char <= "\u9fff" for char in text)


def _contains_latin(text: str) -> bool:
    return any(("A" <= char <= "Z") or ("a" <= char <= "z") for char in text)


def _looks_localized_for_language(language_code: str, text: str) -> bool:
    value = str(text or "").strip()
    if not value:
        return False
    if language_code == "ko":
        return _contains_hangul(value)
    if language_code == "ru":
        return _contains_cyrillic(value)
    if language_code == "zh":
        return _contains_cjk(value)
    if language_code == "en":
        return _contains_latin(value)
    return True


def _quiz_entry_looks_localized(language_code: str, entry: dict, fallback: dict) -> bool:
    question = str(entry.get("question") or "").strip()
    explanation = str(entry.get("explanation") or "").strip()
    skill_tag = str(entry.get("skillTag") or "").strip()
    concept_refs = [
        str(value).strip()
        for value in list(entry.get("conceptRefs") or [])
        if str(value).strip()
    ]
    fallback_question = str(fallback.get("question") or "").strip()
    fallback_explanation = str(fallback.get("explanation") or "").strip()

    if language_code != "ko" and question == fallback_question and _contains_hangul(fallback_question):
        return False
    if language_code != "ko" and explanation == fallback_explanation and _contains_hangul(fallback_explanation):
        return False

    if not (
        _looks_localized_for_language(language_code, question)
        or _looks_localized_for_language(language_code, explanation)
    ):
        return False

    if language_code in {"en", "ru", "zh"}:
        if _contains_hangul(question) and not _looks_localized_for_language(language_code, question):
            return False
        if _contains_hangul(explanation) and not _looks_localized_for_language(language_code, explanation):
            return False
        if skill_tag and _contains_hangul(skill_tag) and not _looks_localized_for_language(language_code, skill_tag):
            return False
        if any(
            _contains_hangul(concept) and not _looks_localized_for_language(language_code, concept)
            for concept in concept_refs
        ):
            return False

    return True


def _normalize_quizzes(raw_quizzes: object) -> list[dict]:
    normalized_quizzes: list[dict] = []
    if not isinstance(raw_quizzes, list):
        return normalized_quizzes

    for item in raw_quizzes:
        if not isinstance(item, dict):
            continue
        question = str(item.get("question") or "").strip()
        answer = str(item.get("answer") or "").strip()
        if not question or not answer:
            continue
        options = [
            str(option).strip()
            for option in list(item.get("options") or [])
            if str(option).strip()
        ]
        skill_tag = str(item.get("skillTag") or "").strip()
        concept_refs = [
            str(value).strip()
            for value in list(item.get("conceptRefs") or [])
            if str(value).strip()
        ]
        if skill_tag and skill_tag not in concept_refs:
            concept_refs.insert(0, skill_tag)
        normalized_quiz = {
            "type": str(item.get("type") or "multiple_choice").strip() or "multiple_choice",
            "question": question,
            "options": options,
            "answer": answer,
            "explanation": str(item.get("explanation") or "").strip(),
            "difficulty": str(item.get("difficulty") or "easy").strip() or "easy",
            "skillTag": skill_tag or (concept_refs[0] if concept_refs else ""),
            "conceptRefs": concept_refs,
            "reviewHint": str(item.get("reviewHint") or "").strip(),
            "followUpPrompt": str(item.get("followUpPrompt") or "").strip(),
        }
        normalized_quiz["localizedContent"] = _normalize_quiz_localizations(
            item.get("localizedContent"),
            normalized_quiz,
        )
        normalized_quizzes.append(normalized_quiz)

    return normalized_quizzes


def _quizzes_multilingual_complete(quizzes: list[dict]) -> bool:
    if not quizzes:
        return True

    for quiz in quizzes:
        localized_content = quiz.get("localizedContent") or {}
        if not isinstance(localized_content, dict):
            return False
        option_count = len(list(quiz.get("options") or []))
        for language_code in SUMMARY_LANGUAGE_CODES:
            entry = localized_content.get(language_code)
            if not isinstance(entry, dict):
                return False
            if not str(entry.get("question") or "").strip():
                return False
            if not str(entry.get("answer") or "").strip():
                return False
            if not str(entry.get("explanation") or "").strip():
                return False
            localized_options = [
                str(option).strip()
                for option in list(entry.get("options") or [])
                if str(option).strip()
            ]
            if option_count and len(localized_options) != option_count:
                return False
            if not _quiz_entry_looks_localized(language_code, entry, quiz):
                return False
    return True


def _quizzes_ready_for_review(quizzes: list[dict]) -> bool:
    if not quizzes:
        return True
    return all(
        quiz.get("skillTag", "").strip()
        and list(quiz.get("conceptRefs") or [])
        and quiz.get("reviewHint", "").strip()
        for quiz in quizzes
    )


def _dedupe_quizzes(quizzes: list[dict]) -> list[dict]:
    deduped: list[dict] = []
    seen_questions: set[str] = set()
    for quiz in quizzes:
        question_key = " ".join(str(quiz.get("question") or "").strip().casefold().split())
        if not question_key or question_key in seen_questions:
            continue
        seen_questions.add(question_key)
        deduped.append(quiz)
    return deduped


def generate_quiz_set(
    title: str,
    course_name: str,
    transcript: str,
    *,
    existing_quizzes: list[dict] | None = None,
    question_count: int = TARGET_QUIZ_COUNT,
    force_new: bool = False,
) -> list[dict]:
    target_count = max(1, question_count)
    normalized_quizzes = _dedupe_quizzes(_normalize_quizzes(existing_quizzes or []))

    if force_new or len(normalized_quizzes) != target_count:
        best_quizzes = list(normalized_quizzes)
        for attempt in range(2):
            system = (
                "You create lecture review quizzes for active recall. Return strict JSON only."
            )
            user = (
                f"course: {course_name}\n"
                f"lecture_title: {title}\n"
                f"transcript:\n{transcript}\n\n"
                f"existing_quizzes: {best_quizzes}\n"
                f"question_count: {target_count}\n"
                f"attempt: {attempt + 1}\n\n"
                'Return JSON: {"quizzes":[{"type":"multiple_choice|short_answer|blank","question":"...","options":["..."],"answer":"...","explanation":"...","difficulty":"easy|medium|hard","skillTag":"...","conceptRefs":["..."],"reviewHint":"...","followUpPrompt":"...","localizedContent":{"en":{"question":"...","options":["..."],"answer":"...","explanation":"...","reviewHint":"...","followUpPrompt":"...","skillTag":"...","conceptRefs":["..."]},"ko":{"question":"...","options":["..."],"answer":"...","explanation":"...","reviewHint":"...","followUpPrompt":"...","skillTag":"...","conceptRefs":["..."]},"ru":{"question":"...","options":["..."],"answer":"...","explanation":"...","reviewHint":"...","followUpPrompt":"...","skillTag":"...","conceptRefs":["..."]},"zh":{"question":"...","options":["..."],"answer":"...","explanation":"...","reviewHint":"...","followUpPrompt":"...","skillTag":"...","conceptRefs":["..."]}}}]}. '
                f"Create exactly {target_count} quiz questions from the transcript. "
                "Mix roughly 40% memory-check items, 40% concept-understanding items, and 20% application items. "
                "Each quiz should include a short concept label, one to three concept references, a review hint, and a next-step prompt. "
                "Use only facts supported by the transcript."
            )
            data = generate_json(system=system, user=user)
            if not isinstance(data, dict):
                continue
            candidate_quizzes = _dedupe_quizzes(_normalize_quizzes(data.get("quizzes") or []))
            if candidate_quizzes:
                best_quizzes = candidate_quizzes
            if len(best_quizzes) >= target_count:
                break

        normalized_quizzes = list(best_quizzes)

    if not normalized_quizzes:
        raise ValueError("The model did not return any quizzes.")

    normalized_quizzes = generate_review_quizzes(
        title,
        course_name,
        transcript,
        normalized_quizzes,
    )
    normalized_quizzes = generate_multilingual_quizzes(
        title,
        course_name,
        transcript,
        normalized_quizzes,
    )
    normalized_quizzes = _dedupe_quizzes(normalized_quizzes)
    if len(normalized_quizzes) > target_count:
        normalized_quizzes = normalized_quizzes[:target_count]
    return normalized_quizzes


def generate_review_quizzes(
    title: str,
    course_name: str,
    transcript: str,
    quizzes: list[dict],
) -> list[dict]:
    normalized_quizzes = _normalize_quizzes(quizzes)
    if _quizzes_ready_for_review(normalized_quizzes):
        return normalized_quizzes

    system = (
        "You improve lecture review quizzes for active recall. Return strict JSON only."
    )
    user = (
        f"course: {course_name}\n"
        f"lecture_title: {title}\n"
        f"transcript:\n{transcript}\n\n"
        f"existing_quizzes: {normalized_quizzes}\n\n"
        'Return JSON: {"quizzes":[{"type":"multiple_choice|short_answer|blank","question":"...","options":["..."],"answer":"...","explanation":"...","difficulty":"easy|medium|hard","skillTag":"...","conceptRefs":["..."],"reviewHint":"...","followUpPrompt":"..."}]}. '
        "Preserve the existing quiz count, order, answer key, and overall meaning. "
        "For each quiz, provide a short `skillTag`, one to three `conceptRefs`, a learner-friendly `reviewHint`, and a `followUpPrompt` that tells the student what to practice next if they miss it. "
        "Use only facts supported by the transcript."
    )
    data = generate_json(system=system, user=user)
    if not isinstance(data, dict):
        raise ValueError("Gemini returned an invalid quiz enrichment payload")
    generated_quizzes = _normalize_quizzes(data.get("quizzes") or [])
    if generated_quizzes:
        return generated_quizzes
    return normalized_quizzes


def generate_multilingual_quizzes(
    title: str,
    course_name: str,
    transcript: str,
    quizzes: list[dict],
) -> list[dict]:
    normalized_quizzes = _normalize_quizzes(quizzes)
    if _quizzes_multilingual_complete(normalized_quizzes):
        return normalized_quizzes

    def fill_quiz_localizations(quiz: dict) -> dict:
        localized_content = _normalize_quiz_localizations(quiz.get("localizedContent"), quiz)
        question_translations = generate_text_translations(
            title=title,
            course_name=course_name,
            source_text=str(quiz.get("question") or ""),
            field_name="quiz question",
        )
        explanation_translations = generate_text_translations(
            title=title,
            course_name=course_name,
            source_text=str(quiz.get("explanation") or ""),
            field_name="quiz explanation",
        )
        review_hint_translations = generate_text_translations(
            title=title,
            course_name=course_name,
            source_text=str(quiz.get("reviewHint") or ""),
            field_name="quiz review hint",
        )
        follow_up_translations = generate_text_translations(
            title=title,
            course_name=course_name,
            source_text=str(quiz.get("followUpPrompt") or ""),
            field_name="quiz follow-up prompt",
        )
        skill_tag_translations = generate_text_translations(
            title=title,
            course_name=course_name,
            source_text=str(quiz.get("skillTag") or ""),
            field_name="quiz concept label",
        )
        concept_refs_translations = generate_list_translations(
            title=title,
            course_name=course_name,
            values=[
                str(value).strip()
                for value in list(quiz.get("conceptRefs") or [])
                if str(value).strip()
            ],
            field_name="quiz concept references",
        )

        options = [
            str(option).strip()
            for option in list(quiz.get("options") or [])
            if str(option).strip()
        ]
        answer = str(quiz.get("answer") or "").strip()
        option_translations = {language_code: [] for language_code in SUMMARY_LANGUAGE_CODES}
        answer_translations = {language_code: "" for language_code in SUMMARY_LANGUAGE_CODES}
        if options:
            option_translations = generate_list_translations(
                title=title,
                course_name=course_name,
                values=options,
                field_name="quiz answer options",
            )
            answer_index = options.index(answer) if answer in options else -1
            if answer_index >= 0:
                for language_code in SUMMARY_LANGUAGE_CODES:
                    translated_options = option_translations.get(language_code) or []
                    if len(translated_options) > answer_index:
                        answer_translations[language_code] = translated_options[answer_index]
        else:
            answer_translations = generate_text_translations(
                title=title,
                course_name=course_name,
                source_text=answer,
                field_name="quiz answer",
            )

        for language_code in SUMMARY_LANGUAGE_CODES:
            localized_content[language_code] = {
                "question": question_translations.get(language_code, "").strip(),
                "options": option_translations.get(language_code) or [],
                "answer": answer_translations.get(language_code, "").strip(),
                "explanation": explanation_translations.get(language_code, "").strip(),
                "reviewHint": review_hint_translations.get(language_code, "").strip(),
                "followUpPrompt": follow_up_translations.get(language_code, "").strip(),
                "skillTag": skill_tag_translations.get(language_code, "").strip(),
                "conceptRefs": concept_refs_translations.get(language_code) or [],
            }

        updated_quiz = dict(quiz)
        updated_quiz["localizedContent"] = localized_content
        return updated_quiz

    localized_quizzes: list[dict] = []
    for quiz in normalized_quizzes:
        if _quizzes_multilingual_complete([quiz]):
            localized_quizzes.append(quiz)
            continue

        best_quiz = quiz
        for attempt in range(2):
            system = (
                "You localize a single lecture review quiz for international students. Return strict JSON only."
            )
            user = (
                f"course: {course_name}\n"
                f"lecture_title: {title}\n"
                f"transcript:\n{transcript}\n\n"
                f"existing_quiz: {best_quiz}\n\n"
                f"attempt: {attempt + 1}\n\n"
                'Return JSON: {"quiz":{"type":"multiple_choice|short_answer|blank","question":"...","options":["..."],"answer":"...","explanation":"...","difficulty":"easy|medium|hard","skillTag":"...","conceptRefs":["..."],"reviewHint":"...","followUpPrompt":"...","localizedContent":{"en":{"question":"...","options":["..."],"answer":"...","explanation":"...","reviewHint":"...","followUpPrompt":"...","skillTag":"...","conceptRefs":["..."]},"ko":{"question":"...","options":["..."],"answer":"...","explanation":"...","reviewHint":"...","followUpPrompt":"...","skillTag":"...","conceptRefs":["..."]},"ru":{"question":"...","options":["..."],"answer":"...","explanation":"...","reviewHint":"...","followUpPrompt":"...","skillTag":"...","conceptRefs":["..."]},"zh":{"question":"...","options":["..."],"answer":"...","explanation":"...","reviewHint":"...","followUpPrompt":"...","skillTag":"...","conceptRefs":["..."]}}}}. '
                "Preserve the answer key and the overall meaning. "
                "Translate the quiz into English (`en`), Korean (`ko`), Russian (`ru`), and Chinese (`zh`). "
                "For multiple-choice quizzes, each localized `answer` must exactly match one item in the localized `options` list for that same language. "
                "Do not leave Korean text inside the English, Russian, or Chinese entries except for technical terms that genuinely should stay unchanged. "
                "If a previous localization was written in the wrong language, replace it with a correct translation."
            )
            data = generate_json(system=system, user=user)
            if not isinstance(data, dict):
                raise ValueError("Gemini returned an invalid multilingual quiz payload")
            candidate_quizzes = _normalize_quizzes([data.get("quiz") or {}])
            if candidate_quizzes:
                best_quiz = candidate_quizzes[0]
            if _quizzes_multilingual_complete([best_quiz]):
                break

        if not _quizzes_multilingual_complete([best_quiz]):
            best_quiz = fill_quiz_localizations(best_quiz)
        localized_quizzes.append(best_quiz)

    return localized_quizzes


def generate_study_materials(title: str, course_name: str, transcript: str) -> dict:
    system = (
        "You create study materials for Russian-speaking international students studying university lectures "
        "in Korean or English. Return strict JSON only."
    )
    user = (
        f"course: {course_name}\n"
        f"lecture_title: {title}\n"
        f"transcript:\n{transcript}\n\n"
        'Return JSON: {"summaryTranslations":{"en":"...","ko":"...","ru":"...","zh":"..."},"keyTerms":[{"term":"...",'
        '"explanations":{"en":"...","ko":"...","ru":"...","zh":"..."},"additionalNotes":{"en":"...","ko":"...","ru":"...","zh":"..."}}],"quizzes":[{"type":"multiple_choice|short_answer|blank",'
        '"question":"...","options":["..."],"answer":"...","explanation":"...","difficulty":"easy|medium|hard","skillTag":"...","conceptRefs":["..."],"reviewHint":"...","followUpPrompt":"...","localizedContent":{"en":{"question":"...","options":["..."],"answer":"...","explanation":"...","reviewHint":"...","followUpPrompt":"...","skillTag":"...","conceptRefs":["..."]},"ko":{"question":"...","options":["..."],"answer":"...","explanation":"...","reviewHint":"...","followUpPrompt":"...","skillTag":"...","conceptRefs":["..."]},"ru":{"question":"...","options":["..."],"answer":"...","explanation":"...","reviewHint":"...","followUpPrompt":"...","skillTag":"...","conceptRefs":["..."]},"zh":{"question":"...","options":["..."],"answer":"...","explanation":"...","reviewHint":"...","followUpPrompt":"...","skillTag":"...","conceptRefs":["..."]}}}]}. '
        "Use only facts supported by the transcript. "
        "Write summaryTranslations as four structured lecture-note summaries for English (`en`), Korean (`ko`), Russian (`ru`), and Chinese (`zh`). "
        "Each summary should include the three section headings `Core takeaway`, `Main flow`, and `Additional notes`, translated naturally into that language where appropriate. "
        "For each keyTerms item, use the term as the main keyword, and provide explanation text plus additional notes in English, Korean, Russian, and Chinese. "
        "For quizzes, mix roughly 40% memory-check items, 40% concept-understanding items, and 20% application items. "
        "Each quiz should include a short concept label, one to three concept references, a review hint, and a next-step prompt. "
        f"Produce 3 to 8 key terms and exactly {TARGET_QUIZ_COUNT} quizzes."
    )
    initial_error: Exception | None = None
    try:
        payload = generate_json(system=system, user=user)
        if not isinstance(payload, dict):
            raise ValueError("Gemini returned an invalid study-material payload")
    except Exception as error:
        initial_error = error
        _log_material_warning("initial study-material generation", error)
        payload = {}

    data = _seed_study_materials(payload)

    try:
        data["summaryTranslations"] = generate_summary_translations(
            title,
            course_name,
            transcript,
            existing_translations=data.get("summaryTranslations"),
        )
        data["summaryOriginal"] = data["summaryTranslations"].get("en", "")
        data["summaryRussian"] = data["summaryTranslations"].get("ru", "")
    except Exception as error:
        _log_material_warning("summary translation", error)
        if not any(str(value or "").strip() for value in data["summaryTranslations"].values()):
            if initial_error is not None:
                raise initial_error
            raise

    try:
        data["keyTerms"] = generate_multilingual_key_terms(
            title,
            course_name,
            transcript,
            list(data.get("keyTerms") or []),
        )
    except Exception as error:
        _log_material_warning("key-term enrichment", error)

    try:
        data["quizzes"] = generate_quiz_set(
            title,
            course_name,
            transcript,
            existing_quizzes=list(data.get("quizzes") or []),
            question_count=TARGET_QUIZ_COUNT,
        )
    except Exception as error:
        _log_material_warning("quiz generation", error)

    if not isinstance(data["keyTerms"], list) or not isinstance(data["quizzes"], list):
        raise ValueError("Gemini returned malformed study-material collections")
    return data
