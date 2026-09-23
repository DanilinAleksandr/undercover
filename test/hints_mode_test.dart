import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undercover/app.dart';
import 'package:undercover/logic/hint_policy.dart';
import 'package:undercover/models/difficulty.dart';
import 'package:undercover/models/game_config.dart';
import 'package:undercover/models/word_category.dart';
import 'package:undercover/models/word_pair.dart';
import 'package:undercover/providers/game_session_provider.dart';
import 'package:undercover/providers/game_setup_provider.dart';
import 'package:undercover/providers/word_pack_provider.dart';

/// «Подсказки» is a per-party switch, not a rewrite of the hint system: with
/// it off the round never asks the policy, so the quiet link under the card
/// does not exist. The policy itself and the authored clues are untouched.

/// A single hard pair whose two words both have authored hints, so the link is
/// guaranteed to appear when hints are on.
const _hardPack = [
  WordCategory(
    id: 'hard',
    name: 'Сложная',
    icon: Icons.science,
    pairs: [
      WordPair('Маяк', 'Прожектор', Difficulty.hard, ['свет в темноте'], 5),
    ],
  ),
];

Future<ProviderContainer> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [wordPackProvider.overrideWithValue(_hardPack)],
  );
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

/// Walks to the filter step with three players.
Future<void> _toFilters(WidgetTester tester) async {
  await _tap(tester, 'Новая игра');
  for (var i = 0; i < 2; i++) {
    await tester.tap(find.byKey(const ValueKey('remove-player-0')));
    await tester.pumpAndSettle();
  }
  for (var i = 0; i < 3; i++) {
    await tester.enterText(find.byKey(ValueKey('player-name-$i')), 'И${i + 1}');
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Далее'));
  await tester.pumpAndSettle();
}

/// From the setup screen out to the home gear and into the app settings,
/// where the rules of play now live.
Future<void> _openGameSettings(WidgetTester tester) async {
  // Two steps of setup to back out of before the home gear is in reach.
  while (find.byTooltip('Назад').evaluate().isNotEmpty) {
    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
}

/// Back out of the app settings and into a fresh setup screen.
Future<void> _backToSetup(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pumpAndSettle();
  await _tap(tester, 'Новая игра');
}

/// Hands the phone over and holds the card open.
Future<void> _revealCurrentCard(WidgetTester tester) async {
  await _tap(tester, 'Это я, показать карту');
  final gesture = await tester
      .startGesture(tester.getCenter(find.byKey(const ValueKey('reveal-card'))));
  await tester.pump(const Duration(milliseconds: 1200));
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> _startAndRevealFirstCard(WidgetTester tester) async {
  await _tap(tester, 'Начать игру');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 2200));
  await tester.pumpAndSettle();

  await _tap(tester, 'Это я, показать карту');
  final gesture = await tester
      .startGesture(tester.getCenter(find.byKey(const ValueKey('reveal-card'))));
  await tester.pump(const Duration(milliseconds: 1200));
  await gesture.up();
  await tester.pumpAndSettle();
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

  group('the setting itself', () {
    test('hints are on by default, so nothing changes for an existing table',
        () {
      const config = GameConfig(playerNames: ['А', 'Б', 'В']);
      expect(config.hintsEnabled, isTrue);
      expect(GameConfig.initial.hintsEnabled, isTrue);
    });

    test('the notifier stores it without disturbing the other filters', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(gameSetupProvider.notifier);

      notifier.toggleDifficulty(Difficulty.hard);
      notifier.setAlcoMode(true);
      notifier.setHintsEnabled(false);

      final config = container.read(gameSetupProvider);
      expect(config.hintsEnabled, isFalse);
      expect(config.selectedDifficulties, {Difficulty.hard});
      expect(config.alcoModeEnabled, isTrue);

      notifier.setHintsEnabled(true);
      expect(container.read(gameSetupProvider).hintsEnabled, isTrue);
    });

    test('it travels with the session, not in a global', () {
      final container = ProviderContainer(
        overrides: [wordPackProvider.overrideWithValue(_hardPack)],
      );
      addTearDown(container.dispose);
      container.read(gameSetupProvider.notifier).setHintsEnabled(false);
      container
          .read(gameSessionProvider.notifier)
          .startGame(container.read(gameSetupProvider));
      expect(container.read(gameSessionProvider)!.config.hintsEnabled, isFalse);
    });

    test('the policy behind the switch is untouched', () {
      // The switch decides whether the round asks; what the answer is stays
      // exactly as it was.
      expect(maxHintsFor(Difficulty.hard), 1);
      expect(maxHintsFor(Difficulty.expert), 3);
      expect(maxHintsFor(Difficulty.easy), 0);
      expect(hintsFor('Маяк', Difficulty.hard), hasLength(1));
    });
  });

  group('in a round', () {
    testWidgets('with hints on, a hard card offers the link', (tester) async {
      final container = await _pump(tester);
      await _toFilters(tester);
      expect(container.read(gameSetupProvider).hintsEnabled, isTrue);

      await _startAndRevealFirstCard(tester);
      expect(find.text('Слово незнакомо?'), findsOneWidget);

      // And it still opens the authored clue.
      await _tap(tester, 'Слово незнакомо?');
      // Whoever holds the card, the clue is the authored one for their word.
      final clues = [
        'Стоит на берегу и светит далеко в темноту',
        'Даёт узкий мощный луч на стадионе или сцене',
      ];
      expect(clues.where((c) => find.text(c).evaluate().isNotEmpty), hasLength(1),
          reason: 'the authored clue itself, unchanged by the switch');
    });

    testWidgets('with hints off, the link never appears', (tester) async {
      final container = await _pump(tester);
      await _toFilters(tester);

      await _openGameSettings(tester);
      expect(find.text('Подсказки'), findsOneWidget);
      await _toggleByTitle(tester, 'Подсказки');
      expect(container.read(gameSetupProvider).hintsEnabled, isFalse);
      await _backToSetup(tester);
      // Step two: the round starts from the party settings.
      await _tap(tester, 'Далее');
      await _tap(tester, 'Начать игру');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();
      await _revealCurrentCard(tester);
      expect(container.read(gameSessionProvider)!.wordPair.difficulty,
          Difficulty.hard,
          reason: 'the round must be one that would normally offer help');
      expect(find.text('Слово незнакомо?'), findsNothing);

      // The card itself is unaffected: the word is still there to memorise.
      await _tap(tester, 'Я запомнил слово');
      expect(find.text('Это я, показать карту'), findsOneWidget);
    });

    testWidgets('the switch is remembered for the next card too', (tester) async {
      final container = await _pump(tester);
      await _toFilters(tester);
      await _openGameSettings(tester);
      await _toggleByTitle(tester, 'Подсказки');
      await _backToSetup(tester);
      // Step two: the round starts from the party settings.
      await _tap(tester, 'Далее');
      await _tap(tester, 'Начать игру');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();
      await _revealCurrentCard(tester);
      await _tap(tester, 'Я запомнил слово');
      // Second player, same round, still no link.
      await _tap(tester, 'Это я, показать карту');
      final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('reveal-card'))));
      await tester.pump(const Duration(milliseconds: 1200));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('Слово незнакомо?'), findsNothing);
      expect(container.read(gameSessionProvider)!.config.hintsEnabled, isFalse);
    });
  });
}
