import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A card that flips between [front] and [back] with a 3D rotation,
/// externally controlled via [flipped].
class FlipCard extends StatefulWidget {
  final Widget front;
  final Widget back;
  final bool flipped;

  const FlipCard({
    super.key,
    required this.front,
    required this.back,
    required this.flipped,
  });

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    if (widget.flipped) _controller.value = 1;
  }

  @override
  void didUpdateWidget(covariant FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.flipped != oldWidget.flipped) {
      if (widget.flipped) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final angle = _controller.value * math.pi;
        final showFront = angle < math.pi / 2;
        final displayAngle = showFront ? angle : angle - math.pi;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateY(displayAngle),
          child: showFront ? widget.front : widget.back,
        );
      },
    );
  }
}
