---
title: TiramSehat Scan ML
emoji: 🍄
colorFrom: green
colorTo: green
sdk: gradio
sdk_version: 4.44.0
app_file: app.py
pinned: false
---

# TiramSehat Scan ML Service

Microservice inferensi server-side untuk klasifikasi penyakit baglog jamur tiram berbasis TFLite (FastAPI + Gradio).

> **Penting:** `labels.json` di folder ini harus berurutan sama dengan output
> model TFLite yang di-deploy. Artefak di `assets/models/` saat ini memakai 3
> kelas (`Healthy`, `Mixed_Infected`, `Single_Infected`), sedangkan
> `ml-service/labels.json` masih 8 kelas. Service akan mencatat warning saat
> jumlah kelas tidak cocok — selaraskan sebelum produksi.

## Endpoint API

- `GET /health`: Health check status model dan versi.
- `GET /ui`: UI Gradio untuk pengujian manual.
- `POST /predict`:
  - **Headers**: `X-Internal-Secret: <INTERNAL_SECRET>`
  - **Body**: `{"image_url": "https://res.cloudinary.com/.../scan.jpg"}`
  - **Response**: `{"label": "green_mold", "confidence": 0.94, "model_version": "v1"}`
