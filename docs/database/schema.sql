-- ============================================================================
-- TiramSehat — Skema Basis Data (SQLite)
-- ============================================================================
-- Offline-first, siap disinkronkan.
--  - id TEXT PRIMARY KEY (UUID v4, digenerate oleh aplikasi)
--  - Timestamp TEXT ISO-8601
--  - Uang INTEGER (Rupiah), Berat REAL (Kg)
--
-- Cara pakai:
--   1. Aktifkan foreign key pada setiap koneksi: PRAGMA foreign_keys = ON;
--   2. Jalankan seluruh blok CREATE TABLE & CREATE INDEX di bawah.
-- ============================================================================

PRAGMA foreign_keys = ON;

-- ---------------------------------------------------------------------------
-- MASTER & REFERENSI
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS users (
    id            TEXT PRIMARY KEY NOT NULL,
    name          TEXT NOT NULL,
    phone         TEXT UNIQUE,
    farmer_id     TEXT UNIQUE,
    pin_hash      TEXT NOT NULL,
    role          TEXT NOT NULL DEFAULT 'farmer'
                  CHECK (role IN ('farmer', 'officer', 'admin')),
    email         TEXT,
    google_id     TEXT UNIQUE,
    avatar_url    TEXT,
    is_active     INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
    created_at    TEXT NOT NULL,
    updated_at    TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS refresh_tokens (
    id          TEXT PRIMARY KEY NOT NULL,
    user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash  TEXT NOT NULL UNIQUE,            -- hash dari refresh token
    expires_at  TEXT NOT NULL,
    revoked_at  TEXT,
    replaced_by TEXT,
    ip          TEXT,
    user_agent  TEXT,
    created_at  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS kumbungs (
    id            TEXT PRIMARY KEY NOT NULL,
    code          TEXT NOT NULL UNIQUE,          -- Blok A / B / C
    name          TEXT NOT NULL,
    address       TEXT,
    manager_id    TEXT REFERENCES users(id) ON DELETE SET NULL,
    is_active     INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
    created_at    TEXT NOT NULL,
    updated_at    TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS user_kumbung_assignments (
    id            TEXT PRIMARY KEY NOT NULL,
    user_id       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    kumbung_id    TEXT NOT NULL REFERENCES kumbungs(id) ON DELETE CASCADE,
    is_primary    INTEGER NOT NULL DEFAULT 0 CHECK (is_primary IN (0, 1)),
    assigned_at   TEXT NOT NULL,
    UNIQUE (user_id, kumbung_id)
);

CREATE TABLE IF NOT EXISTS raks (
    id            TEXT PRIMARY KEY NOT NULL,
    kumbung_id    TEXT NOT NULL REFERENCES kumbungs(id) ON DELETE CASCADE,
    code          TEXT NOT NULL,                 -- mis. B-04
    block         TEXT,                          -- A / B / C / D
    column_count  INTEGER NOT NULL DEFAULT 8,
    capacity      INTEGER,
    is_active     INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
    created_at    TEXT NOT NULL,
    updated_at    TEXT NOT NULL,
    UNIQUE (kumbung_id, code)
);

CREATE TABLE IF NOT EXISTS mushroom_varieties (
    id              TEXT PRIMARY KEY NOT NULL,
    name            TEXT NOT NULL UNIQUE,        -- Florida Putih
    scientific_name TEXT,
    description     TEXT,
    is_active       INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS diseases (
    id               TEXT PRIMARY KEY NOT NULL,
    name             TEXT NOT NULL,              -- Green Mold
    scientific_name  TEXT,                       -- Trichoderma sp.
    category         TEXT
                     CHECK (category IN ('jamur', 'bakteri', 'virus', 'nutrisi', 'hama', 'lainnya')),
    default_severity TEXT NOT NULL DEFAULT 'treatable'
                     CHECK (default_severity IN ('treatable', 'must_discard')),
    location_hint    TEXT,
    description      TEXT,
    is_active        INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
    created_at       TEXT NOT NULL,
    updated_at       TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS disease_steps (
    id          TEXT PRIMARY KEY NOT NULL,
    disease_id  TEXT NOT NULL REFERENCES diseases(id) ON DELETE CASCADE,
    step_order  INTEGER NOT NULL,
    title       TEXT NOT NULL,
    description TEXT NOT NULL,
    UNIQUE (disease_id, step_order)
);

-- ---------------------------------------------------------------------------
-- OPERASIONAL
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS baglog_batches (
    id            TEXT PRIMARY KEY NOT NULL,
    code          TEXT NOT NULL UNIQUE,          -- Batch Panen K-04 Margomulyo
    variety_id    TEXT REFERENCES mushroom_varieties(id) ON DELETE SET NULL,
    kumbung_id    TEXT REFERENCES kumbungs(id) ON DELETE SET NULL,
    planted_at    TEXT,
    harvested_at  TEXT,
    status        TEXT NOT NULL DEFAULT 'active'
                  CHECK (status IN ('planned', 'active', 'harvesting', 'completed', 'archived')),
    grade         TEXT,
    total_baglog  INTEGER NOT NULL DEFAULT 0,
    note          TEXT,
    created_at    TEXT NOT NULL,
    updated_at    TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS baglogs (
    id            TEXT PRIMARY KEY NOT NULL,
    code          TEXT UNIQUE,                   -- mis. B-04-03
    batch_id      TEXT REFERENCES baglog_batches(id) ON DELETE SET NULL,
    rak_id        TEXT NOT NULL REFERENCES raks(id) ON DELETE CASCADE,
    column_no     INTEGER NOT NULL,
    status        TEXT NOT NULL DEFAULT 'sehat'
                  CHECK (status IN ('sehat', 'bisa_diobati', 'sedang_diobati', 'afkir', 'dibuang', 'panen')),
    planted_at    TEXT,
    harvested_at  TEXT,
    created_at    TEXT NOT NULL,
    updated_at    TEXT NOT NULL,
    UNIQUE (rak_id, column_no, batch_id)
);

CREATE TABLE IF NOT EXISTS harvest_entries (
    id            TEXT PRIMARY KEY NOT NULL,
    user_id       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    batch_id      TEXT REFERENCES baglog_batches(id) ON DELETE SET NULL,
    kumbung_id    TEXT REFERENCES kumbungs(id) ON DELETE SET NULL,
    harvested_at  TEXT NOT NULL,
    weight_kg     REAL NOT NULL CHECK (weight_kg > 0),
    price_per_kg  INTEGER NOT NULL CHECK (price_per_kg >= 0),
    gross_income  INTEGER NOT NULL,
    note          TEXT,
    created_at    TEXT NOT NULL,
    updated_at    TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS scans (
    id                 TEXT PRIMARY KEY NOT NULL,
    code               TEXT UNIQUE,              -- SCAN-0001
    user_id            TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    baglog_id          TEXT REFERENCES baglogs(id) ON DELETE SET NULL,
    rak_id             TEXT NOT NULL REFERENCES raks(id) ON DELETE CASCADE,
    column_no          INTEGER NOT NULL,
    batch_id           TEXT REFERENCES baglog_batches(id) ON DELETE SET NULL,
    disease_id         TEXT REFERENCES diseases(id) ON DELETE SET NULL,
    diagnosis_name     TEXT,                     -- snapshot
    scientific_name    TEXT,                     -- snapshot
    confidence         REAL CHECK (confidence BETWEEN 0 AND 1),
    infection_location TEXT,
    severity           TEXT NOT NULL DEFAULT 'treatable'
                       CHECK (severity IN ('healthy', 'treatable', 'must_discard')),
    scan_method        TEXT NOT NULL DEFAULT 'camera'
                       CHECK (scan_method IN ('camera', 'manual')),
    image_local_path   TEXT,                     -- path gambar di perangkat (offline-first)
    image_public_id    TEXT,                     -- Cloudinary public_id (setelah upload)
    image_url          TEXT,                     -- Cloudinary secure_url
    image_version      INTEGER,                  -- Cloudinary version
    image_thumbnail_url TEXT,                    -- URL thumbnail (hasil transformasi)
    status             TEXT NOT NULL DEFAULT 'action_required'
                       CHECK (status IN ('action_required', 'in_treatment', 'recovered', 'discarded', 'archived')),
    status_note        TEXT,
    status_tag         TEXT,
    scanned_at         TEXT NOT NULL,
    created_at         TEXT NOT NULL,
    updated_at         TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS scan_steps (
    id          TEXT PRIMARY KEY NOT NULL,
    scan_id     TEXT NOT NULL REFERENCES scans(id) ON DELETE CASCADE,
    step_order  INTEGER NOT NULL,
    title       TEXT NOT NULL,
    description TEXT NOT NULL,
    UNIQUE (scan_id, step_order)
);

CREATE TABLE IF NOT EXISTS treatment_logs (
    id           TEXT PRIMARY KEY NOT NULL,
    scan_id      TEXT NOT NULL REFERENCES scans(id) ON DELETE CASCADE,
    action_type  TEXT NOT NULL
                 CHECK (action_type IN ('note', 'status_change', 'treatment', 'discard', 'recover', 'archive')),
    from_status  TEXT,
    to_status    TEXT,
    note         TEXT,
    tag          TEXT,
    performed_by TEXT REFERENCES users(id) ON DELETE SET NULL,
    performed_at TEXT NOT NULL,
    created_at   TEXT NOT NULL
);

-- ---------------------------------------------------------------------------
-- PENDUKUNG
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS daily_inspections (
    id            TEXT PRIMARY KEY NOT NULL,
    kumbung_id    TEXT NOT NULL REFERENCES kumbungs(id) ON DELETE CASCADE,
    date          TEXT NOT NULL,                 -- YYYY-MM-DD
    target        INTEGER NOT NULL DEFAULT 0,
    checked_count INTEGER NOT NULL DEFAULT 0,
    created_at    TEXT NOT NULL,
    updated_at    TEXT NOT NULL,
    UNIQUE (kumbung_id, date)
);

CREATE TABLE IF NOT EXISTS health_snapshots (
    id            TEXT PRIMARY KEY NOT NULL,
    kumbung_id    TEXT NOT NULL REFERENCES kumbungs(id) ON DELETE CASCADE,
    batch_id      TEXT REFERENCES baglog_batches(id) ON DELETE SET NULL,
    date          TEXT NOT NULL,
    period        TEXT NOT NULL DEFAULT 'daily'
                  CHECK (period IN ('daily', 'weekly', 'monthly')),
    total_baglog  INTEGER NOT NULL DEFAULT 0,
    healthy       INTEGER NOT NULL DEFAULT 0,
    treatable     INTEGER NOT NULL DEFAULT 0,
    discarded     INTEGER NOT NULL DEFAULT 0,
    health_ratio  REAL,
    created_at    TEXT NOT NULL,
    UNIQUE (kumbung_id, batch_id, period, date)
);

CREATE TABLE IF NOT EXISTS report_exports (
    id           TEXT PRIMARY KEY NOT NULL,
    user_id      TEXT REFERENCES users(id) ON DELETE SET NULL,
    period_type  TEXT NOT NULL CHECK (period_type IN ('week', 'month', 'year')),
    period_start TEXT NOT NULL,
    period_end   TEXT NOT NULL,
    format       TEXT NOT NULL CHECK (format IN ('csv', 'pdf')),
    file_path    TEXT NOT NULL,
    created_at   TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS user_preferences (
    user_id                TEXT PRIMARY KEY NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    active_kumbung_id      TEXT REFERENCES kumbungs(id) ON DELETE SET NULL,
    active_batch_id        TEXT REFERENCES baglog_batches(id) ON DELETE SET NULL,
    daily_check_target     INTEGER NOT NULL DEFAULT 100,
    default_price_per_kg   INTEGER NOT NULL DEFAULT 15000,
    estimated_baglog_value INTEGER NOT NULL DEFAULT 3000,
    onboarding_completed   INTEGER NOT NULL DEFAULT 0 CHECK (onboarding_completed IN (0, 1)),
    updated_at             TEXT NOT NULL
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
CREATE INDEX IF NOT EXISTS idx_scan_steps_scan         ON scan_steps(scan_id);
CREATE INDEX IF NOT EXISTS idx_treatment_scan          ON treatment_logs(scan_id);
CREATE INDEX IF NOT EXISTS idx_treatment_performed_at  ON treatment_logs(performed_at);
CREATE INDEX IF NOT EXISTS idx_harvest_user            ON harvest_entries(user_id);
CREATE INDEX IF NOT EXISTS idx_harvest_date            ON harvest_entries(harvested_at);
CREATE INDEX IF NOT EXISTS idx_daily_insp_date        ON daily_inspections(kumbung_id, date);
CREATE INDEX IF NOT EXISTS idx_health_snap_period      ON health_snapshots(kumbung_id, period, date);
CREATE INDEX IF NOT EXISTS idx_report_exports_user     ON report_exports(user_id);
