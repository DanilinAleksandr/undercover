import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/game_setup_provider.dart';
import '../../providers/last_roster_provider.dart';
import '../../router/route_paths.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../widgets/app_button.dart';
import '../../widgets/gradient_background.dart';
import 'widgets/player_names_step.dart';

/// Step one of two: who is playing, and nothing else.
///
/// The line-up is the only part of a setup that changes every evening, so it
/// gets a screen to itself. What the party is dealt from waits behind «Далее»;
/// how it is played waits in the in-game settings. Neither belongs in a list
/// of names.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  late List<TextEditingController> _nameControllers;

  /// The remembered line-up is offered once, and only into an untouched setup.
  bool _rosterHandled = false;

  @override
  void initState() {
    super.initState();
    final config = ref.read(gameSetupProvider);
    _nameControllers =
        config.playerNames.map((n) => TextEditingController(text: n)).toList();
  }

  @override
  void dispose() {
    for (final c in _nameControllers) {
      c.dispose();
    }
    super.dispose();
  }

  /// Keeps the number of controllers in step with the number of seats.
  ///
  /// Length only: writing into a controller notifies its listeners, which must
  /// never happen while the tree is building.
  void _syncNameControllerCount(int count) {
    while (_nameControllers.length < count) {
      _nameControllers.add(TextEditingController());
    }
    while (_nameControllers.length > count) {
      _nameControllers.removeLast().dispose();
    }
  }

  /// Applies the last party's line-up, unless the host has already started
  /// typing this time round.
  void _maybeRestoreRoster(List<String> roster) {
    if (_rosterHandled || roster.isEmpty) return;
    _rosterHandled = true;
    final current = ref.read(gameSetupProvider).playerNames;
    if (current.any((n) => n.trim().isNotEmpty)) return;
    // After the frame: setRoster changes the seat count and the fields get
    // their text, neither of which may happen mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(gameSetupProvider.notifier).setRoster(roster);
      final names = ref.read(gameSetupProvider).playerNames;
      setState(() {
        _syncNameControllerCount(names.length);
        for (var i = 0; i < names.length; i++) {
          _nameControllers[i].text = names[i];
        }
      });
    });
  }

  void _removePlayer(int index) {
    if (ref.read(gameSetupProvider).playerNames.length <= kMinPlayers) return;
    setState(() {
      _nameControllers.removeAt(index).dispose();
    });
    ref.read(gameSetupProvider.notifier).removePlayerAt(index);
  }

  void _forgetSavedRoster() {
    ref.read(lastRosterProvider.notifier).clear();
    ref.read(gameSetupProvider.notifier).setRoster(const []);
    setState(() {
      for (final controller in _nameControllers) {
        controller.clear();
      }
    });
  }

  /// Moving on confirms the line-up, and is the only moment it is written
  /// down — a name typed and then abandoned never becomes the saved roster.
  void _next() {
    ref
        .read(lastRosterProvider.notifier)
        .remember(ref.read(gameSetupProvider).playerNames);
    context.push(RoutePaths.partySettings);
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(gameSetupProvider);
    final notifier = ref.read(gameSetupProvider.notifier);
    final savedRoster = ref.watch(lastRosterProvider);
    _maybeRestoreRoster(savedRoster);
    _syncNameControllerCount(config.playerNames.length);

    return Scaffold(
      body: GradientBackground(
        accentGlow: AppColors.spyGradient,
        child: SafeArea(
          child: Column(
            children: [
              SetupStepHeader(
                step: 0,
                onBack: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    // Reached setup straight from the winner screen, so there
                    // is no entry below it on the stack to pop back to.
                    context.go(RoutePaths.home);
                  }
                },
              ),
              Expanded(
                child: PlayerNamesStep(
                  controllers: _nameControllers,
                  onChanged: notifier.setPlayerName,
                  onAdd: notifier.addPlayer,
                  onRemove: _removePlayer,
                  onForgetSaved:
                      savedRoster.isEmpty ? null : _forgetSavedRoster,
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.lg),
                child: AppButton(
                  label: 'Далее',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: notifier.isValid ? _next : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Back arrow and the two dots, shared by both steps so the progress reads the
/// same whichever screen the host is on.
class SetupStepHeader extends StatelessWidget {
  final int step;
  final VoidCallback onBack;

  const SetupStepHeader({super.key, required this.step, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: 'Назад',
            icon: Icon(Icons.arrow_back_ios_new,
                color: context.palette.textSecondary, size: 18),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(2, (i) {
                final done = i < step;
                final active = i == step;
                return AnimatedContainer(
                  duration: Motion.base,
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 28 : 16,
                  height: 5,
                  decoration: BoxDecoration(
                    gradient: active ? AppColors.spyGradient : null,
                    color: active
                        ? null
                        : (done
                            ? AppColors.violet.withValues(alpha: 0.55)
                            : context.palette.cardFillStrong),
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}
