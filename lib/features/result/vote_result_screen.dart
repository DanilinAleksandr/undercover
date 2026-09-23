import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/player.dart';
import '../../providers/game_session_provider.dart';
import '../../router/route_paths.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_button.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/player_avatar.dart';
import '../../widgets/surface_card.dart';

class VoteResultScreen extends ConsumerWidget {
  const VoteResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(gameSessionProvider);
    if (session == null || session.voteResult == null) return const SizedBox.shrink();
    final result = session.voteResult!;
    final maxVotes = result.tally.values.isEmpty
        ? 0
        : result.tally.values.reduce((a, b) => a > b ? a : b);

    Player? majority;
    if (result.majorityTargetId != null) {
      majority = session.players.firstWhere((p) => p.id == result.majorityTargetId);
    }

    return Scaffold(
      body: GradientBackground(
        accentGlow:
            result.spyWasCaught ? AppColors.civilianGradient : AppColors.spyGradient,
        intense: true,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.lg),
            child: Column(
              children: [
                const Eyebrow('Итоги раунда', ruled: true),
                const SizedBox(height: Gap.lg),
                Text(
                  'Результаты голосования',
                  style: AppText.title(context, size: 24),
                ),
                const SizedBox(height: Gap.lg),
                Expanded(
                  child: ListView.separated(
                    itemCount: session.players.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: Gap.sm + 2),
                    itemBuilder: (context, index) {
                      final p = session.players[index];
                      final votes = result.tally[p.id] ?? 0;
                      final fraction = maxVotes == 0 ? 0.0 : votes / maxVotes;
                      return _TallyRow(
                        name: p.name,
                        votes: votes,
                        fraction: fraction,
                        isMajority: p.id == result.majorityTargetId,
                      );
                    },
                  ),
                ),
                const SizedBox(height: Gap.md),
                if (result.isTie)
                  const _ResultBanner(
                    icon: Icons.balance_rounded,
                    title: 'Ничья!',
                    subtitle: 'Большинства нет — шпион не пойман',
                    gradient: AppColors.spyGradient,
                  )
                else if (majority != null)
                  _ResultBanner(
                    icon: result.spyWasCaught ? Icons.visibility_rounded : Icons.error_outline_rounded,
                    title: result.spyWasCaught
                        ? '${majority.name} — ШПИОН!'
                        : '${majority.name} оказался мирным',
                    subtitle: result.spyWasCaught ? 'Большинство угадало верно' : 'Большинство ошиблось',
                    gradient: result.spyWasCaught ? AppColors.civilianGradient : AppColors.spyGradient,
                  ),
                const SizedBox(height: Gap.lg),
                AppButton(
                  label: 'Продолжить',
                  icon: Icons.arrow_forward_rounded,
                  gradient: result.spyWasCaught ? AppColors.civilianGradient : AppColors.spyGradient,
                  onPressed: () {
                    ref.read(gameSessionProvider.notifier).proceedFromVoteResult();
                    final next = ref.read(gameSessionProvider);
                    if (next != null) context.go(pathForPhase(next.phase));
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TallyRow extends StatelessWidget {
  final String name;
  final int votes;
  final double fraction;
  final bool isMajority;

  const _TallyRow({
    required this.name,
    required this.votes,
    required this.fraction,
    required this.isMajority,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final barColor = isMajority ? AppColors.gold : AppColors.plum;
    // Players nobody suspected fade back; the accused holds the eye.
    return Opacity(
      opacity: votes == 0 && !isMajority ? 0.5 : 1,
      child: Row(
      children: [
        PlayerAvatar(name: name, size: 34, highlighted: isMajority),
        const SizedBox(width: Gap.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isMajority ? palette.textPrimary : palette.textSecondary,
                  fontSize: 13.5,
                  fontWeight: isMajority ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: Gap.xs + 1),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fraction),
                duration: Motion.slow,
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.pill),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 10,
                      backgroundColor: palette.cardFillStrong,
                      valueColor: AlwaysStoppedAnimation(barColor),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: Gap.md),
        SizedBox(
          width: 24,
          child: Text(
            '$votes',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: isMajority ? AppColors.gold : palette.textSecondary,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ),
      ],
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;

  const _ResultBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.slow,
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.scale(
        scale: 0.94 + 0.06 * t,
        child: Opacity(opacity: t.clamp(0, 1), child: child),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(Radii.lg),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withValues(alpha: 0.35),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(Gap.sm),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.18),
              ),
              child: Icon(icon, color: palette.onAccent, size: 22),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: palette.onAccent,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: palette.onAccentMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
