import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/game_state_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/backup_settings_sheet.dart';
import 'fixture_screen.dart';
import 'history_screen.dart';
import 'teams_screen.dart';
import 'tournaments_screen.dart';

/// Kerangka navigasi utama aplikasi dengan Nested Navigator pada setiap tab
/// (Turnamen, Fixture, Daftar Tim, History) agar Bottom Navigation Bar tetap
/// tampil saat user membuka halaman detail.
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    4,
    (_) => GlobalKey<NavigatorState>(),
  );

  static const List<String> _tabTitles = [
    'Turnamen',
    'Fixture',
    'Daftar Tim',
    'History',
  ];

  static const List<Widget> _pages = [
    TournamentsScreen(),
    FixtureScreen(),
    TeamsScreen(),
    HistoryScreen(),
  ];

  void _onTabTapped(int index) {
    if (index == _selectedIndex) {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() => _selectedIndex = index);
  }

  Future<void> _handlePopInvoked(bool didPop, Object? result) async {
    if (didPop) return;

    final currentNavigator = _navigatorKeys[_selectedIndex].currentState;
    if (currentNavigator != null && currentNavigator.canPop()) {
      await currentNavigator.maybePop();
      return;
    }

    if (!mounted) return;
    final rootNavigator = Navigator.of(context);
    if (rootNavigator.canPop()) {
      rootNavigator.pop();
    } else {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: _handlePopInvoked,
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            for (var i = 0; i < _pages.length; i++)
              _TabNavigator(
                navigatorKey: _navigatorKeys[i],
                title: _tabTitles[i],
                child: _pages[i],
              ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: AppTheme.borderHairline, width: 1),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onTabTapped,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.emoji_events_outlined),
                activeIcon: Icon(Icons.emoji_events),
                label: 'Turnamen',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_today_outlined),
                activeIcon: Icon(Icons.calendar_today),
                label: 'Fixture',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.shield_outlined),
                activeIcon: Icon(Icons.shield),
                label: 'Daftar Tim',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history_edu_outlined),
                activeIcon: Icon(Icons.history_edu),
                label: 'History',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabNavigator extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final String title;
  final Widget child;

  const _TabNavigator({
    required this.navigatorKey,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => _TabRootScaffold(
          title: title,
          body: child,
        ),
      ),
    );
  }
}

class _TabRootScaffold extends StatelessWidget {
  final String title;
  final Widget body;

  const _TabRootScaffold({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final currentSeason = context.select<GameStateProvider, int>(
      (provider) => provider.currentSeason,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.ovrEliteBg,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                border: Border.all(
                  color: AppTheme.primaryBrand.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'Musim $currentSeason',
                style: AppTheme.badge.copyWith(
                  color: AppTheme.ovrEliteText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Pengaturan & Backup',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => showBackupSettingsSheet(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: body,
    );
  }
}
