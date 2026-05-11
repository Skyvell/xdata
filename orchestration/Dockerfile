FROM python:3.14-slim

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /opt/dagster/app

COPY pyproject.toml uv.lock ./
COPY ingestion/ ./ingestion/
COPY orchestration/ ./orchestration/

RUN uv sync --frozen --no-dev

ENV PATH="/opt/dagster/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    DAGSTER_HOME=/opt/dagster/dagster_home

RUN mkdir -p $DAGSTER_HOME
