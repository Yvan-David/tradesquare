# TradeSquare

TradeSquare is an AI-powered B2B trade facilitation platform for buyers and suppliers across Rwanda and East Africa.

## Repository layout

- `frontend/` — Flutter client application.
- `backend/` — FastAPI application, AI inference services, and ML workspace.
- `docs/` — product, architecture, API, UX, and operational documentation.
- `infrastructure/` — container, deployment, and development scripts.

Frontend and backend are intentionally kept separate. AI services used by the running application live in `backend/app/ai/`; experimentation and model training live in `backend/ml/`.

## Development status

This repository currently contains the initial project structure, not production application features. See the directory READMEs and [CONTRIBUTING.md](CONTRIBUTING.md) before adding code. Copy `.env.example` to `.env` and replace its placeholders locally; never commit `.env` or real credentials.

## Technology

- Frontend: Flutter, Dart, Material 3, Riverpod, go_router, Dio.
- Backend: Python, FastAPI, Pydantic, SQLAlchemy, Alembic, PostgreSQL, pgvector.
- AI/ML: Python, Pandas, NumPy, scikit-learn, Sentence Transformers, and XGBoost where appropriate.
