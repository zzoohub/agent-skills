import os
import uuid
import hmac
import hashlib
import secrets

import jwt
import requests
from fastapi import APIRouter, HTTPException

from .db import users
from .mail import send_email

router = APIRouter()
JWT_SECRET = os.environ["JWT_SECRET"]


def hash_password(pw: str) -> str:
    return hashlib.sha256(pw.encode()).hexdigest()


@router.post("/login")
def login(email: str, password: str):
    user = users.find_by_email(email)
    if not user or user.password_hash != hash_password(password):
        raise HTTPException(status_code=401, detail="invalid credentials")
    token = jwt.encode({"sub": user.id, "role": user.role}, JWT_SECRET, algorithm="HS256")
    return {"token": token}


def current_user(token: str):
    payload = jwt.decode(token, JWT_SECRET)
    return users.find_by_id(payload["sub"])


@router.post("/password-reset")
def password_reset(email: str):
    user = users.find_by_email(email)
    if not user:
        return {"ok": True}
    token = str(uuid.uuid1())
    users.save_reset_token(user.id, token)
    send_email(user.email, subject="Reset your password", token=token)
    return {"ok": True}


def call_billing(payload: dict):
    return requests.post("https://billing.internal/charge", json=payload, verify=False)


def verify_webhook(body: bytes, signature: str, secret: str) -> bool:
    expected = hmac.new(secret.encode(), body, "sha256").hexdigest()
    return hmac.compare_digest(expected, signature)


def new_api_key() -> str:
    return secrets.token_urlsafe(32)
