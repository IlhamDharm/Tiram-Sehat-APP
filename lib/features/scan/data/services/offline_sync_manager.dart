import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/models/scan_result.dart';

class OfflineScanRecord {
  final String id;
  final String rakCode;
  final int columnNo;
  final String diagnosisName;
  final String scientificName;
  final double confidence;
  final String severity;
  final DateTime scannedAt;
  bool isSynced;

  OfflineScanRecord({
    required this.id,
    required this.rakCode,
    required this.columnNo,
    required this.diagnosisName,
    required this.scientificName,
    required this.confidence,
    required this.severity,
    required this.scannedAt,
    this.isSynced = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'rak_code': rakCode,
        'column_no': columnNo,
        'diagnosis_name': diagnosisName,
        'scientific_name': scientificName,
        'confidence': confidence,
        'severity': severity,
        'scanned_at': scannedAt.toIso8601String(),
        'is_synced': isSynced,
      };

  factory OfflineScanRecord.fromJson(Map<String, dynamic> json) =>
      OfflineScanRecord(
        id: json['id'] as String,
        rakCode: json['rak_code'] as String,
        columnNo: json['column_no'] as int,
        diagnosisName: json['diagnosis_name'] as String,
        scientificName: json['scientific_name'] as String,
        confidence: (json['confidence'] as num).toDouble(),
        severity: json['severity'] as String,
        scannedAt: DateTime.parse(json['scanned_at'] as String),
        isSynced: json['is_synced'] as bool? ?? false,
      );
}

class OfflineSyncManager extends ChangeNotifier {
  static final OfflineSyncManager _instance = OfflineSyncManager._internal();
  factory OfflineSyncManager() => _instance;
  OfflineSyncManager._internal();

  final List<OfflineScanRecord> _records = [];
  bool _isSyncing = false;

  List<OfflineScanRecord> get records => List.unmodifiable(_records);
  int get pendingCount => _records.where((r) => !r.isSynced).length;
  bool get isSyncing => _isSyncing;

  /// Menyimpan hasil scan on-device ke antrean lokal offline.
  void recordScan(ScanResult result) {
    final severityStr = switch (result.severity) {
      ScanSeverity.healthy => 'healthy',
      ScanSeverity.mustDiscard => 'must_discard',
      ScanSeverity.treatable => 'treatable',
    };

    // Bersihkan nama rak (misal 'Rak Kumbung B-04' -> 'B-04')
    final cleanRak = result.rack.replaceAll('Rak Kumbung ', '').trim();

    final record = OfflineScanRecord(
      id: result.id,
      rakCode: cleanRak.isNotEmpty ? cleanRak : 'B-04',
      columnNo: result.column,
      diagnosisName: result.diagnosisName,
      scientificName: result.scientificName,
      confidence: result.confidence,
      severity: severityStr,
      scannedAt: DateTime.now(),
      isSynced: false,
    );

    _records.insert(0, record);
    notifyListeners();
  }

  /// Melakukan sinkronisasi data pending ke Backend FastAPI & Neon PostgreSQL.
  Future<int> syncPending(ApiClient api) async {
    if (_isSyncing) return 0;
    final pending = _records.where((r) => !r.isSynced).toList();
    if (pending.isEmpty) return 0;

    _isSyncing = true;
    notifyListeners();

    int syncedCount = 0;

    try {
      for (final item in pending) {
        final payload = {
          'client_id': item.id,
          'rak_id': item.rakCode,
          'column_no': item.columnNo,
          'diagnosis_name': item.diagnosisName,
          'scientific_name': item.scientificName,
          'confidence': item.confidence,
          'severity': item.severity,
          'scan_method': 'camera',
          'scanned_at': item.scannedAt.toIso8601String(),
        };

        final response = await api.post('/api/v1/scans', body: payload);

        // Jika respons 200/201/202, tandai lokal sebagai sudah tersinkronkan
        if (response.error == null) {
          item.isSynced = true;
          syncedCount++;
        }
      }
    } catch (e) {
      debugPrint('Sync failed (offline or network error): $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }

    return syncedCount;
  }
}

