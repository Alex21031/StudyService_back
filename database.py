import datetime as dt
import uuid
from typing import List, Optional

from sqlalchemy import JSON, Boolean, DateTime, ForeignKey, Integer, String, Text, create_engine, func, inspect, text
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship, sessionmaker

from config import settings


class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    email: Mapped[str] = mapped_column(String(320), unique=True, index=True, nullable=False)
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)
    full_name: Mapped[str] = mapped_column(String(160), default="", nullable=False)
    school_name: Mapped[str] = mapped_column(String(200), default="", nullable=False)
    major: Mapped[str] = mapped_column(String(160), default="", nullable=False)
    academic_year: Mapped[str] = mapped_column(String(80), default="", nullable=False)
    preferred_language: Mapped[str] = mapped_column(String(16), default="ko", nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[dt.datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )


class StudyPlan(Base):
    __tablename__ = "study_plans"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[Optional[int]] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    course: Mapped[str] = mapped_column(String(200), nullable=False)
    exam_date: Mapped[str] = mapped_column(String(32), nullable=False)
    scope: Mapped[str] = mapped_column(String, nullable=False)
    result: Mapped[dict] = mapped_column(JSON, nullable=False)
    created_at: Mapped[dt.datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    user: Mapped[Optional[User]] = relationship(User, lazy="joined")


class TranslationJob(Base):
    __tablename__ = "translation_jobs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[Optional[int]] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    text: Mapped[str] = mapped_column(String, nullable=False)
    result: Mapped[dict] = mapped_column(JSON, nullable=False)
    created_at: Mapped[dt.datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    user: Mapped[Optional[User]] = relationship(User, lazy="joined")


class ProblemSession(Base):
    __tablename__ = "problem_sessions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[Optional[int]] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    problem: Mapped[str] = mapped_column(String, nullable=False)
    problem_type: Mapped[str] = mapped_column(String(32), default="auto", nullable=False)
    language: Mapped[str] = mapped_column(String(16), default="zh", nullable=False)
    state: Mapped[dict] = mapped_column(JSON, nullable=False)
    created_at: Mapped[dt.datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    user: Mapped[Optional[User]] = relationship(User, lazy="joined")


class Lecture(Base):
    __tablename__ = "lectures"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    course_name: Mapped[str] = mapped_column(String(255), nullable=False)
    audio_path: Mapped[str] = mapped_column(String(1024), default="", nullable=False)
    status: Mapped[str] = mapped_column(String(32), default="uploaded", nullable=False)
    transcript: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    summary_original: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    summary_russian: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    summary_translations: Mapped[dict] = mapped_column(JSON, default=dict, nullable=False)
    key_terms: Mapped[list] = mapped_column(JSON, default=list, nullable=False)
    error_message: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    progress_percent: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    progress_message: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    progress_current: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    progress_total: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    created_at: Mapped[dt.datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[dt.datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    user: Mapped[User] = relationship(User, lazy="joined")
    quizzes: Mapped[List["LectureQuiz"]] = relationship(
        "LectureQuiz", back_populates="lecture", cascade="all, delete-orphan"
    )


class LectureQuiz(Base):
    __tablename__ = "lecture_quizzes"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    lecture_id: Mapped[str] = mapped_column(ForeignKey("lectures.id"), nullable=False, index=True)
    type: Mapped[str] = mapped_column(String(32), nullable=False)
    question: Mapped[str] = mapped_column(Text, nullable=False)
    options: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)
    answer: Mapped[str] = mapped_column(Text, nullable=False)
    explanation: Mapped[str] = mapped_column(Text, nullable=False)
    difficulty: Mapped[str] = mapped_column(String(32), nullable=False)
    skill_tag: Mapped[Optional[str]] = mapped_column(String(120), nullable=True)
    concept_refs: Mapped[list] = mapped_column(JSON, default=list, nullable=False)
    review_hint: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    follow_up_prompt: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    localized_content: Mapped[dict] = mapped_column(JSON, default=dict, nullable=False)
    created_at: Mapped[dt.datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    lecture: Mapped[Lecture] = relationship("Lecture", back_populates="quizzes")


class QuizAttempt(Base):
    __tablename__ = "quiz_attempts"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    lecture_id: Mapped[str] = mapped_column(ForeignKey("lectures.id"), nullable=False, index=True)
    answers: Mapped[dict] = mapped_column(JSON, nullable=False)
    score: Mapped[int] = mapped_column(Integer, nullable=False)
    mode: Mapped[str] = mapped_column(String(16), default="practice", nullable=False)
    feedback: Mapped[dict] = mapped_column(JSON, default=dict, nullable=False)
    created_at: Mapped[dt.datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    user: Mapped[User] = relationship(User, lazy="joined")
    lecture: Mapped[Lecture] = relationship(Lecture, lazy="joined")


engine = create_engine(settings.database_url, pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def _ensure_user_columns() -> None:
    inspector = inspect(engine)
    if not inspector.has_table("users"):
        return

    existing_columns = {column["name"] for column in inspector.get_columns("users")}
    statements: list[str] = []

    if "full_name" not in existing_columns:
        statements.append("ALTER TABLE users ADD COLUMN full_name VARCHAR(160) DEFAULT '' NOT NULL")
    if "school_name" not in existing_columns:
        statements.append("ALTER TABLE users ADD COLUMN school_name VARCHAR(200) DEFAULT '' NOT NULL")
    if "major" not in existing_columns:
        statements.append("ALTER TABLE users ADD COLUMN major VARCHAR(160) DEFAULT '' NOT NULL")
    if "academic_year" not in existing_columns:
        statements.append("ALTER TABLE users ADD COLUMN academic_year VARCHAR(80) DEFAULT '' NOT NULL")
    if "preferred_language" not in existing_columns:
        statements.append("ALTER TABLE users ADD COLUMN preferred_language VARCHAR(16) DEFAULT 'ko' NOT NULL")

    if not statements:
        return

    with engine.begin() as connection:
        for statement in statements:
            connection.execute(text(statement))


def _ensure_lecture_columns() -> None:
    inspector = inspect(engine)
    if not inspector.has_table("lectures"):
        return

    existing_columns = {column["name"] for column in inspector.get_columns("lectures")}
    statements: list[str] = []

    if "progress_percent" not in existing_columns:
        statements.append(
            "ALTER TABLE lectures ADD COLUMN progress_percent INTEGER DEFAULT 0 NOT NULL"
        )
    if "progress_message" not in existing_columns:
        statements.append("ALTER TABLE lectures ADD COLUMN progress_message TEXT")
    if "progress_current" not in existing_columns:
        statements.append("ALTER TABLE lectures ADD COLUMN progress_current INTEGER")
    if "progress_total" not in existing_columns:
        statements.append("ALTER TABLE lectures ADD COLUMN progress_total INTEGER")
    if "summary_translations" not in existing_columns:
        statements.append("ALTER TABLE lectures ADD COLUMN summary_translations JSON DEFAULT '{}' NOT NULL")

    if not statements:
        return

    with engine.begin() as connection:
        for statement in statements:
            connection.execute(text(statement))


def _ensure_lecture_quiz_columns() -> None:
    inspector = inspect(engine)
    if not inspector.has_table("lecture_quizzes"):
        return

    existing_columns = {column["name"] for column in inspector.get_columns("lecture_quizzes")}
    statements: list[str] = []

    if "skill_tag" not in existing_columns:
        statements.append("ALTER TABLE lecture_quizzes ADD COLUMN skill_tag VARCHAR(120)")
    if "concept_refs" not in existing_columns:
        statements.append("ALTER TABLE lecture_quizzes ADD COLUMN concept_refs JSON DEFAULT '[]' NOT NULL")
    if "review_hint" not in existing_columns:
        statements.append("ALTER TABLE lecture_quizzes ADD COLUMN review_hint TEXT")
    if "follow_up_prompt" not in existing_columns:
        statements.append("ALTER TABLE lecture_quizzes ADD COLUMN follow_up_prompt TEXT")
    if "localized_content" not in existing_columns:
        statements.append("ALTER TABLE lecture_quizzes ADD COLUMN localized_content JSON DEFAULT '{}' NOT NULL")

    if not statements:
        return

    with engine.begin() as connection:
        for statement in statements:
            connection.execute(text(statement))


def _ensure_quiz_attempt_columns() -> None:
    inspector = inspect(engine)
    if not inspector.has_table("quiz_attempts"):
        return

    existing_columns = {column["name"] for column in inspector.get_columns("quiz_attempts")}
    statements: list[str] = []

    if "mode" not in existing_columns:
        statements.append("ALTER TABLE quiz_attempts ADD COLUMN mode VARCHAR(16) DEFAULT 'practice' NOT NULL")
    if "feedback" not in existing_columns:
        statements.append("ALTER TABLE quiz_attempts ADD COLUMN feedback JSON DEFAULT '{}' NOT NULL")

    if not statements:
        return

    with engine.begin() as connection:
        for statement in statements:
            connection.execute(text(statement))


def init_db() -> None:
    Base.metadata.create_all(bind=engine)
    _ensure_user_columns()
    _ensure_lecture_columns()
    _ensure_lecture_quiz_columns()
    _ensure_quiz_attempt_columns()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
