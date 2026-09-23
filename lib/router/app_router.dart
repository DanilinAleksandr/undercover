import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/discussion/association_screen.dart';
import '../features/home/home_screen.dart';
import '../features/result/spy_guess_screen.dart';
import '../features/result/vote_result_screen.dart';
import '../features/result/winner_screen.dart';
import '../features/reveal/handoff_screen.dart';
import '../features/reveal/reveal_screen.dart';
import '../features/role_intro/role_intro_screen.dart';
import '../features/rules/rules_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/setup/game_settings_screen.dart';
import '../features/setup/setup_screen.dart';
import '../features/voting/voting_handoff_screen.dart';
import '../features/voting/voting_screen.dart';
import '../providers/game_session_provider.dart';
import '../widgets/game_exit_guard.dart';
import 'route_paths.dart';

CustomTransitionPage<void> _buildPage(Widget child, GoRouterState state) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(gameSessionProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: RoutePaths.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(gameSessionProvider);
      final isGameRoute = state.matchedLocation.startsWith('/game');
      if (isGameRoute && session == null) return RoutePaths.home;
      return null;
    },
    routes: [
      GoRoute(
        path: RoutePaths.home,
        pageBuilder: (c, s) => _buildPage(const HomeScreen(), s),
      ),
      GoRoute(
        path: RoutePaths.setup,
        pageBuilder: (c, s) => _buildPage(const SetupScreen(), s),
      ),
      GoRoute(
        path: RoutePaths.partySettings,
        pageBuilder: (c, s) => _buildPage(const GameSettingsScreen(), s),
      ),
      GoRoute(
        path: RoutePaths.roleIntro,
        pageBuilder: (c, s) =>
            _buildPage(const GameExitGuard(child: RoleIntroScreen()), s),
      ),
      GoRoute(
        path: RoutePaths.handoff,
        pageBuilder: (c, s) =>
            _buildPage(const GameExitGuard(child: HandoffScreen()), s),
      ),
      GoRoute(
        path: RoutePaths.reveal,
        pageBuilder: (c, s) =>
            _buildPage(const GameExitGuard(child: RevealScreen()), s),
      ),
      GoRoute(
        path: RoutePaths.association,
        pageBuilder: (c, s) =>
            _buildPage(const GameExitGuard(child: AssociationScreen()), s),
      ),
      GoRoute(
        path: RoutePaths.votingHandoff,
        pageBuilder: (c, s) =>
            _buildPage(const GameExitGuard(child: VotingHandoffScreen()), s),
      ),
      GoRoute(
        path: RoutePaths.voting,
        pageBuilder: (c, s) =>
            _buildPage(const GameExitGuard(child: VotingScreen()), s),
      ),
      GoRoute(
        path: RoutePaths.voteResult,
        pageBuilder: (c, s) =>
            _buildPage(const GameExitGuard(child: VoteResultScreen()), s),
      ),
      GoRoute(
        path: RoutePaths.spyGuess,
        pageBuilder: (c, s) =>
            _buildPage(const GameExitGuard(child: SpyGuessScreen()), s),
      ),
      GoRoute(
        path: RoutePaths.winner,
        pageBuilder: (c, s) =>
            _buildPage(const GameExitGuard(child: WinnerScreen()), s),
      ),
      GoRoute(
        path: RoutePaths.settings,
        pageBuilder: (c, s) => _buildPage(const SettingsScreen(), s),
      ),
      GoRoute(
        path: RoutePaths.rules,
        pageBuilder: (c, s) => _buildPage(const RulesScreen(), s),
      ),
    ],
  );
});
