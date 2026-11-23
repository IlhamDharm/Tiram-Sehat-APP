import '../datasources/harvest_local_datasource.dart';
import '../datasources/harvest_remote_datasource.dart';
import '../../domain/models/harvest_entry.dart';

class HarvestRepository {
  final HarvestLocalDataSource _local;
  final HarvestRemoteDataSource? _remote;

  HarvestRepository(this._local, [this._remote]);

  List<HarvestEntry> getHistory() => _local.getHistory();

  Future<void> createHarvest(HarvestEntry entry) async {
    if (_remote == null) return;
    try {
      await _remote.createHarvest(entry);
    } catch (_) {
      // Offline fallback: data tetap ada di state lokal
    }
  }

  Future<List<HarvestEntry>?> fetchRemoteHistory() async {
    if (_remote == null) return null;
    try {
      return await _remote.fetchHarvests();
    } catch (_) {
      return null;
    }
  }
}
