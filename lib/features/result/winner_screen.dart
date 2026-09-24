import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/alco_penalty.dart';
import '../../models/game_mode.dart';
import '../../models/game_result.dart';
import '../../models/game_session.dart';
import '../../providers/game_session_provider.dart';
import '../../router/route_paths.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_text.dart';
import '../../utils/plural_ru.dart';
import '../../widgets/app_button.dart';
import '../../widgets/confetti_overlay.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/surface_card.dart';
import '../../widgets/used_words_card.dart';

class WinnerScreen extends ConsumerWidget {
  const WinnerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(gameSessionProvider);
    if (session == null || session.result == null) return const SizedBox.shrink();
    final result = session.result!;
    final spyWon = result.spyWon;
    final gradient = spyWon ? AppColors.spyGradient : AppColors.civilianGradient;

    final title = spyWon ? 'Шпион победил!' : 'Мирные победили!';
    // One sentence naming the rule that decided it — the card below spells out
    // the vote and the words, so this line only has to answer "почему".
    final reason = switch (result.outcome) {
      Outcome.spyWinsByGuess =>
        'Шпиона вычислили, но он назвал ответ мирных верно',
      Outcome.civiliansWin => 'Шпиона вычислили, и ответ он не угадал',
      Outcome.spyWinsUncaught => session.voteResult?.isTie == true
          ? 'Голоса разделились — большинства не было, шпион уцелел'
          : 'Большинство выгнало мирного — шпион остался неразоблачённым',
    };

    return Scaffold(
      body: Stack(
        children: [
          GradientBackground(
            accentGlow: gradient,
            intense: true,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.lg),
                child: Column(
                  children: [
                    // The celebration scrolls if the screen is short; the two
                    // actions below stay pinned so the party can always move on.
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            const SizedBox(height: Gap.lg),
                            Eyebrow(
                              spyWon ? 'Победа шпиона' : 'Победа мирных',
                              ruled: true,
                              color: AppColors.gold,
                            ),
                            const SizedBox(height: Gap.xl),
                            // Springy entrance so the payoff lands.
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 620),
                              curve: Curves.elasticOut,
                              builder: (context, t, child) =>
                                  Transform.scale(scale: 0.6 + 0.4 * t, child: child),
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: gradient,
                                  boxShadow: [
                                    BoxShadow(
                                      color: gradient.colors.first
                                          .withValues(alpha: 0.5),
                                      blurRadius: 44,
                                      spreadRadius: 6,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  spyWon
                                      ? Icons.theater_comedy_rounded
                                      : Icons.shield_rounded,
                                  color: context.palette.onAccent,
                                  size: 56,
                                ),
                              ),
                            ),
                            const SizedBox(height: Gap.xxl),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: AppText.title(context, size: 32),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              reason,
                              textAlign: TextAlign.center,
                              style: AppText.body(context),
                            ),
                            const SizedBox(height: Gap.xl),
                            _VerdictCard(session: session, result: result),
                            if (result.penalty != null) ...[
                              const SizedBox(height: 24),
                              _PenaltyCard(
                                  penalty: result.penalty!, session: session),
                            ],
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                    // Реванш keeps the table exactly as it is — same names, new
                    // roles and a new word. Новая игра goes back to setup.
                    AppButton(
                      label: 'Реванш',
                      icon: Icons.replay_rounded,
                      gradient: gradient,
                      onPressed: () async {
                        final notifier = ref.read(gameSessionProvider.notifier);
                        if (notifier.playAgainSamePlayers()) {
                          final next = ref.read(gameSessionProvider);
                          if (next != null && context.mounted) {
                            context.go(pathForPhase(next.phase));
                          }
                          return;
                        }
                        // Nothing left under these filters. Say so and let the
                        // host choose — never quietly replay a used pair.
                        if (context.mounted) await _offerWayOut(context, ref, session);
                      },
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      'Те же игроки, новые роли и новое слово',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: context.palette.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: Gap.md),
                    AppButton(
                      label: 'Новая игра',
                      icon: Icons.tune_rounded,
                      outlined: true,
                      onPressed: () {
                        ref.read(gameSessionProvider.notifier).endGame();
                        context.go(RoutePaths.setup);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          ConfettiOverlay(primaryColor: gradient.colors.first, secondaryColor: gradient.colors.last),
        ],
      ),
    );
  }
}

/// Explains a rematch that cannot happen and offers the only two real fixes.
///
/// Resetting from here still goes through the same confirmation as in the
/// settings, and if the host confirms, the rematch it was blocking starts
/// straight away.
Future<void> _offerWayOut(
    BuildContext context, WidgetRef ref, GameSession session) async {
  final choice = await showDialog<_WayOut>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Подходящие пары закончились'),
      content: const Text(
        'В этом режиме с текущими фильтрами всё уже сыграно. Смените фильтры '
        'или сбросьте историю режима.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_WayOut.changeFilters),
          child: const Text('Изменить фильтры'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_WayOut.resetHistory),
          child: const Text('Сбросить историю режима'),
        ),
      ],
    ),
  );
  if (!context.mounted || choice == null) return;

  switch (choice) {
    case _WayOut.changeFilters:
      ref.read(gameSessionProvider.notifier).endGame();
      context.go(RoutePaths.setup);
    case _WayOut.resetHistory:
      if (!await resetUsedWords(context, ref, session.config.gameMode)) return;
      if (!context.mounted) return;
      final notifier = ref.read(gameSessionProvider.notifier);
      if (notifier.playAgainSamePlayers()) {
        final next = ref.read(gameSessionProvider);
        if (next != null && context.mounted) {
          context.go(pathForPhase(next.phase));
        }
      }
  }
}

enum _WayOut { changeFilters, resetHistory }

/// The round laid out in full: who the spy was, what the table voted, and the
/// two words side by side.
///
/// Everyone argues about this for a minute after the reveal, so the answers
/// have to be on screen — not remembered from the vote-result screen two taps
/// back.
class _VerdictCard extends StatelessWidget {
  final GameSession session;
  final GameResult result;

  const _VerdictCard({required this.session, required this.result});

  @override
  Widget build(BuildContext context) {
    final vote = session.voteResult;
    final spy = session.spyPlayer;

    final String voteLine;
    if (vote == null) {
      voteLine = 'Голосование не состоялось';
    } else if (vote.isTie || vote.majorityTargetId == null) {
      voteLine = 'Ничья — большинство ни на ком не сошлось';
    } else {
      final target = session.players
          .firstWhere((p) => p.id == vote.majorityTargetId);
      final votes = vote.tally[target.id] ?? 0;
      final who = target.id == spy.id ? 'шпион' : 'мирный';
      voteLine = 'Выгнали: ${target.name} — '
          '${pluralRu(votes, '$votes голос', '$votes голоса', '$votes голосов')} ($who)';
    }

    final String? guessLine = switch (result.outcome) {
      Outcome.spyWinsByGuess => 'Назвал ответ мирных верно',
      Outcome.civiliansWin => 'Ответ мирных назвать не смог',
      Outcome.spyWinsUncaught => null,
    };

    return SurfaceCard(
      depth: Depth.raised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VerdictRow(
            icon: Icons.theater_comedy_rounded,
            color: AppColors.magenta,
            label: 'Шпион',
            value: spy.name,
          ),
          const _VerdictDivider(),
          _VerdictRow(
            icon: Icons.how_to_vote_rounded,
            color: AppColors.gold,
            label: 'Голосование',
            value: voteLine,
            note: guessLine,
          ),
          const _VerdictDivider(),
          _VerdictRow(
            icon: Icons.menu_book_rounded,
            color: AppColors.teal,
            label: 'Ответы',
            value: 'Мирные: «${session.wordPair.civilianWord}»',
            // A blind impostor was never shown the decoy; printing it as
            // "their answer" would describe a card nobody saw.
            note: session.wordPair.gameMode == GameMode.impostor &&
                    !session.config.impostorSeesDecoy
                ? 'Самозванец темы не видел'
                : 'Шпион: «${session.wordPair.spyWord}»',
          ),
        ],
      ),
    );
  }
}

class _VerdictDivider extends StatelessWidget {
  const _VerdictDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.md),
      child: Container(height: 1, color: context.palette.border),
    );
  }
}

class _VerdictRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? note;

  const _VerdictRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: Gap.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                  height: 1.25,
                ),
              ),
              if (note != null) ...[
                const SizedBox(height: 2),
                Text(
                  note!,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PenaltyCard extends StatelessWidget {
  final AlcoPenalty penalty;
  final GameSession session;

  const _PenaltyCard({required this.penalty, required this.session});

  @override
  Widget build(BuildContext context) {
    final String text;
    if (penalty.target == PenaltyTarget.spy) {
      text = '${session.spyPlayer.name} выпивает штрафной стакан';
    } else {
      text = 'Все мирные делают по ${penalty.sips} ${penalty.sips == 1 ? "глоток" : "глотка"}';
    }
    final palette = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        gradient: AppColors.alcoGradient,
        borderRadius: BorderRadius.circular(Radii.lg),
        boxShadow: [
          BoxShadow(
            color: AppColors.amber.withValues(alpha: 0.32),
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
            child: Icon(Icons.local_bar_rounded, color: palette.onAccent, size: 20),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ШТРАФ',
                  style: TextStyle(
                    color: palette.onAccentMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(
                    color: palette.onAccent,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
