import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undercover/app.dart';
import 'package:undercover/models/game_phase.dart';
import 'package:undercover/providers/game_session_provider.dart';
import 'package:undercover/widgets/player_avatar.dart';

/// Guards for the two things that break a real party rather than a screenshot:
/// losing the round to a stray back-swipe, and losing track of whose turn it is.

Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await tester.pumpAndSettle();
}

void _usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<ProviderContainer> _pump(WidgetTester tester) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const UndercoverApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).first);
  await tester.pumpAndSettle();
}

/// Taps "Добавить игрока", dragging the lazy list until the row exists.
Future<void> _addPlayer(WidgetTester tester) async {
  final add = find.byKey(const ValueKey('add-player'));
  for (var i = 0; i < 14 && add.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView), const Offset(0, -220));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(add);
  await tester.pumpAndSettle();
  await tester.tap(add);
  await tester.pumpAndSettle();
}

Future<void> _startGame(WidgetTester tester, int players) async {
  await _tap(tester, 'Новая игра');
  for (var i = 5; i > players; i--) {
    await tester.tap(find.byKey(const ValueKey('remove-player-0')));
    await tester.pumpAndSettle();
  }
  for (var i = 5; i < players; i++) {
    await _addPlayer(tester);
  }
  // Adding seats leaves the list scrolled to the bottom; scrollUntilVisible
  // only searches downwards, so go back to the top before filling names.
  await tester.drag(find.byType(ListView), const Offset(0, 4000));
  await tester.pumpAndSettle();
  final list =
      find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable));
  for (var i = 0; i < players; i++) {
    final field = find.byKey(ValueKey('player-name-$i'));
    await tester.scrollUntilVisible(field, 120, scrollable: list.first);
    await tester.pumpAndSettle();
    await tester.enterText(field, 'Игрок ${i + 1}');
    await tester.pumpAndSettle();
  }
  // Step two: the round starts from the party settings.
  await _tap(tester, 'Далее');
  await _tap(tester, 'Начать игру');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 2200));
  await tester.pumpAndSettle();
}

Future<void> _revealOne(WidgetTester tester) async {
  await _tap(tester, 'Это я, показать карту');
  final gesture = await tester
      .startGesture(tester.getCenter(find.byKey(const ValueKey('reveal-card'))));
  await tester.pump(const Duration(milliseconds: 1200));
  await gesture.up();
  await tester.pumpAndSettle();
  await _tap(tester, 'Я запомнил слово');
}

void main() {
  testWidgets('system back never silently drops a round in progress',
      (tester) async {
    _usePhone(tester);
    final container = await _pump(tester);
    await _startGame(tester, 3);

    // Each in-game screen is reached with context.go, so there is nothing to
    // pop; without a guard Android would close the app and end the party.
    Future<void> expectGuarded(String phase) async {
      await _systemBack(tester);
      expect(find.text('Выйти из игры?'), findsOneWidget, reason: 'unguarded: $phase');
      await _tap(tester, 'Остаться');
      expect(container.read(gameSessionProvider), isNotNull,
          reason: 'staying must keep the round: $phase');
    }

    await expectGuarded('hand-off');
    await _tap(tester, 'Это я, показать карту');
    await expectGuarded('reveal');

    final gesture = await tester
        .startGesture(tester.getCenter(find.byKey(const ValueKey('reveal-card'))));
    await tester.pump(const Duration(milliseconds: 1200));
    await gesture.up();
    await tester.pumpAndSettle();
    await _tap(tester, 'Я запомнил слово');
    await _revealOne(tester);
    await _revealOne(tester);

    await expectGuarded('free discussion');
    await _tap(tester, 'Готовы голосовать');
    await expectGuarded('voting hand-off');

    final spy = container.read(gameSessionProvider)!.spyPlayer.name;
    final civilian = container.read(gameSessionProvider)!.civilians.first.name;
    for (var i = 0; i < 3; i++) {
      final voter = container.read(gameSessionProvider)!.players[i].name;
      await _tap(tester, 'Это я, голосовать');
      if (i == 0) await expectGuarded('voting');
      await _tap(tester, voter == spy ? civilian : spy);
      await _tap(tester, 'Подтвердить голос');
    }
    await expectGuarded('vote result');
    await _tap(tester, 'Продолжить');

    if (find.text('Не отгадал').evaluate().isNotEmpty) {
      await expectGuarded('spy guess');
      await _tap(tester, 'Не отгадал');
    }
    await expectGuarded('winner');
  });

  testWidgets('leaving from the guard actually returns home', (tester) async {
    _usePhone(tester);
    final container = await _pump(tester);
    await _startGame(tester, 3);

    await _systemBack(tester);
    await _tap(tester, 'Выйти');
    expect(container.read(gameSessionProvider), isNull);
    expect(find.text('UNDERCOVER'), findsOneWidget);
  });

  testWidgets('a full round plays through in light theme', (tester) async {
    _usePhone(tester);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    final container = await _pump(tester);
    expect(Theme.of(tester.element(find.text('Новая игра'))).brightness,
        Brightness.light);

    await _startGame(tester, 4);
    for (var i = 0; i < 4; i++) {
      await _revealOne(tester);
    }
    await _tap(tester, 'Готовы голосовать');

    final spy = container.read(gameSessionProvider)!.spyPlayer.name;
    final civilian = container.read(gameSessionProvider)!.civilians.first.name;
    for (var i = 0; i < 4; i++) {
      final voter = container.read(gameSessionProvider)!.players[i].name;
      await _tap(tester, 'Это я, голосовать');
      await _tap(tester, voter == spy ? civilian : spy);
      await _tap(tester, 'Подтвердить голос');
    }
    await _tap(tester, 'Продолжить');
    await _tap(tester, 'Не отгадал');
    expect(find.text('Мирные победили!'), findsOneWidget);
  });

  testWidgets('replay and "new setup" both leave the app in a usable state',
      (tester) async {
    _usePhone(tester);
    final container = await _pump(tester);
    await _startGame(tester, 3);
    for (var i = 0; i < 3; i++) {
      await _revealOne(tester);
    }
    await _tap(tester, 'Готовы голосовать');

    final first = container.read(gameSessionProvider)!;
    for (var i = 0; i < 3; i++) {
      await _tap(tester, 'Это я, голосовать');
      final voter = container.read(gameSessionProvider)!.players[i].name;
      await _tap(tester,
          voter == first.civilians.first.name
              ? first.spyPlayer.name
              : first.civilians.first.name);
      await _tap(tester, 'Подтвердить голос');
    }
    await _tap(tester, 'Продолжить');
    if (find.text('Не отгадал').evaluate().isNotEmpty) {
      await _tap(tester, 'Не отгадал');
    }

    // Replay keeps the table and starts a clean round.
    await _tap(tester, 'Реванш');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pumpAndSettle();
    expect(find.text('Это я, показать карту'), findsOneWidget);
    expect(container.read(gameSessionProvider)!.votes, isEmpty);

    // And backing all the way out lands on a working home screen.
    await _systemBack(tester);
    await _tap(tester, 'Выйти');
    expect(find.text('UNDERCOVER'), findsOneWidget);
    await _tap(tester, 'Новая игра');
    expect(find.textContaining('Игроки · '), findsOneWidget);
  });

  testWidgets('the last card lands straight in free discussion, with no queue',
      (tester) async {
    _usePhone(tester);
    final container = await _pump(tester);
    await _startGame(tester, 12);
    for (var i = 0; i < 12; i++) {
      await _revealOne(tester);
    }

    // No intro step, no "whose turn is it" screen: the phone is done being
    // passed around and the table simply talks.
    expect(container.read(gameSessionProvider)!.phase, GamePhase.association);
    expect(find.text('Ассоциации — в любом порядке'), findsOneWidget);
    expect(find.text('Следующий игрок'), findsNothing);
    expect(find.text('Это я, показать карту'), findsNothing);
    expect(find.byType(PlayerAvatar), findsNothing);

    // The only way on is the vote, and it goes there in one tap.
    expect(find.text('Готовы голосовать'), findsOneWidget);
    await _tap(tester, 'Готовы голосовать');
    expect(container.read(gameSessionProvider)!.phase, GamePhase.votingHandoff);

    // Backing out of the vote returns to free discussion, not into a queue.
    await _systemBack(tester);
    await _tap(tester, 'Остаться');
    expect(container.read(gameSessionProvider)!.phase, GamePhase.votingHandoff);
  });
}
