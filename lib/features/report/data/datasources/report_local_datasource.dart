import '../../../../mock/mock_data.dart';
import '../../domain/models/report_data.dart';

/// Sumber data sementara untuk laporan sampai endpoint `/reports` terhubung
/// penuh ke provider. UI hanya mengenal [ReportData].
class ReportLocalDataSource {
  ReportData getReport() => MockData.report;
}
