/// Ringkasan batch tanam yang sedang berjalan.
class BatchData {
  final String code;
  final String variety;
  final int day;
  final String grade;
  final String weighedAt;

  const BatchData({
    required this.code,
    required this.variety,
    required this.day,
    required this.grade,
    required this.weighedAt,
  });
}

/// Data laporan produksi yang ditampilkan pada layar Evaluasi & Laporan.
class ReportData {
  final double todayKg;
  final double deltaKg;
  final double deltaPct;
  final int salesToday;
  final int pricePerKg;
  final double success;
  final int totalBaglog;
  final int healthy;
  final int contaminated;
  final List<double> trend;
  final double trendDelta;
  final int monthIncome;
  final double monthKg;
  final int monthLoss;
  final int lossReducedPct;
  final BatchData batch;

  const ReportData({
    required this.todayKg,
    required this.deltaKg,
    required this.deltaPct,
    required this.salesToday,
    required this.pricePerKg,
    required this.success,
    required this.totalBaglog,
    required this.healthy,
    required this.contaminated,
    required this.trend,
    required this.trendDelta,
    required this.monthIncome,
    required this.monthKg,
    required this.monthLoss,
    required this.lossReducedPct,
    required this.batch,
  });
}
