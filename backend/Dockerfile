# The backend with everything a job runs: the API, RefChecker (a Python package from
# requirements.txt) and Java 8 for Saffron. Saffron's jars and models are mounted from
# tools/saffron-home, and GROBID runs in its own container. See docker-compose.yml.
FROM eclipse-temurin:8-jre-jammy AS java8

FROM python:3.13-slim
COPY --from=java8 /opt/java/openjdk /opt/java8

ENV PYTHONUNBUFFERED=1 PYTHONUTF8=1
WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY pytest.ini saffron-config.json ./
COPY orchestrator ./orchestrator
COPY tests ./tests

EXPOSE 8000
CMD ["python", "-m", "uvicorn", "--factory", "orchestrator.main:build_app", "--host", "0.0.0.0", "--port", "8000"]
