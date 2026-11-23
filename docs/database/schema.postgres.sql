-- ============================================================================
-- TiramSehat — Skema Basis Data (PostgreSQL / Neon)
-- ============================================================================
-- Target : Neon (serverless PostgreSQL, PG 15+)
-- Offline-first + cloud-ready.
--  - id        UUID PRIMARY KEY DEFAULT gen_random_uuid()
--  - Timestamp TIMESTAMPTZ
--  - Uang      BIGINT (Rupiah), Berat NUMERIC (Kg)
--  - Boolean   BOOLEAN
--
-- Cara menjalankan:
--   1. Neon Console -> SQL Editor -> paste seluruh file -> Run
--      atau
--   2. psql "<connection_string>?sslmode=require" -f docs/database/schema.postgres.sql
--
-- Catatan:
--   - gen_random_uuid() bawaan PostgreSQL 13+ (tidak perlu pgcrypto).
--   - Aplikasi juga boleh mengirim id sendiri (UUID) jika sudah punya.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- MASTER & REFERENSI
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS users (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name          TEXT NOT NULL,
    phone         TEXT UNIQUE,
    farmer_id     TEXT UNIQUE,
    pin_hash      TEXT NOT NULL,
    role          TEXT NOT NULL DEFAULT 'farmer'
                  CHECK (role IN ('farmer', 'officer', 'admin')),
    email         TEXT,
    google_id     TEXT UNIQUE,
    avatar_url    TEXT,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS refresh_tokens (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash  TEXT NOT NULL UNIQUE,            -- hash dari refresh token
    expires_at  TIMESTAMPTZ NOT NULL,
    revoked_at  TIMESTAMPTZ,
    replaced_by UUID,
    ip          INET,
    user_agent  TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS kumbungs (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code          TEXT NOT NULL UNIQUE,          -- Blok A / B / C
    name          TEXT NOT NULL,
    address       TEXT,
    manager_id    UUID REFERENCES users(id) ON DELETE SET NULL,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_kumbung_assignments (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    kumbung_id    UUID NOT NULL REFERENCES kumbungs(id) ON DELETE CASCADE,
    is_primary    BOOLEAN NOT NULL DEFAULT FALSE,
    assigned_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, kumbung_id)
);

CREATE TABLE IF NOT EXISTS raks (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kumbung_id    UUID NOT NULL REFERENCES kumbungs(id) ON DELETE CASCADE,
    code          TEXT NOT NULL,                 -- mis. B-04
    block         TEXT,                          -- A / B / C / D
    column_count  INTEGER NOT NULL DEFAULT 8,
    capacity      INTEGER,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (kumbung_id, code)
);

CREATE TABLE IF NOT EXISTS mushroom_varieties (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT NOT NULL UNIQUE,        -- Florida Putih
    scientific_name TEXT,
    description     TEXT,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS diseases (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name             TEXT NOT NULL,              -- Green Mold
    scientific_name  TEXT,                       -- Trichoderma sp.
    category         TEXT
                     CHECK (category IN ('jamur', 'bakteri', 'virus', 'nutrisi', 'hama', 'sehat', 'lainnya')),
    default_severity TEXT NOT NULL DEFAULT 'treatable'
                     CHECK (default_severity IN ('healthy', 'treatable', 'must_discard')),
    ml_label         TEXT UNIQUE,                -- Label output model (Healthy, Single_Infected, Mixed_Infected)
    is_healthy       BOOLEAN NOT NULL DEFAULT FALSE,
    location_hint    TEXT,
    description      TEXT,
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS disease_steps (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    disease_id  UUID NOT NULL REFERENCES diseases(id) ON DELETE CASCADE,
    step_order  INTEGER NOT NULL,
    title       TEXT NOT NULL,
    description TEXT NOT NULL,
    UNIQUE (disease_id, step_order)
);

-- ---------------------------------------------------------------------------
-- OPERASIONAL
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS baglog_batches (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code          TEXT NOT NULL UNIQUE,          -- Batch Panen K-04 Margomulyo
    variety_id    UUID REFERENCES mushroom_varieties(id) ON DELETE SET NULL,
    kumbung_id    UUID REFERENCES kumbungs(id) ON DELETE SET NULL,
    planted_at    TIMESTAMPTZ,
    harvested_at  TIMESTAMPTZ,
    status        TEXT NOT NULL DEFAULT 'active'
                  CHECK (status IN ('planned', 'active', 'harvesting', 'completed', 'archived')),
    grade         TEXT,
    total_baglog  INTEGER NOT NULL DEFAULT 0,
    note          TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS baglogs (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code          TEXT UNIQUE,                   -- mis. B-04-03
    batch_id      UUID REFERENCES baglog_batches(id) ON DELETE SET NULL,
    rak_id        UUID NOT NULL REFERENCES raks(id) ON DELETE CASCADE,
    column_no     INTEGER NOT NULL,
    status        TEXT NOT NULL DEFAULT 'sehat'
                  CHECK (status IN ('sehat', 'bisa_diobati', 'sedang_diobati', 'afkir', 'dibuang', 'panen')),
    planted_at    TIMESTAMPTZ,
    harvested_at  TIMESTAMPTZ,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (rak_id, column_no, batch_id)
);

CREATE TABLE IF NOT EXISTS harvest_entries (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    batch_id      UUID REFERENCES baglog_batches(id) ON DELETE SET NULL,
    kumbung_id    UUID REFERENCES kumbungs(id) ON DELETE SET NULL,
    harvested_at  TIMESTAMPTZ NOT NULL,
    weight_kg     NUMERIC(10, 2) NOT NULL CHECK (weight_kg > 0),
    price_per_kg  BIGINT NOT NULL CHECK (price_per_kg >= 0),
    gross_income  BIGINT NOT NULL,
    note          TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS scans (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code               TEXT UNIQUE,              -- SCAN-0001
    user_id            UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    baglog_id          UUID REFERENCES baglogs(id) ON DELETE SET NULL,
    rak_id             UUID NOT NULL REFERENCES raks(id) ON DELETE CASCADE,
    column_no          INTEGER NOT NULL,
    batch_id           UUID REFERENCES baglog_batches(id) ON DELETE SET NULL,
    disease_id         UUID REFERENCES diseases(id) ON DELETE SET NULL,
    diagnosis_name     TEXT,                     -- snapshot
    scientific_name    TEXT,                     -- snapshot
    confidence         DOUBLE PRECISION CHECK (confidence BETWEEN 0 AND 1),
    infection_location TEXT,
    severity           TEXT NOT NULL DEFAULT 'treatable'
                       CHECK (severity IN ('healthy', 'treatable', 'must_discard')),
    scan_method        TEXT NOT NULL DEFAULT 'camera'
                       CHECK (scan_method IN ('camera', 'manual', 'on_device_tflite')),
    image_local_path   TEXT,                     -- path gambar di perangkat (offline-first)
    image_public_id    TEXT,                     -- Cloudinary public_id (setelah upload)
    image_url          TEXT,                     -- Cloudinary secure_url
    image_version      BIGINT,                   -- Cloudinary version
    image_thumbnail_url TEXT,                    -- URL thumbnail (hasil transformasi)
    status             TEXT NOT NULL DEFAULT 'action_required'
                       CHECK (status IN ('action_required', 'in_treatment', 'recovered', 'discarded', 'archived')),
    status_note        TEXT,
    status_tag         TEXT,
    inference_status   TEXT NOT NULL DEFAULT 'completed'
                       CHECK (inference_status IN ('pending', 'processing', 'completed', 'failed')),
    inference_error    TEXT,
    inference_attempts INTEGER NOT NULL DEFAULT 0,
    model_version      TEXT,
    inference_started_at TIMESTAMPTZ,
    inference_completed_at TIMESTAMPTZ,
    raw_response       JSONB,
    ml_label           TEXT,
    scanned_at         TIMESTAMPTZ NOT NULL,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS scan_steps (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scan_id     UUID NOT NULL REFERENCES scans(id) ON DELETE CASCADE,
    step_order  INTEGER NOT NULL,
    title       TEXT NOT NULL,
    description TEXT NOT NULL,
    UNIQUE (scan_id, step_order)
);

CREATE TABLE IF NOT EXISTS treatment_logs (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scan_id      UUID NOT NULL REFERENCES scans(id) ON DELETE CASCADE,
    action_type  TEXT NOT NULL
                 CHECK (action_type IN ('note', 'status_change', 'treatment', 'discard', 'recover', 'archive')),
    from_status  TEXT,
    to_status    TEXT,
    note         TEXT,
    tag          TEXT,
    performed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    performed_at TIMESTAMPTZ NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- PENDUKUNG
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS daily_inspections (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kumbung_id    UUID NOT NULL REFERENCES kumbungs(id) ON DELETE CASCADE,
    date          DATE NOT NULL,                 -- YYYY-MM-DD
    target        INTEGER NOT NULL DEFAULT 0,
    checked_count INTEGER NOT NULL DEFAULT 0,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (kumbung_id, date)
);

CREATE TABLE IF NOT EXISTS health_snapshots (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kumbung_id    UUID NOT NULL REFERENCES kumbungs(id) ON DELETE CASCADE,
    batch_id      UUID REFERENCES baglog_batches(id) ON DELETE SET NULL,
    date          DATE NOT NULL,
    period        TEXT NOT NULL DEFAULT 'daily'
                  CHECK (period IN ('daily', 'weekly', 'monthly')),
    total_baglog  INTEGER NOT NULL DEFAULT 0,
    healthy       INTEGER NOT NULL DEFAULT 0,
    treatable     INTEGER NOT NULL DEFAULT 0,
    discarded     INTEGER NOT NULL DEFAULT 0,
    health_ratio  DOUBLE PRECISION,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (kumbung_id, batch_id, period, date)
);

CREATE TABLE IF NOT EXISTS report_exports (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID REFERENCES users(id) ON DELETE SET NULL,
    period_type  TEXT NOT NULL CHECK (period_type IN ('week', 'month', 'year')),
    period_start DATE NOT NULL,
    period_end   DATE NOT NULL,
    format       TEXT NOT NULL CHECK (format IN ('csv', 'pdf')),
    file_path    TEXT NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_preferences (
    user_id                UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    active_kumbung_id      UUID REFERENCES kumbungs(id) ON DELETE SET NULL,
    active_batch_id        UUID REFERENCES baglog_batches(id) ON DELETE SET NULL,
    daily_check_target     INTEGER NOT NULL DEFAULT 100,
    default_price_per_kg   BIGINT NOT NULL DEFAULT 15000,
    estimated_baglog_value BIGINT NOT NULL DEFAULT 3000,
    onboarding_completed   BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- INDEKS
-- ---------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_refresh_user            ON refresh_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_assignments_user       ON user_kumbung_assignments(user_id);
CREATE INDEX IF NOT EXISTS idx_assignments_kumbung    ON user_kumbung_assignments(kumbung_id);
CREATE INDEX IF NOT EXISTS idx_raks_kumbung           ON raks(kumbung_id);
CREATE INDEX IF NOT EXISTS idx_batches_kumbung        ON baglog_batches(kumbung_id);
CREATE INDEX IF NOT EXISTS idx_batches_status         ON baglog_batches(status);
CREATE INDEX IF NOT EXISTS idx_baglogs_batch           ON baglogs(batch_id);
CREATE INDEX IF NOT EXISTS idx_baglogs_rak             ON baglogs(rak_id);
CREATE INDEX IF NOT EXISTS idx_baglogs_status          ON baglogs(status);
CREATE INDEX IF NOT EXISTS idx_scans_user              ON scans(user_id);
CREATE INDEX IF NOT EXISTS idx_scans_rak               ON scans(rak_id);
CREATE INDEX IF NOT EXISTS idx_scans_status            ON scans(status);
CREATE INDEX IF NOT EXISTS idx_scans_scanned_at        ON scans(scanned_at);
CREATE INDEX IF NOT EXISTS idx_scans_batch             ON scans(batch_id);
CREATE INDEX IF NOT EXISTS idx_scans_inference_status  ON scans(inference_status);
CREATE INDEX IF NOT EXISTS idx_diseases_ml_label       ON diseases(ml_label);
CREATE INDEX IF NOT EXISTS idx_scan_steps_scan         ON scan_steps(scan_id);
CREATE INDEX IF NOT EXISTS idx_treatment_scan          ON treatment_logs(scan_id);
CREATE INDEX IF NOT EXISTS idx_treatment_performed_at  ON treatment_logs(performed_at);
CREATE INDEX IF NOT EXISTS idx_harvest_user            ON harvest_entries(user_id);
CREATE INDEX IF NOT EXISTS idx_harvest_date            ON harvest_entries(harvested_at);
CREATE INDEX IF NOT EXISTS idx_daily_insp_date        ON daily_inspections(kumbung_id, date);
CREATE INDEX IF NOT EXISTS idx_health_snap_period      ON health_snapshots(kumbung_id, period, date);
CREATE INDEX IF NOT EXISTS idx_report_exports_user     ON report_exports(user_id);

COMMIT;
