import io
import json
import logging
import os
from contextlib import asynccontextmanager
from pathlib import Path

import gradio as gr
import httpx
import numpy as np
from fastapi import FastAPI, Header, HTTPException
from PIL import Image
from pydantic import BaseModel

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("ml-service")


@asynccontextmanager
async def lifespan(_app: FastAPI):
    """Muat model sekali saat proses service mulai."""
    _load_model()
    yield


# ── 1. Inisialisasi FastAPI ───────────────────────────────────────────────────
app = FastAPI(
    title="TiramSehat Scan ML Service",
    version="1.0.0",
    lifespan=lifespan,
)

_interpreter = None
_input_details = None
_output_details = None
_labels: list[str] = []
_preprocess: dict = {}


class PredictRequest(BaseModel):
    image_url: str


def _load_model():
    global _interpreter, _input_details, _output_details, _labels, _preprocess

    # Coba tflite_runtime, fallback ke ai-edge-litert atau tensorflow
    try:
        import tflite_runtime.interpreter as tflite
    except ImportError:
        try:
            import ai_edge_litert.interpreter as tflite
        except ImportError:
            try:
                import tensorflow.lite as tflite
            except ImportError:
                logger.error("Interpreter TFLite tidak ditemukan")
                return

    model_path = os.environ.get("MODEL_PATH", "model.tflite")
    candidate_paths = [
        model_path,
        str(Path(__file__).parent / "model.tflite"),
        "/app/model.tflite",
    ]

    found_path = None
    for p in candidate_paths:
        if os.path.exists(p):
            found_path = p
            break

    if not found_path:
        logger.warning("File model.tflite belum diunggah. Menunggu upload model...")
        return

    try:
        _interpreter = tflite.Interpreter(model_path=found_path)
        _interpreter.allocate_tensors()
        _input_details = _interpreter.get_input_details()[0]
        _output_details = _interpreter.get_output_details()[0]
        logger.info("Model TFLite berhasil dimuat dari %s", found_path)
    except Exception as exc:
        logger.error("Gagal memuat model TFLite dari %s: %s", found_path, exc)

    # Muat labels & konfigurasi preprocessing
    base_dir = Path(__file__).parent
    labels_file = base_dir / "labels.json"
    preprocess_file = base_dir / "preprocess.json"

    if labels_file.exists():
        with open(labels_file, "r", encoding="utf-8") as f:
            _labels = json.load(f)
    else:
        _labels = [
            "healthy", "green_mold", "black_bread_mold", "bacterial_brown_blotch",
            "cobweb_mold", "bacterial_wet_spot", "yellow_mold", "neurospora"
        ]

    if preprocess_file.exists():
        with open(preprocess_file, "r", encoding="utf-8") as f:
            _preprocess = json.load(f)
    else:
        _preprocess = {
            "input_height": 224,
            "input_width": 224,
            "scale": 0.007843137,
            "mean": [1.0, 1.0, 1.0]
        }

    if _output_details is not None and _labels:
        model_classes = int(_output_details["shape"][-1])
        if model_classes != len(_labels):
            logger.warning(
                "Jumlah kelas model (%s) tidak sama dengan labels.json (%s). "
                "Selaraskan labels.json dengan model yang di-deploy.",
                model_classes,
                len(_labels),
            )


def _run_inference_on_pil(img: Image.Image) -> tuple[str, float]:
    """Helper untuk menjalankan inferensi pada objek PIL Image."""
    if _interpreter is None:
        _load_model()
        if _interpreter is None:
            raise RuntimeError("Model TFLite belum tersedia di server")

    img_rgb = img.convert("RGB")
    w = int(_preprocess.get("input_width", _input_details["shape"][2]))
    h = int(_preprocess.get("input_height", _input_details["shape"][1]))
    resized = img_rgb.resize((w, h), Image.Resampling.BILINEAR)
    arr = np.asarray(resized, dtype=np.float32)

    if _input_details["dtype"] == np.uint8:
        arr = arr.astype(np.uint8)
    else:
        scale = float(_preprocess.get("scale", 1.0))
        mean = np.asarray(_preprocess.get("mean", [0.0, 0.0, 0.0]), dtype=np.float32)
        arr = (arr * scale) - mean

    tensor = np.expand_dims(arr, axis=0)
    _interpreter.set_tensor(_input_details["index"], tensor)
    _interpreter.invoke()

    output = _output_details or _interpreter.get_output_details()[0]
    raw = _interpreter.get_tensor(output["index"])[0]

    # Dekuantisasi jika model quantized (uint8 / int8)
    if output["dtype"] in (np.uint8, np.int8):
        out_scale, zero_point = output["quantization"]
        probs = (raw.astype(np.float32) - zero_point) * out_scale
    else:
        probs = raw.astype(np.float32)

    # Softmax jika output berupa logits
    if np.sum(probs) > 1.5 or np.min(probs) < 0.0:
        exp_probs = np.exp(probs - np.max(probs))
        probs = exp_probs / np.sum(exp_probs)

    idx = int(np.argmax(probs))
    confidence = max(0.0, min(1.0, float(probs[idx])))
    label = _labels[idx] if idx < len(_labels) else f"class_{idx}"
    return label, confidence


# ── 2. Endpoint REST API (Untuk Backend TiramSehat) ──────────────────────────

@app.get("/health")
def health():
    """Health check dipanggil oleh backend TiramSehat."""
    return {
        "status": "ok",
        "model_loaded": _interpreter is not None,
        "model_version": os.environ.get("MODEL_VERSION", "v1"),
        "labels_count": len(_labels),
    }


@app.post("/predict")
async def predict(req: PredictRequest, x_internal_secret: str = Header(default="")):
    """Endpoint inferensi yang dipanggil oleh FastAPI Backend."""
    expected_secret = os.environ.get("INTERNAL_SECRET", "")
    if expected_secret and x_internal_secret != expected_secret:
        raise HTTPException(status_code=401, detail="Unauthorized: invalid secret")

    try:
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.get(req.image_url)
            resp.raise_for_status()
    except Exception as exc:
        raise HTTPException(status_code=422, detail=f"Gagal mengunduh gambar: {exc}")

    try:
        img = Image.open(io.BytesIO(resp.content))
        label, confidence = _run_inference_on_pil(img)
        return {
            "label": label,
            "confidence": confidence,
            "model_version": os.environ.get("MODEL_VERSION", "v1"),
        }
    except Exception as exc:
        logger.exception("Inference failed")
        raise HTTPException(status_code=500, detail=f"Inference error: {exc}")


# ── 3. Web UI Gradio (Untuk Pengujian Manual di Browser) ──────────────────────

def gradio_predict(input_image):
    if input_image is None:
        return "Silakan unggah gambar terlebih dahulu", 0.0
    try:
        img = Image.fromarray(input_image)
        label, confidence = _run_inference_on_pil(img)
        return {label: confidence}
    except Exception as exc:
        return f"Error: {exc}", 0.0


demo = gr.Interface(
    fn=gradio_predict,
    inputs=gr.Image(label="Unggah Foto Baglog Jamur"),
    outputs=gr.Label(num_top_classes=3, label="Hasil Prediksi"),
    title="🍄 TiramSehat ML Service — Scanner Penyakit Baglog",
    description="Microservice ML Server-side berbasis TFLite untuk deteksi penyakit jamur tiram BUMDes Margomulyo.",
)

# Mount Gradio UI ke FastAPI app (dipisah dari root agar route API tidak tertutup)
app = gr.mount_gradio_app(app, demo, path="/ui")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=7860)
