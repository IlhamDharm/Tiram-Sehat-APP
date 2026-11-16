/// Kategori tampilan pada layar Riwayat Deteksi.
enum HistorySectionCategory { actionRequired, recovered, archived }

/// Model domain satu entri riwayat diagnosa baglog.
class HistoryItem {
  final String id;
  final String name;
  final String badge;
  final String tone; // 'warning', 'danger', 'success', 'neutral'
  final String when;
  final String rack;
  final int col;
  final HistorySectionCategory category;
  final String? status;
  final String? tag;
  final String? note;
  final String? actionLabel;
  final bool isInitiallyExpanded;
  final String? imageUrl;

  const HistoryItem({
    required this.id,
    required this.name,
    required this.badge,
    required this.tone,
    required this.when,
    required this.rack,
    required this.col,
    required this.category,
    this.status,
    this.tag,
    this.note,
    this.actionLabel,
    this.isInitiallyExpanded = false,
    this.imageUrl,
  });

  String get rackLocation => '$rack • Kolom $col';
}
