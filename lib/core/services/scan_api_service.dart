import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../features/history/domain/models/history_item.dart';
import '../../features/scan/domain/models/scan_result.dart';
import '../network/api_client.dart';

/// Layanan API terpadu untuk integrasi Cloudinary & Neon DB melalui backend
/// `/api/v1/uploads` dan `/api/v1/scans`.
class ScanApiService {
  ScanApiService._();
  static final ScanApiService instance = ScanApiService._();

  static const String _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get defaultBaseUrl {
    if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;
    if (kIsWeb) return 'http://localhost:8000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  /// Mengunggah gambar baglog ke Cloudinary via `/api/v1/uploads/image`
  /// lalu menyimpan metadata scan ke Neon DB via `POST /api/v1/scans`.
  Future<ScanResult> uploadScan({
    required Uint8List bytes,
    ApiClient? api,
    String filename = 'scan.jpg',
    String rack = 'B-04',
    int column = 1,
    String? diagnosisName,
    String? scientificName,
    double? confidenceScore,
    String? infectionLocation,
    String? severity,
    String? notes,
    String? statusTag,
    String scanMethod = 'camera',
    List<ScanStep> steps = const [],
  }) async {
    if (api == null || !api.hasToken) {
      throw Exception('Sesi login belum aktif untuk upload ke server.');
    }

    // 1. Upload gambar ke Cloudinary lewat endpoint backend terautentikasi
    // Pastikan activeBaseUrl sudah teruji sebelum upload multipart.
    try {
      await api.get('/health');
    } catch (_) {
      // Tetap lanjut memakai activeBaseUrl / baseUrl bila /health tidak terjangkau.
    }
    final uploadUri = Uri.parse('${api.activeBaseUrl}/api/v1/uploads/image');
    final request = http.MultipartRequest('POST', uploadUri);
    request.headers['Authorization'] = 'Bearer ${api.accessToken}';
    request.fields['upload_type'] = 'scan';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    final streamed = await request.send().timeout(const Duration(seconds: 20));
    final uploadRes = await http.Response.fromStream(streamed);
    if (uploadRes.statusCode < 200 || uploadRes.statusCode >= 300) {
      throw Exception(
        'Gagal upload gambar (HTTP ${uploadRes.statusCode}): ${uploadRes.body}',
      );
    }

    final decodedUpload = jsonDecode(uploadRes.body) as Map<String, dynamic>;
    final media = decodedUpload['data'] as Map<String, dynamic>? ?? {};

    // 2. Simpan metadata scan ke `/api/v1/scans`
    final double? normalizedConfidence = confidenceScore == null
        ? null
        : (confidenceScore > 1.0 ? confidenceScore / 100.0 : confidenceScore)
            .clamp(0.0, 1.0);

    final body = <String, dynamic>{
      'rak_id': rack,
      'column_no': column,
      'diagnosis_name': diagnosisName,
      'scientific_name': scientificName,
      'confidence': normalizedConfidence,
      'severity': severity ?? 'treatable',
      'infection_location': infectionLocation,
      'scan_method': scanMethod == 'manual' ? 'manual' : 'camera',
      'scanned_at': DateTime.now().toUtc().toIso8601String(),
      'image_url': media['image_url'],
      'image_public_id': media['image_public_id'],
      'image_version': media['image_version'],
      'image_thumbnail_url': media['image_thumbnail_url'],
      if (notes != null && notes.isNotEmpty) 'status_note': notes,
      if (statusTag != null && statusTag.isNotEmpty) 'status_tag': statusTag,
      if (steps.isNotEmpty)
        'steps': steps
            .map((s) => {'title': s.title, 'description': s.description})
            .toList(),
    };

    final scanRes = await api.post('/api/v1/scans', body: body);
    if (scanRes.error != null || scanRes.data == null) {
      throw Exception(scanRes.error?.message ?? 'Gagal menyimpan data scan');
    }

    return _mapJsonToScanResult(scanRes.data as Map<String, dynamic>);
  }

  /// Menyimpan catatan inspeksi manual ke `/api/v1/scans`.
  Future<HistoryItem> createManualScan({
    required ApiClient api,
    required String rack,
    required int column,
    required String diagnosisName,
    String? scientificName,
    required String severity,
    String? infectionLocation,
    String? note,
    List<ScanStep> steps = const [],
    DateTime? scannedAt,
  }) async {
    if (!api.hasToken) {
      throw Exception('Sesi login belum aktif.');
    }

    final body = <String, dynamic>{
      'rak_id': rack,
      'column_no': column,
      'diagnosis_name': diagnosisName,
      if (scientificName != null && scientificName.isNotEmpty)
        'scientific_name': scientificName,
      'severity': severity,
      if (infectionLocation != null && infectionLocation.isNotEmpty)
        'infection_location': infectionLocation,
      'scan_method': 'manual',
      'scanned_at': (scannedAt ?? DateTime.now()).toUtc().toIso8601String(),
      if (note != null && note.isNotEmpty) 'status_note': note,
      'status_tag': 'Inspeksi Manual',
      if (steps.isNotEmpty)
        'steps': steps
            .map((s) => {'title': s.title, 'description': s.description})
            .toList(),
    };

    final res = await api.post('/api/v1/scans', body: body);
    if (res.error != null || res.data == null) {
      throw Exception(res.error?.message ?? 'Gagal menyimpan inspeksi manual');
    }

    return mapJsonToHistoryItem(res.data as Map<String, dynamic>);
  }

  /// Mengambil seluruh riwayat hasil pemindaian dari `/api/v1/scans`.
  Future<List<HistoryItem>> fetchScanHistory({ApiClient? api}) async {
    if (api == null || !api.hasToken) {
      throw Exception('Belum terautentikasi ke server.');
    }

    final res = await api.get('/api/v1/scans', query: {'limit': '100'});
    if (res.error != null) {
      throw Exception(res.error!.message);
    }

    final list = res.data as List<dynamic>? ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(mapJsonToHistoryItem)
        .toList();
  }

  /// Memperbarui status tindak lanjut scan di `/api/v1/scans/{id}`.
  Future<bool> updateScanStatus(
    String id, {
    required String status,
    String? note,
    String? tag,
    ApiClient? api,
  }) async {
    if (api == null || !api.hasToken) return false;
    try {
      final res = await api.patch(
        '/api/v1/scans/$id',
        body: {
          'status': status,
          'status_note': ?note,
          'status_tag': ?tag,
        },
      );
      return res.error == null;
    } catch (e) {
      debugPrint('ScanApiService: updateScanStatus error: $e');
      return false;
    }
  }

  /// Menghapus rekaman scan dari Neon DB via `DELETE /api/v1/scans/{id}`.
  Future<bool> deleteScan(String id, {ApiClient? api}) async {
    if (api == null || !api.hasToken) return false;
    try {
      final res = await api.delete('/api/v1/scans/$id');
      return res.error == null;
    } catch (e) {
      debugPrint('ScanApiService: deleteScan error: $e');
      return false;
    }
  }

  List<ScanStep> _parseSteps(dynamic rawSteps, {bool withDefaultFallback = true}) {
    List<ScanStep> parsedSteps = [];

    if (rawSteps is List) {
      parsedSteps = rawSteps
          .map((s) {
            if (s is Map) {
              return ScanStep(
                title: s['title']?.toString() ?? '',
                description: s['description']?.toString() ?? '',
              );
            }
            return ScanStep(title: s.toString(), description: '');
          })
          .where((s) => s.title.isNotEmpty || s.description.isNotEmpty)
          .toList();
    } else if (rawSteps is String && rawSteps.isNotEmpty) {
      try {
        final list = jsonDecode(rawSteps) as List;
        parsedSteps = list
            .map((s) {
              if (s is Map) {
                return ScanStep(
                  title: s['title']?.toString() ?? '',
                  description: s['description']?.toString() ?? '',
                );
              }
              return ScanStep(title: s.toString(), description: '');
            })
            .where((s) => s.title.isNotEmpty || s.description.isNotEmpty)
            .toList();
      } catch (_) {}
    }

    if (parsedSteps.isEmpty && withDefaultFallback) {
      parsedSteps = const [
        ScanStep(
          title: 'Pindahkan ke Rak Karantina',
          description:
              'Pisahkan baglog dari rak utama untuk mencegah penularan spora.',
        ),
        ScanStep(
          title: 'Observasi 48 Jam',
          description:
              'Pantau pertumbuhan miselium; buang bila bercak meluas.',
        ),
      ];
    }

    return parsedSteps;
  }

  double _normalizeConfidencePercent(dynamic rawConfidence, {double fallback = 94.2}) {
    if (rawConfidence is num) {
      final value = rawConfidence.toDouble();
      return value <= 1.0 ? value * 100.0 : value;
    }
    final parsed = double.tryParse(rawConfidence?.toString() ?? '');
    if (parsed != null) {
      return parsed <= 1.0 ? parsed * 100.0 : parsed;
    }
    return fallback;
  }

  String _formatRackLabel(String? rawRack) {
    final trimmed = rawRack?.trim() ?? '';
    if (trimmed.isEmpty) return 'Rak Kumbung B-04';
    if (trimmed.toLowerCase().startsWith('rak')) return trimmed;
    return 'Rak Kumbung $trimmed';
  }

  /// Mengonversi payload response Neon DB (`/api/v1/scans`) menjadi [ScanResult].
  ScanResult _mapJsonToScanResult(Map<String, dynamic> json) {
    final parsedSteps = _parseSteps(json['steps'], withDefaultFallback: true);
    final rawConf = json['confidence'] ?? json['confidence_score'];
    final double confPercent = _normalizeConfidencePercent(rawConf);

    final severityStr = (json['severity']?.toString() ?? '').toLowerCase();
    final severity = severityStr == 'healthy'
        ? ScanSeverity.healthy
        : severityStr == 'must_discard'
            ? ScanSeverity.mustDiscard
            : ScanSeverity.treatable;

    final rackValue = json['rak_code']?.toString() ?? json['rack']?.toString();

    return ScanResult(
      id: json['id']?.toString() ?? 'scan-${DateTime.now().millisecondsSinceEpoch}',
      diagnosisName: json['diagnosis_name']?.toString() ?? 'Green Mold',
      scientificName: json['scientific_name']?.toString() ?? 'Trichoderma sp.',
      confidence: confPercent / 100.0,
      infectionLocation:
          json['infection_location']?.toString() ?? 'Cincin & Leher Baglog',
      severity: severity,
      steps: parsedSteps,
      rack: _formatRackLabel(rackValue),
      column: json['column_no'] is int
          ? json['column_no'] as int
          : int.tryParse(json['column_no']?.toString() ?? '1') ?? 1,
      scannedAt: json['scanned_at']?.toString() ??
          json['created_at']?.toString() ??
          'Baru Saja',
      imageUrl: json['image_url']?.toString(),
    );
  }

  /// Mengonversi payload response Neon DB menjadi model [HistoryItem].
  HistoryItem mapJsonToHistoryItem(Map<String, dynamic> json) {
    final severityStr = (json['severity']?.toString() ?? '').toLowerCase();
    final statusCode = (json['status']?.toString() ?? '').toLowerCase();
    final scanMethod = (json['scan_method']?.toString() ?? 'camera').toLowerCase();
    final isManual = scanMethod == 'manual';

    String badge;
    String tone;
    HistorySectionCategory category;
    String status;
    String? actionLabel;

    if (statusCode == 'discarded') {
      badge = 'Telah Dibuang';
      tone = 'danger';
      category = HistorySectionCategory.archived;
      status = 'Status: Baglog telah dimusnahkan';
      actionLabel = null;
    } else if (statusCode == 'recovered') {
      badge = 'Selesai Diobati';
      tone = 'success';
      category = HistorySectionCategory.recovered;
      status = 'Miselium Kembali Merambat Aktif';
      actionLabel = 'Arsipkan Temuan';
    } else if (statusCode == 'archived') {
      if (severityStr == 'healthy') {
        badge = 'Sehat';
        tone = 'success';
        category = HistorySectionCategory.recovered;
        status = 'Baglog dalam kondisi sehat produktif';
        actionLabel = null;
      } else {
        badge = 'Tersanitasi';
        tone = 'warning';
        category = HistorySectionCategory.archived;
        status = 'Status: Terarsip';
        actionLabel = null;
      }
    } else if (severityStr == 'must_discard') {
      badge = 'Harus Dibuang';
      tone = 'danger';
      category = HistorySectionCategory.actionRequired;
      status = 'Status: Menunggu Pemusnahan';
      actionLabel = 'Konfirmasi Buang Baglog';
    } else if (severityStr == 'recovered') {
      badge = 'Selesai Diobati';
      tone = 'success';
      category = HistorySectionCategory.recovered;
      status = 'Miselium Kembali Merambat Aktif';
      actionLabel = 'Arsipkan Temuan';
    } else if (severityStr == 'healthy') {
      badge = 'Sehat';
      tone = 'success';
      category = HistorySectionCategory.recovered;
      status = 'Baglog dalam kondisi sehat produktif';
      actionLabel = null;
    } else {
      badge = 'Bisa Diobati';
      tone = 'warning';
      category = HistorySectionCategory.actionRequired;
      status = 'Status: Menunggu Desinfeksi';
      actionLabel = 'Konfirmasi Selesai Diobati';
    }

    // Format tanggal jika ada (`scanned_at` atau `created_at`)
    String whenStr = 'Baru Saja';
    DateTime? parsedCreatedAt;
    final rawDate =
        json['scanned_at']?.toString() ?? json['created_at']?.toString();
    if (rawDate != null && rawDate.isNotEmpty) {
      try {
        final dt = DateTime.parse(rawDate).toLocal();
        parsedCreatedAt = dt;
        const months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
          'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
        ];
        final hour = dt.hour.toString().padLeft(2, '0');
        final min = dt.minute.toString().padLeft(2, '0');
        whenStr = '${dt.day} ${months[dt.month - 1]}, $hour:$min WIB';
      } catch (_) {
        whenStr = rawDate;
      }
    }

    final int col = json['column_no'] is int
        ? json['column_no'] as int
        : int.tryParse(json['column_no']?.toString() ?? '1') ?? 1;

    final diagnosisName =
        json['diagnosis_name']?.toString().trim().isNotEmpty == true
            ? json['diagnosis_name'].toString().trim()
            : 'Pemeriksaan Visual';
    final scientificName = json['scientific_name']?.toString().trim();
    final hasScientific = scientificName != null && scientificName.isNotEmpty;

    final rawConf = json['confidence'] ?? json['confidence_score'];
    final double? confPercent =
        rawConf != null ? _normalizeConfidencePercent(rawConf) : null;

    final infectionLocation = json['infection_location']?.toString().trim();
    final parsedSteps = _parseSteps(json['steps'], withDefaultFallback: false);

    final rawNote =
        (json['status_note'] ?? json['notes'])?.toString().trim();
    final rawTag = json['status_tag']?.toString().trim();
    final rawId = json['id'];
    final itemId = rawId is int ? 'neon-$rawId' : rawId.toString();

    final rackValue = json['rak_code']?.toString() ?? json['rack']?.toString();

    return HistoryItem(
      id: itemId,
      name: hasScientific ? '$diagnosisName ($scientificName)' : diagnosisName,
      badge: badge,
      tone: tone,
      when: whenStr,
      rack: _formatRackLabel(rackValue),
      col: col,
      category: category,
      status: status,
      tag: (rawTag != null && rawTag.isNotEmpty)
          ? rawTag
          : (isManual ? 'Inspeksi Manual' : 'Tersimpan di Server'),
      note: (rawNote != null && rawNote.isNotEmpty)
          ? rawNote
          : (isManual
              ? 'Dicatat melalui inspeksi manual kumbung.'
              : confPercent != null
                  ? 'Hasil deteksi tersimpan dengan tingkat akurasi ${confPercent.toStringAsFixed(1)}%.'
                  : null),
      actionLabel: actionLabel,
      isInitiallyExpanded: false,
      imageUrl: json['image_url']?.toString() ??
          json['image_thumbnail_url']?.toString(),
      diagnosisName: diagnosisName,
      scientificName: hasScientific ? scientificName : null,
      confidenceScore: confPercent,
      infectionLocation:
          (infectionLocation != null && infectionLocation.isNotEmpty)
              ? infectionLocation
              : null,
      steps: parsedSteps,
      createdAt: parsedCreatedAt,
      isManual: isManual,
    );
  }
}
