import '../datasources/history_local_datasource.dart';
import '../../domain/models/history_item.dart';

class HistoryRepository {
  final HistoryLocalDataSource _local;

  HistoryRepository(this._local);

  List<HistoryItem> getHistory() => _local.getItems();
}
