import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/surface_card.dart';
import '../../widgets/used_words_card.dart';
import 'widgets/game_toggles_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final mode = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки игры')),
      body: GradientBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.xxl),
          children: [
            const Eyebrow('Ход партии', ruled: true),
            const SizedBox(height: Gap.md),
            Text(
              'Можно менять прямо во время игры',
              style: TextStyle(color: palette.textMuted, fontSize: 12.5),
            ),
            const SizedBox(height: Gap.md),
            const GameTogglesCard(),
            const SizedBox(height: Gap.xxl),
            const Eyebrow('Оформление', ruled: true),
            const SizedBox(height: Gap.md),
            Text(
              'Тема оформления',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Gap.md),
            _ThemeOption(
              label: 'Системная',
              description: 'Как на телефоне',
              icon: Icons.brightness_auto_rounded,
              mode: ThemeMode.system,
              current: mode,
              onTap: () =>
                  ref.read(settingsProvider.notifier).setThemeMode(ThemeMode.system),
            ),
            _ThemeOption(
              label: 'Тёмная',
              description: 'Лучше всего для вечера',
              icon: Icons.dark_mode_rounded,
              mode: ThemeMode.dark,
              current: mode,
              onTap: () =>
                  ref.read(settingsProvider.notifier).setThemeMode(ThemeMode.dark),
            ),
            _ThemeOption(
              label: 'Светлая',
              description: 'Для яркого света',
              icon: Icons.light_mode_rounded,
              mode: ThemeMode.light,
              current: mode,
              onTap: () =>
                  ref.read(settingsProvider.notifier).setThemeMode(ThemeMode.light),
            ),
            const SizedBox(height: Gap.xxl),
            const Eyebrow('История слов', ruled: true),
            const SizedBox(height: Gap.md),
            const UsedWordsCard(),
            const SizedBox(height: Gap.xxl),
            const Eyebrow('Приложение', ruled: true),
            const SizedBox(height: Gap.md),
            SurfaceCard(
              child: Row(
                children: [
                  Icon(Icons.visibility_off_rounded,
                      color: palette.textSecondary, size: 22),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Undercover',
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Версия 1.0.0 · играется офлайн',
                          style:
                              TextStyle(color: palette.textMuted, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final ThemeMode mode;
  final ThemeMode current;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.description,
    required this.icon,
    required this.mode,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final selected = mode == current;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: SurfaceCard(
        onTap: onTap,
        depth: selected ? Depth.lifted : Depth.raised,
        accent: selected ? AppColors.gold : null,
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
        child: Row(
          children: [
            Icon(icon,
                size: 22,
                color: selected ? AppColors.gold : palette.textSecondary),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(color: palette.textMuted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            AnimatedScale(
              scale: selected ? 1 : 0,
              duration: Motion.fast,
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.gold, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}
