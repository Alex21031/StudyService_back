# FastAPI Backend

## 运行（本地）

```bash
python -m venv .venv
.venv\Scripts\activate
python -m pip install -U pip
pip install -r requirements.txt
copy .env.example .env
uvicorn main:app --reload
```

访问：
- http://127.0.0.1:8000/health
- http://127.0.0.1:8000/docs

## Lecture API

The merged backend now includes lecture-processing endpoints for the `Project` app:

- `POST /lectures/transcribe-audio`
- `POST /lectures/process-audio`
- `GET /lectures`
- `GET /lectures/{lecture_id}`
- `GET /lectures/{lecture_id}/quizzes`
- `POST /lectures/{lecture_id}/quiz-attempts`

`/lectures/process-audio` requires JWT auth from `/auth/token`. Audio uploads are stored under `LECTURE_STORAGE_DIR`, then transcribed with local Whisper and turned into summaries, Russian notes, key terms, and quizzes through Gemini.

Before using lecture processing locally, make sure the Python runtime configured by `WHISPER_PYTHON_BIN` can import `whisper`, and make sure `ffmpeg` is installed or reachable through `WHISPER_PATH_PREFIX`.
