# Arsitektur Backend TiramSehat

> **Status implementasi:** dokumen ini adalah rancangan awal (Node/TypeScript).
> Backend yang berjalan saat ini memakai **Python/FastAPI + psycopg + Neon**.
> Lihat [`backend/README.md`](../../backend/README.md) untuk struktur aktual.

> Stack: **PostgreSQL (Neon)** + **Cloudinary** untuk penyimpanan gambar.
> Dokumen ini berisi best practice rancangan backend: lapisan arsitektur, auth, integrasi Neon, integrasi Cloudinary, kontrak API, keamanan, dan sinkronisasi offline-first.

Related:
- Rancangan ERD & skema: [`../database/ERD.md`](../database/ERD.md)
- Skema Postgres/Neon: [`../database/schema.postgres.sql`](../database/schema.postgres.sql)
- Panduan Neon: [`../database/NEON.md`](../database/NEON.md)
- Kontrak API: [`API_CONTRACT.md`](./API_CONTRACT.md)

---

## 1. Tujuan & Lingkup

Backend TiramSehat bertugas sebagai **sumber kebenaran (source of truth)** untuk:

- Autentikasi & otorisasi petani/pengurus BUMDes.
- Pencatatan panen, scan diagnosa, tindak lanjut, dan ringkasan laporan.
- Orkestrasi penyimpanan gambar ke **Cloudinary** (tidak pernah mengekspos secret ke aplikasi).
- Menyediakan API yang konsisten untuk aplikasi Flutter (offline-first) dan sinkronisasi data.

```
┌────────────────────┐        HTTPS/JSON         ┌────────────────────────┐
│  Aplikasi Flutter  │ ────────────────────────► │  Backend TiramSehat     │
│  + SQLite lokal    │ ◄──────────────────────── │  (Node/TypeScript)      │
│  (offline-first)   │                           │                        │
└────────────────────┘                           │  ┌──────────────────┐  │
                                                 │  │ Cloudinary       │  │
                                                 │  │ (upload gambar)  │  │
                                                 │  └──────────────────┘  │
                                                 │  ┌──────────────────┐  │
                                                 │  │ Neon PostgreSQL  │  │
                                                 │  │ (source of truth)│  │
                                                 │  └──────────────────┘  │
                                                 └────────────────────────┘
```

> **Aturan emas:** jangan pernah menaruh `DATABASE_URL`, `JWT_SECRET`, atau `CLOUDINARY_API_SECRET` di dalam aplikasi mobile. Semua lewat backend.

---

## 2. Pilihan Stack

### Rekomendasi

| Lapisan | Teknologi | Alasan |
|---|---|---|
| Bahasa | **TypeScript** (Node 20+) | Typing, ekosistem Neon/Cloudinary, mudah diuji. |
| Framework HTTP | **Fastify** (atau **Hono** untuk serverless) | Cepat, schema validation bawaan, plugin. |
| DB client | **`postgres.js`** (container) / **`@neondatabase/serverless`** (serverless) | Support TLS + pool; official Neon. |
| ORM/Query | **Drizzle ORM** atau SQL mentah via `postgres.js` | Drizzle type-safe; SQL mentah tetap boleh untuk query kompleks. |
| Migrasi | **node-pg-migrate** atau **drizzle-kit** | Migrasi berversi, idempoten. |
| Validasi | **Zod** | Validasi boundary + inference tipe. |
| Auth | **JWT** (access) + refresh token tersimpan + **argon2id/bcrypt** untuk PIN. | Stateless + revocation. |
| Storage | **Cloudinary** (SDK Admin untuk signature/delete; upload direct dari client). | CDN, transformasi, manajemen aset. |
| Logging | **pino** (JSON) | Structured logging. |
| Error tracking | **Sentry** (opsional) | Observability. |

### Alternatif

| Opsi | Kapan dipilih |
|---|---|
| **Dart + Shelf** (backend Dart) | Ingin berbagi model/validasi dengan Flutter. Ekosistem Neon/Cloudinary lebih kecil, jadi butuh HTTP SDK sendiri. |
| **Express + Prisma** | Tim sudah familiar Prisma; Prisma support Postgres/Neon. |
| **NestJS** | Proyek besar dengan banyak modul; lebih opinionated. |
| **PostgREST / Hasura** | Ingin API otomatis dari skema tanpa menulis backend; tetap perlu layer auth/upload. |

---

## 3. Prinsip Desain

1. **Layered / clean architecture** — HTTP, service, repository terpisah.
2. **Stateless** — sesi di client (JWT + refresh token), server bisa diskalakan horizontal.
3. **Validasi di boundary** — semua input divalidasi dengan Zod sebelum masuk service.
4. **Parameterized query** — tidak ada string concatenation SQL.
5. **Fail fast** — konfigurasi divalidasi saat startup; error log jelas.
6. **Idempotent** — operasi tulis mendukung `Idempotency-Key` untuk retry sinkronisasi.
7. **Least privilege** — peran DB & API berbeda (migration vs app).
8. **Aman default** — TLS wajib, secret di server, upload preset terbatas.

---

## 4. Arsitektur Bertingkat

```
Request
  │
  ▼
┌─────────────────────────────────────────────┐
│ HTTP Layer (Fastify)                        │
│  - middleware: request-id, logger, rate-limit│
│  - CORS, body limit, helmet                 │
│  - plugin: auth, error handler              │
└─────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────────┐
│ Route / Controller                          │
│  - parse & validate (Zod)                   │
│  - terapkan authn/authz                     │
│  - format response envelope                 │
│  - TIDAK ada business logic                 │
└─────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────────┐
│ Service (business logic)                    │
│  - aturan bisnis, transaksi DB              │
│  - orkestrasi Cloudinary                    │
│  - TIDAK tahu HTTP                          │
└─────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────────┐
│ Repository (data access)                    │
│  - SQL / Drizzle                            │
│  - parameterized queries                    │
│  - TIDAK ada business logic                 │
└─────────────────────────────────────────────┘
  │
  ▼
Neon PostgreSQL
```

**Aturan dependensi:** `route → service → repository → db`. Jangan membalik arah (db tidak boleh memanggil service).

---

## 5. Struktur Repositori (Contoh)

```
backend/
├── src/
│   ├── config/
│   │   ├── env.ts                # validasi env dengan Zod (fail fast)
│   │   └── constants.ts
│   ├── app.ts                    # build Fastify app (tanpa listen)
│   ├── server.ts                 # bootstrap + listen + graceful shutdown
│   ├── plugins/
│   │   ├── db.ts                 # pool neon + helper transaksi
│   │   ├── auth.ts               # dekode JWT, requireRole, requireKumbung
│   │   ├── cloudinary.ts         # signed upload + delete
│   │   ├── error-handler.ts      # AppError → HTTP response
│   │   └── request-context.ts    # request id, user
│   ├── modules/
│   │   ├── auth/
│   │   │   ├── auth.routes.ts
│   │   │   ├── auth.service.ts
│   │   │   ├── auth.repository.ts
│   │   │   └── auth.dto.ts       # Zod schemas
│   │   ├── users/
│   │   ├── kumbungs/
│   │   ├── raks/
│   │   ├── batches/
│   │   ├── baglogs/
│   │   ├── harvests/
│   │   ├── scans/
│   │   ├── treatments/
│   │   ├── reports/
│   │   └── uploads/
│   └── common/
│       ├── db/
│       │   ├── client.ts
│       │   ├── transaction.ts
│       │   └── pagination.ts
│       ├── http/
│       │   ├── envelope.ts
│       │   ├── errors.ts
│       │   └── validate.ts
│       ├── storage/
│       │   └── cloudinary.ts
│       └── logger.ts
├── migrations/                   # node-pg-migrate / drizzle
├── tests/
│   ├── unit/
│   └── integration/
├── package.json
├── tsconfig.json
├── .env.example
└── README.md
```

---

## 6. Konfigurasi & Secrets

Validasi env **saat startup** (Zod), gagal langsung jika ada yang kurang:

```ts
// src/config/env.ts
import { z } from 'zod';

export const env = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(3000),

  // Neon — direct untuk migrasi, pooled untuk aplikasi
  DATABASE_URL: z.string().url(),
  DATABASE_URL_POOLED: z.string().url().optional(),

  // Auth
  JWT_SECRET: z.string().min(32),
  JWT_ACCESS_TTL_SECONDS: z.coerce.number().default(900),   // 15 menit
  REFRESH_TTL_SECONDS: z.coerce.number().default(2_592_000), // 30 hari
  PIN_HASH_ROUNDS: z.coerce.number().default(12),

  // Cloudinary
  CLOUDINARY_CLOUD_NAME: z.string(),
  CLOUDINARY_API_KEY: z.string(),
  CLOUDINARY_API_SECRET: z.string(),     // SERVER ONLY
  CLOUDINARY_UPLOAD_PRESET: z.string(),  // preset unsigned untuk client
  CLOUDINARY_FOLDER: z.string().default('tiramsehat'),

  CORS_ORIGIN: z.string().default('http://localhost:3000'),
}).parse(process.env);
```

```bash
# .env.example
DATABASE_URL=postgresql://user:pass@ep-xxx.neon.tech/neondb?sslmode=require
DATABASE_URL_POOLED=postgresql://user:pass@ep-xxx-pooler.neon.tech/neondb?sslmode=require
JWT_SECRET=change-me-min-32-chars
CLOUDINARY_CLOUD_NAME=your-cloud
CLOUDINARY_API_KEY=your-key
CLOUDINARY_API_SECRET=your-secret
CLOUDINARY_UPLOAD_PRESET=tiramsehat_uploads
CLOUDINARY_FOLDER=tiramsehat
```

> `.env` masuk `.gitignore`. Gunakan secret manager (Vercel/Render env, Doppler, atau Neon integration) di produksi.

---

## 7. Integrasi Neon (PostgreSQL)

### 7.1 Koneksi

| Runtime | Client | Koneksi |
|---|---|---|
| Container / long-running (Node) | `postgres.js` | Pool, pakai **pooled endpoint** (`-pooler`). |
| Serverless function (Vercel/Edge/Cloudflare) | `@neondatabase/serverless` | HTTP driver, **pooled endpoint**. |
| Migrasi / DDL | `psql` / migration tool | **Direct endpoint** (bukan pooler). |

```ts
// src/common/db/client.ts
import postgres from 'postgres';

export const sql = postgres(env.DATABASE_URL_POOLED ?? env.DATABASE_URL, {
  ssl: 'require',            // Neon wajib TLS
  max: 10,                   // sesuaikan kapasitas pool
  idle_timeout: 20,
  connect_timeout: 10,
  prepare: false,            // penting jika memakai pooler transaction mode
});
```

### 7.2 Transaksi

```ts
// src/common/db/transaction.ts
export async function withTransaction<T>(fn: (tx: Tx) => Promise<T>): Promise<T> {
  return sql.transaction(async (tx) => fn(tx as Tx)) as Promise<T>;
}
```

Gunakan transaksi untuk operasi multi-tulis (mis. simpan scan + snapshot langkah + update status baglog).

### 7.3 Retry & Resiliensi

Neon bisa mengembalikan error sesaat (`ECONNRESET`, `0A000`, compute waking). Tambahkan retry dengan exponential backoff untuk query read/write idempotent:

```ts
async function withRetry<T>(fn: () => Promise<T>, retries = 3): Promise<T> {
  let attempt = 0;
  for (;;) {
    try { return await fn(); }
    catch (err) {
      if (attempt >= retries || !isTransient(err)) throw err;
      await sleep(2 ** attempt * 100 + Math.random() * 50);
      attempt++;
    }
  }
}
```

### 7.4 Migrasi & Branching

- Migrasi dijalankan di **branch terpisah**: `main` (produksi), `dev` (pengembangan), `test` (CI).
- Perubahan skema harus **backward-compatible** (expand → migrate → contract) agar deploy zero-downtime.
- Seed data master (kumbung, rak, varietas, penyakit, langkah) di migration/seed.

### 7.5 Peran & Hak Akses DB

| Role | Hak |
|---|---|
| `migrator` | DDL + seed (hanya untuk migrasi). |
| `app` | `SELECT/INSERT/UPDATE/DELETE` pada tabel operasional; **tidak** boleh `DROP/ALTER`. |
| `readonly` | `SELECT` saja (untuk reporting/BI). |

Opsional: aktifkan **Row Level Security (RLS)** bila satu database dipakai banyak tenant.

---

## 8. Autentikasi & Otorisasi

### 8.1 Model

- `users` — identitas, `pin_hash`, `role`, `google_id`.
- `refresh_tokens` — token hash, expiry, rotasi, revoke, metadata.

### 8.2 Alur Login (PIN / No. WhatsApp)

```
1. Client → POST /api/v1/auth/login { identifier, pin }
2. Backend cari user by phone/farmer_id
3. Verifikasi PIN (argon2id / bcrypt)
4. Rate-limit & audit
5. Buat access token (JWT 15 menit) + refresh token (random 32+ byte)
6. Simpan HASH refresh token + expiry + user_agent/ip
7. Return { access_token, refresh_token, expires_in, user }
```

### 8.3 Google Sign-In

```
1. Client login Google → dapat id_token
2. POST /api/v1/auth/google { id_token }
3. Backend verifikasi ke Google (audience, issuer, expiry)
4. Cari user by google_id/email; bila belum ada → buat user (role farmer)
5. Terbitkan token seperti login biasa
```

> Verifikasi **selalu di backend** — jangan percaya klaim client.

### 8.4 Refresh & Rotasi

- Access token pendek (15–30 menit).
- Refresh token panjang (7–30 hari), **rotasi** setiap dipakai: token lama dicabut, `replaced_by` diisi.
- Deteksi penggunaan token yang sudah dicabut → **revoke seluruh family** (indikasi pencurian).
- Logout → set `revoked_at`.

### 8.5 Otorisasi

- **RBAC**: `farmer` < `officer` < `admin`.
- **Scoping kumbung**: petani hanya bisa mengakses kumbung yang di-assign (`user_kumbung_assignments`).
- Middleware berurutan: `authenticate` → `requireRole(...)` → `requireKumbungAccess(kumbungId)`.

---

## 9. Integrasi Cloudinary (Penyimpanan Gambar)

### 9.1 Prinsip

- `CLOUDINARY_API_SECRET` **hanya di backend**.
- Client tidak mengunggah ke backend (hemat bandwidth), melainkan **direct upload** ke Cloudinary memakai **upload preset + signature** yang dibangkitkan backend.
- Backend menyimpan metadata gambar di tabel (`image_public_id`, `image_url`, `image_version`, `image_thumbnail_url`).
- Hapus/invalidasi gambar di Cloudinary saat data dihapus (best effort).

### 9.2 Alur Upload (Signed Direct Upload) — Rekomendasi

```
┌──────────┐  1. minta signature      ┌──────────┐
│  Flutter │ ───────────────────────► │ Backend  │
│          │ ◄─────────────────────── │          │
│          │  2. signature+public_id  │          │
│          │                          │          │
│          │  3. POST file ke Cloudinary (api_key, signature, preset)
│          │ ─────────────────────────────────────────────► ┌────────────┐
│          │ ◄───────────────────────────────────────────── │ Cloudinary │
│          │  4. public_id, secure_url, version              └────────────┘
│          │                          │
│          │  5. simpan scan + metadata gambar
│          │ ───────────────────────► │ Backend  │
└──────────┘                          └──────────┘
```

**Langkah 1–2: backend membangkitkan signature**

```ts
// src/common/storage/cloudinary.ts
import crypto from 'node:crypto';

export function signUpload(params: Record<string, string | number>) {
  const toSign = Object.keys(params)
    .sort()
    .map((k) => `${k}=${params[k]}`)
    .join('&');

  const signature = crypto
    .createHash('sha1')
    .update(toSign + env.CLOUDINARY_API_SECRET)
    .digest('hex');

  return signature;
}
```

```ts
// POST /api/v1/uploads/sign
const timestamp = Math.floor(Date.now() / 1000);
const publicId = `scan_${user.id}_${crypto.randomUUID()}`;
const folder = `${env.CLOUDINARY_FOLDER}/scans/${new Date().getFullYear()}`;

const signature = signUpload({ folder, public_id: publicId, timestamp });

return {
  cloud_name: env.CLOUDINARY_CLOUD_NAME,
  api_key: env.CLOUDINARY_API_KEY,
  upload_preset: env.CLOUDINARY_UPLOAD_PRESET,
  folder,
  public_id: publicId,
  timestamp,
  signature,
  expires_at: timestamp + 300, // 5 menit
};
```

**Langkah 3–4: client upload** (contoh Android/iOS/Dart `http` multipart):

```
POST https://api.cloudinary.com/v1_1/{cloud_name}/image/upload
multipart:
  file          = <bytes>
  api_key       = <api_key>
  timestamp     = <timestamp>
  signature     = <signature>
  folder        = <folder>
  public_id     = <public_id>
  upload_preset = <upload_preset>   # bila preset unsigned
```

Cloudinary membalas:

```json
{
  "public_id": "tiramsehat/scans/2026/scan_...",
  "secure_url": "https://res.cloudinary.com/.../upload/v1731.../scan_...jpg",
  "version": 1731...,
  "width": 1280,
  "height": 720,
  "format": "jpg",
  "bytes": 2456789
}
```

**Langkah 5: simpan ke `scans`** dengan metadata dari Cloudinary (normalisasi di backend).

### 9.3 Struktur Folder & Konvensi

```
tiramsehat/
├── scans/
│   └── 2026/11/            # per bulan
├── avatars/
└── batches/
```

- `public_id` unik: `{type}_{user_id}_{uuid}`.
- `use_filename: false`, `unique_filename: true`, `overwrite: false`.
- `resource_type: image`.

### 9.4 Transformasi & URL

- Thumbnail: `https://res.cloudinary.com/<cloud>/image/upload/w_400,q_auto,f_webp/<public_id>`
- Full: `.../upload/q_auto,f_webp/<public_id>`
- Simpan URL hasil transformasi di `image_thumbnail_url`.
- Gunakan `f_auto`/`f_webp` + `q_auto` untuk hemat bandwidth.
- Untuk gambar privat, gunakan **signed URL** (`sign_url=true`).

### 9.5 Validasi & Keamanan Upload

| Kontrol | Keterangan |
|---|---|
| Autentikasi | `POST /uploads/sign` wajib login. |
| Rate limit | Batasi jumlah request signature per menit. |
| Upload preset | Gunakan preset **unsigned** dengan batas ukuran/format/folder. |
| Allowed types | `image/jpeg`, `image/png`, `image/webp` (maks. 5–10 MB). |
| Filename | Jangan pakai nama asli client untuk `public_id`. |
| Verifikasi | Opsional: panggil Admin API `resources/{public_id}` untuk memastikan upload valid. |
| Moderation | Aktifkan `moderation: auto/manual` bila perlu. |
| Expiry signature | 5–10 menit. |
| Delete | Saat scan dihapus → `api.destroy(public_id)` (best effort, jangan gagalkan transaksi DB). |

### 9.6 Alternatif: Backend Proxy Upload

Client → backend (multipart) → Cloudinary → backend simpan metadata.
- **Kelebihan:** kontrol penuh, bisa validasi/scan virus, tidak expose preset.
- **Kekurangan:** bandwidth & memory backend, timeout lebih lama.
- Cocok bila ukuran file kecil dan jumlah user terbatas.

---

## 10. Desain API

### 10.1 Konvensi

- Base URL: `/api/v1`.
- JSON, `Content-Type: application/json` (kecuali upload).
- Header: `Authorization: Bearer <access_token>`.
- `Idempotency-Key: <uuid>` pada POST yang berisiko duplikat (harvest, scan, sync).
- `X-Request-ID` untuk korrelasi log.

### 10.2 Response Envelope

```jsonc
// Sukses
{
  "data": { "id": "…", "weight_kg": 18.5, "gross_income": 277500 },
  "meta": { "request_id": "req_…" }
}

// Daftar (paginasi)
{
  "data": [ /* … */ ],
  "meta": { "limit": 20, "next_cursor": "eyJpZCI6…" }
}

// Error
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Data tidak valid",
    "details": [ { "field": "weight_kg", "issue": "harus lebih dari 0" } ]
  }
}
```

### 10.3 Kode Error

| HTTP | `code` | Kapan |
|---|---|---|
| 400 | `VALIDATION_ERROR` | Input tidak valid. |
| 401 | `UNAUTHENTICATED` | Token tidak ada/kedaluwarsa. |
| 403 | `FORBIDDEN` | Tidak punya hak/scope kumbung. |
| 404 | `NOT_FOUND` | Resource tidak ada. |
| 409 | `CONFLICT` | Duplikat/versi bentrok. |
| 429 | `RATE_LIMITED` | Terlalu banyak request. |
| 500 | `INTERNAL_ERROR` | Kesalahan server. |

### 10.4 Paginasi & Filter

- Paginasi **cursor** (stabil untuk data berubah) atau offset sederhana.
- `limit` default 20, maks. 100.
- Filter/sort hanya pada kolom yang di-whitelist.
- Contoh: `GET /api/v1/scans?status=action_required&rak_id=…&limit=20&cursor=…`

---

## 11. Daftar Endpoint (Ringkas)

Detail lengkap di [`API_CONTRACT.md`](./API_CONTRACT.md).

| Grup | Endpoint |
|---|---|
| Auth | `POST /auth/login`, `POST /auth/google`, `POST /auth/refresh`, `POST /auth/logout` |
| Users | `GET /users/me`, `PATCH /users/me` |
| Kumbung/Rak | `GET/POST /kumbungs`, `GET/PATCH /kumbungs/:id`, `GET/POST /raks` |
| Batch/Baglog | `GET/POST /batches`, `PATCH /batches/:id`, `GET/POST /baglogs`, `PATCH /baglogs/:id/status` |
| Panen | `GET/POST /harvests`, `GET /harvests/summary` |
| Scan | `GET/POST /scans`, `GET/PATCH /scans/:id`, `POST /scans/:id/actions` |
| Upload | `POST /uploads/sign`, `POST /uploads/verify` |
| Laporan | `GET /reports/daily`, `GET /reports/trend`, `GET /reports/monthly` |
| Sync | `POST /sync` (opsional) |
| Health | `GET /health` |

---

## 12. Validasi & Error Handling

```ts
// src/common/http/errors.ts
export class AppError extends Error {
  constructor(
    public statusCode: number,
    public code: string,
    message: string,
    public details?: unknown,
  ) { super(message); }
}

// Zod → AppError(400, 'VALIDATION_ERROR')
```

- Satu central error handler; jangan bocor stack trace ke client.
- Log error lengkap (termasuk `request_id`) di server.
- Validasi di controller, business rule di service.

---

## 13. Logging, Observability & Audit

- **Structured JSON log** (pino) dengan `request_id`, `user_id`, `kumbung_id`, durasi.
- **Audit trail**: `treatment_logs` mencatat setiap perubahan status/tindakan (siapa, kapan, dari status apa ke apa).
- **Metrics**: latency endpoint, error rate, pool DB, Cloudinary usage.
- **Tracing**: OpenTelemetry (opsional).
- **Health check**: `GET /health` (DB ping + status dependensi).

---

## 14. Keamanan — Checklist

| Area | Praktik |
|---|---|
| Transport | HTTPS wajib, HSTS. |
| CORS | Whitelist origin aplikasi saja. |
| AuthN | JWT pendek + refresh token hashed + rotasi + revoke. |
| AuthZ | RBAC + scope kumbung. |
| Secrets | Server-only, secret manager, `.env` di-ignore. |
| Database | Parameterized query; role least privilege; SSL. |
| Rate limit | Global, login, upload. |
| Upload | Preset terbatas, tipe/ukuran, signature ber-expiry. |
| Input | Zod + body size limit + content-type check. |
| Dependency | `npm audit`, pin versi, minimal dependency. |
| Headers | `helmet` (X-Content-Type-Options, dsb.). |
| Logging | Jangan log secret/PIN/token. |
| Error | Pesan generik ke client, detail di log. |

---

## 15. Sinkronisasi Offline-First

Aplikasi Flutter menyimpan data di SQLite lokal (`schema.sql`). Backend menyimpan yang sama di Neon. Strategi:

1. **Cursor `updated_at`** — client mengirim `since`; server mengembalikan perubahan setelahnya.
2. **Idempotency-Key** — setiap POST client menyertakan key; server menyimpan/menolak duplikat.
3. **Soft delete** — tambahkan `deleted_at` pada tabel transaksi agar penghapusan ikut tersinkron.
4. **Conflict resolution** — server menang untuk data transaksi (panen/status); client menang untuk draf scan lokal.
5. **Batch sync** — `POST /sync` menerima array perubahan; server memproses dalam satu transaksi.
6. **Sinkron gambar** — gambar diunggah saat online; `image_local_path` dipakai offline, lalu diganti `image_url`.

> Rekomendasi evolusi skema: tambahkan `deleted_at TIMESTAMPTZ` pada `harvests`, `scans`, `baglogs`, `batches`, dan tabel master yang perlu sinkron.

---

## 16. Testing

| Jenis | Lingkungan | Fokus |
|---|---|---|
| Unit | Node | Service, validasi, util. |
| Integration | Neon branch `test` (ephemeral) | Repository + migration + API. |
| Contract | — | Cocokkan API dengan OpenAPI. |
| E2E | Staging | Alur login → scan → upload → panen → laporan. |

- Jalankan migrasi di branch `test` sebelum test.
- Bersihkan data test (truncate) per suite.
- Jangan pernah menjalankan test ke branch `main`.

---

## 17. CI/CD & Deployment

```
PR → lint → typecheck → unit test → integration test (branch test)
    → build → deploy staging → smoke test → deploy produksi
```

- **Migrasi**: jalan di pipeline dengan role `migrator`, **expand-contract**.
- **Deploy backend**: Vercel/Render/Railway/Fly; atau container.
- **Neon**: produksi branch `main`; `DATABASE_URL` + pooled URL disimpan sebagai secret.
- **Cloudinary**: preset produksi vs staging; pantau kuota.
- **Rollback**: migrasi harus reversible; simpan versi migration.

---

## 18. Evolusi Skema yang Direkomendasikan

| Perubahan | Alasan |
|---|---|
| `deleted_at` pada tabel transaksi | Sync & restore. |
| `updated_at` trigger (`BEFORE UPDATE`) | Konsistensi timestamp untuk cursor sync. |
| Tabel `audit_logs` (opsional) | Audit lebih luas (login, perubahan master). |
| View/materialized view laporan | Query ringkasan kompleks yang sering dipakai. |
| Index tambahan | Sesuaikan query pattern nyata (mis. `(kumbung_id, status, scanned_at)`). |

---

## 19. Roadmap Implementasi Backend

| Fase | Cakupan |
|---|---|
| **1. Fondasi** | Setup project, env, koneksi Neon, migration, health check, error handler. |
| **2. Auth** | users + refresh_tokens, login PIN, Google, RBAC, scope kumbung. |
| **3. Master** | kumbungs, raks, varieties, diseases + disease_steps (seed). |
| **4. Operasional** | harvests, batches, baglogs, scans + treatments. |
| **5. Upload** | Cloudinary signature + verify + delete. |
| **6. Laporan** | daily/trend/monthly + CSV/PDF. |
| **7. Sync** | cursor + idempotency + soft delete. |
| **8. Observability & hardening** | logging, metrics, rate limit, Sentry, audit. |

---

*Living document — sesuaikan dengan kebutuhan tim dan fase proyek.*
