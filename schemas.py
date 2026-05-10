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
    course: str = Field(min_length=1)
    exam_date: dt.date
    scope: str = Field(min_length=1)
    start_date: Optional[dt.date] = None
    language: str = Field(default="zh", min_length=2, max_length=16)


class StudyPlanItem(BaseModel):
    date: dt.date
    task: str


class StudyPlanResponse(BaseModel):
    course: str
    exam_date: dt.date
    scope: str
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


class KeyTermOut(BaseModel):
    term: str
    originalExplanation: str
    russianExplanation: str


class LectureQuizOut(BaseModel):
    id: str
    lectureId: str
    type: QuizType
    question: str
    options: List[str] = Field(default_factory=list)
    answer: str
    explanation: str
    difficulty: QuizDifficulty
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
    keyTerms: List[KeyTermOut] = Field(default_factory=list)
    errorMessage: Optional[str] = None
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


class QuizAttemptResponse(BaseModel):
    attemptId: str
    correct: int
    total: int
    score: int
