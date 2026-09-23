import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game_mode.dart';
import '../providers/used_entries_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_palette.dart';
import '../utils/plural_ru.dart';
import 'surface_card.dart';

/// Asks before wiping the played-words history.
///
/// It is the one destructive action in the app — every word the party has
/// already heard comes back into the pool — so it never happens on a single
/// tap, and never happens on its own after a game, a rematch or a restart.
Future<bool> confirmResetUsedWords(BuildContext context, GameMode mode) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Сбросить историю режима «${mode.label}»?'),
      content: const Text('Все использованные ответы этого режима снова '
          'станут доступны. Другие режимы не изменятся.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Сбросить'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Confirms the wipe where the user is standing. Short on purpose — the number
/// on screen has already updated, this is only the acknowledgement.
void showHistoryResetToast(BuildContext context) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    const SnackBar(
      content: Text('История сброшена'),
      duration: Duration(seconds: 2),
    ),
  );
}

/// Runs the guarded reset of one mode. Returns true when it was cleared.
Future<bool> resetUsedWords(
    BuildContext context, WidgetRef ref, GameMode mode) async {
  if (!await confirmResetUsedWords(context, mode)) return false;
  ref.read(usedEntriesProvider.notifier).reset(mode);
  if (context.mounted) showHistoryResetToast(context);
  return true;
}

/// Settings entry for the played history: one row per mode, each with its own
/// count and its own reset. The modes never share content, so they never share
/// a history either.
class UsedWordsCard extends ConsumerWidget {
  const UsedWordsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final used = ref.watch(usedEntriesProvider);
    final total = GameMode.values
        .fold<int>(0, (sum, mode) => sum + (used[mode]?.length ?? 0));

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_toggle_off_rounded,
                  color: total == 0 ? palette.textSecondary : AppColors.gold,
                  size: 22),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Text(
                  'История ответов',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Text(
            'Сыгранный ответ больше не выпадает в своём режиме. История '
            'переживает перезапуск и сбрасывается только здесь.',
            style: TextStyle(
                color: palette.textSecondary, fontSize: 12.5, height: 1.35),
          ),
          for (final mode in GameMode.values) ...[
            const SizedBox(height: Gap.md),
            _ModeRow(mode: mode, count: used[mode]?.length ?? 0),
          ],
        ],
      ),
    );
  }
}

class _ModeRow extends ConsumerWidget {
  final GameMode mode;
  final int count;

  const _ModeRow({required this.mode, required this.count});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final empty = count == 0;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mode.label,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                empty
                    ? 'Пока ничего не сыграно'
                    : 'Использовано: ${wordsLabel(count)}',
                style: TextStyle(color: palette.textMuted, fontSize: 12.5),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: empty ? null : () => resetUsedWords(context, ref, mode),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.magenta,
            disabledForegroundColor: palette.textMuted,
            padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
            visualDensity: VisualDensity.compact,
          ),
          child: const Text('Сбросить', style: TextStyle(fontSize: 12.5)),
        ),
      ],
    );
  }
}
