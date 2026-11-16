"""Unit tests for shared auth dependencies (no database required)."""
from __future__ import annotations

import asyncio
import unittest

from app.core.deps import get_current_user_id, get_optional_user_id
from app.core.exceptions import AppException
from app.core.security import create_access_token


class AuthDependencyTests(unittest.TestCase):
    def test_requires_authorization_header(self) -> None:
        with self.assertRaises(AppException) as ctx:
            asyncio.run(get_current_user_id(None))
        self.assertEqual(ctx.exception.status_code, 401)
        self.assertEqual(ctx.exception.code, "UNAUTHENTICATED")

    def test_rejects_wrong_scheme(self) -> None:
        with self.assertRaises(AppException):
            asyncio.run(get_current_user_id("Basic abc"))

    def test_decodes_valid_token(self) -> None:
        token = create_access_token("user-123", "farmer")
        user_id = asyncio.run(get_current_user_id(f"Bearer {token}"))
        self.assertEqual(user_id, "user-123")

    def test_optional_allows_anonymous(self) -> None:
        self.assertIsNone(asyncio.run(get_optional_user_id(None)))

    def test_optional_rejects_invalid_token(self) -> None:
        with self.assertRaises(AppException):
            asyncio.run(get_optional_user_id("Bearer not-a-jwt"))

    def test_optional_decodes_valid_token(self) -> None:
        token = create_access_token("user-456", "farmer")
        self.assertEqual(
            asyncio.run(get_optional_user_id(f"Bearer {token}")), "user-456"
        )


if __name__ == "__main__":
    unittest.main()
