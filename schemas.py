import datetime as dt
from typing import Dict, List, Literal, Optional

from pydantic import BaseModel, EmailStr, Field


class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6)


class UserOut(BaseModel):
    id: int
    email: EmailStr
    is_active: bool

    model_config = {"from_attributes": True}


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


class StudyPlanRequest(BaseModel):
    course: str = Field(default="")
    exam_date: dt.date
    scope: str = Field(default="")
    start_date: Optional[dt.date] = None
    language: str = Field(default="en", min_length=2, max_length=16)
    study_days_per_week: int = Field(default=5, ge=1, le=7)
    session_minutes: int = Field(default=90, ge=30, le=240)
    lecture_ids: List[str] = Field(default_factory=list, alias="lectureIds")


class StudyPlanItem(BaseModel):
    date: dt.date
    phase: str
    title: str
    task: str
    mission: str
    focus: str
    review: str
    expected_output: str = Field(alias="expectedOutput")
    why_this_matters: str = Field(alias="whyThisMatters")
    focus_boost: Optional[str] = Field(default=None, alias="focusBoost")
    effort: str = Field(default="steady")
    session_minutes: int = Field(default=90, alias="sessionMinutes")


class StudyPlanResponse(BaseModel):
    course: str
    exam_date: dt.date
    start_date: dt.date
    scope: str
    language: str
    total_days: int
    study_days: int
    daily_minutes: int
    overview: str
    checkpoints: List[str] = Field(default_factory=list)
    personalization_note: Optional[str] = Field(default=None, alias="personalizationNote")
    weak_concepts: List[str] = Field(default_factory=list, alias="weakConcepts")
    selected_lecture_ids: List[str] = Field(default_factory=list, alias="selectedLectureIds")
    selected_lecture_titles: List[str] = Field(default_factory=list, alias="selectedLectureTitles")
    plan: List[StudyPlanItem]


class EmailTranslateRequest(BaseModel):
    text: str = Field(min_length=1)
    languages: List[str] = Field(default_factory=lambda: ["zh", "ko", "ru"])


class EmailTranslateResponse(BaseModel):
    translations: Dict[str, str]


class SolveProblemRequest(BaseModel):
    problem: str = Field(min_length=1)
    problem_type: str = Field(default="auto", min_length=1, max_length=32)
    language: str = Field(default="zh", min_length=2, max_length=16)


class SolveStep(BaseModel):
    step: int = Field(ge=1)
    title: str
    explanation: str
    question: Optional[str] = None
    hint: Optional[str] = None


class SolveProblemResponse(BaseModel):
    steps: List[SolveStep]


class ProblemSessionCreateResponse(BaseModel):
    session_id: str
    prompt: str
    step_index: int
    total_steps: int
    step_title: Optional[str] = None


class ProblemAnswerRequest(BaseModel):
    answer: str = Field(min_length=1)


class ProblemSessionStateResponse(BaseModel):
    session_id: str
    prompt: str
    step_index: int
    total_steps: int
    is_finished: bool
    ok: Optional[bool] = None
    feedback: Optional[str] = None
    hint: Optional[str] = None
    step_title: Optional[str] = None
    attempts: int = 0


LectureStatus = Literal["uploaded", "transcribing", "summarizing", "generating_quiz", "ready", "failed"]
QuizType = Literal["multiple_choice", "short_answer", "blank"]
QuizDifficulty = Literal["easy", "medium", "hard"]
QuizMode = Literal["practice", "test"]


class KeyTermOut(BaseModel):
    term: str
    originalExplanation: str
    russianExplanation: str
    additionalContext: str = ""
    explanations: Dict[str, str] = Field(default_factory=dict)
    additionalNotes: Dict[str, str] = Field(default_factory=dict)


class QuizLocalizationOut(BaseModel):
    question: str
    options: List[str] = Field(default_factory=list)
    answer: str
    explanation: str
    reviewHint: Optional[str] = None
    followUpPrompt: Optional[str] = None
    skillTag: Optional[str] = None
    conceptRefs: List[str] = Field(default_factory=list)


class LectureQuizOut(BaseModel):
    id: str
    lectureId: str
    type: QuizType
    question: str
    options: List[str] = Field(default_factory=list)
    answer: str
    explanation: str
    difficulty: QuizDifficulty
    skillTag: Optional[str] = None
    conceptRefs: List[str] = Field(default_factory=list)
    reviewHint: Optional[str] = None
    followUpPrompt: Optional[str] = None
    localizedContent: Dict[str, QuizLocalizationOut] = Field(default_factory=dict)
    createdAt: dt.datetime


class LectureOut(BaseModel):
    id: str
    userId: int
    title: str
    courseName: str
    audioPath: str
    status: LectureStatus
    transcript: Optional[str] = None
    summaryOriginal: Optional[str] = None
    summaryRussian: Optional[str] = None
    summaryTranslations: Dict[str, str] = Field(default_factory=dict)
    keyTerms: List[KeyTermOut] = Field(default_factory=list)
    errorMessage: Optional[str] = None
    progressPercent: int = 0
    progressMessage: Optional[str] = None
    progressCurrent: Optional[int] = None
    progressTotal: Optional[int] = None
    createdAt: dt.datetime
    updatedAt: dt.datetime


class LectureDetailOut(BaseModel):
    lecture: LectureOut
    quizzes: List[LectureQuizOut] = Field(default_factory=list)


class ProcessLectureResponse(BaseModel):
    lecture: LectureOut
    quizzes: List[LectureQuizOut] = Field(default_factory=list)


class TranscriptResponse(BaseModel):
    transcript: str


class QuizAttemptRequest(BaseModel):
    answers: Dict[str, str]
    mode: QuizMode = "practice"
    language: str = "en"
    quiz_ids: List[str] = Field(default_factory=list, alias="quizIds")


class RegenerateLectureQuizzesRequest(BaseModel):
    lecture_ids: List[str] = Field(default_factory=list, alias="lectureIds")
    question_count: int = Field(default=10, alias="questionCount", ge=1, le=20)


class QuizQuestionResultOut(BaseModel):
    quizId: str
    question: str
    submittedAnswer: str
    correctAnswer: str
    isCorrect: bool
    explanation: str
    reviewHint: Optional[str] = None
    skillTag: Optional[str] = None
    conceptRefs: List[str] = Field(default_factory=list)
    followUpPrompt: Optional[str] = None


class WeakConceptOut(BaseModel):
    label: str
    misses: int
    reviewHint: Optional[str] = None


class QuizAttemptResponse(BaseModel):
    attemptId: str
    correct: int
    total: int
    score: int
    mode: QuizMode
    language: str
    questionResults: List[QuizQuestionResultOut] = Field(default_factory=list)
    weakConcepts: List[WeakConceptOut] = Field(default_factory=list)
    recommendedActions: List[str] = Field(default_factory=list)
