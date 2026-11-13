# Backend

The backend is a modular Python/FastAPI application. HTTP endpoints live under `app/api/v1/`; business capabilities are grouped under `app/modules/`; database access is in `app/database/`.

Production AI inference services belong in `app/ai/`, while data preparation, experiments, training, evaluation, and model registry work belong in `ml/`. Keep these concerns separate and do not introduce independent services without a clear need.

PostgreSQL with pgvector is the intended database. Alembic configuration and migration directories are present, but no production schema or migrations are generated in this scaffold.
