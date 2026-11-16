class RecentHarvest {
  final String id;
  final DateTime harvestedAt;
  final double weightKg;
  final int grossIncome;

  const RecentHarvest({
    required this.id,
    required this.harvestedAt,
    required this.weightKg,
    required this.grossIncome,
  });

  factory RecentHarvest.fromJson(Map<String, dynamic> json) {
    final rawStr = json['harvested_at'] as String? ?? '';
    final parsed = DateTime.tryParse(rawStr) ?? DateTime.now();
    return RecentHarvest(
      id: json['id'] as String? ?? '',
      harvestedAt: parsed.toLocal(),
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 0.0,
      grossIncome: (json['gross_income'] as num?)?.toInt() ?? 0,
    );
  }
}

class SelfCheckSummary {
  final int checked;
  final int target;

  const SelfCheckSummary({
    required this.checked,
    required this.target,
  });

  factory SelfCheckSummary.fromJson(Map<String, dynamic> json) {
    return SelfCheckSummary(
      checked: (json['checked'] as num).toInt(),
      target: (json['target'] as num).toInt(),
    );
  }
}

class HomeSummary {
  final String date;
  final double todayKg;
  final int todayIncome;
  final double deltaPct;
  final int activeBaglogs;
  final int healthyBaglogs;
  final int contaminatedBaglogs;
  final Map<String, int> baglogBreakdown;
  final SelfCheckSummary selfCheck;
  final List<RecentHarvest> recentHarvests;

  const HomeSummary({
    required this.date,
    required this.todayKg,
    required this.todayIncome,
    required this.deltaPct,
    required this.activeBaglogs,
    required this.healthyBaglogs,
    required this.contaminatedBaglogs,
    required this.baglogBreakdown,
    required this.selfCheck,
    required this.recentHarvests,
  });

  factory HomeSummary.fromJson(Map<String, dynamic> json) {
    final breakdownRaw = json['baglog_breakdown'] as Map<String, dynamic>? ?? {};
    final breakdown = breakdownRaw.map(
      (key, value) => MapEntry(key, (value as num).toInt()),
    );

    final harvestsRaw = json['recent_harvests'] as List<dynamic>? ?? [];
    final harvests = harvestsRaw
        .map((e) => RecentHarvest.fromJson(e as Map<String, dynamic>))
        .toList();

    return HomeSummary(
      date: json['date'] as String? ?? '',
      todayKg: (json['today_kg'] as num?)?.toDouble() ?? 0.0,
      todayIncome: (json['today_income'] as num?)?.toInt() ?? 0,
      deltaPct: (json['delta_pct'] as num?)?.toDouble() ?? 0.0,
      activeBaglogs: (json['active_baglogs'] as num?)?.toInt() ?? 0,
      healthyBaglogs: (json['healthy_baglogs'] as num?)?.toInt() ?? 0,
      contaminatedBaglogs: (json['contaminated_baglogs'] as num?)?.toInt() ?? 0,
      baglogBreakdown: breakdown,
      selfCheck: SelfCheckSummary.fromJson(
          json['self_check'] as Map<String, dynamic>? ?? {'checked': 0, 'target': 0}),
      recentHarvests: harvests,
    );
  }

  /// Derived: treatable baglogs = bisa_diobati + sedang_diobati
  int get treatableBaglogs =>
      (baglogBreakdown['bisa_diobati'] ?? 0) +
      (baglogBreakdown['sedang_diobati'] ?? 0);

  /// Derived: discarded baglogs = afkir + dibuang
  int get discardedBaglogs =>
      (baglogBreakdown['afkir'] ?? 0) + (baglogBreakdown['dibuang'] ?? 0);

  /// Derived: health ratio
  double get healthRatio =>
      activeBaglogs > 0 ? healthyBaglogs / activeBaglogs : 0.0;

  /// Derived: price per kg
  int get pricePerKg =>
      todayKg > 0 ? (todayIncome / todayKg).round() : 0;
}
