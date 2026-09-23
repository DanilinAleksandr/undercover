import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undercover/logic/word_pack_selector.dart';
import 'package:undercover/models/difficulty.dart';
import 'package:undercover/models/word_category.dart';
import 'package:undercover/models/word_pair.dart';

void main() {
  const category = WordCategory(
    id: 'cat',
    name: 'Категория',
    icon: Icons.category,
    pairs: [
      WordPair('Маяк', 'Прожектор', Difficulty.easy, ['свет'], 5),
      WordPair('Компас', 'Навигатор', Difficulty.hard, ['направление'], 5),
    ],
  );

  const other = WordCategory(
    id: 'other',
    name: 'Другая',
    icon: Icons.star,
    pairs: [WordPair('Гиря', 'Якорь', Difficulty.medium, ['тяжесть'], 5)],
  );

  const adult = WordCategory(
    id: 'adult',
    name: '18+',
    icon: Icons.no_adult_content,
    isAdult: true,
    pairs: [WordPair('Казино', 'Биржа', Difficulty.medium, ['ставка'], 5)],
  );

  test('draws only from the pairs the filters left', () {
    for (var i = 0; i < 10; i++) {
      final pair = pickWordPair(
        categories: const [category],
        selectedCategoryIds: const {},
        selectedDifficulties: const {Difficulty.hard},
      );
      expect(pair!.difficulty, Difficulty.hard);
    }
  });

  test('restricts to the selected categories only', () {
    final pair = pickWordPair(
      categories: const [category, other],
      selectedCategoryIds: const {'other'},
    );
    expect(pair!.civilianWord, 'Гиря');
  });

  test('an impossible filter returns null instead of quietly relaxing itself', () {
    // The old behaviour dropped the difficulty and dealt something else; the
    // pool counter now promises this combination is unplayable, so the picker
    // has to agree with it.
    final pair = pickWordPair(
      categories: const [other],
      selectedCategoryIds: const {},
      selectedDifficulties: const {Difficulty.expert},
    );
    expect(pair, isNull);
  });

  test('hides adult categories unless adult content is allowed', () {
    for (var i = 0; i < 10; i++) {
      final pair = pickWordPair(
        categories: const [other, adult],
        selectedCategoryIds: const {},
      );
      expect(pair!.civilianWord, 'Гиря');
    }
    expect(
      visibleCategories(const [other, adult], allowAdultContent: true).length,
      2,
    );
  });

  test('a pair holding a played word is never dealt again', () {
    final first = pickWordPair(
      categories: const [category],
      selectedCategoryIds: const {},
    )!;
    for (var i = 0; i < 10; i++) {
      final next = pickWordPair(
        categories: const [category],
        selectedCategoryIds: const {},
        usedWordKeys: {...first.wordKeys},
      );
      expect(next!.wordKeys.any(first.wordKeys.contains), isFalse);
    }
  });

  test('one played word is enough to empty the pool', () {
    final pair = pickWordPair(
      categories: const [other],
      selectedCategoryIds: const {},
      usedWordKeys: {'якорь'},
    );
    expect(pair, isNull, reason: 'the spy side of the pair was already heard');
  });

  test('the 3s become reachable once every good pair is played', () {
    const mixed = [
      WordCategory(
        id: 'mixed',
        name: 'Смешанная',
        icon: Icons.category,
        pairs: [
          WordPair('Маяк', 'Прожектор', Difficulty.easy, ['свет'], 5),
          WordPair('Гиря', 'Якорь', Difficulty.easy, ['тяжесть'], 3),
        ],
      ),
    ];
    expect(playablePairs(mixed).map((p) => p.id), ['Маяк/Прожектор']);
    expect(
      playablePairs(mixed, usedWordKeys: {'маяк'}).map((p) => p.id),
      ['Гиря/Якорь'],
    );
  });

  group('the history key identifies a pair, not an order', () {
    test('A/B and B/A are the same pair', () {
      const ab = WordPair('Кошка', 'Собака', Difficulty.easy, ['питомец'], 5);
      const ba = WordPair('Собака', 'Кошка', Difficulty.easy, ['питомец'], 5);
      expect(ab.historyKey, ba.historyKey);
      expect(ab.id, isNot(ba.id));

      final pair = pickWordPair(
        categories: const [
          WordCategory(
            id: 'swap',
            name: 'Обратная',
            icon: Icons.category,
            pairs: [ba],
          ),
        ],
        selectedCategoryIds: const {},
        usedWordKeys: {...ab.wordKeys},
      );
      expect(pair, isNull,
          reason: 'the words are the same however the pair is written');
    });

    test('case and ё do not create a second identity', () {
      const a = WordPair('Ёлка', 'Сосна', Difficulty.easy, ['хвоя'], 5);
      const b = WordPair('сосна', 'елка', Difficulty.easy, ['хвоя'], 5);
      expect(a.historyKey, b.historyKey);
    });
  });
}
