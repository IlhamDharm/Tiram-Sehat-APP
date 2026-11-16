import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/harvest_local_datasource.dart';
import '../../data/repositories/harvest_repository.dart';
import '../../domain/models/harvest_entry.dart';

final harvestLocalDataSourceProvider = Provider<HarvestLocalDataSource>((ref) {
  return HarvestLocalDataSource();
});

final harvestRepositoryProvider = Provider<HarvestRepository>((ref) {
  return HarvestRepository(ref.watch(harvestLocalDataSourceProvider));
});

/// Sumber tunggal state panen. Nama `harvestListProvider` disediakan agar
/// modul laporan (agregasi mingguan/bulanan) bisa ikut memakai state yang sama.
final harvestControllerProvider =
    StateNotifierProvider<HarvestController, List<HarvestEntry>>((ref) {
  return HarvestController(ref.watch(harvestRepositoryProvider));
});

final harvestListProvider = harvestControllerProvider;

final latestHarvestProvider = Provider<HarvestEntry>((ref) {
  final harvests = ref.watch(harvestControllerProvider);
  if (harvests.isNotEmpty) return harvests.first;
  return HarvestEntry(
    id: 'empty',
    dateTime: DateTime.now(),
    weightKg: 0,
    pricePerKg: 0,
  );
});

class HarvestController extends StateNotifier<List<HarvestEntry>> {
  HarvestController(this._repository) : super(_repository.getHistory());

  final HarvestRepository _repository;

  void refresh() => state = _repository.getHistory();

  void add(HarvestEntry entry) {
    state = [entry, ...state]
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  void addHarvest(HarvestEntry entry) => add(entry);

  void remove(String id) {
    state = state.where((entry) => entry.id != id).toList();
  }

  void removeHarvest(String id) => remove(id);
}
