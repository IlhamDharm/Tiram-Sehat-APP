import '../../../../mock/mock_data.dart';
import '../../domain/models/harvest_entry.dart';

/// Data panen lokal (seed prototipe). Nanti bisa diganti implementasi SQLite
/// tanpa mengubah UI karena UI hanya bergantung pada repository.
class HarvestLocalDataSource {
  List<HarvestEntry> getHistory() => List<HarvestEntry>.from(MockData.harvestHistory);
}
