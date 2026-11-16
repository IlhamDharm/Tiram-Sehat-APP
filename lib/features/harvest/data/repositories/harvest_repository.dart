import '../datasources/harvest_local_datasource.dart';
import '../../domain/models/harvest_entry.dart';

class HarvestRepository {
  final HarvestLocalDataSource _local;

  HarvestRepository(this._local);

  List<HarvestEntry> getHistory() => _local.getHistory();
}
