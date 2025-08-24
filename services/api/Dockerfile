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
COPY services/api /app

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host=0.0.0.0", "--port=8000"]
