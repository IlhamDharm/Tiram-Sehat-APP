/// Satu catatan panen/penjualan pada Buku Panen.
class HarvestEntry {
  final String date;
  final double weightKg;
  final int pricePerKg;
  final int grossIncome;
  final String? note;
  final String? buyer;

  const HarvestEntry({
    required this.date,
    required this.weightKg,
    required this.pricePerKg,
    required this.grossIncome,
    this.note,
    this.buyer,
  });
}
