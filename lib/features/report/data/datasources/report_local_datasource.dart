import '../../../../mock/mock_data.dart';
import '../../domain/models/report_data.dart';

/// Sumber data sementara untuk laporan sampai endpoint `/reports` terhubung
/// penuh. UI hanya mengenal [ReportData] dan [BaglogCycle].
class ReportLocalDataSource {
  ReportData getReport() => MockData.report;

  BaglogCycle getCycle() => const BaglogCycle(
        cycleNo: 4,
        total: 2450,
        healthy: 2210,
        treatable: 165,
        discarded: 75,
        healthRatio: 0.902,
      );
}
