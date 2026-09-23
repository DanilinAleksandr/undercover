import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undercover/app.dart';
import 'package:undercover/data/word_pack_registry.dart';
import 'package:undercover/logic/word_pack_selector.dart';
import 'package:undercover/models/content_type.dart';
import 'package:undercover/models/difficulty.dart';
import 'package:undercover/models/word_category.dart';
import 'package:undercover/models/word_pair.dart';
import 'package:undercover/models/game_mode.dart';
import 'package:undercover/providers/used_entries_provider.dart';
import 'package:undercover/providers/word_pack_provider.dart';
import 'package:undercover/utils/plural_ru.dart';

/// «Хватит примерно на N партий» is arithmetic over the real pool, not a
/// forecast model: available pairs divided by how many pairs an average round
/// takes out of that same pool. These pin the arithmetic and, more usefully,
/// that the number moves with the filters and with the history.

const _e = Difficulty.easy;
const _m = Difficulty.medium;
const _h = Difficulty.hard;

/// «Кошка» carries three pairs, so dealing it costs more than one pair — which
/// is exactly what the divisor is for.
const _fixture = [
  WordCategory(
    id: 'alpha',
    name: 'Альфа',
    icon: Icons.science,
    pairs: [
      WordPair('Кошка', 'Тигр', _e, ['усы и лапы'], 5),
      WordPair('Кошка', 'Лев', _m, ['кошачьи'], 5),
      WordPair('Кошка', 'Рысь', _h, ['дикая кошка'], 5),
      WordPair('Гиря', 'Якорь', _m, ['тяжесть'], 5),
      WordPair('Маяк', 'Прожектор', _h, ['свет'], 5),
      WordPair('Первое свидание', 'Тихий двор', _m, ['волнуешься'], 5),
    ],
  ),
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the divisor', () {
    test('a pool of pairs sharing no words burns exactly one per round', () {
      const independent = [
        WordCategory(
          id: 'ind',
          name: 'Независимые',
          icon: Icons.science,
          pairs: [
            WordPair('Гиря', 'Якорь', _m, ['тяжесть'], 5),
            WordPair('Маяк', 'Прожектор', _h, ['свет'], 5),
          ],
        ),
      ];
      expect(averageBurnPerGame(independent.first.pairs), 1.0);
      expect(poolStats(independent).estimatedGames, 2);
    });

    test('shared words push the burn above one', () {
      final burn = averageBurnPerGame(_fixture.first.pairs);
      expect(burn, greaterThan(1.0),
          reason: 'three pairs share «Кошка» — one deal spends all three');
      // 6 pairs, burn 2.0 -> three rounds.
      expect(poolStats(_fixture).estimatedGames, 3);
    });

    test('an empty pool forecasts nothing', () {
      final stats = poolStats(_fixture, selectedContentTypes: {ContentType.phrases},
          usedWordKeys: {'первое свидание'});
      expect(stats.isEmpty, isTrue);
      expect(stats.estimatedGames, 0);
    });

    test('a pool that holds anything is worth at least one round', () {
      const single = [
        WordCategory(
          id: 'one',
          name: 'Одна',
          icon: Icons.science,
          pairs: [WordPair('Гиря', 'Якорь', _m, ['тяжесть'], 5)],
        ),
      ];
      expect(poolStats(single).estimatedGames, 1);
    });
  });

  group('the estimate follows the filters', () {
    test('narrowing the difficulty lowers it', () {
      final all = poolStats(_fixture).estimatedGames;
      final mediumOnly = poolStats(_fixture, selectedDifficulties: {_m});
      expect(mediumOnly.total, lessThan(poolStats(_fixture).total));
      expect(mediumOnly.estimatedGames, lessThanOrEqualTo(all));
    });

    test('the content type changes it', () {
      final phrases = poolStats(_fixture, selectedContentTypes: {ContentType.phrases});
      expect(phrases.total, 1);
      expect(phrases.estimatedGames, 1);
      final words = poolStats(_fixture, selectedContentTypes: {ContentType.words});
      expect(words.estimatedGames, greaterThan(phrases.estimatedGames));
    });

    test('history lowers it as the evening goes on', () {
      final fresh = poolStats(_fixture);
      expect(fresh.estimatedGames, 3);

      // Spending a pair that shares nothing removes exactly one pair, so the
      // remaining rounds drop.
      final later = poolStats(_fixture, usedWordKeys: {'гиря', 'якорь'});
      expect(later.total, 5);
      expect(later.estimatedGames, lessThan(fresh.estimatedGames));
    });

    test('a smaller pool can still be worth the same number of rounds', () {
      // Spending «Кошка» removes three pairs at once, but everything left is
      // independent — half the pool, same number of rounds. The estimate
      // tracks what can be played, not what is stored.
      final later = poolStats(_fixture, usedWordKeys: {'кошка'});
      expect(later.total, 3);
      expect(later.estimatedGames, 3);
      expect(averageBurnPerGame(_fixture.first.pairs), greaterThan(1.0));
    });

    test('the real base gives a plausible, conservative number', () {
      final stats = poolStats(allWordCategories);
      expect(stats.total, greaterThan(600));
      // Simulating the whole base takes ~700 rounds; the estimate must be in
      // the same order of magnitude and must not over-promise wildly.
      expect(stats.estimatedGames, greaterThan(100));
      expect(stats.estimatedGames, lessThan(stats.total));
    });
  });

  group('the visibility threshold', () {
    /// Builds a pool of [size] independent pairs, so the burn is exactly one
    /// per round and the estimate equals the pair count.
    List<WordCategory> packOf(int size) => [
          WordCategory(
            id: 'gen',
            name: 'Сгенерированная',
            icon: Icons.science,
            pairs: [
              for (var i = 0; i < size; i++)
                WordPair('Слово$i', 'Пара$i', _m, ['тег'], 5),
            ],
          ),
        ];

    test('the threshold is a named constant, not a literal in the widget', () {
      expect(estimatedGamesVisibilityThreshold, 100);
    });

    test('exactly at the threshold the forecast still shows', () {
      final stats = poolStats(packOf(estimatedGamesVisibilityThreshold));
      expect(stats.estimatedGames, 100);
      expect(stats.showsForecast, isTrue);
    });

    test('one round past the threshold it hides', () {
      final stats = poolStats(packOf(estimatedGamesVisibilityThreshold + 1));
      expect(stats.estimatedGames, 101);
      expect(stats.showsForecast, isFalse);
    });

    test('a huge pool hides it too', () {
      final stats = poolStats(packOf(1200));
      expect(stats.estimatedGames, 1200);
      expect(stats.showsForecast, isFalse);
    });

    test('an empty pool has nothing to show either', () {
      expect(poolStats(packOf(0)).showsForecast, isFalse);
    });

    test('the threshold is about rounds, not pairs', () {
      // 150 pairs, but they all share one word: a single round takes the lot,
      // so the forecast is worth showing even though the pool is large.
      final clustered = [
        WordCategory(
          id: 'cluster',
          name: 'Связка',
          icon: Icons.science,
          pairs: [
            for (var i = 0; i < 150; i++)
              WordPair('Кошка', 'Пара$i', _m, ['тег'], 5),
          ],
        ),
      ];
      final stats = poolStats(clustered);
      expect(stats.total, 150);
      expect(stats.estimatedGames, 1);
      expect(stats.showsForecast, isTrue);
    });

    test('the real base is far past the threshold', () {
      expect(poolStats(allWordCategories).showsForecast, isFalse);
    });
  });

  group('the wording', () {
    test('партия is declined with the number', () {
      expect(gamesLabel(1), '1 партия');
      expect(gamesLabel(3), '3 партии');
      expect(gamesLabel(5), '5 партий');
      expect(gamesLabel(11), '11 партий');
      expect(gamesLabel(21), '21 партия');
      expect(gamesLabel(30), '30 партий');
    });
  });

  group('on the filter screen', () {
    testWidgets('the line appears with the pool and moves with it',
        (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [wordPackProvider.overrideWithValue(_fixture)],
      );
      addTearDown(container.dispose);
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
      for (var i = 0; i < 5; i++) {
        await tester.enterText(find.byKey(ValueKey('player-name-$i')), 'И${i + 1}');
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Далее'));
      await tester.pumpAndSettle();

      expect(find.text('В пуле: 6 пар'), findsOneWidget);
      expect(find.text('Хватит примерно на 3 партии'), findsOneWidget);

      // Playing a round moves both numbers.
      container.read(usedEntriesProvider.notifier).markUsed(GameMode.words, 
          const WordPair('Гиря', 'Якорь', _m, ['тяжесть'], 5));
      await tester.pumpAndSettle();
      expect(find.text('В пуле: 5 пар'), findsOneWidget);
      expect(find.text('Хватит примерно на 2 партии'), findsOneWidget);

      // An empty pool drops the forecast entirely and keeps the old message.
      for (final pair in _fixture.expand((c) => c.pairs)) {
        container.read(usedEntriesProvider.notifier).markUsed(GameMode.words, pair);
      }
      await tester.pumpAndSettle();
      expect(find.textContaining('Хватит примерно на'), findsNothing);
      expect(find.text('Все подходящие ответы режима уже использованы'),
          findsOneWidget);
    });

    testWidgets('a pool past the threshold shows the count without a forecast',
        (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 120 independent pairs: one round each, so 120 estimated rounds.
      final wide = [
        WordCategory(
          id: 'wide',
          name: 'Широкая',
          icon: Icons.science,
          pairs: [
            for (var i = 0; i < 120; i++)
              WordPair('Слово$i', 'Пара$i', _m, ['тег'], 5),
          ],
        ),
      ];
      final container = ProviderContainer(
        overrides: [wordPackProvider.overrideWithValue(wide)],
      );
      addTearDown(container.dispose);
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
      for (var i = 0; i < 5; i++) {
        await tester.enterText(find.byKey(ValueKey('player-name-$i')), 'И${i + 1}');
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Далее'));
      await tester.pumpAndSettle();

      expect(find.text('В пуле: 120 пар'), findsOneWidget);
      expect(find.textContaining('Хватит примерно на'), findsNothing,
          reason: '120 rounds is past the threshold — the line adds nothing');
    });
  });
}
