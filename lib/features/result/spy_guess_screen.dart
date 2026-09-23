import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/game_session_provider.dart';
import '../../router/route_paths.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_button.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/surface_card.dart';

/// The spy's last chance, judged by the table rather than by a text field.
///
/// The spy says the word out loud — everyone hears it and everyone agrees on
/// the verdict in the same second. Typing it in would put one player on the
/// keyboard while the rest wait, and would turn a spelling slip into a lost
/// round.
class SpyGuessScreen extends ConsumerWidget {
  const SpyGuessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final session = ref.watch(gameSessionProvider);
    if (session == null) return const SizedBox.shrink();

    void finish({required bool correct}) {
      ref.read(gameSessionProvider.notifier).resolveSpyGuess(correct: correct);
      context.go(RoutePaths.winner);
    }

    return Scaffold(
      body: GradientBackground(
        accentGlow: AppColors.spyGradient,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.lg),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: Gap.xl),
                        const Eyebrow('Последний шанс',
                            icon: Icons.hourglass_bottom_rounded),
                        const SizedBox(height: Gap.xl),
                        Container(
                          width: 96,
                          height: 96,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.spyGradient,
                          ),
                          child: Icon(Icons.visibility_off_rounded,
                              color: palette.onAccent, size: 42),
                        ),
                        const SizedBox(height: Gap.xl),
                        Text(
                          'Шпион найден',
                          textAlign: TextAlign.center,
                          style: AppText.title(context, size: 30),
                        ),
                        const SizedBox(height: Gap.sm),
                        Text(
                          '${session.spyPlayer.name}, назовите ответ мирных вслух',
                          textAlign: TextAlign.center,
                          style: AppText.body(context),
                        ),
                        const SizedBox(height: Gap.xl),
                        SurfaceCard(
                          child: Row(
                            children: [
                              const Icon(Icons.groups_rounded,
                                  color: AppColors.gold, size: 22),
                              const SizedBox(width: Gap.md),
                              Expanded(
                                child: Text(
                                  'Мирные слышат ответ и вместе решают, засчитан он или нет',
                                  style: AppText.body(context)
                                      .copyWith(fontSize: 13.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Gap.lg),
                      ],
                    ),
                  ),
                ),
                AppButton(
                  label: 'Отгадал',
                  icon: Icons.check_rounded,
                  gradient: AppColors.spyGradient,
                  onPressed: () => finish(correct: true),
                ),
                const SizedBox(height: Gap.md),
                AppButton(
                  label: 'Не отгадал',
                  icon: Icons.close_rounded,
                  outlined: true,
                  onPressed: () => finish(correct: false),
                ),
                const SizedBox(height: Gap.sm),
                // The verdict is one tap with no confirmation dialog, so the
                // rule it applies is spelled out next to it instead.
                Text(
                  'Нажмите «Отгадал», только если шпион назвал именно ответ '
                  'мирных.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
