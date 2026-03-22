"""
Meepo Meta Worker — main entry point.

Runs the token refresh loop and health check server.
The actual message processing is triggered by the backend webhook router.
"""
import asyncio
import logging
import time

import sentry_sdk
from aiohttp import web

from meta_worker.config import settings
from meta_worker.token_manager import token_refresh_loop

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("meepo-meta-worker")

if settings.SENTRY_DSN:
    sentry_sdk.init(
        dsn=settings.SENTRY_DSN,
        traces_sample_rate=0.1,
        environment="production",
    )
    logger.info("Sentry initialized")

_worker_started_at = time.monotonic()


async def _health_handler(request: web.Request) -> web.Response:
    uptime = int(time.monotonic() - _worker_started_at)
    return web.json_response({
        "status": "ok",
        "service": "meta_worker",
        "uptime_seconds": uptime,
    })


async def _start_health_server():
    app = web.Application()
    app.router.add_get("/health", _health_handler)
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, "0.0.0.0", 8080)
    await site.start()
    logger.info("Health check server started on :8080")


async def main():
    logger.info("Meepo Meta Worker starting...")

    await _start_health_server()

    # Start token refresh loop
    asyncio.create_task(token_refresh_loop())

    logger.info("Meta Worker running. Waiting for webhook events...")

    # Keep running
    while True:
        await asyncio.sleep(3600)


if __name__ == "__main__":
    asyncio.run(main())
