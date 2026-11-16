import '../datasources/report_local_datasource.dart';
import '../../domain/models/report_data.dart';

class ReportRepository {
  final ReportLocalDataSource _local;

  ReportRepository(this._local);

  ReportData getReport() => _local.getReport();

  BaglogCycle getCycle() => _local.getCycle();
}
