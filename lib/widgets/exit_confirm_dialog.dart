import 'package:flutter/material.dart';

/// Shows a confirmation dialog before letting the user back out of a
/// sensitive in-game screen (reveal/voting) where a stray back-gesture
/// could expose someone else's card or skip a vote.
Future<bool> confirmExitGame(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Выйти из игры?'),
      content: const Text('Текущий раунд будет потерян. Вы уверены?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Остаться'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Выйти'),
        ),
      ],
    ),
  );
  return result ?? false;
}
