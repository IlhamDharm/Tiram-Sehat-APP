BEGIN;

-- 1. Seed User Petani Default (digunakan oleh API & sinkronisasi Flutter)
INSERT INTO users (id, name, phone, farmer_id, pin_hash, role, email, is_active)
VALUES (
  'a0000000-0000-0000-0000-000000000001',
  'Budi Santoso',
  '081234567890',
  'PETANI-001',
  '$2b$12$66IMEduLWHDI5zDBtEzYUegNaRu9iHce7ley6iPbVm1nz91IOlMam', -- PIN: 123456
  'farmer',
  'petani@tiramsehat.id',
  TRUE
)
ON CONFLICT (id) DO NOTHING;

-- 2. Seed Kumbung & Rak
INSERT INTO kumbungs (id, code, name, address, manager_id, is_active)
VALUES
  ('a0000000-0000-0000-0000-000000000001', 'A', 'Kumbung Blok A', 'Margomulyo', 'a0000000-0000-0000-0000-000000000001', TRUE),
  ('a0000000-0000-0000-0000-000000000002', 'B', 'Kumbung Blok B', 'Margomulyo', 'a0000000-0000-0000-0000-000000000001', TRUE)
ON CONFLICT (code) DO NOTHING;

INSERT INTO user_kumbung_assignments (id, user_id, kumbung_id, is_primary)
VALUES
  ('e0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', TRUE)
ON CONFLICT (user_id, kumbung_id) DO NOTHING;

INSERT INTO user_preferences (user_id, active_kumbung_id, daily_check_target, default_price_per_kg, estimated_baglog_value, onboarding_completed)
VALUES
  ('a0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 100, 15000, 3000, TRUE)
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO raks (id, kumbung_id, code, block, column_count, capacity, is_active)
VALUES
  ('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'A-01', 'A', 8, 300, TRUE),
  ('b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'B-04', 'B', 8, 300, TRUE)
ON CONFLICT (kumbung_id, code) DO NOTHING;

-- 3. Seed Varietas Jamur & Batch Baglog
INSERT INTO mushroom_varieties (id, name, scientific_name, description, is_active)
VALUES
  ('c0000000-0000-0000-0000-000000000001', 'Florida Putih', 'Pleurotus ostreatus var. florida', 'Varietas jamur tiram putih unggulan BUMDes', TRUE)
ON CONFLICT (name) DO NOTHING;

INSERT INTO baglog_batches (id, code, variety_id, kumbung_id, planted_at, status, grade, total_baglog, note)
VALUES
  ('f0000000-0000-0000-0000-000000000001', 'Batch Panen K-04 Margomulyo', 'c0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', now() - INTERVAL '35 days', 'active', 'Grade A Super', 1240, 'Batch aktif periode panen minggu ke-3')
ON CONFLICT (code) DO NOTHING;

-- 4. Seed Baglog Sampel (untuk status agregasi di Beranda)
INSERT INTO baglogs (id, code, batch_id, rak_id, column_no, status, planted_at)
VALUES
  ('10000000-0000-0000-0000-000000000001', 'B-04-01', 'f0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002', 1, 'sehat', now() - INTERVAL '35 days'),
  ('10000000-0000-0000-0000-000000000002', 'B-04-02', 'f0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002', 2, 'sehat', now() - INTERVAL '35 days'),
  ('10000000-0000-0000-0000-000000000003', 'B-04-03', 'f0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002', 3, 'bisa_diobati', now() - INTERVAL '35 days'),
  ('10000000-0000-0000-0000-000000000004', 'B-04-04', 'f0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002', 4, 'sehat', now() - INTERVAL '35 days'),
  ('10000000-0000-0000-0000-000000000005', 'B-04-05', 'f0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002', 5, 'sehat', now() - INTERVAL '35 days'),
  ('10000000-0000-0000-0000-000000000006', 'B-04-06', 'f0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002', 6, 'afkir', now() - INTERVAL '35 days'),
  ('10000000-0000-0000-0000-000000000007', 'B-04-07', 'f0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002', 7, 'sehat', now() - INTERVAL '35 days'),
  ('10000000-0000-0000-0000-000000000008', 'B-04-08', 'f0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002', 8, 'sehat', now() - INTERVAL '35 days')
ON CONFLICT (code) DO NOTHING;

-- 5. Seed Panen (Hari Ini & Kemarin untuk Beranda)
INSERT INTO harvest_entries (id, user_id, batch_id, kumbung_id, harvested_at, weight_kg, price_per_kg, gross_income, note)
VALUES
  ('20000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', now() - INTERVAL '1 day', 38.00, 15000, 570000, 'Panen pagi hari kemarin'),
  ('20000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', now(), 45.50, 15000, 682500, 'Panen pagi hari ini')
ON CONFLICT (id) DO NOTHING;

-- 6. Seed Inspeksi Harian
INSERT INTO daily_inspections (id, kumbung_id, date, target, checked_count)
VALUES
  ('30000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', CURRENT_DATE, 100, 68)
ON CONFLICT (kumbung_id, date) DO UPDATE SET checked_count = EXCLUDED.checked_count;

-- 7. Seed Penyakit + Label On-Device TFLite (3 Kelas MobileNetV2 + Referensi Umum)
INSERT INTO diseases
  (id, name, scientific_name, category, default_severity, ml_label, is_healthy, location_hint, description, is_active, created_at, updated_at)
VALUES
  -- 3 Kelas Utama Model On-Device Flutter
  ('d0000000-0000-0000-0000-000000000001', 'Baglog Sehat Produktif', 'Pleurotus ostreatus', 'sehat', 'healthy', 'Healthy', TRUE,
   'Seluruh Baglog', 'Baglog dalam kondisi optimal, miselium putih merambat tebal tanpa tanda kontaminasi penyakit.', TRUE, now(), now()),
  ('d0000000-0000-0000-0000-000000000002', 'Kontaminasi Tunggal (Bisa Diobati)', 'Trichoderma / Rhizopus / Aspergillus', 'jamur', 'treatable', 'Single_Infected', FALSE,
   'Cincin & Permukaan Baglog', 'Kontaminasi jamur/kapang pada satu area terlokalisir. Masih berpotensi diselamatkan melalui karantina dan tindakan kuratif.', TRUE, now(), now()),
  ('d0000000-0000-0000-0000-000000000003', 'Kontaminasi Ganda / Parah (Harus Dibuang)', 'Mixed Fungal Contamination', 'jamur', 'must_discard', 'Mixed_Infected', FALSE,
   'Sebagian Besar Substrat Baglog', 'Kontaminasi parah/komposit berbagai jenis jamur patogen. Wajib segera dibuang dan dimusnahkan agar tidak menulari seisi kumbung.', TRUE, now(), now()),

  -- Referensi Penyakit Spesifik (untuk edukasi & diagnosis manual)
  ('d0000000-0000-0000-0000-000000000004', 'Green Mold', 'Trichoderma sp.', 'jamur', 'treatable', 'green_mold', FALSE,
   'Cincin & Leher Baglog', 'Kontaminasi jamur hijau (Trichoderma).', TRUE, now(), now()),
  ('d0000000-0000-0000-0000-000000000005', 'Black Bread Mold', 'Rhizopus sp.', 'jamur', 'must_discard', 'black_bread_mold', FALSE,
   'Permukaan baglog', 'Kontaminasi Rhizopus (spora hitam).', TRUE, now(), now()),
  ('d0000000-0000-0000-0000-000000000006', 'Bacterial Brown Blotch', 'Pseudomonas sp.', 'bakteri', 'treatable', 'bacterial_brown_blotch', FALSE,
   'Permukaan baglog', 'Bercak cokelat akibat bakteri.', TRUE, now(), now()),
  ('d0000000-0000-0000-0000-000000000007', 'Cobweb Mold', 'Dactylium dendroides', 'jamur', 'treatable', 'cobweb_mold', FALSE,
   'Permukaan baglog', 'Jamur laba-laba (cobweb).', TRUE, now(), now()),
  ('d0000000-0000-0000-0000-000000000008', 'Bacterial Wet Spot', 'Bacillus sp.', 'bakteri', 'treatable', 'bacterial_wet_spot', FALSE,
   'Leher baglog', 'Area berlendir akibat bakteri.', TRUE, now(), now()),
  ('d0000000-0000-0000-0000-000000000009', 'Yellow Mold', 'Mycelium spp.', 'jamur', 'treatable', 'yellow_mold', FALSE,
   'Permukaan baglog', 'Kontaminasi jamur kuning.', TRUE, now(), now()),
  ('d0000000-0000-0000-0000-000000000010', 'Neurospora', 'Neurospora crassa', 'jamur', 'must_discard', 'neurospora', FALSE,
   'Permukaan baglog', 'Kontaminasi Neurospora (spora oranye).', TRUE, now(), now())
ON CONFLICT (ml_label) DO NOTHING;

-- 8. Langkah Penanganan (SOP) Per Penyakit
INSERT INTO disease_steps (id, disease_id, step_order, title, description)
SELECT gen_random_uuid(), d.id, s.step_order, s.title, s.description
FROM diseases d
JOIN (VALUES
  -- SOP untuk 3 Kelas Model On-Device
  ('Healthy', 1, 'Jaga Kelembapan Optimal', 'Pertahankan kelembapan relatif 80-90% dengan penyemprotan kabut halus 2-3 kali sehari.'),
  ('Healthy', 2, 'Pastikan Sirkulasi Udara Lancar', 'Buka ventilasi kumbung secara berkala agar sirkulasi oksigen optimal untuk pembentukan pinhead.'),
  ('Single_Infected', 1, 'Pindahkan ke Rak Karantina', 'Segera pisahkan baglog dari rak utama kumbung untuk mencegah penularan spora via sirkulasi udara lembap.'),
  ('Single_Infected', 2, 'Kerik Lembut Spora / Jamur Liar', 'Gunakan sendok makan bersih steril alkohol 70%. Kerik hingga batas miselium putih yang masih segar.'),
  ('Single_Infected', 3, 'Oles Larutan Kapur Tohor (CaCO3)', 'Oleskan pasta kapur tohor pekat atau fungisida nabati rebusan daun sirih ke bekas kerokan untuk menaikkan pH lokal.'),
  ('Single_Infected', 4, 'Observasi Pemulihan 48 Jam', 'Jika miselium putih tumbuh menutupi bekas luka, baglog aman. Jika spora meluas, segera buang dari kumbung.'),
  ('Mixed_Infected', 1, 'Bungkus Rapat dengan Plastik', 'Tutup baglog rapat sebelum dipindahkan dari rak agar spora infeksi ganda tidak menyebar di udara kumbung.'),
  ('Mixed_Infected', 2, 'Keluarkan & Musnahkan Segera', 'Segera buang atau kubur jauh dari area budidaya kumbung. Jangan biarkan menumpuk di sekitar kumbung.'),
  ('Mixed_Infected', 3, 'Sterilisasi Lokasi Rak', 'Semprot rak tempat baglog diletakkan dengan alkohol 70% atau disinfektan untuk mematikan sisa spora patogen.'),

  -- SOP untuk Penyakit Referensi
  ('green_mold', 1, 'Pindahkan ke Rak Karantina', 'Segera pisahkan baglog dari rak utama kumbung untuk mencegah penularan spora via sirkulasi udara lembap.'),
  ('green_mold', 2, 'Kerik Lembut Spora Hijau', 'Gunakan sendok makan bersih yang telah disterilkan alkohol 70%. Kerik hingga batas miselium putih yang masih segar.'),
  ('green_mold', 3, 'Oles Larutan Kapur Tohor (CaCO3)', 'Oleskan pasta kapur tohor pekat atau fungisida nabati rebusan daun sirih ke bekas kerokan untuk menaikkan pH lokal.'),
  ('green_mold', 4, 'Observasi Pemulihan 48 Jam', 'Jika miselium putih tumbuh menutupi bekas luka, baglog aman. Jika spora menghitam/meluas, segera buang dari kumbung.'),
  ('black_bread_mold', 1, 'Isolasi Segera dengan Plastik', 'Tutup baglog rapat dengan plastik sebelum dipindahkan agar spora hitam tidak berterbangan di dalam kumbung.'),
  ('black_bread_mold', 2, 'Musnahkan Jauh dari Kumbung', 'Segera bakar atau kubur jauh dari kumbung; bersihkan rak bekas baglog dengan disinfektan.'),
  ('bacterial_brown_blotch', 1, 'Keringkan Permukaan Bercak', 'Bersihkan permukaan bercak cokelat secara lembut memakai lap bersih kering sekali pakai.'),
  ('bacterial_brown_blotch', 2, 'Semprot Larutan Kalsium Hipoklorit Encer', 'Semprotkan larutan desinfektan encer dan tingkatkan sirkulasi udara kumbung.'),
  ('cobweb_mold', 1, 'Pisahkan ke Area Karantina', 'Jauhkan baglog dari rak produksi aktif agar hifa laba-laba tidak merambat ke baglog sebelah.'),
  ('cobweb_mold', 2, 'Semprot Rebusan Sirih & Kapur Tohor', 'Semprotkan fungisida nabati rebusan daun sirih dan taburi kapur tohor tipis di area terdampak.'),
  ('bacterial_wet_spot', 1, 'Sanitasi Area Berlendir', 'Lap area berlendir dan lakukan sanitasi klorin encer untuk membendung bakteri anaerob.'),
  ('bacterial_wet_spot', 2, 'Perbaiki Sirkulasi & Kelembapan', 'Kurangi penyemprotan kabut sementara dan pastikan ventilasi kumbung lancar.'),
  ('yellow_mold', 1, 'Karantina & Kerik Area Kuning', 'Pisahkan baglog dari rak utama, lalu kerik tipis bagian substrat yang menguning.'),
  ('yellow_mold', 2, 'Oles Kapur & Pantau 48 Jam', 'Oleskan larutan kapur tohor dan amati perkembangan miselium putih.'),
  ('neurospora', 1, 'Tutup Mulut Baglog & Keluarkan', 'Spora oranye menyebar sangat cepat melalui udara; bungkus baglog sebelum dikeluarkan dari kumbung.'),
  ('neurospora', 2, 'Bakar/Musnahkan & Sterilisasi Rak', 'Musnahkan baglog di luar area budidaya dan semprot rak dengan alkohol 70% atau disinfektan.')
) AS s(ml_label, step_order, title, description) ON d.ml_label = s.ml_label
WHERE NOT EXISTS (
  SELECT 1 FROM disease_steps ds WHERE ds.disease_id = d.id
);

COMMIT;
