import datetime as dt
import json
from typing import Iterable, List

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload
from starlette.responses import StreamingResponse

from auth import get_current_user
from database import Lecture, LectureQuiz, QuizAttempt, User, get_db
from gemini_api import GeminiNotConfiguredError
from lecture_service import (
    WhisperTranscriptionError,
    cleanup_temporary_upload,
    generate_study_materials,
    resolve_audio_path,
    save_temporary_upload,
    store_uploaded_audio,
    stream_transcription,
    transcribe_audio,
)
from schemas import (
    LectureDetailOut,
    LectureOut,
    LectureQuizOut,
    ProcessLectureResponse,
    QuizAttemptRequest,
    QuizAttemptResponse,
    TranscriptResponse,
)


router = APIRouter(prefix="/lectures", tags=["lectures"])


def _now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def _lecture_to_out(lecture: Lecture) -> LectureOut:
    return LectureOut(
        id=lecture.id,
        userId=lecture.user_id,
        title=lecture.title,
        courseName=lecture.course_name,
        audioPath=lecture.audio_path,
        status=lecture.status,
        transcript=lecture.transcript,
        summaryOriginal=lecture.summary_original,
        summaryRussian=lecture.summary_russian,
        keyTerms=lecture.key_terms or [],
        errorMessage=lecture.error_message,
        createdAt=lecture.created_at,
        updatedAt=lecture.updated_at,
    )


def _quiz_to_out(quiz: LectureQuiz) -> LectureQuizOut:
    return LectureQuizOut(
        id=quiz.id,
        lectureId=quiz.lecture_id,
        type=quiz.type,
        question=quiz.question,
        options=quiz.options or [],
        answer=quiz.answer,
        explanation=quiz.explanation,
        difficulty=quiz.difficulty,
        createdAt=quiz.created_at,
    )


def _owned_lecture(db: Session, lecture_id: str, user_id: int) -> Lecture:
    lecture = db.scalar(
        select(Lecture)
        .where(Lecture.id == lecture_id, Lecture.user_id == user_id)
        .options(selectinload(Lecture.quizzes))
    )
    if not lecture:
        raise HTTPException(status_code=404, detail="Lecture not found")
    return lecture


def _streaming_payload(audio_path: str) -> Iterable[bytes]:
    transcript_parts: List[str] = []
    try:
        for payload in stream_transcription(audio_path):
            chunk_text = payload["transcript"]
            if chunk_text:
                transcript_parts.append(chunk_text)
            yield f'{json.dumps({"type": "chunk", **payload}, ensure_ascii=False)}\n'.encode("utf-8")
        final_transcript = "\n\n".join(transcript_parts).strip()
        yield f'{json.dumps({"type": "done", "transcript": final_transcript}, ensure_ascii=False)}\n'.encode("utf-8")
    except WhisperTranscriptionError as error:
        yield f'{json.dumps({"type": "error", "error": str(error)}, ensure_ascii=False)}\n'.encode("utf-8")
    finally:
        cleanup_temporary_upload(audio_path)


@router.post("/transcribe-audio", response_model=TranscriptResponse)
def transcribe_audio_route(
    stream: bool = Query(False),
    audio: UploadFile = File(...),
):
    temp_audio_path = save_temporary_upload(audio)
    if stream:
        return StreamingResponse(
            _streaming_payload(temp_audio_path),
            media_type="application/x-ndjson; charset=utf-8",
            headers={"Cache-Control": "no-cache"},
        )

    try:
        transcript = transcribe_audio(temp_audio_path)
        return TranscriptResponse(transcript=transcript)
    except WhisperTranscriptionError as error:
        raise HTTPException(status_code=error.status, detail=str(error)) from error
    finally:
        cleanup_temporary_upload(temp_audio_path)


@router.post("/process-audio", response_model=ProcessLectureResponse, status_code=status.HTTP_201_CREATED)
def process_audio_route(
    title: str = Form(...),
    course_name: str = Form(..., alias="courseName"),
    audio: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not title.strip():
        raise HTTPException(status_code=400, detail="title is required")
    if not course_name.strip():
        raise HTTPException(status_code=400, detail="courseName is required")

    stored_audio_path = store_uploaded_audio(audio, current_user.id)
    lecture = Lecture(
        user_id=current_user.id,
        title=title.strip(),
        course_name=course_name.strip(),
        audio_path=stored_audio_path,
        status="uploaded",
        key_terms=[],
        updated_at=_now(),
    )
    db.add(lecture)
    db.commit()
    db.refresh(lecture)

    try:
        lecture.status = "transcribing"
        lecture.error_message = None
        lecture.updated_at = _now()
        db.add(lecture)
        db.commit()

        transcript = transcribe_audio(resolve_audio_path(lecture.audio_path))
        lecture.transcript = transcript
        lecture.status = "summarizing"
        lecture.updated_at = _now()
        db.add(lecture)
        db.commit()

        materials = generate_study_materials(lecture.title, lecture.course_name, transcript)
        lecture.summary_original = str(materials.get("summaryOriginal") or "")
        lecture.summary_russian = str(materials.get("summaryRussian") or "")
        lecture.key_terms = list(materials.get("keyTerms") or [])
        lecture.status = "generating_quiz"
        lecture.updated_at = _now()
        db.add(lecture)
        db.commit()

        for quiz in list(lecture.quizzes):
            db.delete(quiz)
        db.flush()

        for quiz_payload in list(materials.get("quizzes") or []):
            quiz = LectureQuiz(
                lecture_id=lecture.id,
                type=str(quiz_payload.get("type") or "multiple_choice"),
                question=str(quiz_payload.get("question") or "").strip(),
                options=[
                    str(option).strip()
                    for option in list(quiz_payload.get("options") or [])
                    if str(option).strip()
                ],
                answer=str(quiz_payload.get("answer") or "").strip(),
                explanation=str(quiz_payload.get("explanation") or "").strip(),
                difficulty=str(quiz_payload.get("difficulty") or "easy"),
            )
            if quiz.question and quiz.answer:
                db.add(quiz)

        lecture.status = "ready"
        lecture.updated_at = _now()
        db.add(lecture)
        db.commit()
        db.refresh(lecture)
        lecture = _owned_lecture(db, lecture.id, current_user.id)
    except WhisperTranscriptionError as error:
        lecture.status = "failed"
        lecture.error_message = str(error)
        lecture.updated_at = _now()
        db.add(lecture)
        db.commit()
        raise HTTPException(status_code=error.status, detail=str(error)) from error
    except GeminiNotConfiguredError as error:
        lecture.status = "failed"
        lecture.error_message = str(error)
        lecture.updated_at = _now()
        db.add(lecture)
        db.commit()
        raise HTTPException(status_code=503, detail=str(error)) from error
    except Exception as error:
        lecture.status = "failed"
        lecture.error_message = str(error)
        lecture.updated_at = _now()
        db.add(lecture)
        db.commit()
        raise HTTPException(status_code=502, detail="Lecture processing failed") from error

    return ProcessLectureResponse(
        lecture=_lecture_to_out(lecture),
        quizzes=[_quiz_to_out(quiz) for quiz in lecture.quizzes],
    )


@router.get("", response_model=List[LectureOut])
def list_lectures(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    lectures = db.scalars(
        select(Lecture)
        .where(Lecture.user_id == current_user.id)
        .order_by(Lecture.created_at.desc())
    ).all()
    return [_lecture_to_out(lecture) for lecture in lectures]


@router.get("/{lecture_id}", response_model=LectureDetailOut)
def get_lecture(
    lecture_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    lecture = _owned_lecture(db, lecture_id, current_user.id)
    return LectureDetailOut(
        lecture=_lecture_to_out(lecture),
        quizzes=[_quiz_to_out(quiz) for quiz in lecture.quizzes],
    )


@router.get("/{lecture_id}/quizzes", response_model=List[LectureQuizOut])
def list_lecture_quizzes(
    lecture_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    lecture = _owned_lecture(db, lecture_id, current_user.id)
    return [_quiz_to_out(quiz) for quiz in lecture.quizzes]


@router.post("/{lecture_id}/quiz-attempts", response_model=QuizAttemptResponse, status_code=status.HTTP_201_CREATED)
def submit_quiz_attempt(
    lecture_id: str,
    payload: QuizAttemptRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    lecture = _owned_lecture(db, lecture_id, current_user.id)
    correct = 0
    for quiz in lecture.quizzes:
        submitted = str(payload.answers.get(quiz.id, "")).strip().casefold()
        expected = quiz.answer.strip().casefold()
        if submitted and submitted == expected:
            correct += 1

    total = len(lecture.quizzes)
    score = round((correct / total) * 100) if total else 0
    attempt = QuizAttempt(
        user_id=current_user.id,
        lecture_id=lecture.id,
        answers={key: str(value) for key, value in payload.answers.items()},
        score=score,
    )
    db.add(attempt)
    db.commit()
    db.refresh(attempt)

    return QuizAttemptResponse(attemptId=attempt.id, correct=correct, total=total, score=score)
