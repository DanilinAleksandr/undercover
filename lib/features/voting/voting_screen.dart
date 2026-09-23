import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
                  session.config.fastVoting
                      ? 'Голос $position из ${session.players.length}'
                      : 'Тайное голосование',
                  ruled: true,
                ),
                const SizedBox(height: Gap.lg),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${voter.name}, кто шпион?',
                    style: AppText.title(context, size: 25),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: Gap.xs),
                AnimatedSwitcher(
                  duration: Motion.fast,
                  child: Text(
                    _selected == null
                        ? 'Выберите одного игрока'
                        : 'Решение принято — подтвердите',
                    key: ValueKey(_selected == null),
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
                      final isSelf = p.id == voter.id;
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
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
