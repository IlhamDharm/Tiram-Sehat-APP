"""Local TFLite inference service for TiramSehat MobileNetV2 end2end model."""
from __future__ import annotations

import asyncio
import io
import logging
import threading
from pathlib import Path
from typing import Any

import numpy as np
from PIL import Image, ImageOps
from pydantic import BaseModel

from app.core.config import settings

logger = logging.getLogger(__name__)

DEFAULT_MODEL_PATH = (
    Path(__file__).resolve().parents[2]
    / "model"
    / "tiramsehat_mobilenetv2_end2end.tflite"
)
DEFAULT_LABELS: tuple[str, ...] = ("blackmold", "greenmold", "healthy")


class PredictionResult(BaseModel):
    """Normalized ML classification result."""

    label: str
    confidence: float
    probabilities: dict[str, float] = {}
    model_version: str = settings.ML_MODEL_VERSION


_interpreter: Any = None
_input_details: dict[str, Any] | None = None
_output_details: dict[str, Any] | None = None
_model_lock = threading.Lock()


def _import_interpreter_class() -> Any:
    """Import TFLite Interpreter from ai-edge-litert, tflite-runtime, or tensorflow."""
    try:
        from ai_edge_litert.interpreter import Interpreter

        return Interpreter
    except ImportError:
        pass

    try:
        from tflite_runtime.interpreter import Interpreter

        return Interpreter
    except ImportError:
        pass

    from tensorflow.lite.python.interpreter import Interpreter

    return Interpreter


def resolve_model_path() -> Path:
    """Return configured TFLite model path or the repository default."""
    configured = (settings.ML_MODEL_PATH or "").strip()
    if configured:
        return Path(configured)
    return DEFAULT_MODEL_PATH


def is_model_loaded() -> bool:
    """Return True when the TFLite interpreter has been initialized."""
    return _interpreter is not None


def load_model() -> bool:
    """Load the TFLite model and allocate tensors once (thread-safe)."""
    global _interpreter, _input_details, _output_details

    with _model_lock:
        if _interpreter is not None:
            return True

        model_path = resolve_model_path()
        if not model_path.exists():
            logger.warning("TFLite model file not found at %s", model_path)
            return False

        try:
            interpreter_cls = _import_interpreter_class()
            interpreter = interpreter_cls(model_path=str(model_path))
            interpreter.allocate_tensors()
            input_details = interpreter.get_input_details()
            output_details = interpreter.get_output_details()
            if not input_details or not output_details:
                logger.warning("Invalid TFLite model details in %s", model_path)
                return False

            _interpreter = interpreter
            _input_details = input_details[0]
            _output_details = output_details[0]
            logger.info(
                "TFLite model loaded from %s (input=%s %s, output=%s %s)",
                model_path,
                _input_details["shape"],
                _input_details["dtype"],
                _output_details["shape"],
                _output_details["dtype"],
            )
            return True
        except Exception as exc:
            logger.warning("Failed to load TFLite model from %s: %s", model_path, exc)
            _interpreter = None
            _input_details = None
            _output_details = None
            return False


def predict_image_bytes(image_bytes: bytes) -> PredictionResult:
    """Run synchronous TFLite inference on raw image bytes."""
    if _interpreter is None:
        load_model()
    if _interpreter is None or _input_details is None or _output_details is None:
        raise RuntimeError("Model TFLite belum tersedia di server")

    img = Image.open(io.BytesIO(image_bytes))
    img = ImageOps.exif_transpose(img).convert("RGB")

    shape = _input_details["shape"]
    height = int(shape[1]) if len(shape) >= 3 and int(shape[1]) > 0 else 416
    width = int(shape[2]) if len(shape) >= 3 and int(shape[2]) > 0 else 416
    resized = img.resize((width, height), Image.Resampling.BILINEAR)

    # Model end2end menerapkan rescaling MobileNetV2 secara internal pada piksel [0..255].
    if _input_details["dtype"] == np.uint8:
        arr = np.asarray(resized, dtype=np.uint8)
    else:
        arr = np.asarray(resized, dtype=np.float32)

    tensor = np.expand_dims(arr, axis=0)

    with _model_lock:
        _interpreter.set_tensor(_input_details["index"], tensor)
        _interpreter.invoke()
        output_tensor = _interpreter.get_tensor(_output_details["index"])

    raw = np.asarray(output_tensor[0])
    if _output_details["dtype"] in (np.uint8, np.int8):
        scale, zero_point = _output_details["quantization"]
        probs = (raw.astype(np.float32) - zero_point) * scale
    else:
        probs = raw.astype(np.float32)

    if float(np.min(probs)) < 0.0 or float(np.sum(probs)) > 1.5:
        shifted = probs - np.max(probs)
        exp_probs = np.exp(shifted)
        probs = exp_probs / np.sum(exp_probs)

    idx = int(np.argmax(probs))
    label = DEFAULT_LABELS[idx] if idx < len(DEFAULT_LABELS) else f"class_{idx}"
    confidence = max(0.0, min(1.0, float(probs[idx])))
    probabilities = {
        lbl: round(float(probs[i]), 6)
        for i, lbl in enumerate(DEFAULT_LABELS)
        if i < len(probs)
    }

    return PredictionResult(
        label=label,
        confidence=confidence,
        probabilities=probabilities,
        model_version=settings.ML_MODEL_VERSION,
    )


async def predict_image_bytes_async(image_bytes: bytes) -> PredictionResult:
    """Run TFLite inference off the asyncio event loop."""
    return await asyncio.to_thread(predict_image_bytes, image_bytes)
