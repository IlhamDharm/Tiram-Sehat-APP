import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tiram_sehat/core/network/api_client.dart';
import 'package:tiram_sehat/core/network/api_providers.dart';
import 'package:tiram_sehat/core/theme/app_theme.dart';
import 'package:tiram_sehat/features/auth/login_screen.dart';
import 'package:tiram_sehat/features/auth/register_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('LoginScreen menampilkan form login tanpa tombol Google',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const LoginScreen(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('TiramSehat'), findsOneWidget);
    expect(find.text('Selamat Datang, Petani!'), findsOneWidget);
    expect(
      find.text('Masuk untuk mencatat hasil panen dan memantau kesehatan baglog.'),
      findsOneWidget,
    );

    expect(find.text('Nomor WhatsApp / ID Petani'), findsOneWidget);
    expect(find.text('Contoh: 0812×xxx atau P-01'), findsOneWidget);
    expect(find.text('PIN Masuk'), findsOneWidget);
    expect(find.text('Ketik 4–6 angka PIN'), findsOneWidget);
    expect(find.text('Lupa PIN?'), findsOneWidget);
    expect(find.text('Masuk ke Kumbung'), findsOneWidget);
    expect(find.textContaining('Petani baru?'), findsOneWidget);
    expect(find.text('Registrasi Akun'), findsOneWidget);
    expect(find.textContaining('Pengurus BUMDes'), findsNothing);

    // Login dengan Google telah dihapus
    expect(find.text('ATAU'), findsNothing);
    expect(find.text('Lanjutkan dengan Google'), findsNothing);
  });

  testWidgets('Toggle obscure text PIN berfungsi dengan baik',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const LoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });

  testWidgets('Mengetuk Lupa PIN menampilkan modal bantuan pemulihan PIN',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const LoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lupa PIN?'));
    await tester.pumpAndSettle();

    expect(find.text('Lupa PIN Masuk?'), findsOneWidget);
    expect(find.text('Bantuan Pemulihan Akun Petani'), findsOneWidget);
    expect(find.text('Mengerti'), findsOneWidget);

    await tester.tap(find.text('Mengerti'));
    await tester.pumpAndSettle();

    expect(find.text('Lupa PIN Masuk?'), findsNothing);
  });

  testWidgets('PIN kurang dari 4 digit ditolak dengan pesan validasi',
      (WidgetTester tester) async {
    bool loginSuccessCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LoginScreen(
          onLoginSuccess: () => loginSuccessCalled = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), '081234567890');
    await tester.enterText(textFields.at(1), '12');
    await tester.pump();

    final cta = find.text('Masuk ke Kumbung');
    await tester.ensureVisible(cta);
    await tester.tap(cta);
    await tester.pumpAndSettle();

    expect(loginSuccessCalled, isFalse);
    expect(find.text('PIN masuk harus terdiri dari 4–8 angka.'), findsWidgets);
  });

  testWidgets('PIN salah dari server menampilkan pesan error dan memblokir login',
      (WidgetTester tester) async {
    bool loginSuccessCalled = false;
    final mockApi = ApiClient(
      baseUrl: 'http://example.test',
      client: MockClient(
        (_) async => http.Response(
          '{"error":{"code":"UNAUTHENTICATED","message":"Identifier atau PIN salah"}}',
          401,
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: LoginScreen(
            onLoginSuccess: () => loginSuccessCalled = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), '081234567890');
    await tester.enterText(textFields.at(1), '999999');
    await tester.pump();

    final cta = find.text('Masuk ke Kumbung');
    await tester.ensureVisible(cta);
    await tester.tap(cta);
    await tester.pumpAndSettle();

    expect(loginSuccessCalled, isFalse);
    expect(
      find.text(
        'Nomor WhatsApp / ID Petani atau PIN salah. Silakan periksa kembali.',
      ),
      findsWidgets,
    );
  });

  testWidgets('Login berhasil menyimpan token dan memanggil callback onLoginSuccess',
      (WidgetTester tester) async {
    bool loginSuccessCalled = false;
    final mockApi = ApiClient(
      baseUrl: 'http://example.test',
      client: MockClient(
        (_) async => http.Response(
          '{"data":{"access_token":"jwt-test-123","refresh_token":"rft-test-456"}}',
          200,
        ),
      ),
    );

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(mockApi),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: LoginScreen(
            onLoginSuccess: () {
              loginSuccessCalled = true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), '081234567890');
    await tester.enterText(textFields.at(1), '123456');
    await tester.pump();

    final cta = find.text('Masuk ke Kumbung');
    await tester.ensureVisible(cta);
    await tester.tap(cta);
    await tester.pumpAndSettle();

    expect(loginSuccessCalled, isTrue);
    expect(container.read(authTokenProvider), 'jwt-test-123');
    expect(container.read(refreshTokenProvider), 'rft-test-456');
  });

  testWidgets('Mengetuk Registrasi Akun membuka RegisterScreen dan registrasi berhasil',
      (WidgetTester tester) async {
    bool loginSuccessCalled = false;
    final mockApi = ApiClient(
      baseUrl: 'http://example.test',
      client: MockClient(
        (_) async => http.Response(
          '{"data":{"access_token":"jwt-reg-789","refresh_token":"rft-reg-012"}}',
          201,
        ),
      ),
    );

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(mockApi),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: LoginScreen(
            onLoginSuccess: () => loginSuccessCalled = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final regLink = find.text('Registrasi Akun');
    await tester.ensureVisible(regLink);
    await tester.tap(regLink);
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.text('Daftar Akun Petani'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Siti Aminah');
    await tester.enterText(fields.at(1), '081299998888');
    await tester.enterText(fields.at(2), 'PETANI-002');
    await tester.enterText(fields.at(3), '123456');
    await tester.enterText(fields.at(4), '123456');
    await tester.pump();

    final submitBtn = find.text('Daftar Sekarang');
    await tester.ensureVisible(submitBtn);
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    expect(loginSuccessCalled, isTrue);
    expect(container.read(authTokenProvider), 'jwt-reg-789');
  });

  testWidgets('RegisterScreen menolak konfirmasi PIN yang tidak cocok',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const RegisterScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Siti Aminah');
    await tester.enterText(fields.at(1), '081299998888');
    await tester.enterText(fields.at(3), '123456');
    await tester.enterText(fields.at(4), '654321');
    await tester.pump();

    final submitBtn = find.text('Daftar Sekarang');
    await tester.ensureVisible(submitBtn);
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    expect(
      find.text('Konfirmasi PIN tidak cocok dengan PIN masuk.'),
      findsWidgets,
    );
  });
}
