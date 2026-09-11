from __future__ import annotations

import hashlib
import hmac
import json
import os
import secrets
import sys
import threading
import time
from dataclasses import dataclass
from pathlib import Path

from .models import ValidationError

ALGORITHM = "pbkdf2_sha256"
ITERATIONS = 600_000
SESSION_SECONDS = 8 * 60 * 60


def hash_password(password: str, salt: bytes | None = None) -> str:
    _validate_password(password)
    salt = salt or secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, ITERATIONS)
    return f"{ALGORITHM}:{ITERATIONS}:{salt.hex()}:{digest.hex()}"


def verify_password(password: str, encoded: str) -> bool:
    if not isinstance(password, str) or len(password) > 1024:
        return False
    try:
        algorithm, iterations_text, salt_text, digest_text = encoded.split(":")
        iterations = int(iterations_text)
        salt = bytes.fromhex(salt_text)
        expected = bytes.fromhex(digest_text)
    except (ValueError, TypeError):
        return False
    if algorithm != ALGORITHM or iterations != ITERATIONS or len(salt) != 16 or len(expected) != 32:
        return False
    actual = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, iterations)
    return hmac.compare_digest(actual, expected)


@dataclass(frozen=True)
class Session:
    token: str
    csrf: str
    expires_at: float


class AdminAuth:
    def __init__(self, path: Path, bootstrap_hash: str) -> None:
        self.path = path
        self.lock = threading.RLock()
        self.sessions: dict[str, Session] = {}
        self.failed_logins = 0
        self.blocked_until = 0.0
        self.password_hash, self.must_change = self._load_or_create(bootstrap_hash)

    def login(self, password: str) -> Session | None:
        with self.lock:
            now = time.time()
            if now < self.blocked_until:
                return None
            if not verify_password(password, self.password_hash):
                self.failed_logins += 1
                if self.failed_logins >= 5:
                    self.blocked_until = now + 30
                    self.failed_logins = 0
                return None
            self.failed_logins = 0
            self.blocked_until = 0.0
            self._expire()
            session = Session(secrets.token_urlsafe(32), secrets.token_urlsafe(24), time.time() + SESSION_SECONDS)
            self.sessions[session.token] = session
            return session

    def authenticate(self, token: str) -> Session | None:
        with self.lock:
            self._expire()
            session = self.sessions.get(token)
            if session is None:
                return None
            renewed = Session(session.token, session.csrf, time.time() + SESSION_SECONDS)
            self.sessions[token] = renewed
            return renewed

    def logout(self, token: str) -> None:
        with self.lock:
            self.sessions.pop(token, None)

    def change_password(self, current: str, new: str, session_token: str) -> None:
        with self.lock:
            if not verify_password(current, self.password_hash):
                raise ValidationError("current password is incorrect")
            replacement = hash_password(new)
            self._save(replacement, False)
            self.password_hash = replacement
            self.must_change = False
            current_session = self.sessions.get(session_token)
            self.sessions.clear()
            if current_session is not None:
                self.sessions[session_token] = current_session

    def _load_or_create(self, bootstrap_hash: str) -> tuple[str, bool]:
        if self.path.exists():
            try:
                value = json.loads(self.path.read_text(encoding="utf-8"))
                encoded = value["password_hash"]
                must_change = value["must_change"]
                if value.get("version") != 1 or not isinstance(encoded, str) or not isinstance(must_change, bool):
                    raise ValueError("unsupported format")
                if not _valid_hash(encoded):
                    raise ValueError("invalid password hash")
                return encoded, must_change
            except (OSError, json.JSONDecodeError, KeyError, ValueError) as error:
                raise RuntimeError(f"cannot load admin credentials {self.path}: {error}") from error
        if not _valid_hash(bootstrap_hash):
            raise RuntimeError("GATEWAY_ADMIN_PASSWORD_HASH is missing or invalid")
        self._save(bootstrap_hash, True)
        return bootstrap_hash, True

    def _save(self, encoded: str, must_change: bool) -> None:
        temporary = self.path.with_suffix(self.path.suffix + ".tmp")
        self.path.parent.mkdir(parents=True, exist_ok=True)
        try:
            with temporary.open("w", encoding="utf-8") as handle:
                os.chmod(temporary, 0o600)
                json.dump({"version": 1, "password_hash": encoded, "must_change": must_change}, handle)
                handle.write("\n")
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temporary, self.path)
        except OSError as error:
            temporary.unlink(missing_ok=True)
            raise RuntimeError(f"cannot save admin credentials {self.path}: {error}") from error

    def _expire(self) -> None:
        now = time.time()
        self.sessions = {token: session for token, session in self.sessions.items() if session.expires_at > now}


def _valid_hash(encoded: str) -> bool:
    try:
        algorithm, iterations, salt, digest = encoded.split(":")
        return (
            algorithm == ALGORITHM
            and int(iterations) == ITERATIONS
            and len(bytes.fromhex(salt)) == 16
            and len(bytes.fromhex(digest)) == 32
        )
    except (ValueError, TypeError):
        return False


def _validate_password(password: str) -> None:
    if not isinstance(password, str) or not 12 <= len(password) <= 1024:
        raise ValidationError("password must contain 12 to 1024 characters")


def main() -> None:
    if sys.argv[1:] != ["hash"]:
        raise SystemExit("usage: python -m vps_gateway.auth hash")
    password = sys.stdin.read()
    try:
        print(hash_password(password))
    except ValidationError as error:
        raise SystemExit(str(error)) from error


if __name__ == "__main__":
    main()
