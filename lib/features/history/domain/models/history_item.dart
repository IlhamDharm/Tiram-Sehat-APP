import '../../../scan/domain/models/scan_result.dart';

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
  final String? diagnosisName;
  final String? scientificName;
  final double? confidenceScore;
  final String? infectionLocation;
  final List<ScanStep> steps;
  final DateTime? createdAt;
  final bool isManual;

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
    this.diagnosisName,
    this.scientificName,
    this.confidenceScore,
    this.infectionLocation,
    this.steps = const [],
    this.createdAt,
    this.isManual = false,
  });

  String get rackLocation => '$rack • Kolom $col';

  HistoryItem copyWith({
    String? id,
    String? name,
    String? badge,
    String? tone,
    String? when,
    String? rack,
    int? col,
    HistorySectionCategory? category,
    String? status,
    bool clearStatus = false,
    String? tag,
    bool clearTag = false,
    String? note,
    bool clearNote = false,
    String? actionLabel,
    bool clearActionLabel = false,
    bool? isInitiallyExpanded,
    String? imageUrl,
    String? diagnosisName,
    String? scientificName,
    double? confidenceScore,
    String? infectionLocation,
    List<ScanStep>? steps,
    DateTime? createdAt,
    bool? isManual,
  }) {
    return HistoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      badge: badge ?? this.badge,
      tone: tone ?? this.tone,
      when: when ?? this.when,
      rack: rack ?? this.rack,
      col: col ?? this.col,
      category: category ?? this.category,
      status: clearStatus ? null : (status ?? this.status),
      tag: clearTag ? null : (tag ?? this.tag),
      note: clearNote ? null : (note ?? this.note),
      actionLabel:
          clearActionLabel ? null : (actionLabel ?? this.actionLabel),
      isInitiallyExpanded: isInitiallyExpanded ?? this.isInitiallyExpanded,
      imageUrl: imageUrl ?? this.imageUrl,
      diagnosisName: diagnosisName ?? this.diagnosisName,
      scientificName: scientificName ?? this.scientificName,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      infectionLocation: infectionLocation ?? this.infectionLocation,
      steps: steps ?? this.steps,
      createdAt: createdAt ?? this.createdAt,
      isManual: isManual ?? this.isManual,
    );
  }
}
