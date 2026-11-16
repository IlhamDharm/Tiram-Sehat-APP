import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_env.dart';
import 'api_client.dart';

/// Base URL backend FastAPI (diatur lewat file `.env` di root project,
/// atau override via `--dart-define=API_BASE_URL=...`).
String get kBackendBaseUrl => AppEnv.baseUrl;

List<String> get kBackendFallbackUrls => AppEnv.fallbackUrls;

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
