FROM python:3.11-slim

WORKDIR /app

# =========================
# System dependencies (minimal)
# =========================
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    curl \
    && rm -rf /var/lib/apt/lists/*

# =========================
# Python dependencies
# =========================
COPY requirements.txt .

RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# =========================
# App source
# =========================
COPY main.py .
COPY signal_fetcher.py .

# =========================
# Runtime config
# =========================
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

EXPOSE 25345

# =========================
# Health check (FIXED)
# =========================
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:25345/health || exit 1

# =========================
# Run both services
# =========================
CMD sh -c "python signal_fetcher.py &\npython main.py"