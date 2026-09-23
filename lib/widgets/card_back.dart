import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_palette.dart';

/// The face-down side of a secret card.
///
/// A patterned, gold-ruled back is what makes the reveal feel like turning
/// over a real card. It is deliberately identical for every player: nothing
/// about the role may leak before the flip.
class CardBack extends StatelessWidget {
  final Widget child;

  const CardBack({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(palette.cardBack, Colors.white, 0.05)!,
            AppColors.ink900,
          ],
        ),
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.30), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.xl),
        child: CustomPaint(
          painter: _CardBackPainter(palette.cardBackPattern),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Diamond lattice inside a double gold rule, with corner pips — the visual
/// grammar of a printed card back.
class _CardBackPainter extends CustomPainter {
  final Color color;

  const _CardBackPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final lattice = Paint()
      ..color = color.withValues(alpha: color.a * 0.55)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const step = 26.0;
    for (var i = -size.height; i < size.width + size.height; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), lattice);
      canvas.drawLine(Offset(i + size.height, 0), Offset(i, size.height), lattice);
    }

    final rule = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.38)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final outer = Rect.fromLTWH(12, 12, size.width - 24, size.height - 24);
    final inner = outer.deflate(5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(outer, const Radius.circular(Radii.md)),
      rule,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner, const Radius.circular(Radii.sm)),
      Paint()
        ..color = AppColors.gold.withValues(alpha: 0.16)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke,
    );

    // Corner pips.
    final pip = Paint()..color = AppColors.gold.withValues(alpha: 0.45);
    for (final corner in [
      outer.topLeft,
      outer.topRight,
      outer.bottomLeft,
      outer.bottomRight,
    ]) {
      canvas.save();
      canvas.translate(corner.dx, corner.dy);
      canvas.rotate(math.pi / 4);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: 5, height: 5),
        pip,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CardBackPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Ring that fills while the card is held, showing when the dwell time that
/// unlocks the confirm button has elapsed.
class HoldProgressRing extends StatelessWidget {
  final double progress;
  final Color color;
  final Widget child;

  const HoldProgressRing({
    super.key,
    required this.progress,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final complete = progress >= 1;
    return SizedBox(
      width: 78,
      height: 78,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 2.5,
              strokeCap: StrokeCap.round,
              backgroundColor: context.palette.border,
              valueColor: AlwaysStoppedAnimation(
                complete ? AppColors.gold : color,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
