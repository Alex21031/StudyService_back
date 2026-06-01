import json
import re
from typing import Any, Dict, List, Optional, Tuple

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from auth import get_current_user_optional
from database import ProblemSession, User, get_db
from gemini_api import GeminiNotConfiguredError, generate_json
from i18n import normalize_lang, t
from schemas import (
    ProblemAnswerRequest,
    ProblemSessionCreateResponse,
    ProblemSessionStateResponse,
    SolveProblemRequest,
    SolveProblemResponse,
)


router = APIRouter()


def _ensure_session_access(session: ProblemSession, current_user: Optional[User]) -> None:
    if session.user_id is None:
        return
    if current_user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    if current_user.id != session.user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")


def _steps_from_state(state: dict) -> List[Dict]:
    steps = state.get("steps") if isinstance(state, dict) else None
    return steps if isinstance(steps, list) else []


def _clean_problem_type(problem_type: str) -> str:
    pt = (problem_type or "").strip().lower()
    if pt in ("math", "coding", "theory"):
        return pt
    return "auto"


def _build_steps(problem: str, problem_type: str, language: str) -> Tuple[str, List[Dict]]:
    pt = _clean_problem_type(problem_type)
    lang = normalize_lang(language)
    system = (
        "你是严谨的老师。你的目标是引导学生自己完成解题。"
        "每一步都要：给出标题(title)、简短解释(explanation)、一个需要学生回答的问题(question)、以及一个提示(hint)。"
        "不要在任何一步直接给出最终答案（例如最后的数值解、最终代码实现、最终结论）。"
        "只输出 JSON，不要解释。"
    )
    user = (
        f"problem_type: {pt}\n"
        f"output_language: {lang}\n"
        f"problem:\n{problem}\n\n"
        '输出 JSON 格式：{"problem_type":"math|coding|theory","steps":[{"step":1,"title":"...","explanation":"...","question":"...","hint":"...","rubric":["要点1","要点2"]}]}。'
        "title/explanation/question/hint 使用 output_language 语言输出。步骤数量 3~7。rubric 用于判断学生回答是否基本正确。"
    )
    data = generate_json(system=system, user=user)
    inferred_type = (data.get("problem_type") or pt) if isinstance(data, dict) else pt
    inferred_type = _clean_problem_type(str(inferred_type))
    if inferred_type == "auto":
        inferred_type = "theory"
    steps = data.get("steps") if isinstance(data, dict) else None
    if not isinstance(steps, list) or not steps:
        raise ValueError("empty steps")
    normalized = []
    for i, raw in enumerate(steps[:7], start=1):
        if not isinstance(raw, dict):
            continue
        normalized.append(
            {
                "step": int(raw.get("step") or i),
                "title": str(raw.get("title") or f"Step {i}"),
                "explanation": str(raw.get("explanation") or ""),
                "question": str(raw.get("question") or t("keep_going", lang)),
                "hint": str(raw.get("hint") or ""),
                "rubric": raw.get("rubric") if isinstance(raw.get("rubric"), list) else [],
            }
        )
    if not normalized:
        raise ValueError("empty steps")
    return inferred_type, normalized


def _attempts_for_step(state: dict, step_index: int) -> int:
    attempts = state.get("attempts") if isinstance(state, dict) else None
    if not isinstance(attempts, dict):
        return 0
    return int(attempts.get(str(step_index), 0))


def _set_attempts_for_step(state: dict, step_index: int, value: int) -> None:
    if "attempts" not in state or not isinstance(state.get("attempts"), dict):
        state["attempts"] = {}
    state["attempts"][str(step_index)] = int(value)


def _evaluate_answer(
    problem: str,
    problem_type: str,
    language: str,
    step: dict,
    answer: str,
    attempt: int,
    history: list,
) -> Dict[str, Any]:
    lang = normalize_lang(language)
    system = (
        "你是助教。你只判断学生对当前步骤问题的回答是否基本正确，并给出一句反馈与一句提示。"
        "禁止直接给出最终答案/最终代码/最终结论。"
        "只输出 JSON，不要解释。"
    )
    rubric = step.get("rubric") if isinstance(step.get("rubric"), list) else []
    user = (
        f"problem_type: {problem_type}\n"
        f"output_language: {lang}\n"
        f"problem:\n{problem}\n\n"
        f"current_step_title: {step.get('title','')}\n"
        f"current_step_question: {step.get('question','')}\n"
        f"current_step_rubric: {rubric}\n"
        f"default_hint: {step.get('hint','')}\n"
        f"attempt: {attempt}\n"
        f"recent_history: {history[-3:]}\n\n"
        f"student_answer:\n{answer}\n\n"
        '输出 JSON：{"ok":true|false,"feedback":"...","hint":"..."}。'
        "feedback/hint 使用 output_language 语言输出。如果 attempt>=3，请给更具体的 hint，但仍不要给最终答案。"
    )
    data = generate_json(system=system, user=user)
    if not isinstance(data, dict):
        raise ValueError("bad eval")
    ok_raw = data.get("ok")
    ok = bool(ok_raw) if isinstance(ok_raw, bool) else str(ok_raw).lower() == "true"
    feedback = str(data.get("feedback") or "").strip()
    hint = str(data.get("hint") or step.get("hint") or "").strip()
    if not feedback:
        feedback = t("received", lang)
    return {"ok": ok, "feedback": feedback, "hint": hint}


@router.post("/solve-problem", response_model=SolveProblemResponse)
def solve(payload: SolveProblemRequest):
    try:
        _, steps = _build_steps(payload.problem, payload.problem_type, payload.language)
    except GeminiNotConfiguredError as e:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(e))
    except Exception:
        raise HTTPException(status_code=502, detail="Bad solve response")
    return SolveProblemResponse(steps=steps)


@router.post("/solve-problem/sessions", response_model=ProblemSessionCreateResponse)
def create_session(
    payload: SolveProblemRequest,
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user_optional),
):
    try:
        inferred_type, steps = _build_steps(payload.problem, payload.problem_type, payload.language)
    except GeminiNotConfiguredError as e:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(e))
    except Exception:
        raise HTTPException(status_code=502, detail="Bad solve response")

    state = {"steps": steps, "step_index": 0, "history": [], "attempts": {}, "problem_type": inferred_type}
    s = ProblemSession(
        user_id=current_user.id if current_user else None,
        problem=payload.problem,
        problem_type=inferred_type,
        language=payload.language,
        state=state,
    )
    db.add(s)
    db.commit()
    db.refresh(s)

    lang = normalize_lang(payload.language)
    prompt = steps[0].get("question") or steps[0].get("title") or t("continue", lang)
    return ProblemSessionCreateResponse(
        session_id=s.id,
        prompt=prompt,
        step_index=0,
        total_steps=len(steps),
        step_title=steps[0].get("title"),
    )


@router.get("/solve-problem/sessions/{session_id}", response_model=ProblemSessionStateResponse)
def get_session(
    session_id: str,
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user_optional),
):
    s = db.get(ProblemSession, session_id)
    if not s:
        raise HTTPException(status_code=404, detail="Not found")
    _ensure_session_access(s, current_user)
    steps = _steps_from_state(s.state)
    idx = int((s.state or {}).get("step_index") or 0)
    is_finished = idx >= len(steps)
    lang = normalize_lang(s.language)
    prompt = (
        t("done", lang)
        if is_finished
        else (steps[idx].get("question") or steps[idx].get("title") or t("continue", lang))
    )
    attempts = _attempts_for_step(s.state or {}, idx)
    return ProblemSessionStateResponse(
        session_id=s.id,
        prompt=prompt,
        step_index=min(idx, len(steps)),
        total_steps=len(steps),
        is_finished=is_finished,
        step_title=None if is_finished else steps[idx].get("title"),
        attempts=attempts,
    )


@router.post("/solve-problem/sessions/{session_id}/answer", response_model=ProblemSessionStateResponse)
def answer(
    session_id: str,
    payload: ProblemAnswerRequest,
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user_optional),
):
    s = db.get(ProblemSession, session_id)
    if not s:
        raise HTTPException(status_code=404, detail="Not found")
    _ensure_session_access(s, current_user)
    lang = normalize_lang(s.language)
    state = s.state or {}
    steps = _steps_from_state(state)
    idx = int(state.get("step_index") or 0)
    if idx >= len(steps):
        return ProblemSessionStateResponse(
            session_id=s.id,
            prompt=t("done", lang),
            step_index=len(steps),
            total_steps=len(steps),
            is_finished=True,
        )

    history = state.get("history") or []
    attempt = _attempts_for_step(state, idx) + 1
    _set_attempts_for_step(state, idx, attempt)

    try:
        evaluation = _evaluate_answer(
            problem=s.problem,
            problem_type=str(state.get("problem_type") or s.problem_type or "theory"),
            language=s.language,
            step=steps[idx],
            answer=payload.answer,
            attempt=attempt,
            history=history,
        )
    except GeminiNotConfiguredError as e:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(e))
    except Exception:
        raise HTTPException(status_code=502, detail="Bad evaluation response")

    history.append(
        {
            "step_index": idx,
            "step": idx + 1,
            "answer": payload.answer,
            "ok": evaluation.get("ok"),
            "feedback": evaluation.get("feedback"),
            "hint": evaluation.get("hint"),
            "attempt": attempt,
        }
    )

    ok = bool(evaluation.get("ok"))
    feedback = str(evaluation.get("feedback") or "").strip()
    hint = str(evaluation.get("hint") or "").strip()

    if ok:
        idx += 1
        state["step_index"] = idx
    state["history"] = history
    s.state = state
    db.add(s)
    db.commit()
    db.refresh(s)

    is_finished = idx >= len(steps)
    if is_finished:
        prompt = t("done", lang)
        step_title = None
    else:
        next_q = steps[idx].get("question") or steps[idx].get("title") or t("continue", lang)
        parts = []
        if feedback:
            parts.append(feedback)
        if not ok and hint:
            parts.append(hint)
        parts.append(next_q)
        prompt = "\n\n".join(parts)
        step_title = steps[idx].get("title")

    return ProblemSessionStateResponse(
        session_id=s.id,
        prompt=prompt,
        step_index=min(idx, len(steps)),
        total_steps=len(steps),
        is_finished=is_finished,
        ok=ok,
        feedback=feedback or None,
        hint=hint or None,
        step_title=step_title,
        attempts=_attempts_for_step(state, idx if not ok else idx - 1),
    )

