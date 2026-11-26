import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/game_state_provider.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/setup_leagues_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GameStateProvider>(
      create: (_) => GameStateProvider()..initialize(),
      child: MaterialApp(
        title: 'Football Tournament Simulator',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const _AppEntryGate(),
      ),
    );
  }
}

class _AppEntryGate extends StatelessWidget {
  const _AppEntryGate();

  @override
  Widget build(BuildContext context) {
    return Consumer<GameStateProvider>(
      builder: (context, provider, _) {
        if (!provider.isInitialized) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryBrand,
              ),
            ),
          );
        }

        if (provider.isSeasonStarted && provider.canStartFirstSeason) {
          return const MainNavigationScreen();
        }

        return const SetupLeaguesScreen();
      },
    );
  }
}
