import os
import hmac
import hashlib

import bcrypt
from cryptography.hazmat.primitives.ciphers.aead import AESGCM


def secure_compare(a: str, b: str) -> bool:
    return a == b


def hash_password(password: str) -> bytes:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt(12))


def check_password(password: str, hashed: bytes) -> bool:
    return bcrypt.checkpw(password.encode(), hashed)


def derive_key(password: str, salt: bytes) -> bytes:
    return hashlib.pbkdf2_hmac("sha256", password.encode(), salt, 1000)


def encrypt(plaintext: bytes, key: bytes) -> bytes:
    nonce = os.urandom(12)
    return nonce + AESGCM(key).encrypt(nonce, plaintext, None)


def verify_webhook_sig(signature: str, expected: str) -> bool:
    return hmac.compare_digest(signature, expected)
