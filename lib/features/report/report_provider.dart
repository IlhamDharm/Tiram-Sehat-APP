import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format/format_helper.dart';
import '../../mock/mock_data.dart';
import '../harvest/harvest_provider.dart';

DateTime getSundayOfWeek(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  final daysSinceSunday = d.weekday == DateTime.sunday ? 0 : d.weekday;
  return d.subtract(Duration(days: daysSinceSunday));
}

DateTime getSaturdayOfWeek(DateTime date) {
  final sun = getSundayOfWeek(date);
  return DateTime(sun.year, sun.month, sun.day, 23, 59, 59, 999).add(const Duration(days: 6));
}

final selectedReportDateProvider = StateProvider<DateTime>((ref) {
  final harvests = ref.watch(harvestListProvider);
  if (harvests.isNotEmpty) {
    return harvests.first.dateTime;
  }
  return DateTime(2024, 10, 24);
});

class WeeklyReportSummary {
  final DateTime startDate;
  final DateTime endDate;
  final double totalKg;
  final int totalIncome;
  final double avgPrice;
  final double prevWeekKg;
  final int prevWeekIncome;
  final double deltaKg;
  final double deltaPct;
  final List<double> dailyKg;
  final List<int> dailyIncome;
  final List<String> dayLabels;
  final List<DateTime> dayDates;
  final List<HarvestEntry> entries;

  const WeeklyReportSummary({
    required this.startDate,
    required this.endDate,
    required this.totalKg,
    required this.totalIncome,
    required this.avgPrice,
    required this.prevWeekKg,
    required this.prevWeekIncome,
    required this.deltaKg,
    required this.deltaPct,
    required this.dailyKg,
    required this.dailyIncome,
    required this.dayLabels,
    required this.dayDates,
    required this.entries,
  });

  String get periodLabel => FormatHelper.dateRange(startDate, endDate);

  String get deltaKgText {
    final prefix = deltaKg >= 0 ? '+' : '';
    return '$prefix${FormatHelper.kg(deltaKg)}';
  }

  String get deltaPctText {
    final prefix = deltaPct >= 0 ? '+' : '';
    return '$prefix${deltaPct.toStringAsFixed(1)}%';
  }

  double get maxDailyKg {
    if (dailyKg.isEmpty) return 0.0;
    return dailyKg.reduce((a, b) => a > b ? a : b);
  }
}

class MonthlyReportSummary {
  final int year;
  final int month;
  final String monthName;
  final double totalKg;
  final int totalIncome;
  final double avgPrice;
  final double prevMonthKg;
  final int prevMonthIncome;
  final double deltaKg;
  final double deltaPct;
  final List<double> weeklyKg;
  final List<int> weeklyIncome;
  final List<String> weekLabels;

  const MonthlyReportSummary({
    required this.year,
    required this.month,
    required this.monthName,
    required this.totalKg,
    required this.totalIncome,
    required this.avgPrice,
    required this.prevMonthKg,
    required this.prevMonthIncome,
    required this.deltaKg,
    required this.deltaPct,
    required this.weeklyKg,
    required this.weeklyIncome,
    required this.weekLabels,
  });

  String get deltaKgText {
    final prefix = deltaKg >= 0 ? '+' : '';
    return '$prefix${FormatHelper.kg(deltaKg)}';
  }

  String get deltaPctText {
    final prefix = deltaPct >= 0 ? '+' : '';
    return '$prefix${deltaPct.toStringAsFixed(1)}%';
  }
}

class YearlyReportSummary {
  final int year;
  final double totalKg;
  final int totalIncome;
  final double avgPrice;
  final List<double> quarterlyKg;
  final List<String> quarterLabels;

  const YearlyReportSummary({
    required this.year,
    required this.totalKg,
    required this.totalIncome,
    required this.avgPrice,
    required this.quarterlyKg,
    required this.quarterLabels,
  });
}

final weeklyHarvestReportProvider = Provider<WeeklyReportSummary>((ref) {
  final harvests = ref.watch(harvestListProvider);
  final anchorDate = ref.watch(selectedReportDateProvider);

  final sunday = getSundayOfWeek(anchorDate);
  final saturday = getSaturdayOfWeek(anchorDate);

  // Filter panen di pekan Minggu s/d Sabtu
  final thisWeekEntries = harvests.where((h) {
    return !h.dateTime.isBefore(sunday) && !h.dateTime.isAfter(saturday);
  }).toList();

  final dailyKg = List<double>.filled(7, 0.0);
  final dailyIncome = List<int>.filled(7, 0);
  final dayDates = <DateTime>[];
  const dayNames = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];

  for (int i = 0; i < 7; i++) {
    final currentDay = sunday.add(Duration(days: i));
    dayDates.add(currentDay);

    final dayEntries = thisWeekEntries.where((h) =>
      h.dateTime.year == currentDay.year &&
      h.dateTime.month == currentDay.month &&
      h.dateTime.day == currentDay.day
    );

    for (final e in dayEntries) {
      dailyKg[i] += e.weightKg;
      dailyIncome[i] += e.grossIncome;
    }
  }

  final totalKg = dailyKg.reduce((a, b) => a + b);
  final totalIncome = dailyIncome.reduce((a, b) => a + b);
  final avgPrice = totalKg > 0 ? (totalIncome / totalKg) : 15000.0;

  // Pekan sebelumnya untuk kalkulasi pertumbuhan
  final prevSunday = sunday.subtract(const Duration(days: 7));
  final prevSaturday = DateTime(prevSunday.year, prevSunday.month, prevSunday.day, 23, 59, 59, 999).add(const Duration(days: 6));

  final prevWeekEntries = harvests.where((h) {
    return !h.dateTime.isBefore(prevSunday) && !h.dateTime.isAfter(prevSaturday);
  }).toList();

  final prevWeekKg = prevWeekEntries.fold<double>(0.0, (sum, e) => sum + e.weightKg);
  final prevWeekIncome = prevWeekEntries.fold<int>(0, (sum, e) => sum + e.grossIncome);

  final deltaKg = totalKg - prevWeekKg;
  final deltaPct = prevWeekKg > 0 ? ((totalKg - prevWeekKg) / prevWeekKg) * 100 : 0.0;

  return WeeklyReportSummary(
    startDate: sunday,
    endDate: saturday,
    totalKg: totalKg,
    totalIncome: totalIncome,
    avgPrice: avgPrice,
    prevWeekKg: prevWeekKg,
    prevWeekIncome: prevWeekIncome,
    deltaKg: deltaKg,
    deltaPct: deltaPct,
    dailyKg: dailyKg,
    dailyIncome: dailyIncome,
    dayLabels: dayNames,
    dayDates: dayDates,
    entries: thisWeekEntries,
  );
});

final monthlyHarvestReportProvider = Provider<MonthlyReportSummary>((ref) {
  final harvests = ref.watch(harvestListProvider);
  final anchorDate = ref.watch(selectedReportDateProvider);

  final year = anchorDate.year;
  final month = anchorDate.month;

  final thisMonthEntries = harvests.where((h) {
    return h.dateTime.year == year && h.dateTime.month == month;
  }).toList();

  final totalKg = thisMonthEntries.fold<double>(0.0, (sum, e) => sum + e.weightKg);
  final totalIncome = thisMonthEntries.fold<int>(0, (sum, e) => sum + e.grossIncome);
  final avgPrice = totalKg > 0 ? (totalIncome / totalKg) : 15000.0;

  // Akumulasi 4 pekan dalam sebulan
  final weeklyKg = <double>[0.0, 0.0, 0.0, 0.0];
  final weeklyIncome = <int>[0, 0, 0, 0];
  for (final e in thisMonthEntries) {
    int weekIndex = ((e.dateTime.day - 1) ~/ 7).clamp(0, 3);
    weeklyKg[weekIndex] += e.weightKg;
    weeklyIncome[weekIndex] += e.grossIncome;
  }

  // Bulan sebelumnya
  final prevMonthDate = month == 1 ? DateTime(year - 1, 12) : DateTime(year, month - 1);
  final prevMonthEntries = harvests.where((h) {
    return h.dateTime.year == prevMonthDate.year && h.dateTime.month == prevMonthDate.month;
  }).toList();

  final prevMonthKg = prevMonthEntries.fold<double>(0.0, (sum, e) => sum + e.weightKg);
  final prevMonthIncome = prevMonthEntries.fold<int>(0, (sum, e) => sum + e.grossIncome);
  final deltaKg = totalKg - prevMonthKg;
  final deltaPct = prevMonthKg > 0 ? ((totalKg - prevMonthKg) / prevMonthKg) * 100 : 0.0;

  return MonthlyReportSummary(
    year: year,
    month: month,
    monthName: '${FormatHelper.namaBulan[month - 1]} $year',
    totalKg: totalKg,
    totalIncome: totalIncome,
    avgPrice: avgPrice,
    prevMonthKg: prevMonthKg,
    prevMonthIncome: prevMonthIncome,
    deltaKg: deltaKg,
    deltaPct: deltaPct,
    weeklyKg: weeklyKg,
    weeklyIncome: weeklyIncome,
    weekLabels: [
      'M1: ${FormatHelper.kg(weeklyKg[0])}',
      'M2: ${FormatHelper.kg(weeklyKg[1])}',
      'M3: ${FormatHelper.kg(weeklyKg[2])}',
      FormatHelper.kg(weeklyKg[3]),
    ],
  );
});

final yearlyHarvestReportProvider = Provider<YearlyReportSummary>((ref) {
  final harvests = ref.watch(harvestListProvider);
  final anchorDate = ref.watch(selectedReportDateProvider);
  final year = anchorDate.year;

  final thisYearEntries = harvests.where((h) => h.dateTime.year == year).toList();
  final totalKg = thisYearEntries.fold<double>(0.0, (sum, e) => sum + e.weightKg);
  final totalIncome = thisYearEntries.fold<int>(0, (sum, e) => sum + e.grossIncome);
  final avgPrice = totalKg > 0 ? (totalIncome / totalKg) : 15000.0;

  // Kuartal (Q1 - Q4)
  final quarterlyKg = <double>[0.0, 0.0, 0.0, 0.0];
  for (final e in thisYearEntries) {
    final q = ((e.dateTime.month - 1) ~/ 3).clamp(0, 3);
    quarterlyKg[q] += e.weightKg;
  }

  return YearlyReportSummary(
    year: year,
    totalKg: totalKg,
    totalIncome: totalIncome,
    avgPrice: avgPrice,
    quarterlyKg: quarterlyKg,
    quarterLabels: ['Q1', 'Q2', 'Q3', 'Q4'],
  );
});

