import 'package:flutter_test/flutter_test.dart';
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
    steps: const [],
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
    });
  });
}
