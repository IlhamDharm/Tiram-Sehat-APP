import '../../../../core/format/format_helper.dart';

/// Satu catatan panen/penjualan pada Buku Panen.
///
/// Mendukung dua cara pengisian:
/// - [dateTime] untuk perhitungan laporan dinamis (minggu/bulan/tahun).
/// - [date] untuk teks tanggal yang sudah diformat (mis. hasil input manual).
class HarvestEntry {
  final String id;
  final DateTime dateTime;
  final double weightKg;
  final int pricePerKg;
  final int grossIncome;
  final String? note;
  final String? buyer;
  final String? customDate;

  HarvestEntry({
    String? id,
    DateTime? dateTime,
    String? date,
    required this.weightKg,
    required this.pricePerKg,
    int? grossIncome,
    this.note,
    this.buyer,
    String? customDate,
  })  : dateTime = dateTime ?? DateTime.now(),
        customDate = customDate ?? date,
        id = id ?? '${(dateTime ?? DateTime.now()).millisecondsSinceEpoch}_$weightKg',
        grossIncome = grossIncome ?? (weightKg * pricePerKg).round();

  String get date => customDate ?? FormatHelper.dateTimeLong(dateTime);
}
