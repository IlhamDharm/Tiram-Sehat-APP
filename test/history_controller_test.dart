import 'package:flutter_test/flutter_test.dart';
import 'package:tiram_sehat/core/services/scan_api_service.dart';
import 'package:tiram_sehat/features/history/data/datasources/history_local_datasource.dart';
import 'package:tiram_sehat/features/history/data/repositories/history_repository.dart';
import 'package:tiram_sehat/features/history/domain/models/history_item.dart';
import 'package:tiram_sehat/features/history/presentation/providers/history_provider.dart';
import 'package:tiram_sehat/features/scan/domain/models/scan_result.dart';

ScanResult _scanResult(String id, ScanSeverity severity) {
  return ScanResult(
    id: id,
    diagnosisName: 'Green Mold',
    scientificName: 'Trichoderma sp.',
    confidence: 0.9,
    infectionLocation: 'Leher baglog',
    severity: severity,
    steps: const [
      ScanStep(
        title: 'Pindahkan ke Rak Karantina',
        description: 'Pisahkan dari rak utama.',
      ),
    ],
    rack: 'Rak Kumbung B-04',
    column: 3,
    scannedAt: 'Hari ini, 09:15',
  );
}

void main() {
  group('HistoryController', () {
    late HistoryController controller;

    setUp(() {
      controller = HistoryController(
        HistoryRepository(HistoryLocalDataSource()),
      );
    });

    tearDown(() => controller.dispose());

    test('hasil scan langsung masuk riwayat dan tidak duplikat', () {
      final before = controller.state.length;
      final result = _scanResult('scan-test-1', ScanSeverity.treatable);

      controller.addFromScan(result);
      expect(controller.state.length, before + 1);
      expect(controller.state.first.id, 'scan-test-1');
      expect(controller.state.first.badge, 'Bisa Diobati');
      expect(controller.state.first.diagnosisName, 'Green Mold');
      expect(controller.state.first.confidenceScore, 90.0);
      expect(controller.state.first.steps.length, 1);

      controller.addFromScan(result);
      expect(controller.state.length, before + 1);
    });

    test('scan sehat dipetakan ke kategori pulih', () {
      controller.addFromScan(_scanResult('scan-test-2', ScanSeverity.healthy));

      expect(controller.state.first.category, HistorySectionCategory.recovered);
      expect(controller.state.first.tone, 'success');
    });

    test('tindakan lanjut memindahkan item ke pulih', () {
      controller.addFromScan(_scanResult('scan-test-3', ScanSeverity.treatable));
      final item = controller.state.first;

      controller.markHandled(item);

      expect(controller.state.first.category, HistorySectionCategory.recovered);
      expect(controller.state.first.actionLabel, isNull);
      expect(controller.state.first.diagnosisName, 'Green Mold');
    });

    test('addManualInspection menambahkan catatan inspeksi manual', () {
      final before = controller.state.length;
      const manualItem = HistoryItem(
        id: 'manual-1',
        name: 'Yellow Mold (Mycelium spp.)',
        badge: 'Bisa Diobati',
        tone: 'warning',
        when: 'Hari ini, 10:00 WIB',
        rack: 'Rak Kumbung A-01',
        col: 2,
        category: HistorySectionCategory.actionRequired,
        isManual: true,
        diagnosisName: 'Yellow Mold',
        scientificName: 'Mycelium spp.',
      );

      controller.addManualInspection(manualItem);
      expect(controller.state.length, before + 1);
      expect(controller.state.first.id, 'manual-1');
      expect(controller.state.first.isManual, isTrue);
    });
  });

  group('ScanApiService.mapJsonToHistoryItem', () {
    test('memetakan payload JSON /api/v1/scans dengan lengkap', () {
      final item = ScanApiService.instance.mapJsonToHistoryItem({
        'id': '550e8400-e29b-41d4-a716-446655440000',
        'image_url':
            'https://res.cloudinary.com/jvwoxfkj/image/upload/v1794189745/img_jamur/iobjnahr4qhqhs9xprgc.jpg',
        'diagnosis_name': 'Green Mold',
        'scientific_name': 'Trichoderma sp.',
        'confidence': 0.942,
        'infection_location': 'Cincin & Leher Baglog',
        'severity': 'treatable',
        'scan_method': 'camera',
        'rak_code': 'B-04',
        'column_no': 3,
        'status': 'action_required',
        'status_note': 'Ditemukan di leher baglog.',
        'status_tag': 'Scan Kamera',
        'steps': [
          {
            'step_order': 1,
            'title': 'Pindahkan ke Rak Karantina',
            'description': 'Segera pisahkan baglog dari rak utama kumbung.',
          },
          {
            'step_order': 2,
            'title': 'Kerik Lembut Spora Hijau',
            'description': 'Gunakan sendok makan bersih steril alkohol 70%.',
          },
        ],
        'scanned_at': '2026-11-09T09:02:26.549461+07:00',
      });

      expect(item.id, '550e8400-e29b-41d4-a716-446655440000');
      expect(item.name, 'Green Mold (Trichoderma sp.)');
      expect(item.diagnosisName, 'Green Mold');
      expect(item.scientificName, 'Trichoderma sp.');
      expect(item.confidenceScore, closeTo(94.2, 0.01));
      expect(item.infectionLocation, 'Cincin & Leher Baglog');
      expect(item.rack, 'Rak Kumbung B-04');
      expect(item.col, 3);
      expect(item.badge, 'Bisa Diobati');
      expect(item.category, HistorySectionCategory.actionRequired);
      expect(item.note, 'Ditemukan di leher baglog.');
      expect(item.steps.length, 2);
      expect(item.steps.first.title, 'Pindahkan ke Rak Karantina');
      expect(item.imageUrl, contains('cloudinary.com'));
      expect(item.isManual, isFalse);
      expect(item.createdAt, isNotNull);
    });

    test('memetakan inspeksi manual dan status recovered dari /api/v1/scans', () {
      final item = ScanApiService.instance.mapJsonToHistoryItem({
        'id': '660e8400-e29b-41d4-a716-446655440001',
        'diagnosis_name': 'Cobweb Mold',
        'scientific_name': 'Dactylium dendroides',
        'severity': 'treatable',
        'scan_method': 'manual',
        'rak_code': 'A-01',
        'column_no': 2,
        'status': 'recovered',
        'status_note': 'Sudah sembuh setelah semprot sirih.',
        'scanned_at': '2026-11-10T08:30:00+07:00',
      });

      expect(item.isManual, isTrue);
      expect(item.badge, 'Selesai Diobati');
      expect(item.category, HistorySectionCategory.recovered);
      expect(item.rack, 'Rak Kumbung A-01');
      expect(item.confidenceScore, isNull);
    });
  });
}
