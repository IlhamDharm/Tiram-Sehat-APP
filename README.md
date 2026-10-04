# tiram_sehat

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## 👥 Team

| No. | Name | Student ID |
|:---:|---|:---:|
| 1 | Achmad Nabil Afgareza | 244107020001 |
| 2 | Amin Aziz Sudjud | 244107020079 |
| 3 | Aryan Zuda Firdaus | 244107020060 |
| 4 | Fazel Priyono | 244107020033 |
| 5 | Ilham Dharma Atmaja | 244107020220 |

## 📌 Project Description

### What
**Tiram Sehat** adalah aplikasi mobile Android berbasis Machine Learning
(Computer Vision) yang dirancang untuk mendeteksi kondisi baglog jamur tiram,
khususnya membedakan baglog **Sehat** dan **Terkontaminasi** melalui kamera
smartphone.

### Why
Proses pemeriksaan baglog masih dilakukan secara manual sehingga membutuhkan
waktu dan memiliki risiko keterlambatan dalam mengenali kontaminasi. Kontaminasi
yang tidak segera ditangani dapat menyebar ke baglog lain dan menyebabkan
kerugian serta gagal panen.

### Who
MushScan ditujukan untuk **petani dan pengelola BUMDes Desa Margomulyo,
Kabupaten Banyuwangi** sebagai pengguna utama dalam melakukan inspeksi baglog
jamur tiram.

### Where
Aplikasi dirancang untuk digunakan pada **kumbung budidaya jamur tiram BUMDes
Desa Margomulyo, Kabupaten Banyuwangi**, termasuk sebagai lokasi pengambilan
data dan pengujian lapangan.

### When
Project ini dikembangkan dalam periode **16 minggu** sebagai bagian dari
Project Based Learning (PBL) Program Studi Sarjana Terapan Teknik Informatika,
Politeknik Negeri Malang, Tahun Akademik 2026/2027.

### How
MushScan menggunakan **Computer Vision** dengan model CNN/MobileNet yang
dikonversi ke **TensorFlow Lite** dan dijalankan secara **on-device** pada
smartphone. Pengguna dapat mengambil gambar baglog melalui kamera atau
mengunggah gambar dari galeri. Sistem kemudian melakukan klasifikasi dan
menampilkan status **Sehat/Terkontaminasi** beserta confidence score serta
rekomendasi mitigasi apabila ditemukan kontaminasi.
