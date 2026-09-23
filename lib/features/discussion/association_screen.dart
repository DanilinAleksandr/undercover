import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/game_session_provider.dart';
import '../../router/route_paths.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_button.dart';
import '../../widgets/game_settings_button.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/surface_card.dart';

/// The whole talking part of a round, in one screen.
///
/// The app deliberately does not run the circle: how many rounds of
/// associations to play, who starts, in what order and when to stop are table
/// decisions, and enforcing them on a shared phone only slowed the game down.
/// The single job left here is to hand the phone over to secret voting when
/// the table says so.
class AssociationScreen extends ConsumerWidget {
  const AssociationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final session = ref.watch(gameSessionProvider);
    if (session == null) return const SizedBox.shrink();
    const accent = AppColors.civilianGradient;

    return Scaffold(
      body: GradientBackground(
        accentGlow: accent,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.lg),
            child: Column(
              children: [
                const GameSettingsButton(),
                const Eyebrow('Время обсуждения', ruled: true),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: Gap.xxl),
                        Container(
                          width: 96,
                          height: 96,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: accent,
                          ),
                          child: Icon(Icons.forum_rounded,
                              color: palette.onAccent, size: 42),
                        ),
                        const SizedBox(height: Gap.xl),
                        Text(
                          'Ассоциации — в любом порядке',
                          textAlign: TextAlign.center,
                          style: AppText.title(context, size: 26),
                        ),
                        const SizedBox(height: Gap.sm),
                        Text(
                          'Все карты просмотрены. Обсудите столько кругов, '
                          'сколько хотите — приложение не торопит и ничего '
                          'не записывает.',
                          textAlign: TextAlign.center,
                          style: AppText.body(context),
                        ),
                        const SizedBox(height: Gap.xl),
                        const _HouseRules(),
                        const SizedBox(height: Gap.lg),
                      ],
                    ),
                  ),
                ),
                AppButton(
                  label: 'Готовы голосовать',
                  icon: Icons.how_to_vote_rounded,
                  gradient: accent,
                  onPressed: () {
                    ref.read(gameSessionProvider.notifier).startVoting();
                    // Where the vote begins is the state machine's call: the
                    // hand-off screen, or the ballot itself in a fast vote.
                    final next = ref.read(gameSessionProvider);
                    if (next != null) context.go(pathForPhase(next.phase));
                  },
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  'Голосование тайное — телефон пойдёт по кругу',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What the table decides for itself — spelled out so nobody waits for the
/// phone to tell them whose turn it is.
class _HouseRules extends StatelessWidget {
  const _HouseRules();

  @override
  Widget build(BuildContext context) {
    const lines = [
      (Icons.record_voice_over_rounded, 'Кто говорит первым и в каком порядке'),
      (Icons.repeat_rounded, 'Сколько кругов ассоциаций сыграть'),
      (Icons.timer_off_rounded, 'Когда закончить и перейти к голосованию'),
    ];
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Решаете вы, не приложение', style: AppText.caption(context)),
          const SizedBox(height: Gap.md),
          for (final (icon, text) in lines) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: AppColors.gold),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Text(
                    text,
                    style: AppText.body(context).copyWith(fontSize: 13.5),
                  ),
                ),
              ],
            ),
            if (text != lines.last.$2) const SizedBox(height: Gap.md),
          ],
        ],
      ),
    );
  }
}
