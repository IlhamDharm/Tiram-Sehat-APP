import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/report_local_datasource.dart';
import '../../data/repositories/report_repository.dart';
import '../../domain/models/report_data.dart';

final reportLocalDataSourceProvider = Provider<ReportLocalDataSource>((ref) {
  return ReportLocalDataSource();
});

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository(ref.watch(reportLocalDataSourceProvider));
});

final reportProvider = Provider<ReportData>((ref) {
  return ref.watch(reportRepositoryProvider).getReport();
});
