import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/tokens.dart';
import '../../core/components/app_header.dart';
import '../../core/components/bottom_nav.dart';
import '../home/home_screen.dart';
import '../scan/scan_screen.dart';
import '../harvest/harvest_screen.dart';
import '../history/history_screen.dart';
import '../report/report_screen.dart';
import '../auth/login_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
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

  Widget _screenFor(BottomNavTab tab) {
    switch (tab) {
      case BottomNavTab.home:
        return HomeScreen(onGoToScan: () => _selectTab(BottomNavTab.scan));
      case BottomNavTab.harvest:
        return const HarvestScreen();
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
          : AppHeader(
              onProfilePress: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
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

