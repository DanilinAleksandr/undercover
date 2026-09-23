import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../logic/word_pack_selector.dart';
import '../../models/content_type.dart';
import '../../models/difficulty.dart';
import '../../models/game_mode.dart';
import '../../providers/game_session_provider.dart';
import '../../providers/game_setup_provider.dart';
import '../../providers/last_roster_provider.dart';
import '../../providers/used_entries_provider.dart';
import '../../providers/word_pack_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../widgets/app_button.dart';
import '../../router/route_paths.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/surface_card.dart';
import 'setup_screen.dart';
import 'widgets/pool_readout.dart';

/// Step two of two: what the next party will be dealt from.
///
/// The mode, the categories, the tiers and the words/phrases split — every one
/// of them decides which pairs can come up, which is why they are settled
/// before a pair is drawn and are gone from the app once one has been. How the
/// party is *played* — alco, 18+, hints, roles, pace — lives in the in-game
/// settings instead, where the table can still change its mind.
///
/// Reached from the gear on the setup screen and nowhere else: once a round is
/// running the config is fixed, so there is no route into here from inside the
/// game. The screen reads and writes the setup provider directly — the values
/// outlive the screen, and a settings sheet that owned them would lose them
/// the moment it closed.
class GameSettingsScreen extends ConsumerWidget {
  const GameSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(gameSetupProvider);
    final notifier = ref.read(gameSetupProvider.notifier);
    final pack = ref.watch(wordPackProvider);
    final categories = visibleCategories(
      pack,
      allowAdultContent: config.allowAdultContent,
    ).where((c) => c.pairs.any((p) => p.gameMode == config.gameMode)).toList();
    final mode = config.gameMode;
    // Each mode keeps its own played history, so the counter below is about
    // this mode and nothing else.
    final usedWords = ref.watch(usedEntriesProvider)[mode] ?? const <String>{};
    // Recomputed on every build, so any chip tap updates the number in the
    // same frame. Counting ~900 const pairs is far cheaper than the rebuild
    // that surrounds it.
    final pool = poolStats(
      pack,
      gameMode: mode,
      selectedCategoryIds: config.selectedCategoryIds,
      selectedContentTypes: config.selectedContentTypes,
      selectedDifficulties: config.selectedDifficulties,
      allowAdultContent: config.allowAdultContent,
      usedWordKeys: usedWords,
    );
    final content = Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.lg),
            children: [
              const Eyebrow('Шаг 2 из 2', icon: Icons.tune_rounded),
              const SizedBox(height: Gap.md),
              Text(
                'Настройки партии',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 26),
              ),
              const SizedBox(height: Gap.xl),
              _SectionTitle(
                title: 'Режим игры',
                hint: 'Во что играет компания — выбирается один',
              ),
              const SizedBox(height: Gap.md),
              Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                children: [
                  for (final option in GameMode.values)
                    _Chip(
                      label: option.label,
                      icon: _modeIcon(option),
                      selected: mode == option,
                      color: AppColors.violet,
                      onTap: () => notifier.setGameMode(option),
                    ),
                ],
              ),
              const SizedBox(height: Gap.xs),
              Text(
                mode.hint,
                style: TextStyle(color: context.palette.textMuted, fontSize: 12),
              ),
              const SizedBox(height: Gap.xxl),
              const SizedBox(height: Gap.xxl),
              // Words and phrases only exist inside the words mode; the other
              // two have no such distinction, so the row is simply absent.
              if (mode == GameMode.words) ...[
                _SectionTitle(
                  title: 'Тип контента',
                  hint: 'Ничего не выбрано — слова и фразы вместе',
                ),
                const SizedBox(height: Gap.md),
                Wrap(
                  spacing: Gap.sm,
                  runSpacing: Gap.sm,
                  children: [
                    _Chip(
                      label: 'Всё',
                      icon: Icons.all_inclusive_rounded,
                      selected: config.selectedContentTypes.isEmpty,
                      color: AppColors.gold,
                      onTap: notifier.clearContentTypes,
                    ),
                    for (final type in ContentType.values)
                      _Chip(
                        label: type.label,
                        icon: _contentIcon(type),
                        selected: config.selectedContentTypes.contains(type),
                        color: AppColors.gold,
                        onTap: () => notifier.toggleContentType(type),
                      ),
                  ],
                ),
                const SizedBox(height: Gap.xxl),
              ],
              const SizedBox(height: Gap.xxl),
              _SectionTitle(
                title: 'Сложность',
                hint: 'Ничего не выбрано — любая сложность',
              ),
              const SizedBox(height: Gap.md),
              Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                children: Difficulty.values.map((level) {
                  final selected = config.selectedDifficulties.contains(level);
                  return _Chip(
                    label: level.label,
                    selected: selected,
                    color: _difficultyColor(level),
                    onTap: () => notifier.toggleDifficulty(level),
                  );
                }).toList(),
              ),
              const SizedBox(height: Gap.xxl),
              _SectionTitle(
                title: 'Категории',
                hint: 'Ничего не выбрано — используются все',
              ),
              const SizedBox(height: Gap.md),
              Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                children: categories.map((cat) {
                  final selected = config.selectedCategoryIds.contains(cat.id);
                  return _Chip(
                    label: cat.name,
                    icon: cat.icon,
                    selected: selected,
                    color: cat.isAdult ? AppColors.magenta : AppColors.violet,
                    onTap: () => notifier.toggleCategory(cat.id),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PoolReadout(
                  pool: pool, usedWords: usedWords.length, mode: mode),
              const SizedBox(height: Gap.md),
              AppButton(
                label: 'Начать игру',
                icon: Icons.play_arrow_rounded,
                onPressed: pool.isEmpty
                    ? null
                    : () {
                        // The button is disabled on an empty pool, so this can
                        // only fail if the history changed underneath us —
                        // stay put rather than open an empty round.
                        if (ref
                            .read(gameSessionProvider.notifier)
                            .startGame(config)) {
                          ref
                              .read(lastRosterProvider.notifier)
                              .remember(config.playerNames);
                          context.go(RoutePaths.roleIntro);
                        }
                      },
              ),
            ],
          ),
        ),
      ],
    );
    return Scaffold(
      body: GradientBackground(
        accentGlow: AppColors.spyGradient,
        child: SafeArea(
          child: Column(
            children: [
              SetupStepHeader(step: 1, onBack: () => context.pop()),
              Expanded(child: content),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _contentIcon(ContentType type) {
    switch (type) {
      case ContentType.words:
        return Icons.abc_rounded;
      case ContentType.phrases:
        return Icons.format_quote_rounded;
    }
  }

  static IconData _modeIcon(GameMode mode) {
    switch (mode) {
      case GameMode.words:
        return Icons.abc_rounded;
      case GameMode.people:
        return Icons.person_outline_rounded;
      case GameMode.places:
        return Icons.place_outlined;
    }
  }

  static Color _difficultyColor(Difficulty level) {
    switch (level) {
      case Difficulty.easy:
        return AppColors.teal;
      case Difficulty.medium:
        return AppColors.blue;
      case Difficulty.hard:
        return AppColors.violet;
      case Difficulty.expert:
        return AppColors.magenta;
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String hint;

  const _SectionTitle({required this.title, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: Gap.xs),
        Text(hint,
            style: TextStyle(color: context.palette.textMuted, fontSize: 12)),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.22)
              : context.palette.cardFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : context.palette.border,
            width: 1.4,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 16,
                  color: selected ? color : context.palette.textSecondary),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? context.palette.textPrimary
                    : context.palette.textSecondary,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
