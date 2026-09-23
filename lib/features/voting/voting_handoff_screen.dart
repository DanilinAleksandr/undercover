import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/game_session_provider.dart';
import '../../router/route_paths.dart';
import '../../theme/app_colors.dart';
import '../../widgets/pass_device_scaffold.dart';

class VotingHandoffScreen extends ConsumerWidget {
  const VotingHandoffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(gameSessionProvider);
    if (session == null) return const SizedBox.shrink();
    final player = session.players[session.currentVotingIndex];
    final total = session.players.length;
    final position = session.currentVotingIndex + 1;

    return PassDeviceScaffold(
      eyebrow: 'Голос $position из $total',
      playerName: player.name,
      message: 'Передайте телефон этому игроку. Голос должен остаться в тайне.',
      buttonLabel: 'Это я, голосовать',
      icon: Icons.how_to_vote_rounded,
      accent: AppColors.civilianGradient,
      onConfirm: () {
        ref.read(gameSessionProvider.notifier).confirmVotingHandoff();
        context.go(RoutePaths.voting);
      },
    );
  }
}
