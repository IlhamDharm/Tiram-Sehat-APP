import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiram_sehat/core/components/app_bottom_sheet.dart';
import 'package:tiram_sehat/features/scan/domain/models/scan_result.dart';
import 'package:tiram_sehat/features/scan/widgets/app_camera_preview.dart';
import 'package:tiram_sehat/features/scan/widgets/scan_result_sheet.dart';
import 'package:tiram_sehat/features/scan/widgets/scan_reticle.dart';
import 'package:tiram_sehat/features/scan/widgets/scan_viewfinder_screen.dart';

void main() {
  const sample = ScanResult(
    id: 'scan-1',
    diagnosisName: 'Green Mold',
    scientificName: 'Trichoderma sp.',
    description: 'Kontaminasi jamur hijau (Trichoderma sp.) pada baglog.',
    confidence: 0.83,
    probabilities: {
      'greenmold': 0.83,
      'blackmold': 0.12,
      'healthy': 0.05,
    },
    mlLabel: 'greenmold',
    modelVersion: 'mobilenetv2-end2end-v7',
    infectionLocation: 'Cincin & Leher Baglog',
    severity: ScanSeverity.treatable,
    steps: [
      ScanStep(
        title: 'Pindahkan ke Rak Karantina',
        description: 'Pisahkan baglog dari rak utama.',
      ),
    ],
    rack: 'Rak Kumbung',
    column: 0,
    scannedAt: 'Hari ini, 09:00',
  );

  testWidgets(
      'ScanResultSheetContent menampilkan detail prediksi model, probabilitas, dan deskripsi',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScanResultSheetContent(
            result: sample,
            onSaveToHistory: (_, _) {},
            onScanAgain: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Green Mold'), findsAtLeastNWidgets(2));
    expect(find.text('(Trichoderma sp.)'), findsOneWidget);
    expect(
      find.text('Kontaminasi jamur hijau (Trichoderma sp.) pada baglog.'),
      findsOneWidget,
    );
    expect(find.text('Cukup Yakin'), findsOneWidget);
    expect(find.text('Distribusi Probabilitas Kelas'), findsOneWidget);
    expect(find.text('Healthy (Baglog Sehat)'), findsOneWidget);
    expect(find.text('Black Mold'), findsOneWidget);
    expect(find.text('Model: mobilenetv2-end2end-v7'), findsOneWidget);

    expect(find.text('Foto & Keputusan Lapangan'), findsOneWidget);
    expect(find.text('Risiko Penularan'), findsOneWidget);
    expect(find.text('Batas Obati vs Buang'), findsOneWidget);
    expect(find.text('Alat & Bahan'), findsOneWidget);
    expect(find.text('Jadwal Cek Ulang'), findsOneWidget);

    expect(find.text('Perbandingan Visual Lapangan'), findsNothing);
    expect(find.text('Target Normal'), findsNothing);
    expect(find.text('Spora Hijau'), findsNothing);
    expect(find.text('Diameter 1,8 cm aktif'), findsNothing);
  });

  testWidgets('AppBottomSheet bersama ScanResultSheetContent bisa di-slide down',
      (tester) async {
    BottomSheetSnap? latestSnap;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              const SizedBox.expand(),
              AppBottomSheet(
                onSnapChange: (snap) => latestSnap = snap,
                builder: (context, snap, scrollController) =>
                    ScanResultSheetContent(
                  result: sample,
                  scrollController: scrollController,
                  onSaveToHistory: (_, _) {},
                  onScanAgain: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('⌃ TARIK KE ATAS · ⌄ GESER KE BAWAH'),
      findsOneWidget,
    );

    // Geser handle ke bawah untuk mengecilkan sheet (slide down)
    await tester.fling(
      find.text('⌃ TARIK KE ATAS · ⌄ GESER KE BAWAH'),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    expect(latestSnap, BottomSheetSnap.collapsed);
    expect(find.text('⌃ TARIK KE ATAS UNTUK HASIL SCAN'), findsOneWidget);
  });

  testWidgets(
      'ScanViewfinderScreen menyembunyikan reticle saat kamera tidak tersedia agar card upload tidak tertutup',
      (tester) async {
    var galleryTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScanViewfinderScreen(
            onBack: () {},
            onShutter: () {},
            onGallery: () {},
            flashOn: false,
            onToggleFlash: () {},
            onToggleMacro: () {},
            showReticle: false,
            cameraPreview: AppCameraPreview(
              isInitialized: false,
              isLoading: false,
              errorMessage: 'Kamera tidak dapat diakses',
              onRetry: () {},
              onPickGallery: () => galleryTapped = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ScanReticle), findsNothing);
    expect(find.text('Posisikan Cincin / Mulut Baglog'), findsNothing);
    expect(find.text('Kamera Tidak Tersedia'), findsOneWidget);

    // Pastikan tombol Galeri di dalam card Kamera Tidak Tersedia bisa diketuk langsung
    await tester.tap(find.widgetWithText(ElevatedButton, 'Galeri'));
    await tester.pumpAndSettle();
    expect(galleryTapped, isTrue);
  });
}
