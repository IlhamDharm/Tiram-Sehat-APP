"""Async connection pool (psycopg_pool) and transaction helper."""
from __future__ import annotations

import logging
from contextlib import asynccontextmanager
from typing import Any, AsyncGenerator, Callable, TypeVar

from psycopg import AsyncConnection
from psycopg.rows import dict_row
from psycopg_pool import AsyncConnectionPool

from app.core.config import settings

logger = logging.getLogger(__name__)

T = TypeVar("T")

# Global pool – initialised during app lifespan
pool: AsyncConnectionPool | None = None


async def open_pool() -> AsyncConnectionPool:
    """Create and open the async connection pool."""
    global pool
    conninfo = settings.DATABASE_URL_POOLED or settings.DATABASE_URL
    pool = AsyncConnectionPool(
        conninfo=conninfo,
        min_size=2,
        max_size=10,
        open=False,
        kwargs={"row_factory": dict_row},
    )
    await pool.open()
    logger.info("Database pool opened (%s)", conninfo[:40] + "…")
    return pool


async def close_pool() -> None:
    """Close the connection pool."""
    global pool
    if pool is not None:
        await pool.close()
        pool = None
        logger.info("Database pool closed")


@asynccontextmanager
async def get_connection() -> AsyncGenerator[AsyncConnection, None]:
    """Acquire a connection from the pool."""
    if pool is None:
        raise RuntimeError("Database pool is not initialised")
    async with pool.connection() as conn:
        yield conn


async def with_transaction(fn: Callable[..., Any], *args: Any, **kwargs: Any) -> Any:
    """Execute *fn(conn, ...)* inside a transaction, rolling back on error."""
    async with get_connection() as conn:
        async with conn.transaction():
            return await fn(conn, *args, **kwargs)


async def fetch_one(query: str, params: tuple | dict | None = None) -> dict | None:
    """Run a query and return the first row as a dict, or ``None``."""
    async with get_connection() as conn:
        cur = await conn.execute(query, params)
        return await cur.fetchone()  # type: ignore[return-value]


async def fetch_all(query: str, params: tuple | dict | None = None) -> list[dict]:
    """Run a query and return all rows as a list of dicts."""
    async with get_connection() as conn:
        cur = await conn.execute(query, params)
        return await cur.fetchall()  # type: ignore[return-value]


async def execute(query: str, params: tuple | dict | None = None) -> int:
    """Execute a write query and return the number of affected rows."""
    async with get_connection() as conn:
        async with conn.transaction():
            cur = await conn.execute(query, params)
            return cur.rowcount  # type: ignore[return-value]
