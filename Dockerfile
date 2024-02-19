FROM python:3.11-slim

RUN pip install poetry==1.6.1

RUN poetry config virtualenvs.create false

WORKDIR /app

COPY ./pyproject.toml ./README.md ./poetry.lock* ./requirements.txt ./

ADD ./docs /app/docs

COPY ./package[s] ./packages

RUN pip install -r requirements.txt

RUN poetry install  --no-interaction --no-ansi --no-root

COPY ./app ./app

RUN poetry install --no-interaction --no-ansi

EXPOSE 8000

ENV APP_DIR="/app"

ARG OPENAI_API_KEY

ENV OPENAI_API_KEY=${OPENAI_API_KEY}

CMD exec uvicorn app.server:app --host 0.0.0.0 --port 8000
