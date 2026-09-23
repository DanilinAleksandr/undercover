import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../logic/word_pack_selector.dart';
import '../../../models/game_mode.dart';
import '../../../router/route_paths.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimens.dart';
import '../../../theme/app_palette.dart';
import '../../../utils/plural_ru.dart';
import '../../../widgets/used_words_card.dart';

/// Live readout of what the current filter combination leaves to play with.
///
/// Sits directly above the start button because that is where the host looks
/// last: the number answers "will this even work" before the tap, and an empty
/// pool says so in words rather than failing at the first round.
class PoolReadout extends ConsumerWidget {
  final WordPoolStats pool;

  /// Which mode the numbers describe — the reset offered here must clear that
  /// mode's history and no other.
  final GameMode mode;

  /// How many words the party has spent in total — the reason the pool keeps
  /// shrinking between rounds.
  final int usedWords;

  const PoolReadout({
    super.key,
    required this.pool,
    required this.usedWords,
    required this.mode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final empty = pool.isEmpty;
    final exhausted = pool.exhaustedByHistory;
    final accent = empty ? AppColors.magenta : AppColors.gold;

    final String headline;
    if (exhausted) {
      headline = 'Все подходящие ответы режима уже использованы';
    } else if (empty) {
      headline = 'Нет подходящих пар';
    } else {
      headline = 'В пуле: ${pairsLabel(pool.total)}';
    }

    final String detail;
    // Only shown when the forecast carries information: an empty pool has a
    // better thing to say, and a huge one says nothing the pair count did not.
    String? forecast;
    if (exhausted) {
      detail = 'Смените фильтры, режим или сбросьте историю режима';
    } else if (empty) {
      detail = 'Ослабьте фильтры — тип контента, сложность или категории';
    } else {
      forecast = pool.showsForecast
          ? 'Хватит примерно на ${gamesLabel(pool.estimatedGames)}'
          : null;
      final breakdown = pool.presentDifficulties
          .map((d) => difficultyCountLabel(d, pool.countOf(d)))
          .join(' · ');
      // The history line only earns its space once something has been played.
      detail = usedWords == 0
          ? breakdown
          : '$breakdown · ${wordsLabel(usedWords)} уже использовано';
    }

    return AnimatedContainer(
      duration: Motion.fast,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      decoration: BoxDecoration(
        color: empty
            ? AppColors.magenta.withValues(alpha: 0.12)
            : palette.cardFill,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(
          color: empty ? accent.withValues(alpha: 0.6) : palette.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                exhausted
                    ? Icons.history_toggle_off_rounded
                    : (empty ? Icons.search_off_rounded : Icons.style_rounded),
                size: 18,
                color: accent,
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: TextStyle(
                        color: empty ? accent : palette.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    if (forecast != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        forecast,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: TextStyle(color: palette.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // A quiet way into the history without leaving the step; only
              // shown once there is a history to look at.
              if (usedWords > 0 && !exhausted)
                TextButton(
                  onPressed: () => context.push(RoutePaths.settings),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
                    visualDensity: VisualDensity.compact,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('История', style: TextStyle(fontSize: 12.5)),
                ),
            ],
          ),
          // The way out is offered where the dead end is discovered, but it is
          // still the same guarded reset as in the settings.
          if (exhausted)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => resetUsedWords(context, ref, mode),
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('Сбросить историю режима'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.magenta,
                  padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
