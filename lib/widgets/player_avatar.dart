import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_palette.dart';

/// A player's token — the game piece that represents them all evening.
///
/// Built like a physical counter rather than a Material avatar: a dark inset
/// disc, a coloured rim that identifies the person, a light sheen across the
/// top and their initials struck into the middle. The colour is derived from
/// the name, so the same person keeps the same token every round.
class PlayerAvatar extends StatelessWidget {
  final String name;
  final double size;

  /// Dimmed: still in the game, but not what the screen is about.
  final bool disabled;

  /// The token the screen is currently about — gains a gold rim and glow.
  final bool highlighted;

  const PlayerAvatar({
    super.key,
    required this.name,
    this.size = 56,
    this.disabled = false,
    this.highlighted = false,
  });

  static const _rims = [
    Color(0xFF9B3350),
    Color(0xFF6A3A9E),
    Color(0xFF1F7A80),
    Color(0xFF37599E),
    Color(0xFFB4813A),
    Color(0xFF3F7A52),
    Color(0xFF8E4A2E),
    Color(0xFF4A5C9E),
  ];

  Color get _rim {
    final hash = name.codeUnits.fold<int>(7, (a, b) => a * 31 + b);
    return _rims[hash.abs() % _rims.length];
  }

  String get _initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts[0].characters.first + parts[1].characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final rim = _rim;
    final ringColor = highlighted
        ? AppColors.gold
        : (disabled ? rim.withValues(alpha: 0.30) : rim);
    final ringWidth = size * (highlighted ? 0.075 : 0.055);

    return AnimatedContainer(
      duration: Motion.base,
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: ringWidth),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(AppColors.ink600, rim, disabled ? 0.10 : 0.34)!,
            Color.lerp(AppColors.ink900, rim, disabled ? 0.04 : 0.16)!,
          ],
        ),
        boxShadow: [
          if (highlighted)
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.34),
              blurRadius: size * 0.34,
              spreadRadius: 1,
            )
          else if (!disabled)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.42),
              blurRadius: size * 0.14,
              offset: Offset(0, size * 0.05),
            ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: disabled
              ? palette.textMuted
              : palette.textPrimary.withValues(alpha: 0.94),
          fontWeight: FontWeight.w800,
          fontSize: size * 0.34,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
