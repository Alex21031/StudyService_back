from typing import Dict


_STRINGS: Dict[str, Dict[str, str]] = {
    "zh": {
        "done": "已完成。",
        "continue": "继续",
        "keep_going": "请继续说明你的思路。",
        "received": "收到。",
        "study_review": "复习/练习",
        "study_final_review": "总复习",
        "study_scope": "学习/复习",
    },
    "ko": {
        "done": "완료되었습니다.",
        "continue": "계속",
        "keep_going": "풀이 과정을 계속 설명해 주세요.",
        "received": "확인했습니다.",
        "study_review": "복습/연습",
        "study_final_review": "총정리",
        "study_scope": "학습/복습",
    },
    "ru": {
        "done": "Готово.",
        "continue": "Продолжить",
        "keep_going": "Пожалуйста, продолжайте объяснять ход своих мыслей.",
        "received": "Принято.",
        "study_review": "повторение/практика",
        "study_final_review": "итоговое повторение",
        "study_scope": "изучение/повторение",
    },
}


def map_lang(lang: str):
    l = (lang or "").strip().lower()
    if not l:
        return None

    if l in ("zh", "zh-cn", "zh-hans", "cn", "chinese"):
        return "zh"
    if l in ("ko", "ko-kr", "kr", "korean", "한국어"):
        return "ko"
    if l in ("ru", "ru-ru", "russian"):
        return "ru"
    if l.startswith("zh"):
        return "zh"
    if l.startswith("ko"):
        return "ko"
    if l.startswith("ru"):
        return "ru"
    return None


def normalize_lang(lang: str) -> str:
    return map_lang(lang) or "zh"


def t(key: str, lang: str) -> str:
    l = normalize_lang(lang)
    return _STRINGS.get(l, _STRINGS["zh"]).get(key, _STRINGS["zh"].get(key, key))

