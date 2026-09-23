import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/game_mode.dart';
import '../../../providers/game_session_provider.dart';
import '../../../providers/game_setup_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimens.dart';
import '../../../theme/app_palette.dart';

/// The five settings that change how a party is played rather than what it is
/// played with.
///
/// They live here, next to the theme and the played history, because they are
/// the ones a table changes with the game already on the table: somebody wants
/// the alco rule after all, the hints turned out to be too generous, the phone
/// is going round too slowly. The pool-shaping settings — mode, categories,
/// tiers, the words/phrases split — stay in the second setup step, since
/// changing them describes a round that was never dealt.
///
/// Each toggle writes twice, and the two writes mean different things. The
/// preference is what the host wants next time and is what gets persisted; the
/// running round, if there is one, follows along immediately.
class GameTogglesCard extends ConsumerWidget {
  const GameTogglesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(gameSetupProvider);
    final notifier = ref.read(gameSetupProvider.notifier);
    // A round in progress was dealt in one mode; hints exist only in words, so
    // that is the mode whose round may offer them.
    final session = ref.watch(gameSessionProvider);
    final mode = session?.config.gameMode ?? config.gameMode;

    void set(void Function(bool) apply, bool value) {
      apply(value);
      ref.read(gameSessionProvider.notifier).syncLiveSettings(
          ref.read(gameSetupProvider));
    }

    return Column(
      children: [
        _ToggleTile(
          icon: Icons.local_bar,
          gradient: AppColors.alcoGradient,
          title: 'Алко-режим',
          subtitle: 'Проигравшие делают глоток',
          value: config.alcoModeEnabled,
          onChanged: (v) => set(notifier.setAlcoMode, v),
        ),
        const SizedBox(height: Gap.md),
        _ToggleTile(
          icon: Icons.local_fire_department,
          gradient: AppColors.spyGradient,
          title: 'Контент 18+',
          subtitle: 'Пороки, ночная жизнь, табу',
          value: config.allowAdultContent,
          onChanged: (v) => set(notifier.setAllowAdultContent, v),
        ),
        // Hints are authored per word; personalities and places have none, so
        // the switch is not offered where it would promise help that cannot
        // arrive.
        if (mode == GameMode.words) ...[
          const SizedBox(height: Gap.md),
          _ToggleTile(
            icon: Icons.lightbulb_outline_rounded,
            gradient: AppColors.civilianGradient,
            title: 'Подсказки',
            subtitle: 'Помощь на сложных словах',
            value: config.hintsEnabled,
            onChanged: (v) => set(notifier.setHintsEnabled, v),
          ),
        ],
        const SizedBox(height: Gap.md),
        _ToggleTile(
          icon: Icons.badge_outlined,
          gradient: AppColors.civilianGradient,
          title: 'Показывать роль',
          subtitle: 'Показывать игроку, является ли он шпионом',
          value: config.showRoles,
          onChanged: (v) => set(notifier.setShowRoles, v),
        ),
        const SizedBox(height: Gap.md),
        _ToggleTile(
          icon: Icons.bolt_rounded,
          gradient: AppColors.civilianGradient,
          title: 'Быстрые ответы',
          subtitle: 'Сразу к выбору игрока, без экранов передачи',
          value: config.fastVoting,
          onChanged: (v) => set(notifier.setFastVoting, v),
        ),
      ],
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final Gradient gradient;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.gradient,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: value ? palette.cardFillStrong : palette.cardFill,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(
          color: value
              ? gradient.colors.first.withValues(alpha: 0.5)
              : palette.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration:
                BoxDecoration(shape: BoxShape.circle, gradient: gradient),
            child: Icon(icon, color: palette.onAccent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: palette.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: gradient.colors.first,
          ),
        ],
      ),
    );
  }
}
