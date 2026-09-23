import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/game_session_provider.dart';
import '../../router/route_paths.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../widgets/gradient_background.dart';

class RoleIntroScreen extends ConsumerStatefulWidget {
  const RoleIntroScreen({super.key});

  @override
  ConsumerState<RoleIntroScreen> createState() => _RoleIntroScreenState();
}

class _RoleIntroScreenState extends ConsumerState<RoleIntroScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      ref.read(gameSessionProvider.notifier).beginHandoffSequence();
      context.go(RoutePaths.handoff);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        accentGlow: AppColors.spyGradient,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RotationTransition(
                turns: _controller,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.spyGradient,
                  ),
                  child: Icon(Icons.style_rounded,
                      color: context.palette.onAccent, size: 40),
                ),
              ),
              const SizedBox(height: Gap.xxl),
              Text(
                'Раздаём роли...',
                style: TextStyle(
                  color: context.palette.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: Gap.sm),
              Text(
                'Один из вас станет шпионом',
                style: TextStyle(
                  color: context.palette.textMuted,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
