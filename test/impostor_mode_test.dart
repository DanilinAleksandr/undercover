import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undercover/app.dart';
import 'package:undercover/data/theme_pack_registry.dart';
import 'package:undercover/data/word_hints.dart';
import 'package:undercover/data/word_pack_registry.dart';
import 'package:undercover/logic/game_rules.dart';
import 'package:undercover/logic/hint_policy.dart';
import 'package:undercover/models/difficulty.dart';
import 'package:undercover/models/game_config.dart';
import 'package:undercover/models/game_mode.dart';
import 'package:undercover/models/game_phase.dart';
import 'package:undercover/models/game_result.dart';
import 'package:undercover/models/theme_pair.dart';
import 'package:undercover/models/word_category.dart';
import 'package:undercover/providers/game_session_provider.dart';
import 'package:undercover/providers/game_setup_provider.dart';
import 'package:undercover/providers/word_pack_provider.dart';

/// «Самозванец»: a theme for everybody, a neighbouring theme — or nothing —
/// for one player. The round is spoken aloud; everything the app does after
/// the cards is the ordinary game, reused as it is.

const _theme = 'Футбол';
const _decoy = 'Хоккей';

final _pack = <WordCategory>[
  const ThemeCategory(
    id: 'theme_test',
    name: 'Темы',
    icon: Icons.theater_comedy,
    pairs: [ThemePair(_theme, _decoy, Difficulty.easy, 5)],
  ).toWordCategory(),
];

ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [wordPackProvider.overrideWithValue(_pack)],
  );
  addTearDown(container.dispose);
  return container;
}

GameConfig _config({bool seesDecoy = true}) => GameConfig(
      playerNames: const ['Аня', 'Боря', 'Вика'],
      gameMode: GameMode.impostor,
      impostorSeesDecoy: seesDecoy,
    );

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('a theme pair plays as an ordinary pair', () {
    test('the theme goes to the majority and the decoy to the impostor', () {
      final pair = const ThemePair(_theme, _decoy, Difficulty.hard, 4)
          .toWordPair();
      expect(pair.civilianWord, _theme);
      expect(pair.spyWord, _decoy);
      expect(pair.difficulty, Difficulty.hard);
      expect(pair.score, 4);
      expect(pair.gameMode, GameMode.impostor);
      expect(pair.tags, isEmpty);
    });

    test('a theme pack keeps its identity in the shared shape', () {
      final category = themeGamesCategory().toWordCategory();
      expect(category.id, themeGamesCategory().id);
      expect(category.name, themeGamesCategory().name);
      expect(category.pairs, hasLength(themeGamesCategory().pairs.length));
      expect(category.pairs.every((p) => p.gameMode == GameMode.impostor),
          isTrue);
    });

    test('themes are dealt from the game base but vetted apart from words', () {
      final themeIds = {for (final c in allThemeCategories) c.id};
      expect(allGameCategories.map((c) => c.id), containsAll(themeIds));
      // The word rules — tags, stems, 13 letters — were never meant for
      // «Souls-игры FromSoftware»; the themes have their own checks.
      expect(allWordCategories.map((c) => c.id).toSet().intersection(themeIds),
          isEmpty);
    });

    test('a round in the mode deals a theme pair', () async {
      final container = _container();
      expect(
          container.read(gameSessionProvider.notifier).startGame(_config()),
          isTrue);
      final session = container.read(gameSessionProvider)!;
      expect(session.wordPair.gameMode, GameMode.impostor);
      expect(session.wordPair.civilianWord, _theme);
      expect(session.wordPair.spyWord, _decoy);
      await _settle();
    });

    test('no hints ever reach a theme, whatever the tier', () {
      // A word that does have authored hints, asked for as a theme.
      final hinted = wordHints.keys.first;
      // Control: the same word does get help in its own mode, so the empty
      // lists below are the gate at work and not a word without hints.
      expect(hintsFor(hinted, Difficulty.expert), isNotEmpty);
      for (final level in Difficulty.values) {
        expect(hintsFor(hinted, level, mode: GameMode.impostor), isEmpty);
      }
    });
  });

  group('what the impostor sees', () {
    test('by default the impostor is dealt the decoy', () {
      expect(GameConfig.initial.impostorSeesDecoy, isTrue);
      expect(_container().read(gameSetupProvider).impostorSeesDecoy, isTrue);
    });

    test('the choice is remembered between launches', () async {
      final first = _container();
      first.read(gameSetupProvider);
      await _settle();
      first.read(gameSetupProvider.notifier).setImpostorSeesDecoy(false);
      await _settle();

      final second = _container();
      second.read(gameSetupProvider);
      await _settle();
      expect(second.read(gameSetupProvider).impostorSeesDecoy, isFalse);
    });

    test('a running round keeps the value it was dealt with', () async {
      final container = _container();
      container
          .read(gameSessionProvider.notifier)
          .startGame(_config(seesDecoy: false));
      // The in-game toggles resync the round; this one is not among them,
      // because it decides what cards already shown have said.
      container
          .read(gameSessionProvider.notifier)
          .syncLiveSettings(_config(seesDecoy: true));
      expect(container.read(gameSessionProvider)!.config.impostorSeesDecoy,
          isFalse);
      await _settle();
    });
  });

  group('the vote is the ordinary vote', () {
    test('catching the impostor leads to the guess, missing ends the round',
        () async {
      final container = _container();
      final notifier = container.read(gameSessionProvider.notifier);
      notifier.startGame(_config(seesDecoy: false)
          .copyWith(alcoModeEnabled: true));
      final session = container.read(gameSessionProvider)!;

      notifier.castUnanimousVote(session.spyPlayerId);
      expect(container.read(gameSessionProvider)!.voteResult!.spyWasCaught,
          isTrue);
      notifier.proceedFromVoteResult();
      expect(container.read(gameSessionProvider)!.phase, GamePhase.spyGuess);
      notifier.resolveSpyGuess(correct: false);
      final result = container.read(gameSessionProvider)!.result!;
      expect(result.outcome, Outcome.civiliansWin);
      expect(result.penalty,
          derivePenalty(Outcome.civiliansWin, true));
      await _settle();
    });
  });

  group('on the card', () {
    Future<ProviderContainer> pumpRound(WidgetTester tester,
        {required bool seesDecoy, required bool showRoles}) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = _container();
      final setup = container.read(gameSetupProvider.notifier);
      setup.setRoster(const ['Аня', 'Боря', 'Вика']);
      setup.setGameMode(GameMode.impostor);
      setup.setImpostorSeesDecoy(seesDecoy);
      setup.setShowRoles(showRoles);

      await tester.pumpWidget(UncontrolledProviderScope(
          container: container, child: const UndercoverApp()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Новая игра'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Далее'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Начать игру'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();
      return container;
    }

    /// Opens every card in turn and records what each player was shown.
    ///
    /// The card flips back when the finger lifts, so each one is read while
    /// the gesture is down.
    Future<Map<String, _Seen>> walkCards(
        WidgetTester tester, ProviderContainer container) async {
      final seen = <String, _Seen>{};
      final count = container.read(gameSessionProvider)!.players.length;
      for (var i = 0; i < count; i++) {
        await tester.tap(find.text('Это я, показать карту'));
        await tester.pumpAndSettle();
        final session = container.read(gameSessionProvider)!;
        final player = session.players[session.currentRevealIndex];
        final gesture = await tester.startGesture(
            tester.getCenter(find.byKey(const ValueKey('reveal-card'))));
        await tester.pump(const Duration(milliseconds: 1200));
        await tester.pumpAndSettle();
        seen[player.id] = _Seen(
          theme: find.text(_theme).evaluate().isNotEmpty,
          decoy: find.text(_decoy).evaluate().isNotEmpty,
          blind: find.text('Ты — Самозванец').evaluate().isNotEmpty,
          impostorLabel: find.text('САМОЗВАНЕЦ').evaluate().isNotEmpty,
        );
        expect(tester.takeException(), isNull);
        await gesture.up();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Я запомнил слово'));
        await tester.pumpAndSettle();
      }
      return seen;
    }

    testWidgets('with a decoy: the table sees the theme, the impostor the decoy',
        (tester) async {
      final container =
          await pumpRound(tester, seesDecoy: true, showRoles: false);
      final spyId = container.read(gameSessionProvider)!.spyPlayerId;
      final seen = await walkCards(tester, container);

      for (final entry in seen.entries) {
        final isSpy = entry.key == spyId;
        expect(entry.value.theme, !isSpy, reason: entry.key);
        expect(entry.value.decoy, isSpy, reason: entry.key);
        expect(entry.value.blind, isFalse, reason: entry.key);
        // Roles hidden: a decoy impostor may not even know they are one.
        expect(entry.value.impostorLabel, isFalse, reason: entry.key);
      }
    });

    testWidgets('without a decoy: the impostor is told so and shown no theme',
        (tester) async {
      final container =
          await pumpRound(tester, seesDecoy: false, showRoles: false);
      final spyId = container.read(gameSessionProvider)!.spyPlayerId;
      final seen = await walkCards(tester, container);

      for (final entry in seen.entries) {
        final isSpy = entry.key == spyId;
        expect(entry.value.blind, isSpy, reason: entry.key);
        expect(entry.value.theme, !isSpy, reason: entry.key);
        // Nobody sees the decoy — it was never dealt to a card.
        expect(entry.value.decoy, isFalse, reason: entry.key);
      }
    });

    testWidgets('with roles shown, the impostor is called by its own name',
        (tester) async {
      final container =
          await pumpRound(tester, seesDecoy: true, showRoles: true);
      final spyId = container.read(gameSessionProvider)!.spyPlayerId;
      final seen = await walkCards(tester, container);
      for (final entry in seen.entries) {
        expect(entry.value.impostorLabel, entry.key == spyId,
            reason: entry.key);
      }
      expect(find.text('ШПИОН'), findsNothing);
    });

    testWidgets('the blind card fits a 320pt phone', (tester) async {
      final container =
          await pumpRound(tester, seesDecoy: false, showRoles: false);
      // pumpRound set a larger size; this test wants the small one.
      tester.view.physicalSize = const Size(960, 1704);
      await tester.pumpAndSettle();
      final seen = await walkCards(tester, container);
      expect(seen.values.where((s) => s.blind), hasLength(1));
    });
  });

  group('in the party settings', () {
    Future<ProviderContainer> pumpSettings(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = _container();
      container
          .read(gameSetupProvider.notifier)
          .setRoster(const ['Аня', 'Боря', 'Вика']);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container, child: const UndercoverApp()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Новая игра'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Далее'));
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('the choice appears only in «Самозванец»', (tester) async {
      final container = await pumpSettings(tester);
      container.read(gameSetupProvider.notifier).setGameMode(GameMode.words);
      await tester.pumpAndSettle();
      expect(find.text('Что видит самозванец'), findsNothing);

      container.read(gameSetupProvider.notifier).setGameMode(GameMode.impostor);
      await tester.pumpAndSettle();
      expect(find.text('Что видит самозванец'), findsOneWidget);
      // The words-only row goes with its mode.
      expect(find.text('Тип контента'), findsNothing);

      await tester.ensureVisible(find.text('Ничего'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ничего'));
      await tester.pumpAndSettle();
      expect(container.read(gameSetupProvider).impostorSeesDecoy, isFalse);

      await tester.tap(find.text('Похожую тему'));
      await tester.pumpAndSettle();
      expect(container.read(gameSetupProvider).impostorSeesDecoy, isTrue);
    });
  });
}

ThemeCategory themeGamesCategory() => allThemeCategories.first;

class _Seen {
  final bool theme;
  final bool decoy;
  final bool blind;
  final bool impostorLabel;

  const _Seen({
    required this.theme,
    required this.decoy,
    required this.blind,
    required this.impostorLabel,
  });
}
