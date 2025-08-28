FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# deps для uvicorn[standard]
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /app

# python-зависимости
COPY services/api/requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY services/api /app

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host=0.0.0.0", "--port=8000"]
RUN id -u bfl >/dev/null 2>&1 || (adduser -D -u 10001 bfl 2>/dev/null || useradd -m -u 10001 bfl)
USER bfl
