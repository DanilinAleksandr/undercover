import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_palette.dart';

/// Primary action button.
///
/// Every screen ends with one of these, so it carries the app's tactility:
/// it dips and dims under the finger, gives a light haptic tick, and reads as
/// clearly unavailable when the step is not finished yet.
class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Gradient gradient;
  final IconData? icon;
  final bool expand;
  final bool outlined;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.gradient = AppColors.spyGradient,
    this.icon,
    this.expand = true,
    this.outlined = false,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onPressed == null) return;
    setState(() => _pressed = value);
  }

  void _handleTap() {
    if (widget.onPressed == null) return;
    HapticFeedback.lightImpact();
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = widget.onPressed != null;
    final accent = widget.gradient.colors.first;

    final Color labelColor;
    if (!enabled) {
      labelColor = palette.textMuted;
    } else if (widget.outlined) {
      labelColor = palette.textPrimary;
    } else {
      labelColor = palette.onAccent;
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        onTap: _handleTap,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: Motion.fast,
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: Motion.fast,
            width: widget.expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(vertical: 17, horizontal: Gap.xxl),
            decoration: BoxDecoration(
              gradient: widget.outlined || !enabled ? null : widget.gradient,
              color: widget.outlined
                  ? (_pressed ? palette.cardFillStrong : palette.cardFill)
                  : (enabled ? null : palette.cardFill),
              border: Border.all(
                color: widget.outlined
                    ? (_pressed
                        ? AppColors.gold.withValues(alpha: 0.55)
                        : palette.borderStrong)
                    : (enabled
                        ? Colors.white.withValues(alpha: 0.14)
                        : palette.border),
                width: 1.2,
              ),
              borderRadius: BorderRadius.circular(Radii.lg),
              boxShadow: enabled && !widget.outlined && !_pressed
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.42),
                        blurRadius: 26,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            // Lit top edge, so the button reads as a moulded piece rather
            // than a painted rectangle.
            foregroundDecoration: enabled && !widget.outlined
                ? BoxDecoration(
                    gradient: AppColors.sheen,
                    borderRadius: BorderRadius.circular(Radii.lg),
                  )
                : null,
            child: Row(
              mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: labelColor, size: 20),
                  const SizedBox(width: Gap.sm + 2),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: labelColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
