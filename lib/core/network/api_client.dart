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
  final String baseUrl;
  final Duration timeout;
  String? _accessToken;
  final http.Client _http;

  ApiClient({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 20),
    http.Client? client,
  }) : _http = client ?? http.Client();

  void setToken(String token) => _accessToken = token;
  void clearToken() => _accessToken = null;
  bool get hasToken => _accessToken != null && _accessToken!.isNotEmpty;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  Future<ApiResponse> get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final res = await _http.get(uri, headers: _headers).timeout(timeout);
    return _parse(res);
  }

  Future<ApiResponse> post(String path,
      {Object? body, Map<String, String>? headers}) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await _http
        .post(uri,
            headers: {..._headers, ...?headers},
            body: body != null ? jsonEncode(body) : null)
        .timeout(timeout);
    return _parse(res);
  }

  Future<ApiResponse> patch(String path, {Object? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await _http
        .patch(uri,
            headers: _headers, body: body != null ? jsonEncode(body) : null)
        .timeout(timeout);
    return _parse(res);
  }

  Future<ApiResponse> delete(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await _http.delete(uri, headers: _headers).timeout(timeout);
    return _parse(res);
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
