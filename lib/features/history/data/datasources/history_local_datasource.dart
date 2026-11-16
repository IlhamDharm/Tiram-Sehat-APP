import '../../../../mock/mock_data.dart';
import '../../../scan/data/services/offline_sync_manager.dart';
import '../../domain/models/history_item.dart';

/// Sumber data lokal untuk layar riwayat.
///
/// Menggabungkan data contoh dengan antrean scan offline yang belum tersinkron,
/// sehingga hasil scan langsung terlihat di tab Riwayat tanpa menunggu backend.
class HistoryLocalDataSource {
  List<HistoryItem> getItems() {
    final items = List<HistoryItem>.from(MockData.historyList);
    final knownIds = items.map((item) => item.id).toSet();

    for (final record in OfflineSyncManager().records) {
      if (knownIds.contains(record.id)) continue;
      items.insert(0, _fromOfflineRecord(record));
      knownIds.add(record.id);
    }
    return items;
  }

  HistoryItem _fromOfflineRecord(OfflineScanRecord record) {
    final isHealthy = record.severity == 'healthy';
    final mustDiscard = record.severity == 'must_discard';

    return HistoryItem(
      id: record.id,
      name: record.scientificName.isEmpty
          ? record.diagnosisName
          : '${record.diagnosisName} (${record.scientificName})',
      badge: isHealthy
          ? 'Sehat'
          : mustDiscard
              ? 'Harus Dibuang'
              : 'Bisa Diobati',
      tone: isHealthy ? 'success' : mustDiscard ? 'danger' : 'warning',
      when: _formatDateTime(record.scannedAt),
      rack: record.rakCode.startsWith('Rak')
          ? record.rakCode
          : 'Rak Kumbung ${record.rakCode}',
      col: record.columnNo,
      category: isHealthy
          ? HistorySectionCategory.recovered
          : HistorySectionCategory.actionRequired,
      status: record.isSynced ? 'Tersinkron ke server' : 'Menunggu sinkronisasi',
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return 'Hari ini, $hour:$minute';
  }
}
