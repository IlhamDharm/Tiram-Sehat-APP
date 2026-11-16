import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiram_sehat/core/format/format_helper.dart';
import 'package:tiram_sehat/features/report/report_screen.dart';

void main() {
  test('FormatHelper.rupiahSingkat abbreviates rb, jt, and M properly', () {
    expect(FormatHelper.rupiahSingkat(500), 'Rp 500');
    expect(FormatHelper.rupiahSingkat(15000), 'Rp 15 rb');
    expect(FormatHelper.rupiahSingkat(25500), 'Rp 25,5 rb');
    expect(FormatHelper.rupiahSingkat(367500), 'Rp 367,5 rb');
    expect(FormatHelper.rupiahSingkat(1000000), 'Rp 1 jt');
    expect(FormatHelper.rupiahSingkat(1500000), 'Rp 1,5 jt');
    expect(FormatHelper.rupiahSingkat(2172000), 'Rp 2,17 jt');
    expect(FormatHelper.rupiahSingkat(18250000), 'Rp 18,3 jt');
    expect(FormatHelper.rupiahSingkat(105000000), 'Rp 105 jt');
    expect(FormatHelper.rupiahSingkat(1200000000), 'Rp 1,2 M');

    expect(FormatHelper.rupiahPerKgSingkat(15000), 'Rp 15 rb /Kg');
  });

  testWidgets('ReportScreen renders title, segmented tabs, and all report cards', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ReportScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('Evaluasi & Laporan'), findsOneWidget);

    // Verify Segmented Tabs
    expect(find.text('Minggu Ini'), findsOneWidget);
    expect(find.text('Bulan Ini'), findsOneWidget);
    expect(find.text('Tahun Ini'), findsOneWidget);

    // Verify Weekly Metric Tiles (from harvest accumulation)
    expect(find.text('Total Panen Minggu Ini'), findsOneWidget);
    expect(find.text('Penghasilan Minggu Ini'), findsOneWidget);

    // Verify SectionCards
    expect(find.text('Tingkat Keberhasilan Panen'), findsOneWidget);
    expect(find.text('89,4%'), findsOneWidget);
    expect(find.text('Akumulasi Pekan Ini'), findsOneWidget);
    expect(find.text('Total Pemasukan Panen'), findsOneWidget);
    expect(find.text('Estimasi Kerugian Baglog'), findsOneWidget);
    expect(find.text('Rp 420.000'), findsOneWidget);

    // Verify Batch Card & Action Button
    expect(find.text('Batch Panen K-04 Margomulyo'), findsOneWidget);
    expect(find.text('Unduh Rekap Laporan (CSV / PDF)'), findsOneWidget);

    // Switch to Bulan Ini tab
    await tester.tap(find.text('Bulan Ini'));
    await tester.pumpAndSettle();

    expect(find.text('Total Panen Bulan Ini'), findsOneWidget);
    expect(find.text('Penghasilan Bulan Ini'), findsOneWidget);
    expect(find.text('Akumulasi Bulan Ini'), findsOneWidget);
  });
}
