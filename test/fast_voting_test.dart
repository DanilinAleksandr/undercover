import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undercover/app.dart';
import 'package:undercover/models/content_type.dart';
import 'package:undercover/models/difficulty.dart';
import 'package:undercover/models/game_config.dart';
import 'package:undercover/models/game_phase.dart';
import 'package:undercover/models/word_category.dart';
import 'package:undercover/models/word_pair.dart';
import 'package:undercover/providers/game_session_provider.dart';
import 'package:undercover/providers/game_setup_provider.dart';
import 'package:undercover/models/game_mode.dart';
import 'package:undercover/providers/used_entries_provider.dart';
import 'package:undercover/providers/word_pack_provider.dart';
import 'package:undercover/widgets/player_avatar.dart';

/// «Быстрое голосование» removes one screen and nothing else: the ballot, who
/// may be picked, the tally and the result are the same code either way. What
/// these tests watch most closely is the seam that screen used to cover — the
/// previous voter's choice must not be on screen when the phone changes hands.

const _e = Difficulty.easy;
const _m = Difficulty.medium;

const _pack = [
  WordCategory(
    id: 'alpha',
    name: 'Альфа',
    icon: Icons.science,
    pairs: [
      WordPair('Кошка', 'Тигр', _e, ['усы и лапы'], 5),
      WordPair('Гиря', 'Якорь', _m, ['тяжесть'], 5),
      WordPair('Маяк', 'Прожектор', _m, ['свет'], 5),
    ],
  ),
];

GameConfig _config({bool fastVoting = false, int players = 4}) => GameConfig(
      playerNames: [for (var i = 0; i < players; i++) 'Игрок$i'],
      fastVoting: fastVoting,
    );

ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [wordPackProvider.overrideWithValue(_pack)],
  );
  addTearDown(container.dispose);
  return container;
}

/// Plays a whole vote through the notifier, voting for [targetName] except
/// when that would be a self-vote.
List<GamePhase> _voteAll(
  ProviderContainer container, {
  required String targetName,
  required String fallbackName,
}) {
  final notifier = container.read(gameSessionProvider.notifier);
  final phases = <GamePhase>[];
  final total = container.read(gameSessionProvider)!.players.length;
  for (var i = 0; i < total; i++) {
    final session = container.read(gameSessionProvider)!;
    final voter = session.players[session.currentVotingIndex];
    final wanted = voter.name == targetName ? fallbackName : targetName;
    notifier.castVote(session.players.firstWhere((p) => p.name == wanted).id);
    phases.add(container.read(gameSessionProvider)!.phase);
  }
  return phases;
}

/// Flips the switch of the tile carrying [title].
///
/// By label rather than by index: the setup step gains and loses rows as the
/// mode changes, and a positional index quietly starts pointing at the wrong
/// toggle the moment the layout shifts.
Future<void> _toggleByTitle(WidgetTester tester, String title) async {
  final label = find.text(title);
  for (var i = 0; i < 14 && label.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView), const Offset(0, -220));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(label.first);
  await tester.pumpAndSettle();
  final row = find.ancestor(of: label.first, matching: find.byType(Row)).last;
  await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the setting', () {
    test('it is off by default, so nothing changes for an existing table', () {
      expect(const GameConfig(playerNames: ['А', 'Б', 'В']).fastVoting, isFalse);
      expect(GameConfig.initial.fastVoting, isFalse);
      final container = _container();
      expect(container.read(gameSetupProvider).fastVoting, isFalse);
    });

    test('it travels into the session like the other party settings', () {
      final container = _container();
      container.read(gameSetupProvider.notifier).setFastVoting(true);
      container
          .read(gameSessionProvider.notifier)
          .startGame(container.read(gameSetupProvider));
      expect(container.read(gameSessionProvider)!.config.fastVoting, isTrue);
    });

    test('it disturbs no other setting, and none of them disturb it', () {
      final container = _container();
      final notifier = container.read(gameSetupProvider.notifier);
      notifier.setFastVoting(true);
      notifier.setHintsEnabled(false);
      notifier.toggleContentType(ContentType.phrases);
      notifier.toggleDifficulty(Difficulty.hard);
      notifier.setAllowAdultContent(true);
      notifier.setAlcoMode(true);

      var config = container.read(gameSetupProvider);
      expect(config.fastVoting, isTrue);
      expect(config.hintsEnabled, isFalse);
      expect(config.selectedContentTypes, {ContentType.phrases});
      expect(config.selectedDifficulties, {Difficulty.hard});
      expect(config.allowAdultContent, isTrue);
      expect(config.alcoModeEnabled, isTrue);

      // And the pace is not a filter: turning it off leaves every one of them
      // exactly where the host put it.
      notifier.setFastVoting(false);
      config = container.read(gameSetupProvider);
      expect(config.fastVoting, isFalse);
      expect(config.hintsEnabled, isFalse);
      expect(config.selectedContentTypes, {ContentType.phrases});
      expect(config.selectedDifficulties, {Difficulty.hard});
      expect(config.allowAdultContent, isTrue);
      expect(config.alcoModeEnabled, isTrue);
    });

    test('it leaves the played-word history alone', () {
      final container = _container();
      container.read(gameSetupProvider.notifier).setFastVoting(true);
      container
          .read(gameSessionProvider.notifier)
          .startGame(container.read(gameSetupProvider));
      expect(container.read(usedEntriesProvider)[GameMode.words]!, hasLength(2),
          reason: 'exactly the dealt pair, as in any other round');
    });
  });

  group('the phase sequence', () {
    test('the ordinary mode still stops at a hand-off before every vote', () {
      final container = _container();
      final notifier = container.read(gameSessionProvider.notifier);
      notifier.startGame(_config());
      notifier.startVoting();
      expect(container.read(gameSessionProvider)!.phase,
          GamePhase.votingHandoff);

      notifier.confirmVotingHandoff();
      expect(container.read(gameSessionProvider)!.phase, GamePhase.voting);

      final session = container.read(gameSessionProvider)!;
      notifier.castVote(session.players[1].id);
      expect(container.read(gameSessionProvider)!.phase,
          GamePhase.votingHandoff,
          reason: 'the next voter gets the hand-off screen as before');
    });

    test('the fast mode goes straight to the ballot, every time', () {
      final container = _container();
      final notifier = container.read(gameSessionProvider.notifier);
      notifier.startGame(_config(fastVoting: true));
      notifier.startVoting();
      expect(container.read(gameSessionProvider)!.phase, GamePhase.voting);

      final phases = _voteAll(container,
          targetName: 'Игрок1', fallbackName: 'Игрок0');
      expect(phases.sublist(0, phases.length - 1),
          everyElement(GamePhase.voting));
      expect(phases.last, GamePhase.voteResult,
          reason: 'the last vote opens the results, as in the ordinary mode');
    });
  });

  group('the vote itself is untouched', () {
    test('the same votes produce the same tally in both modes', () {
      final results = <bool, dynamic>{};
      for (final fast in [false, true]) {
        final container = _container();
        final notifier = container.read(gameSessionProvider.notifier);
        notifier.startGame(_config(fastVoting: fast));
        notifier.startVoting();
        if (!fast) notifier.confirmVotingHandoff();

        // Everyone votes for Игрок1, who votes for Игрок0.
        for (var i = 0; i < 4; i++) {
          final session = container.read(gameSessionProvider)!;
          final voter = session.players[session.currentVotingIndex];
          final wanted = voter.name == 'Игрок1' ? 'Игрок0' : 'Игрок1';
          notifier.castVote(
              session.players.firstWhere((p) => p.name == wanted).id);
          if (!fast &&
              container.read(gameSessionProvider)!.phase ==
                  GamePhase.votingHandoff) {
            notifier.confirmVotingHandoff();
          }
        }
        final session = container.read(gameSessionProvider)!;
        results[fast] = session.voteResult!.tally;
        expect(session.votes, hasLength(4),
            reason: 'one vote per player, no more and no less');
        expect(session.players.where((p) => p.hasVoted), hasLength(4));
        expect(session.phase, GamePhase.voteResult);
      }
      expect(results[true], results[false]);
    });

    test('the round data is the same either way', () {
      final container = _container();
      final notifier = container.read(gameSessionProvider.notifier);
      notifier.startGame(_config(fastVoting: true));
      final before = container.read(gameSessionProvider)!;
      notifier.startVoting();
      final after = container.read(gameSessionProvider)!;

      expect(after.wordPair.id, before.wordPair.id);
      expect(after.spyPlayerId, before.spyPlayerId);
      expect(after.players.map((p) => p.name), before.players.map((p) => p.name));
      expect(after.result, isNull);
    });
  });

  group('on screen', () {
    Future<ProviderContainer> playToVoting(
      WidgetTester tester, {
      required bool fast,
      required Size size,
      int players = 4,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [wordPackProvider.overrideWithValue(_pack)],
      );
      addTearDown(container.dispose);
      container.read(gameSetupProvider.notifier).setFastVoting(fast);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const UndercoverApp()),
      );
      await tester.pumpAndSettle();

      Future<void> tap(String label) async {
        await tester.ensureVisible(find.text(label).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).first);
        await tester.pumpAndSettle();
      }

      await tap('Новая игра');
      final nameList = find.descendant(
          of: find.byType(ListView), matching: find.byType(Scrollable));
      for (var i = 5; i > players; i--) {
        await tester.tap(find.byKey(const ValueKey('remove-player-0')));
        await tester.pumpAndSettle();
      }
      for (var i = 5; i < players; i++) {
        final add = find.byKey(const ValueKey('add-player'));
        for (var k = 0; k < 14 && add.evaluate().isEmpty; k++) {
          await tester.drag(find.byType(ListView), const Offset(0, -220));
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(add);
        await tester.pumpAndSettle();
        await tester.tap(add);
        await tester.pumpAndSettle();
      }
      // A full table scrolls, so walk back up and then down to each field.
      await tester.drag(find.byType(ListView), const Offset(0, 4000));
      await tester.pumpAndSettle();
      for (var i = 0; i < players; i++) {
        final field = find.byKey(ValueKey('player-name-$i'));
        await tester.scrollUntilVisible(field, 120, scrollable: nameList.first);
        await tester.pumpAndSettle();
        await tester.enterText(field, 'Игрок$i');
        await tester.pumpAndSettle();
      }
      // Step two: the round starts from the party settings.
      await tap('Далее');
      await tap('Начать игру');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();

      for (var i = 0; i < players; i++) {
        await tap('Это я, показать карту');
        final gesture = await tester.startGesture(
            tester.getCenter(find.byKey(const ValueKey('reveal-card'))));
        await tester.pump(const Duration(milliseconds: 1200));
        await gesture.up();
        await tester.pumpAndSettle();
        await tap('Я запомнил слово');
      }
      await tap('Готовы голосовать');
      // Guards the helper itself: a wrong config here would make every
      // assertion below meaningless.
      expect(container.read(gameSessionProvider)!.config.fastVoting, fast,
          reason: 'the session must carry the pace the test asked for');
      return container;
    }

    testWidgets('the ordinary mode still shows the hand-off screen',
        (tester) async {
      final container = await playToVoting(tester,
          fast: false, size: const Size(1170, 2532));
      expect(find.text('Это я, голосовать'), findsOneWidget);
      expect(find.textContaining('Передайте телефон'), findsOneWidget);
      expect(container.read(gameSessionProvider)!.phase,
          GamePhase.votingHandoff);
    });

    testWidgets('the fast mode opens the ballot with no hand-off in between',
        (tester) async {
      final container = await playToVoting(tester,
          fast: true, size: const Size(1170, 2532));

      expect(find.text('Это я, голосовать'), findsNothing);
      expect(find.textContaining('Передайте телефон'), findsNothing);
      expect(container.read(gameSessionProvider)!.phase, GamePhase.voting);

      // The ballot still says what is happening, who is choosing and how many.
      expect(find.text('ГОЛОС 1 ИЗ 4'), findsOneWidget);
      final voter = container.read(gameSessionProvider)!.players.first.name;
      expect(find.text('$voter, кто шпион?'), findsOneWidget);
      expect(find.text('Выберите одного игрока'), findsOneWidget);
      expect(find.text('Подтвердить голос'), findsOneWidget);
    });

    testWidgets('the previous choice is gone when the phone changes hands',
        (tester) async {
      final container = await playToVoting(tester,
          fast: true, size: const Size(1170, 2532));

      Future<void> tapText(String label) async {
        await tester.ensureVisible(find.text(label).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).first);
        await tester.pumpAndSettle();
      }

      int highlighted() => tester
          .widgetList<PlayerAvatar>(find.byType(PlayerAvatar))
          .where((a) => a.highlighted)
          .length;

      expect(highlighted(), 0);
      await tapText('Игрок1');
      expect(highlighted(), 1, reason: 'the first voter made a choice');
      expect(find.text('Решение принято — подтвердите'), findsOneWidget);

      await tapText('Подтвердить голос');

      // Second voter, same screen instance, no hand-off in between.
      expect(container.read(gameSessionProvider)!.currentVotingIndex, 1);
      expect(find.text('ГОЛОС 2 ИЗ 4'), findsOneWidget);
      expect(highlighted(), 0,
          reason: 'the previous vote must not be visible to the next player');
      expect(find.text('Выберите одного игрока'), findsOneWidget);
      expect(find.text('Подтвердить голос'), findsOneWidget);
    });

    testWidgets('a fast vote runs to the result screen on 320x568 with 3',
        (tester) async {
      final container = await playToVoting(tester,
          fast: true, size: const Size(960, 1704), players: 3);

      Future<void> tapText(String label) async {
        await tester.ensureVisible(find.text(label).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).first);
        await tester.pumpAndSettle();
      }

      for (var i = 0; i < 3; i++) {
        final session = container.read(gameSessionProvider)!;
        final voter = session.players[session.currentVotingIndex];
        await tapText(voter.name == 'Игрок1' ? 'Игрок0' : 'Игрок1');
        await tapText('Подтвердить голос');
      }
      expect(container.read(gameSessionProvider)!.phase, GamePhase.voteResult);
      expect(container.read(gameSessionProvider)!.votes, hasLength(3));
      expect(find.text('Результаты голосования'), findsOneWidget);
    });

    testWidgets('a fast vote runs with a full table of 12', (tester) async {
      final container = await playToVoting(tester,
          fast: true, size: const Size(1170, 2532), players: 12);

      Future<void> tapText(String label) async {
        await tester.ensureVisible(find.text(label).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).first);
        await tester.pumpAndSettle();
      }

      for (var i = 0; i < 12; i++) {
        expect(find.text('ГОЛОС ${i + 1} ИЗ 12'), findsOneWidget);
        final session = container.read(gameSessionProvider)!;
        final voter = session.players[session.currentVotingIndex];
        await tapText(voter.name == 'Игрок1' ? 'Игрок0' : 'Игрок1');
        await tapText('Подтвердить голос');
      }
      expect(container.read(gameSessionProvider)!.votes, hasLength(12));
      expect(container.read(gameSessionProvider)!.phase, GamePhase.voteResult);
    });

    testWidgets('the toggle is in the game settings and drives the config',
        (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [wordPackProvider.overrideWithValue(_pack)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const UndercoverApp()),
      );
      await tester.pumpAndSettle();

      // A rule of play, so it is in the app settings behind the home gear —
      // not on the setup screen, which only shapes the pool.
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      await _toggleByTitle(tester, 'Быстрые ответы');
      expect(find.text('Сразу к выбору игрока, без экранов передачи'),
          findsOneWidget);
      expect(container.read(gameSetupProvider).fastVoting, isTrue);
    });
  });
}
