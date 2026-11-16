# TiramSehat Backend

Backend API untuk aplikasi TiramSehat. **Implementasi aktual memakai
Python/FastAPI + psycopg + Neon PostgreSQL**, bukan Node/TypeScript seperti
rancangan awal di `docs/backend/ARCHITECTURE.md`.

## Stack

| Lapisan | Teknologi |
|---|---|
| HTTP | FastAPI + Uvicorn |
| Database | PostgreSQL (Neon) via `psycopg` + `psycopg_pool` |
| Auth | JWT access token + refresh token (bcrypt untuk PIN) |
| Media | Cloudinary signed upload |
| ML | HTTP client ke `ml-service` (`HF_SPACE_URL`) |

## Struktur

```
backend/
├── app/
│   ├── main.py                 # App factory + router registration
│   ├── core/
│   │   ├── config.py           # Settings dari .env
│   │   ├── database.py         # Connection pool + helper query
│   │   ├── deps.py             # Dependency auth bersama
│   │   ├── exceptions.py       # AppException + envelope response
│   │   ├── security.py         # JWT + bcrypt PIN
│   │   ├── cloudinary.py
│   │   └── ml_client.py
│   └── modules/<domain>/
│       ├── router.py           # HTTP boundary
│       ├── service.py          # Business logic
│       ├── repository.py       # SQL
│       └── schemas.py          # Pydantic request/response
├── migrations/                 # SQL migration berurutan
├── seeds/                      # Data master
├── tests/                      # (belum ada test otomatis)
├── requirements.txt
└── run.py
```

Aturan dependensi: `router → service → repository → database`. Router tidak
berisi SQL; repository tidak berisi aturan bisnis.

## Menjalankan

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate            # Windows
pip install -r requirements.txt
copy .env.example .env            # isi secret secara lokal
python run.py
```

Dokumentasi interaktif: `http://localhost:8000/docs`.

## Autentikasi

Semua endpoint yang mengubah/membaca data pribadi memakai dependency bersama:

```python
from app.core.deps import get_current_user_id

@router.get("")
async def list_items(user_id: str = Depends(get_current_user_id)):
    ...
```

- `get_current_user_id` → wajib Bearer token valid, selain itu `401`.
- `get_optional_user_id` → boleh tanpa token, tetapi token yang dikirim harus
  valid (dipakai ringkasan beranda publik).
- Endpoint scan/harvest memfilter data berdasarkan `user_id`, sehingga pengguna
  tidak bisa membaca atau menghapus data pengguna lain.

## Response envelope

```jsonc
// Sukses
{ "data": { }, "meta": { "request_id": "..." } }

// Error
{ "error": { "code": "UNAUTHENTICATED", "message": "..." } }
```

## Endpoint utama

| Grup | Endpoint |
|---|---|
| Auth | `POST /api/v1/auth/login`, `/google`, `/refresh`, `/logout` |
| Home | `GET /api/v1/home/summary` (token opsional) |
| Scans | `GET/POST /api/v1/scans`, `GET/PATCH/DELETE /api/v1/scans/{id}`, `POST /{id}/actions` |
| Harvests | `GET/POST /api/v1/harvests`, `GET/PATCH/DELETE /api/v1/harvests/{id}` |
| Uploads | `POST /api/v1/uploads/sign`, `/verify` |
| Reports | `GET /api/v1/reports/daily`, `/trend`, `/monthly` |

## Catatan keamanan

- `.env` tidak boleh di-commit; gunakan `.env.example` sebagai template.
- Ganti `JWT_SECRET` dan seluruh secret Cloudinary/DB sebelum produksi.
- CORS `*` hanya cocok untuk pengembangan; batasi origin di produksi.
- Migrasi masih dijalankan manual dari folder `migrations/`; pertimbangkan
  Alembic saat skema mulai berubah sering.
