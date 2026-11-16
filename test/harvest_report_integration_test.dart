import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiram_sehat/features/harvest/harvest_provider.dart';
import 'package:tiram_sehat/features/report/report_provider.dart';
import 'package:tiram_sehat/mock/mock_data.dart';

void main() {
  group('Harvest & Report Integration Tests', () {
    test('Sunday to Saturday week calculation (1 Pekan)', () {
      // Thursday, 24 October 2024
      final thursday = DateTime(2024, 10, 24);
      final sunday = getSundayOfWeek(thursday);
      final saturday = getSaturdayOfWeek(thursday);

      // Verify Sunday is 20 Oct 2024
      expect(sunday.year, 2024);
      expect(sunday.month, 10);
      expect(sunday.day, 20);
      expect(sunday.weekday, DateTime.sunday);

      // Verify Saturday is 26 Oct 2024
      expect(saturday.year, 2024);
      expect(saturday.month, 10);
      expect(saturday.day, 26);
      expect(saturday.weekday, DateTime.saturday);
    });

    test('Weekly income is accumulated from Sunday to Saturday entries', () {
      final container = ProviderContainer(
        overrides: [
          selectedReportDateProvider.overrideWith((ref) => DateTime(2024, 10, 24)),
        ],
      );
      addTearDown(container.dispose);

      final weeklySummary = container.read(weeklyHarvestReportProvider);

      // 7 days in chart: Min, Sen, Sel, Rab, Kam, Jum, Sab
      expect(weeklySummary.dailyKg.length, 7);
      expect(weeklySummary.dayLabels, ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab']);

      // Minggu 20 Okt: 16.0 Kg @ 15.000 = Rp 240.000
      // Senin 21 Okt: 17.5 Kg @ 15.000 = Rp 262.500
      // Selasa 22 Okt: 19.0 Kg @ 15.000 = Rp 285.000
      // Rabu 23 Okt: 20.3 Kg @ 15.000 = Rp 304.500
      // Kamis 24 Okt: 24.5 Kg @ 15.000 = Rp 367.500
      // Jumat 25 Okt: 22.0 Kg @ 15.000 = Rp 330.000
      // Sabtu 26 Okt: 25.5 Kg @ 15.000 = Rp 382.500
      // Total Kg = 144.8 Kg
      // Total Income = Rp 2.172.000
      expect(weeklySummary.totalKg, closeTo(144.8, 0.01));
      expect(weeklySummary.totalIncome, 2172000);

      // Verify each daily point on the chart
      expect(weeklySummary.dailyKg[0], 16.0); // Min
      expect(weeklySummary.dailyKg[1], 17.5); // Sen
      expect(weeklySummary.dailyKg[2], 19.0); // Sel
      expect(weeklySummary.dailyKg[3], 20.3); // Rab
      expect(weeklySummary.dailyKg[4], 24.5); // Kam
      expect(weeklySummary.dailyKg[5], 22.0); // Jum
      expect(weeklySummary.dailyKg[6], 25.5); // Sab
    });

    test('Adding a harvest entry updates weekly accumulation and chart dynamically', () {
      final container = ProviderContainer(
        overrides: [
          selectedReportDateProvider.overrideWith((ref) => DateTime(2024, 10, 24)),
        ],
      );
      addTearDown(container.dispose);

      final before = container.read(weeklyHarvestReportProvider);
      expect(before.totalIncome, 2172000);
      expect(before.dailyKg[4], 24.5); // Thursday

      // Add a new harvest on Thursday, 24 Okt 2024: 10.0 Kg @ Rp 15.000 (Rp 150.000)
      container.read(harvestListProvider.notifier).addHarvest(
            HarvestEntry(
              dateTime: DateTime(2024, 10, 24, 14, 0),
              weightKg: 10.0,
              pricePerKg: 15000,
              grossIncome: 150000,
              note: 'Petikan tambahan sore hari',
            ),
          );

      final after = container.read(weeklyHarvestReportProvider);

      // Weekly income increases by 150.000 -> 2.322.000
      expect(after.totalIncome, 2172000 + 150000);
      // Weekly weight increases by 10.0 -> 154.8
      expect(after.totalKg, closeTo(154.8, 0.01));
      // Thursday's chart point increases from 24.5 to 34.5
      expect(after.dailyKg[4], 34.5);
    });
  });
}

