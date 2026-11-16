-- ============================================================================
-- TiramSehat — Patch Migrasi Skema (PostgreSQL / Neon)
-- ============================================================================
-- Jalankan file ini di Neon SQL Editor jika Anda SUDAH menjalankan skema awal
-- sebelumnya, sehingga tidak perlu drop/menghapus tabel yang sudah ada.
-- Skrip ini IDEMPOTENT (aman dijalankan berulang kali).
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Penambahan Kolom & Penyesuaian Constraint Tabel: diseases
-- ---------------------------------------------------------------------------

-- Tambahkan kolom ml_label dan is_healthy
ALTER TABLE diseases
  ADD COLUMN IF NOT EXISTS ml_label TEXT UNIQUE,
  ADD COLUMN IF NOT EXISTS is_healthy BOOLEAN NOT NULL DEFAULT FALSE;

-- Perbarui CHECK constraint category agar mengizinkan 'sehat'
ALTER TABLE diseases DROP CONSTRAINT IF EXISTS diseases_category_check;
ALTER TABLE diseases
  ADD CONSTRAINT diseases_category_check
  CHECK (category IN ('jamur', 'bakteri', 'virus', 'nutrisi', 'hama', 'sehat', 'lainnya'));

-- Perbarui CHECK constraint default_severity agar mengizinkan 'healthy'
ALTER TABLE diseases DROP CONSTRAINT IF EXISTS diseases_default_severity_check;
ALTER TABLE diseases
  ADD CONSTRAINT diseases_default_severity_check
  CHECK (default_severity IN ('healthy', 'treatable', 'must_discard'));

-- Index pencarian label ML
CREATE INDEX IF NOT EXISTS idx_diseases_ml_label ON diseases (ml_label);

-- ---------------------------------------------------------------------------
-- 2. Penambahan Kolom Status Inferensi Tabel: scans
-- ---------------------------------------------------------------------------

ALTER TABLE scans
  ADD COLUMN IF NOT EXISTS inference_status TEXT NOT NULL DEFAULT 'completed'
    CHECK (inference_status IN ('pending', 'processing', 'completed', 'failed')),
  ADD COLUMN IF NOT EXISTS inference_error TEXT,
  ADD COLUMN IF NOT EXISTS inference_attempts INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS model_version TEXT,
  ADD COLUMN IF NOT EXISTS inference_started_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS inference_completed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS raw_response JSONB,
  ADD COLUMN IF NOT EXISTS ml_label TEXT;

-- Index status inferensi
CREATE INDEX IF NOT EXISTS idx_scans_inference_status ON scans (inference_status);
CREATE INDEX IF NOT EXISTS idx_scans_inference_pending
  ON scans (created_at)
  WHERE inference_status IN ('pending', 'failed');

COMMIT;
