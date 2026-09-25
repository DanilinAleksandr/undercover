import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/word_descriptions.dart';
import '../../logic/hint_policy.dart';
import '../../models/game_mode.dart';
import '../../providers/game_session_provider.dart';
import '../../router/route_paths.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_button.dart';
import '../../widgets/card_back.dart';
import '../../widgets/flip_card.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/surface_card.dart';
import 'widgets/hint_sheet.dart';

class RevealScreen extends ConsumerStatefulWidget {
  const RevealScreen({super.key});

  @override
  ConsumerState<RevealScreen> createState() => _RevealScreenState();
}

/// How long the card must be held before the player is credited with having
/// read it. Stops a stray tap from skipping someone's word.
const _kDwell = Duration(milliseconds: 700);

class _RevealScreenState extends ConsumerState<RevealScreen>
    with SingleTickerProviderStateMixin {
  bool _flipped = false;
  bool _hasSeenEnough = false;
  Timer? _dwellTimer;
  late final AnimationController _hold;

  @override
  void initState() {
    super.initState();
    _hold = AnimationController(vsync: this, duration: _kDwell);
  }

  void _onPressStart() {
    setState(() => _flipped = true);
    _hold.forward();
    _dwellTimer?.cancel();
    _dwellTimer = Timer(_kDwell, () {
      if (!mounted) return;
      HapticFeedback.selectionClick();
      setState(() => _hasSeenEnough = true);
    });
  }

  void _onPressEnd() {
    _dwellTimer?.cancel();
    _hold.reverse();
    setState(() => _flipped = false);
  }

  @override
  void dispose() {
    _dwellTimer?.cancel();
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final session = ref.watch(gameSessionProvider);
    if (session == null) return const SizedBox.shrink();
    final player = session.players[session.currentRevealIndex];
    final isSpy = player.id == session.spyPlayerId;
    final word = isSpy
        ? session.wordPair.spyWord
        : session.wordPair.civilianWord;
    // «Самозванец» deals topics instead of words, and the table may have
    // chosen to give the impostor nothing at all. The theme is still the
    // majority's "word" and the decoy the impostor's — only the blind card
    // is new.
    final mode = session.wordPair.gameMode;
    final blindImpostor = mode == GameMode.impostor &&
        isSpy &&
        !session.config.impostorSeesDecoy;
    // Which role got which word is decided before this screen exists and is
    // not touched here. All that `showRoles` changes is whether the card is
    // allowed to say so.
    final showRoles = session.config.showRoles;
    // With roles hidden every card wears the house accent, so the colour of
    // the glow, the ring and the border carry no information either.
    final accent = showRoles
        ? (isSpy ? AppColors.spyGradient : AppColors.civilianGradient)
        : AppColors.spyGradient;
    // Only hard and expert rounds offer help, and only once the player has
    // actually looked at their card. A party that turned hints off never asks
    // the policy in the first place — the link simply does not exist.
    final hints = session.config.hintsEnabled
        ? hintsFor(word, session.wordPair.difficulty,
            mode: session.wordPair.gameMode)
        : const <String>[];
    // Who the person on a «Личности» card is. It sits behind the same quiet
    // link as a hint, not on the card: the table asked for the name to be
    // met on its own first. Unlike a hint it is offered in every tier and
    // whatever the «Подсказки» switch says — that switch does not exist in
    // this mode, and a player who does not recognise the name cannot play.
    final personLine =
        mode == GameMode.people ? descriptionFor(word, mode) : null;

    return Scaffold(
      body: GradientBackground(
        accentGlow: accent,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Gap.page,
              Gap.lg,
              Gap.page,
              Gap.lg,
            ),
            child: Column(
              children: [
                Eyebrow(
                  'Карта ${session.currentRevealIndex + 1} из ${session.players.length}',
                  ruled: true,
                ),
                const SizedBox(height: Gap.lg),
                Text(
                  player.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.playerName(context, size: 22),
                ),
                const SizedBox(height: Gap.xs),
                AnimatedSwitcher(
                  duration: Motion.fast,
                  child: Text(
                    _hasSeenEnough
                        ? 'Слово запомнено — передавайте дальше'
                        : 'Удерживай карту, чтобы увидеть слово',
                    key: ValueKey(_hasSeenEnough),
                    textAlign: TextAlign.center,
                    style: AppText.caption(context),
                  ),
                ),
                // The card scales to whatever room is left instead of using a
                // fixed size: on a 320pt phone a hard-coded card is clipped,
                // and a player who cannot read their word cannot play.
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: Gap.lg),
                      child: AspectRatio(
                        aspectRatio: 0.7,
                        child: GestureDetector(
                          key: const ValueKey('reveal-card'),
                          onLongPressStart: (_) => _onPressStart(),
                          onLongPressEnd: (_) => _onPressEnd(),
                          child: AnimatedScale(
                            scale: _flipped ? 1.02 : 1,
                            duration: Motion.base,
                            curve: Curves.easeOut,
                            child: FlipCard(
                              flipped: _flipped,
                              front: CardBack(
                                child: AnimatedBuilder(
                                  animation: _hold,
                                  builder: (context, _) => HoldProgressRing(
                                    progress: _hold.value,
                                    color: accent.colors.first,
                                    child: Icon(
                                      Icons.fingerprint_rounded,
                                      color: palette.textSecondary,
                                      size: 34,
                                    ),
                                  ),
                                ),
                              ),
                              back: blindImpostor
                                  ? _BlindImpostorFace(gradient: accent)
                                  : _CardFace(
                                      gradient: accent,
                                      role: showRoles ? isSpy : null,
                                      word: word,
                                      mode: mode,
                                      // Only the words mode prints its line
                                      // on the card; people keep theirs
                                      // behind the link below.
                                      description: mode == GameMode.people
                                          ? null
                                          : descriptionFor(word, mode),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Deliberately quiet and only after the card has been read:
                // the round is better when a player wrestles with the word
                // first, so help is offered, never pushed.
                if (_hasSeenEnough && hints.isNotEmpty)
                  HintLink(
                    onTap: () =>
                        showHintSheet(context, hints: hints, accent: accent),
                  ),
                if (_hasSeenEnough && personLine != null)
                  HintLink(
                    label: 'Кто это?',
                    onTap: () => showHintSheet(
                      context,
                      hints: [personLine],
                      accent: accent,
                      levelNames: const ['Кто это'],
                    ),
                  ),
                AppButton(
                  label: 'Я запомнил слово',
                  icon: _hasSeenEnough
                      ? Icons.check_rounded
                      : Icons.lock_outline_rounded,
                  gradient: accent,
                  onPressed: _hasSeenEnough
                      ? () {
                          final notifier = ref.read(
                            gameSessionProvider.notifier,
                          );
                          notifier.confirmReveal();
                          final next = ref.read(gameSessionProvider);
                          if (next != null) {
                            context.go(pathForPhase(next.phase));
                          }
                        }
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The revealed side.
///
/// Everything here is subordinated to the word: the role is a small sigil at
/// the top, the reminder a whisper at the bottom, and the word itself gets the
/// whole middle plus a soft halo so it reads as lit from within.
class _CardFace extends StatelessWidget {
  final Gradient gradient;

  /// True for the spy, false for a civilian — or null when the party plays
  /// with roles hidden. Null is not "civilian": nothing on the card may differ
  /// between the two, down to the width of a border.
  final bool? role;

  final String word;

  /// What was dealt: the role is called differently in «Самозванец».
  final GameMode mode;

  /// The line printed under the word, or null for none.
  final String? description;

  const _CardFace({
    required this.gradient,
    required this.role,
    required this.word,
    required this.mode,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final description = this.description;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(gradient.colors.first, AppColors.ink900, 0.28)!,
            Color.lerp(gradient.colors.last, AppColors.ink900, 0.42)!,
          ],
        ),
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: role == true ? 0.42 : 0.24),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.45),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      padding: const EdgeInsets.all(Gap.xl),
      child: Column(
        children: [
          if (role != null)
            _RoleSigil(isSpy: role!, impostor: mode == GameMode.impostor),
          const Spacer(),
          Flexible(
            flex: 8,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 30,
                    ),
                  ],
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    word,
                    textAlign: TextAlign.center,
                    style: AppText.gameWord(context, size: 44),
                  ),
                ),
              ),
            ),
          ),
          // What the word means, for the player who drew it. A round dies on
          // the spot when somebody reads «Завхоз» and has nothing to
          // associate from, so this is not a hint and follows none of their
          // rules: it ignores the tier and the «Подсказки» switch, and it is
          // printed for every word that has one — including the obvious ones,
          // because a line that appeared only on rare words would announce
          // that the word is rare.
          if (description != null) ...[
            const SizedBox(height: Gap.md),
            Text(
              description,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.onAccentMuted.withValues(alpha: 0.62),
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ],
          const Spacer(),
          Text(
            // The hidden-role line has to fit both sides equally: «Не выдай
            // себя» reads as an instruction to the spy, «Найди шпиона» to a
            // civilian, and either one would give the card away.
            role == null
                ? 'Никому не показывай'
                : (role! ? 'Не выдай себя' : 'Найди шпиона'),
            style: TextStyle(
              color: palette.onAccentMuted.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small gold-ruled chip naming the role — present, but never louder than
/// the word underneath it.
class _RoleSigil extends StatelessWidget {
  final bool isSpy;
  final bool impostor;

  const _RoleSigil({required this.isSpy, this.impostor = false});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSpy ? Icons.visibility_off_rounded : Icons.groups_rounded,
            size: 13,
            color: AppColors.gold,
          ),
          const SizedBox(width: Gap.sm),
          Text(
            isSpy ? (impostor ? 'САМОЗВАНЕЦ' : 'ШПИОН') : 'МИРНЫЙ',
            style: AppText.eyebrow(context, color: palette.onAccentMuted),
          ),
        ],
      ),
    );
  }
}

/// The card of a «Самозванец» impostor who was dealt no theme at all.
///
/// It necessarily names the role — a card with nothing on it is itself the
/// answer — so it does so plainly and tells the player what to do instead.
/// The shape, the border and the colours are the ordinary card's: across the
/// table only the text is different, and nobody else can see the text.
class _BlindImpostorFace extends StatelessWidget {
  final Gradient gradient;

  const _BlindImpostorFace({required this.gradient});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(gradient.colors.first, AppColors.ink900, 0.28)!,
            Color.lerp(gradient.colors.last, AppColors.ink900, 0.42)!,
          ],
        ),
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.24),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.45),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      padding: const EdgeInsets.all(Gap.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hearing_rounded, color: AppColors.gold, size: 40),
          const SizedBox(height: Gap.lg),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Ты — Самозванец',
              textAlign: TextAlign.center,
              style: AppText.gameWord(context, size: 30),
            ),
          ),
          const SizedBox(height: Gap.md),
          Text(
            'Темы у тебя нет. Слушай остальных, угадай её и не выдай себя',
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.onAccentMuted.withValues(alpha: 0.8),
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
