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
import 'package:undercover/providers/game_session_provider.dart';
import 'package:undercover/providers/game_setup_provider.dart';

/// The content-type and difficulty filters must intersect, never replace each
/// other. These cover the combinations plus the edge cases that decide whether
/// a round can still start.

const _e = Difficulty.easy;
const _m = Difficulty.medium;
const _h = Difficulty.hard;
const _x = Difficulty.expert;

/// A miniature base with a known pair in every content/difficulty cell.
const _fixture = [
  WordCategory(
    id: 'fixture',
    name: 'Тест',
    icon: Icons.science,
    pairs: [
      WordPair('Маяк', 'Прожектор', _e, ['свет'], 5),
      WordPair('Гиря', 'Якорь', _m, ['тяжесть'], 5),
      WordPair('Замок', 'Крепость', _h, ['камень'], 5),
      WordPair('Табурет', 'Стул', _x, ['сидят'], 5),
      WordPair('Детский сад', 'Начальная школа', _e, ['малыши'], 5),
      WordPair('Чёрный юмор', 'Страшная история', _m, ['жутко'], 5),
      WordPair('Белая ворона', 'Чёрная овца', _h, ['не как все'], 5),
      WordPair('Золотые руки', 'Светлая голова', _x, ['талант'], 5),
    ],
  ),
];

Set<String> _idsFor({
  Set<ContentType> selectedContentTypes = const {},
  Set<Difficulty> difficulties = const {},
}) {
  return pairsMatching(
    _fixture,
    selectedContentTypes: selectedContentTypes,
    selectedDifficulties: difficulties,
  ).map((p) => p.id).toSet();
}

void main() {
  group('pair classification', () {
    test('single-word pairs and phrase pairs are complementary', () {
      for (final category in allWordCategories) {
        for (final pair in category.pairs) {
          expect(pair.isPhrase, isNot(pair.isWordsOnly),
              reason: '${pair.id} must fall in exactly one bucket');
        }
      }
    });

    test('a pair counts as a phrase when either side is multi-word', () {
      const oneSide = WordPair('Похмелье', 'Ночной клуб', _e, ['утро'], 4);
      expect(oneSide.isPhrase, isTrue);
      expect(const WordPair('Маяк', 'Прожектор', _e, ['свет'], 5).isPhrase, isFalse);
    });

    test('every pair in the base is reachable through some content type', () {
      // The four kinds partition the base exactly: no pair may be unreachable
      // under every filter, and none may answer to two of them.
      final all = pairsMatching(allWordCategories, allowAdultContent: true).length;
      var sum = 0;
      for (final type in ContentType.values) {
        final count = pairsMatching(allWordCategories,
                selectedContentTypes: {type}, allowAdultContent: true)
            .length;
        expect(count, greaterThan(0), reason: 'nothing to play for ${type.label}');
        sum += count;
      }
      expect(sum, all);
    });
  });

  group('filters intersect', () {
    test('"Всё" + лёгкая/средняя = слова И фразы этих сложностей', () {
      expect(
        _idsFor(selectedContentTypes: const {}, difficulties: {_e, _m}),
        {
          'Маяк/Прожектор',
          'Гиря/Якорь',
          'Детский сад/Начальная школа',
          'Чёрный юмор/Страшная история',
        },
      );
    });

    test('"Слова" + лёгкая/средняя = только слова этих сложностей', () {
      expect(
        _idsFor(selectedContentTypes: {ContentType.words}, difficulties: {_e, _m}),
        {'Маяк/Прожектор', 'Гиря/Якорь'},
      );
    });

    test('"Фразы" + средняя = только фразы средней сложности', () {
      expect(
        _idsFor(selectedContentTypes: {ContentType.phrases}, difficulties: {_m}),
        {'Чёрный юмор/Страшная история'},
      );
    });

    test('"Всё" + все сложности = вся база', () {
      expect(
        _idsFor(selectedContentTypes: const {}, difficulties: {_e, _m, _h, _x}).length,
        _fixture.first.pairs.length,
      );
    });

    test('пустой набор сложностей означает все сложности', () {
      expect(
        _idsFor(selectedContentTypes: {ContentType.phrases}),
        _idsFor(selectedContentTypes: {ContentType.phrases}, difficulties: {_e, _m, _h, _x}),
      );
      expect(_idsFor().length, _fixture.first.pairs.length);
    });

    test('difficulty alone does not widen the content type', () {
      final words = _idsFor(selectedContentTypes: {ContentType.words}, difficulties: {_x});
      expect(words, {'Табурет/Стул'});
      final phrases = _idsFor(selectedContentTypes: {ContentType.phrases}, difficulties: {_x});
      expect(phrases, {'Золотые руки/Светлая голова'});
      expect(words.intersection(phrases), isEmpty);
    });
  });

  group('drawing a pair', () {
    test('respects both filters at once over many draws', () {
      for (var i = 0; i < 60; i++) {
        final pair = pickWordPair(
          categories: _fixture,
          selectedCategoryIds: const {},
          selectedContentTypes: {ContentType.phrases},
          selectedDifficulties: const {_h, _x},
        );
        expect(pair!.isPhrase, isTrue);
        expect({_h, _x}, contains(pair.difficulty));
      }
    });

    test('honours the content type across the real base', () {
      for (var i = 0; i < 60; i++) {
        final pair = pickWordPair(
          categories: allWordCategories,
          selectedCategoryIds: const {},
          selectedContentTypes: {ContentType.words},
          selectedDifficulties: const {_e},
        );
        expect(pair!.isWordsOnly, isTrue);
        expect(pair.difficulty, _e);
      }
    });

    test('an impossible combination draws nothing rather than something else',
        () {
      const onlyEasy = [
        WordCategory(
          id: 'thin',
          name: 'Тонкая',
          icon: Icons.science,
          pairs: [
            WordPair('Маяк', 'Прожектор', _e, ['свет'], 5),
            WordPair('Детский сад', 'Начальная школа', _e, ['малыши'], 5),
          ],
        ),
      ];
      // No hard phrases here. The filter screen already reports zero for this
      // combination and blocks the start, so the picker must not invent a
      // round out of a pair the host filtered out.
      expect(
        pickWordPair(
          categories: onlyEasy,
          selectedCategoryIds: const {},
          selectedContentTypes: {ContentType.phrases},
          selectedDifficulties: const {_h},
        ),
        isNull,
      );
      // The same categories still play fine once the filter matches something.
      expect(
        pickWordPair(
          categories: onlyEasy,
          selectedCategoryIds: const {},
          selectedContentTypes: {ContentType.phrases},
        )!.isPhrase,
        isTrue,
      );
    });

    test('a content type the categories do not carry draws nothing', () {
      const wordsOnly = [
        WordCategory(
          id: 'words',
          name: 'Слова',
          icon: Icons.science,
          pairs: [WordPair('Маяк', 'Прожектор', _e, ['свет'], 5)],
        ),
      ];
      expect(
        pickWordPair(
          categories: wordsOnly,
          selectedCategoryIds: const {},
          selectedContentTypes: {ContentType.phrases},
        ),
        isNull,
      );
    });
  });

  group('setup wiring', () {
    test('the notifier accumulates kinds and defaults to "Всё"', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(gameSetupProvider.notifier);
      expect(container.read(gameSetupProvider).selectedContentTypes, isEmpty);

      notifier.toggleContentType(ContentType.phrases);
      expect(container.read(gameSetupProvider).selectedContentTypes,
          {ContentType.phrases});

      // A second kind adds to the first rather than replacing it, and the
      // difficulty filter is not disturbed either way.
      notifier.toggleDifficulty(_h);
      notifier.toggleContentType(ContentType.words);
      expect(container.read(gameSetupProvider).selectedDifficulties, {_h});
      expect(container.read(gameSetupProvider).selectedContentTypes,
          {ContentType.phrases, ContentType.words});

      // Tapping a selected kind again removes it; «Всё» clears the lot.
      notifier.toggleContentType(ContentType.phrases);
      expect(container.read(gameSetupProvider).selectedContentTypes,
          {ContentType.words});
      notifier.clearContentTypes();
      expect(container.read(gameSetupProvider).selectedContentTypes, isEmpty);
      expect(container.read(gameSetupProvider).selectedDifficulties, {_h});
    });

    testWidgets('choosing "Фразы" in setup starts a round on a phrase pair',
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
      // The list is the count now: drop the last two seats of the default five.
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

      // A lazy ListView only builds what is near the viewport, so bring the
      // chips into it first.
      Future<void> scrollTo(String label) async {
        for (var i = 0; i < 12 && find.text(label).evaluate().isEmpty; i++) {
          await tester.drag(find.byType(ListView), const Offset(0, -220));
          await tester.pumpAndSettle();
        }
      }

      await scrollTo('Тип контента');
      expect(find.text('Тип контента'), findsOneWidget);
      await scrollTo('Фразы');
      await tap('Фразы');
      await scrollTo('Сложные');
      await tap('Сложные');
      expect(container.read(gameSetupProvider).selectedContentTypes, {ContentType.phrases});
      expect(container.read(gameSetupProvider).selectedDifficulties, {_h});

      await tap('Начать игру');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();

      final drawn = container.read(gameSessionProvider)!.wordPair;
      expect(drawn.isPhrase, isTrue);
      expect(drawn.difficulty, _h);
    });
  });
}
