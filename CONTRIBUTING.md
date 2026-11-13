# Contributing

## Project boundaries

- Put Flutter application code and its tests under `frontend/`.
- Put FastAPI, database application logic, AI inference, ML work, workers, and server-side integrations under `backend/`.
- Keep production inference in `backend/app/ai/` and experiments/training in `backend/ml/`.
- Put shared project documentation in `docs/` and infrastructure work in `infrastructure/`.
- Avoid adding root-level application directories or unnecessary services and abstractions.

## Working agreements

- Prefer small, focused changes that follow the existing feature/module boundaries.
- Use clear, consistent `snake_case` names for Python modules and Dart `lower_snake_case` file names; use `PascalCase` for Dart types and `snake_case` for Python functions and variables.
- Add or update focused tests with behavior changes. Keep test data synthetic and non-sensitive.
- Do not commit credentials, private business records, confidential MINICOM data, datasets, or model weights.
- Document architectural or API changes in the relevant `docs/` section.

## Local configuration

Use `.env.example` as a key reference and keep local values in an untracked `.env`. Do not put credentials in source code, fixtures, logs, notebooks, or documentation.
