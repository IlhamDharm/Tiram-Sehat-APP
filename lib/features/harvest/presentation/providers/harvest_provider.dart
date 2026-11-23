import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_providers.dart';
import '../../data/datasources/harvest_local_datasource.dart';
import '../../data/datasources/harvest_remote_datasource.dart';
import '../../data/repositories/harvest_repository.dart';
import '../../domain/models/harvest_entry.dart';

final harvestLocalDataSourceProvider = Provider<HarvestLocalDataSource>((ref) {
  return HarvestLocalDataSource();
});

final harvestRemoteDataSourceProvider =
    Provider<HarvestRemoteDataSource>((ref) {
  return HarvestRemoteDataSource(ref.watch(apiClientProvider));
});

final harvestRepositoryProvider = Provider<HarvestRepository>((ref) {
  return HarvestRepository(
    ref.watch(harvestLocalDataSourceProvider),
    ref.watch(harvestRemoteDataSourceProvider),
  );
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
  HarvestController(this._repository) : super(_repository.getHistory()) {
    fetchRemote();
  }

  final HarvestRepository _repository;

  Future<void> fetchRemote() async {
    final remoteList = await _repository.fetchRemoteHistory();
    if (remoteList != null && remoteList.isNotEmpty) {
      state = remoteList..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    }
  }

  void refresh() => state = _repository.getHistory();

  Future<void> add(HarvestEntry entry) async {
    state = [entry, ...state]
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    await _repository.createHarvest(entry);
  }

  void addHarvest(HarvestEntry entry) => add(entry);

  void remove(String id) {
    state = state.where((entry) => entry.id != id).toList();
  }

  void removeHarvest(String id) => remove(id);
}
