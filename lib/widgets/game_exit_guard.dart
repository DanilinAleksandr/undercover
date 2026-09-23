import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/game_session_provider.dart';
import '../router/route_paths.dart';
import 'exit_confirm_dialog.dart';

/// Protects a round in progress from the system back button.
///
/// Every in-game screen is reached with `context.go`, which replaces the
/// navigation stack — so there is nothing to pop and Android would simply
/// close the app, taking the round with it. Around a table that means one
/// stray back-swipe during the discussion ends the game for everyone, so the
/// guard is applied to the whole `/game` branch in one place rather than
/// screen by screen.
class GameExitGuard extends ConsumerWidget {
  final Widget child;

  const GameExitGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await confirmExitGame(context)) {
          ref.read(gameSessionProvider.notifier).endGame();
          if (context.mounted) context.go(RoutePaths.home);
        }
      },
      child: child,
    );
  }
}
