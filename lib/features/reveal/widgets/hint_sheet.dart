import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_dimens.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_text.dart';
import '../../../widgets/surface_card.dart';

/// Progressive clue sheet for a hard or expert word.
///
/// Opened from a quiet link under the card, never shown by default: the round
/// is better when a player wrestles with the word first. Clues unlock one at a
/// time so nobody burns the near-definition when the broad nudge would have
/// been enough.
Future<void> showHintSheet(
  BuildContext context, {
  required List<String> hints,
  required Gradient accent,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _HintSheet(hints: hints, accent: accent),
  );
}

class _HintSheet extends StatefulWidget {
  final List<String> hints;
  final Gradient accent;

  const _HintSheet({required this.hints, required this.accent});

  @override
  State<_HintSheet> createState() => _HintSheetState();
}

class _HintSheetState extends State<_HintSheet> {
  int _revealed = 1;

  static const _levelNames = ['Намёк', 'Уточнение', 'Почти определение'];

  void _revealNext() {
    HapticFeedback.selectionClick();
    setState(() => _revealed++);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasMore = _revealed < widget.hints.length;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.ink700 : AppColors.paper000,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        border: Border(
          top: BorderSide(color: AppColors.gold.withValues(alpha: 0.35), width: 1.2),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        Gap.page,
        Gap.md,
        Gap.page,
        Gap.xl + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: palette.border,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
          ),
          const SizedBox(height: Gap.lg),
          const Eyebrow('Подсказка', ruled: true, color: AppColors.gold),
          const SizedBox(height: Gap.lg),
          for (var i = 0; i < _revealed && i < widget.hints.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: SurfaceCard(
                depth: i == _revealed - 1 ? Depth.lifted : Depth.flat,
                accent: i == _revealed - 1 ? AppColors.gold : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.lg,
                  vertical: Gap.md,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${i + 1}',
                      style: AppText.eyebrow(context, color: AppColors.gold)
                          .copyWith(fontSize: 13),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _levelNames[i].toUpperCase(),
                            style: AppText.eyebrow(context),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.hints[i],
                            style: AppText.body(context).copyWith(
                              color: palette.textPrimary,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: Gap.sm),
          if (hasMore)
            TextButton.icon(
              onPressed: _revealNext,
              icon: const Icon(Icons.add_circle_outline_rounded,
                  size: 18, color: AppColors.gold),
              label: Text(
                'Ещё подсказка',
                style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            )
          else
            Text('Это всё, что можно подсказать',
                style: AppText.caption(context)),
        ],
      ),
    );
  }
}

/// The quiet entry point under the card.
class HintLink extends StatelessWidget {
  final VoidCallback onTap;

  const HintLink({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: context.palette.textMuted,
        padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
        minimumSize: const Size(0, 40),
      ),
      icon: Icon(Icons.help_outline_rounded,
          size: 16, color: context.palette.textMuted),
      label: Text(
        'Слово незнакомо?',
        style: AppText.caption(context).copyWith(
          decoration: TextDecoration.underline,
          decorationColor: context.palette.textMuted,
        ),
      ),
    );
  }
}
