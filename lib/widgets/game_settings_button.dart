import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/route_paths.dart';
import '../theme/app_dimens.dart';
import '../theme/app_palette.dart';

/// The way into the settings from inside a running party.
///
/// It opens the same screen the home gear does, and that screen only holds
/// what a round is allowed to follow mid-game. The setup screen is not
/// reachable from here: the mode, the categories and the tiers already decided
/// which pair was dealt.
class GameSettingsButton extends StatelessWidget {
  const GameSettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: IconButton(
        key: const ValueKey('in-game-settings-gear'),
        onPressed: () => context.push(RoutePaths.settings),
        tooltip: 'Настройки игры',
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(Gap.sm),
        constraints: const BoxConstraints(),
        icon: Icon(Icons.settings_outlined,
            color: context.palette.textSecondary, size: 20),
      ),
    );
  }
}
