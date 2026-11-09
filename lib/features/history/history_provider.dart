import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/scan_api_service.dart';
import '../../mock/mock_data.dart';

class HistoryListNotifier extends StateNotifier<List<HistoryItem>> {
  HistoryListNotifier() : super(MockData.historyList) {
    fetchNeonHistory();
  }

  /// Mengambil data histori terbaru dari Neon DB di awan
  Future<void> fetchNeonHistory() async {
    try {
      final remoteList = await ScanApiService.instance.fetchScanHistory();
      if (remoteList.isNotEmpty) {
        // Gabungkan data dari Neon DB di paling atas
        final existingIds = remoteList.map((e) => e.id).toSet();
        final localOnly = state.where((item) => !existingIds.contains(item.id)).toList();
        state = [...remoteList, ...localOnly];
      }
    } catch (_) {
      // Fallback ke data lokal jika backend belum berjalan
    }
  }

  /// Menambahkan hasil scan baru dari kamera / Cloudinary ke state
  void addScanResult(ScanResult result) {
    final newItem = ScanApiService.instance.mapJsonToHistoryItem({
      'id': result.id.replaceAll('neon-', ''),
      'diagnosis_name': result.diagnosisName,
      'scientific_name': result.scientificName,
      'confidence_score': (result.confidence <= 1.0 ? result.confidence * 100 : result.confidence),
      'infection_location': result.infectionLocation,
      'severity': result.severity == ScanSeverity.mustDiscard ? 'must_discard' : 'treatable',
      'rack': result.rack,
      'column_no': result.column,
      'notes': 'Gambar tersimpan di Cloudinary.',
      'created_at': DateTime.now().toIso8601String(),
      'image_url': result.imageUrl,
    });

    state = [newItem, ...state];
  }

  /// Menandai item sebagai telah pulih / selesai diobati
  void markAsRecovered(String id) {
    state = state.map((item) {
      if (item.id == id) {
        return HistoryItem(
          id: item.id,
          name: item.name,
          badge: 'Selesai Diobati',
          tone: 'success',
          when: 'Baru Saja',
          rack: item.rack,
          col: item.col,
          category: HistorySectionCategory.recovered,
          status: 'Miselium Kembali Merambat Aktif',
          tag: 'Karantina Tuntas',
          note: item.note,
          actionLabel: 'Arsipkan Temuan',
          isInitiallyExpanded: true,
          imageUrl: item.imageUrl,
        );
      }
      return item;
    }).toList();
  }

  /// Menghapus item dari daftar dan dari Neon DB jika ada ID numerik
  Future<void> removeItem(String id) async {
    state = state.where((item) => item.id != id).toList();

    if (id.startsWith('neon-')) {
      final numId = int.tryParse(id.replaceFirst('neon-', ''));
      if (numId != null) {
        await ScanApiService.instance.deleteScan(numId);
      }
    }
  }
}

final historyListProvider = StateNotifierProvider<HistoryListNotifier, List<HistoryItem>>((ref) {
  return HistoryListNotifier();
});
