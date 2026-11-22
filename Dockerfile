FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /opt/weatherops

COPY requirements.txt ./
RUN python -m pip install --no-cache-dir --no-compile -r requirements.txt

RUN groupadd --gid 10001 weatherops \
    && useradd --uid 10001 --gid 10001 --no-create-home \
        --shell /usr/sbin/nologin weatherops

COPY app/ ./app/

USER 10001:10001
EXPOSE 8000
CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
