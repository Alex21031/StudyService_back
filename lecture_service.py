import json
import os
import subprocess
import tempfile
import uuid
from datetime import datetime
from pathlib import Path
from typing import Dict, Generator, Iterable, List

from fastapi import UploadFile

from config import settings
from gemini_api import generate_json


DEFAULT_CHUNK_SECONDS = 600
MIN_CHUNK_SECONDS = 60
MAX_CHUNK_SECONDS = 1800

WHISPER_SCRIPT = """
import json
import os
import sys

try:
    import whisper
except ModuleNotFoundError as error:
    print(json.dumps({"error": "missing_whisper", "detail": str(error)}))
    sys.exit(42)

audio_paths = sys.argv[1:]
model_name = os.environ.get("WHISPER_MODEL", "turbo")
language = os.environ.get("WHISPER_LANGUAGE") or None
device = os.environ.get("WHISPER_DEVICE") or None
download_root = os.environ.get("WHISPER_MODEL_DIR") or None

model = whisper.load_model(model_name, device=device, download_root=download_root)
options = {
    "task": "transcribe",
    "verbose": False,
    "fp16": False,
}

if language:
    options["language"] = language

total = len(audio_paths)

for index, audio_path in enumerate(audio_paths):
    result = model.transcribe(audio_path, **options)
    print(json.dumps({
        "index": index,
        "total": total,
        "transcript": (result.get("text") or "").strip()
    }, ensure_ascii=False), flush=True)
"""


class WhisperTranscriptionError(Exception):
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


def _chunk_seconds() -> int:
    value = int(settings.whisper_chunk_seconds or DEFAULT_CHUNK_SECONDS)
    return max(MIN_CHUNK_SECONDS, min(MAX_CHUNK_SECONDS, value))


def _whisper_env() -> Dict[str, str]:
    env = dict(os.environ)
    if settings.whisper_path_prefix:
        current_path = env.get("PATH", "")
        env["PATH"] = f"{settings.whisper_path_prefix}:{current_path}" if current_path else settings.whisper_path_prefix
    env["WHISPER_MODEL"] = settings.whisper_model
    if settings.whisper_language:
        env["WHISPER_LANGUAGE"] = settings.whisper_language
    if settings.whisper_device:
        env["WHISPER_DEVICE"] = settings.whisper_device
    if settings.whisper_model_dir:
        env["WHISPER_MODEL_DIR"] = settings.whisper_model_dir
    return env


def _compact_output(*parts: str) -> str:
    lines: List[str] = []
    for part in parts:
        if not part:
            continue
        lines.extend(line.strip() for line in part.splitlines() if line.strip())
    return " ".join(lines[-4:])


def _map_whisper_error(message: str, output: str = "", status: int = 502) -> WhisperTranscriptionError:
    lower_output = output.lower()
    if "missing_whisper" in output or "no module named" in lower_output:
        return WhisperTranscriptionError(
            "OpenAI Whisper is not installed. Install it in the Python runtime used by StudyService_back.",
            501,
        )
    if "ffmpeg" in lower_output:
        return WhisperTranscriptionError("ffmpeg is required for audio decoding and chunking.", 501)
    if output:
        return WhisperTranscriptionError(f"{message}: {output}", status)
    return WhisperTranscriptionError(message, status)


def _run_ffmpeg_chunking(input_path: str, chunk_dir: str) -> List[str]:
    Path(chunk_dir).mkdir(parents=True, exist_ok=True)
    command = [
        settings.whisper_ffmpeg_bin,
        "-hide_banner",
        "-loglevel",
        "error",
        "-i",
        input_path,
        "-f",
        "segment",
        "-segment_time",
        str(_chunk_seconds()),
        "-reset_timestamps",
        "1",
        "-ac",
        "1",
        "-ar",
        "16000",
        str(Path(chunk_dir) / "chunk-%05d.wav"),
    ]

    try:
        completed = subprocess.run(
            command,
            check=True,
            capture_output=True,
            text=True,
            env=_whisper_env(),
            timeout=max(1, settings.whisper_total_timeout_ms // 1000),
        )
    except FileNotFoundError as error:
        raise WhisperTranscriptionError("ffmpeg is required for Whisper audio chunking.", 501) from error
    except subprocess.TimeoutExpired as error:
        raise WhisperTranscriptionError("Audio chunking timed out.", 504) from error
    except subprocess.CalledProcessError as error:
        output = _compact_output(error.stdout or "", error.stderr or "")
        raise _map_whisper_error("Audio chunking failed", output) from error

    chunk_paths = sorted(str(path) for path in Path(chunk_dir).glob("chunk-*.wav"))
    if not chunk_paths:
        output = _compact_output(completed.stdout, completed.stderr)
        raise _map_whisper_error("Audio chunking produced no chunks", output)
    return chunk_paths


def _stream_whisper_chunks(chunk_paths: Iterable[str]) -> Generator[dict, None, None]:
    command = [settings.whisper_python_bin, "-c", WHISPER_SCRIPT, *chunk_paths]
    try:
        process = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=_whisper_env(),
        )
    except FileNotFoundError as error:
        raise WhisperTranscriptionError(
            "Python is not available. Install Python and set WHISPER_PYTHON_BIN if needed.",
            501,
        ) from error

    try:
        assert process.stdout is not None
        for raw_line in process.stdout:
            line = raw_line.strip()
            if not line:
                continue
            try:
                payload = json.loads(line)
            except json.JSONDecodeError:
                continue
            if payload.get("error"):
                raise _map_whisper_error("Whisper transcription failed", str(payload))
            yield payload
        stderr = process.stderr.read() if process.stderr is not None else ""
        return_code = process.wait(timeout=max(1, settings.whisper_total_timeout_ms // 1000))
    except subprocess.TimeoutExpired as error:
        process.kill()
        raise WhisperTranscriptionError("Whisper transcription timed out.", 504) from error
    finally:
        if process.poll() is None:
            process.kill()

    if return_code != 0:
        raise _map_whisper_error("Whisper transcription failed", _compact_output(stderr), 502)


def stream_transcription(audio_path: str) -> Generator[dict, None, None]:
    with tempfile.TemporaryDirectory(prefix="lecture-chunks-") as chunk_dir:
        chunk_paths = _run_ffmpeg_chunking(audio_path, chunk_dir)
        for payload in _stream_whisper_chunks(chunk_paths):
            yield {
                "index": int(payload.get("index", 0)),
                "total": int(payload.get("total", len(chunk_paths))),
                "transcript": str(payload.get("transcript") or "").strip(),
            }


def transcribe_audio(audio_path: str) -> str:
    transcript_parts: List[str] = []
    for payload in stream_transcription(audio_path):
        chunk_text = payload["transcript"]
        if chunk_text:
            transcript_parts.append(chunk_text)
    transcript = "\n\n".join(transcript_parts).strip()
    if not transcript:
        raise WhisperTranscriptionError("Whisper returned an empty transcript.", 502)
    return transcript


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
                raise WhisperTranscriptionError("Audio file is too large.", 413)
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
                raise WhisperTranscriptionError("Audio file is too large.", 413)
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


def generate_study_materials(title: str, course_name: str, transcript: str) -> dict:
    system = (
        "You create study materials for Russian-speaking international students studying university lectures "
        "in Korean or English. Return strict JSON only."
    )
    user = (
        f"course: {course_name}\n"
        f"lecture_title: {title}\n"
        f"transcript:\n{transcript}\n\n"
        'Return JSON: {"summaryOriginal":"...","summaryRussian":"...","keyTerms":[{"term":"...",'
        '"originalExplanation":"...","russianExplanation":"..."}],"quizzes":[{"type":"multiple_choice|short_answer|blank",'
        '"question":"...","options":["..."],"answer":"...","explanation":"...","difficulty":"easy|medium|hard"}]}. '
        "Use only facts supported by the transcript. Produce 2 to 8 key terms and 2 to 6 quizzes."
    )
    data = generate_json(system=system, user=user)
    if not isinstance(data, dict):
        raise ValueError("Gemini returned an invalid study-material payload")
    data.setdefault("summaryOriginal", "")
    data.setdefault("summaryRussian", "")
    data.setdefault("keyTerms", [])
    data.setdefault("quizzes", [])
    if not isinstance(data["keyTerms"], list) or not isinstance(data["quizzes"], list):
        raise ValueError("Gemini returned malformed study-material collections")
    return data
