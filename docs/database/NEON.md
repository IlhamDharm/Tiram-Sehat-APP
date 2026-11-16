# Panduan: Menjalankan Skema di Neon (PostgreSQL)

> Skema PostgreSQL/Neon: [`schema.postgres.sql`](./schema.postgres.sql)
> Skema SQLite (offline/lokal): [`schema.sql`](./schema.sql)
> Rancangan ERD: [`ERD.md`](./ERD.md)

Neon adalah PostgreSQL serverless di cloud. Skema dibuat sekali (atau lewat migrasi) di sisi server — **bukan** dari aplikasi Flutter. Berikut langkah menjalankannya.

---

## 1. Siapkan Akun & Project Neon

1. Daftar di [https://console.neon.tech](https://console.neon.tech).
2. Buat **project** (mis. `tiram-sehat`). Neon otomatis membuat database `neondb`.
3. Pilih region terdekat (mis. Singapore / Jakarta bila tersedia).

---

## 2. Ambil Connection String

Di Neon Console:

- Buka project → **Connect** / **Connection Details** (dashboard).
- Pilih **Connection string** → salin.

Formatnya:

```
postgresql://<user>:<password>@<endpoint>.neon.tech/neondb?sslmode=require
```

Contoh:

```
postgresql://<user>:<password>@ep-<endpoint>.ap-southeast-1.aws.neon.tech/neondb?sslmode=require
```

> **Penting:** gunakan `?sslmode=require` (Neon mewajibkan SSL).
> Password dengan karakter khusus harus di-URL-encode (mis. `@` → `%40`).

### Endpoint pooled (disarankan untuk aplikasi)

Neon menyediakan endpoint connection pooler dengan `-pooler` pada host:

```
postgresql://<user>:<password>@ep-cool-rose-123456-pooler.ap-southeast-1.aws.neon.tech/neondb?sslmode=require
```

- **Migrasi / DDL** → pakai koneksi **direct** (tanpa `-pooler`).
- **Aplikasi (banyak koneksi pendek)** → pakai **pooled**.

Simpan sebagai variabel lingkungan:

```bash
DATABASE_URL="postgresql://...?sslmode=require"
DATABASE_URL_POOLED="postgresql://...-pooler...?sslmode=require"
```

---

## 3. Cara Menjalankan Skema

### Metode A — Neon SQL Editor (paling mudah, tanpa instalasi)

1. Di Neon Console, buka **SQL Editor** (sidebar).
2. Salin seluruh isi `docs/database/schema.postgres.sql`.
3. Tempel ke editor → klik **Run**.
4. Skrip membungkus semua perintah dalam `BEGIN; ... COMMIT;`, sehingga atomik.

Verifikasi di editor:

```sql
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
```

### Metode B — `psql` dari terminal

**Windows:** instal `psql` (PostgreSQL client):
- [EDB installer](https://www.enterprisedb.com/downloads/postgres-postgresql-downloads), atau
- `winget install PostgreSQL.PostgreSQL` (termasuk `psql`), atau
- gunakan WSL dan `sudo apt install postgresql-client`.

Jalankan:

```powershell
psql "postgresql://<user>:<password>@<endpoint>.neon.tech/neondb?sslmode=require" -f docs/database/schema.postgres.sql
```

Verifikasi:

```powershell
psql "postgresql://<user>:<password>@<endpoint>.neon.tech/neondb?sslmode=require" -c "\dt"
```

### Metode C — Alat migrasi (untuk tim)

Contoh `node-pg-migrate`:

```powershell
$env:DATABASE_URL="postgresql://<user>:<password>@<endpoint>.neon.tech/neondb?sslmode=require"
npx node-pg-migrate up
```

Contoh `psql` via GitHub Actions / CI:

```yaml
- name: Migrate Neon
  env:
    DATABASE_URL: ${{ secrets.NEON_DATABASE_URL }}
  run: psql "$DATABASE_URL" -f docs/database/schema.postgres.sql
```

---

## 4. Verifikasi Skema

```sql
-- Cek tabel
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- Cek constraint & foreign key
SELECT conname, contype
FROM pg_constraint
WHERE conrelid = 'scans'::regclass;

-- Cek indeks
SELECT indexname FROM pg_indexes WHERE schemaname = 'public' ORDER BY indexname;
```

Hasil yang diharapkan: **18 tabel** dan **22 indeks** (ditambah index otomatis dari `PRIMARY KEY`/`UNIQUE`).

---

## 5. Tips & Catatan Neon

| Hal | Penjelasan |
|---|---|
| **Compute sleep** | Free plan: compute tidur setelah 5 menit tidak aktif. Query pertama bisa berjalan beberapa detik — normal. |
| **Branching** | Buat branch (`main`, `dev`, `staging`). Skema dijalankan per branch; gunakan branch `dev` untuk pengujian. |
| **Role** | Gunakan role owner (`neondb_owner`) untuk DDL. Untuk aplikasi, buat role khusus dengan hak terbatas (`SELECT/INSERT/UPDATE/DELETE` saja). |
| **`gen_random_uuid()`** | Bawaan PostgreSQL 13+; Neon (PG 15+) mendukung tanpa ekstensi. |
| **Timestamp** | Skema memakai `TIMESTAMPTZ`; kirim ISO-8601 dari Dart/JS (`DateTime.toIso8601String()`). |
| **ID** | Kolom `id` memakai `DEFAULT gen_random_uuid()`; aplikasi boleh mengirim UUID sendiri. |
| **Transaksi** | `BEGIN; ... COMMIT;` membuat seluruh skema atomik — gagal di tengah akan di-rollback. |
| **Idempoten** | Semua perintah memakai `IF NOT EXISTS`, jadi aman dijalankan ulang. |
| **Pooler** | Untuk aplikasi dengan banyak koneksi, gunakan endpoint `-pooler` dan set `statement_cache_size=0` bila memakai pooler + prepared statements. |

---

## 6. Arsitektur Aplikasi (Penting)

**Jangan menaruh connection string Neon langsung di aplikasi Flutter** — kredensial bisa bocor saat APK di-reverse-engineer.

Pola yang direkomendasikan:

```
┌─────────────────────┐        HTTPS/REST        ┌──────────────────────┐      ┌─────────────┐
│  Flutter (mobile)   │ ───────────────────────► │  API / Backend       │ ───► │  Neon       │
│  + SQLite lokal     │ ◄─────────────────────── │  (Node/Fastify/dll.) │      │  PostgreSQL │
│  (offline-first)    │        JSON              │                      │      └─────────────┘
└─────────────────────┘                          └──────────────────────┘
```

Opsi backend/API:

| Opsi | Keterangan |
|---|---|
| **REST API sendiri** (Node/Fastify/Hono, Go, dst.) | Paling fleksibel; pakai `pg` / `postgres.js` / Neon serverless driver. |
| **PostgREST** | Otomatis membuat REST API dari skema Postgres. |
| **Hasura / Supabase** | GraphQL/REST + auth; Supabase punya Postgres sendiri, tapi polanya bisa ditiru. |
| **Neon serverless driver (HTTP)** | `@neondatabase/serverless` untuk edge/serverless function. |

Aplikasi Flutter tetap bisa memakai **SQLite lokal** (`schema.sql`) secara offline-first, lalu disinkronkan ke Neon lewat API.

---

## 7. Ringkasan Perintah Cepat

```powershell
# 1. Jalankan skema (direct connection)
psql "postgresql://<user>:<password>@<endpoint>.neon.tech/neondb?sslmode=require" -f docs/database/schema.postgres.sql

# 2. Verifikasi
psql "postgresql://<user>:<password>@<endpoint>.neon.tech/neondb?sslmode=require" -c "\dt"

# 3. Cek jumlah tabel
psql "postgresql://<user>:<password>@<endpoint>.neon.tech/neondb?sslmode=require" -c "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE';"
```

---

*Living document — sesuaikan region, role, dan endpoint dengan project Neon Anda.*
