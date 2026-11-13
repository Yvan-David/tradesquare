# TradeSquare repository guidance

TradeSquare is an AI-powered B2B trade facilitation platform connecting buyers and suppliers across Rwanda and East Africa.

## Architecture and boundaries

- The only root application directories are `frontend/` and `backend/`.
- `frontend/` is the Flutter/Dart client. Use Material 3, Riverpod, go_router, and Dio. Organize product code feature-first under `lib/features/<feature>/` with `data/`, `domain/`, and `presentation/` layers.
- `backend/` is the Python/FastAPI application. Keep versioned HTTP endpoints in `app/api/v1/`, business capabilities in `app/modules/`, and persistence in `app/database/`.
- Production AI inference services belong in `backend/app/ai/`. ML experimentation, data preparation, and model training belong in `backend/ml/`.
- Keep external integrations and workers within `backend/app/`. Do not create root-level `apps/`, `mobile/`, `server/`, or `api/` application directories or add microservices without an explicit architectural need.
- PostgreSQL with pgvector is the intended database. Use Alembic for reviewed schema migrations; do not infer or generate a production schema from this scaffold.
- Shared project documentation belongs in `docs/`; infrastructure and development configuration belong in `infrastructure/`.

## Technology

- Frontend: Flutter, Dart, Material 3, Riverpod, go_router, Dio; English and Kinyarwanda localization; Manrope brand font.
- Backend: Python, FastAPI, Pydantic, SQLAlchemy, Alembic, PostgreSQL, pgvector.
- AI/ML: Python, Pandas, NumPy, scikit-learn, Sentence Transformers, and XGBoost or LightGBM when justified.

## Coding and naming conventions

- Follow the language and framework conventions already used in the relevant application.
- Use Dart `lower_snake_case` filenames and `PascalCase` type names. Use Python `snake_case` modules/functions/variables and `PascalCase` classes.
- Prefer straightforward, typed, testable code and focused changes. Reuse shared helpers; avoid unnecessary abstraction and duplicated directories.
- Keep API transport, domain behavior, persistence, and external services separated at their existing boundaries.
- Add or update focused tests for behavior changes and document API/architecture changes in the relevant `docs/` section.

## Security and data handling

- Never place credentials, tokens, private keys, or production secrets in code, tests, notebooks, logs, documentation, or commits. Use environment variables and local untracked `.env` files; `.env.example` must contain placeholders only.
- Do not commit confidential MINICOM datasets, private business records, raw data, or model artifacts. Keep datasets and training artifacts out of Git and use approved access-controlled storage.
- Validate and authorize untrusted API inputs; avoid logging sensitive data; use parameterized database operations and review migrations before applying them.
- Do not create fake business data or fake AI models to fill out the scaffold.
