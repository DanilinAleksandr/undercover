import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undercover/app.dart';
import 'package:undercover/data/word_pack_registry.dart';
import 'package:undercover/logic/word_pack_selector.dart';
import 'package:undercover/models/content_type.dart';
import 'package:undercover/models/difficulty.dart';
import 'package:undercover/models/game_config.dart';
import 'package:undercover/models/word_category.dart';
import 'package:undercover/models/word_pair.dart';
import 'package:undercover/providers/game_session_provider.dart';
import 'package:undercover/providers/settings_provider.dart';
import 'package:undercover/models/game_mode.dart';
import 'package:undercover/providers/used_entries_provider.dart';
import 'package:undercover/providers/word_pack_provider.dart';

/// The history is kept per word, not per pair: once the table has heard a
/// word, every future pair containing it is spent. These cover the rule end to
/// end — the picker, the pool counter, persistence across restarts, the
/// migration from the old pair-level format, and the manual reset.

const _e = Difficulty.easy;
const _m = Difficulty.medium;
const _h = Difficulty.hard;
const _x = Difficulty.expert;

/// «Кошка» appears in two pairs and «Собака» in two more, so spending one word
/// has to knock out pairs the party never saw.
const _fixture = [
  WordCategory(
    id: 'alpha',
    name: 'Альфа',
    icon: Icons.science,
    pairs: [
      WordPair('Кошка', 'Тигр', _e, ['усы и лапы'], 5),
      WordPair('Кошка', 'Лев', _m, ['кошачьи'], 5),
      WordPair('Собака', 'Волк', _h, ['клыки'], 5),
      WordPair('Маяк', 'Прожектор', _x, ['свет'], 5),
    ],
  ),
  WordCategory(
    id: 'beta',
    name: 'Бета',
    icon: Icons.star,
    pairs: [
      WordPair('Собака', 'Лиса', _e, ['хвост'], 5),
      WordPair('Гиря', 'Якорь', _m, ['тяжесть'], 5),
      WordPair('Первое свидание', 'Собеседование на работу', _m, ['волнуешься'], 5),
      WordPair('Тихий двор', 'Пустой перрон', _h, ['никого нет'], 5),
    ],
  ),
  WordCategory(
    id: 'hot',
    name: '18+',
    icon: Icons.no_adult_content,
    isAdult: true,
    pairs: [WordPair('Казино', 'Биржа', _m, ['ставка'], 5)],
  ),
];

GameConfig _config({
  Set<ContentType> selectedContentTypes = const {},
  Set<Difficulty> difficulties = const {},
  Set<String> categoryIds = const {},
  bool adult = false,
}) {
  return GameConfig(
    playerNames: const ['А', 'Б', 'В'],
    selectedContentTypes: selectedContentTypes,
    selectedDifficulties: difficulties,
    selectedCategoryIds: categoryIds,
    allowAdultContent: adult,
  );
}

ProviderContainer _container({List<WordCategory> pack = _fixture}) {
  final container = ProviderContainer(
    overrides: [wordPackProvider.overrideWithValue(pack)],
  );
  addTearDown(container.dispose);
  return container;
}

Set<String> _ids(List<WordPair> pairs) => pairs.map((p) => p.id).toSet();

/// Long enough for the mocked preference channel to answer.
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('a fresh history', () {
    test('starts empty and blocks nothing', () {
      final container = _container();
      expect(container.read(usedEntriesProvider)[GameMode.words]!, isEmpty);
      expect(playablePairs(_fixture, allowAdultContent: true), hasLength(9));
      expect(poolStats(_fixture).blockedByHistory, 0);
    });
  });

  group('a dealt pair spends both of its words', () {
    test('the deal records the civilian word and the spy word', () {
      final container = _container();
      expect(container.read(gameSessionProvider.notifier).startGame(_config()),
          isTrue);
      final dealt = container.read(gameSessionProvider)!.wordPair;
      expect(container.read(usedEntriesProvider)[GameMode.words]!,
          containsAll(dealt.wordKeys));
      expect(container.read(usedEntriesProvider)[GameMode.words]!, hasLength(2));
    });

    test('a pair is out when its first word was used', () {
      final left = playablePairs(_fixture, usedWordKeys: {'кошка'});
      expect(_ids(left), isNot(contains('Кошка/Тигр')));
      expect(_ids(left), isNot(contains('Кошка/Лев')));
      expect(_ids(left), contains('Собака/Волк'));
    });

    test('a pair is out when its second word was used', () {
      // «Тигр» is only ever a spy word, and it still spends its pair.
      final left = playablePairs(_fixture, usedWordKeys: {'тигр'});
      expect(_ids(left), isNot(contains('Кошка/Тигр')));
      expect(_ids(left), contains('Кошка/Лев'));
    });

    test('a pair with two fresh words stays available', () {
      final left = playablePairs(_fixture, usedWordKeys: {'кошка', 'тигр'});
      expect(_ids(left), containsAll(['Собака/Волк', 'Гиря/Якорь', 'Маяк/Прожектор']));
    });

    test('the block ignores category and difficulty', () {
      // «Собака» lives in a hard pair of alpha and an easy pair of beta.
      final left = playablePairs(_fixture, usedWordKeys: {'собака'});
      expect(_ids(left), isNot(contains('Собака/Волк')));
      expect(_ids(left), isNot(contains('Собака/Лиса')));
      // And the same word blocks across an explicit category filter too.
      expect(
        playablePairs(_fixture,
            selectedCategoryIds: {'beta'},
            selectedDifficulties: {_e},
            usedWordKeys: {'собака'}),
        isEmpty,
      );
    });

    test('case and ё do not create a second word', () {
      const pair = WordPair('Ёлка', 'Сосна', _e, ['хвоя'], 5);
      expect(pair.wordKeys, ['елка', 'сосна']);
      const pack = [
        WordCategory(id: 'x', name: 'Х', icon: Icons.star, pairs: [pair]),
      ];
      expect(playablePairs(pack, usedWordKeys: {'ЁЛКА'.toLowerCase()}), hasLength(1),
          reason: 'the stored key is normalised, the lookup must match it');
      expect(playablePairs(pack, usedWordKeys: {'елка'}), isEmpty);
    });

    test('phrases are spent exactly like single words', () {
      final container = _container();
      container.read(usedEntriesProvider.notifier).markUsed(GameMode.words, const WordPair(
          'Первое свидание', 'Собеседование на работу', _m, ['волнуешься'], 5));
      expect(container.read(usedEntriesProvider)[GameMode.words]!,
          {'первое свидание', 'собеседование на работу'});
      final left = playablePairs(_fixture,
          usedWordKeys: container.read(usedEntriesProvider)[GameMode.words]!);
      expect(_ids(left), isNot(contains('Первое свидание/Собеседование на работу')));
      expect(_ids(left), contains('Тихий двор/Пустой перрон'));
    });
  });

  group('history and the filters intersect', () {
    test('words and phrases each keep their own filter', () {
      const used = {'кошка'};
      expect(
        _ids(playablePairs(_fixture,
            selectedContentTypes: {ContentType.words}, usedWordKeys: used)),
        {'Собака/Волк', 'Собака/Лиса', 'Гиря/Якорь', 'Маяк/Прожектор'},
      );
      expect(
        _ids(playablePairs(_fixture,
            selectedContentTypes: {ContentType.phrases}, usedWordKeys: used)),
        {'Первое свидание/Собеседование на работу', 'Тихий двор/Пустой перрон'},
      );
    });

    test('several difficulties at once still respect the history', () {
      expect(
        _ids(playablePairs(_fixture,
            selectedDifficulties: {_e, _m}, usedWordKeys: {'кошка', 'собака'})),
        {'Гиря/Якорь', 'Первое свидание/Собеседование на работу'},
      );
    });

    test('18+ stays behind its own switch', () {
      expect(_ids(playablePairs(_fixture, usedWordKeys: {'кошка'})),
          isNot(contains('Казино/Биржа')));
      expect(
        _ids(playablePairs(_fixture,
            allowAdultContent: true, usedWordKeys: {'кошка'})),
        contains('Казино/Биржа'),
      );
    });

    test('the counter subtracts the blocked pairs', () {
      final before = poolStats(_fixture);
      expect(before.total, 8);
      expect(before.blockedByHistory, 0);

      final after = poolStats(_fixture, usedWordKeys: {'кошка', 'собака'});
      expect(after.total, 4);
      expect(after.blockedByHistory, 4);
      expect(after.countOf(_e), 0);
      expect(after.isEmpty, isFalse);
    });

    test('an empty pool distinguishes history from an impossible filter', () {
      final spent = poolStats(_fixture,
          selectedCategoryIds: {'alpha'},
          selectedDifficulties: {_e},
          usedWordKeys: {'кошка'});
      expect(spent.isEmpty, isTrue);
      expect(spent.exhaustedByHistory, isTrue);

      final impossible = poolStats(_fixture,
          selectedCategoryIds: {'alpha'}, selectedContentTypes: {ContentType.phrases});
      expect(impossible.isEmpty, isTrue);
      expect(impossible.exhaustedByHistory, isFalse);
    });

    test('the picker draws from exactly what the counter promised', () {
      const used = {'кошка', 'собака'};
      final allowed = _ids(playablePairs(_fixture, usedWordKeys: used));
      for (var i = 0; i < 40; i++) {
        final pair = pickWordPair(
          categories: _fixture,
          selectedCategoryIds: const {},
          usedWordKeys: used,
        );
        expect(allowed, contains(pair!.id));
      }
    });
  });

  group('the game loop writes at exactly one moment', () {
    test('building a config or reading the pool records nothing', () {
      final container = _container();
      poolStats(_fixture, usedWordKeys: container.read(usedEntriesProvider)[GameMode.words]!);
      _config(difficulties: {_h});
      expect(container.read(usedEntriesProvider)[GameMode.words]!, isEmpty);
    });

    test('a game that never got a pair records nothing', () {
      const empty = [
        WordCategory(id: 'none', name: 'Пусто', icon: Icons.star, pairs: []),
      ];
      final container = _container(pack: empty);
      expect(container.read(gameSessionProvider.notifier).startGame(_config()),
          isFalse);
      expect(container.read(gameSessionProvider), isNull);
      expect(container.read(usedEntriesProvider)[GameMode.words]!, isEmpty);
    });

    test('abandoning a round keeps the words spent but adds no more', () {
      final container = _container();
      final notifier = container.read(gameSessionProvider.notifier);
      notifier.startGame(_config());
      final afterDeal = {...container.read(usedEntriesProvider)[GameMode.words]!};
      notifier.endGame();
      expect(container.read(usedEntriesProvider)[GameMode.words]!, afterDeal);
    });

    test('a rematch records its new pair too', () {
      final container = _container();
      final notifier = container.read(gameSessionProvider.notifier);
      notifier.startGame(_config());
      final first = container.read(gameSessionProvider)!.wordPair;

      expect(notifier.playAgainSamePlayers(), isTrue);
      final second = container.read(gameSessionProvider)!.wordPair;
      expect(second.wordKeys.any(first.wordKeys.contains), isFalse,
          reason: 'a rematch must not reuse a word from the round just played');
      expect(container.read(usedEntriesProvider)[GameMode.words]!, hasLength(4));
      expect(container.read(usedEntriesProvider)[GameMode.words]!,
          containsAll([...first.wordKeys, ...second.wordKeys]));
    });

    test('the real base loses two words per round', () {
      final container = _container(pack: allWordCategories);
      final before = poolStats(allWordCategories).total;
      container.read(gameSessionProvider.notifier).startGame(_config());
      expect(container.read(usedEntriesProvider)[GameMode.words]!, hasLength(2));
      final after = poolStats(allWordCategories,
              usedWordKeys: container.read(usedEntriesProvider)[GameMode.words]!)
          .total;
      expect(after, lessThan(before),
          reason: 'at least the dealt pair itself is gone');
    });
  });

  group('storage', () {
    test('the history survives a restart', () async {
      final first = _container();
      first.read(gameSessionProvider.notifier).startGame(_config());
      final dealt = first.read(gameSessionProvider)!.wordPair.wordKeys;
      await _settle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(usedEntriesKeys[GameMode.words]!), containsAll(dealt));
      expect(prefs.getInt(usedEntriesVersionKey), usedEntriesVersion);

      // A fresh container is a fresh launch: same disk, new providers. The
      // first read builds the notifier and starts the asynchronous load.
      final relaunched = _container();
      expect(relaunched.read(usedEntriesProvider)[GameMode.words]!, isEmpty);
      await _settle();
      expect(relaunched.read(usedEntriesProvider)[GameMode.words]!,
          containsAll(dealt));
    });

    test('a word spent before the load finishes is not lost', () async {
      SharedPreferences.setMockInitialValues({
        usedEntriesKeys[GameMode.words]!: ['вчерашнее'],
      });
      final container = _container();
      container.read(gameSessionProvider.notifier).startGame(_config());
      final dealt = container.read(gameSessionProvider)!.wordPair.wordKeys;
      await _settle();
      expect(container.read(usedEntriesProvider)[GameMode.words]!,
          containsAll([...dealt, 'вчерашнее']));
    });

    test('the old pair-level history migrates into words', () async {
      // Format shipped in the previous version: one entry per pair.
      SharedPreferences.setMockInitialValues({
        'used_pair_keys': ['кошка|тигр', 'гиря|якорь'],
        'theme_mode': 'dark',
      });
      final container = _container();
      expect(container.read(usedEntriesProvider)[GameMode.words]!, isEmpty);
      await _settle();

      expect(container.read(usedEntriesProvider)[GameMode.words]!,
          {'кошка', 'тигр', 'гиря', 'якорь'});
      // Both of the pairs holding «Кошка» are gone, not just the one played.
      final left = _ids(playablePairs(_fixture,
          usedWordKeys: container.read(usedEntriesProvider)[GameMode.words]!));
      expect(left, isNot(contains('Кошка/Лев')));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('used_pair_keys'), isFalse,
          reason: 'the legacy key is consumed, not left to be read twice');
      expect(prefs.getStringList(usedEntriesKeys[GameMode.words]!),
          containsAll(['кошка', 'тигр', 'гиря', 'якорь']));
    });

    test('unrelated settings are left alone', () async {
      SharedPreferences.setMockInitialValues({
        'theme_mode': 'light',
        'used_pair_keys': ['кошка|тигр'],
      });
      final container = _container();
      expect(container.read(settingsProvider), ThemeMode.system);
      await _settle();

      expect(container.read(settingsProvider), ThemeMode.light,
          reason: 'the theme must still load next to the migrated history');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'light');
    });

    test('an unreadable history degrades to an empty one', () async {
      // A future format, or a corrupted value: the game still starts.
      SharedPreferences.setMockInitialValues({
        usedEntriesKeys[GameMode.words]!: 'не список',
        usedEntriesVersionKey: 99,
      });
      final container = _container();
      await _settle();
      expect(container.read(usedEntriesProvider)[GameMode.words]!, isEmpty);
      expect(container.read(gameSessionProvider.notifier).startGame(_config()),
          isTrue);
    });
  });

  group('the manual reset', () {
    test('it clears everything and puts the words back in the pool', () async {
      final container = _container();
      container.read(usedEntriesProvider.notifier).markUsed(GameMode.words, 
          const WordPair('Кошка', 'Тигр', _e, ['усы и лапы'], 5));
      expect(poolStats(_fixture, usedWordKeys: container.read(usedEntriesProvider)[GameMode.words]!)
          .total, 6);

      container.read(usedEntriesProvider.notifier).reset(GameMode.words);
      expect(container.read(usedEntriesProvider)[GameMode.words]!, isEmpty);
      expect(poolStats(_fixture, usedWordKeys: container.read(usedEntriesProvider)[GameMode.words]!)
          .total, 8);

      await _settle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(usedEntriesKeys[GameMode.words]!), isNull,
          reason: 'an empty store is removed rather than written as []');
    });

    test('nothing in the game loop resets it', () {
      final container = _container();
      final notifier = container.read(gameSessionProvider.notifier);
      notifier.startGame(_config());
      notifier.endGame();
      notifier.startGame(_config());
      notifier.playAgainSamePlayers();
      expect(container.read(usedEntriesProvider)[GameMode.words]!, hasLength(6));
    });
  });

  group('on screen', () {
    Future<ProviderContainer> pumpTo(
      WidgetTester tester, {
      List<WordCategory> pack = _fixture,
    }) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [wordPackProvider.overrideWithValue(pack)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const UndercoverApp()),
      );
      await tester.pumpAndSettle();
      return container;
    }

    Future<void> tap(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.text(label).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
    }

    Future<void> toFilters(WidgetTester tester) async {
      await tap(tester, 'Новая игра');
      for (var i = 0; i < 5; i++) {
        await tester.enterText(find.byKey(ValueKey('player-name-$i')), 'И${i + 1}');
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Далее'));
      await tester.pumpAndSettle();
    }

    testWidgets('the readout counts the pool and the spent words',
        (tester) async {
      final container = await pumpTo(tester);
      await toFilters(tester);

      expect(find.text('В пуле: 8 пар'), findsOneWidget);
      expect(find.textContaining('использовано'), findsNothing);
      expect(find.text('История'), findsNothing);

      container.read(usedEntriesProvider.notifier).markUsed(GameMode.words, 
          const WordPair('Кошка', 'Тигр', _e, ['усы и лапы'], 5));
      await tester.pumpAndSettle();

      // «Кошка» also killed «Кошка / Лев», which was never played.
      expect(find.text('В пуле: 6 пар'), findsOneWidget);
      expect(find.textContaining('2 слова уже использовано'), findsOneWidget);
      expect(find.text('История'), findsOneWidget);
    });

    testWidgets('a pool spent by history says so and blocks the start',
        (tester) async {
      final container = await pumpTo(tester);
      await toFilters(tester);

      for (final pair in _fixture.expand((c) => c.pairs)) {
        container.read(usedEntriesProvider.notifier).markUsed(GameMode.words, pair);
      }
      await tester.pumpAndSettle();

      expect(find.text('Все подходящие ответы режима уже использованы'),
          findsOneWidget);
      expect(find.textContaining('В пуле:'), findsNothing);

      await tap(tester, 'Начать игру');
      expect(container.read(gameSessionProvider), isNull);

      await tap(tester, 'Сбросить историю режима');
      expect(find.text('Сбросить историю режима «Слова»?'), findsOneWidget);
      expect(
          find.textContaining('снова станут доступны'), findsOneWidget);
      await tap(tester, 'Отмена');
      expect(container.read(usedEntriesProvider)[GameMode.words]!, isNotEmpty);

      await tap(tester, 'Сбросить историю режима');
      await tap(tester, 'Сбросить');
      expect(container.read(usedEntriesProvider)[GameMode.words]!, isEmpty);
      expect(find.text('История сброшена'), findsOneWidget);
      expect(find.text('В пуле: 8 пар'), findsOneWidget);

      // The toast sits over the pinned button for a couple of seconds; wait it
      // out rather than tapping through it.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      await tap(tester, 'Начать игру');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();
      expect(container.read(gameSessionProvider), isNotNull);
    });

    testWidgets('the settings entry shows the count and guards the reset',
        (tester) async {
      final container = await pumpTo(tester);
      container.read(usedEntriesProvider.notifier).markUsed(GameMode.words, 
          const WordPair('Кошка', 'Тигр', _e, ['усы и лапы'], 5));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('История ответов'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();

      // One row per mode; only the words row has anything in it.
      expect(find.text('Использовано: 2 слова'), findsOneWidget);
      expect(find.text('Пока ничего не сыграно'),
          findsNWidgets(GameMode.values.length - 1));

      // Every mode row carries a «Сбросить», and so does the dialog, so the
      // taps have to say which one they mean.
      final cardReset = find.text('Сбросить').first;
      final dialogReset = find.descendant(
          of: find.byType(AlertDialog), matching: find.text('Сбросить'));

      await tester.tap(cardReset);
      await tester.pumpAndSettle();
      expect(find.text('Сбросить историю режима «Слова»?'), findsOneWidget);
      await tap(tester, 'Отмена');
      expect(container.read(usedEntriesProvider)[GameMode.words]!, hasLength(2));

      await tester.tap(cardReset);
      await tester.pumpAndSettle();
      await tester.tap(dialogReset);
      await tester.pumpAndSettle();
      expect(container.read(usedEntriesProvider)[GameMode.words]!, isEmpty);
      expect(find.text('История сброшена'), findsOneWidget);
      expect(find.text('Пока ничего не сыграно'),
          findsNWidgets(GameMode.values.length));
    });

    testWidgets('the history link opens the settings from the filters',
        (tester) async {
      final container = await pumpTo(tester);
      container.read(usedEntriesProvider.notifier).markUsed(GameMode.words, 
          const WordPair('Кошка', 'Тигр', _e, ['усы и лапы'], 5));
      await toFilters(tester);

      await tap(tester, 'История');
      expect(find.text('Тема оформления'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      // And it comes back to the step it left, filters intact.
      expect(find.text('В пуле: 6 пар'), findsOneWidget);
    });
  });
}
