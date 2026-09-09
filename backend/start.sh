#!/usr/bin/env bash
set -e

# Wait for DB if necessary (handled by compose condition service_healthy, but good practice)
echo "Running database migrations..."
python -m alembic upgrade head

echo "Starting FastAPI server..."
exec uvicorn app.main:app --host 0.0.0.0 --port 8000
