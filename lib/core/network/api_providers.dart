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
    // HP fisik via `adb reverse tcp:8000 tcp:8000` memakai 127.0.0.1;
    // emulator Android akan otomatis fallback ke 10.0.2.2.
    TargetPlatform.android => 'http://127.0.0.1:8000',
    _ => 'http://localhost:8000',
  };
}

List<String> get kBackendFallbackUrls {
  if (_configuredBaseUrl.isNotEmpty || kIsWeb) return const [];
  if (defaultTargetPlatform == TargetPlatform.android) {
    return const ['http://10.0.2.2:8000'];
  }
  return const [];
}

/// Token sesi aktif. Diisi saat login atau registrasi berhasil ke backend.
/// ApiClient otomatis memakai token ini pada header Authorization.
final authTokenProvider = StateProvider<String?>((ref) => null);
final refreshTokenProvider = StateProvider<String?>((ref) => null);

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    baseUrl: kBackendBaseUrl,
    fallbackBaseUrls: kBackendFallbackUrls,
  );
  final token = ref.watch(authTokenProvider);
  if (token != null && token.isNotEmpty) {
    client.setToken(token);
  }
  return client;
});
