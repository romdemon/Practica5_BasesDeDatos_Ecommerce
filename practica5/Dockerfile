# ============================================================================
# Dockerfile - Aplicación Python para Poblado de Base de Datos
# Práctica 5 - Sistema E-Commerce
# ============================================================================

# Imagen base oficial de Python
FROM python:3.11-slim

# Metadata
LABEL maintainer="tu_email@ejemplo.com"
LABEL description="Aplicación para poblado automatizado de BD E-Commerce"
LABEL version="1.0"

# Variables de entorno
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    DEBIAN_FRONTEND=noninteractive

# Instalar dependencias del sistema
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-client \
    gcc \
    python3-dev \
    libpq-dev \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Crear directorio de trabajo
WORKDIR /app

# Copiar requirements y instalar dependencias Python
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install -r requirements.txt

# Copiar scripts de la aplicación
COPY scripts/ ./scripts/
COPY entrypoint.sh .

# Crear directorio para logs
RUN mkdir -p /app/logs

# Dar permisos de ejecución al entrypoint
RUN chmod +x entrypoint.sh

# Usuario no root para mayor seguridad
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app
USER appuser

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD python -c "import psycopg2; print('OK')" || exit 1

# Punto de entrada
ENTRYPOINT ["./entrypoint.sh"]