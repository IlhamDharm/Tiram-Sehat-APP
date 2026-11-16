import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/scan_api_service.dart';
import '../../../scan/domain/models/scan_result.dart';
import '../../data/datasources/history_local_datasource.dart';
import '../../data/repositories/history_repository.dart';
import '../../domain/models/history_item.dart';

final historyLocalDataSourceProvider = Provider<HistoryLocalDataSource>((ref) {
  return HistoryLocalDataSource();
});

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepository(ref.watch(historyLocalDataSourceProvider));
});

final historyControllerProvider =
    StateNotifierProvider<HistoryController, List<HistoryItem>>((ref) {
  return HistoryController(ref.watch(historyRepositoryProvider));
});

/// Menyimpan daftar riwayat di satu tempat agar hasil scan dari fitur Scan
/// langsung muncul di tab Riwayat tanpa saling mengimpor state widget.
class HistoryController extends StateNotifier<List<HistoryItem>> {
  HistoryController(this._repository) : super(_repository.getHistory());

  final HistoryRepository _repository;

  void refresh() => state = _repository.getHistory();

  /// Menarik riwayat terbaru dari backend (Neon) lalu menggabungkannya dengan
  /// data lokal. Dipakai pull-to-refresh; gagal koneksi bukan error fatal.
  Future<void> refreshFromRemote() async {
    try {
      final remote = await ScanApiService.instance.fetchScanHistory();
      if (remote.isEmpty) return;

      final remoteIds = remote.map((item) => item.id).toSet();
      final localOnly = state.where((item) => !remoteIds.contains(item.id));
      state = [...remote, ...localOnly];
    } catch (_) {
      // Fallback ke data lokal bila backend belum berjalan / offline.
    }
  }

  void addFromScan(ScanResult result) {
    if (state.any((item) => item.id == result.id)) return;

    final isHealthy = result.severity == ScanSeverity.healthy;
    final mustDiscard = result.severity == ScanSeverity.mustDiscard;

    final item = HistoryItem(
      id: result.id,
      name: result.scientificName.isEmpty
          ? result.diagnosisName
          : '${result.diagnosisName} (${result.scientificName})',
      badge: isHealthy
          ? 'Sehat'
          : mustDiscard
              ? 'Harus Dibuang'
              : 'Bisa Diobati',
      tone: isHealthy ? 'success' : mustDiscard ? 'danger' : 'warning',
      when: result.scannedAt,
      rack: result.rack,
      col: result.column,
      category: isHealthy
          ? HistorySectionCategory.recovered
          : HistorySectionCategory.actionRequired,
      imageUrl: result.imageUrl,
    );

    state = [item, ...state];
  }

  /// Menandai tindakan lanjut selesai. Temuan yang harus dibuang berpindah ke
  /// arsip; temuan yang bisa diobati berpindah ke bagian pulih.
  void markHandled(HistoryItem item) {
    final shouldArchive = item.badge == 'Harus Dibuang';

    state = [
      for (final current in state)
        if (current.id == item.id)
          HistoryItem(
            id: current.id,
            name: current.name,
            badge: shouldArchive ? 'Telah Dibuang' : 'Selesai Diobati',
            tone: shouldArchive ? 'danger' : 'success',
            when: current.when,
            rack: current.rack,
            col: current.col,
            category: shouldArchive
                ? HistorySectionCategory.archived
                : HistorySectionCategory.recovered,
            status: shouldArchive
                ? 'Status: Baglog telah dimusnahkan'
                : 'Status: Selesai diobati',
            tag: current.tag,
            note: current.note,
            isInitiallyExpanded: true,
            imageUrl: current.imageUrl,
          )
        else
          current,
    ];
  }

  void markAsRecovered(String id) {
    HistoryItem? target;
    for (final item in state) {
      if (item.id == id) {
        target = item;
        break;
      }
    }
    if (target != null) markHandled(target);
  }

  /// Menghapus entri dari daftar; entri dari backend ikut dihapus di server.
  Future<void> remove(String id) async {
    state = state.where((item) => item.id != id).toList();

    if (id.startsWith('neon-')) {
      final numericId = int.tryParse(id.replaceFirst('neon-', ''));
      if (numericId != null) {
        await ScanApiService.instance.deleteScan(numericId);
      }
    }
  }
}
