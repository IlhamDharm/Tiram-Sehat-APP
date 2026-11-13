import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tiram_sehat/core/theme/app_theme.dart';
import 'package:tiram_sehat/features/harvest/harvest_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('HarvestScreen beralih tab dan menampilkan Riwayat & Kas',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: HarvestScreen()),
      ),
    );

    // Tab default: Catat Panen
    expect(find.text('Catat Panen'), findsOneWidget);
    expect(find.text('Riwayat & Kas'), findsOneWidget);
    expect(find.text('Simpan Data Panen'), findsOneWidget);

    // Pindah ke tab Riwayat & Kas
    await tester.tap(find.text('Riwayat & Kas'));
    await tester.pumpAndSettle();

    expect(find.text('TOTAL PANEN'), findsOneWidget);
    expect(find.text('TOTAL PENJUALAN'), findsOneWidget);
    expect(find.text('Catatan Riwayat Petik & Kas'), findsOneWidget);

    // Kembali ke Catat Panen
    await tester.tap(find.text('Catat Panen'));
    await tester.pumpAndSettle();
    expect(find.text('Simpan Data Panen'), findsOneWidget);

    // Simpan data dan pastikan berpindah ke Riwayat & Kas
    await tester.tap(find.text('Simpan Data Panen'));
    await tester.pumpAndSettle();

    expect(find.text('Catatan Riwayat Petik & Kas'), findsOneWidget);
  });
}
