FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# deps для uvicorn[standard]
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# python-зависимости
RUN pip install --no-cache-dir \
      "fastapi>=0.110" "uvicorn[standard]>=0.29" "prometheus-client>=0.16"

WORKDIR /app
COPY services /app/services

EXPOSE 8000
CMD ["uvicorn", "services.api.app.main:app", "--host=0.0.0.0", "--port=8000"]
RUN id -u bfl >/dev/null 2>&1 || (adduser -D -u 10001 bfl 2>/dev/null || useradd -m -u 10001 bfl)
USER bfl
