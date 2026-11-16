import '../../domain/models/harvest_entry.dart';
import 'harvest_seed.dart';

/// Data panen lokal.
///
/// Saat ini memakai seed prototipe; ganti isi method ini dengan query SQLite
/// atau endpoint `/harvests` tanpa mengubah provider maupun widget.
class HarvestLocalDataSource {
  List<HarvestEntry> getHistory() => buildInitialHarvests();
}
