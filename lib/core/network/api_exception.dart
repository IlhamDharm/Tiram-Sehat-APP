import 'api_client.dart';

class ApiException implements Exception {
  final String code;
  final String message;

  const ApiException({required this.code, required this.message});

  factory ApiException.from(ApiError? error) {
    return ApiException(
      code: error?.code ?? 'unknown',
      message: error?.message ?? 'Unknown error occurred',
    );
  }

  @override
  String toString() => 'ApiException($code): $message';
}
