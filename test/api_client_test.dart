import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tiram_sehat/core/network/api_client.dart';

void main() {
  group('ApiClient', () {
    test('membaca envelope sukses', () async {
      final client = ApiClient(
        baseUrl: 'http://example.test',
        client: MockClient(
          (_) async => http.Response('{"data":{"value":42}}', 200),
        ),
      );

      final res = await client.get('/ping');

      expect(res.error, isNull);
      expect((res.data as Map<String, dynamic>)['value'], 42);
    });

    test('membaca envelope error tanpa melempar exception', () async {
      final client = ApiClient(
        baseUrl: 'http://example.test',
        client: MockClient(
          (_) async => http.Response(
            '{"error":{"code":"UNAUTHENTICATED","message":"Token tidak valid"}}',
            401,
          ),
        ),
      );

      final res = await client.get('/private');

      expect(res.data, isNull);
      expect(res.error?.code, 'UNAUTHENTICATED');
      expect(res.error?.message, 'Token tidak valid');
    });

    test('respons 204 tanpa body tidak membuat FormatException', () async {
      final client = ApiClient(
        baseUrl: 'http://example.test',
        client: MockClient((_) async => http.Response('', 204)),
      );

      final res = await client.delete('/items/1');

      expect(res.error, isNull);
      expect(res.data, isNull);
    });

    test('respons non-JSON diubah menjadi error HTTP', () async {
      final client = ApiClient(
        baseUrl: 'http://example.test',
        client: MockClient((_) async => http.Response('<html>bad</html>', 502)),
      );

      final res = await client.get('/down');

      expect(res.error?.code, 'http_502');
    });
  });
}
