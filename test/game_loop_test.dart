import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undercover/app.dart';
import 'package:undercover/models/game_phase.dart';
import 'package:undercover/models/game_result.dart';
import 'package:undercover/models/role.dart';
import 'package:undercover/providers/game_session_provider.dart';

/// Drives the whole pass-and-play loop through the real UI, the way a table of
/// players actually does it. These are the tests that would have caught a
/// broken hand-off or a phase that never advances.

/// The app is portrait-locked on phones, so drive the tests at a phone size —
/// the default 800x600 test surface is landscape and does not reflect what
/// players actually see.
void _usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Walks the app from the home screen to the first hand-off card.
Future<ProviderContainer> _startGame(
  WidgetTester tester, {
  required List<String> names,
  bool alcoMode = false,
}) async {
  _usePhoneScreen(tester);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const UndercoverApp()),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('Новая игра'));
  await tester.pumpAndSettle();

  // The names list is the count: drop seats from the end of the default five.
  for (var i = 5; i > names.length; i--) {
    await tester.tap(find.byKey(const ValueKey('remove-player-0')));
    await tester.pumpAndSettle();
  }

  for (var i = 0; i < names.length; i++) {
    await tester.enterText(find.byType(TextField).at(i), names[i]);
    await tester.pumpAndSettle();
  }
  if (alcoMode) {
    // The alco switch is a party rule, so it lives behind the gear now.
    // Alco is a rule of play, so it lives in the in-game settings; from the
    // home screen the same screen is one gear away.
    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Новая игра'));
    await tester.pumpAndSettle();
  }

  // Step two: the round starts from the party settings.
  await tester.tap(find.text('Далее'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Начать игру'));
  // The role-intro screen spins a repeating animation, so settle would hang.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 2200));
  await tester.pumpAndSettle();

  return container;
}

/// Hand the phone over, hold the card long enough to read it, confirm.
Future<void> _revealOnePlayer(WidgetTester tester) async {
  await tester.tap(find.text('Это я, показать карту'));
  await tester.pumpAndSettle();

  // The confirm button only unlocks after the card has been held ~700ms.
  final card = find.byKey(const ValueKey('reveal-card'));
  expect(card, findsOneWidget);
  final gesture = await tester.startGesture(tester.getCenter(card));
  await tester.pump(const Duration(milliseconds: 1200));
  await gesture.up();
  await tester.pumpAndSettle();

  await tester.tap(find.text('Я запомнил слово'));
  await tester.pumpAndSettle();
}

Future<void> _revealAll(WidgetTester tester, int playerCount) async {
  for (var i = 0; i < playerCount; i++) {
    await _revealOnePlayer(tester);
  }
}

/// Free discussion is a single screen with a single way out: the table talks
/// for as long as it likes and then calls the vote.
Future<void> _runDiscussion(WidgetTester tester) async {
  expect(find.text('Ассоциации — в любом порядке'), findsOneWidget);
  await tester.tap(find.text('Готовы голосовать'));
  await tester.pumpAndSettle();
}

/// Every player in turn votes for [targetName] — except that player, who has
/// to pick someone else because self-voting is blocked.
Future<void> _voteAll(
  WidgetTester tester,
  ProviderContainer container, {
  required String targetName,
  required String fallbackName,
}) async {
  final playerCount = container.read(gameSessionProvider)!.players.length;
  for (var i = 0; i < playerCount; i++) {
    final s = container.read(gameSessionProvider)!;
    final voter = s.players[i];
    expect(find.text('Это я, голосовать'), findsOneWidget,
        reason: 'vote $i: phase=${s.phase} idx=${s.currentVotingIndex} '
            'votes=${s.votes.length} target=$targetName fallback=$fallbackName');
    await tester.tap(find.text('Это я, голосовать'));
    await tester.pumpAndSettle();

    final choice = voter.name == targetName ? fallbackName : targetName;
    expect(find.text(choice), findsOneWidget,
        reason: 'vote $i: voter=${voter.name} choosing $choice');
    await tester.ensureVisible(find.text(choice));
    await tester.pumpAndSettle();
    await tester.tap(find.text(choice));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Подтвердить голос'));
    await tester.pumpAndSettle();
  }
}

void main() {
  const names = ['Аня', 'Боря', 'Вика', 'Гоша'];

  testWidgets('a full round ends with the civilians winning when the spy guesses wrong',
      (tester) async {
    final container = await _startGame(tester, names: names);

    var session = container.read(gameSessionProvider)!;
    expect(session.players, hasLength(4));
    expect(session.players.where((p) => p.role == Role.spy), hasLength(1));

    await _revealAll(tester, names.length);
    session = container.read(gameSessionProvider)!;
    expect(session.players.every((p) => p.hasSeenWord), isTrue,
        reason: 'every player must be marked as having seen their card');
    expect(session.phase, GamePhase.association,
        reason: 'the last card must land straight in free discussion');

    await _runDiscussion(tester);

    final spy = container.read(gameSessionProvider)!.spyPlayer;
    final civilian =
        container.read(gameSessionProvider)!.civilians.first;
    await _voteAll(tester, container,
        targetName: spy.name, fallbackName: civilian.name);

    session = container.read(gameSessionProvider)!;
    expect(session.phase, GamePhase.voteResult);
    expect(session.voteResult!.spyWasCaught, isTrue);
    expect(find.textContaining('ШПИОН'), findsWidgets);

    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    expect(container.read(gameSessionProvider)!.phase, GamePhase.spyGuess);

    // The spy says the word out loud; the table taps the verdict. No typing.
    expect(find.text('Шпион найден'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Не отгадал'));
    await tester.pumpAndSettle();

    expect(container.read(gameSessionProvider)!.result!.outcome,
        Outcome.civiliansWin);
    expect(find.text('Мирные победили!'), findsOneWidget);
  });

  testWidgets('the spy wins by guessing the civilians word', (tester) async {
    final container = await _startGame(tester, names: names);
    await _revealAll(tester, names.length);
    await _runDiscussion(tester);

    final session = container.read(gameSessionProvider)!;
    await _voteAll(tester, container,
        targetName: session.spyPlayer.name,
        fallbackName: session.civilians.first.name);

    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Отгадал'));
    await tester.pumpAndSettle();

    expect(container.read(gameSessionProvider)!.result!.outcome,
        Outcome.spyWinsByGuess);
    expect(find.text('Шпион победил!'), findsOneWidget);
  });

  testWidgets('voting out an innocent hands the win to the spy, no guess offered',
      (tester) async {
    final container = await _startGame(tester, names: names);
    await _revealAll(tester, names.length);
    await _runDiscussion(tester);

    final session = container.read(gameSessionProvider)!;
    final innocent = session.civilians.first;
    final other = session.players.firstWhere((p) => p.id != innocent.id);
    await _voteAll(tester, container,
        targetName: innocent.name, fallbackName: other.name);

    final result = container.read(gameSessionProvider)!;
    expect(result.voteResult!.spyWasCaught, isFalse);

    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();

    // The spy never gets a guess when they were not caught.
    expect(container.read(gameSessionProvider)!.phase, GamePhase.winner);
    expect(container.read(gameSessionProvider)!.result!.outcome,
        Outcome.spyWinsUncaught);
    expect(find.text('Шпион победил!'), findsOneWidget);
  });

  testWidgets('alco mode shows the penalty card matching the outcome',
      (tester) async {
    final container =
        await _startGame(tester, names: names, alcoMode: true);
    expect(container.read(gameSessionProvider)!.config.alcoModeEnabled, isTrue);

    await _revealAll(tester, names.length);
    await _runDiscussion(tester);

    final session = container.read(gameSessionProvider)!;
    await _voteAll(tester, container,
        targetName: session.spyPlayer.name,
        fallbackName: session.civilians.first.name);

    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Не отгадал'));
    await tester.pumpAndSettle();

    // Spy caught and failed to guess -> the spy drinks a full glass.
    expect(find.textContaining('штрафной стакан'), findsOneWidget);
  });

  testWidgets('replaying with the same players reshuffles roles and word',
      (tester) async {
    final container = await _startGame(tester, names: names);
    await _revealAll(tester, names.length);
    await _runDiscussion(tester);

    final first = container.read(gameSessionProvider)!;
    final firstPair = first.wordPair.id;
    await _voteAll(tester, container,
        targetName: first.civilians.first.name,
        fallbackName: first.spyPlayer.name);
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Реванш'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pumpAndSettle();

    final second = container.read(gameSessionProvider)!;
    expect(second.players.map((p) => p.name).toList(),
        first.players.map((p) => p.name).toList(),
        reason: 'the same people keep playing');
    expect(second.wordPair.id, isNot(firstPair),
        reason: 'a replay must not reuse the previous word pair');
    expect(second.votes, isEmpty);
    expect(second.result, isNull);
    expect(second.players.every((p) => !p.hasSeenWord), isTrue);
    expect(second.players.where((p) => p.role == Role.spy), hasLength(1));
  });

  testWidgets('a player cannot vote for themselves', (tester) async {
    final container = await _startGame(tester, names: names);
    await _revealAll(tester, names.length);
    await _runDiscussion(tester);

    await tester.tap(find.text('Это я, голосовать'));
    await tester.pumpAndSettle();

    final voter = container.read(gameSessionProvider)!.players.first;
    await tester.tap(find.text(voter.name));
    await tester.pumpAndSettle();

    // Own avatar is inert, so the confirm button must still be locked.
    await tester.tap(find.text('Подтвердить голос'));
    await tester.pumpAndSettle();
    expect(container.read(gameSessionProvider)!.votes, isEmpty);
    expect(container.read(gameSessionProvider)!.phase, GamePhase.voting);
  });
}
