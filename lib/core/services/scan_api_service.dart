import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../mock/mock_data.dart';

/// Layanan API untuk integrasi Cloudinary (Image Storage) & Neon DB (PostgreSQL).
/// Menyediakan fungsi unggah gambar scan, pengambilan riwayat, dan penghapusan data.
class ScanApiService {
  ScanApiService._();
  static final ScanApiService instance = ScanApiService._();

  /// Default URL: 127.0.0.1:8000 untuk Android (bekerja via adb reverse) dan localhost untuk Web/Desktop.
  static String get defaultBaseUrl {
    if (kIsWeb) return 'http://localhost:8000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://127.0.0.1:8000';
    }
    return 'http://localhost:8000';
  }

  String baseUrl = defaultBaseUrl;

  List<String> get _candidateUrls {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Pada Android, utamakan baseUrl aktif, lalu 127.0.0.1 (via adb reverse), dan fallback 10.0.2.2
      final list = <String>[baseUrl, 'http://127.0.0.1:8000', 'http://10.0.2.2:8000'];
      return list.toSet().toList();
    }
    return [baseUrl];
  }

  /// Mengunggah gambar baglog ke Cloudinary (folder img_jamur) dan menyimpan metadata ke Neon DB.
  Future<ScanResult> uploadScan({
    required Uint8List bytes,
    String filename = 'scan.jpg',
    String rack = 'Rak Kumbung B-04',
    int column = 3,
    String? diagnosisName,
    String? scientificName,
    double? confidenceScore,
    String? infectionLocation,
    String? severity,
    String? notes,
  }) async {
    final candidates = _candidateUrls;
    Exception? lastError;

    for (int i = 0; i < candidates.length; i++) {
      final currentBase = candidates[i];
      final uri = Uri.parse('$currentBase/api/scan');
      debugPrint('ScanApiService: Uploading scan to $uri (attempt ${i + 1}/${candidates.length})...');

      try {
        final request = http.MultipartRequest('POST', uri);
        request.fields['rack'] = rack;
        request.fields['column'] = column.toString();
        if (diagnosisName != null) request.fields['diagnosis_name'] = diagnosisName;
        if (scientificName != null) request.fields['scientific_name'] = scientificName;
        if (confidenceScore != null) {
          request.fields['confidence_score'] =
              (confidenceScore <= 1.0 ? confidenceScore * 100 : confidenceScore)
                  .toStringAsFixed(1);
        }
        if (infectionLocation != null) {
          request.fields['infection_location'] = infectionLocation;
        }
        if (severity != null) request.fields['severity'] = severity;
        if (notes != null && notes.isNotEmpty) {
          request.fields['notes'] = notes;
        }

        final multipartFile = http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
          contentType: MediaType('image', 'jpeg'),
        );
        request.files.add(multipartFile);

        debugPrint('ScanApiService: Sending ${bytes.length} bytes as image/jpeg...');
        final streamedResponse = await request.send().timeout(
              const Duration(seconds: 10),
            );
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final data = decoded['data'] as Map<String, dynamic>;
          debugPrint('ScanApiService: Scan uploaded successfully. ID: ${data['id']}, URL: ${data['image_url']}');
          baseUrl = currentBase; // Simpan URL aktif agar request berikutnya langsung ke host ini
          return _mapJsonToScanResult(data);
        } else {
          throw Exception(
            'Gagal mengunggah scan (HTTP ${response.statusCode}): ${response.body}',
          );
        }
      } catch (e) {
        debugPrint('ScanApiService: upload to $currentBase failed: $e');
        lastError = e is Exception ? e : Exception(e.toString());
      }
    }

    throw lastError ?? Exception('Semua koneksi backend gagal dihubungi');
  }

  /// Mengambil seluruh riwayat hasil pemindaian dari database Neon DB.
  Future<List<HistoryItem>> fetchScanHistory() async {
    final candidates = _candidateUrls;

    for (int i = 0; i < candidates.length; i++) {
      final currentBase = candidates[i];
      final uri = Uri.parse('$currentBase/api/scans');
      debugPrint('ScanApiService: Fetching scans from $uri (attempt ${i + 1}/${candidates.length})...');

      try {
        final response = await http.get(uri).timeout(const Duration(seconds: 10));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final list = decoded['data'] as List<dynamic>;
          baseUrl = currentBase; // Simpan URL aktif

          return list.map((item) {
            final map = item as Map<String, dynamic>;
            return mapJsonToHistoryItem(map);
          }).toList();
        } else {
          throw Exception(
            'Gagal mengambil riwayat scan (HTTP ${response.statusCode})',
          );
        }
      } catch (e) {
        debugPrint('ScanApiService: fetch from $currentBase failed: $e');
        if (i == candidates.length - 1) rethrow;
      }
    }

    return [];
  }

  /// Menghapus rekaman scan dari Neon DB.
  Future<bool> deleteScan(int id) async {
    final uri = Uri.parse('$baseUrl/api/scans/$id');
    try {
      final response = await http.delete(uri).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('ScanApiService: deleteScan error: $e');
      return false;
    }
  }

  /// Mengonversi payload response Neon DB menjadi model ScanResult.
  ScanResult _mapJsonToScanResult(Map<String, dynamic> json) {
    final rawSteps = json['steps'];
    List<ScanStep> parsedSteps = [];

    if (rawSteps is List) {
      parsedSteps = rawSteps.map((s) {
        if (s is Map) {
          return ScanStep(
            title: s['title']?.toString() ?? '',
            description: s['description']?.toString() ?? '',
          );
        }
        return ScanStep(title: s.toString(), description: '');
      }).toList();
    } else if (rawSteps is String) {
      try {
        final list = jsonDecode(rawSteps) as List;
        parsedSteps = list.map((s) {
          return ScanStep(
            title: s['title']?.toString() ?? '',
            description: s['description']?.toString() ?? '',
          );
        }).toList();
      } catch (_) {}
    }

    if (parsedSteps.isEmpty) {
      parsedSteps = MockData.scanResult.steps;
    }

    final double confScore = json['confidence_score'] is num
        ? (json['confidence_score'] as num).toDouble()
        : 94.2;

    final severityStr = (json['severity']?.toString() ?? '').toLowerCase();
    final severity = severityStr == 'must_discard'
        ? ScanSeverity.mustDiscard
        : ScanSeverity.treatable;

    return ScanResult(
      id: 'neon-${json['id']}',
      diagnosisName: json['diagnosis_name']?.toString() ?? 'Green Mold',
      scientificName: json['scientific_name']?.toString() ?? 'Trichoderma sp.',
      confidence: confScore > 1 ? confScore / 100.0 : confScore,
      infectionLocation:
          json['infection_location']?.toString() ?? 'Cincin & Leher Baglog',
      severity: severity,
      steps: parsedSteps,
      rack: json['rack']?.toString() ?? 'Rak Kumbung B-04',
      column: json['column_no'] is int
          ? json['column_no'] as int
          : int.tryParse(json['column_no']?.toString() ?? '3') ?? 3,
      scannedAt: json['created_at']?.toString() ?? 'Baru Saja',
      imageUrl: json['image_url']?.toString(),
    );
  }

  /// Mengonversi payload response Neon DB menjadi model HistoryItem.
  HistoryItem mapJsonToHistoryItem(Map<String, dynamic> json) {
    final severityStr = (json['severity']?.toString() ?? '').toLowerCase();

    String badge;
    String tone;
    HistorySectionCategory category;
    String status;
    String actionLabel;

    if (severityStr == 'must_discard') {
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
    } else {
      badge = 'Bisa Diobati';
      tone = 'warning';
      category = HistorySectionCategory.actionRequired;
      status = 'Status: Menunggu Desinfeksi';
      actionLabel = 'Konfirmasi Selesai Diobati';
    }

    // Format tanggal jika ada
    String whenStr = 'Baru Saja';
    final createdAt = json['created_at']?.toString();
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        final months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
          'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
        ];
        final hour = dt.hour.toString().padLeft(2, '0');
        final min = dt.minute.toString().padLeft(2, '0');
        whenStr = '${dt.day} ${months[dt.month - 1]}, $hour:$min WIB';
      } catch (_) {
        whenStr = createdAt;
      }
    }

    final int col = json['column_no'] is int
        ? json['column_no'] as int
        : int.tryParse(json['column_no']?.toString() ?? '1') ?? 1;

    return HistoryItem(
      id: 'neon-${json['id']}',
      name: '${json['diagnosis_name'] ?? 'Pemeriksaan Visual'}${json['scientific_name'] != null ? ' (${json['scientific_name']})' : ''}',
      badge: badge,
      tone: tone,
      when: whenStr,
      rack: json['rack']?.toString() ?? 'Rak Kumbung B-04',
      col: col,
      category: category,
      status: status,
      tag: 'Tersimpan di Neon DB',
      note: json['notes']?.toString() ??
          'Gambar tersimpan di Cloudinary dengan tingkat akurasi ${(json['confidence_score'] ?? 94.2)}%.',
      actionLabel: actionLabel,
      isInitiallyExpanded: true,
      imageUrl: json['image_url']?.toString(),
    );
  }
}
