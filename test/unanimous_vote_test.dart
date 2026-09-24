import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undercover/app.dart';
import 'package:undercover/models/difficulty.dart';
import 'package:undercover/models/game_config.dart';
import 'package:undercover/models/game_phase.dart';
import 'package:undercover/models/word_category.dart';
import 'package:undercover/models/word_pair.dart';
import 'package:undercover/providers/game_session_provider.dart';
import 'package:undercover/providers/game_setup_provider.dart';
import 'package:undercover/providers/word_pack_provider.dart';

/// «Единогласно» is a shortcut through the ballot, not a second set of rules.
///
/// The table has already said out loud who it thinks the spy is, so passing
/// the phone round to collect secret votes only slows the evening down. What
/// these tests watch is that the shortcut really is one: the same `tallyVotes`
/// decides the round, so the result, the alco penalty and the win condition
/// cannot drift away from the ordinary path.

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

/// Starts a round and walks it to the moment the ballot opens.
ProviderContainer _atVoting({bool fastVoting = false}) {
  final container = _container();
  final notifier = container.read(gameSessionProvider.notifier);
  notifier.startGame(_config(fastVoting: fastVoting));
  notifier.startVoting();
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the outcome comes from the ordinary tally', () {
    test('picking the spy catches the spy', () {
      final container = _atVoting();
      final spyId = container.read(gameSessionProvider)!.spyPlayerId;
      container.read(gameSessionProvider.notifier).castUnanimousVote(spyId);

      final session = container.read(gameSessionProvider)!;
      expect(session.phase, GamePhase.voteResult);
      expect(session.voteResult!.spyWasCaught, isTrue);
      expect(session.voteResult!.majorityTargetId, spyId);
      expect(session.voteResult!.isTie, isFalse,
          reason: 'one ballot cannot tie with anything');
    });

    test('picking an innocent does not', () {
      final container = _atVoting();
      final session = container.read(gameSessionProvider)!;
      final innocent =
          session.players.firstWhere((p) => p.id != session.spyPlayerId);
      container
          .read(gameSessionProvider.notifier)
          .castUnanimousVote(innocent.id);

      final after = container.read(gameSessionProvider)!;
      expect(after.phase, GamePhase.voteResult);
      expect(after.voteResult!.spyWasCaught, isFalse);
      expect(after.voteResult!.majorityTargetId, innocent.id);
      expect(after.voteResult!.isTie, isFalse);
    });

    test('the result is identical to a full vote for the same player', () {
      VoteOutcome outcomeOf(void Function(ProviderContainer) vote) {
        final container = _atVoting();
        vote(container);
        final r = container.read(gameSessionProvider)!.voteResult!;
        return (
          caught: r.spyWasCaught,
          tie: r.isTie,
          // The tally is keyed by generated player ids, so compare the shape
          // of the outcome rather than the ids themselves.
          topVotes: r.majorityTargetId == null ? 0 : r.tally[r.majorityTargetId]!,
        );
      }

      final unanimous = outcomeOf((c) {
        final spyId = c.read(gameSessionProvider)!.spyPlayerId;
        c.read(gameSessionProvider.notifier).castUnanimousVote(spyId);
      });
      final byHand = outcomeOf((c) {
        final notifier = c.read(gameSessionProvider.notifier);
        final spyId = c.read(gameSessionProvider)!.spyPlayerId;
        final total = c.read(gameSessionProvider)!.players.length;
        for (var i = 0; i < total; i++) {
          final session = c.read(gameSessionProvider)!;
          final voter = session.players[session.currentVotingIndex];
          // Nobody votes for themselves, so the spy votes for a neighbour and
          // the majority is one short of the whole table.
          notifier.castVote(voter.id == spyId
              ? session.players.firstWhere((p) => p.id != spyId).id
              : spyId);
        }
        return;
      });

      expect(unanimous.caught, byHand.caught);
      expect(unanimous.tie, byHand.tie);
    });

    test('a caught spy still gets the guess, an innocent still ends it', () {
      final caught = _atVoting();
      caught
          .read(gameSessionProvider.notifier)
          .castUnanimousVote(caught.read(gameSessionProvider)!.spyPlayerId);
      caught.read(gameSessionProvider.notifier).proceedFromVoteResult();
      expect(caught.read(gameSessionProvider)!.phase, GamePhase.spyGuess,
          reason: 'the spy gets the same last word as after a normal vote');

      final missed = _atVoting();
      final session = missed.read(gameSessionProvider)!;
      missed.read(gameSessionProvider.notifier).castUnanimousVote(
          session.players.firstWhere((p) => p.id != session.spyPlayerId).id);
      missed.read(gameSessionProvider.notifier).proceedFromVoteResult();
      expect(missed.read(gameSessionProvider)!.phase, GamePhase.winner);
    });
  });

  group('the shortcut is honest about what happened', () {
    test('one ballot is recorded, and it belongs to nobody', () {
      final container = _atVoting();
      final spyId = container.read(gameSessionProvider)!.spyPlayerId;
      container.read(gameSessionProvider.notifier).castUnanimousVote(spyId);

      final session = container.read(gameSessionProvider)!;
      expect(session.votes, hasLength(1));
      expect(session.votes.single.voterId, unanimousVoterId);
      expect(session.votes.single.targetId, spyId);
      expect(session.players.map((p) => p.id), isNot(contains(unanimousVoterId)),
          reason: 'the synthetic voter must not collide with a real player');
    });

    test('nobody is marked as having voted, and the queue never moved', () {
      final container = _atVoting();
      container
          .read(gameSessionProvider.notifier)
          .castUnanimousVote(container.read(gameSessionProvider)!.players[1].id);

      final session = container.read(gameSessionProvider)!;
      expect(session.players.every((p) => !p.hasVoted), isTrue);
      expect(session.currentVotingIndex, 0);
    });

    test('it does nothing at all when no game is running', () {
      final container = _container();
      container.read(gameSessionProvider.notifier).castUnanimousVote('whoever');
      expect(container.read(gameSessionProvider), isNull);
    });
  });

  group('on screen', () {
    Future<ProviderContainer> playToBallot(WidgetTester tester,
        {Size size = const Size(1170, 2532)}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [wordPackProvider.overrideWithValue(_pack)],
      );
      addTearDown(container.dispose);
      // The fast pace only removes the hand-off screens between ballots; it
      // has nothing to do with the unanimous path, it just makes the walk to
      // the ballot short enough to read.
      container.read(gameSetupProvider.notifier).setFastVoting(true);
      await tester.pumpWidget(
        UncontrolledProviderScope(
            container: container, child: const UndercoverApp()),
      );
      await tester.pumpAndSettle();

      Future<void> tap(String label) async {
        await tester.ensureVisible(find.text(label).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).first);
        await tester.pumpAndSettle();
      }

      await tap('Новая игра');
      await tester.tap(find.byKey(const ValueKey('remove-player-0')));
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await tester.enterText(find.byKey(ValueKey('player-name-$i')), 'Игрок$i');
        await tester.pumpAndSettle();
      }
      await tap('Далее');
      await tap('Начать игру');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();

      for (var i = 0; i < 4; i++) {
        await tap('Это я, показать карту');
        final gesture = await tester.startGesture(
            tester.getCenter(find.byKey(const ValueKey('reveal-card'))));
        await tester.pump(const Duration(milliseconds: 1200));
        await gesture.up();
        await tester.pumpAndSettle();
        await tap('Я запомнил слово');
      }
      await tap('Готовы голосовать');
      expect(container.read(gameSessionProvider)!.phase, GamePhase.voting);
      return container;
    }

    Future<void> tapText(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.text(label).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
    }

    testWidgets('the offer is there before the first ballot and gone after',
        (tester) async {
      final container = await playToBallot(tester);
      expect(find.text('Все и так согласны'), findsOneWidget);

      // One secret vote, and "everyone agrees" stops being true of the room.
      final session = container.read(gameSessionProvider)!;
      await tapText(tester, session.players[1].name);
      await tapText(tester, 'Подтвердить голос');
      expect(container.read(gameSessionProvider)!.currentVotingIndex, 1);
      expect(find.text('Все и так согласны'), findsNothing);
    });

    testWidgets('the table may pick the player whose turn it formally is',
        (tester) async {
      final container = await playToBallot(tester);
      final voter = container.read(gameSessionProvider)!.players.first;

      // In an ordinary ballot this tap does nothing: you cannot vote for
      // yourself. The whole table choosing together is a different question.
      await tapText(tester, voter.name);
      expect(find.text('Решение принято — подтвердите'), findsNothing);

      await tapText(tester, 'Все и так согласны');
      expect(find.text('Кто шпион?'), findsOneWidget,
          reason: 'no longer anybody\'s turn');
      await tapText(tester, voter.name);
      expect(find.text('Выбор стола — подтвердите'), findsOneWidget);
    });

    testWidgets('it asks before skipping the vote, and a refusal changes nothing',
        (tester) async {
      final container = await playToBallot(tester);
      await tapText(tester, 'Все и так согласны');
      await tapText(tester, container.read(gameSessionProvider)!.players[2].name);
      await tapText(tester, 'Выбрать единогласно');

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Выбрать единогласно?'), findsOneWidget);
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.text('Отмена')));
      await tester.pumpAndSettle();

      final session = container.read(gameSessionProvider)!;
      expect(session.phase, GamePhase.voting, reason: 'still on the ballot');
      expect(session.votes, isEmpty);
    });

    testWidgets('confirming ends the vote in one step', (tester) async {
      final container = await playToBallot(tester);
      final spyId = container.read(gameSessionProvider)!.spyPlayerId;
      final spy = container
          .read(gameSessionProvider)!
          .players
          .firstWhere((p) => p.id == spyId);

      await tapText(tester, 'Все и так согласны');
      await tapText(tester, spy.name);
      await tapText(tester, 'Выбрать единогласно');
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.text('Да, выбрать')));
      await tester.pumpAndSettle();

      final session = container.read(gameSessionProvider)!;
      expect(session.phase, GamePhase.voteResult,
          reason: 'straight to the result, with no phone going round');
      expect(session.voteResult!.spyWasCaught, isTrue);
      expect(session.votes, hasLength(1));
    });

    testWidgets('the extra line still fits a 320pt screen', (tester) async {
      // The ballot now carries a second button under the primary one, and
      // that is exactly the kind of addition a small screen refuses.
      final container =
          await playToBallot(tester, size: const Size(960, 1704));
      expect(tester.takeException(), isNull);
      expect(find.text('Все и так согласны'), findsOneWidget);

      await tapText(tester, 'Все и так согласны');
      expect(tester.takeException(), isNull);
      expect(find.text('Выбрать единогласно'), findsOneWidget);
      expect(find.text('Вернуться к голосованию'), findsOneWidget);
      expect(container.read(gameSessionProvider)!.phase, GamePhase.voting);
    });

    testWidgets('the table can change its mind and vote normally after all',
        (tester) async {
      final container = await playToBallot(tester);
      await tapText(tester, 'Все и так согласны');
      await tapText(tester, 'Вернуться к голосованию');

      final voter = container.read(gameSessionProvider)!.players.first;
      expect(find.text('${voter.name}, кто шпион?'), findsOneWidget);
      expect(find.text('Подтвердить голос'), findsOneWidget);
      expect(container.read(gameSessionProvider)!.votes, isEmpty);
    });
  });
}

/// The part of a vote result that has to match between the two paths.
typedef VoteOutcome = ({bool caught, bool tie, int topVotes});
