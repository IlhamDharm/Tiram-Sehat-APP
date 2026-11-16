import asyncio
import os
import sys

# PENTING untuk Windows: psycopg3 async memerlukan WindowsSelectorEventLoopPolicy
if sys.platform == "win32":
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

import uvicorn

if __name__ == "__main__":
    uvicorn.run(
        "app.main:create_app",
        factory=True,
        host="0.0.0.0",
        port=8000,
        reload=True,
        loop="asyncio",
    )
