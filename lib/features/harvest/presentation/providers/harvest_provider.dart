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

final harvestControllerProvider =
    StateNotifierProvider<HarvestController, List<HarvestEntry>>((ref) {
  return HarvestController(ref.watch(harvestRepositoryProvider));
});

class HarvestController extends StateNotifier<List<HarvestEntry>> {
  HarvestController(this._repository) : super(_repository.getHistory());

  final HarvestRepository _repository;

  void refresh() => state = _repository.getHistory();

  void add(HarvestEntry entry) {
    state = [entry, ...state];
  }
}
