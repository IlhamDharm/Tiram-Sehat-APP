import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/network/api_providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/components/app_header.dart';
import '../../core/components/bottom_nav.dart';
import '../home/home_screen.dart';
import '../scan/scan_screen.dart';
import '../harvest/harvest_screen.dart';
import '../history/history_screen.dart';
import '../history/presentation/providers/history_provider.dart';
import '../report/report_screen.dart';
import '../auth/login_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _stackTabs = <BottomNavTab>[
    BottomNavTab.home,
    BottomNavTab.harvest,
    BottomNavTab.report,
    BottomNavTab.history,
  ];

  BottomNavTab _activeTab = BottomNavTab.home;
  final Set<BottomNavTab> _visitedTabs = {BottomNavTab.home};

  void _selectTab(BottomNavTab tab) {
    setState(() {
      _activeTab = tab;
      _visitedTabs.add(tab);
    });
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: Text(
          'Keluar dari Akun?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Sesi login saat ini akan diakhiri dan Anda akan kembali ke halaman masuk.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Batal',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Keluar',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final refreshToken = ref.read(refreshTokenProvider);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await ref.read(apiClientProvider).post(
          '/api/v1/auth/logout',
          body: {'refresh_token': refreshToken},
        );
      } catch (_) {
        // Tetap lanjut keluar secara lokal bila server tidak terjangkau.
      }
    }

    if (!mounted) return;
    ref.read(authTokenProvider.notifier).state = null;
    ref.read(refreshTokenProvider.notifier).state = null;
    ref.read(historySyncStatusProvider.notifier).state = HistorySyncStatus.idle;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _screenFor(BottomNavTab tab) {
    switch (tab) {
      case BottomNavTab.home:
        return HomeScreen(onGoToScan: () => _selectTab(BottomNavTab.scan));
      case BottomNavTab.harvest:
        return HarvestScreen(onSaved: () => _selectTab(BottomNavTab.home));
      case BottomNavTab.report:
        return const ReportScreen();
      case BottomNavTab.history:
        return const HistoryScreen();
      case BottomNavTab.scan:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBody() {
    // Scan bersifat fullscreen dan tidak ikut disimpan di IndexedStack agar
    // kamera benar-benar dilepas saat pengguna keluar dari layar scan.
    if (_activeTab == BottomNavTab.scan) {
      return ScanScreen(
        onBack: () => _selectTab(BottomNavTab.home),
        onSavedToHistory: () => _selectTab(BottomNavTab.history),
      );
    }

    return IndexedStack(
      index: _stackTabs.indexOf(_activeTab),
      children: [
        for (final tab in _stackTabs)
          _visitedTabs.contains(tab)
              ? _screenFor(tab)
              : const SizedBox.shrink(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Layar scan bersifat fullscreen immersif (DESIGN §8.3, §10 #2):
    // tanpa AppHeader dan tanpa BottomNav.
    final bool immersive = _activeTab == BottomNavTab.scan;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: immersive ? Brightness.light : Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: immersive
          ? null
          : AppHeader(onLogoutPress: _handleLogout),
      body: _buildBody(),
      bottomNavigationBar: immersive
          ? null
          : BottomNav(
              active: _activeTab,
              onChange: (tab) => _selectTab(tab),
            ),
    );
  }
}
