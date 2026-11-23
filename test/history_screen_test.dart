import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tiram_sehat/features/history/history_detail_screen.dart';
import 'package:tiram_sehat/features/history/history_screen.dart';
import 'package:tiram_sehat/features/history/manual_inspection_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('HistoryScreen renders title, search, filter chips, and cards without inline dropdown',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: HistoryScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    // Pastikan judul dan subtitle tampil
    expect(find.text('Riwayat Deteksi Baglog'), findsOneWidget);
    expect(
      find.text('Arsip inspeksi kamera & diagnosis on-device'),
      findsOneWidget,
    );

    // Pastikan filter chip tampil
    expect(find.textContaining('Semua Temuan'), findsOneWidget);
    expect(find.textContaining('Perlu Tindakan'), findsOneWidget);
    expect(find.text('Harus Dibuang (2)'), findsOneWidget);

    // Pastikan kartu pertama tampil
    expect(find.text('Green Mold (Trichoderma sp.)'), findsOneWidget);

    // Pastikan tombol aksi dropdown tidak lagi tampil inline di halaman daftar
    expect(find.text('Konfirmasi Buang Baglog'), findsNothing);
    expect(find.text('Konfirmasi Selesai Diobati'), findsNothing);
  });

  testWidgets('Tapping a history card navigates to HistoryDetailScreen and updates status',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: HistoryScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    // Ketuk kartu Black Bread Mold (Rhizopus) untuk pindah ke halaman detail
    await tester.tap(find.text('Black Bread Mold (Rhizopus)'));
    await tester.pumpAndSettle();

    expect(find.byType(HistoryDetailScreen), findsOneWidget);
    expect(find.text('Detail Riwayat Baglog'), findsOneWidget);
    expect(find.text('Konfirmasi Buang Baglog'), findsOneWidget);

    // Tekan tombol konfirmasi di halaman detail
    await tester.ensureVisible(find.text('Konfirmasi Buang Baglog'));
    await tester.tap(find.text('Konfirmasi Buang Baglog'));
    await tester.pumpAndSettle();

    expect(find.text('Status: Baglog telah dimusnahkan'), findsOneWidget);
  });

  testWidgets('Tapping Inspeksi Manual Baglog opens ManualInspectionScreen and saves entry',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: HistoryScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    // Scroll ke kartu Inspeksi Manual Baglog di bawah
    final manualCard = find.text('Inspeksi Manual Baglog');
    await tester.ensureVisible(manualCard);
    await tester.tap(manualCard);
    await tester.pumpAndSettle();

    expect(find.byType(ManualInspectionScreen), findsOneWidget);
    expect(find.text('Lokasi Baglog'), findsOneWidget);

    // Pilih chip cepat Rak A-01
    await tester.tap(find.text('Rak A-01'));
    await tester.pump();

    // Pilih kondisi Cobweb Mold
    await tester.tap(find.text('Cobweb Mold'));
    await tester.pump();

    // Scroll ke tombol simpan dan simpan
    final saveBtn = find.text('Simpan Inspeksi Manual');
    await tester.ensureVisible(saveBtn);
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    // Kembali ke HistoryScreen dan pastikan item baru muncul
    expect(find.byType(HistoryScreen), findsOneWidget);
    expect(find.text('Cobweb Mold (Dactylium dendroides)'), findsOneWidget);
  });
}
