import 'package:flutter_test/flutter_test.dart';
import 'package:tiram_sehat/core/config/app_env.dart';

void main() {
  tearDown(AppEnv.reset);

  test('default mengarah ke server AlwaysData', () {
    AppEnv.reset();
    expect(AppEnv.baseUrl, 'https://pbl-inlet.alwaysdata.net');
    expect(AppEnv.fallbackUrls, isEmpty);
  });

  test('switch ke alwaysdata memakai API_URL_ALWAYSDATA', () {
    AppEnv.loadFromString('''
# comment
API_ENV=alwaysdata
API_URL_ALWAYSDATA=https://pbl-inlet.alwaysdata.net
API_URL_LOCAL=http://192.168.18.8:8000
''');
    expect(AppEnv.baseUrl, 'https://pbl-inlet.alwaysdata.net');
  });

  test('switch ke local memakai API_URL_LOCAL custom', () {
    AppEnv.loadFromString('''
API_ENV=local
API_URL_ALWAYSDATA="https://pbl-inlet.alwaysdata.net"
API_URL_LOCAL="http://192.168.18.8:8000"
''');
    expect(AppEnv.baseUrl, 'http://192.168.18.8:8000');
  });
}
