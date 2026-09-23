import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undercover/app.dart';
import 'package:undercover/data/word_pack_registry.dart';
import 'package:undercover/logic/hint_policy.dart';
import 'package:undercover/logic/word_pack_selector.dart';
import 'package:undercover/models/content_type.dart';
import 'package:undercover/models/difficulty.dart';
import 'package:undercover/models/game_config.dart';
import 'package:undercover/models/game_mode.dart';
import 'package:undercover/models/word_category.dart';
import 'package:undercover/models/word_pair.dart';
import 'package:undercover/providers/game_session_provider.dart';
import 'package:undercover/providers/game_setup_provider.dart';
import 'package:undercover/providers/used_entries_provider.dart';
import 'package:undercover/providers/word_pack_provider.dart';

/// «Слова», «Личности» and «Места» are three modes, not three filters. A round
/// is played in exactly one of them; the modes have separate content, separate
/// pools and separate played histories, and nothing ever falls back from one
/// into another.

const _e = Difficulty.easy;
const _m = Difficulty.medium;
const _h = Difficulty.hard;
const _people = GameMode.people;
const _places = GameMode.places;
const _words = GameMode.words;

/// Every mode present, with two categories each so category filters can be
/// exercised inside a mode.
const _fixture = [
  WordCategory(
    id: 'w1',
    name: 'Слова A',
    icon: Icons.abc,
    pairs: [
      WordPair('Маяк', 'Прожектор', _e, ['свет'], 5),
      WordPair('Гиря', 'Якорь', _m, ['тяжесть'], 5),
      WordPair('Первый снег', 'Тёплый дождь', _h, ['погода'], 5),
    ],
  ),
  WordCategory(
    id: 'w2',
    name: 'Слова Б',
    icon: Icons.abc,
    pairs: [WordPair('Сито', 'Дуршлаг', _m, ['кухня'], 5)],
  ),
  WordCategory(
    id: 'p1',
    name: 'Люди A',
    icon: Icons.person,
    pairs: [
      WordPair('Эйнштейн', 'Ньютон', _e, ['физик'], 5, mode: _people),
      WordPair('Илон Маск', 'Джефф Безос', _m, ['ракеты'], 5, mode: _people),
    ],
  ),
  WordCategory(
    id: 'p2',
    name: 'Люди Б',
    icon: Icons.person,
    pairs: [WordPair('Пушкин', 'Лермонтов', _h, ['поэт'], 5, mode: _people)],
  ),
  WordCategory(
    id: 'l1',
    name: 'Места A',
    icon: Icons.place,
    pairs: [
      WordPair('Париж', 'Лондон', _e, ['столица'], 5, mode: _places),
      WordPair('Байкал', 'Каспий', _m, ['вода'], 5, mode: _places),
    ],
  ),
  WordCategory(
    id: 'l2',
    name: 'Места Б',
    icon: Icons.place,
    pairs: [WordPair('Рим', 'Афины', _h, ['древность'], 5, mode: _places)],
  ),
];

Set<String> _ids(List<WordPair> pairs) => pairs.map((p) => p.id).toSet();

ProviderContainer _container({List<WordCategory> pack = _fixture}) {
  final container = ProviderContainer(
    overrides: [wordPackProvider.overrideWithValue(pack)],
  );
  addTearDown(container.dispose);
  return container;
}

GameConfig _config(GameMode mode) =>
    GameConfig(playerNames: const ['А', 'Б', 'В'], gameMode: mode);

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the mode is a single choice', () {
    test('a config carries exactly one, and words is the default', () {
      expect(const GameConfig(playerNames: ['А']).gameMode, _words);
      expect(GameConfig.initial.gameMode, _words);
      final container = _container();
      expect(container.read(gameSetupProvider).gameMode, _words);
    });

    test('choosing a mode replaces the previous one — they cannot combine', () {
      final container = _container();
      final notifier = container.read(gameSetupProvider.notifier);
      notifier.setGameMode(_people);
      expect(container.read(gameSetupProvider).gameMode, _people);
      notifier.setGameMode(_places);
      expect(container.read(gameSetupProvider).gameMode, _places,
          reason: 'a second mode replaces the first, it does not add to it');
    });

    test('switching modes drops a category selection made in another one', () {
      final container = _container();
      final notifier = container.read(gameSetupProvider.notifier);
      notifier.toggleCategory('w1');
      notifier.toggleDifficulty(_h);
      notifier.setGameMode(_places);
      final config = container.read(gameSetupProvider);
      expect(config.selectedCategoryIds, isEmpty,
          reason: 'a words category would silently empty the places pool');
      expect(config.selectedDifficulties, {_h},
          reason: 'difficulty means the same thing in every mode');
    });

    test('the pair declares its mode, and the old base declares nothing', () {
      const word = WordPair('Маяк', 'Прожектор', _e, ['свет'], 5);
      expect(word.mode, isNull);
      expect(word.gameMode, _words);
      expect(
        const WordPair('Париж', 'Лондон', _e, ['столица'], 5, mode: _places)
            .gameMode,
        _places,
      );
    });
  });

  group('a mode never sees another mode', () {
    test('words see only words', () {
      expect(_ids(playablePairs(_fixture, gameMode: _words)),
          {'Маяк/Прожектор', 'Гиря/Якорь', 'Первый снег/Тёплый дождь', 'Сито/Дуршлаг'});
    });

    test('people see only people', () {
      expect(_ids(playablePairs(_fixture, gameMode: _people)),
          {'Эйнштейн/Ньютон', 'Илон Маск/Джефф Безос', 'Пушкин/Лермонтов'});
    });

    test('places see only places', () {
      expect(_ids(playablePairs(_fixture, gameMode: _places)),
          {'Париж/Лондон', 'Байкал/Каспий', 'Рим/Афины'});
    });

    test('the modes partition the base with nothing left over', () {
      var sum = 0;
      for (final mode in GameMode.values) {
        final count = pairsMatching(allWordCategories,
                gameMode: mode, allowAdultContent: true)
            .length;
        expect(count, greaterThan(0), reason: mode.name);
        sum += count;
      }
      final everything = [
        for (final c in allWordCategories) ...c.pairs,
      ].length;
      expect(sum, everything);
    });

    test('the words/phrases split only applies inside the words mode', () {
      // Asking for phrases in the places mode is meaningless, and it must not
      // silently empty the pool either.
      expect(
        playablePairs(_fixture,
            gameMode: _places,
            selectedContentTypes: {ContentType.phrases}).length,
        3,
      );
      expect(
        _ids(playablePairs(_fixture,
            gameMode: _words, selectedContentTypes: {ContentType.phrases})),
        {'Первый снег/Тёплый дождь'},
      );
    });
  });

  group('the filters work inside every mode', () {
    test('categories', () {
      for (final (mode, id, expected) in [
        (_words, 'w2', {'Сито/Дуршлаг'}),
        (_people, 'p2', {'Пушкин/Лермонтов'}),
        (_places, 'l2', {'Рим/Афины'}),
      ]) {
        expect(
          _ids(playablePairs(_fixture, gameMode: mode, selectedCategoryIds: {id})),
          expected,
          reason: '$mode/$id',
        );
      }
    });

    test('a category from another mode yields nothing, never a fallback', () {
      expect(
        playablePairs(_fixture, gameMode: _places, selectedCategoryIds: {'w1'}),
        isEmpty,
      );
    });

    test('difficulty', () {
      for (final (mode, expected) in [
        (_words, {'Гиря/Якорь', 'Сито/Дуршлаг'}),
        (_people, {'Илон Маск/Джефф Безос'}),
        (_places, {'Байкал/Каспий'}),
      ]) {
        expect(
          _ids(playablePairs(_fixture, gameMode: mode, selectedDifficulties: {_m})),
          expected,
          reason: '$mode',
        );
      }
    });
  });

  group('each mode has its own history', () {
    test('a word played does not block a person or a place', () {
      // «Пушкин» is a person here; spending the word «Маяк» must not touch it.
      final left = playablePairs(_fixture, gameMode: _people,
          usedWordKeys: const {'маяк', 'гиря', 'сито'});
      expect(left, hasLength(3), reason: 'the words history is another store');
    });

    test('a person played does not block a word or a place', () {
      expect(playablePairs(_fixture, gameMode: _words,
          usedWordKeys: const {'эйнштейн', 'пушкин'}), hasLength(4));
      expect(playablePairs(_fixture, gameMode: _places,
          usedWordKeys: const {'эйнштейн', 'пушкин'}), hasLength(3));
    });

    test('a place played does not block a word or a person', () {
      expect(playablePairs(_fixture, gameMode: _words,
          usedWordKeys: const {'париж', 'байкал'}), hasLength(4));
      expect(playablePairs(_fixture, gameMode: _people,
          usedWordKeys: const {'париж', 'байкал'}), hasLength(3));
    });

    test('the stores really are separate in the provider', () {
      final container = _container();
      final notifier = container.read(gameSessionProvider.notifier);
      notifier.startGame(_config(_people));
      final peopleAfterOne = container.read(usedEntriesProvider)[_people]!;
      expect(peopleAfterOne, hasLength(2));
      expect(container.read(usedEntriesProvider)[_words], isEmpty);
      expect(container.read(usedEntriesProvider)[_places], isEmpty);

      notifier.startGame(_config(_places));
      expect(container.read(usedEntriesProvider)[_places], hasLength(2));
      expect(container.read(usedEntriesProvider)[_people], peopleAfterOne,
          reason: 'playing a place must not add to the people history');
    });

    test('inside a mode, one side of a pair still blocks the whole pair', () {
      final left = playablePairs(_fixture, gameMode: _places,
          usedWordKeys: const {'лондон'});
      expect(_ids(left), isNot(contains('Париж/Лондон')));
      expect(left, hasLength(2));
    });

    test('resetting one mode leaves the other two untouched', () {
      final container = _container();
      final notifier = container.read(usedEntriesProvider.notifier);
      notifier.markUsed(_words, const WordPair('Маяк', 'Прожектор', _e, ['свет'], 5));
      notifier.markUsed(_people,
          const WordPair('Эйнштейн', 'Ньютон', _e, ['физик'], 5, mode: _people));
      notifier.markUsed(_places,
          const WordPair('Париж', 'Лондон', _e, ['столица'], 5, mode: _places));

      notifier.reset(_people);
      final used = container.read(usedEntriesProvider);
      expect(used[_people], isEmpty);
      expect(used[_words], hasLength(2));
      expect(used[_places], hasLength(2));
    });

    test('each mode gets its own key on disk, and words keeps the old one',
        () async {
      final container = _container();
      container.read(usedEntriesProvider.notifier).markUsed(
          _places, const WordPair('Париж', 'Лондон', _e, ['с'], 5, mode: _places));
      await _settle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('used_places'), containsAll(['париж', 'лондон']));
      expect(prefs.getStringList('used_words'), isNull);
      expect(usedEntriesKeys[_words], 'used_words');
    });

    test('the old single history migrates into the words mode', () async {
      SharedPreferences.setMockInitialValues({
        'used_pair_keys': ['кошка|собака'],
      });
      final container = _container();
      container.read(usedEntriesProvider);
      await _settle();
      final used = container.read(usedEntriesProvider);
      expect(used[_words], {'кошка', 'собака'},
          reason: 'words already played must survive the upgrade');
      expect(used[_people], isEmpty);
      expect(used[_places], isEmpty);
    });

    test('a pre-existing used_words store still belongs to the words mode',
        () async {
      SharedPreferences.setMockInitialValues({
        'used_words': ['маяк', 'прожектор'],
      });
      final container = _container();
      container.read(usedEntriesProvider);
      await _settle();
      expect(container.read(usedEntriesProvider)[_words], {'маяк', 'прожектор'});
      expect(playablePairs(_fixture, gameMode: _words,
          usedWordKeys: container.read(usedEntriesProvider)[_words]!), hasLength(3));
    });
  });

  group('the pool and the forecast are per mode', () {
    test('the counter changes with the mode', () {
      expect(poolStats(_fixture, gameMode: _words).total, 4);
      expect(poolStats(_fixture, gameMode: _people).total, 3);
      expect(poolStats(_fixture, gameMode: _places).total, 3);
    });

    test('the real base counts each mode on its own', () {
      // Floors, not exact counts: content grows, and a test that pins the
      // number just has to be edited every time a pair is authored.
      final authoredPeople = pairsMatching(allWordCategories, gameMode: _people);
      final authoredPlaces = pairsMatching(allWordCategories, gameMode: _places);
      expect(authoredPeople.length, greaterThanOrEqualTo(250));
      expect(authoredPlaces.length, greaterThanOrEqualTo(250));

      final words = poolStats(allWordCategories, gameMode: _words).total;
      final people = poolStats(allWordCategories, gameMode: _people).total;
      final places = poolStats(allWordCategories, gameMode: _places).total;
      // Each mode counts only its own pairs, and the quality gate can only
      // ever shrink what was authored.
      expect(people, lessThanOrEqualTo(authoredPeople.length));
      expect(places, lessThanOrEqualTo(authoredPlaces.length));
      expect(people, greaterThan(200),
          reason: 'people is a mode of its own, not a bonus pack');
      expect(places, greaterThan(200),
          reason: 'places is a mode of its own, not a handful of landmarks');
      expect(words, greaterThan(600));
      expect(words, isNot(people + places));
    });

    test('the forecast is computed inside the mode', () {
      final words = poolStats(allWordCategories, gameMode: _words);
      final people = poolStats(allWordCategories, gameMode: _people);
      final places = poolStats(allWordCategories, gameMode: _places);
      for (final stats in [words, people, places]) {
        expect(stats.estimatedGames, greaterThan(0));
        expect(stats.estimatedGames, lessThanOrEqualTo(stats.total));
      }
      // Three different pools, three different numbers — no shared statistic.
      expect(people.estimatedGames, isNot(words.estimatedGames));

      // The visibility threshold still applies, per mode.
      final narrow = poolStats(allWordCategories,
          gameMode: _people, selectedCategoryIds: {'pers_sport'});
      expect(narrow.estimatedGames, lessThanOrEqualTo(estimatedGamesVisibilityThreshold));
      expect(narrow.showsForecast, isTrue);
      expect(words.showsForecast, isFalse, reason: 'far past the threshold');
    });

    test('history shrinks only the pool of its own mode', () {
      final before = poolStats(_fixture, gameMode: _people).total;
      final after = poolStats(_fixture,
          gameMode: _people, usedWordKeys: const {'эйнштейн'}).total;
      expect(after, before - 1);
      expect(poolStats(_fixture,
          gameMode: _words, usedWordKeys: const {'эйнштейн'}).total, 4);
    });
  });

  group('starting a round', () {
    test('the pair always comes from the chosen mode', () {
      final container = _container();
      for (final mode in GameMode.values) {
        container.read(gameSessionProvider.notifier).startGame(_config(mode));
        expect(container.read(gameSessionProvider)!.wordPair.gameMode, mode);
        expect(container.read(gameSessionProvider)!.config.gameMode, mode);
      }
    });

    test('an empty pool blocks the start instead of borrowing another mode',
        () {
      const noPlaces = [
        WordCategory(
          id: 'w',
          name: 'Слова',
          icon: Icons.abc,
          pairs: [WordPair('Маяк', 'Прожектор', _e, ['свет'], 5)],
        ),
      ];
      final container = _container(pack: noPlaces);
      expect(container.read(gameSessionProvider.notifier).startGame(_config(_places)),
          isFalse);
      expect(container.read(gameSessionProvider), isNull);
      // And the words mode of the same pack still plays.
      expect(container.read(gameSessionProvider.notifier).startGame(_config(_words)),
          isTrue);
    });

    test('a rematch stays in the mode of the round that just ended', () {
      final container = _container();
      final notifier = container.read(gameSessionProvider.notifier);
      notifier.startGame(_config(_places));
      expect(notifier.playAgainSamePlayers(), isTrue);
      expect(container.read(gameSessionProvider)!.wordPair.gameMode, _places);
    });

    test('an exhausted mode does not fall back, even with other modes full',
        () {
      final container = _container();
      final notifier = container.read(gameSessionProvider.notifier);
      // Burn the three places.
      for (var i = 0; i < 3; i++) {
        expect(notifier.startGame(_config(_places)), isTrue);
      }
      expect(notifier.startGame(_config(_places)), isFalse);
      expect(notifier.startGame(_config(_words)), isTrue,
          reason: 'the other modes are untouched by the exhausted one');
    });
  });

  group('hints belong to the words mode only', () {
    test('no personality or place pair can produce a hint', () {
      for (final category in allWordCategories) {
        for (final pair in category.pairs) {
          if (pair.gameMode == _words) continue;
          for (final side in [pair.civilianWord, pair.spyWord]) {
            expect(hintsFor(side, pair.difficulty, mode: pair.gameMode), isEmpty,
                reason: '${pair.id} would promise help that does not exist');
          }
        }
      }
    });

    test('the mode is what silences the hint, not an empty hint table', () {
      // «Замок» is a lock in the words base and a fortress in the places one.
      // The clue exists and still works where it was written — it is the mode
      // that keeps it out of a places round, so the guard above cannot pass
      // just because nobody ever authored a hint for these words.
      const shared = 'Замок';
      expect(hintsFor(shared, Difficulty.hard, mode: _words), isNotEmpty);
      expect(hintsFor(shared, Difficulty.hard, mode: _places), isEmpty);
    });
  });

  group('the original base is untouched', () {
    test('the words base only ever grew, and still declares nothing', () {
      const original = [
        'objects', 'people', 'animals', 'food', 'places', 'technology',
        'nature', 'movies', 'games', 'history', 'science', 'sports',
        'music', 'daily_life', 'abstract', 'phrases', 'adult',
      ];
      var count = 0;
      for (final id in original) {
        final category = allWordCategories.firstWhere((c) => c.id == id);
        for (final pair in category.pairs) {
          expect(pair.mode, isNull, reason: '${pair.id} was rewritten');
          expect(pair.gameMode, _words);
          count++;
        }
      }
      // 858 at the time the modes were introduced, 1019 once the rework
      // queue in `needs_rework.dart` was emptied back into the categories.
      // The number may grow again; what must never change is the line above
      // it — not one of these pairs declares a mode, so the words base is
      // still the base the other two modes were added beside.
      expect(count, 1019);
    });

    test('the new packs declare their mode all the way through', () {
      for (final (ids, mode) in [
        (['pers_screen', 'pers_sport', 'pers_history', 'pers_mind'], _people),
        (['place_cities', 'place_countries', 'place_nature', 'place_landmarks'],
            _places),
      ]) {
        for (final id in ids) {
          final category = allWordCategories.firstWhere((c) => c.id == id);
          expect(category.pairs.every((p) => p.gameMode == mode), isTrue,
              reason: id);
          expect(category.pairs, hasLength(32));
        }
      }
    });
  });

  group('on the setup screen', () {
    Future<ProviderContainer> pumpToFilters(
      WidgetTester tester, {
      Size size = const Size(1170, 2532),
      List<WordCategory> pack = _fixture,
    }) async {
      tester.view.physicalSize = size;
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

      await _tap(tester, 'Новая игра');
      for (var i = 0; i < 5; i++) {
        await tester.enterText(find.byKey(ValueKey('player-name-$i')), 'И${i + 1}');
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Далее'));
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('the three modes are offered and the pool follows the choice',
        (tester) async {
      final container = await pumpToFilters(tester);

      expect(find.text('Режим игры'), findsOneWidget);
      expect(find.text('В пуле: 4 пары'), findsOneWidget);

      await _tap(tester, 'Личности');
      expect(container.read(gameSetupProvider).gameMode, _people);
      expect(find.text('В пуле: 3 пары'), findsOneWidget);

      await _tap(tester, 'Места');
      expect(container.read(gameSetupProvider).gameMode, _places);
      expect(find.text('В пуле: 3 пары'), findsOneWidget);
    });

    testWidgets('the words/phrases split only exists in the words mode',
        (tester) async {
      await pumpToFilters(tester);
      await _scrollTo(tester, 'Тип контента');
      expect(find.text('Тип контента'), findsOneWidget);
      // Hints are a rule of play and live in the in-game settings; the setup
      // screen only shapes the pool.
      expect(find.text('Подсказки'), findsNothing);

      await _tap(tester, 'Личности');
      expect(find.text('Тип контента'), findsNothing,
          reason: 'personalities are neither words nor phrases');
    });

    testWidgets('only the categories of the chosen mode are offered',
        (tester) async {
      await pumpToFilters(tester);
      await _scrollTo(tester, 'Слова A');
      expect(find.text('Слова A'), findsOneWidget);

      await _tap(tester, 'Места');
      await _scrollTo(tester, 'Места A');
      expect(find.text('Места A'), findsOneWidget);
      expect(find.text('Слова A'), findsNothing);
    });

    testWidgets('an empty pool in a mode blocks the start', (tester) async {
      const noPeople = [
        WordCategory(
          id: 'w',
          name: 'Слова',
          icon: Icons.abc,
          pairs: [WordPair('Маяк', 'Прожектор', _e, ['свет'], 5)],
        ),
        WordCategory(
          id: 'l',
          name: 'Места',
          icon: Icons.place,
          pairs: [WordPair('Париж', 'Лондон', _e, ['с'], 5, mode: _places)],
        ),
      ];
      final container = await pumpToFilters(tester, pack: noPeople);

      await _tap(tester, 'Личности');
      expect(find.text('Нет подходящих пар'), findsOneWidget);
      await _tap(tester, 'Начать игру');
      expect(container.read(gameSessionProvider), isNull);

      // Another mode still plays — the empty one simply refuses.
      await _tap(tester, 'Места');
      await _tap(tester, 'Начать игру');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();
      expect(container.read(gameSessionProvider)!.wordPair.gameMode, _places);
    });

    testWidgets('a round starts in the chosen mode on a 320x568 screen',
        (tester) async {
      final container =
          await pumpToFilters(tester, size: const Size(960, 1704));

      await _tap(tester, 'Личности');
      expect(find.text('В пуле: 3 пары'), findsOneWidget);
      await _tap(tester, 'Начать игру');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();

      final session = container.read(gameSessionProvider)!;
      expect(session.wordPair.gameMode, _people);
      expect(session.config.gameMode, _people);
    });

    testWidgets('the mode section and its settings fit a 390x844 screen',
        (tester) async {
      final container =
          await pumpToFilters(tester, size: const Size(1170, 2532));

      // The section renders whole: title, all three modes, and the pool line
      // that reacts to them.
      await _scrollTo(tester, 'Режим игры');
      for (final mode in GameMode.values) {
        expect(find.text(mode.label), findsWidgets);
      }
      expect(tester.takeException(), isNull);

      await _tap(tester, 'Места');
      expect(find.text('В пуле: 3 пары'), findsOneWidget);
      // The words-only settings are gone with the mode, not just greyed out.
      expect(find.text('Тип контента'), findsNothing);
      expect(find.text('Подсказки'), findsNothing);
      expect(tester.takeException(), isNull);

      await _tap(tester, 'Начать игру');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();

      final session = container.read(gameSessionProvider)!;
      expect(session.wordPair.gameMode, _places);
      expect(session.config.gameMode, _places);
    });
  });
}

/// The step is a lazy list; bring a control into the build window, searching
/// downwards and then back up.
Future<void> _scrollTo(WidgetTester tester, String label) async {
  for (final direction in [-220.0, 220.0]) {
    for (var i = 0; i < 14 && find.text(label).evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView), Offset(0, direction));
      await tester.pumpAndSettle();
    }
    if (find.text(label).evaluate().isNotEmpty) return;
  }
}

Future<void> _tap(WidgetTester tester, String label) async {
  await _scrollTo(tester, label);
  await tester.ensureVisible(find.text(label).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).first);
  await tester.pumpAndSettle();
}
