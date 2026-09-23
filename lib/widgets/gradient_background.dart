import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// The room the game is played in.
///
/// Four cheap static layers, ordered from far to near: the theme gradient, a
/// broad glow tinted by the current phase, a sparse ember field, and a heavy
/// vignette that pulls the eye to the middle of the screen. The decoration is
/// almost invisible at the edges by design — it should register as atmosphere,
/// never compete with the content.
class GradientBackground extends StatelessWidget {
  final Widget child;
  final Gradient? accentGlow;

  /// Turns the phase glow up for the screens that carry a beat of tension.
  final bool intense;

  const GradientBackground({
    super.key,
    required this.child,
    this.accentGlow,
    this.intense = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = accentGlow?.colors.first;

    return DecoratedBox(
      decoration: BoxDecoration(gradient: palette.background),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (accentGlow != null) ...[
            Positioned(
              top: -110,
              right: -90,
              child: _Glow(
                gradient: accentGlow!,
                size: intense ? 340 : 280,
                opacity: isDark ? (intense ? 0.42 : 0.26) : 0.18,
              ),
            ),
            Positioned(
              bottom: -140,
              left: -110,
              child: _Glow(
                gradient: accentGlow!,
                size: intense ? 380 : 300,
                opacity: isDark ? (intense ? 0.30 : 0.18) : 0.12,
              ),
            ),
          ],
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _AtmospherePainter(
                  ember: palette.cardBackPattern,
                  accent: accent,
                  vignette: isDark ? 0.55 : 0.12,
                  dark: isDark,
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final Gradient gradient;
  final double size;
  final double opacity;

  const _Glow({required this.gradient, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
        child: Opacity(
          opacity: opacity,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
          ),
        ),
      ),
    );
  }
}

/// Ember field plus vignette. The embers are placed by a deterministic hash so
/// they never shimmer between rebuilds, and vary in size and alpha so the
/// surface reads as textured rather than as a printed grid.
class _AtmospherePainter extends CustomPainter {
  final Color ember;
  final Color? accent;
  final double vignette;
  final bool dark;

  const _AtmospherePainter({
    required this.ember,
    required this.accent,
    required this.vignette,
    required this.dark,
  });

  static const _cell = 46.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    var row = 0;
    for (var y = 0.0; y < size.height + _cell; y += _cell, row++) {
      var col = 0;
      for (var x = 0.0; x < size.width + _cell; x += _cell, col++) {
        // Stable pseudo-random from the cell coordinates.
        final h = (row * 73856093) ^ (col * 19349663);
        final r = ((h >> 5) & 0xFF) / 255.0;
        final jitterX = (((h >> 3) & 0x1F) / 31.0 - 0.5) * _cell;
        final jitterY = (((h >> 11) & 0x1F) / 31.0 - 0.5) * _cell;
        if (r < 0.45) continue;
        paint.color = ember.withValues(alpha: ember.a * (0.25 + r * 0.75));
        canvas.drawCircle(
          Offset(x + jitterX, y + jitterY),
          r > 0.92 ? 1.7 : 1.0,
          paint,
        );
      }
    }

    final rect = Offset.zero & size;

    // A faint warm bloom behind the centre of interest.
    if (accent != null && dark) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0, -0.35),
            radius: 0.9,
            colors: [accent!.withValues(alpha: 0.10), Colors.transparent],
          ).createShader(rect),
      );
    }

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: math.max(size.width, size.height) / math.min(size.width, size.height) * 0.72,
          colors: [Colors.transparent, Colors.black.withValues(alpha: vignette)],
          stops: const [0.42, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _AtmospherePainter old) =>
      old.ember != ember || old.vignette != vignette || old.accent != accent;
}
