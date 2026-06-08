import datetime as dt
import json
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from typing import Iterable, List

from fastapi import APIRouter, BackgroundTasks, Depends, File, Form, HTTPException, Query, UploadFile, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload
from starlette.responses import StreamingResponse

from auth import get_current_user
from database import Lecture, LectureQuiz, QuizAttempt, SessionLocal, User, get_db
from gemini_api import GeminiNotConfiguredError
from lecture_service import (
    TARGET_QUIZ_COUNT,
    AudioTranscriptionError,
    _normalize_quizzes,
    _quizzes_multilingual_complete,
    cleanup_temporary_upload,
    generate_quiz_set,
    generate_multilingual_key_terms,
    generate_study_materials,
    generate_summary_translations,
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
    RegenerateLectureQuizzesRequest,
    TranscriptResponse,
)


router = APIRouter(prefix="/lectures", tags=["lectures"])
QUIZ_LANGUAGE_CODES = ("en", "ko", "ru", "zh")


def _now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def _lecture_summary_translations(lecture: Lecture) -> dict[str, str]:
    raw_translations = lecture.summary_translations or {}
    translations = {
        "en": "",
        "ko": "",
        "ru": "",
        "zh": "",
    }
    if isinstance(raw_translations, dict):
        for language_code in translations:
            value = raw_translations.get(language_code)
            if isinstance(value, str):
                translations[language_code] = value.strip()

    if not translations["en"] and lecture.summary_original:
        translations["en"] = lecture.summary_original.strip()
    if not translations["ru"] and lecture.summary_russian:
        translations["ru"] = lecture.summary_russian.strip()
    return {key: value for key, value in translations.items() if value}


def _lecture_to_out(lecture: Lecture) -> LectureOut:
    summary_translations = _lecture_summary_translations(lecture)
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
        summaryTranslations=summary_translations,
        keyTerms=lecture.key_terms or [],
        errorMessage=lecture.error_message,
        progressPercent=lecture.progress_percent,
        progressMessage=lecture.progress_message,
        progressCurrent=lecture.progress_current,
        progressTotal=lecture.progress_total,
        createdAt=lecture.created_at,
        updatedAt=lecture.updated_at,
    )


def _backfill_lecture_summary_translations(db: Session, lecture: Lecture) -> Lecture:
    summary_translations = _lecture_summary_translations(lecture)
    missing_languages = [code for code in ("en", "ko", "ru", "zh") if not summary_translations.get(code, "").strip()]
    if not missing_languages or not (lecture.transcript or "").strip():
        return lecture

    generated = generate_summary_translations(
        lecture.title,
        lecture.course_name,
        lecture.transcript or "",
        existing_translations=summary_translations,
    )
    lecture.summary_translations = generated
    lecture.summary_original = generated.get("en", lecture.summary_original or "")
    lecture.summary_russian = generated.get("ru", lecture.summary_russian or "")
    lecture.updated_at = _now()
    db.add(lecture)
    db.commit()
    db.refresh(lecture)
    return lecture


def _backfill_lecture_key_terms(db: Session, lecture: Lecture) -> Lecture:
    if not lecture.key_terms or not (lecture.transcript or "").strip():
        return lecture

    needs_backfill = False
    for item in lecture.key_terms:
        if not isinstance(item, dict):
            needs_backfill = True
            break
        explanations = item.get("explanations")
        if not isinstance(explanations, dict):
            needs_backfill = True
            break
        if any(not str(explanations.get(code, "")).strip() for code in ("en", "ko", "ru", "zh")):
            needs_backfill = True
            break

    if not needs_backfill:
        return lecture

    lecture.key_terms = generate_multilingual_key_terms(
        lecture.title,
        lecture.course_name,
        lecture.transcript or "",
        list(lecture.key_terms or []),
    )
    lecture.updated_at = _now()
    db.add(lecture)
    db.commit()
    db.refresh(lecture)
    return lecture


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
        skillTag=quiz.skill_tag,
        conceptRefs=list(quiz.concept_refs or []),
        reviewHint=quiz.review_hint,
        followUpPrompt=quiz.follow_up_prompt,
        localizedContent=_quiz_localized_content(quiz),
        createdAt=quiz.created_at,
    )


def _quiz_payload_from_record(quiz: LectureQuiz) -> dict:
    return {
        "type": quiz.type,
        "question": quiz.question,
        "options": list(quiz.options or []),
        "answer": quiz.answer,
        "explanation": quiz.explanation,
        "difficulty": quiz.difficulty,
        "skillTag": quiz.skill_tag or "",
        "conceptRefs": list(quiz.concept_refs or []),
        "reviewHint": quiz.review_hint or "",
        "followUpPrompt": quiz.follow_up_prompt or "",
        "localizedContent": _quiz_localized_content(quiz),
    }


def _preferred_quiz_language(language: str | None) -> str:
    normalized = str(language or "").strip().lower()
    if normalized in QUIZ_LANGUAGE_CODES:
        return normalized
    return "en"


def _quiz_localized_content(quiz: LectureQuiz) -> dict[str, dict]:
    raw_content = quiz.localized_content or {}
    localized_content: dict[str, dict] = {}
    if not isinstance(raw_content, dict):
        raw_content = {}

    for language_code in QUIZ_LANGUAGE_CODES:
        raw_entry = raw_content.get(language_code)
        if not isinstance(raw_entry, dict):
            raw_entry = {}
        localized_content[language_code] = {
            "question": str(raw_entry.get("question") or "").strip(),
            "options": [
                str(option).strip()
                for option in list(raw_entry.get("options") or [])
                if str(option).strip()
            ],
            "answer": str(raw_entry.get("answer") or "").strip(),
            "explanation": str(raw_entry.get("explanation") or "").strip(),
            "reviewHint": str(raw_entry.get("reviewHint") or "").strip(),
            "followUpPrompt": str(raw_entry.get("followUpPrompt") or "").strip(),
            "skillTag": str(raw_entry.get("skillTag") or "").strip(),
            "conceptRefs": [
                str(value).strip()
                for value in list(raw_entry.get("conceptRefs") or [])
                if str(value).strip()
            ],
        }
    return localized_content


def _quiz_localizations_complete(quiz: LectureQuiz) -> bool:
    normalized_payload = _normalize_quizzes([_quiz_payload_from_record(quiz)])
    return _quizzes_multilingual_complete(normalized_payload)


def _quiz_localized_view(quiz: LectureQuiz, language: str) -> dict:
    preferred_language = _preferred_quiz_language(language)
    localized_content = _quiz_localized_content(quiz)
    fallback_entry = localized_content.get("en") or {}
    preferred_entry = localized_content.get(preferred_language) or {}

    def choose_text(field: str, fallback: str = "") -> str:
        return (
            str(preferred_entry.get(field) or "").strip()
            or str(fallback_entry.get(field) or "").strip()
            or fallback
        )

    def choose_list(field: str, fallback: list[str]) -> list[str]:
        preferred_values = [
            str(value).strip()
            for value in list(preferred_entry.get(field) or [])
            if str(value).strip()
        ]
        if preferred_values:
            return preferred_values
        fallback_values = [
            str(value).strip()
            for value in list(fallback_entry.get(field) or [])
            if str(value).strip()
        ]
        if fallback_values:
            return fallback_values
        return fallback

    return {
        "question": choose_text("question", quiz.question),
        "options": choose_list(
            "options",
            [str(option).strip() for option in list(quiz.options or []) if str(option).strip()],
        ),
        "answer": choose_text("answer", quiz.answer),
        "explanation": choose_text("explanation", quiz.explanation),
        "reviewHint": choose_text("reviewHint", quiz.review_hint or ""),
        "followUpPrompt": choose_text("followUpPrompt", quiz.follow_up_prompt or ""),
        "skillTag": choose_text("skillTag", quiz.skill_tag or ""),
        "conceptRefs": choose_list(
            "conceptRefs",
            [str(value).strip() for value in list(quiz.concept_refs or []) if str(value).strip()],
        ),
    }


def _quiz_metadata_complete(quiz: LectureQuiz) -> bool:
    return bool(
        (quiz.skill_tag or "").strip()
        and list(quiz.concept_refs or [])
        and (quiz.review_hint or "").strip()
    )


def _replace_lecture_quizzes(db: Session, lecture: Lecture, quiz_payloads: list[dict]) -> None:
    lecture.quizzes.clear()
    db.flush()

    for quiz_payload in quiz_payloads:
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
            skill_tag=str(quiz_payload.get("skillTag") or "").strip() or None,
            concept_refs=[
                str(value).strip()
                for value in list(quiz_payload.get("conceptRefs") or [])
                if str(value).strip()
            ],
            review_hint=str(quiz_payload.get("reviewHint") or "").strip() or None,
            follow_up_prompt=str(quiz_payload.get("followUpPrompt") or "").strip() or None,
            localized_content=dict(quiz_payload.get("localizedContent") or {}),
        )
        if quiz.question and quiz.answer:
            db.add(quiz)

    lecture.updated_at = _now()
    db.commit()
    db.refresh(lecture)


def _backfill_lecture_quizzes(db: Session, lecture: Lecture) -> Lecture:
    if not (lecture.transcript or "").strip():
        return lecture
    if lecture.quizzes and len(lecture.quizzes) == TARGET_QUIZ_COUNT and all(
        _quiz_metadata_complete(quiz) and _quiz_localizations_complete(quiz)
        for quiz in lecture.quizzes
    ):
        return lecture

    refreshed_quizzes = generate_quiz_set(
        lecture.title,
        lecture.course_name,
        lecture.transcript or "",
        existing_quizzes=[_quiz_payload_from_record(quiz) for quiz in lecture.quizzes],
        question_count=TARGET_QUIZ_COUNT,
        force_new=len(lecture.quizzes) != TARGET_QUIZ_COUNT,
    )
    if not refreshed_quizzes:
        return lecture
    _replace_lecture_quizzes(db, lecture, refreshed_quizzes)
    return lecture


def _normalize_answer_text(value: str) -> str:
    return " ".join(str(value).strip().casefold().split())


def _answer_matches(quiz: LectureQuiz, submitted_answer: str) -> bool:
    submitted = _normalize_answer_text(submitted_answer)
    if not submitted:
        return False

    expected_answers = {_normalize_answer_text(quiz.answer)}
    localized_content = _quiz_localized_content(quiz)
    for entry in localized_content.values():
        localized_answer = _normalize_answer_text(str(entry.get("answer") or ""))
        if localized_answer:
            expected_answers.add(localized_answer)
    return submitted in expected_answers


def _recommended_actions_for_attempt(
    *,
    weak_concepts: list[dict],
    question_results: list[dict],
    mode: str,
    total: int,
    correct: int,
    language: str,
) -> list[str]:
    preferred_language = _preferred_quiz_language(language)

    def template(key: str, **values: str) -> str:
        messages = {
            "review_with_hint": {
                "en": "Review {label}: {hint}",
                "ko": "{label} 개념을 다시 보세요: {hint}",
                "ru": "Повторите тему {label}: {hint}",
                "zh": "复习 {label}：{hint}",
            },
            "review_without_hint": {
                "en": "Review {label} in the study notes and keyword cards.",
                "ko": "학습 노트와 키워드 카드에서 {label} 개념을 다시 확인하세요.",
                "ru": "Повторите тему {label} в конспекте и карточках ключевых понятий.",
                "zh": "请在学习笔记和关键词卡片中复习 {label}。",
            },
            "perfect_score": {
                "en": "You answered every question correctly. Switch to test mode or upload another lecture for a harder review set.",
                "ko": "모든 문제를 맞혔습니다. 테스트 모드로 바꾸거나 다른 강의를 업로드해서 더 어려운 복습 세트를 풀어보세요.",
                "ru": "Вы ответили правильно на все вопросы. Переключитесь в режим теста или загрузите другую лекцию для более сложного повторения.",
                "zh": "你答对了所有题目。可以切换到测试模式，或上传另一节课进行更高难度的复习。",
            },
            "practice_retry": {
                "en": "Use the retry action to focus only on missed questions, then review the linked weak concepts before another full attempt.",
                "ko": "틀린 문제만 다시 풀어본 뒤, 연결된 약한 개념을 복습하고 전체 시도를 다시 진행하세요.",
                "ru": "Сначала повторно решите только ошибочные вопросы, затем повторите слабые темы перед новой полной попыткой.",
                "zh": "先重新练习答错的题目，再复习对应的薄弱概念，然后进行下一次完整尝试。",
            },
            "test_retry": {
                "en": "Open the lecture notes again, revisit the weak concepts, and retry in practice mode for guided feedback.",
                "ko": "강의 노트를 다시 열고 약한 개념을 복습한 뒤, 연습 모드에서 다시 풀어보세요.",
                "ru": "Снова откройте конспект лекции, повторите слабые темы и затем попробуйте режим практики с подсказками.",
                "zh": "重新打开课程笔记，复习薄弱概念，然后在练习模式下再次作答以获得引导反馈。",
            },
        }
        return messages[key][preferred_language].format(**values)

    actions: list[str] = []

    for concept in weak_concepts[:3]:
        hint = str(concept.get("reviewHint") or "").strip()
        if hint:
            actions.append(template("review_with_hint", label=concept["label"], hint=hint))
        else:
            actions.append(template("review_without_hint", label=concept["label"]))

    for result in question_results:
        if result["isCorrect"]:
            continue
        follow_up = str(result.get("followUpPrompt") or "").strip()
        if follow_up and follow_up not in actions:
            actions.append(follow_up)
        if len(actions) >= 5:
            break

    if total and correct == total:
        actions.append(template("perfect_score"))
    elif mode == "practice":
        actions.append(template("practice_retry"))
    else:
        actions.append(template("test_retry"))

    deduped_actions: list[str] = []
    for action in actions:
        if action and action not in deduped_actions:
            deduped_actions.append(action)
    return deduped_actions[:5]


def _owned_lecture(db: Session, lecture_id: str, user_id: int) -> Lecture:
    lecture = db.scalar(
        select(Lecture)
        .where(Lecture.id == lecture_id, Lecture.user_id == user_id)
        .options(selectinload(Lecture.quizzes))
    )
    if not lecture:
        raise HTTPException(status_code=404, detail="Lecture not found")
    return lecture


def _set_lecture_status(
    db: Session,
    lecture: Lecture,
    *,
    status_value: str,
    error_message: str | None = None,
    progress_percent: int | None = None,
    progress_message: str | None = None,
    progress_current: int | None = None,
    progress_total: int | None = None,
) -> None:
    lecture.status = status_value
    lecture.error_message = error_message
    if progress_percent is not None:
        lecture.progress_percent = max(0, min(100, progress_percent))
    lecture.progress_message = progress_message
    lecture.progress_current = progress_current
    lecture.progress_total = progress_total
    lecture.updated_at = _now()
    db.add(lecture)
    db.commit()
    db.refresh(lecture)


def _process_lecture_job(lecture_id: str) -> None:
    db = SessionLocal()
    try:
        lecture = db.scalar(
            select(Lecture)
            .where(Lecture.id == lecture_id)
            .options(selectinload(Lecture.quizzes))
        )
        if not lecture:
            return

        _set_lecture_status(
            db,
            lecture,
            status_value="transcribing",
            error_message=None,
            progress_percent=15,
            progress_message="Normalizing the single recording for hosted transcription.",
        )

        _set_lecture_status(
            db,
            lecture,
            status_value="transcribing",
            error_message=None,
            progress_percent=45,
            progress_message="Waiting for the hosted transcription result.",
        )

        transcript = transcribe_audio(resolve_audio_path(lecture.audio_path))
        lecture.transcript = transcript
        _set_lecture_status(
            db,
            lecture,
            status_value="summarizing",
            progress_percent=80,
            progress_message="Generating summaries and key terms.",
        )

        materials = generate_study_materials(lecture.title, lecture.course_name, transcript)
        lecture.summary_original = str(materials.get("summaryOriginal") or "")
        lecture.summary_russian = str(materials.get("summaryRussian") or "")
        lecture.summary_translations = dict(materials.get("summaryTranslations") or {})
        lecture.key_terms = list(materials.get("keyTerms") or [])
        _set_lecture_status(
            db,
            lecture,
            status_value="generating_quiz",
            progress_percent=92,
            progress_message="Generating a 10-question quiz set.",
        )

        lecture = _owned_lecture(db, lecture.id, lecture.user_id)
        _replace_lecture_quizzes(db, lecture, list(materials.get("quizzes") or []))
        lecture = _owned_lecture(db, lecture.id, lecture.user_id)
        _set_lecture_status(
            db,
            lecture,
            status_value="ready",
            progress_percent=100,
            progress_message="Study materials are ready.",
        )
    except AudioTranscriptionError as error:
        lecture = db.scalar(select(Lecture).where(Lecture.id == lecture_id))
        if lecture:
            _set_lecture_status(
                db,
                lecture,
                status_value="failed",
                error_message=str(error),
                progress_message="Processing failed before completion.",
            )
    except GeminiNotConfiguredError as error:
        lecture = db.scalar(select(Lecture).where(Lecture.id == lecture_id))
        if lecture:
            _set_lecture_status(
                db,
                lecture,
                status_value="failed",
                error_message=str(error),
                progress_message="Processing failed before completion.",
            )
    except Exception as error:
        lecture = db.scalar(select(Lecture).where(Lecture.id == lecture_id))
        if lecture:
            _set_lecture_status(
                db,
                lecture,
                status_value="failed",
                error_message=str(error),
                progress_message="Processing failed before completion.",
            )
    finally:
        db.close()


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
    except AudioTranscriptionError as error:
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
    except AudioTranscriptionError as error:
        raise HTTPException(status_code=error.status, detail=str(error)) from error
    finally:
        cleanup_temporary_upload(temp_audio_path)


@router.post("/process-audio", response_model=ProcessLectureResponse, status_code=status.HTTP_202_ACCEPTED)
def process_audio_route(
    background_tasks: BackgroundTasks,
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
        summary_translations={},
        key_terms=[],
        progress_percent=0,
        progress_message="Upload received. Waiting to start processing.",
        updated_at=_now(),
    )
    db.add(lecture)
    db.commit()
    db.refresh(lecture)

    _set_lecture_status(
        db,
        lecture,
        status_value="transcribing",
        error_message=None,
        progress_percent=5,
        progress_message="Upload saved. Preparing the single recording for hosted transcription.",
    )
    background_tasks.add_task(_process_lecture_job, lecture.id)

    return ProcessLectureResponse(
        lecture=_lecture_to_out(lecture),
        quizzes=[],
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
    try:
        lecture = _backfill_lecture_summary_translations(db, lecture)
        lecture = _backfill_lecture_key_terms(db, lecture)
        lecture = _backfill_lecture_quizzes(db, lecture)
    except GeminiNotConfiguredError:
        pass
    except Exception:
        pass
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
    try:
        lecture = _backfill_lecture_quizzes(db, lecture)
    except GeminiNotConfiguredError:
        pass
    except Exception:
        pass
    return [_quiz_to_out(quiz) for quiz in lecture.quizzes]


@router.post("/quiz-sets/regenerate", response_model=List[LectureQuizOut])
def regenerate_lecture_quizzes(
    payload: RegenerateLectureQuizzesRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    lecture_ids = [lecture_id.strip() for lecture_id in payload.lecture_ids if lecture_id.strip()]
    if not lecture_ids:
        raise HTTPException(status_code=400, detail="Choose at least one lecture first.")

    lecture_specs: list[dict] = []
    for lecture_id in lecture_ids:
        lecture = _owned_lecture(db, lecture_id, current_user.id)
        transcript = (lecture.transcript or "").strip()
        if not transcript:
            raise HTTPException(
                status_code=409,
                detail=f"Lecture '{lecture.title}' does not have a transcript yet.",
            )
        lecture_specs.append(
            {
                "id": lecture.id,
                "user_id": lecture.user_id,
                "title": lecture.title,
                "course_name": lecture.course_name,
                "transcript": transcript,
            }
        )

    def build_quizzes(spec: dict) -> tuple[str, list[dict]]:
        return spec["id"], generate_quiz_set(
            spec["title"],
            spec["course_name"],
            spec["transcript"],
            question_count=payload.question_count,
            force_new=True,
        )

    if len(lecture_specs) == 1:
        quiz_results = [build_quizzes(lecture_specs[0])]
    else:
        max_workers = min(4, len(lecture_specs))
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            quiz_results = list(executor.map(build_quizzes, lecture_specs))

    quiz_payload_by_lecture = {lecture_id: payloads for lecture_id, payloads in quiz_results}

    refreshed_quizzes: list[LectureQuizOut] = []
    for spec in lecture_specs:
        lecture = _owned_lecture(db, spec["id"], current_user.id)
        quiz_payloads = quiz_payload_by_lecture.get(spec["id"]) or []
        _replace_lecture_quizzes(db, lecture, quiz_payloads)
        lecture = _owned_lecture(db, lecture.id, lecture.user_id)
        refreshed_quizzes.extend(_quiz_to_out(quiz) for quiz in lecture.quizzes)
    return refreshed_quizzes


@router.post("/{lecture_id}/quiz-attempts", response_model=QuizAttemptResponse, status_code=status.HTTP_201_CREATED)
def submit_quiz_attempt(
    lecture_id: str,
    payload: QuizAttemptRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    lecture = _owned_lecture(db, lecture_id, current_user.id)
    requested_language = _preferred_quiz_language(payload.language)
    try:
        lecture = _backfill_lecture_quizzes(db, lecture)
    except GeminiNotConfiguredError:
        pass
    except Exception:
        pass

    requested_quiz_ids = {
        quiz_id.strip() for quiz_id in payload.quiz_ids if quiz_id.strip()
    }
    quizzes_to_grade = [
        quiz for quiz in lecture.quizzes if not requested_quiz_ids or quiz.id in requested_quiz_ids
    ]
    if requested_quiz_ids and not quizzes_to_grade:
        raise HTTPException(status_code=404, detail="The selected quiz questions were not found.")

    correct = 0
    question_results: list[dict] = []
    weak_concept_counts: dict[str, int] = defaultdict(int)
    weak_concept_hints: dict[str, str] = {}

    for quiz in quizzes_to_grade:
        localized_quiz = _quiz_localized_view(quiz, requested_language)
        submitted_answer = str(payload.answers.get(quiz.id, "")).strip()
        is_correct = _answer_matches(quiz, submitted_answer)
        if is_correct:
            correct += 1
        else:
            concept_labels = [
                str(value).strip()
                for value in list(localized_quiz.get("conceptRefs") or [])
                if str(value).strip()
            ]
            if not concept_labels and str(localized_quiz.get("skillTag") or "").strip():
                concept_labels = [str(localized_quiz.get("skillTag") or "").strip()]
            if not concept_labels:
                concept_labels = {
                    "en": "General review",
                    "ko": "전체 복습",
                    "ru": "Общее повторение",
                    "zh": "综合复习",
                }[requested_language]
            for label in concept_labels:
                weak_concept_counts[label] += 1
                localized_hint = str(localized_quiz.get("reviewHint") or "").strip()
                if localized_hint and label not in weak_concept_hints:
                    weak_concept_hints[label] = localized_hint

        question_results.append(
            {
                "quizId": quiz.id,
                "question": str(localized_quiz.get("question") or quiz.question),
                "submittedAnswer": submitted_answer,
                "correctAnswer": str(localized_quiz.get("answer") or quiz.answer),
                "isCorrect": is_correct,
                "explanation": str(localized_quiz.get("explanation") or quiz.explanation),
                "reviewHint": str(localized_quiz.get("reviewHint") or "") or None,
                "skillTag": str(localized_quiz.get("skillTag") or "") or None,
                "conceptRefs": [
                    str(value).strip()
                    for value in list(localized_quiz.get("conceptRefs") or [])
                    if str(value).strip()
                ],
                "followUpPrompt": str(localized_quiz.get("followUpPrompt") or "") or None,
            }
        )

    total = len(quizzes_to_grade)
    score = round((correct / total) * 100) if total else 0
    weak_concepts = [
        {
            "label": label,
            "misses": misses,
            "reviewHint": weak_concept_hints.get(label),
        }
        for label, misses in sorted(
            weak_concept_counts.items(),
            key=lambda item: (-item[1], item[0].casefold()),
        )
    ]
    recommended_actions = _recommended_actions_for_attempt(
        weak_concepts=weak_concepts,
        question_results=question_results,
        mode=payload.mode,
        total=total,
        correct=correct,
        language=requested_language,
    )
    feedback_payload = {
        "questionResults": question_results,
        "weakConcepts": weak_concepts,
        "recommendedActions": recommended_actions,
    }
    attempt = QuizAttempt(
        user_id=current_user.id,
        lecture_id=lecture.id,
        answers={key: str(value) for key, value in payload.answers.items()},
        score=score,
        mode=payload.mode,
        feedback=feedback_payload,
    )
    db.add(attempt)
    db.commit()
    db.refresh(attempt)

    return QuizAttemptResponse(
        attemptId=attempt.id,
        correct=correct,
        total=total,
        score=score,
        mode=payload.mode,
        language=requested_language,
        questionResults=question_results,
        weakConcepts=weak_concepts,
        recommendedActions=recommended_actions,
    )
