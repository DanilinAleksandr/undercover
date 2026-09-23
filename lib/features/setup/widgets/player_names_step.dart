import 'package:flutter/material.dart';

import '../../../providers/game_setup_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimens.dart';
import '../../../theme/app_palette.dart';
import '../../../widgets/player_avatar.dart';
import '../../../widgets/surface_card.dart';

/// The one place a line-up is managed.
///
/// There is no separate "how many players" screen any more: the list is the
/// count. Adding a row adds a player, removing one removes a player, and the
/// header simply reports the length of the list — a second counter could only
/// ever disagree with it.
class PlayerNamesStep extends StatelessWidget {
  final List<TextEditingController> controllers;
  final void Function(int index, String name) onChanged;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  /// Offered only when there is a remembered line-up to forget.
  final VoidCallback? onForgetSaved;

  const PlayerNamesStep({
    super.key,
    required this.controllers,
    required this.onChanged,
    required this.onAdd,
    required this.onRemove,
    required this.onForgetSaved,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final count = controllers.length;
    final canRemove = count > kMinPlayers;
    final canAdd = count < kMaxPlayers;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.lg),
      children: [
        const Eyebrow('Шаг 1 из 2', icon: Icons.badge_rounded),
        const SizedBox(height: Gap.md),
        Text(
          'Игроки · $count',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontSize: 26),
        ),
        const SizedBox(height: Gap.xs),
        Text(
          'От $kMinPlayers до $kMaxPlayers человек · имена должны '
          'отличаться, по ним передают телефон',
          style: TextStyle(color: palette.textMuted, fontSize: 13),
        ),
        const SizedBox(height: Gap.lg),
        for (var index = 0; index < count; index++) ...[
          _PlayerRow(
            index: index,
            controller: controllers[index],
            onChanged: (value) => onChanged(index, value),
            isLast: index == count - 1,
            onRemove: canRemove ? () => onRemove(index) : null,
          ),
          const SizedBox(height: Gap.md),
        ],
        _AddPlayerButton(onTap: canAdd ? onAdd : null, canAdd: canAdd),
        if (onForgetSaved != null) ...[
          const SizedBox(height: Gap.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onForgetSaved,
              icon: const Icon(Icons.person_remove_outlined, size: 18),
              label: const Text('Очистить сохранённых игроков'),
              style: TextButton.styleFrom(
                foregroundColor: palette.textMuted,
                padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 12.5),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final int index;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool isLast;
  final VoidCallback? onRemove;

  const _PlayerRow({
    required this.index,
    required this.controller,
    required this.onChanged,
    required this.isLast,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final filled = controller.text.trim().isNotEmpty;
        return SurfaceCard(
          padding:
              const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
          depth: filled ? Depth.lifted : Depth.flat,
          child: Row(
            children: [
              PlayerAvatar(
                name: filled ? controller.text : '${index + 1}',
                size: 40,
                disabled: !filled,
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: TextField(
                  key: ValueKey('player-name-$index'),
                  controller: controller,
                  onChanged: onChanged,
                  textCapitalization: TextCapitalization.words,
                  textInputAction:
                      isLast ? TextInputAction.done : TextInputAction.next,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Игрок ${index + 1}',
                    hintStyle: TextStyle(
                      color: palette.textMuted,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: Gap.md),
                  ),
                ),
              ),
              // Greyed out rather than hidden at the minimum, so the row does
              // not change width as the table shrinks.
              IconButton(
                key: ValueKey('remove-player-$index'),
                onPressed: onRemove,
                tooltip: 'Убрать игрока',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: onRemove == null
                      ? palette.textMuted.withValues(alpha: 0.4)
                      : palette.textMuted,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AddPlayerButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool canAdd;

  const _AddPlayerButton({required this.onTap, required this.canAdd});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SurfaceCard(
      key: const ValueKey('add-player'),
      onTap: onTap,
      depth: Depth.flat,
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.md),
      child: Row(
        children: [
          Icon(
            Icons.person_add_alt_1_rounded,
            size: 20,
            color: canAdd ? AppColors.gold : palette.textMuted,
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              canAdd ? 'Добавить игрока' : 'Больше $kMaxPlayers не поместится',
              style: TextStyle(
                color: canAdd ? palette.textPrimary : palette.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 14.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
