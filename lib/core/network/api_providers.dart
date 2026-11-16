import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

/// Base URL backend FastAPI.
///
/// Override saat build/run, misalnya untuk HP fisik:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.18.8:8000`
const String _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

String get kBackendBaseUrl {
  if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;
  if (kIsWeb) return 'http://localhost:8000';
  return switch (defaultTargetPlatform) {
    // Emulator Android memetakan host ke 10.0.2.2.
    TargetPlatform.android => 'http://10.0.2.2:8000',
    _ => 'http://localhost:8000',
  };
}

/// Token sesi aktif. Menggunakan default dev token agar saat development langsung
/// terautentikasi ke backend sebagai petani default Budi Santoso (PETANI-001).
const String _devDefaultToken =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJhMDAwMDAwMC0wMDAwLTAwMDAtMDAwMC0wMDAwMDAwMDAwMDEiLCJyb2xlIjoiZmFybWVyIiwiZXhwIjoyMDUxMTk3MjAwLjB9.mbl1FeOf43X9F0kSLD4qOWXmTvVWxDQD3OgorKuytfY';

final authTokenProvider = StateProvider<String?>((ref) => _devDefaultToken);

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(baseUrl: kBackendBaseUrl);
  final token = ref.watch(authTokenProvider);
  if (token != null && token.isNotEmpty) {
    client.setToken(token);
  }
  return client;
});
