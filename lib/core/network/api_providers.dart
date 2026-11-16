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

/// Token sesi aktif. Diisi saat login atau registrasi berhasil ke backend.
/// ApiClient otomatis memakai token ini pada header Authorization.
final authTokenProvider = StateProvider<String?>((ref) => null);
final refreshTokenProvider = StateProvider<String?>((ref) => null);

final apiClientProvider = Provider<ApiClient>((ref) {
  final candidateUrls = <String>[
    if (_configuredBaseUrl.isNotEmpty) _configuredBaseUrl,
    if (kIsWeb)
      'http://localhost:8000'
    else ...[
      'http://127.0.0.1:8000', // HP fisik via adb reverse USB
      'http://10.0.2.2:8000', // Android Emulator
      'http://192.168.1.212:8000', // Wi-Fi LAN
      'http://localhost:8000',
    ],
  ];

  final primary = candidateUrls.first;
  final fallbacks = candidateUrls.skip(1).toList();

  final client = ApiClient(baseUrl: primary, fallbackUrls: fallbacks);
  final token = ref.watch(authTokenProvider);
  if (token != null && token.isNotEmpty) {
    client.setToken(token);
  }
  return client;
});
