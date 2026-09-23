import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undercover/app.dart';
import 'package:undercover/models/content_type.dart';
import 'package:undercover/models/difficulty.dart';
import 'package:undercover/models/word_category.dart';
import 'package:undercover/models/word_pair.dart';
import 'package:undercover/providers/game_session_provider.dart';
import 'package:undercover/providers/game_setup_provider.dart';
import 'package:undercover/providers/last_roster_provider.dart';
import 'package:undercover/providers/settings_provider.dart';
import 'package:undercover/providers/word_pack_provider.dart';

/// The same people play several evenings in a row, so the line-up of the last
/// party comes back on its own. Only the line-up: no roles, no words, no round.
///
/// These also pin the other half of the change — the separate "how many
/// players" step is gone and the list of names is the only count.

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
      WordPair('Сито', 'Дуршлаг', _m, ['кухня'], 5),
    ],
  ),
];

/// Long enough for the mocked preference channel to answer.
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

/// The same wait inside a widget test, where a bare Future.delayed would sit
/// in the fake-async zone forever.
Future<List<String>?> _storedRoster(WidgetTester tester) async {
  return tester.runAsync<List<String>?>(() async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(lastRosterKey);
  });
}

ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [wordPackProvider.overrideWithValue(_pack)],
  );
  addTearDown(container.dispose);
  return container;
}

Future<ProviderContainer> _pumpApp(WidgetTester tester) async {
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
  return container;
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).first);
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Opens setup and waits for the asynchronous roster load to land.
Future<void> _openSetup(WidgetTester tester) async {
  await _tap(tester, 'Новая игра');
  await tester.pump(const Duration(milliseconds: 30));
  await tester.pumpAndSettle();
}

List<String> _fieldTexts(WidgetTester tester) => tester
    .widgetList<TextField>(find.byType(TextField))
    .map((f) => f.controller?.text ?? '')
    .toList();

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the store itself', () {
    test('empty storage means an empty roster and an ordinary blank setup',
        () async {
      final container = _container();
      expect(container.read(lastRosterProvider), isEmpty);
      await _settle();
      expect(container.read(lastRosterProvider), isEmpty);
      expect(
        container.read(gameSetupProvider).playerNames,
        List.filled(kDefaultPlayers, ''),
      );
    });

    test('a remembered roster is written and read back in order', () async {
      final first = _container();
      first
          .read(lastRosterProvider.notifier)
          .remember(['Аня', 'Боря', 'Вика', 'Гоша']);
      await _settle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(lastRosterKey), ['Аня', 'Боря', 'Вика', 'Гоша']);

      final relaunched = _container();
      expect(relaunched.read(lastRosterProvider), isEmpty);
      await _settle();
      expect(relaunched.read(lastRosterProvider),
          ['Аня', 'Боря', 'Вика', 'Гоша'],
          reason: 'the order is part of the line-up');
    });

    test('blank seats are not remembered', () {
      final container = _container();
      container.read(lastRosterProvider.notifier).remember(['Аня', '', '  ']);
      expect(container.read(lastRosterProvider), ['Аня']);
    });

    test('clearing really empties it, on disk too', () async {
      SharedPreferences.setMockInitialValues({
        lastRosterKey: ['Аня', 'Боря', 'Вика'],
      });
      final container = _container();
      expect(container.read(lastRosterProvider), isEmpty);
      await _settle();
      expect(container.read(lastRosterProvider), hasLength(3));

      container.read(lastRosterProvider.notifier).clear();
      expect(container.read(lastRosterProvider), isEmpty);
      await _settle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(lastRosterKey), isNull);
    });

    test('it does not disturb the other stored settings', () async {
      SharedPreferences.setMockInitialValues({
        'theme_mode': 'dark',
        'used_words': ['кошка', 'тигр'],
      });
      final container = _container();
      container.read(lastRosterProvider.notifier).remember(['Аня', 'Боря', 'Вика']);
      await _settle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'dark');
      expect(prefs.getStringList('used_words'), ['кошка', 'тигр']);
      // The theme provider loads on first read, like every other one.
      expect(container.read(settingsProvider), ThemeMode.system);
      await _settle();
      expect(container.read(settingsProvider), ThemeMode.dark);
    });
  });

  group('the list is the count', () {
    test('adding and removing move the count with the list', () {
      final container = _container();
      final notifier = container.read(gameSetupProvider.notifier);
      expect(container.read(gameSetupProvider).playerNames, hasLength(5));

      notifier.addPlayer();
      expect(container.read(gameSetupProvider).playerNames, hasLength(6));
      notifier.removePlayerAt(0);
      notifier.removePlayerAt(0);
      expect(container.read(gameSetupProvider).playerNames, hasLength(4));
    });

    test('the minimum and maximum still hold', () {
      final container = _container();
      final notifier = container.read(gameSetupProvider.notifier);
      for (var i = 0; i < 20; i++) {
        notifier.addPlayer();
      }
      expect(container.read(gameSetupProvider).playerNames, hasLength(kMaxPlayers));
      for (var i = 0; i < 20; i++) {
        notifier.removePlayerAt(0);
      }
      expect(container.read(gameSetupProvider).playerNames, hasLength(kMinPlayers));
    });

    test('removing takes the right seat, not just the last one', () {
      final container = _container();
      final notifier = container.read(gameSetupProvider.notifier);
      for (var i = 0; i < 5; i++) {
        notifier.setPlayerName(i, 'И$i');
      }
      notifier.removePlayerAt(1);
      expect(container.read(gameSetupProvider).playerNames,
          ['И0', 'И2', 'И3', 'И4']);
    });

    test('a restored roster sets the count as well', () async {
      final container = _container();
      container.read(gameSetupProvider.notifier).setRoster(['Аня', 'Боря', 'Вика']);
      expect(container.read(gameSetupProvider).playerNames, hasLength(3));
      // Below the minimum the roster is padded, never truncated past it.
      container.read(gameSetupProvider.notifier).setRoster(['Аня']);
      expect(container.read(gameSetupProvider).playerNames, hasLength(kMinPlayers));
      expect(container.read(gameSetupProvider).playerNames.first, 'Аня');
    });
  });

  group('on screen', () {
    testWidgets('the separate player-count step is gone', (tester) async {
      await _pumpApp(tester);
      await _openSetup(tester);

      expect(find.text('Сколько игроков?'), findsNothing);
      expect(find.text('Количество игроков'), findsNothing);
      // The names step is the first thing the host sees, and it names the count.
      expect(find.text('Игроки · 5'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(5));
    });

    testWidgets('the header count follows the list', (tester) async {
      await _pumpApp(tester);
      await _openSetup(tester);

      // The header scrolls with the list now, and the add button lives at the
      // bottom of it — come back up before reading the count.
      Future<void> toTop() async {
        await tester.drag(find.byType(ListView), const Offset(0, 4000));
        await tester.pumpAndSettle();
      }

      await _tapKey(tester, 'add-player');
      await toTop();
      expect(find.text('Игроки · 6'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(6));

      await _tapKey(tester, 'remove-player-0');
      await _tapKey(tester, 'remove-player-0');
      await toTop();
      expect(find.text('Игроки · 4'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(4));
    });

    testWidgets('an empty store leaves the usual blank list', (tester) async {
      await _pumpApp(tester);
      await _openSetup(tester);
      expect(_fieldTexts(tester), List.filled(5, ''));
      expect(find.text('Очистить сохранённых игроков'), findsNothing,
          reason: 'nothing to forget yet');
    });

    testWidgets('a saved roster comes back, in order', (tester) async {
      SharedPreferences.setMockInitialValues({
        lastRosterKey: ['Аня', 'Боря', 'Вика', 'Гоша'],
      });
      await _pumpApp(tester);
      await _openSetup(tester);

      expect(find.text('Игроки · 4'), findsOneWidget);
      expect(_fieldTexts(tester), ['Аня', 'Боря', 'Вика', 'Гоша']);
      // And the round can start right away: the rules are one tap away and
      // the start button is already armed.
      // And the round is two taps away: the step is armed.
      expect(find.text('Далее'), findsOneWidget);
      await _tap(tester, 'Далее');
      expect(find.text('Настройки партии'), findsOneWidget);
      expect(find.text('Начать игру'), findsOneWidget);
    });

    testWidgets('a roster is remembered when the names step is confirmed',
        (tester) async {
      final container = await _pumpApp(tester);
      await _openSetup(tester);
      for (var i = 0; i < 5; i++) {
        await tester.enterText(
            find.byKey(ValueKey('player-name-$i')), 'Игрок$i');
        await tester.pumpAndSettle();
      }
      // Nothing is written while typing.
      expect(container.read(lastRosterProvider), isEmpty);

      await tester.tap(find.text('Далее'));
      await tester.pumpAndSettle();
      expect(container.read(lastRosterProvider),
          ['Игрок0', 'Игрок1', 'Игрок2', 'Игрок3', 'Игрок4']);
    });

    testWidgets('an abandoned edit never becomes the saved roster',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        lastRosterKey: ['Аня', 'Боря', 'Вика'],
      });
      final container = await _pumpApp(tester);
      await _openSetup(tester);
      expect(_fieldTexts(tester), ['Аня', 'Боря', 'Вика']);

      // Type something and back out without confirming.
      await tester.enterText(
          find.byKey(const ValueKey('player-name-0')), 'Опечатка');
      await tester.pumpAndSettle();
      // A focused text field keeps its caret blinking, so pumpAndSettle would
      // never settle here — pump the transition by hand instead.
      await tester.tap(find.byTooltip('Назад'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(container.read(lastRosterProvider), ['Аня', 'Боря', 'Вика']);
      expect(await _storedRoster(tester), ['Аня', 'Боря', 'Вика']);
    });

    testWidgets('adding, removing and renaming all survive the confirmation',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        lastRosterKey: ['Аня', 'Боря', 'Вика', 'Гоша'],
      });
      final container = await _pumpApp(tester);
      await _openSetup(tester);
      expect(find.text('Игроки · 4'), findsOneWidget);

      // Rename the first, drop the second, add a seat and name it.
      await tester.enterText(
          find.byKey(const ValueKey('player-name-0')), 'Анна');
      await tester.pumpAndSettle();
      await _tapKey(tester, 'remove-player-1');
      expect(find.text('Игроки · 3'), findsOneWidget);

      await _tapKey(tester, 'add-player');
      expect(find.text('Игроки · 4'), findsOneWidget);
      await tester.enterText(
          find.byKey(const ValueKey('player-name-3')), 'Дима');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Далее'));
      await tester.pumpAndSettle();
      expect(container.read(lastRosterProvider),
          ['Анна', 'Вика', 'Гоша', 'Дима']);
      expect(await _storedRoster(tester), ['Анна', 'Вика', 'Гоша', 'Дима']);
    });

    testWidgets('starting a game remembers the line-up too', (tester) async {
      final container = await _pumpApp(tester);
      await _openSetup(tester);
      for (var i = 0; i < 5; i++) {
        await tester.enterText(
            find.byKey(ValueKey('player-name-$i')), 'Игрок$i');
        await tester.pumpAndSettle();
      }
      // Step two: the round starts from the party settings.
      await _tap(tester, 'Далее');
      await _tap(tester, 'Начать игру');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();

      expect(container.read(gameSessionProvider), isNotNull);
      expect(container.read(lastRosterProvider), hasLength(5));
    });

    testWidgets('forgetting the saved players really empties the list',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        lastRosterKey: ['Аня', 'Боря', 'Вика'],
      });
      final container = await _pumpApp(tester);
      await _openSetup(tester);
      expect(_fieldTexts(tester), ['Аня', 'Боря', 'Вика']);

      await _tap(tester, 'Очистить сохранённых игроков');
      expect(container.read(lastRosterProvider), isEmpty);
      expect(_fieldTexts(tester), List.filled(kMinPlayers, ''));
      expect(find.text('Очистить сохранённых игроков'), findsNothing);
      expect(await _storedRoster(tester), isNull);
    });
  });

  group('only the line-up comes back', () {
    testWidgets('a new party gets fresh roles and a fresh word', (tester) async {
      SharedPreferences.setMockInitialValues({
        lastRosterKey: ['Аня', 'Боря', 'Вика'],
      });
      final container = await _pumpApp(tester);
      await _openSetup(tester);
      // Step two: the round starts from the party settings.
      await _tap(tester, 'Далее');
      await _tap(tester, 'Начать игру');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();

      final session = container.read(gameSessionProvider)!;
      expect(session.players.map((p) => p.name), ['Аня', 'Боря', 'Вика']);
      // Everything that is not the line-up starts from scratch.
      expect(session.votes, isEmpty);
      expect(session.voteResult, isNull);
      expect(session.result, isNull);
      expect(session.players.where((p) => p.hasSeenWord), isEmpty);
      expect(session.players.where((p) => p.hasVoted), isEmpty);
    });

    test('restoring a roster leaves the filters exactly as they were', () {
      final container = _container();
      final notifier = container.read(gameSetupProvider.notifier);
      notifier.toggleContentType(ContentType.phrases);
      notifier.toggleDifficulty(Difficulty.hard);
      notifier.setHintsEnabled(false);
      notifier.setAlcoMode(true);
      notifier.toggleCategory('alpha');

      notifier.setRoster(['Аня', 'Боря', 'Вика']);

      final config = container.read(gameSetupProvider);
      expect(config.playerNames, ['Аня', 'Боря', 'Вика']);
      expect(config.selectedContentTypes, {ContentType.phrases});
      expect(config.selectedDifficulties, {Difficulty.hard});
      expect(config.hintsEnabled, isFalse);
      expect(config.alcoModeEnabled, isTrue);
      expect(config.selectedCategoryIds, {'alpha'});
    });
  });
}
