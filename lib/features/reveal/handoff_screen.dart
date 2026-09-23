import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/game_session_provider.dart';
import '../../router/route_paths.dart';
import '../../theme/app_colors.dart';
import '../../widgets/pass_device_scaffold.dart';

class HandoffScreen extends ConsumerWidget {
  const HandoffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(gameSessionProvider);
    if (session == null) return const SizedBox.shrink();
    final player = session.players[session.currentRevealIndex];
    final total = session.players.length;
    final position = session.currentRevealIndex + 1;

    return PassDeviceScaffold(
      eyebrow: 'Карта $position из $total',
      playerName: player.name,
      message: 'Передайте телефон этому игроку. Остальные не должны видеть экран.',
      buttonLabel: 'Это я, показать карту',
      icon: Icons.phonelink_lock_rounded,
      accent: AppColors.spyGradient,
      onConfirm: () {
        ref.read(gameSessionProvider.notifier).confirmHandoff();
        context.go(RoutePaths.reveal);
      },
    );
  }
}
