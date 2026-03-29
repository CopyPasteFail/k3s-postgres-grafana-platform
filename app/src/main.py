from datetime import datetime
import os

import psycopg
from psycopg.rows import dict_row
from fastapi import FastAPI, HTTPException, status
from pydantic import BaseModel, Field


class TodoCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=255)


class TodoRead(BaseModel):
    id: int
    title: str
    completed: bool
    created_at: datetime


app = FastAPI(title="TODO API", version="0.1.0")


def db_settings() -> dict[str, object]:
    return {
        "host": os.getenv("POSTGRES_HOST", "postgresql"),
        "port": int(os.getenv("POSTGRES_PORT", "5432")),
        "dbname": os.getenv("POSTGRES_DB", "todoapp"),
        "user": os.getenv("POSTGRES_USER", "todoapp"),
        "password": os.getenv("POSTGRES_PASSWORD", ""),
        "connect_timeout": int(os.getenv("POSTGRES_CONNECT_TIMEOUT_SECONDS", "5")),
    }


def fetch_all_todos() -> list[TodoRead]:
    with psycopg.connect(**db_settings(), row_factory=dict_row) as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, title, completed, created_at
                FROM public.todos
                ORDER BY id ASC
                """
            )
            return [TodoRead(**row) for row in cur.fetchall()]


@app.get("/healthz")
def healthz() -> dict[str, str]:
    try:
        with psycopg.connect(**db_settings()) as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
                cur.fetchone()
    except psycopg.Error as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="database unavailable") from exc
    return {"status": "ok"}


@app.get("/todos", response_model=list[TodoRead])
def list_todos() -> list[TodoRead]:
    return fetch_all_todos()


@app.post("/todos", response_model=TodoRead, status_code=status.HTTP_201_CREATED)
def create_todo(payload: TodoCreate) -> TodoRead:
    with psycopg.connect(**db_settings(), row_factory=dict_row) as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO public.todos (title)
                VALUES (%s)
                RETURNING id, title, completed, created_at
                """,
                (payload.title,),
            )
            row = cur.fetchone()
        conn.commit()
    return TodoRead(**row)


@app.post("/todos/{todo_id}/complete", response_model=TodoRead)
def complete_todo(todo_id: int) -> TodoRead:
    with psycopg.connect(**db_settings(), row_factory=dict_row) as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                UPDATE public.todos
                SET completed = TRUE
                WHERE id = %s
                RETURNING id, title, completed, created_at
                """,
                (todo_id,),
            )
            row = cur.fetchone()
        conn.commit()

    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="todo not found")

    return TodoRead(**row)


@app.get("/")
def root() -> dict[str, object]:
    return {
        "service": "todo-api",
        "status": "ok",
        "endpoints": ["/healthz", "/todos", "/todos/{id}/complete"],
    }
