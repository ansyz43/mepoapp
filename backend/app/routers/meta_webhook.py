"""
Meta Platform Webhook receiver.

GET  /api/meta/webhook  — verification challenge (hub.verify_token)
POST /api/meta/webhook  — incoming events with HMAC-SHA256 signature
"""
import hashlib
import hmac
import logging

from fastapi import APIRouter, Request, HTTPException, Query
from fastapi.responses import PlainTextResponse

from app.config import settings

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/meta", tags=["meta_webhook"])


@router.get("/webhook")
async def verify_webhook(
    hub_mode: str = Query(..., alias="hub.mode"),
    hub_verify_token: str = Query(..., alias="hub.verify_token"),
    hub_challenge: str = Query(..., alias="hub.challenge"),
):
    """Meta webhook verification (subscribe mode)."""
    if hub_mode != "subscribe":
        raise HTTPException(status_code=403, detail="Invalid mode")
    if not hmac.compare_digest(hub_verify_token, settings.META_WEBHOOK_VERIFY_TOKEN):
        raise HTTPException(status_code=403, detail="Invalid verify token")
    logger.info("Webhook verification successful")
    return PlainTextResponse(content=hub_challenge)


@router.post("/webhook")
async def receive_webhook(request: Request):
    """Receive and validate Meta webhook events."""
    # Verify HMAC-SHA256 signature
    signature_header = request.headers.get("X-Hub-Signature-256", "")
    if not signature_header.startswith("sha256="):
        raise HTTPException(status_code=403, detail="Missing signature")

    body = await request.body()
    expected = hmac.new(
        settings.META_APP_SECRET.encode(),
        body,
        hashlib.sha256,
    ).hexdigest()
    received = signature_header[7:]  # strip "sha256="

    if not hmac.compare_digest(expected, received):
        logger.warning("Webhook signature mismatch")
        raise HTTPException(status_code=403, detail="Invalid signature")

    payload = await request.json()
    obj_type = payload.get("object")

    if obj_type == "instagram":
        await _handle_instagram_events(payload)
    elif obj_type == "page":
        await _handle_messenger_events(payload)
    else:
        logger.debug(f"Ignoring webhook object type: {obj_type}")

    # Must return 200 quickly to avoid Meta retries
    return {"status": "ok"}


async def _handle_instagram_events(payload: dict):
    """Process Instagram messaging events."""
    from app.services.meta_client import MetaClient

    for entry in payload.get("entry", []):
        ig_id = entry.get("id")
        for messaging in entry.get("messaging", []):
            sender_id = messaging.get("sender", {}).get("id")
            recipient_id = messaging.get("recipient", {}).get("id")
            message = messaging.get("message", {})
            text = message.get("text")

            if not sender_id or sender_id == recipient_id:
                continue  # echo or missing sender

            if text:
                logger.info(f"[IG] Message from {sender_id} to page {ig_id}: {text[:50]}...")
                # Forward to meta_worker for AI processing
                await _enqueue_message(
                    platform="instagram",
                    page_id=ig_id,
                    sender_id=sender_id,
                    text=text,
                    timestamp=messaging.get("timestamp"),
                )

            # Handle postback (button clicks)
            postback = messaging.get("postback")
            if postback:
                logger.info(f"[IG] Postback from {sender_id}: {postback.get('payload')}")


async def _handle_messenger_events(payload: dict):
    """Process Facebook Messenger events."""
    for entry in payload.get("entry", []):
        page_id = entry.get("id")
        for messaging in entry.get("messaging", []):
            sender_id = messaging.get("sender", {}).get("id")
            recipient_id = messaging.get("recipient", {}).get("id")
            message = messaging.get("message", {})
            text = message.get("text")

            if not sender_id or sender_id == recipient_id:
                continue

            if text:
                logger.info(f"[MSG] Message from {sender_id} to page {page_id}: {text[:50]}...")
                await _enqueue_message(
                    platform="facebook_messenger",
                    page_id=page_id,
                    sender_id=sender_id,
                    text=text,
                    timestamp=messaging.get("timestamp"),
                )

            # Handle referral (m.me links with ref param)
            referral = messaging.get("referral")
            if referral:
                ref_param = referral.get("ref", "")
                logger.info(f"[MSG] Referral from {sender_id}: ref={ref_param}")
                await _handle_referral(
                    platform="facebook_messenger",
                    page_id=page_id,
                    sender_id=sender_id,
                    ref_param=ref_param,
                )


async def _enqueue_message(
    platform: str,
    page_id: str,
    sender_id: str,
    text: str,
    timestamp: int | None = None,
):
    """
    Enqueue incoming message for AI processing.

    In production, this would publish to a message queue (Redis, RabbitMQ, etc.).
    For initial implementation, process inline using meta_worker logic.
    """
    from meta_worker.webhook_handler import process_incoming_message

    try:
        await process_incoming_message(
            platform=platform,
            page_id=page_id,
            sender_id=sender_id,
            text=text,
        )
    except Exception as e:
        logger.error(f"Error processing message from {sender_id}: {e}", exc_info=True)


async def _handle_referral(
    platform: str,
    page_id: str,
    sender_id: str,
    ref_param: str,
):
    """Handle referral parameter from m.me or ig.me link."""
    if not ref_param.startswith("ref_"):
        return

    ref_code = ref_param[4:]  # strip "ref_" prefix
    from meta_worker.webhook_handler import process_referral

    try:
        await process_referral(
            platform=platform,
            page_id=page_id,
            sender_id=sender_id,
            ref_code=ref_code,
        )
    except Exception as e:
        logger.error(f"Error processing referral from {sender_id}: {e}", exc_info=True)
