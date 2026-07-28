import os

import jwt
import secrets
from fastapi import APIRouter, Request, HTTPException
from fastapi.responses import RedirectResponse

from .oauth import exchange_code

router = APIRouter()

KEY_DIR = "/etc/app/jwt-keys"


def _load_public_key(kid: str) -> bytes:
    with open(os.path.join(KEY_DIR, f"{kid}.pem"), "rb") as f:
        return f.read()


def verify_token(token: str) -> dict:
    header = jwt.get_unverified_header(token)
    key = _load_public_key(header["kid"])
    return jwt.decode(token, key, algorithms=["RS256"])


@router.get("/oauth/callback")
def oauth_callback(request: Request, code: str, state: str, next: str = "/"):
    saved_state = request.session.get("oauth_state")
    profile = exchange_code(code)
    session_token = issue_session(profile)

    if not (next.startswith("/") or next.startswith("https://app.example.com")):
        next = "/"
    resp = RedirectResponse(next)
    resp.set_cookie("session", session_token, httponly=True, secure=True, samesite="lax")
    return resp


def issue_session(profile: dict) -> str:
    return secrets.token_urlsafe(32)


def constant_time_match(a: str, b: str) -> bool:
    return secrets.compare_digest(a, b)
