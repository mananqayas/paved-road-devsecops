# Dockerfile
# --- Stage 1: Build the virtual evvironment ---
FROM python:3.12-slim AS builder

# Install uv inside the builder stage
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Set working directory
WORKDIR /srv/app

# Copy dependencies files first (enabled Docker build caching)
COPY pyproject.toml uv.lock ./

# Install dependency files into a localized .venv folder
# --frozen ensures uv.local is adhered to exactly without updating it
RUN uv sync --frozen --no-cache --no-dev

# --- Stage 2: Final minimal production image
FROM python:3.12-slim AS runner

WORKDIR /srv/app

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
	
CMD ["fastapi", "run", "main.py", "--host", "0.0.0.0", "--port", "8000"]