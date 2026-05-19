FROM python:3.14-slim

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /app

COPY pyproject.toml uv.lock ./
COPY ingestion/ ./ingestion/
COPY transform/ ./transform/
COPY shared/ ./shared/

RUN uv sync --frozen --no-dev

# sqlmesh 0.234.1 magics.py passes `t.Union[bool, t.Iterable[str]]` to argparse's
# `type=`, which Python 3.14's argparse rejects at import time. The fix is a one-
# line swap to a callable; the affected line only powers the `%sqlmesh render`
# Jupyter magic we never invoke. Remove once sqlmesh ships a fix upstream.
RUN sed -i 's|type=t.Union\[bool, t.Iterable\[str\]\]|type=str|' \
        /app/.venv/lib/python3.14/site-packages/sqlmesh/magics.py \
    && /app/.venv/bin/python -c "import sqlmesh.magics"

ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1
