import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/game_session.dart';
import 'providers/game_session_provider.dart';
import 'providers/settings_provider.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'utils/keep_awake.dart';

class UndercoverApp extends ConsumerWidget {
  const UndercoverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(settingsProvider);

    // Hold the screen awake for as long as a round is running.
    ref.listen<GameSession?>(gameSessionProvider, (previous, next) {
      final wasRunning = previous != null;
      final isRunning = next != null;
      if (wasRunning != isRunning) setKeepAwake(isRunning);
    });

    return MaterialApp.router(
      title: 'Undercover',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
