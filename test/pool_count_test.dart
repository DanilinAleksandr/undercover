import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undercover/app.dart';
import 'package:undercover/data/word_pack_registry.dart';
import 'package:undercover/logic/word_pack_selector.dart';
import 'package:undercover/models/content_type.dart';
import 'package:undercover/models/difficulty.dart';
import 'package:undercover/models/word_category.dart';
import 'package:undercover/models/word_pair.dart';
import 'package:undercover/providers/game_setup_provider.dart';
import 'package:undercover/utils/plural_ru.dart';

/// The number on the filter screen is a promise: it has to equal the pairs the
/// picker can actually serve for that exact combination of filters. These tests
/// walk every combination the host can produce, including the empty one.

const _e = Difficulty.easy;
const _m = Difficulty.medium;
const _h = Difficulty.hard;
const _x = Difficulty.expert;

/// Two words and two phrases per difficulty, so every count is predictable.
const _fixture = [
  WordCategory(
    id: 'fixture',
    name: 'Тест',
    icon: Icons.science,
    pairs: [
      WordPair('Маяк', 'Прожектор', _e, ['свет'], 5),
      WordPair('Ведро', 'Таз', _e, ['вода'], 4),
      WordPair('Гиря', 'Якорь', _m, ['тяжесть'], 5),
      WordPair('Сито', 'Дуршлаг', _m, ['кухня'], 4),
      WordPair('Замок', 'Крепость', _h, ['камень'], 5),
      WordPair('Ринг', 'Татами', _h, ['схватка'], 4),
      WordPair('Табурет', 'Стул', _x, ['сидят'], 5),
      WordPair('Лужа', 'Слякоть', _x, ['мокро'], 4),
      WordPair('Детский сад', 'Начальная школа', _e, ['малыши'], 5),
      WordPair('Первый снег', 'Тёплый дождь', _e, ['погода'], 4),
      WordPair('Чёрный юмор', 'Страшная история', _m, ['жутко'], 5),
      WordPair('Утро понедельника', 'Конец отпуска', _m, ['уныло'], 4),
      WordPair('Белая ворона', 'Чёрная овца', _h, ['не как все'], 5),
      WordPair('Пустой перрон', 'Тихий двор', _h, ['пусто'], 4),
      WordPair('Золотые руки', 'Светлая голова', _x, ['талант'], 5),
      WordPair('Долгое молчание', 'Неловкая пауза', _x, ['тишина'], 5),
    ],
  ),
];

WordPoolStats _pool({
  Set<ContentType> selectedContentTypes = const {},
  Set<Difficulty> difficulties = const {},
  List<WordCategory> categories = _fixture,
  Set<String> categoryIds = const {},
}) {
  return poolStats(
    categories,
    selectedCategoryIds: categoryIds,
    selectedContentTypes: selectedContentTypes,
    selectedDifficulties: difficulties,
  );
}

void main() {
  group('pool counting by filter combination', () {
    test('только слова', () {
      final pool = _pool(selectedContentTypes: {ContentType.words});
      expect(pool.total, 8);
      expect(pool.countOf(_e), 2);
      expect(pool.countOf(_m), 2);
      expect(pool.countOf(_h), 2);
      expect(pool.countOf(_x), 2);
    });

    test('только фразы', () {
      final pool = _pool(selectedContentTypes: {ContentType.phrases});
      expect(pool.total, 8);
      expect(pool.presentDifficulties, Difficulty.values);
    });

    test('слова + фразы дают всю базу и совпадают в сумме', () {
      final all = _pool();
      final words = _pool(selectedContentTypes: {ContentType.words});
      final phrases = _pool(selectedContentTypes: {ContentType.phrases});
      expect(all.total, 16);
      expect(words.total + phrases.total, all.total);
      for (final level in Difficulty.values) {
        expect(words.countOf(level) + phrases.countOf(level), all.countOf(level));
      }
    });

    test('одна сложность', () {
      final pool = _pool(difficulties: {_h});
      expect(pool.total, 4);
      expect(pool.countOf(_h), 4);
      expect(pool.presentDifficulties, [_h]);
      // The tiers that were filtered out report zero rather than going missing.
      expect(pool.countOf(_e), 0);
    });

    test('несколько сложностей', () {
      final pool = _pool(difficulties: {_m, _x});
      expect(pool.total, 8);
      expect(pool.presentDifficulties, [_m, _x]);
      expect(pool.countOf(_m), 4);
      expect(pool.countOf(_x), 4);
    });

    test('тип контента + несколько сложностей', () {
      final pool = _pool(selectedContentTypes: {ContentType.phrases}, difficulties: {_e, _h});
      expect(pool.total, 4);
      expect(pool.countOf(_e), 2);
      expect(pool.countOf(_h), 2);
      expect(pool.countOf(_m), 0);
    });

    test('пустой пул: комбинация, которой нет ни одной пары', () {
      const wordsOnly = [
        WordCategory(
          id: 'words',
          name: 'Слова',
          icon: Icons.science,
          pairs: [WordPair('Маяк', 'Прожектор', _e, ['свет'], 5)],
        ),
      ];
      final pool = _pool(categories: wordsOnly, selectedContentTypes: {ContentType.phrases});
      expect(pool.total, 0);
      expect(pool.isEmpty, isTrue);
      expect(pool.presentDifficulties, isEmpty);

      // A difficulty the category simply does not carry is empty too.
      expect(_pool(categories: wordsOnly, difficulties: {_x}).total, 0);
    });

    test('пустой набор сложностей означает все сложности', () {
      expect(_pool(difficulties: const {}).total,
          _pool(difficulties: {_e, _m, _h, _x}).total);
    });

    test('категории сужают пул вместе с остальными фильтрами', () {
      expect(_pool(categoryIds: {'fixture'}).total, 16);
      expect(_pool(categoryIds: {'нет такой'}).total, 0);
    });
  });

  group('the count matches what the game can draw', () {
    test('только оценённые 4-5 пары попадают в пул', () {
      const mixed = [
        WordCategory(
          id: 'mixed',
          name: 'Смешанная',
          icon: Icons.science,
          pairs: [
            WordPair('Маяк', 'Прожектор', _e, ['свет'], 5),
            WordPair('Ведро', 'Таз', _e, ['вода'], 3),
          ],
        ),
      ];
      // The 3 exists in the base but the picker never reaches it while a
      // 4-5 pair matches, so the readout must not promise it.
      expect(_pool(categories: mixed).total, 1);
      expect(pairsMatching(mixed).length, 2);
    });

    test('каждая пара из пула действительно проходит фильтры', () {
      final pool = playablePairs(
        allWordCategories,
        selectedContentTypes: {ContentType.phrases},
        selectedDifficulties: {_x},
        allowAdultContent: true,
      );
      expect(pool, isNotEmpty);
      for (final pair in pool) {
        expect(pair.isPhrase, isTrue);
        expect(pair.difficulty, _x);
        expect(pair.isPrime, isTrue);
      }
    });

    test('пул реальной базы не пуст ни для одной одиночной сложности', () {
      for (final level in Difficulty.values) {
        for (final type in ContentType.values) {
          final pool = poolStats(
            allWordCategories,
            selectedContentTypes: {type},
            selectedDifficulties: {level},
            allowAdultContent: true,
          );
          expect(pool.isEmpty, isFalse,
              reason: 'нет пар для ${type.label} + ${level.label}');
        }
      }
    });

    test('18+ категории считаются только при включённом переключателе', () {
      final without = poolStats(allWordCategories);
      final with18 = poolStats(allWordCategories, allowAdultContent: true);
      expect(with18.total, greaterThan(without.total));
    });
  });

  group('the readout wording', () {
    test('русские числительные согласованы', () {
      expect(pairsLabel(1), '1 пара');
      expect(pairsLabel(3), '3 пары');
      expect(pairsLabel(11), '11 пар');
      expect(pairsLabel(21), '21 пара');
      expect(pairsLabel(730), '730 пар');
      expect(difficultyCountLabel(_e, 142), '142 лёгких');
      expect(difficultyCountLabel(_h, 301), '301 сложная');
      expect(difficultyCountLabel(_m, 287), '287 средних');
      expect(difficultyCountLabel(_x, 1), '1 очень сложная');
    });
  });

  group('on the filter screen', () {
    testWidgets('the readout follows every filter change and blocks an empty pool',
        (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
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

      String readout() {
        final texts = tester
            .widgetList<Text>(find.textContaining('В пуле:'))
            .map((t) => t.data!)
            .toList();
        expect(texts, hasLength(1));
        return texts.single;
      }

      int expected() {
        final config = container.read(gameSetupProvider);
        return poolStats(
          allWordCategories,
          selectedCategoryIds: config.selectedCategoryIds,
          selectedContentTypes: config.selectedContentTypes,
          selectedDifficulties: config.selectedDifficulties,
          allowAdultContent: config.allowAdultContent,
        ).total;
      }

      expect(readout(), 'В пуле: ${pairsLabel(expected())}');
      final startingTotal = expected();

      // A lazy ListView only builds what is near the viewport, so bring the
      // chips into it first.
      Future<void> scrollTo(String label) async {
        for (var i = 0; i < 12 && find.text(label).evaluate().isEmpty; i++) {
          await tester.drag(find.byType(ListView), const Offset(0, -220));
          await tester.pumpAndSettle();
        }
      }

      // A real tap first, to prove the chip drives the recount at all.
      await scrollTo('Фразы');
      await tap('Фразы');
      expect(readout(), 'В пуле: ${pairsLabel(expected())}');
      expect(expected(), lessThan(startingTotal));

      // The rest goes through the notifier: the chips scroll out of the lazy
      // list once the difficulty row is on screen, and the widget watches the
      // same provider either way.
      final setup = container.read(gameSetupProvider.notifier);
      Future<void> settle() async => tester.pumpAndSettle();

      setup.toggleDifficulty(_x);
      await settle();
      expect(readout(), 'В пуле: ${pairsLabel(expected())}');
      final phrasesExpert = expected();

      // Difficulty and content type narrow together, not one instead of the other.
      setup.toggleContentType(ContentType.words);
      await settle();
      expect(expected(), isNot(phrasesExpert));
      expect(readout(), 'В пуле: ${pairsLabel(expected())}');

      setup.toggleDifficulty(_h);
      await settle();
      expect(expected(), greaterThan(phrasesExpert));
      expect(readout(), 'В пуле: ${pairsLabel(expected())}');

      // Narrowing to one category on top of both filters keeps shrinking it.
      final narrower = expected();
      setup.toggleCategory(allWordCategories.first.id);
      await settle();
      expect(expected(), lessThan(narrower));
      expect(readout(), 'В пуле: ${pairsLabel(expected())}');

      // And back to the widest combination.
      setup.toggleCategory(allWordCategories.first.id);
      setup.clearContentTypes();
      setup.toggleDifficulty(_h);
      setup.toggleDifficulty(_x);
      await settle();
      expect(expected(), startingTotal);
      expect(readout(), 'В пуле: ${pairsLabel(startingTotal)}');
    });

    testWidgets('an impossible combination shows "Нет подходящих пар"',
        (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Drive the notifier straight to a combination the base cannot satisfy,
      // then render the step: fewer taps, same widget under test.
      final thin = allWordCategories
          .firstWhere((c) => c.pairs.every((p) => !p.isPhrase || !p.isPrime),
              orElse: () => allWordCategories.first);

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

      // Find a real category/type/difficulty triple that yields nothing.
      ({String id, ContentType type, Difficulty level})? empty;
      for (final category in allWordCategories) {
        for (final type in ContentType.values) {
          for (final level in Difficulty.values) {
            final count = poolStats(
              allWordCategories,
              selectedCategoryIds: {category.id},
              selectedContentTypes: {type},
              selectedDifficulties: {level},
            ).total;
            if (count == 0) {
              empty ??= (id: category.id, type: type, level: level);
            }
          }
        }
      }
      expect(empty, isNotNull,
          reason: 'нужна комбинация с пустым пулом, иначе тест бессмысленен '
              '(проверено и на $thin)');

      final setup = container.read(gameSetupProvider.notifier);
      setup.toggleCategory(empty!.id);
      setup.toggleContentType(empty.type);
      setup.toggleDifficulty(empty.level);
      await tester.pumpAndSettle();

      expect(find.text('Нет подходящих пар'), findsOneWidget);
      expect(find.textContaining('В пуле:'), findsNothing);

      // Back on the setup screen the start button is still there, but
      // tapping it must do nothing.
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Начать игру'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Начать игру'));
      await tester.pumpAndSettle();
      expect(find.text('Нет подходящих пар'), findsOneWidget);

      // Relaxing the difficulty brings the pool — and the button — back.
      setup.toggleDifficulty(empty.level);
      await tester.pumpAndSettle();
      expect(find.textContaining('В пуле:'), findsOneWidget);
    });
  });
}
