import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_palette.dart';
import '../theme/app_text.dart';

/// How far a surface sits above the table.
enum Depth {
  /// Barely there — grouping only, for long lists.
  flat,

  /// The default card: readable fill, hairline border, soft drop.
  raised,

  /// Reserved for the one thing the screen is about.
  lifted,
}

/// The single card shape in the app.
///
/// Instead of one flat Material `Card`, surfaces are separated by depth: fill
/// strength, border, an inner top sheen and a drop shadow all move together.
/// That layering is what stops a screen from reading as stacked grey boxes.
class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Depth depth;

  /// Tints the border and glow — use for the selected or active item only.
  final Color? accent;
  final VoidCallback? onTap;

  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Gap.lg),
    this.depth = Depth.raised,
    this.accent,
    this.onTap,
  });

  /// Kept for call sites that just want a slightly stronger card.
  const SurfaceCard.emphasised({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Gap.lg),
    this.accent,
    this.onTap,
  }) : depth = Depth.lifted;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color fill;
    final Color borderColor;
    switch (depth) {
      case Depth.flat:
        fill = palette.cardFill;
        borderColor = palette.border;
      case Depth.raised:
        fill = palette.cardFill;
        borderColor = palette.border;
      case Depth.lifted:
        fill = palette.cardFillStrong;
        borderColor = palette.borderStrong;
    }

    final resolvedBorder = accent?.withValues(alpha: 0.62) ?? borderColor;

    final card = AnimatedContainer(
      duration: Motion.fast,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: resolvedBorder, width: accent != null ? 1.4 : 1),
        boxShadow: depth == Depth.flat
            ? null
            : [
                BoxShadow(
                  color: accent?.withValues(alpha: 0.24) ??
                      Colors.black.withValues(alpha: isDark ? 0.45 : 0.10),
                  blurRadius: depth == Depth.lifted ? 26 : 16,
                  offset: Offset(0, depth == Depth.lifted ? 10 : 6),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.lg - 1),
        child: DecoratedBox(
          // Lit top edge: the cheapest way to make a surface feel physical.
          decoration: const BoxDecoration(gradient: AppColors.sheen),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.lg),
        splashColor: (accent ?? AppColors.gold).withValues(alpha: 0.08),
        highlightColor: Colors.transparent,
        child: card,
      ),
    );
  }
}

/// Small tracked label that names a section or the current phase. Optionally
/// flanked by hairlines, which reads as an engraved caption on a game box.
class Eyebrow extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? color;
  final bool ruled;

  const Eyebrow(
    this.text, {
    super.key,
    this.icon,
    this.color,
    this.ruled = false,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.palette.textMuted;
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: tint),
          const SizedBox(width: Gap.sm),
        ],
        Flexible(
          child: Text(
            text.toUpperCase(),
            textAlign: TextAlign.center,
            style: AppText.eyebrow(context, color: tint),
          ),
        ),
      ],
    );

    if (!ruled) return label;
    // The label keeps priority; the hairlines take whatever is left, so the
    // block survives being dropped into a narrow column.
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(child: _Rule(color: tint, fadeLeft: true)),
        Flexible(
          flex: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.md),
            child: label,
          ),
        ),
        Expanded(child: _Rule(color: tint)),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  final Color color;
  final bool fadeLeft;

  const _Rule({required this.color, this.fadeLeft = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: fadeLeft ? Alignment.centerLeft : Alignment.centerRight,
          end: fadeLeft ? Alignment.centerRight : Alignment.centerLeft,
          colors: [color.withValues(alpha: 0), color.withValues(alpha: 0.45)],
        ),
      ),
    );
  }
}

/// Pill used for counters and phase progress ("Голос 3 из 8").
class CountPill extends StatelessWidget {
  final String text;
  final Color accent;

  const CountPill({super.key, required this.text, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Text(
        text.toUpperCase(),
        style: AppText.eyebrow(context, color: accent),
      ),
    );
  }
}
