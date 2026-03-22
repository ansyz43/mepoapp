"""
Apple Sign In verification.

Verifies Apple identity tokens using Apple's public JWKS endpoint.
"""
import logging
import time
from typing import Any

import httpx
import jwt as pyjwt
from jwt import PyJWKClient

from app.config import settings

logger = logging.getLogger(__name__)

APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"
APPLE_ISSUER = "https://appleid.apple.com"

_jwks_client = PyJWKClient(APPLE_JWKS_URL, cache_keys=True)


async def verify_apple_identity_token(identity_token: str) -> dict[str, Any]:
    """
    Verify an Apple identity token (JWT RS256).

    Returns the decoded payload with fields:
      - sub (Apple user ID)
      - email
      - email_verified
      - is_private_email
    """
    try:
        # Get the signing key from Apple's JWKS
        signing_key = _jwks_client.get_signing_key_from_jwt(identity_token)

        # Decode and verify
        payload = pyjwt.decode(
            identity_token,
            signing_key.key,
            algorithms=["RS256"],
            audience=settings.APPLE_CLIENT_ID,
            issuer=APPLE_ISSUER,
        )

        return payload

    except pyjwt.ExpiredSignatureError:
        raise ValueError("Apple identity token has expired")
    except pyjwt.InvalidTokenError as e:
        raise ValueError(f"Invalid Apple identity token: {e}")
