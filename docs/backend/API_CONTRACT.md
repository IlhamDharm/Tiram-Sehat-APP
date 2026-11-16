# Kontrak API TiramSehat

> Pelengkap dari [`ARCHITECTURE.md`](./ARCHITECTURE.md).
> Semua contoh menggunakan `https://api.tiramsehat.example.com/api/v1` sebagai base URL.

---

## 1. Konvensi Umum

### 1.1 Base & Header

```
Base URL : https://api.tiramsehat.example.com/api/v1
Auth     : Authorization: Bearer <access_token>
Body     : application/json; charset=utf-8
Request  : X-Request-ID: <uuid> (opsional, untuk korrelasi log)
Idempoten: Idempotency-Key: <uuid> (wajib untuk POST yang bisa duplikat)
```

### 1.2 Response Envelope

```jsonc
// Sukses
{ "data": { }, "meta": { "request_id": "req_01J…" } }

// Daftar
{ "data": [ ], "meta": { "request_id": "req_01J…", "limit": 20, "next_cursor": "…" } }

// Error
{ "error": { "code": "VALIDATION_ERROR", "message": "…", "details": [ ] } }
```

### 1.3 Kode Error

| HTTP | `code` | Keterangan |
|---|---|---|
| 400 | `VALIDATION_ERROR` | Input tidak valid. |
| 401 | `UNAUTHENTICATED` | Token tidak ada/kedaluwarsa. |
| 403 | `FORBIDDEN` | Tidak ada hak/scope kumbung. |
| 404 | `NOT_FOUND` | Resource tidak ditemukan. |
| 409 | `CONFLICT` | Duplikat / versi bentrok. |
| 423 | `LOCKED` | Resource dikunci. |
| 429 | `RATE_LIMITED` | Terlalu banyak request. |
| 500 | `INTERNAL_ERROR` | Kesalahan server. |

### 1.4 Paginasi

```
GET /scans?limit=20&cursor=eyJpZCI6…&status=action_required
```

- `limit` default 20, maks. 100.
- `next_cursor` = null berarti sudah halaman terakhir.
- Sort default `created_at DESC` (atau `scanned_at DESC` untuk scan).

---

## 2. Autentikasi

### 2.1 Login PIN

```http
POST /auth/login
Content-Type: application/json

{ "identifier": "081234567890", "pin": "123456" }
```

`identifier` bisa nomor WhatsApp **atau** ID Petani (`P-01`).

**Response 200**

```jsonc
{
  "data": {
    "access_token": "eyJhbGciOi…",
    "refresh_token": "rft_8f3a…",
    "expires_in": 900,
    "user": {
      "id": "01J…",
      "name": "Achmad Nabil",
      "farmer_id": "P-01",
      "role": "farmer",
      "kumbungs": [ { "id": "…", "code": "A", "name": "Kumbung Blok A", "is_primary": true } ]
    }
  },
  "meta": { "request_id": "req_…" }
}
```

**Error** 401 `UNAUTHENTICATED`, 429 `RATE_LIMITED`.

### 2.2 Login Google

```http
POST /auth/google
{ "id_token": "ya29.a0…" }
```

Alir: verifikasi `id_token` ke Google di backend → cari/buat `users` → terbitkan token.

### 2.3 Refresh Token

```http
POST /auth/refresh
{ "refresh_token": "rft_8f3a…" }
```

**Response 200** — token baru + refresh token baru (rotasi). Refresh token lama dicabut.

### 2.4 Logout

```http
POST /auth/logout
Authorization: Bearer <access_token>
{ "refresh_token": "rft_8f3a…" }
```

Mencabut refresh token; access token dibiarkan kedaluwarsa.

### 2.5 Ganti PIN

```http
PATCH /users/me/pin
Authorization: Bearer <access_token>

{ "current_pin": "123456", "new_pin": "654321" }
```

---

## 3. Profil & Preferensi

```http
GET /users/me
Authorization: Bearer <access_token>
```

```jsonc
{ "data": { "id": "01J…", "name": "…", "farmer_id": "P-01", "role": "farmer",
           "active_kumbung_id": "…", "active_batch_id": "…",
           "daily_check_target": 100, "default_price_per_kg": 15000 } }
```

```http
PATCH /users/me
{ "name": "Nama Baru", "active_kumbung_id": "…", "active_batch_id": "…",
  "daily_check_target": 120, "default_price_per_kg": 15500 }
```

---

## 4. Master: Kumbung, Rak, Varietas, Penyakit

### 4.1 Kumbung

```http
GET  /kumbungs
GET  /kumbungs/{id}
POST /kumbungs                 # officer/admin
PATCH /kumbungs/{id}           # officer/admin
```

```jsonc
// POST body
{ "code": "A", "name": "Kumbung Blok A", "address": "Margomulyo", "manager_id": "01J…" }
```

### 4.2 Rak

```http
GET  /kumbungs/{kumbung_id}/raks
POST /kumbungs/{kumbung_id}/raks
PATCH /raks/{id}
```

```jsonc
// POST body
{ "code": "B-04", "block": "B", "column_count": 8, "capacity": 200 }
```

### 4.3 Varietas

```http
GET /varieties
```

### 4.4 Penyakit & Langkah

```http
GET  /diseases?include=steps
GET  /diseases/{id}
POST /diseases                 # admin
PATCH /diseases/{id}           # admin
```

```jsonc
{
  "data": {
    "id": "01J…",
    "name": "Green Mold",
    "scientific_name": "Trichoderma sp.",
    "default_severity": "treatable",
    "steps": [
      { "step_order": 1, "title": "Pindahkan ke Rak Karantina", "description": "…" },
      { "step_order": 2, "title": "Kerik Lembut Spora Hijau", "description": "…" }
    ]
  }
}
```

---

## 5. Batch & Baglog

### 5.1 Batch

```http
GET  /batches?status=active&kumbung_id=…
POST /batches
GET  /batches/{id}
PATCH /batches/{id}
```

```jsonc
// POST body
{
  "code": "Batch Panen K-04 Margomulyo",
  "variety_id": "01J…",
  "kumbung_id": "01J…",
  "planted_at": "2026-09-02T00:00:00Z",
  "status": "active",
  "grade": "98% Grade A",
  "total_baglog": 2450
}
```

### 5.2 Baglog

```http
GET  /baglogs?batch_id=…&rak_id=…&status=sehat
POST /baglogs                 # bisa array untuk pendaftaran massal
GET  /baglogs/{id}
PATCH /baglogs/{id}/status
```

```jsonc
// POST /baglogs (bulk)
{
  "items": [
    { "batch_id": "…", "rak_id": "…", "column_no": 1, "code": "B-04-01", "status": "sehat" },
    { "batch_id": "…", "rak_id": "…", "column_no": 2, "code": "B-04-02", "status": "sehat" }
  ]
}
```

```http
PATCH /baglogs/{id}/status
{ "status": "bisa_diobati" }
```

**Nilai `baglogs.status`:** `sehat` · `bisa_diobati` · `sedang_diobati` · `afkir` · `dibuang` · `panen`.

---

## 6. Pencatatan Panen

```http
GET  /harvests?from=2026-11-01&to=2026-11-13&kumbung_id=…
POST /harvests
GET  /harvests/{id}
PATCH /harvests/{id}          # koreksi
DELETE /harvests/{id}
```

```jsonc
// POST /harvests
{
  "batch_id": "01J…",
  "kumbung_id": "01J…",
  "harvested_at": "2026-11-13T07:30:00+07:00",
  "weight_kg": 18.5,
  "price_per_kg": 15000,
  "note": "Panen petik ke-3 kumbung selatan"
}
```

**Response 201**

```jsonc
{
  "data": {
    "id": "01J…",
    "weight_kg": 18.5,
    "price_per_kg": 15000,
    "gross_income": 277500,     // dihitung server
    "harvested_at": "2026-11-13T07:30:00+07:00"
  }
}
```

> `gross_income` dihitung server (`weight_kg × price_per_kg`) — jangan dipercaya dari client.

---

## 7. Scan & Tindak Lanjut

### 7.1 Daftar Scan

```http
GET /scans?status=action_required&rak_id=…&disease_id=…&from=…&to=…&limit=20&cursor=…
```

**Nilai `scans.status`:** `action_required` · `in_treatment` · `recovered` · `discarded` · `archived`.

### 7.2 Simpan Scan

```http
POST /scans
Idempotency-Key: 7c9e6679-7425-40de-944b-e07fc1f90ae7
```

```jsonc
{
  "rak_id": "01J…",
  "column_no": 3,
  "batch_id": "01J…",
  "disease_id": "01J…",
  "confidence": 0.942,
  "severity": "treatable",
  "infection_location": "Cincin & Leher Baglog",
  "scan_method": "camera",
  "scanned_at": "2026-11-13T09:15:00+07:00",
  "image_public_id": "tiramsehat/scans/2026/11/scan_…",
  "image_url": "https://res.cloudinary.com/…/scan_….jpg",
  "image_version": 1731561300,
  "image_thumbnail_url": "https://res.cloudinary.com/…/w_400,q_auto,f_webp/scan_…"
}
```

**Response 201**

```jsonc
{
  "data": {
    "id": "01J…",
    "code": "SCAN-0001",
    "diagnosis_name": "Green Mold",
    "scientific_name": "Trichoderma sp.",
    "confidence": 0.942,
    "severity": "treatable",
    "status": "action_required",
    "steps": [ { "step_order": 1, "title": "…", "description": "…" } ]
  }
}
```

### 7.3 Detail & Ubah Status

```http
GET   /scans/{id}
PATCH /scans/{id}
```

```jsonc
// PATCH body
{ "status": "in_treatment", "status_note": "Sudah dipindah ke karantina", "status_tag": "Perawatan Ringan" }
```

### 7.4 Catat Tindakan (Treatment Log)

```http
POST /scans/{id}/actions
```

```jsonc
{
  "action_type": "status_change",
  "to_status": "recovered",
  "note": "Miselium kembali menutup 95%",
  "tag": "Karantina Tuntas"
}
```

**`action_type`:** `note` · `status_change` · `treatment` · `discard` · `recover` · `archive`.

### 7.5 Hapus Scan

```http
DELETE /scans/{id}
```

Backend menghapus/mengarsipkan scan dan **best-effort menghapus gambar** di Cloudinary.

---

## 8. Upload Gambar (Cloudinary)

### 8.1 Minta Signature

```http
POST /uploads/sign
Authorization: Bearer <access_token>
```

```jsonc
{
  "type": "scan",                 // scan | avatar | batch
  "content_type": "image/jpeg",
  "size": 2456789
}
```

**Response 200**

```jsonc
{
  "data": {
    "cloud_name": "your-cloud",
    "api_key": "1234567890",
    "upload_preset": "tiramsehat_uploads",
    "folder": "tiramsehat/scans/2026/11",
    "public_id": "tiramsehat/scans/2026/11/scan_01J…_…",
    "timestamp": 1731561300,
    "signature": "a1b2c3…",
    "expires_at": 1731561600
  }
}
```

Client mengunggah langsung ke:

```
POST https://api.cloudinary.com/v1_1/{cloud_name}/image/upload
```

### 8.2 Verifikasi Upload (Opsional)

```http
POST /uploads/verify
{ "public_id": "tiramsehat/scans/2026/11/scan_…" }
```

Backend memeriksa keberadaan via Cloudinary Admin API dan mengembalikan metadata normal.

---

## 9. Laporan

### 9.1 Harian

```http
GET /reports/daily?date=2026-11-13
```

```jsonc
{
  "data": {
    "date": "2026-11-13",
    "total_kg": 24.5,
    "delta_kg": 4.2,
    "delta_pct": 18.0,
    "sales": 367500,
    "price_per_kg": 15000
  }
}
```

### 9.2 Tren Kualitas

```http
GET /reports/trend?weeks=4
```

```jsonc
{
  "data": {
    "points": [
      { "label": "M1", "value": 82.0 },
      { "label": "M2", "value": 85.0 },
      { "label": "M3", "value": 88.0 },
      { "label": "M4", "value": 89.4 }
    ],
    "delta": 7.4
  }
}
```

### 9.3 Bulanan

```http
GET /reports/monthly?month=2026-11
```

```jsonc
{
  "data": {
    "month": "2026-11",
    "income": 8420000,
    "total_kg": 561.3,
    "estimated_loss": 420000,
    "loss_reduced_pct": 65,
    "batch": {
      "code": "Batch Panen K-04 Margomulyo",
      "variety": "Florida Putih",
      "day": 42,
      "grade": "98% Grade A",
      "weighed_at": "07:30 WIB"
    }
  }
}
```

### 9.4 Ekspor

```http
POST /reports/exports
{ "period_type": "month", "period_start": "2026-11-01", "period_end": "2026-11-30", "format": "csv" }
```

**Response 201**

```jsonc
{ "data": { "id": "01J…", "download_url": "https://…/reports/….csv", "expires_at": "…" } }
```

---

## 10. Sinkronisasi Offline-First (Opsional)

### 10.1 Ambil Perubahan

```http
GET /sync/changes?since=2026-11-13T00:00:00Z&limit=200
```

```jsonc
{
  "data": {
    "changes": [ { "table": "scans", "operation": "upsert", "row": { } } ],
    "next_cursor": "eyJ1cGRhdGVkX2F0Ijoi…",
    "has_more": true
  }
}
```

### 10.2 Kirim Perubahan

```http
POST /sync
Idempotency-Key: <uuid>
```

```jsonc
{
  "changes": [
    { "table": "harvests", "operation": "upsert", "row": { "id": "…", "updated_at": "…" } },
    { "table": "scans", "operation": "delete", "row": { "id": "…" } }
  ]
}
```

Server memproses dalam satu transaksi dan mengembalikan konflik bila ada.

---

## 11. Health Check

```http
GET /health
```

```jsonc
{ "data": { "status": "ok", "db": "up", "cloudinary": "up", "version": "1.0.0" } }
```

---

## 12. Ringkasan Endpoint

| Grup | Method & Path |
|---|---|
| Auth | `POST /auth/login` · `POST /auth/google` · `POST /auth/refresh` · `POST /auth/logout` |
| Users | `GET /users/me` · `PATCH /users/me` · `PATCH /users/me/pin` |
| Kumbung | `GET /kumbungs` · `GET /kumbungs/{id}` · `POST /kumbungs` · `PATCH /kumbungs/{id}` |
| Rak | `GET /kumbungs/{id}/raks` · `POST /kumbungs/{id}/raks` · `PATCH /raks/{id}` |
| Varietas | `GET /varieties` |
| Penyakit | `GET /diseases` · `GET /diseases/{id}` · `POST /diseases` · `PATCH /diseases/{id}` |
| Batch | `GET /batches` · `POST /batches` · `GET /batches/{id}` · `PATCH /batches/{id}` |
| Baglog | `GET /baglogs` · `POST /baglogs` · `PATCH /baglogs/{id}/status` |
| Panen | `GET /harvests` · `POST /harvests` · `PATCH /harvests/{id}` · `DELETE /harvests/{id}` |
| Scan | `GET /scans` · `POST /scans` · `GET /scans/{id}` · `PATCH /scans/{id}` · `POST /scans/{id}/actions` · `DELETE /scans/{id}` |
| Upload | `POST /uploads/sign` · `POST /uploads/verify` |
| Laporan | `GET /reports/daily` · `GET /reports/trend` · `GET /reports/monthly` · `POST /reports/exports` |
| Sync | `GET /sync/changes` · `POST /sync` |
| Health | `GET /health` |
