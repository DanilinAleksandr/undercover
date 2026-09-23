import 'package:flutter_test/flutter_test.dart';
import 'package:undercover/data/word_pack_registry.dart';
import 'package:undercover/models/difficulty.dart';

/// Not an assertion suite so much as a readout: run this to see how the base
/// is distributed across categories and difficulty levels.
void main() {
  test('word base statistics', () {
    var totalPairs = 0;
    final byDifficulty = <Difficulty, int>{for (final d in Difficulty.values) d: 0};

    // ignore: avoid_print
    print('\n--- Категории ---');
    for (final category in allWordCategories) {
      totalPairs += category.pairs.length;
      for (final pair in category.pairs) {
        byDifficulty[pair.difficulty] = byDifficulty[pair.difficulty]! + 1;
      }
      final breakdown = Difficulty.values
          .map((d) => '${d.name}:${category.pairsOfDifficulty(d).length}')
          .join(' ');
      // ignore: avoid_print
      print('${category.name.padRight(24)} ${category.pairs.length} пар  ($breakdown)');
    }

    // ignore: avoid_print
    print('\n--- Сложность ---');
    for (final entry in byDifficulty.entries) {
      // ignore: avoid_print
      print('${entry.key.label.padRight(16)} ${entry.value} пар');
    }
    // ignore: avoid_print
    print('\nВСЕГО: $totalPairs пар = ${totalPairs * 2} слов '
        'в ${allWordCategories.length} категориях\n');

    expect(totalPairs, greaterThan(0));
  });
}
