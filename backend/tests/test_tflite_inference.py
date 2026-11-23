"""Unit tests for local TFLite model loading, inference, and predict service."""
from __future__ import annotations

import asyncio
import io
import unittest
from unittest.mock import AsyncMock, patch

from PIL import Image

from app.core.exceptions import AppException
from app.core.tflite_model import (
    DEFAULT_LABELS,
    is_model_loaded,
    load_model,
    predict_image_bytes,
)
from app.modules.scans.router import router as scans_router
from app.modules.scans.service import predict_scan_image


def _make_sample_jpeg(color: tuple[int, int, int] = (230, 230, 230)) -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (416, 416), color).save(buf, format="JPEG")
    return buf.getvalue()


class TfliteInferenceTests(unittest.TestCase):
    def test_load_model_succeeds(self) -> None:
        self.assertEqual(DEFAULT_LABELS, ("blackmold", "greenmold", "healthy"))
        loaded = load_model()
        self.assertTrue(loaded)
        self.assertTrue(is_model_loaded())

    def test_predict_image_bytes_returns_valid_probabilities(self) -> None:
        result = predict_image_bytes(_make_sample_jpeg())
        self.assertIn(result.label, DEFAULT_LABELS)
        self.assertGreaterEqual(result.confidence, 0.0)
        self.assertLessEqual(result.confidence, 1.0)
        self.assertEqual(set(result.probabilities.keys()), set(DEFAULT_LABELS))
        self.assertAlmostEqual(sum(result.probabilities.values()), 1.0, places=3)

    def test_predict_scan_image_maps_disease_metadata(self) -> None:
        mock_disease = {
            "id": "d0000000-0000-0000-0000-000000000001",
            "name": "Baglog Sehat Produktif",
            "scientific_name": "Pleurotus ostreatus",
            "default_severity": "healthy",
            "is_healthy": True,
            "location_hint": "Seluruh Baglog",
        }
        mock_steps = [
            {
                "step_order": 1,
                "title": "Jaga Kelembapan Optimal",
                "description": "Pertahankan kelembapan 80-90%.",
            }
        ]
        with (
            patch(
                "app.modules.scans.service.diseases_repo.find_by_ml_label",
                new=AsyncMock(return_value=mock_disease),
            ),
            patch(
                "app.modules.scans.service.scan_steps_repo.get_disease_steps",
                new=AsyncMock(return_value=mock_steps),
            ),
        ):
            payload = asyncio.run(
                predict_scan_image(
                    contents=_make_sample_jpeg(),
                    filename="sample.jpg",
                    content_type="image/jpeg",
                )
            )

        self.assertIn(payload["ml_label"], DEFAULT_LABELS)
        self.assertEqual(payload["disease_id"], mock_disease["id"])
        self.assertEqual(payload["diagnosis_name"], "Baglog Sehat Produktif")
        self.assertIsNotNone(payload["description"])
        self.assertEqual(payload["severity"], "healthy")
        self.assertGreaterEqual(len(payload["steps"]), 1)

    def test_predict_scan_image_fallback_metadata_for_all_classes(self) -> None:
        from app.modules.diseases.repository import _ML_LABEL_ALIASES
        from app.modules.scans.service import _FALLBACK_DISEASE_METADATA

        for key in ("blackmold", "greenmold", "healthy"):
            self.assertIn(key, _FALLBACK_DISEASE_METADATA)
            self.assertIn(key, _ML_LABEL_ALIASES)

        with patch(
            "app.modules.scans.service.diseases_repo.find_by_ml_label",
            new=AsyncMock(return_value=None),
        ):
            payload = asyncio.run(
                predict_scan_image(
                    contents=_make_sample_jpeg(),
                    filename="sample.jpg",
                    content_type="image/jpeg",
                )
            )

        self.assertIn(payload["ml_label"], DEFAULT_LABELS)
        self.assertIn(payload["diagnosis_name"], {"Black Mold", "Green Mold", "Baglog Sehat Produktif"})
        self.assertEqual(set(payload["probabilities"].keys()), set(DEFAULT_LABELS))

    def test_predict_scan_image_rejects_non_image_file(self) -> None:
        with self.assertRaises(AppException) as ctx:
            asyncio.run(
                predict_scan_image(
                    contents=b"not-an-image",
                    filename="notes.txt",
                    content_type="text/plain",
                )
            )
        self.assertEqual(ctx.exception.status_code, 400)
        self.assertEqual(ctx.exception.code, "VALIDATION_ERROR")

    def test_predict_route_registered_before_dynamic_scan_id(self) -> None:
        paths = [getattr(r, "path", "") for r in scans_router.routes]
        self.assertIn("/predict", paths)
        self.assertIn("/{scan_id}", paths)
        self.assertLess(paths.index("/predict"), paths.index("/{scan_id}"))


if __name__ == "__main__":
    unittest.main()
