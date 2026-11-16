import '../features/harvest/domain/models/harvest_entry.dart';
import '../features/history/domain/models/history_item.dart';
import '../features/report/domain/models/report_data.dart';

/// Data contoh untuk mode prototipe/offline.
///
/// File ini hanya boleh diimpor oleh datasource mock/local. Layer UI dan
/// service produksi harus bergantung pada model domain, bukan pada folder ini.
class MockData {
  static const harvestLast = HarvestEntry(
    date: 'Kamis, 24 Okt 2024 - 07:30 WIB',
    weightKg: 18.5,
    pricePerKg: 15000,
    grossIncome: 277500,
    buyer: 'Tengkulak Margomulyo',
    note: 'Panen petik ke-3 kumbung selatan, kualitas baglog prima tanpa bercak.',
  );

  static const harvestHistory = <HarvestEntry>[
    harvestLast,
    HarvestEntry(
      date: 'Rabu, 23 Okt 2024 - 07:15 WIB',
      weightKg: 20.0,
      pricePerKg: 15000,
      grossIncome: 300000,
      buyer: 'Pasar Tradisional',
      note: 'Panen pagi rak B-01 s/d B-05, jamur mekar segar.',
    ),
    HarvestEntry(
      date: 'Selasa, 22 Okt 2024 - 07:45 WIB',
      weightKg: 16.5,
      pricePerKg: 14500,
      grossIncome: 239250,
      buyer: 'Tengkulak Margomulyo',
      note: 'Sortasi grade A dominan, tanpa bercak kuning.',
    ),
    HarvestEntry(
      date: 'Senin, 21 Okt 2024 - 07:20 WIB',
      weightKg: 22.0,
      pricePerKg: 15000,
      grossIncome: 330000,
      buyer: 'Pengecer Langganan',
      note: 'Petik raya kumbung barat, kondisi kumbung lembap optimal.',
    ),
    HarvestEntry(
      date: 'Minggu, 20 Okt 2024 - 07:30 WIB',
      weightKg: 19.0,
      pricePerKg: 14000,
      grossIncome: 266000,
      buyer: 'Pasar Tradisional',
      note: 'Borongan eceran pasar minggu.',
    ),
  ];

  static final List<HistoryItem> historyList = [
    // 1. Perlu Tindakan
    HistoryItem(
      id: 'h-01',
      name: 'Green Mold (Trichoderma sp.)',
      badge: 'Bisa Diobati',
      tone: 'warning',
      when: 'Hari ini, 09:15',
      rack: 'Rak Kumbung B-04',
      col: 3,
      category: HistorySectionCategory.actionRequired,
      isInitiallyExpanded: false,
    ),
    HistoryItem(
      id: 'h-02',
      name: 'Black Bread Mold (Rhizopus)',
      badge: 'Harus Dibuang',
      tone: 'danger',
      when: '22 Okt, 11:20',
      rack: 'Rak Kumbung C-01',
      col: 5,
      category: HistorySectionCategory.actionRequired,
      status: 'Status: Menunggu Pemusnahan',
      tag: 'Urgen',
      note:
          'Segera bakar atau buang jauh dari kumbung agar spora hitam tidak menyebar ke baglog sehat di sekitarnya.',
      actionLabel: 'Konfirmasi Buang Baglog',
      isInitiallyExpanded: true,
    ),
    HistoryItem(
      id: 'h-03',
      name: 'Bacterial Brown Blotch',
      badge: 'Bisa Diobati',
      tone: 'warning',
      when: '21 Okt, 08:45',
      rack: 'Rak Kumbung A-07',
      col: 2,
      category: HistorySectionCategory.actionRequired,
      status: 'Status: Menunggu Desinfeksi',
      tag: 'Perawatan Ringan',
      note:
          'Pembersihan permukaan bercak cokelat dengan lap bersih kering & semprot larutan kalsium hipoklorit encer.',
      actionLabel: 'Konfirmasi Selesai Diobati',
      isInitiallyExpanded: true,
    ),

    // 2. Selesai Diobati & Pulih
    HistoryItem(
      id: 'h-06',
      name: 'Cobweb Mold (Dactylium)',
      badge: 'Selesai Diobati',
      tone: 'success',
      when: '20 Okt, 14:10',
      rack: 'Rak Kumbung A-02',
      col: 1,
      category: HistorySectionCategory.recovered,
      status: 'Miselium Kembali Merambat Aktif',
      tag: 'Karantina Tuntas',
      note:
          'Telah disemprot fungisida nabati rebusan sirih & kapur tohor. Spora putih laba-laba mati tuntas, miselium sehat telah menutup 95% kembali ke rak produksi.',
      isInitiallyExpanded: true,
    ),
    HistoryItem(
      id: 'h-07',
      name: 'Bacterial Wet Spot',
      badge: 'Selesai Diobati',
      tone: 'success',
      when: '19 Okt, 16:30',
      rack: 'Rak Kumbung B-09',
      col: 4,
      category: HistorySectionCategory.recovered,
      status: 'Area Berlendir Kering Sempurna',
      tag: 'Stabil',
      note:
          'Sanitasi klorin encer berhasil membendung bakteri anaerob. Sirkulasi kumbung ditingkatkan, pinhead baru mulai terbentuk normal.',
      isInitiallyExpanded: true,
    ),

    // 3. Riwayat Terarsip
    HistoryItem(
      id: 'h-08',
      name: 'Yellow Mold (Mycelium …)',
      badge: 'Tersanitasi',
      tone: 'warning',
      when: '18 Okt',
      rack: 'Rak Kumbung A-03',
      col: 7,
      category: HistorySectionCategory.archived,
    ),
    HistoryItem(
      id: 'h-09',
      name: 'Neurospora crassa',
      badge: 'Telah Dibuang',
      tone: 'danger',
      when: '17 Okt',
      rack: 'Rak Kumbung D-02',
      col: 3,
      category: HistorySectionCategory.archived,
    ),
  ];

  static const report = ReportData(
    todayKg: 24.5,
    deltaKg: 4.2,
    deltaPct: 18.0,
    salesToday: 367500,
    pricePerKg: 15000,
    success: 0.894,
    totalBaglog: 2400,
    healthy: 2146,
    contaminated: 254,
    trend: [82.0, 85.0, 88.0, 89.4],
    trendDelta: 7.4,
    monthIncome: 8420000,
    monthKg: 561.3,
    monthLoss: 420000,
    lossReducedPct: 65,
    batch: BatchData(
      code: 'Batch Panen K-04 Margomulyo',
      variety: 'Florida Putih',
      day: 42,
      grade: '98% Grade A',
      weighedAt: '07:30 WIB',
    ),
  );
}
