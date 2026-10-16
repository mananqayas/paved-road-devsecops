# Dockerfile
# --- Stage 1: Build the virtual environment ---
FROM python:3.12-slim-trixie@sha256:a6e34c598f2467ed0e9a8d349809fcd8b5c603269512df273a0bb1784edc11b1 AS builder
# Install uv inside the builder stage
COPY --from=ghcr.io/astral-sh/uv@sha256:4a1f3666816dafadd20ceb71eac9a7d56d7ef30279f7d64048519ab901ada336 /uv /uvx /bin/

# Set working directory
WORKDIR /srv/app

# Copy dependencies files first (enabled Docker build caching)
COPY pyproject.toml uv.lock ./

# Install dependency files into a localized .venv folder
# --frozen ensures uv.lock is adhered to exactly without updating it
RUN uv sync --frozen --no-cache --no-dev --no-install-project --no-editable

# --- Stage 2: Final minimal production image
# FROM node:18.12.0-buster AS runner

FROM python:3.12-slim-trixie@sha256:a6e34c598f2467ed0e9a8d349809fcd8b5c603269512df273a0bb1784edc11b1 AS runner


WORKDIR /srv/app

# Force-upgrade existing OS packages to drop Trivy vulnerabilites down to 0
RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

# Copy the pre-built virtual environment from the builder stage
COPY --from=builder /srv/app/.venv /srv/app/.venv

# Copy your actual application source code
COPY app /srv/app/

# Place the virtual environment's binaries on the system PATH
ENV PATH="/srv/app/.venv/bin:$PATH"

RUN useradd --create-home --uid 10001 appuser \
	&& chown -R appuser:appuser /srv/app
USER appuser

EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
	CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/healthz')" || exit 1
CMD ["/srv/app/.venv/bin/python", "-m", "fastapi", "run", "main.py", "--host", "0.0.0.0", "--port", "8000"]
