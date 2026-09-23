import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undercover/app.dart';
import 'package:undercover/logic/game_rules.dart';
import 'package:undercover/models/difficulty.dart';
import 'package:undercover/models/game_config.dart';
import 'package:undercover/models/game_result.dart';
import 'package:undercover/models/vote.dart';
import 'package:undercover/models/game_mode.dart';
import 'package:undercover/models/word_category.dart';
import 'package:undercover/models/word_pair.dart';
import 'package:undercover/providers/game_session_provider.dart';
import 'package:undercover/providers/game_setup_provider.dart';
import 'package:undercover/providers/word_pack_provider.dart';

/// «Показывать роль» is a presentation switch, and these tests exist to keep
/// it one: the same config, the same pair and the same spy have to produce the
/// same game either way. Only what the card tells the player changes.

const _e = Difficulty.easy;

/// One pair per mode, so the round a test deals is never in doubt.
WordCategory _cat(String id, GameMode mode, WordPair pair) => WordCategory(
      id: id,
      name: id,
      icon: Icons.abc,
      pairs: [pair],
    );

final _pack = [
  _cat('w', GameMode.words,
      const WordPair('Париж', 'Лондон', _e, ['город', 'столица'], 5)),
  _cat('p', GameMode.people,
      const WordPair('Моцарт', 'Бетховен', _e, ['музыка', 'парик'], 5,
          mode: GameMode.people)),
  _cat('l', GameMode.places,
      const WordPair('Маяк', 'Радиовышка', _e, ['башня', 'сигнал'], 5,
          mode: GameMode.places)),
];

ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [wordPackProvider.overrideWithValue(_pack)],
  );
  addTearDown(container.dispose);
  return container;
}

GameConfig _config(GameMode mode, {required bool showRoles}) => GameConfig(
      playerNames: const ['Аня', 'Боря', 'Вика', 'Гоша'],
      gameMode: mode,
      showRoles: showRoles,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the setting itself', () {
    test('a fresh config shows roles', () {
      expect(const GameConfig(playerNames: []).showRoles, isTrue);
      expect(GameConfig.initial.showRoles, isTrue);
    });

    test('turning it off changes nothing else about the config', () {
      const before = GameConfig(
        playerNames: ['Аня', 'Боря', 'Вика'],
        gameMode: GameMode.places,
        selectedCategoryIds: {'place_odd'},
        selectedDifficulties: {Difficulty.hard},
        allowAdultContent: true,
        hintsEnabled: false,
        fastVoting: true,
        alcoModeEnabled: true,
      );
      final after = before.copyWith(showRoles: false);

      expect(after.showRoles, isFalse);
      expect(after.playerNames, before.playerNames);
      expect(after.gameMode, before.gameMode);
      expect(after.selectedCategoryIds, before.selectedCategoryIds);
      expect(after.selectedDifficulties, before.selectedDifficulties);
      expect(after.selectedContentTypes, before.selectedContentTypes);
      expect(after.allowAdultContent, before.allowAdultContent);
      expect(after.hintsEnabled, before.hintsEnabled);
      expect(after.fastVoting, before.fastVoting);
      expect(after.alcoModeEnabled, before.alcoModeEnabled);
    });
  });

  group('the round is identical either way', () {
    for (final mode in GameMode.values) {
      test('${mode.name}: the same pair is dealt with roles hidden', () {
        final shown = _container();
        final hidden = _container();
        expect(
            shown
                .read(gameSessionProvider.notifier)
                .startGame(_config(mode, showRoles: true)),
            isTrue);
        expect(
            hidden
                .read(gameSessionProvider.notifier)
                .startGame(_config(mode, showRoles: false)),
            isTrue);

        final a = shown.read(gameSessionProvider)!;
        final b = hidden.read(gameSessionProvider)!;
        expect(b.wordPair.id, a.wordPair.id);
        expect(b.wordPair.gameMode, a.wordPair.gameMode);
      });

      test('${mode.name}: exactly one spy is dealt with roles hidden', () {
        final container = _container();
        container
            .read(gameSessionProvider.notifier)
            .startGame(_config(mode, showRoles: false));
        final session = container.read(gameSessionProvider)!;

        expect(session.players.where((p) => p.id == session.spyPlayerId),
            hasLength(1));
        expect(session.civilians, hasLength(session.players.length - 1));
        // The spy still holds the other word: hiding the label does not hide
        // the asymmetry the game is built on.
        expect(session.spyPlayer.id, session.spyPlayerId);
        expect(session.wordPair.spyWord, isNot(session.wordPair.civilianWord));
      });
    }

    test('the vote is counted by the same rules', () {
      for (final showRoles in [true, false]) {
        final container = _container();
        container
            .read(gameSessionProvider.notifier)
            .startGame(_config(GameMode.words, showRoles: showRoles));
        final session = container.read(gameSessionProvider)!;
        final spy = session.spyPlayer;

        final result = tallyVotes(
          session.players,
          [
            for (final p in session.players)
              Vote(voterId: p.id, targetId: spy.id),
          ],
          session.spyPlayerId,
        );
        expect(result.spyWasCaught, isTrue, reason: 'showRoles=$showRoles');
        expect(result.isTie, isFalse);
        expect(deriveOutcome(result, spyGuessedCorrectly: false),
            Outcome.civiliansWin);
        expect(deriveOutcome(result, spyGuessedCorrectly: true),
            Outcome.spyWinsByGuess);
      }
    });
  });

  group('on the card', () {
    Future<ProviderContainer> pumpRound(WidgetTester tester,
        {required GameMode mode, required bool showRoles}) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [wordPackProvider.overrideWithValue(_pack)],
      );
      addTearDown(container.dispose);
      final setup = container.read(gameSetupProvider.notifier);
      setup.setRoster(const ['Аня', 'Боря', 'Вика', 'Гоша']);
      setup.setGameMode(mode);
      setup.setShowRoles(showRoles);

      await tester.pumpWidget(UncontrolledProviderScope(
          container: container, child: const UndercoverApp()));
      await tester.pumpAndSettle();
      // Through the UI, so the round carries the config the host actually set.
      await tester.tap(find.text('Новая игра'));
      await tester.pumpAndSettle();
      // Step two: the round starts from the party settings.
      await tester.tap(find.text('Далее'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Начать игру'));
      await tester.pumpAndSettle();
      return container;
    }

    /// Walks to the first card and holds it open.
    ///
    /// The card flips back the moment the finger lifts, so the caller has to
    /// read it while the gesture is still down — and release it afterwards.
    Future<TestGesture> revealFirst(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Это я, показать карту'));
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('reveal-card'))));
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pumpAndSettle();
      return gesture;
    }

    for (final mode in GameMode.values) {
      testWidgets('${mode.name}: the role is named when the party asks for it',
          (tester) async {
        final container =
            await pumpRound(tester, mode: mode, showRoles: true);
        final gesture = await revealFirst(tester);

        final session = container.read(gameSessionProvider)!;
        final isSpy = session.players.first.id == session.spyPlayerId;
        expect(find.text(isSpy ? 'ШПИОН' : 'МИРНЫЙ'), findsOneWidget);
        expect(find.text(isSpy ? 'Не выдай себя' : 'Найди шпиона'),
            findsOneWidget);
        await gesture.up();
      });

      testWidgets('${mode.name}: nothing on the card names the role when hidden',
          (tester) async {
        final container =
            await pumpRound(tester, mode: mode, showRoles: false);
        final gesture = await revealFirst(tester);

        expect(find.text('ШПИОН'), findsNothing);
        expect(find.text('МИРНЫЙ'), findsNothing);
        expect(find.text('Не выдай себя'), findsNothing);
        expect(find.text('Найди шпиона'), findsNothing);
        expect(find.byIcon(Icons.visibility_off_rounded), findsNothing);
        expect(find.byIcon(Icons.groups_rounded), findsNothing);
        // The footer is the same sentence for everyone, so it cannot be read
        // as an instruction addressed to one role.
        expect(find.text('Никому не показывай'), findsOneWidget);

        // But the answer itself is still there — that is the whole point.
        final session = container.read(gameSessionProvider)!;
        final isSpy = session.players.first.id == session.spyPlayerId;
        final word = isSpy
            ? session.wordPair.spyWord
            : session.wordPair.civilianWord;
        expect(find.text(word), findsOneWidget);
        await gesture.up();
      });
    }

  });
}
