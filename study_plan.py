import datetime as dt
import re
from typing import Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from auth import get_current_user_optional
from database import StudyPlan, User, get_db
from gemini_api import GeminiNotConfiguredError, generate_json
from i18n import normalize_lang, t
from schemas import StudyPlanRequest, StudyPlanResponse


router = APIRouter()


def _fallback_plan(
    course: str, exam_date: dt.date, scope: str, start_date: dt.date, language: str
) -> List[Dict]:
    lang = normalize_lang(language)
    m = re.search(r"chapter\s*(\d+)\s*~\s*(\d+)", scope, re.I)
    items = []
    if m:
        a, b = int(m.group(1)), int(m.group(2))
        chapters = list(range(min(a, b), max(a, b) + 1))
        d = start_date
        for ch in chapters:
            if d > exam_date:
                break
            items.append({"date": d.isoformat(), "task": f"{course} - Chapter{ch} {t('study_review', lang)}"})
            d += dt.timedelta(days=1)
        if d <= exam_date:
            items.append(
                {"date": min(d, exam_date).isoformat(), "task": f"{course} - {t('study_final_review', lang)}"}
            )
        return items
    d = start_date
    while d <= exam_date:
        items.append({"date": d.isoformat(), "task": f"{course} - {t('study_scope', lang)}: {scope}"})
        d += dt.timedelta(days=1)
    return items[:14]


@router.post("/study-plan", response_model=StudyPlanResponse)
def create_plan(
    payload: StudyPlanRequest,
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user_optional),
):
    start_date = payload.start_date or dt.date.today()
    if start_date > payload.exam_date:
        start_date = payload.exam_date

    lang = normalize_lang(payload.language)
    system = (
        "你是学习助教。根据考试日期与考试范围，生成从 start_date 到 exam_date 的每日学习计划。"
        "输出严格 JSON，不要解释。"
    )
    user = (
        f"course: {payload.course}\n"
        f"start_date: {start_date.isoformat()}\n"
        f"exam_date: {payload.exam_date.isoformat()}\n"
        f"scope: {payload.scope}\n"
        f"output_language: {lang}\n\n"
        '输出 JSON 格式：{"plan":[{"date":"YYYY-MM-DD","task":"..."}]}。'
        "task 字段使用 output_language 语言输出。任务要包含复习安排（例如练习题/错题回顾/总复习）。"
    )

    try:
        data = generate_json(system=system, user=user)
        plan = data.get("plan") or []
        if not isinstance(plan, list) or not plan:
            raise ValueError("empty plan")
    except (GeminiNotConfiguredError, Exception):
        plan = _fallback_plan(payload.course, payload.exam_date, payload.scope, start_date, language=lang)

    record = StudyPlan(
        user_id=current_user.id if current_user else None,
        course=payload.course,
        exam_date=payload.exam_date.isoformat(),
        scope=payload.scope,
        result={"plan": plan},
    )
    db.add(record)
    db.commit()

    return StudyPlanResponse(
        course=payload.course,
        exam_date=payload.exam_date,
        scope=payload.scope,
        plan=[{"date": it["date"], "task": it["task"]} for it in plan],
    )

