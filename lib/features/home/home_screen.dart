import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/route_paths.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_button.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/surface_card.dart';

/// Cover screen. Composed like the lid of a board-game box: an emblem, a
/// ruled title lock-up, a one-line premise, then the way in.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: Motion.slow)..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  /// Staggered rise so the cover assembles itself instead of just appearing.
  Widget _rise(int step, Widget child) {
    final start = (step * 0.12).clamp(0.0, 0.6);
    final anim = CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, (start + 0.5).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position:
            Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(anim),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      body: GradientBackground(
        accentGlow: AppColors.spyGradient,
        intense: true,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.page),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: () => context.push(RoutePaths.settings),
                    icon: const Icon(Icons.settings_outlined),
                    color: palette.textMuted,
                    tooltip: 'Настройки',
                  ),
                ),
                // Cover block flexes; the two ways in stay pinned so the
                // screen holds together on a 320pt phone.
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: Gap.xl),
                        _rise(0, const _Emblem()),
                        const SizedBox(height: Gap.xxl),
                        _rise(1, const _TitleLockup()),
                        const SizedBox(height: Gap.lg),
                        _rise(
                          2,
                          Text(
                            'Все получили одно слово.\nКроме одного.',
                            textAlign: TextAlign.center,
                            style: AppText.body(context).copyWith(fontSize: 15),
                          ),
                        ),
                        const SizedBox(height: Gap.xl),
                      ],
                    ),
                  ),
                ),
                _rise(
                  3,
                  AppButton(
                    label: 'Новая игра',
                    icon: Icons.play_arrow_rounded,
                    onPressed: () => context.push(RoutePaths.setup),
                  ),
                ),
                const SizedBox(height: Gap.md),
                _rise(
                  4,
                  AppButton(
                    label: 'Как играть',
                    icon: Icons.menu_book_rounded,
                    outlined: true,
                    onPressed: () => context.push(RoutePaths.rules),
                  ),
                ),
                const SizedBox(height: Gap.xl),
                _rise(
                  5,
                  Text(
                    'Одно устройство · 3–12 игроков · без интернета',
                    style: AppText.caption(context).copyWith(fontSize: 11.5),
                  ),
                ),
                const SizedBox(height: Gap.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A fan of face-down cards with the masked eye on the front one.
class _Emblem extends StatelessWidget {
  const _Emblem();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      height: 118,
      width: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final spec in const [(-0.26, -34.0), (0.26, 34.0), (0.0, 0.0)])
            Transform.rotate(
              angle: spec.$1,
              child: Transform.translate(
                offset: Offset(spec.$2, spec.$1 == 0 ? -6 : 6),
                child: Container(
                  width: 74,
                  height: 104,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(palette.cardBack, Colors.white, 0.06)!,
                        AppColors.ink900,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: spec.$1 == 0 ? 0.45 : 0.20),
                      width: 1.1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: spec.$1 == 0
                        ? ShaderMask(
                            shaderCallback: (b) =>
                                AppColors.spyGradient.createShader(b),
                            child: const Icon(Icons.visibility_off_rounded,
                                color: Colors.white, size: 34),
                          )
                        : Transform.rotate(
                            angle: math.pi / 4,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppColors.gold.withValues(alpha: 0.30),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TitleLockup extends StatelessWidget {
  const _TitleLockup();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppColors.gold, Color(0xFFF3DFA8), AppColors.gold],
            ).createShader(bounds),
            child: Text(
              'UNDERCOVER',
              maxLines: 1,
              style: AppText.wordmark.copyWith(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: Gap.md),
        const Eyebrow('Игра на доверие', ruled: true, color: AppColors.gold),
      ],
    );
  }
}
