import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Konfigurasi environment Flutter dari file `.env` di root project.
///
/// Memudahkan switch antara backend `alwaysdata` dan `local` cukup dengan
/// mengubah `API_ENV` / `API_URL_LOCAL` di `.env`.
class AppEnv {
  AppEnv._();

  static const String defaultAlwaysDataUrl = 'https://pbl-inlet.alwaysdata.net';
  static const String defaultLocalUrl = 'http://127.0.0.1:8000';
  static const String _dartDefineBaseUrl = String.fromEnvironment('API_BASE_URL');

  static final Map<String, String> _values = {};

  /// Memuat file `.env` dari bundle asset. Aman dipanggil berulang kali.
  static Future<void> load({String assetPath = '.env'}) async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      loadFromString(raw);
    } catch (_) {
      // Jika `.env` tidak tersedia (misal di unit test), gunakan nilai default.
    }
  }

  /// Mem-parse isi `.env` langsung dari string (berguna untuk pengujian).
  static void loadFromString(String raw) {
    _values.clear();
    for (final rawLine in raw.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final eqIndex = line.indexOf('=');
      if (eqIndex <= 0) continue;
      final key = line.substring(0, eqIndex).trim();
      var value = line.substring(eqIndex + 1).trim();
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        if (value.length >= 2) {
          value = value.substring(1, value.length - 1);
        }
      }
      _values[key] = value;
    }
  }

  /// Menghapus nilai yang dimuat (untuk keperluan test).
  static void reset() => _values.clear();

  static String? get(String key) => _values[key];

  static String get apiEnv => (_values['API_ENV'] ?? 'alwaysdata').toLowerCase();

  static String get baseUrl {
    if (_dartDefineBaseUrl.isNotEmpty) return _dartDefineBaseUrl;

    final directUrl = _values['API_BASE_URL'];
    if (directUrl != null && directUrl.isNotEmpty) return directUrl;

    if (apiEnv == 'local') {
      final localUrl = _values['API_URL_LOCAL'];
      if (localUrl != null && localUrl.isNotEmpty) return localUrl;
      if (kIsWeb) return 'http://localhost:8000';
      return defaultLocalUrl;
    }

    final alwaysDataUrl = _values['API_URL_ALWAYSDATA'];
    if (alwaysDataUrl != null && alwaysDataUrl.isNotEmpty) {
      return alwaysDataUrl;
    }
    return defaultAlwaysDataUrl;
  }

  static List<String> get fallbackUrls {
    if (_dartDefineBaseUrl.isNotEmpty || kIsWeb) return const [];
    if (apiEnv == 'local' &&
        defaultTargetPlatform == TargetPlatform.android &&
        baseUrl == defaultLocalUrl) {
      return const ['http://10.0.2.2:8000'];
    }
    return const [];
  }
}
