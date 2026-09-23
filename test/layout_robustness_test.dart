import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undercover/app.dart';
import 'package:undercover/models/game_phase.dart';
import 'package:undercover/models/game_result.dart';
import 'package:undercover/providers/game_session_provider.dart';
import 'package:undercover/providers/game_setup_provider.dart';

/// Walks every screen at real phone sizes with the smallest and largest
/// supported party. A RenderFlex overflow or a clipped control fails the test,
/// which is what a manual pass on a device would have caught.

class _Phone {
  final String name;
  final Size logical;
  const _Phone(this.name, this.logical);
}

// Logical sizes: an old small phone, a current mainstream phone.
const _smallPhone = _Phone('small 320x568', Size(320, 568));
const _typicalPhone = _Phone('typical 390x844', Size(390, 844));

void _useScreen(WidgetTester tester, _Phone phone) {
  const ratio = 3.0;
  tester.view.physicalSize = phone.logical * ratio;
  tester.view.devicePixelRatio = ratio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Fires the Android system back button / iOS back gesture.
Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
}

Future<ProviderContainer> _pumpApp(WidgetTester tester) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const UndercoverApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _tapText(WidgetTester tester, String label) async {
  expect(find.text(label), findsWidgets,
      reason: 'expected to be able to tap "$label", on screen: '
          '${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).where((d) => d != null && d.trim().isNotEmpty).toList()}');
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

Future<void> _setUpGame(WidgetTester tester, int playerCount) async {
  await _tapText(tester, 'Новая игра');
  // Always drop the first row: it is on screen at any size, and only the
  // resulting count matters — the names are typed in afterwards.
  for (var i = kDefaultPlayers; i > playerCount; i--) {
    await tester.tap(find.byKey(const ValueKey('remove-player-0')));
    await tester.pumpAndSettle();
  }
  for (var i = kDefaultPlayers; i < playerCount; i++) {
    await _addPlayer(tester);
  }
  // Adding seats leaves the list scrolled to the bottom; scrollUntilVisible
  // only searches downwards, so go back to the top before filling names.
  await tester.drag(find.byType(ListView), const Offset(0, 4000));
  await tester.pumpAndSettle();
  // With a full table the name list scrolls, so walk down to each field.
  final nameList =
      find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable));
  for (var i = 0; i < playerCount; i++) {
    final field = find.byKey(ValueKey('player-name-$i'));
    await tester.scrollUntilVisible(field, 120, scrollable: nameList.first);
    await tester.pumpAndSettle();
    await tester.enterText(field, 'Игрок ${i + 1}');
    await tester.pumpAndSettle();
  }
  await _tapText(tester, 'Далее');
  // The pool readout is pinned above the start button; on the smallest screen
  // both must fit without pushing each other off.
  expect(find.textContaining('В пуле:'), findsOneWidget);
  expect(find.text('Начать игру'), findsOneWidget);
  await _tapText(tester, 'Начать игру');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 2200));
  await tester.pumpAndSettle();
}

Future<void> _revealAll(WidgetTester tester, int playerCount) async {
  for (var i = 0; i < playerCount; i++) {
    await _tapText(tester, 'Это я, показать карту');
    final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('reveal-card'))));
    await tester.pump(const Duration(milliseconds: 1200));
    await gesture.up();
    await tester.pumpAndSettle();
    await _tapText(tester, 'Я запомнил слово');
  }
}

Future<void> _discussTo(WidgetTester tester) async {
  expect(find.text('Ассоциации — в любом порядке'), findsOneWidget);
  await _tapText(tester, 'Готовы голосовать');
}

/// Casts one vote per player, taking the target name from [targets].
Future<void> _voteEach(
  WidgetTester tester,
  ProviderContainer container,
  List<String> Function(int index) targets,
) async {
  final count = container.read(gameSessionProvider)!.players.length;
  for (var i = 0; i < count; i++) {
    await _tapText(tester, 'Это я, голосовать');
    await _tapText(tester, targets(i).first);
    await _tapText(tester, 'Подтвердить голос');
  }
}

void main() {
  for (final phone in [_smallPhone, _typicalPhone]) {
    for (final playerCount in [3, 12]) {
      testWidgets('${phone.name}: $playerCount players walk every screen',
          (tester) async {
        _useScreen(tester, phone);
        final container = await _pumpApp(tester);

        await _setUpGame(tester, playerCount);
        expect(container.read(gameSessionProvider)!.players, hasLength(playerCount));

        await _revealAll(tester, playerCount);
        await _discussTo(tester);

        final spyName = container.read(gameSessionProvider)!.spyPlayer.name;
        final civName = container.read(gameSessionProvider)!.civilians.first.name;
        await _voteEach(tester, container,
            (i) => [container.read(gameSessionProvider)!.players[i].name == spyName
                ? civName
                : spyName]);

        expect(container.read(gameSessionProvider)!.phase, GamePhase.voteResult);
        await _tapText(tester, 'Продолжить');

        expect(container.read(gameSessionProvider)!.phase, GamePhase.spyGuess);
        expect(find.text('Шпион найден'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        // The spy says the word out loud, so the screen must not print it —
        // neither the civilians' word nor the spy's own. Answers are always
        // rendered inside «», and the check has to say so: the base contains
        // «Шпион» as a playable word, and a bare substring search would trip
        // over the screen's own «Шпион найден» headline.
        final pair = container.read(gameSessionProvider)!.wordPair;
        expect(find.textContaining('«${pair.civilianWord}»'), findsNothing,
            reason: 'the word the spy has to guess is on screen');
        expect(find.textContaining('«${pair.spyWord}»'), findsNothing);
        expect(
            find.text('Нажмите «Отгадал», только если шпион назвал именно '
                'ответ мирных.'),
            findsOneWidget);
        expect(find.text('Отгадал'), findsOneWidget);
        await _tapText(tester, 'Не отгадал');

        expect(find.text('Мирные победили!'), findsOneWidget);
        // The verdict has to answer the three questions the table asks out
        // loud, without scrolling back to an earlier screen.
        expect(find.text(spyName), findsWidgets);
        expect(find.textContaining('Выгнали: $spyName'), findsOneWidget);
        expect(find.textContaining('Мирные: «'), findsOneWidget);
        expect(find.textContaining('Шпион: «'), findsOneWidget);
        // Both winner-screen actions must stay reachable on a small screen.
        expect(find.text('Реванш'), findsOneWidget);
        await tester.ensureVisible(find.text('Новая игра'));
        await tester.pumpAndSettle();
      });
    }
  }

  testWidgets('a tied vote means the spy was not caught and wins', (tester) async {
    _useScreen(tester, _typicalPhone);
    final container = await _pumpApp(tester);
    await _setUpGame(tester, 4);
    await _revealAll(tester, 4);
    await _discussTo(tester);

    final players = container.read(gameSessionProvider)!.players;
    // 2 votes for player 2, 2 votes for player 0 -> no single leader.
    final plan = [
      players[2].name,
      players[2].name,
      players[0].name,
      players[0].name,
    ];
    await _voteEach(tester, container, (i) => [plan[i]]);

    final result = container.read(gameSessionProvider)!.voteResult!;
    expect(result.isTie, isTrue);
    expect(result.spyWasCaught, isFalse);
    expect(find.text('Ничья!'), findsOneWidget);

    await _tapText(tester, 'Продолжить');
    expect(container.read(gameSessionProvider)!.result!.outcome,
        Outcome.spyWinsUncaught);
    expect(find.textContaining('Голоса разделились'), findsOneWidget);
  });

  testWidgets('rules and settings screens open and come back', (tester) async {
    _useScreen(tester, _smallPhone);
    await _pumpApp(tester);

    await _tapText(tester, 'Как играть');
    expect(find.text('Как играть'), findsWidgets);
    expect(find.text('Расстановка'), findsOneWidget);

    // The rules list must scroll all the way to the alco section on a small
    // screen — a lazy ListView only builds what is on screen.
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.text('Алко-режим'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('UNDERCOVER'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    // The in-game switches lead the screen now, so the theme block sits below
    // them — scroll it in before reaching for it.
    expect(find.text('Показывать роль'), findsOneWidget);

    /// The screen is long on a 320pt phone; walk down until the label shows.
    Future<void> scrollTo(String label) async {
      for (final step in [-220.0, 220.0]) {
        for (var i = 0; i < 14 && find.text(label).evaluate().isEmpty; i++) {
          await tester.drag(find.byType(ListView), Offset(0, step));
          await tester.pumpAndSettle();
        }
        if (find.text(label).evaluate().isNotEmpty) return;
      }
    }

    await scrollTo('Тема оформления');
    expect(find.text('Тема оформления'), findsOneWidget);
    await scrollTo('Светлая');
    await _tapText(tester, 'Светлая');
    await scrollTo('Тёмная');
    await _tapText(tester, 'Тёмная');

    // The played-pairs history lives further down, with its reset guarded.
    await scrollTo('История ответов');
    expect(find.text('История ответов'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('UNDERCOVER'), findsOneWidget);
  });

  testWidgets('backing out of a reveal asks before dropping the round',
      (tester) async {
    _useScreen(tester, _typicalPhone);
    final container = await _pumpApp(tester);
    await _setUpGame(tester, 3);
    await _tapText(tester, 'Это я, показать карту');
    expect(container.read(gameSessionProvider)!.phase, GamePhase.reveal);

    // A stray system-back must not silently expose the next player's card.
    await _systemBack(tester);
    await tester.pumpAndSettle();
    expect(find.text('Выйти из игры?'), findsOneWidget);

    await _tapText(tester, 'Остаться');
    expect(container.read(gameSessionProvider)!.phase, GamePhase.reveal);

    await _systemBack(tester);
    await tester.pumpAndSettle();
    await _tapText(tester, 'Выйти');
    expect(container.read(gameSessionProvider), isNull);
    expect(find.text('UNDERCOVER'), findsOneWidget);
  });

  testWidgets('setup rejects blank and duplicate names', (tester) async {
    _useScreen(tester, _typicalPhone);
    await _pumpApp(tester);
    await _tapText(tester, 'Новая игра');

    // Nothing typed yet: the step must stay locked.
    await _tapText(tester, 'Далее');
    expect(find.text('Игроки · $kDefaultPlayers'), findsOneWidget);

    for (var i = 0; i < kDefaultPlayers; i++) {
      await tester.enterText(find.byType(TextField).at(i), 'Одинаково');
      await tester.pumpAndSettle();
    }
    await _tapText(tester, 'Далее');
    expect(find.text('Игроки · $kDefaultPlayers'), findsOneWidget,
        reason: 'duplicate names must not be accepted');

    for (var i = 0; i < kDefaultPlayers; i++) {
      await tester.enterText(find.byType(TextField).at(i), 'Игрок $i');
      await tester.pumpAndSettle();
    }
    // Valid names finally arm the step and open the party settings.
    await _tapText(tester, 'Далее');
    expect(find.text('Настройки партии'), findsOneWidget);
    await _tapText(tester, 'Начать игру');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pumpAndSettle();
    expect(find.text('Это я, показать карту'), findsOneWidget);
  });
}
