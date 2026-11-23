import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_providers.dart';
import '../../../../core/services/scan_api_service.dart';
import '../../../scan/domain/models/scan_result.dart';
import '../../data/datasources/history_local_datasource.dart';
import '../../data/repositories/history_repository.dart';
import '../../domain/models/history_item.dart';

enum HistorySyncStatus { idle, loading, synced, unauthenticated, offline }

final historyLocalDataSourceProvider = Provider<HistoryLocalDataSource>((ref) {
  return HistoryLocalDataSource();
});

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepository(ref.watch(historyLocalDataSourceProvider));
});

final historySyncStatusProvider =
    StateProvider<HistorySyncStatus>((ref) => HistorySyncStatus.idle);

final historyControllerProvider =
    StateNotifierProvider<HistoryController, List<HistoryItem>>((ref) {
  return HistoryController(
    ref.watch(historyRepositoryProvider),
    api: ref.watch(apiClientProvider),
  );
});

/// Menyimpan daftar riwayat di satu tempat agar hasil scan dari fitur Scan
/// dan inspeksi manual langsung muncul di tab Riwayat.
class HistoryController extends StateNotifier<List<HistoryItem>> {
  HistoryController(this._repository, {this.api})
      : super(_repository.getHistory());

  final HistoryRepository _repository;
  final ApiClient? api;

  void refresh() => state = _repository.getHistory();

  bool _isLocalOnlyId(String id) =>
      id.startsWith('h-') ||
      id.startsWith('scan-') ||
      id.startsWith('manual-');

  /// Menarik riwayat terbaru dari backend (`/api/v1/scans`) lalu menggabungkannya
  /// dengan data lokal.
  Future<HistorySyncStatus> refreshFromRemote() async {
    if (api == null || !api!.hasToken) {
      return HistorySyncStatus.unauthenticated;
    }
    try {
      final remote = await ScanApiService.instance.fetchScanHistory(api: api);
      final remoteIds = remote.map((item) => item.id).toSet();
      final localOnly = state.where((item) => !remoteIds.contains(item.id));
      state = [...remote, ...localOnly];
      return HistorySyncStatus.synced;
    } catch (_) {
      // Fallback ke data lokal bila backend belum berjalan / offline.
      return HistorySyncStatus.offline;
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
      status: isHealthy
          ? 'Baglog dalam kondisi sehat produktif'
          : mustDiscard
              ? 'Status: Menunggu Pemusnahan'
              : 'Status: Menunggu Desinfeksi',
      tag: 'Scan Kamera',
      actionLabel: isHealthy
          ? null
          : mustDiscard
              ? 'Konfirmasi Buang Baglog'
              : 'Konfirmasi Selesai Diobati',
      imageUrl: result.imageUrl,
      diagnosisName: result.diagnosisName,
      scientificName:
          result.scientificName.isNotEmpty ? result.scientificName : null,
      confidenceScore: result.confidence <= 1.0
          ? result.confidence * 100.0
          : result.confidence,
      infectionLocation: result.infectionLocation,
      steps: result.steps,
      createdAt: DateTime.now(),
      isManual: false,
    );

    state = [item, ...state];
  }

  /// Menambahkan catatan inspeksi manual baglog ke bagian atas daftar riwayat.
  void addManualInspection(HistoryItem item) {
    if (state.any((existing) => existing.id == item.id)) return;
    state = [item, ...state];
  }

  /// Menandai tindakan lanjut selesai. Temuan yang harus dibuang berpindah ke
  /// arsip; temuan yang bisa diobati berpindah ke bagian pulih.
  void markHandled(HistoryItem item) {
    final shouldArchive = item.badge == 'Harus Dibuang';
    final isAlreadyRecovered = item.category == HistorySectionCategory.recovered;

    final String nextBadge;
    final String nextTone;
    final HistorySectionCategory nextCategory;
    final String nextStatus;
    final String remoteStatus;

    if (shouldArchive) {
      nextBadge = 'Telah Dibuang';
      nextTone = 'danger';
      nextCategory = HistorySectionCategory.archived;
      nextStatus = 'Status: Baglog telah dimusnahkan';
      remoteStatus = 'discarded';
    } else if (isAlreadyRecovered) {
      nextBadge = 'Tersanitasi';
      nextTone = 'success';
      nextCategory = HistorySectionCategory.archived;
      nextStatus = 'Status: Diarsipkan';
      remoteStatus = 'archived';
    } else {
      nextBadge = 'Selesai Diobati';
      nextTone = 'success';
      nextCategory = HistorySectionCategory.recovered;
      nextStatus = 'Status: Selesai diobati';
      remoteStatus = 'recovered';
    }

    state = [
      for (final current in state)
        if (current.id == item.id)
          current.copyWith(
            badge: nextBadge,
            tone: nextTone,
            category: nextCategory,
            status: nextStatus,
            clearActionLabel: true,
          )
        else
          current,
    ];

    if (!_isLocalOnlyId(item.id) && api != null && api!.hasToken) {
      ScanApiService.instance.updateScanStatus(
        item.id,
        status: remoteStatus,
        note: nextStatus,
        api: api,
      );
    }
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

    if (!_isLocalOnlyId(id) && api != null && api!.hasToken) {
      await ScanApiService.instance.deleteScan(id, api: api);
    }
  }
}
