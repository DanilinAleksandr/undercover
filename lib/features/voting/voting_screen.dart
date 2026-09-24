import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/game_session.dart';
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

class VotingScreen extends ConsumerStatefulWidget {
  const VotingScreen({super.key});

  @override
  ConsumerState<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends ConsumerState<VotingScreen> {
  String? _selected;

  /// Whose choice [_selected] belongs to.
  ///
  /// In a fast vote this screen is not rebuilt from scratch between voters —
  /// there is no hand-off screen in between to unmount it — so the previous
  /// player's pick would otherwise still be sitting there, highlighted, when
  /// the phone reaches the next one.
  int? _selectionOwner;

  /// The table is choosing together instead of voting one by one.
  bool _unanimous = false;

  /// Warns, then hands the table's single choice to the session.
  ///
  /// The warning is not ceremony: this path skips every individual ballot and
  /// goes straight to the result, so a mistap here ends the round for
  /// everyone.
  Future<void> _castUnanimous(GameSession session) async {
    final target =
        session.players.firstWhere((p) => p.id == _selected).name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выбрать единогласно?'),
        content: Text(
          'Тайное голосование не состоится — $target сразу станет выбором '
          'всего стола. Отменить это будет нельзя.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Да, выбрать'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    ref.read(gameSessionProvider.notifier).castUnanimousVote(_selected!);
    final next = ref.read(gameSessionProvider);
    if (next != null && mounted) context.go(pathForPhase(next.phase));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final session = ref.watch(gameSessionProvider);
    if (session == null) return const SizedBox.shrink();
    final voter = session.players[session.currentVotingIndex];
    if (_selectionOwner != session.currentVotingIndex) {
      _selectionOwner = session.currentVotingIndex;
      _selected = null;
    }
    final position = session.currentVotingIndex + 1;
    // Only before the first ballot. Once part of the table has voted in
    // secret, "everyone agrees" is no longer a true statement about the room.
    final canGoUnanimous =
        session.currentVotingIndex == 0 && session.votes.isEmpty;
    if (_unanimous && !canGoUnanimous) _unanimous = false;

    return Scaffold(
      body: GradientBackground(
        accentGlow: AppColors.spyGradient,
        intense: true,
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
                  // Without the hand-off screen this line carries the only
                  // "whose turn is it" information the table gets.
                  _unanimous
                      ? 'Решение стола'
                      : (session.config.fastVoting
                            ? 'Голос $position из ${session.players.length}'
                            : 'Тайное голосование'),
                  ruled: true,
                ),
                const SizedBox(height: Gap.lg),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    // Nobody's turn any more — the room answers as one.
                    _unanimous ? 'Кто шпион?' : '${voter.name}, кто шпион?',
                    style: AppText.title(context, size: 25),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: Gap.xs),
                AnimatedSwitcher(
                  duration: Motion.fast,
                  child: Text(
                    _unanimous
                        ? (_selected == null
                              ? 'Выбирайте вслух, все вместе'
                              : 'Выбор стола — подтвердите')
                        : (_selected == null
                              ? 'Выберите одного игрока'
                              : 'Решение принято — подтвердите'),
                    key: ValueKey('$_unanimous/${_selected == null}'),
                    style: AppText.caption(context),
                  ),
                ),
                const SizedBox(height: Gap.xl),
                Expanded(
                  child: GridView.builder(
                    // Every candidate has to be on screen at once. With a
                    // full table a 3-wide grid pushes the last row out of
                    // sight, and a voter who never scrolls cannot vote for
                    // those players at all.
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: session.players.length <= 6 ? 3 : 4,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: session.players.length,
                    itemBuilder: (context, index) {
                      final p = session.players[index];
                      // In a unanimous choice there is no voter to exclude:
                      // the table picks together, and the player whose formal
                      // turn it is can be the one they pick.
                      final isSelf = !_unanimous && p.id == voter.id;
                      final isSelected = _selected == p.id;
                      return GestureDetector(
                        onTap: isSelf
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                setState(() => _selected = p.id);
                              },
                        behavior: HitTestBehavior.opaque,
                        // Scale the whole cell down rather than clip it: on a
                        // 320pt screen a full-size avatar plus a long name
                        // does not fit the grid cell.
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  AnimatedScale(
                                    scale: isSelected ? 1.10 : 1,
                                    duration: Motion.base,
                                    curve: Curves.easeOutBack,
                                    child: AnimatedOpacity(
                                      duration: Motion.fast,
                                      // Everyone else steps back once a
                                      // choice is on the table.
                                      opacity: isSelf
                                          ? 1
                                          : (_selected == null || isSelected
                                                ? 1
                                                : 0.42),
                                      child: PlayerAvatar(
                                        name: p.name,
                                        size: 64,
                                        disabled: isSelf,
                                        highlighted: isSelected,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.gold,
                                        border: Border.all(
                                          color: palette.cardBack,
                                          width: 2,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.check_rounded,
                                        size: 13,
                                        color: palette.onAccent,
                                      ),
                                    ),
                                  if (isSelf)
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: palette.cardFillStrong,
                                      ),
                                      child: Icon(
                                        Icons.person_rounded,
                                        size: 13,
                                        color: palette.textMuted,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: Gap.sm),
                              SizedBox(
                                width: 88,
                                child: Text(
                                  p.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isSelf
                                        ? palette.textMuted
                                        : (isSelected
                                              ? AppColors.gold
                                              : palette.textSecondary),
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_unanimous) ...[
                  AppButton(
                    label: 'Выбрать единогласно',
                    icon: Icons.groups_rounded,
                    // Deliberately not the spy gradient of «Подтвердить
                    // голос»: this button skips the whole vote and cannot be
                    // taken back, so it must not look like the one next to it.
                    gradient: AppColors.civilianGradient,
                    onPressed:
                        _selected == null ? null : () => _castUnanimous(session),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _unanimous = false;
                      _selected = null;
                    }),
                    child: const Text('Вернуться к голосованию'),
                  ),
                ] else ...[
                  AppButton(
                    label: 'Подтвердить голос',
                    icon: Icons.how_to_vote_rounded,
                    gradient: AppColors.spyGradient,
                    onPressed: _selected == null
                        ? null
                        : () {
                            ref
                                .read(gameSessionProvider.notifier)
                                .castVote(_selected!);
                            final next = ref.read(gameSessionProvider);
                            setState(() {
                              _selected = null;
                              _selectionOwner = next?.currentVotingIndex;
                            });
                            if (next != null) {
                              context.go(pathForPhase(next.phase));
                            }
                          },
                  ),
                  if (canGoUnanimous)
                    TextButton(
                      onPressed: () => setState(() {
                        _unanimous = true;
                        _selected = null;
                      }),
                      child: const Text('Все и так согласны'),
                    ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
