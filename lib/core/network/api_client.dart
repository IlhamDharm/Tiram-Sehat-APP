import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiError {
  final String code;
  final String message;
  const ApiError({required this.code, required this.message});
}

class ApiResponse {
  final dynamic data;
  final ApiError? error;
  const ApiResponse({this.data, this.error});
}

class ApiClient {
  String baseUrl;
  final List<String> fallbackUrls;
  final Duration timeout;
  String? _accessToken;
  final http.Client _http;

  ApiClient({
    required this.baseUrl,
    this.fallbackUrls = const [],
    this.timeout = const Duration(seconds: 10),
    http.Client? client,
  }) : _http = client ?? http.Client();

  void setToken(String token) => _accessToken = token;
  void clearToken() => _accessToken = null;
  bool get hasToken => _accessToken != null && _accessToken!.isNotEmpty;
  String? get accessToken => _accessToken;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  Future<ApiResponse> _execute(Future<http.Response> Function(String base) fn) async {
    final urls = [baseUrl, ...fallbackUrls.where((u) => u != baseUrl)];
    Exception? lastException;
    for (final url in urls) {
      try {
        final res = await fn(url).timeout(timeout);
        // Simpan URL yang berhasil sebagai baseUrl utama untuk panggilan berikutnya
        baseUrl = url;
        return _parse(res);
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        continue;
      }
    }
    throw lastException ?? Exception('Gagal terhubung ke server backend');
  }

  Future<ApiResponse> get(String path, {Map<String, String>? query}) {
    return _execute((base) {
      final uri = Uri.parse('$base$path').replace(queryParameters: query);
      return _http.get(uri, headers: _headers);
    });
  }

  Future<ApiResponse> post(String path,
      {Object? body, Map<String, String>? headers}) {
    return _execute((base) {
      final uri = Uri.parse('$base$path');
      return _http.post(
        uri,
        headers: {..._headers, ...?headers},
        body: body != null ? jsonEncode(body) : null,
      );
    });
  }

  Future<ApiResponse> patch(String path, {Object? body}) {
    return _execute((base) {
      final uri = Uri.parse('$base$path');
      return _http.patch(
        uri,
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );
    });
  }

  Future<ApiResponse> delete(String path) {
    return _execute((base) {
      final uri = Uri.parse('$base$path');
      return _http.delete(uri, headers: _headers);
    });
  }

  ApiResponse _parse(http.Response res) {
    Map<String, dynamic>? json;
    if (res.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) json = decoded;
      } on FormatException {
        // Respons non-JSON (mis. HTML dari proxy) ditangani sebagai error HTTP.
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return ApiResponse(data: json?['data']);
    }

    final err = json?['error'] as Map<String, dynamic>?;
    return ApiResponse(
      error: ApiError(
        code: err?['code'] as String? ?? 'http_${res.statusCode}',
        message: err?['message'] as String? ??
            'Permintaan gagal (HTTP ${res.statusCode})',
      ),
    );
  }
}
