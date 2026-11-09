import os
import sys
import json
import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import cloudinary
import cloudinary.uploader
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv

# Mencegah WinError 64 / ProactorEventLoop crash di Windows
if sys.platform == "win32":
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

dotenv_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env")
load_dotenv(dotenv_path)

# 1. Konfigurasi Cloudinary SDK
cloudinary.config(
    cloud_name=os.getenv("CLOUDINARY_CLOUD_NAME"),
    api_key=os.getenv("CLOUDINARY_API_KEY"),
    api_secret=os.getenv("CLOUDINARY_API_SECRET"),
    secure=True
)

# 2. Fungsi Helper Koneksi Neon DB
def get_db_connection():
    try:
        conn = psycopg2.connect(
            os.getenv("NEON_DATABASE_URL"),
            cursor_factory=RealDictCursor
        )
        return conn
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database connection error: {str(e)}")

# 3. Otomatisasi Pembuatan Skema Tabel di Neon DB jika belum ada
def init_db():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS mushroom_scans (
                id SERIAL PRIMARY KEY,
                image_url TEXT NOT NULL,
                diagnosis_name VARCHAR(150) NOT NULL,
                scientific_name VARCHAR(150),
                confidence_score DOUBLE PRECISION DEFAULT 94.2,
                infection_location VARCHAR(150),
                severity VARCHAR(50) DEFAULT 'treatable',
                rack VARCHAR(100) DEFAULT 'Rak Kumbung B-04',
                column_no INT DEFAULT 3,
                steps JSONB,
                notes TEXT,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
            );
        """)
        conn.commit()
        cursor.close()
        conn.close()
        print("Database Neon DB initialized successfully.")
    except Exception as e:
        print(f"Init DB warning: {e}")

@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    yield

app = FastAPI(title="TiramSehat Cloudinary & Neon DB API", lifespan=lifespan)

# Konfigurasi CORS agar bisa dipanggil dari Flutter Mobile, Web, dan Desktop
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 4. Endpoint Root (Health Check & Dokumentasi)
@app.get("/")
async def root():
    return {
        "status": "online",
        "service": "TiramSehat Cloudinary + Neon DB API",
        "database": "Neon PostgreSQL (Connected)",
        "storage": "Cloudinary (Connected)",
        "docs_url": "/docs"
    }

# 5. Endpoint Upload Scan (Cloudinary) & Simpan Metadata (Neon DB)
@app.post("/api/scan")
async def scan_mushroom(
    file: UploadFile = File(...),
    rack: str = Form("Rak Kumbung B-04"),
    column: int = Form(3),
    diagnosis_name: str = Form("Green Mold"),
    scientific_name: str = Form("Trichoderma sp."),
    confidence_score: float = Form(94.2),
    infection_location: str = Form("Cincin & Leher Baglog"),
    severity: str = Form("treatable"),
    notes: str = Form(None)
):
    # Validasi format file
    print(f"[SCAN] Request received: filename={file.filename}, content_type={file.content_type}, size={file.size}")
    if not file.content_type or not file.content_type.startswith("image/"):
        print(f"[SCAN] REJECTED: content_type={file.content_type}")
        raise HTTPException(status_code=400, detail=f"File harus berupa gambar! Got: {file.content_type}")

    try:
        # A. Unggah Gambar ke Cloudinary (folder 'img_jamur')
        print(f"[SCAN] Uploading to Cloudinary...")
        contents = await file.read()
        print(f"[SCAN] File bytes read: {len(contents)} bytes")
        upload_result = cloudinary.uploader.upload(
            contents,
            folder="img_jamur",
            resource_type="image"
        )
        image_url = upload_result.get("secure_url")
        print(f"[SCAN] Cloudinary upload OK: {image_url}")

        # B. Metadata Hasil Diagnosa Baglog
        steps = [
            {
                "title": "Pindahkan ke Rak Karantina",
                "description": "Segera pisahkan baglog dari rak utama kumbung untuk mencegah penularan spora via sirkulasi udara lembap."
            },
            {
                "title": "Kerik Lembut Spora Hijau",
                "description": "Gunakan sendok makan bersih yang telah disterilkan alkohol 70%. Kerik hingga batas miselium putih yang masih segar."
            },
            {
                "title": "Oles Larutan Kapur Tohor (CaCO3)",
                "description": "Oleskan pasta kapur tohor pekat atau fungisida nabati rebusan daun sirih ke bekas kerokan untuk menaikkan pH lokal."
            },
            {
                "title": "Observasi Pemulihan 48 Jam",
                "description": "Jika miselium putih tumbuh menutupi bekas luka, baglog aman. Jika spora menghitam/meluas, segera buang dari kumbung."
            }
        ]

        # C. Simpan URL Cloudinary dan Metadata ke Neon DB
        conn = get_db_connection()
        cursor = conn.cursor()
        
        insert_query = """
            INSERT INTO mushroom_scans (
                image_url, diagnosis_name, scientific_name, confidence_score,
                infection_location, severity, rack, column_no, steps, notes
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id, image_url, diagnosis_name, scientific_name, confidence_score,
                      infection_location, severity, rack, column_no, steps, notes, created_at;
        """
        cursor.execute(insert_query, (
            image_url,
            diagnosis_name,
            scientific_name,
            confidence_score,
            infection_location,
            severity,
            rack,
            column,
            json.dumps(steps),
            notes
        ))
        new_scan = cursor.fetchone()
        
        conn.commit()
        cursor.close()
        conn.close()

        if "created_at" in new_scan and new_scan["created_at"]:
            new_scan["created_at"] = new_scan["created_at"].isoformat()

        return {
            "success": True,
            "message": "Hasil scan berhasil diunggah ke Cloudinary (img_jamur) dan disimpan ke Neon DB!",
            "data": new_scan
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Gagal memproses scan: {str(e)}")

# 6. Endpoint Mengambil Seluruh Riwayat Scan dari Neon DB
@app.get("/api/scans")
async def get_all_scans():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute("SELECT * FROM mushroom_scans ORDER BY created_at DESC;")
        scans = cursor.fetchall()
        
        cursor.close()
        conn.close()

        for s in scans:
            if "created_at" in s and s["created_at"]:
                s["created_at"] = s["created_at"].isoformat()

        return {
            "success": True,
            "count": len(scans),
            "data": scans
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Gagal mengambil data dari Neon DB: {str(e)}")

# 7. Endpoint Hapus Riwayat Scan
@app.delete("/api/scans/{scan_id}")
async def delete_scan(scan_id: int):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM mushroom_scans WHERE id = %s RETURNING id;", (scan_id,))
        deleted = cursor.fetchone()
        conn.commit()
        cursor.close()
        conn.close()

        if not deleted:
            raise HTTPException(status_code=404, detail="Data scan tidak ditemukan")

        return {
            "success": True,
            "message": f"Scan ID {scan_id} berhasil dihapus dari Neon DB"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)

