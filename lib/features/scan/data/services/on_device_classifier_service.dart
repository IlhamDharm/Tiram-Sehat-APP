import 'dart:convert';
import 'package:flutter/services.dart';
import '../../domain/models/scan_result.dart';

class PredictionResult {
  final String label;
  final double confidence;

  const PredictionResult({required this.label, required this.confidence});
}

class OnDeviceClassifierService {
  static List<dynamic>? _cachedDiseases;
  static List<String>? _cachedLabels;

  /// Inisialisasi dan cache data penyakit offline dari assets.
  static Future<void> init() async {
    if (_cachedDiseases != null && _cachedLabels != null) return;

    try {
      final labelsString =
          await rootBundle.loadString('assets/models/labels.json');
      _cachedLabels = List<String>.from(jsonDecode(labelsString) as List);
    } catch (_) {
      _cachedLabels = [
        'Healthy',
        'Mixed_Infected',
        'Single_Infected',
      ];
    }

    try {
      final diseasesString =
          await rootBundle.loadString('assets/models/diseases.json');
      _cachedDiseases = jsonDecode(diseasesString) as List<dynamic>;
    } catch (_) {
      _cachedDiseases = [];
    }
  }

  /// Menjalankan klasifikasi on-device dari bytes foto kamera.
  static Future<ScanResult> classify({
    required Uint8List? imageBytes,
    required String rack,
    required int column,
  }) async {
    await init();

    // 1. Eksekusi inferensi
    final prediction = await _runInference(imageBytes);

    // 2. Cari data penyakit & SOP penanganan dari database offline lokal
    final diseaseData = _findDisease(prediction.label);

    // 3. Konversi severity
    final severityStr = (diseaseData?['severity'] as String?) ?? 'treatable';
    final ScanSeverity severity = severityStr == 'healthy'
        ? ScanSeverity.healthy
        : severityStr == 'must_discard'
            ? ScanSeverity.mustDiscard
            : ScanSeverity.treatable;

    // 4. Bangun list langkah penanganan (SOP)
    final rawSteps = (diseaseData?['steps'] as List<dynamic>?) ?? [];
    final steps = rawSteps.map((s) {
      return ScanStep(
        title: s['title'] as String? ?? '',
        description: s['description'] as String? ?? '',
      );
    }).toList();

    // 5. Waktu scan
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final scannedAtStr = 'Hari ini, $hour:$minute';

    final scanId = 'scan_${now.millisecondsSinceEpoch}';

    return ScanResult(
      id: scanId,
      diagnosisName: diseaseData?['name'] as String? ?? prediction.label,
      scientificName: diseaseData?['scientific_name'] as String? ?? '',
      confidence: prediction.confidence,
      infectionLocation:
          diseaseData?['location_hint'] as String? ?? 'Permukaan Baglog',
      severity: severity,
      steps: steps.isNotEmpty
          ? steps
          : [
              const ScanStep(
                title: 'Periksa Kondisi Baglog',
                description:
                    'Amati perkembangan miselium dan isolasi baglog jika menunjukkan tanda penyebaran spora.',
              ),
            ],
      rack: rack.startsWith('Rak') ? rack : 'Rak Kumbung ${rack.toUpperCase()}',
      column: column,
      scannedAt: scannedAtStr,
    );
  }

  static Future<PredictionResult> _runInference(Uint8List? bytes) async {
    // Simulasi sementara sampai tflite_flutter + model on-device dipasang.
    // Hasil di bawah BUKAN inferensi model dan tidak boleh dipakai untuk
    // klaim akurasi medis/produksi.
    await Future.delayed(const Duration(milliseconds: 350));

    if (bytes == null || bytes.isEmpty) {
      return const PredictionResult(label: 'Single_Infected', confidence: 0.942);
    }

    // Heuristik variasi berbasis checksum sederhana bytes foto.
    final sum = bytes.take(100).fold<int>(0, (prev, elem) => prev + elem);
    final labels = _cachedLabels ??
        ['Healthy', 'Mixed_Infected', 'Single_Infected'];
    final selectedIdx = sum % labels.length;
    final confidence = 0.88 + ((sum % 11) / 100.0);

    return PredictionResult(
      label: labels[selectedIdx],
      confidence: double.parse(confidence.toStringAsFixed(3)),
    );
  }

  static Map<String, dynamic>? _findDisease(String mlLabel) {
    if (_cachedDiseases == null) return null;
    for (final item in _cachedDiseases!) {
      if (item is Map<String, dynamic> && item['ml_label'] == mlLabel) {
        return item;
      }
    }
    return null;
  }
}

