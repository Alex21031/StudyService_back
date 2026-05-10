from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from auth import get_current_user_optional
from database import TranslationJob, User, get_db
from gemini_api import GeminiNotConfiguredError, generate_json
from i18n import map_lang
from schemas import EmailTranslateRequest, EmailTranslateResponse


router = APIRouter()


@router.post("/email-translate", response_model=EmailTranslateResponse)
def translate(
    payload: EmailTranslateRequest,
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user_optional),
):
    raw = payload.languages or []
    langs = []
    for x in raw:
        m = map_lang(x)
        if not m:
            raise HTTPException(status_code=400, detail="Only zh/ko/ru are supported")
        if m not in langs:
            langs.append(m)
    if not langs:
        langs = ["zh", "ko", "ru"]

    system = (
        "你是专业翻译。保留原有礼貌表达与语气。只输出 JSON，不要解释。"
        '输出格式：{"translations":{"zh":"...","ko":"...","ru":"..."}}。'
    )
    user = (
        f"目标语言列表: {langs}\n"
        f"原文:\n{payload.text}\n\n"
        "将原文翻译为目标语言列表中的所有语言。"
    )

    try:
        data = generate_json(system=system, user=user)
        translations = (data.get("translations") or {}) if isinstance(data, dict) else {}
        if not isinstance(translations, dict) or not translations:
            raise ValueError("empty translations")
    except GeminiNotConfiguredError as e:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(e))
    except Exception:
        raise HTTPException(status_code=502, detail="Bad translation response")

    record = TranslationJob(
        user_id=current_user.id if current_user else None,
        text=payload.text,
        result={"translations": translations},
    )
    db.add(record)
    db.commit()

    return EmailTranslateResponse(translations={k: str(v) for k, v in translations.items()})

