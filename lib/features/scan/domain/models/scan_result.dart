/// Model domain hasil pemindaian baglog.
///
/// Model ini sengaja tidak bergantung pada layer data/UI agar bisa dipakai
/// oleh service on-device, antrean offline, maupun widget hasil scan.
enum ScanSeverity { treatable, mustDiscard, healthy }

class ScanStep {
  final String title;
  final String description;

  const ScanStep({required this.title, required this.description});
}

class ScanResult {
  final String id;
  final String diagnosisName;
  final String scientificName;
  final double confidence;
  final String infectionLocation;
  final ScanSeverity severity;
  final List<ScanStep> steps;
  final String rack;
  final int column;
  final String scannedAt;
  final String? imageUrl;
  final String? mlLabel;
  final String? modelVersion;
  final Map<String, double> probabilities;
  final String? description;

  const ScanResult({
    required this.id,
    required this.diagnosisName,
    required this.scientificName,
    required this.confidence,
    required this.infectionLocation,
    required this.severity,
    required this.steps,
    required this.rack,
    required this.column,
    required this.scannedAt,
    this.imageUrl,
    this.mlLabel,
    this.modelVersion,
    this.probabilities = const {},
    this.description,
  });

  ScanResult copyWith({
    String? rack,
    int? column,
    String? imageUrl,
    String? mlLabel,
    String? modelVersion,
    Map<String, double>? probabilities,
    String? description,
  }) {
    return ScanResult(
      id: id,
      diagnosisName: diagnosisName,
      scientificName: scientificName,
      confidence: confidence,
      infectionLocation: infectionLocation,
      severity: severity,
      steps: steps,
      rack: rack ?? this.rack,
      column: column ?? this.column,
      scannedAt: scannedAt,
      imageUrl: imageUrl ?? this.imageUrl,
      mlLabel: mlLabel ?? this.mlLabel,
      modelVersion: modelVersion ?? this.modelVersion,
      probabilities: probabilities ?? this.probabilities,
      description: description ?? this.description,
    );
  }
}
