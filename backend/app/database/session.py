import os
from collections.abc import Iterator
from functools import lru_cache

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker


class DatabaseNotConfiguredError(RuntimeError):
    """Raised when DATABASE_URL is missing (Supabase / Postgres)."""


@lru_cache
def create_session_factory() -> sessionmaker[Session]:
    database_url = os.environ.get("DATABASE_URL", "").strip()
    if not database_url:
        raise DatabaseNotConfiguredError(
            "DATABASE_URL is not set. Use your Supabase Postgres URI "
            "(Settings → Database → Connection string, URI mode)."
        )
    # Supabase often provides postgres:// — SQLAlchemy 2 prefers postgresql+psycopg://
    if database_url.startswith("postgres://"):
        database_url = "postgresql+psycopg://" + database_url[len("postgres://") :]
    elif database_url.startswith("postgresql://") and "+psycopg" not in database_url:
        database_url = "postgresql+psycopg://" + database_url[len("postgresql://") :]
    engine = create_engine(database_url, pool_pre_ping=True)
    return sessionmaker(bind=engine, autoflush=False, autocommit=False)


def get_db() -> Iterator[Session]:
    session = create_session_factory()()
    try:
        yield session
    finally:
        session.close()
