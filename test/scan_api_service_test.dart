import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiram_sehat/core/network/api_client.dart';
import 'package:tiram_sehat/core/services/scan_api_service.dart';
import 'package:tiram_sehat/features/scan/domain/models/scan_result.dart';

void main() {
  test('ScanApiService.predictImage mengirim multipart file dan mem-parse ScanResult', () async {
    String? receivedMethod;
    String? receivedPath;
    String? receivedContentType;
    var receivedBodyBytes = <int>[];

    final server = await HttpServer.bind('127.0.0.1', 0);
    addTearDown(() => server.close(force: true));

    server.listen((HttpRequest req) async {
      if (req.uri.path == '/health') {
        req.response.statusCode = 200;
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode({
          'data': {'status': 'ok', 'model_loaded': true}
        }));
        await req.response.close();
        return;
      }

      if (req.uri.path == '/api/v1/scans/predict') {
        receivedMethod = req.method;
        receivedPath = req.uri.path;
        receivedContentType = req.headers.contentType?.mimeType;
        receivedBodyBytes = await req.fold<List<int>>([], (acc, chunk) {
          acc.addAll(chunk);
          return acc;
        });

        req.response.statusCode = 200;
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode({
          'data': {
            'ml_label': 'greenmold',
            'disease_id': 'd0000000-0000-0000-0000-000000000004',
            'diagnosis_name': 'Green Mold',
            'scientific_name': 'Trichoderma sp.',
            'description': 'Kontaminasi jamur hijau pada permukaan baglog.',
            'confidence': 0.912,
            'probabilities': {
              'greenmold': 0.912,
              'blackmold': 0.052,
              'healthy': 0.036,
            },
            'severity': 'treatable',
            'infection_location': 'Cincin & Permukaan Baglog',
            'model_version': 'mobilenetv2-end2end-v7',
            'steps': [
              {
                'step_order': 1,
                'title': 'Pindahkan ke Rak Karantina',
                'description': 'Segera pisahkan baglog.',
              },
            ],
          },
          'error': null,
          'meta': null,
        }));
        await req.response.close();
        return;
      }

      req.response.statusCode = 404;
      await req.response.close();
    });

    final api = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
    final fakeJpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);

    final result = await ScanApiService.instance.predictImage(
      bytes: fakeJpeg,
      api: api,
      filename: 'baglog_test.jpg',
      rack: 'A',
      column: 2,
    );

    expect(receivedMethod, 'POST');
    expect(receivedPath, '/api/v1/scans/predict');
    expect(receivedContentType, 'multipart/form-data');
    expect(utf8.decode(receivedBodyBytes, allowMalformed: true),
        contains('name="file"'));

    expect(result.mlLabel, 'greenmold');
    expect(result.modelVersion, 'mobilenetv2-end2end-v7');
    expect(result.diagnosisName, 'Green Mold');
    expect(result.scientificName, 'Trichoderma sp.');
    expect(result.description, 'Kontaminasi jamur hijau pada permukaan baglog.');
    expect(result.probabilities['greenmold'], closeTo(0.912, 0.0001));
    expect(result.probabilities['blackmold'], closeTo(0.052, 0.0001));
    expect(result.probabilities['healthy'], closeTo(0.036, 0.0001));
    expect(result.confidence, closeTo(0.912, 0.0001));
    expect(result.severity, ScanSeverity.treatable);
    expect(result.infectionLocation, 'Cincin & Permukaan Baglog');
    expect(result.rack, 'Rak Kumbung A');
    expect(result.column, 2);
    expect(result.steps.length, 1);
    expect(result.steps.first.title, 'Pindahkan ke Rak Karantina');
  });
}
