# -------------------------------------------------------------
# Stage 1: Build de dependencias
# -------------------------------------------------------------
FROM python:3.11-slim AS builder

WORKDIR /app

# Instalar herramientas para compilar psycopg2
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# -------------------------------------------------------------
# Stage 2: Runtime de producción
# -------------------------------------------------------------
FROM python:3.11-slim AS runner

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000 \
    PATH=/home/appuser/.local/bin:$PATH

# Librería de cliente de postgres y curl para healthcheck
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Crear usuario sin privilegios (Seguridad)
RUN groupadd -g 10001 appgroup && \
    useradd -u 10001 -g appgroup -s /bin/bash -m appuser

# Copiar paquetes instalados desde el builder
COPY --from=builder /root/.local /home/appuser/.local
COPY --chown=appuser:appgroup . /app

USER appuser

EXPOSE 8000

# Healthcheck nativo
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8000/api/users/ || exit 1

# Comando de arranque con Gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "3", "demo.wsgi:application"]