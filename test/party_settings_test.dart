import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undercover/app.dart';
import 'package:undercover/models/difficulty.dart';
import 'package:undercover/models/game_mode.dart';
import 'package:undercover/models/word_category.dart';
import 'package:undercover/models/word_pair.dart';
import 'package:undercover/providers/game_session_provider.dart';
import 'package:undercover/providers/game_setup_provider.dart';
import 'package:undercover/providers/last_roster_provider.dart';
import 'package:undercover/providers/word_pack_provider.dart';

/// Where a setting lives is decided by when it can still matter.
///
/// Step one is the line-up. Step two is what the party will be dealt from —
/// mode, categories, tiers, the words/phrases split — and it ends with the
/// start button, because changing any of it afterwards would describe a round
/// that was never dealt. Everything about *how* a party is played — alco, 18+,
/// hints, roles, pace — sits in the in-game settings next to the theme and the
/// played history, where a table can still change its mind.

const _e = Difficulty.easy;
const _m = Difficulty.medium;
const _h = Difficulty.hard;
const _x = Difficulty.expert;

/// The five that belong to a running game, and the four that never do.
const _inGame = [
  'Алко-режим',
  'Контент 18+',
  'Подсказки',
  'Показывать роль',
  'Быстрые ответы',
];
const _beforeGame = ['Режим игры', 'Категории', 'Сложность', 'Тип контента'];

const _pack = [
  WordCategory(id: 'w', name: 'Слова A', icon: Icons.abc, pairs: [
    WordPair('Париж', 'Лондон', _e, ['город', 'столица'], 5),
    WordPair('Кошка', 'Тигр', _m, ['усы', 'лапы'], 5),
    WordPair('Гиря', 'Якорь', _h, ['тяжесть', 'металл'], 5),
    WordPair('Заря', 'Полдень', _x, ['небо', 'время'], 5),
  ]),
  WordCategory(id: 'p', name: 'Люди A', icon: Icons.person, pairs: [
    WordPair('Моцарт', 'Бетховен', _e, ['музыка', 'парик'], 5,
        mode: GameMode.people),
    WordPair('Ньютон', 'Эйнштейн', _m, ['физика', 'формула'], 5,
        mode: GameMode.people),
  ]),
  WordCategory(id: 'l', name: 'Места A', icon: Icons.place, pairs: [
    WordPair('Маяк', 'Радиовышка', _e, ['башня', 'сигнал'], 5,
        mode: GameMode.places),
    WordPair('Бункер', 'Подлодка', _m, ['люки', 'без окон'], 5,
        mode: GameMode.places),
  ]),
  WordCategory(id: 't', name: 'Темы A', icon: Icons.theater_comedy, pairs: [
    WordPair('Футбол', 'Хоккей', _e, [], 5, mode: GameMode.impostor),
    WordPair('Марио', 'Соник', _m, [], 5, mode: GameMode.impostor),
  ]),
];

Future<ProviderContainer> _pumpHome(WidgetTester tester,
    {Size size = const Size(1170, 2532)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [wordPackProvider.overrideWithValue(_pack)],
  );
  addTearDown(container.dispose);
  // A line-up, so the tests can talk about the settings rather than about
  // typing names.
  container
      .read(gameSetupProvider.notifier)
      .setRoster(const ['Аня', 'Боря', 'Вика', 'Гоша']);
  await tester.pumpWidget(UncontrolledProviderScope(
      container: container, child: const UndercoverApp()));
  await tester.pumpAndSettle();
  return container;
}

/// Step one.
Future<ProviderContainer> _pumpPlayers(WidgetTester tester,
    {Size size = const Size(1170, 2532)}) async {
  final container = await _pumpHome(tester, size: size);
  await tester.tap(find.text('Новая игра'));
  await tester.pumpAndSettle();
  return container;
}

/// Step two.
Future<ProviderContainer> _pumpPartySettings(WidgetTester tester,
    {Size size = const Size(1170, 2532)}) async {
  final container = await _pumpPlayers(tester, size: size);
  await tester.tap(find.text('Далее'));
  await tester.pumpAndSettle();
  return container;
}

Future<void> _openGameSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
}

/// Brings a control into the build window, searching down and then back up.
Future<void> _scrollTo(WidgetTester tester, String label) async {
  for (final step in [-220.0, 220.0]) {
    for (var i = 0; i < 16 && find.text(label).evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView), Offset(0, step));
      await tester.pumpAndSettle();
    }
    if (find.text(label).evaluate().isNotEmpty) return;
  }
}

Future<void> _toggle(WidgetTester tester, String title) async {
  await _scrollTo(tester, title);
  final row = find.ancestor(of: find.text(title), matching: find.byType(Row));
  final sw = find.descendant(of: row.first, matching: find.byType(Switch));
  // A ListView builds a little beyond the viewport, so _scrollTo can stop with
  // the switch built but off screen — where a tap lands on nothing at all.
  await tester.ensureVisible(sw);
  await tester.pumpAndSettle();
  await tester.tap(sw);
  await tester.pumpAndSettle();
}

Future<void> _startRound(WidgetTester tester) async {
  await tester.tap(find.text('Начать игру'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 2200));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('step one: players', () {
    testWidgets('it holds the line-up and nothing else', (tester) async {
      await _pumpPlayers(tester);
      expect(find.text('Игроки · 4'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(4));
      expect(find.text('Добавить игрока'), findsOneWidget);
      expect(find.text('Далее'), findsOneWidget);

      // Neither group of settings is on this screen.
      for (final label in [..._beforeGame, ..._inGame]) {
        await _scrollTo(tester, label);
        expect(find.text(label), findsNothing, reason: label);
      }
      expect(find.text('Начать игру'), findsNothing);
    });

    testWidgets('«Далее» opens step two', (tester) async {
      await _pumpPlayers(tester);
      await tester.tap(find.text('Далее'));
      await tester.pumpAndSettle();

      expect(find.text('Настройки партии'), findsOneWidget);
      expect(find.text('Режим игры'), findsOneWidget);
      expect(find.text('Начать игру'), findsOneWidget);
    });
  });

  group('step two: what the party is dealt from', () {
    testWidgets('it holds the pool settings, and only those', (tester) async {
      await _pumpPartySettings(tester);
      for (final label in _beforeGame) {
        await _scrollTo(tester, label);
        expect(find.text(label), findsOneWidget, reason: label);
      }
      for (final label in _inGame) {
        await _scrollTo(tester, label);
        expect(find.text(label), findsNothing,
            reason: '$label is a rule of play, not of the pool');
      }
    });

    testWidgets('no preset and no hardcore anywhere on it', (tester) async {
      await _pumpPartySettings(tester);
      for (final label in [
        'Хардкор',
        'Быстрый пресет',
        'Пресет',
        'Только сложные пары и без подсказок',
      ]) {
        await _scrollTo(tester, label);
        expect(find.text(label), findsNothing, reason: label);
      }
    });

    testWidgets('the round starts from here', (tester) async {
      final container = await _pumpPartySettings(tester);
      await _startRound(tester);
      expect(container.read(gameSessionProvider), isNotNull);
    });
  });

  group('inside the round', () {
    testWidgets('the game settings hold the five, the history and the theme',
        (tester) async {
      await _pumpHome(tester);
      await _openGameSettings(tester);

      for (final label in [..._inGame, 'История ответов', 'Тема оформления']) {
        await _scrollTo(tester, label);
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // And nothing that would need the party dealt again.
      for (final label in [..._beforeGame, 'Хардкор']) {
        await _scrollTo(tester, label);
        expect(find.text(label), findsNothing, reason: label);
      }
    });

    testWidgets('a gear inside the round opens them', (tester) async {
      final container = await _pumpPartySettings(tester);
      await _startRound(tester);
      expect(container.read(gameSessionProvider), isNotNull);

      // The hand-off screen carries the gear, so the switches are reachable
      // before the very first card.
      await tester.tap(find.byKey(const ValueKey('in-game-settings-gear')));
      await tester.pumpAndSettle();
      expect(find.text('Показывать роль'), findsOneWidget);
      await _scrollTo(tester, 'История ответов');
      expect(find.text('История ответов'), findsOneWidget);
    });

    testWidgets('the running round follows a switch flipped mid-game',
        (tester) async {
      final container = await _pumpPartySettings(tester);
      await _startRound(tester);
      final dealt = container.read(gameSessionProvider)!;

      await tester.tap(find.byKey(const ValueKey('in-game-settings-gear')));
      await tester.pumpAndSettle();
      await _toggle(tester, 'Показывать роль');
      await tester.pageBack();
      await tester.pumpAndSettle();

      final live = container.read(gameSessionProvider)!;
      expect(live.config.showRoles, isFalse, reason: 'the round follows it');
      // And nothing about the deal moved.
      expect(live.wordPair.id, dealt.wordPair.id);
      expect(live.spyPlayerId, dealt.spyPlayerId);
      expect(live.players.map((p) => p.name), dealt.players.map((p) => p.name));
      expect(live.config.gameMode, dealt.config.gameMode);
      expect(
          live.config.selectedDifficulties, dealt.config.selectedDifficulties);
    });

    testWidgets('step two is not reachable from a running round',
        (tester) async {
      final container = await _pumpPartySettings(tester);
      await _startRound(tester);

      expect(find.text('Настройки партии'), findsNothing);
      expect(find.text('Начать игру'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('in-game-settings-gear')));
      await tester.pumpAndSettle();
      for (final label in _beforeGame) {
        await _scrollTo(tester, label);
        expect(find.text(label), findsNothing,
            reason: '$label would need the party dealt again');
      }
      expect(container.read(gameSessionProvider), isNotNull);
    });
  });

  group('no control appears twice', () {
    testWidgets('each of the five has exactly one switch, in the game settings',
        (tester) async {
      await _pumpHome(tester);
      await _openGameSettings(tester);
      for (final label in _inGame) {
        await _scrollTo(tester, label);
        expect(find.text(label), findsOneWidget, reason: label);
      }

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Новая игра'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Далее'));
      await tester.pumpAndSettle();
      for (final label in _inGame) {
        await _scrollTo(tester, label);
        expect(find.text(label), findsNothing, reason: label);
      }
    });
  });

  group('hints belong to the words mode', () {
    for (final mode in [GameMode.people, GameMode.places]) {
      testWidgets('${mode.name}: the hints switch is absent, not greyed out',
          (tester) async {
        final container = await _pumpPartySettings(tester);
        await _scrollTo(tester, mode.label);
        await tester.tap(find.text(mode.label).first);
        await tester.pumpAndSettle();
        expect(container.read(gameSetupProvider).gameMode, mode);

        await tester.tap(find.byTooltip('Назад'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Назад'));
        await tester.pumpAndSettle();
        await _openGameSettings(tester);

        await _scrollTo(tester, 'Показывать роль');
        expect(find.text('Подсказки'), findsNothing);
        expect(find.text('Помощь на сложных словах'), findsNothing);
        // The role switch is not words-only and stays.
        expect(find.text('Показывать роль'), findsOneWidget);
      });
    }
  });

  group('every mode still plays', () {
    for (final mode in GameMode.values) {
      testWidgets('${mode.name}: a round is dealt from its own pool',
          (tester) async {
        final container = await _pumpPartySettings(tester);
        await _scrollTo(tester, mode.label);
        await tester.tap(find.text(mode.label).first);
        await tester.pumpAndSettle();
        await _startRound(tester);

        final session = container.read(gameSessionProvider)!;
        expect(session.config.gameMode, mode);
        expect(session.wordPair.gameMode, mode);
      });
    }
  });

  group('the settings survive a restart', () {
    testWidgets('what the host set is written down', (tester) async {
      final container = await _pumpHome(tester);
      await _openGameSettings(tester);
      await _toggle(tester, 'Контент 18+');
      await _toggle(tester, 'Показывать роль');
      await _toggle(tester, 'Быстрые ответы');
      await _toggle(tester, 'Алко-режим');

      final config = container.read(gameSetupProvider);
      expect(config.allowAdultContent, isTrue);
      expect(config.showRoles, isFalse);
      expect(config.fastVoting, isTrue);
      expect(config.alcoModeEnabled, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(PartySettingsKeys.adult), isTrue);
      expect(prefs.getBool(PartySettingsKeys.showRoles), isFalse);
      expect(prefs.getBool(PartySettingsKeys.fastVoting), isTrue);
      expect(prefs.getBool(PartySettingsKeys.alco), isTrue);
    });

    testWidgets('and come back on the next launch', (tester) async {
      SharedPreferences.setMockInitialValues({
        PartySettingsKeys.gameMode: 'places',
        PartySettingsKeys.adult: true,
        PartySettingsKeys.hints: false,
        PartySettingsKeys.showRoles: false,
        PartySettingsKeys.fastVoting: true,
        PartySettingsKeys.alco: true,
        PartySettingsKeys.difficulties: ['hard'],
        lastRosterKey: ['Аня', 'Боря', 'Вика'],
      });
      final container = await _pumpHome(tester);
      await tester.pumpAndSettle();

      final config = container.read(gameSetupProvider);
      expect(config.gameMode, GameMode.places);
      expect(config.allowAdultContent, isTrue);
      expect(config.hintsEnabled, isFalse);
      expect(config.showRoles, isFalse);
      expect(config.fastVoting, isTrue);
      expect(config.alcoModeEnabled, isTrue);
      expect(config.selectedDifficulties, {Difficulty.hard});
    });

    testWidgets('a retired hardcore key cannot reach the game', (tester) async {
      // An install from before hardcore was dropped still has the key. It must
      // change nothing, and it must not survive the launch that read it.
      SharedPreferences.setMockInitialValues({
        'party_hardcore': true,
        PartySettingsKeys.difficulties: ['easy'],
        lastRosterKey: ['Аня', 'Боря', 'Вика'],
      });
      final container = await _pumpHome(tester);
      await tester.pumpAndSettle();

      expect(container.read(gameSetupProvider).selectedDifficulties,
          {Difficulty.easy},
          reason: 'the tiers are the host\'s, nothing overrides them now');
      expect(container.read(gameSetupProvider).hintsEnabled, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('party_hardcore'), isFalse,
          reason: 'the retired key is cleared, not left to be read again');
    });

    testWidgets('an install from before this existed keeps every default',
        (tester) async {
      SharedPreferences.setMockInitialValues({lastRosterKey: ['Аня', 'Боря']});
      final container = await _pumpHome(tester);
      await tester.pumpAndSettle();

      final config = container.read(gameSetupProvider);
      expect(config.showRoles, isTrue);
      expect(config.gameMode, GameMode.words);
      expect(config.allowAdultContent, isFalse);
      expect(config.hintsEnabled, isTrue);
      expect(config.fastVoting, isFalse);
      expect(config.alcoModeEnabled, isFalse);
      expect(config.selectedDifficulties, isEmpty);
    });

    testWidgets('finishing a round does not reset them', (tester) async {
      final container = await _pumpHome(tester);
      await _openGameSettings(tester);
      await _toggle(tester, 'Показывать роль');
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Новая игра'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Далее'));
      await tester.pumpAndSettle();
      await _startRound(tester);

      expect(container.read(gameSessionProvider)!.config.showRoles, isFalse);
      expect(container.read(gameSetupProvider).showRoles, isFalse,
          reason: 'the preference outlives the round it was set for');
    });
  });

  group('on a small screen', () {
    for (final size in [
      const Size(960, 1704), // 320x568
      const Size(1170, 2532), // 390x844
    ]) {
      final label = '${size.width ~/ 3}x${size.height ~/ 3}';
      testWidgets('$label: both steps and the game settings fit',
          (tester) async {
        final container = await _pumpHome(tester, size: size);

        await _openGameSettings(tester);
        await _toggle(tester, 'Показывать роль');
        expect(container.read(gameSetupProvider).showRoles, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Новая игра'));
        await tester.pumpAndSettle();
        expect(find.text('Далее'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Далее'));
        await tester.pumpAndSettle();
        await _scrollTo(tester, 'Сложность');
        expect(find.text('Сложность'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await _startRound(tester);
        expect(container.read(gameSessionProvider), isNotNull);
        expect(container.read(gameSessionProvider)!.config.showRoles, isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
