import datetime as dt
import math
import re
from typing import Dict, List, Optional

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from auth import get_current_user_optional
from database import Lecture, QuizAttempt, StudyPlan, User, get_db
from gemini_api import GeminiNotConfiguredError, generate_json
from schemas import StudyPlanRequest, StudyPlanResponse


router = APIRouter()


_PLANNER_COPY: Dict[str, Dict[str, str]] = {
    "en": {
        "overview": "You have {days} days until the exam. Study {sessions} focused sessions of about {minutes} minutes and leave the final stretch for review and recall.",
        "phase_foundation": "Foundation",
        "phase_reinforce": "Reinforce",
        "phase_final": "Final recall",
        "study_title": "Study block {index}",
        "study_task": "Cover {focus}. Capture the core ideas, examples, and one short recall question for each topic.",
        "study_review": "Review the previous block for 10 minutes and check whether you can explain it without notes.",
        "study_mission": "Lock in the structure of {focus} before moving on.",
        "study_output": "Leave this block with a 3-line summary and one self-test question for {focus}.",
        "study_why": "This lays the foundation for later quiz practice and final recall.",
        "consolidation_title": "Consolidation review",
        "consolidation_task": "Reconnect the major ideas from {focus}. Turn weak spots into flashcards or short written summaries.",
        "consolidation_review": "Revisit every topic completed so far and mark anything that still feels unstable.",
        "consolidation_mission": "Turn partial understanding of {focus} into recall that feels stable.",
        "consolidation_output": "Finish with a short error log or flashcard set for {focus}.",
        "consolidation_why": "Mid-plan reinforcement prevents the early material from fading before the exam.",
        "final_title": "Final rehearsal",
        "final_task": "Run a timed recap of {focus}, answer likely quiz questions, and finish with a confidence check.",
        "final_review": "Do not start brand-new material. Focus on retrieval, correction, and rest before the exam.",
        "final_mission": "Prove that you can retrieve {focus} under exam pressure.",
        "final_output": "Finish with a one-page recall sheet and a final confidence rating.",
        "final_why": "The last stretch should feel like exam rehearsal, not new learning.",
        "checkpoint_start": "By the first third of the plan, finish the early foundation topics and confirm the core vocabulary.",
        "checkpoint_middle": "Around the midpoint, switch from only covering material to mixed review and recall practice.",
        "checkpoint_end": "In the last stretch, focus on weak areas, quick self-tests, and a final confidence pass.",
        "boost": "Focus boost: {label} has been a recent weak area, so this block gives it extra attention.",
        "personalization": "This plan is tuned to your recent quiz history. Watch for extra review blocks around {labels}.",
        "all_scope": "the full exam scope",
    },
    "ko": {
        "overview": "시험까지 {days}일 남았습니다. 약 {minutes}분짜리 집중 세션 {sessions}회로 핵심 범위를 끝내고, 마지막 구간은 복습과 회상 연습에 남겨두세요.",
        "phase_foundation": "기초 구축",
        "phase_reinforce": "강화 복습",
        "phase_final": "최종 회상",
        "study_title": "학습 블록 {index}",
        "study_task": "{focus} 범위를 공부하고 핵심 개념, 예시, 그리고 직접 떠올려 볼 질문 1개씩을 정리하세요.",
        "study_review": "이전 블록을 10분 정도 다시 보고, 노트 없이 설명할 수 있는지 점검하세요.",
        "study_mission": "{focus}의 구조를 다음 단계로 넘어가기 전에 확실히 잡으세요.",
        "study_output": "{focus}에 대해 3줄 요약과 셀프 테스트 질문 1개를 남기세요.",
        "study_why": "이 구간은 이후 퀴즈와 최종 회상을 위한 기반을 만듭니다.",
        "consolidation_title": "정리 복습",
        "consolidation_task": "{focus}의 주요 아이디어를 다시 연결하고, 약한 부분은 플래시카드나 짧은 요약으로 바꾸세요.",
        "consolidation_review": "지금까지 끝낸 범위를 모두 다시 보면서 아직 불안한 주제를 표시하세요.",
        "consolidation_mission": "{focus}를 애매한 이해에서 안정적인 회상 단계로 끌어올리세요.",
        "consolidation_output": "{focus}에 대한 오답 메모나 플래시카드 묶음을 완성하세요.",
        "consolidation_why": "중간 강화 복습이 초반에 배운 내용이 시험 전에 흐려지는 것을 막아줍니다.",
        "final_title": "최종 리허설",
        "final_task": "{focus}를 시간 제한을 두고 다시 떠올리고, 나올 법한 문제를 스스로 풀어본 뒤 마지막 점검을 하세요.",
        "final_review": "새 범위를 시작하지 말고, 회상 연습과 오답 보완, 휴식에 집중하세요.",
        "final_mission": "시험 압박이 있는 상태에서도 {focus}를 떠올릴 수 있는지 확인하세요.",
        "final_output": "한 장짜리 회상 노트와 최종 자신감 점수를 남기세요.",
        "final_why": "마지막 구간은 새로운 학습보다 시험 리허설처럼 느껴져야 합니다.",
        "checkpoint_start": "초반 3분의 1 안에 기초 범위를 끝내고 핵심 용어를 확실히 잡으세요.",
        "checkpoint_middle": "중반부터는 진도만 나가기보다 섞어서 복습하고 스스로 설명하는 연습을 시작하세요.",
        "checkpoint_end": "마지막 구간은 약한 부분 보완, 짧은 셀프 테스트, 최종 정리에 집중하세요.",
        "boost": "집중 보강: 최근 퀴즈에서 {label} 개념이 약하게 나타나 이 블록에서 더 비중 있게 다룹니다.",
        "personalization": "이 계획은 최근 퀴즈 기록을 반영했습니다. {labels} 주변 복습 블록을 특히 신경 써보세요.",
        "all_scope": "전체 시험 범위",
    },
    "ru": {
        "overview": "До экзамена осталось {days} дней. Запланируйте {sessions} сфокусированных занятий примерно по {minutes} минут и оставьте финальный этап на повторение и активное воспроизведение.",
        "phase_foundation": "База",
        "phase_reinforce": "Закрепление",
        "phase_final": "Финальное воспроизведение",
        "study_title": "Учебный блок {index}",
        "study_task": "Разберите {focus}. Зафиксируйте ключевые идеи, примеры и по одному вопросу для активного воспроизведения по каждой теме.",
        "study_review": "Быстро повторите предыдущий блок в течение 10 минут и проверьте, можете ли объяснить его без конспекта.",
        "study_mission": "Зафиксируйте структуру {focus}, прежде чем двигаться дальше.",
        "study_output": "Оставьте после блока краткое резюме на 3 строки и один вопрос для самопроверки по {focus}.",
        "study_why": "Этот этап создает основу для последующих квизов и финального воспроизведения.",
        "consolidation_title": "Закрепляющее повторение",
        "consolidation_task": "Свяжите между собой основные идеи из {focus}. Слабые места превратите в карточки или короткие письменные конспекты.",
        "consolidation_review": "Снова пройдитесь по уже изученным темам и отметьте то, что пока остается неустойчивым.",
        "consolidation_mission": "Переведите понимание {focus} из частичного в устойчивое воспроизведение.",
        "consolidation_output": "Завершите блок журналом ошибок или набором карточек по {focus}.",
        "consolidation_why": "Повторение в середине плана не дает раннему материалу исчезнуть к экзамену.",
        "final_title": "Финальная репетиция",
        "final_task": "Сделайте ограниченный по времени повтор {focus}, ответьте на вероятные вопросы и завершите занятием на уверенность.",
        "final_review": "Не начинайте новый материал. Сосредоточьтесь на воспроизведении, исправлении ошибок и отдыхе перед экзаменом.",
        "final_mission": "Докажите себе, что можете воспроизвести {focus} под экзаменационным давлением.",
        "final_output": "Сделайте одностраничный лист воспроизведения и поставьте итоговую оценку уверенности.",
        "final_why": "Финальный этап должен ощущаться как репетиция экзамена, а не как новое обучение.",
        "checkpoint_start": "К первой трети плана завершите базовые темы и закрепите ключевую терминологию.",
        "checkpoint_middle": "Около середины переходите от простого прохождения тем к смешанному повторению и практике воспроизведения.",
        "checkpoint_end": "На финальном этапе сосредоточьтесь на слабых местах, коротких самопроверках и последнем проходе по материалу.",
        "boost": "Усиление фокуса: {label} был слабым местом в недавних квизах, поэтому этот блок уделяет ему больше внимания.",
        "personalization": "Этот план учитывает ваши недавние квизы. Обратите особое внимание на блоки вокруг тем {labels}.",
        "all_scope": "весь экзаменационный объем",
    },
    "zh": {
        "overview": "距离考试还有 {days} 天。安排 {sessions} 次、每次约 {minutes} 分钟的专注学习，并把最后阶段留给复习与主动回忆。",
        "phase_foundation": "基础阶段",
        "phase_reinforce": "强化阶段",
        "phase_final": "最终回忆",
        "study_title": "学习模块 {index}",
        "study_task": "完成 {focus}。整理核心概念、例子，并为每个主题写出一个可自测的回忆问题。",
        "study_review": "先用 10 分钟回顾上一模块，并检查自己能否不看笔记讲清楚。",
        "study_mission": "在继续之前，先把 {focus} 的整体结构稳稳建立起来。",
        "study_output": "这一块结束后，留下 3 句总结和 1 个关于 {focus} 的自测问题。",
        "study_why": "这一阶段是在为后续测验和最终回忆打基础。",
        "consolidation_title": "综合复习",
        "consolidation_task": "重新串联 {focus} 的主要思路，把薄弱点整理成抽认卡或简短总结。",
        "consolidation_review": "回看目前完成的全部内容，标出仍然不稳的主题。",
        "consolidation_mission": "把对 {focus} 的部分理解提升为稳定回忆。",
        "consolidation_output": "完成一组关于 {focus} 的错题记录或抽认卡。",
        "consolidation_why": "中段强化可以避免前面学过的内容在考试前逐渐模糊。",
        "final_title": "最终演练",
        "final_task": "限时回顾 {focus}，练习可能出现的题目，并做最后一次信心检查。",
        "final_review": "不要再开始新的内容，把精力放在提取记忆、纠错和考前休息上。",
        "final_mission": "确认自己在考试压力下也能回忆出 {focus}。",
        "final_output": "完成一页回忆提纲，并给自己一个最后的信心评分。",
        "final_why": "最后阶段应该像考试演练，而不是继续学新内容。",
        "checkpoint_start": "在计划前 1/3 内完成基础内容，并确认核心术语已经掌握。",
        "checkpoint_middle": "到中段时，不要只继续赶进度，要开始混合复习和主动回忆练习。",
        "checkpoint_end": "最后阶段重点放在薄弱点、快速自测和考前总复习。",
        "boost": "重点强化：{label} 是你最近测验中的薄弱点，所以这个模块会额外照顾它。",
        "personalization": "这份计划参考了你最近的测验记录。请特别关注围绕 {labels} 的复习模块。",
        "all_scope": "全部考试范围",
    },
}


def _normalize_lang(language: str) -> str:
    value = (language or "").strip().lower()
    if value.startswith("ko"):
        return "ko"
    if value.startswith("ru"):
        return "ru"
    if value.startswith("zh"):
        return "zh"
    return "en"


def _copy(language: str) -> Dict[str, str]:
    return _PLANNER_COPY.get(_normalize_lang(language), _PLANNER_COPY["en"])


def _selected_lectures(
    db: Session,
    current_user: Optional[User],
    lecture_ids: List[str],
) -> List[Lecture]:
    cleaned_ids = [lecture_id.strip() for lecture_id in lecture_ids if lecture_id.strip()]
    if current_user is None or not cleaned_ids:
        return []
    lectures = (
        db.query(Lecture)
        .filter(Lecture.user_id == current_user.id, Lecture.id.in_(cleaned_ids))
        .order_by(Lecture.updated_at.desc())
        .all()
    )
    lecture_map = {lecture.id: lecture for lecture in lectures}
    return [lecture_map[lecture_id] for lecture_id in cleaned_ids if lecture_id in lecture_map]


def _lecture_summary_text(lecture: Lecture, language: str) -> str:
    translations = lecture.summary_translations or {}
    if isinstance(translations, dict):
        localized = str(translations.get(language) or "").strip()
        if localized:
            return localized
        english = str(translations.get("en") or "").strip()
        if english:
            return english
    for candidate in [lecture.summary_original, lecture.summary_russian, lecture.transcript]:
        value = str(candidate or "").strip()
        if value:
            return value
    return ""


def _lecture_topics(lectures: List[Lecture]) -> List[str]:
    topics: List[str] = []
    for lecture in lectures:
        title = str(lecture.title or "").strip()
        if title:
            topics.append(title)
        for item in list(lecture.key_terms or [])[:4]:
            if not isinstance(item, dict):
                continue
            term = str(item.get("term") or "").strip()
            if term:
                topics.append(term)
    deduped: List[str] = []
    for topic in topics:
        if topic not in deduped:
            deduped.append(topic)
    return deduped


def _derive_course_and_scope(
    requested_course: str,
    requested_scope: str,
    lectures: List[Lecture],
    language: str,
) -> tuple[str, str]:
    course = requested_course.strip()
    scope = requested_scope.strip()
    if not lectures:
        return course, scope

    course_names = []
    for lecture in lectures:
        name = str(lecture.course_name or "").strip()
        if name and name not in course_names:
            course_names.append(name)
    lecture_titles = [str(lecture.title or "").strip() for lecture in lectures if str(lecture.title or "").strip()]
    topics = _lecture_topics(lectures)
    copy = _copy(language)

    if not course:
        if len(course_names) == 1:
            course = course_names[0]
        elif course_names:
            course = " / ".join(course_names[:3])
        else:
            course = "Lecture-based study plan"

    if not scope:
        focus_titles = ", ".join(lecture_titles[:4])
        focus_topics = ", ".join(topics[:6])
        pieces = [piece for piece in [focus_titles, focus_topics] if piece]
        scope = pieces[0] if len(pieces) == 1 else f"{pieces[0]} | {pieces[1]}" if pieces else copy["all_scope"]

    return course, scope


def _phase_key(*, index: int, total: int) -> str:
    if total <= 2:
        return "final" if index == total - 1 else "foundation"
    if index >= max(total - 2, 1):
        return "final"
    if index >= max(math.ceil(total * 0.55), 1):
        return "reinforce"
    return "foundation"


def _recent_weak_concepts(
    db: Session,
    current_user: Optional[User],
    lecture_ids: Optional[List[str]] = None,
) -> List[Dict[str, object]]:
    if current_user is None:
        return []
    query = db.query(QuizAttempt).filter(QuizAttempt.user_id == current_user.id)
    cleaned_ids = [lecture_id.strip() for lecture_id in lecture_ids or [] if lecture_id.strip()]
    if cleaned_ids:
        query = query.filter(QuizAttempt.lecture_id.in_(cleaned_ids))
    attempts = query.order_by(QuizAttempt.created_at.desc()).limit(8).all()
    concept_totals: Dict[str, int] = {}
    concept_hints: Dict[str, str] = {}
    for attempt in attempts:
        feedback = attempt.feedback or {}
        for entry in list(feedback.get("weakConcepts") or []):
            if not isinstance(entry, dict):
                continue
            label = str(entry.get("label") or "").strip()
            if not label:
                continue
            misses = entry.get("misses")
            try:
                misses = int(misses)
            except (TypeError, ValueError):
                misses = 1
            concept_totals[label] = concept_totals.get(label, 0) + max(1, misses)
            hint = str(entry.get("reviewHint") or "").strip()
            if hint and label not in concept_hints:
                concept_hints[label] = hint

    ordered = sorted(concept_totals.items(), key=lambda item: (-item[1], item[0].casefold()))
    return [
        {
            "label": label,
            "misses": misses,
            "reviewHint": concept_hints.get(label, ""),
        }
        for label, misses in ordered[:3]
    ]


def _lecture_context_payload(lectures: List[Lecture], language: str) -> List[Dict[str, object]]:
    payload: List[Dict[str, object]] = []
    for lecture in lectures:
        key_terms = []
        for item in list(lecture.key_terms or [])[:6]:
            if not isinstance(item, dict):
                continue
            term = str(item.get("term") or "").strip()
            if term:
                key_terms.append(term)
        payload.append(
            {
                "id": lecture.id,
                "title": lecture.title,
                "course": lecture.course_name,
                "summary": _lecture_summary_text(lecture, language),
                "keyTerms": key_terms,
            }
        )
    return payload


def _parse_scope_topics(scope: str) -> List[str]:
    cleaned_scope = " ".join(str(scope or "").strip().split())
    if not cleaned_scope:
        return []

    chapter_match = re.search(r"chapter\s*(\d+)\s*[-~to]+\s*(\d+)", cleaned_scope, re.IGNORECASE)
    if chapter_match:
        start = int(chapter_match.group(1))
        end = int(chapter_match.group(2))
        return [f"Chapter {number}" for number in range(min(start, end), max(start, end) + 1)]

    topic_match = re.search(r"(\d+)\s*장\s*[-~]+\s*(\d+)\s*장", cleaned_scope)
    if topic_match:
        start = int(topic_match.group(1))
        end = int(topic_match.group(2))
        return [f"{number}장" for number in range(min(start, end), max(start, end) + 1)]

    tokens = [
        piece.strip(" -")
        for piece in re.split(r"[\n,;/]+|\s+\|\s+", cleaned_scope)
        if piece.strip(" -")
    ]
    return tokens or [cleaned_scope]


def _select_study_dates(start_date: dt.date, exam_date: dt.date, study_days_per_week: int) -> List[dt.date]:
    all_dates: List[dt.date] = []
    cursor = start_date
    while cursor <= exam_date:
        all_dates.append(cursor)
        cursor += dt.timedelta(days=1)

    if len(all_dates) <= 1 or study_days_per_week >= 7:
        return all_dates

    selected: List[dt.date] = [all_dates[0]]
    quota = 0.0
    per_day = study_days_per_week / 7
    for index, day in enumerate(all_dates[1:], start=1):
        quota += per_day
        is_exam_day = day == exam_date
        if quota >= 1.0 or is_exam_day:
            selected.append(day)
            if not is_exam_day:
                quota -= 1.0

    if selected[-1] != exam_date:
        selected.append(exam_date)
    return sorted(set(selected))


def _chunk_topics(topics: List[str], parts: int) -> List[List[str]]:
    if parts <= 0:
        return []
    if not topics:
        return [[] for _ in range(parts)]
    chunk_size = math.ceil(len(topics) / parts)
    grouped = [topics[index : index + chunk_size] for index in range(0, len(topics), chunk_size)]
    while len(grouped) < parts:
        grouped.append([])
    return grouped[:parts]


def _render_focus(topics: List[str], fallback: str) -> str:
    cleaned = [topic.strip() for topic in topics if topic.strip()]
    if not cleaned:
        return fallback
    if len(cleaned) == 1:
        return cleaned[0]
    if len(cleaned) == 2:
        return f"{cleaned[0]} + {cleaned[1]}"
    return f"{cleaned[0]} - {cleaned[-1]}"


def _normalize_plan_item(raw_item: object, default_session_minutes: int) -> Optional[Dict]:
    if not isinstance(raw_item, dict):
        return None
    date = str(raw_item.get("date") or "").strip()
    phase = str(raw_item.get("phase") or "").strip()
    task = str(raw_item.get("task") or "").strip()
    title = str(raw_item.get("title") or "").strip() or task
    mission = str(raw_item.get("mission") or "").strip()
    focus = str(raw_item.get("focus") or "").strip() or task
    review = str(raw_item.get("review") or "").strip()
    expected_output = str(
        raw_item.get("expectedOutput", raw_item.get("expected_output")) or ""
    ).strip()
    why_this_matters = str(
        raw_item.get("whyThisMatters", raw_item.get("why_this_matters")) or ""
    ).strip()
    focus_boost = str(raw_item.get("focusBoost", raw_item.get("focus_boost")) or "").strip()
    effort = str(raw_item.get("effort") or "steady").strip().lower()
    if effort not in {"light", "steady", "deep"}:
        effort = "steady"
    session_minutes = raw_item.get("sessionMinutes", raw_item.get("session_minutes"))
    try:
        session_minutes = int(session_minutes)
    except (TypeError, ValueError):
        session_minutes = default_session_minutes
    session_minutes = max(30, min(240, session_minutes))
    if not date or not task:
        return None
    return {
        "date": date,
        "phase": phase or "foundation",
        "title": title,
        "task": task,
        "mission": mission or title,
        "focus": focus,
        "review": review,
        "expectedOutput": expected_output or review or task,
        "whyThisMatters": why_this_matters or review or task,
        "focusBoost": focus_boost or None,
        "effort": effort,
        "sessionMinutes": session_minutes,
    }


def _normalize_model_payload(raw_data: object, default_session_minutes: int) -> Optional[Dict]:
    if not isinstance(raw_data, dict):
        return None
    overview = str(raw_data.get("overview") or "").strip()
    checkpoints = [
        str(item).strip()
        for item in list(raw_data.get("checkpoints") or [])
        if str(item).strip()
    ]
    personalization_note = str(
        raw_data.get("personalizationNote", raw_data.get("personalization_note")) or ""
    ).strip()
    weak_concepts = [
        str(item).strip()
        for item in list(raw_data.get("weakConcepts", raw_data.get("weak_concepts")) or [])
        if str(item).strip()
    ]
    raw_plan = list(raw_data.get("plan") or [])
    plan = [
        normalized
        for item in raw_plan
        if (normalized := _normalize_plan_item(item, default_session_minutes)) is not None
    ]
    if not overview or not plan:
        return None
    return {
        "overview": overview,
        "checkpoints": checkpoints,
        "personalizationNote": personalization_note or None,
        "weakConcepts": weak_concepts,
        "plan": plan,
    }


def _fallback_plan(
    *,
    course: str,
    exam_date: dt.date,
    scope: str,
    start_date: dt.date,
    language: str,
    study_days_per_week: int,
    session_minutes: int,
    weak_concepts: List[Dict[str, object]],
) -> Dict:
    copy = _copy(language)
    total_days = (exam_date - start_date).days + 1
    study_dates = _select_study_dates(start_date, exam_date, study_days_per_week)
    topics = _parse_scope_topics(scope)

    review_sessions = 1
    if len(study_dates) >= 6:
        review_sessions = 2
    if len(study_dates) >= 10:
        review_sessions = 3
    learning_sessions = max(1, len(study_dates) - review_sessions)
    topic_groups = _chunk_topics(topics, learning_sessions)
    all_scope = _render_focus(topics, copy["all_scope"])

    plan: List[Dict] = []
    for index, day in enumerate(study_dates):
        phase = _phase_key(index=index, total=len(study_dates))
        is_last = index == len(study_dates) - 1
        is_review = index >= learning_sessions
        if is_last or phase == "final":
            title = copy["final_title"]
            focus = all_scope
            task = copy["final_task"].format(focus=focus)
            review = copy["final_review"]
            mission = copy["final_mission"].format(focus=focus)
            expected_output = copy["final_output"]
            why_this_matters = copy["final_why"]
            effort = "light" if is_last else "steady"
        elif is_review or phase == "reinforce":
            title = copy["consolidation_title"]
            focus = all_scope if index >= len(topic_groups) else _render_focus(topic_groups[index], all_scope)
            task = copy["consolidation_task"].format(focus=focus)
            review = copy["consolidation_review"]
            mission = copy["consolidation_mission"].format(focus=focus)
            expected_output = copy["consolidation_output"].format(focus=focus)
            why_this_matters = copy["consolidation_why"]
            effort = "steady"
        else:
            focus = _render_focus(topic_groups[index], all_scope)
            title = copy["study_title"].format(index=index + 1)
            task = copy["study_task"].format(focus=focus)
            review = copy["study_review"]
            mission = copy["study_mission"].format(focus=focus)
            expected_output = copy["study_output"].format(focus=focus)
            why_this_matters = copy["study_why"]
            effort = "deep" if index == 0 or len(topic_groups[index]) > 1 else "steady"

        weak_concept = weak_concepts[index % len(weak_concepts)] if weak_concepts else None
        focus_boost = None
        if weak_concept and (phase != "final" or index == len(study_dates) - 1):
            focus_boost = copy["boost"].format(label=str(weak_concept["label"]))

        plan.append(
            {
                "date": day.isoformat(),
                "phase": copy[f"phase_{phase}"],
                "title": title,
                "task": f"{course}: {task}",
                "mission": mission,
                "focus": focus,
                "review": review,
                "expectedOutput": expected_output,
                "whyThisMatters": why_this_matters,
                "focusBoost": focus_boost,
                "effort": effort,
                "sessionMinutes": session_minutes,
            }
        )

    checkpoints = [
        copy["checkpoint_start"],
        copy["checkpoint_middle"],
        copy["checkpoint_end"],
    ]
    weak_labels = [str(item.get("label") or "").strip() for item in weak_concepts if str(item.get("label") or "").strip()]
    personalization_note = None
    if weak_labels:
        personalization_note = copy["personalization"].format(labels=", ".join(weak_labels))
    return {
        "overview": copy["overview"].format(
            days=total_days,
            sessions=len(plan),
            minutes=session_minutes,
        ),
        "checkpoints": checkpoints,
        "personalizationNote": personalization_note,
        "weakConcepts": weak_labels,
        "plan": plan,
    }


@router.post("/study-plan", response_model=StudyPlanResponse)
def create_plan(
    payload: StudyPlanRequest,
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user_optional),
):
    start_date = payload.start_date or dt.date.today()
    if start_date > payload.exam_date:
        start_date = payload.exam_date

    language = _normalize_lang(payload.language)
    selected_lectures = _selected_lectures(db, current_user, payload.lecture_ids)
    course, scope = _derive_course_and_scope(
        payload.course,
        payload.scope,
        selected_lectures,
        language,
    )
    if not course.strip():
        course = "Study plan"
    if not scope.strip():
        scope = _copy(language)["all_scope"]

    lecture_ids = [lecture.id for lecture in selected_lectures]
    lecture_titles = [str(lecture.title or "").strip() for lecture in selected_lectures if str(lecture.title or "").strip()]
    weak_concepts = _recent_weak_concepts(db, current_user, lecture_ids)
    lecture_context = _lecture_context_payload(selected_lectures, language)
    fallback = _fallback_plan(
        course=course,
        exam_date=payload.exam_date,
        scope=scope,
        start_date=start_date,
        language=language,
        study_days_per_week=payload.study_days_per_week,
        session_minutes=payload.session_minutes,
        weak_concepts=weak_concepts,
    )

    system = (
        "You create realistic exam study schedules for students. Return strict JSON only."
    )
    user = (
        f"course: {course}\n"
        f"start_date: {start_date.isoformat()}\n"
        f"exam_date: {payload.exam_date.isoformat()}\n"
        f"scope: {scope}\n"
        f"output_language: {language}\n"
        f"study_days_per_week: {payload.study_days_per_week}\n"
        f"session_minutes: {payload.session_minutes}\n\n"
        f"selected_lectures: {lecture_context}\n\n"
        f"recent_weak_concepts: {weak_concepts}\n\n"
        'Return JSON with this shape: {"overview":"...","checkpoints":["..."],"personalizationNote":"...","weakConcepts":["..."],"plan":[{"date":"YYYY-MM-DD","phase":"...","title":"...","task":"...","mission":"...","focus":"...","review":"...","expectedOutput":"...","whyThisMatters":"...","focusBoost":"...","effort":"light|steady|deep","sessionMinutes":90}]}. '
        "Use the requested output language for all learner-facing text. "
        "Create one study item per active study date, keep dates between start_date and exam_date, and make the plan feel realistic instead of generic. "
        "Early sessions should cover new material, middle sessions should consolidate, and the final stretch should emphasize recall, weak points, and exam readiness. "
        "Each plan item should feel like a mission, not a bland to-do list. "
        "Use `phase` labels such as foundation, reinforce, or final recall in the target language. "
        "Each `task` should be actionable, each `focus` should name the specific topic group, each `review` should tell the student what to revisit, and each `expectedOutput` should leave a concrete artifact behind. "
        "If selected lectures are provided, use their summaries and key terms to shape the plan, and mention lecture-specific content rather than only generic chapter ranges. "
        "If recent weak concepts are provided, weave them into `focusBoost` and `personalizationNote` naturally without overwhelming the whole plan."
    )

    try:
        generated = _normalize_model_payload(
            generate_json(system=system, user=user),
            payload.session_minutes,
        )
        result = generated or fallback
    except (GeminiNotConfiguredError, Exception):
        result = fallback

    record = StudyPlan(
        user_id=current_user.id if current_user else None,
        course=course,
        exam_date=payload.exam_date.isoformat(),
        scope=scope,
        result=result,
    )
    db.add(record)
    db.commit()

    return StudyPlanResponse(
        course=course,
        exam_date=payload.exam_date,
        start_date=start_date,
        scope=scope,
        language=language,
        total_days=(payload.exam_date - start_date).days + 1,
        study_days=len(result["plan"]),
        daily_minutes=payload.session_minutes,
        overview=result["overview"],
        checkpoints=list(result.get("checkpoints") or []),
        personalizationNote=result.get("personalizationNote"),
        weakConcepts=list(result.get("weakConcepts") or []),
        selectedLectureIds=lecture_ids,
        selectedLectureTitles=lecture_titles,
        plan=list(result["plan"]),
    )
