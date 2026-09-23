import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Lightweight hand-rolled confetti burst (no external package) used on the
/// winner screen.
class ConfettiOverlay extends StatefulWidget {
  final Color primaryColor;
  final Color secondaryColor;

  const ConfettiOverlay({
    super.key,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward();
    final rand = math.Random();
    _particles = List.generate(48, (_) {
      return _Particle(
        x: rand.nextDouble(),
        delay: rand.nextDouble() * 0.3,
        speed: 0.6 + rand.nextDouble() * 0.6,
        drift: (rand.nextDouble() - 0.5) * 0.6,
        size: 6 + rand.nextDouble() * 6,
        color: rand.nextBool() ? widget.primaryColor : widget.secondaryColor,
        rotationSpeed: (rand.nextDouble() - 0.5) * 8,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _ConfettiPainter(particles: _particles, progress: _controller.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _Particle {
  final double x;
  final double delay;
  final double speed;
  final double drift;
  final double size;
  final Color color;
  final double rotationSpeed;

  _Particle({
    required this.x,
    required this.delay,
    required this.speed,
    required this.drift,
    required this.size,
    required this.color,
    required this.rotationSpeed,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final dy = t * size.height * p.speed;
      final dx = p.x * size.width + p.drift * size.height * t;
      final paint = Paint()
        ..color = p.color.withValues(alpha: (1 - t * 0.9).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(t * p.rotationSpeed);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => oldDelegate.progress != progress;
}
