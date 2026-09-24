import 'package:flutter_test/flutter_test.dart';
import 'package:undercover/data/theme_pack_registry.dart';
import 'package:undercover/data/word_pack_registry.dart';
import 'package:undercover/models/difficulty.dart';
import 'package:undercover/models/theme_pair.dart';
import 'package:undercover/models/word_pair.dart';

/// Automated vetting of the «Самозванец» base.
///
/// Most of what makes a theme pair good is editorial and lives in the
/// [ThemePair] docstring: the decoy is its own topic, close in spirit but with
/// items that do not fit the theme, and both are worded broadly. What can be
/// checked mechanically is checked here — the shape, the spread across tiers,
/// and the ways a pair can be the same theme twice that text alone reveals.

/// Longest theme a card still prints at a readable size.
///
/// The card scales the text down to fit one line, so length is legibility:
/// «Souls-игры FromSoftware» still reads comfortably, twice that would not.
const _maxThemeLength = 28;

/// Pairs that are one theme under two names — a subtype, a sequel, the same
/// universe. Kept explicit so a regression is caught by name.
const _sameTheme = <List<String>>[
  ['dark souls', 'elden ring'],
  ['clash of clans', 'clash royale'],
  ['кухня', 'отель элеон'],
  ['half-life', 'portal'],
  ['12 стульев', 'золотой теленок'],
  ['комиксы', 'манга'],
];

String _norm(String value) => WordPair.normalizeWord(value);

void main() {
  final allPairs = <ThemePair>[
    for (final category in allThemeCategories) ...category.pairs,
  ];

  group('structure', () {
    test('every pack is uniquely identified and apart from the word base', () {
      final wordIds = allWordCategories.map((c) => c.id).toSet();
      final ids = <String>{};
      for (final category in allThemeCategories) {
        expect(ids.add(category.id), isTrue, reason: 'duplicate ${category.id}');
        expect(category.id.startsWith('theme_'), isTrue, reason: category.id);
        expect(wordIds, isNot(contains(category.id)), reason: category.id);
        expect(category.name.trim(), isNotEmpty);
      }
    });

    test('each pack holds 20-25 pairs', () {
      for (final category in allThemeCategories) {
        expect(category.pairs.length, inInclusiveRange(20, 25),
            reason: '${category.id} has ${category.pairs.length}');
      }
    });

    test('every tier of every pack has at least three pairs to draw', () {
      // The difficulty filter applies here too; a tier of one pair would
      // deal the same round every time it is picked.
      for (final category in allThemeCategories) {
        for (final level in Difficulty.values) {
          final n = category.pairs.where((p) => p.difficulty == level).length;
          expect(n, greaterThanOrEqualTo(3),
              reason: '${category.id}/${level.name} has $n');
        }
      }
    });
  });

  group('a card reads at a glance', () {
    test('both sides are present and short enough', () {
      for (final pair in allPairs) {
        for (final side in [pair.theme, pair.decoyTheme]) {
          expect(side.trim(), isNotEmpty);
          expect(side, side.trim(), reason: 'stray whitespace in "$side"');
          expect(side.length, lessThanOrEqualTo(_maxThemeLength),
              reason: '"$side" is too long for a card');
        }
      }
    });
  });

  group('a pair is two themes, not one', () {
    test('the sides differ and neither contains the other', () {
      // «Гарри Поттер» / «Гарри Поттер и Кубок огня» is one theme narrowed,
      // not two.
      for (final pair in allPairs) {
        final a = _norm(pair.theme);
        final b = _norm(pair.decoyTheme);
        expect(a, isNot(b), reason: '${pair.theme} twice');
        expect(a.contains(b) || b.contains(a), isFalse,
            reason: '${pair.theme} / ${pair.decoyTheme}');
      }
    });

    test('no pair from the same-theme list', () {
      for (final pair in allPairs) {
        final actual = {_norm(pair.theme), _norm(pair.decoyTheme)};
        for (final same in _sameTheme) {
          expect(actual, isNot(equals(same.toSet())),
              reason: '${pair.theme} / ${pair.decoyTheme} is one theme');
        }
      }
    });

    test('no pair repeats, in either direction', () {
      final seen = <String>{};
      for (final pair in allPairs) {
        final key = pair.toWordPair().historyKey;
        expect(seen.add(key), isTrue,
            reason: '${pair.theme} / ${pair.decoyTheme} is already in the base');
      }
    });

    test('no theme dominates the base', () {
      // History spends a theme on either side, so a theme in many pairs
      // takes all of them with it the first time it is dealt.
      final uses = <String, int>{};
      for (final pair in allPairs) {
        for (final side in [pair.theme, pair.decoyTheme]) {
          uses.update(_norm(side), (v) => v + 1, ifAbsent: () => 1);
        }
      }
      final overused = uses.entries.where((e) => e.value > 2).toList();
      expect(overused, isEmpty,
          reason: overused.map((e) => '${e.key} x${e.value}').join(', '));
    });
  });

  group('play value', () {
    test('no pair scored 1-2 ships', () {
      for (final pair in allPairs) {
        expect(pair.score, inInclusiveRange(3, 5),
            reason: '${pair.theme} / ${pair.decoyTheme}');
      }
    });

    test('the base is predominantly 4-5', () {
      final prime = allPairs.where((p) => p.score >= 4).length;
      expect(prime / allPairs.length, greaterThanOrEqualTo(0.75));
    });
  });
}
