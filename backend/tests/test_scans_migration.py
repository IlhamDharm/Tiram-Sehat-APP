"""Unit tests for migrated scan & upload helpers (no database required)."""
from __future__ import annotations

import asyncio
import unittest

from app.core.exceptions import AppException
from app.modules.auth.schemas import RegisterRequest
from app.modules.scans.schemas import CreateScanRequest, ScanStepIn
from app.modules.scans.service import (
    _clean_rak_code,
    _normalize_confidence,
    _normalize_scan_method,
)
from app.modules.uploads.service import upload_image_bytes


class ScanMigrationTests(unittest.TestCase):
    def test_normalize_scan_method(self) -> None:
        self.assertEqual(_normalize_scan_method("manual"), "manual")
        self.assertEqual(_normalize_scan_method("MANUAL"), "manual")
        self.assertEqual(_normalize_scan_method("camera"), "camera")
        self.assertEqual(_normalize_scan_method("on_device_tflite"), "camera")
        self.assertEqual(_normalize_scan_method(None), "camera")

    def test_normalize_confidence(self) -> None:
        self.assertAlmostEqual(_normalize_confidence(0.942), 0.942)
        self.assertAlmostEqual(_normalize_confidence(94.2), 0.942)
        self.assertAlmostEqual(_normalize_confidence(120.0), 1.0)
        self.assertIsNone(_normalize_confidence(None))

    def test_create_scan_request_accepts_manual_with_steps_and_notes(self) -> None:
        req = CreateScanRequest(
            rak_id="B-04",
            column_no=3,
            diagnosis_name="Green Mold",
            scientific_name="Trichoderma sp.",
            confidence=94.2,
            severity="treatable",
            scan_method="manual",
            scanned_at="2026-11-16T11:50:00Z",
            status_note="Bercak di leher baglog.",
            status_tag="Inspeksi Manual",
            steps=[ScanStepIn(title="Karantina", description="Pisahkan baglog.")],
        )
        self.assertEqual(req.scan_method, "manual")
        self.assertEqual(len(req.steps or []), 1)

    def test_upload_image_rejects_non_image_file(self) -> None:
        with self.assertRaises(AppException) as ctx:
            asyncio.run(
                upload_image_bytes(
                    contents=b"hello",
                    filename="script.txt",
                    content_type="text/plain",
                )
            )
        self.assertEqual(ctx.exception.status_code, 400)
        self.assertEqual(ctx.exception.code, "VALIDATION_ERROR")

    def test_register_request_schema(self) -> None:
        req = RegisterRequest(
            name="Siti Aminah",
            phone="081299998888",
            pin="123456",
            farmer_id="PETANI-002",
            kumbung_code="A",
        )
        self.assertEqual(req.name, "Siti Aminah")
        self.assertEqual(req.kumbung_code, "A")

    def test_clean_rak_code(self) -> None:
        self.assertEqual(_clean_rak_code("Rak Kumbung A"), "A")
        self.assertEqual(_clean_rak_code("Rak-B04"), "B04")
        self.assertEqual(_clean_rak_code("b-04"), "B-04")
        self.assertEqual(_clean_rak_code(""), "A-01")


if __name__ == "__main__":
    unittest.main()
