import 'package:flutter_test/flutter_test.dart';
import 'package:undercover/data/needs_rework.dart';
import 'package:undercover/data/word_pack_registry.dart';
import 'package:undercover/models/difficulty.dart';
import 'package:undercover/models/word_pair.dart';

/// Automated vetting of the bundled word base.
///
/// The base follows one rule: **simple words, hard pairs**. Two failure modes
/// break the game, and both are checked here:
///  * a pair that is too obvious (synonyms, shared stem, one word inside the
///    other) — the spy is exposed instantly;
///  * a word too rare or academic for an ordinary player — the round stalls
///    because nobody can form an association.

String _normalize(String word) =>
    word.toLowerCase().replaceAll('ё', 'е').replaceAll('-', ' ').trim();

List<String> _words(String phrase) =>
    _normalize(phrase).split(' ').where((w) => w.isNotEmpty).toList();

bool _isPhrase(String value) => _words(value).length > 1;

/// Longest single word a player should have to read off a card.
const _maxWordLength = 13;

/// Endings typical of academic/abstract vocabulary that does not belong in a
/// party game ("энтропия", "эмерджентность", "фальсифицируемость").
// Deliberately narrow. Endings like "-ация"/"-изация" would flag everyday
// words ("сигнализация", "экранизация"), so only markedly academic endings
// are listed; the rest is covered by the length limit and the banned list.
const _academicEndings = [
  'изм',
  'логия',
  'метрия',
  'фикация',
  'ентность',
  'уемость',
];

/// Words banned outright: understood by few players at a party.
const _bannedWords = [
  'энтропия',
  'парадигма',
  'редукционизм',
  'детерминизм',
  'амбивалентность',
  'трансцендентность',
  'экстраполяция',
  'гомеостаз',
  'клепсидра',
  'гномон',
  'астролябия',
  'апологет',
  'юродивый',
  'мытарь',
  'сатрапия',
  'анклав',
  'эмерджентность',
  'фальсифицируемость',
  'аутентичность',
  'сублимация',
  'катарсис',
  'апокриф',
];

/// Pairs where one side is a plain synonym or an obvious subtype of the other.
/// Kept explicit so a regression is caught by name.
const _forbiddenPairs = <List<String>>[
  ['ролл', 'суши'],
  ['машина', 'автомобиль'],
  ['собака', 'пес'],
  ['врач', 'доктор'],
  ['яблоко', 'фрукт'],
  ['пиво', 'алкоголь'],
  ['море', 'океан'],
  ['пицца', 'пиццерия'],
  ['телефон', 'смартфон'],
  ['кот', 'кошка'],
  ['дом', 'здание'],
  ['судья', 'рефери'],
  ['гильдия', 'клан'],
  ['ловушка', 'западня'],
  ['злодей', 'антагонист'],
  ['пазл', 'головоломка'],
];

void main() {
  final allPairs = <WordPair>[
    for (final category in allWordCategories) ...category.pairs,
  ];
  final allSides = <String>[
    for (final pair in allPairs) ...[pair.civilianWord, pair.spyWord],
  ];

  group('structure', () {
    test('every category is uniquely identified and reasonably sized', () {
      final ids = <String>{};
      for (final category in allWordCategories) {
        expect(ids.add(category.id), isTrue, reason: 'duplicate id ${category.id}');
        expect(category.name.trim(), isNotEmpty);
        expect(category.pairs.length, greaterThanOrEqualTo(30),
            reason: '${category.id} has only ${category.pairs.length} pairs');
      }
    });

    test('all requested categories are present', () {
      const required = [
        'objects', 'people', 'animals', 'food', 'places', 'technology',
        'nature', 'movies', 'games', 'history', 'science', 'sports',
        'music', 'daily_life', 'abstract', 'phrases', 'adult',
      ];
      final actual = allWordCategories.map((c) => c.id).toSet();
      for (final id in required) {
        expect(actual, contains(id), reason: 'missing category $id');
      }
    });

    test('all four difficulty levels are represented in every category', () {
      for (final category in allWordCategories) {
        for (final level in Difficulty.values) {
          expect(category.pairsOfDifficulty(level), isNotEmpty,
              reason: '${category.id} has no ${level.name} pairs');
        }
      }
    });

    test('the base carries at least 1000 game words', () {
      final wordCount = allSides.length;
      expect(wordCount, greaterThanOrEqualTo(1000),
          reason: 'only $wordCount words in the base');
    });

    test('exactly one adult category exists and it is flagged', () {
      final adult = allWordCategories.where((c) => c.isAdult).toList();
      expect(adult, hasLength(1));
      expect(adult.single.id, 'adult');
    });

    test('the phrases category is actually built from phrases', () {
      final phrases = allWordCategories.firstWhere((c) => c.id == 'phrases');
      final withPhrase = phrases.pairs
          .where((p) => _isPhrase(p.civilianWord) && _isPhrase(p.spyWord))
          .length;
      expect(withPhrase, phrases.pairs.length,
          reason: 'every pair in "phrases" must have a phrase on both sides');
    });

    test('phrases appear across the rest of the base too', () {
      final outsidePhrasesPack = [
        for (final c in allWordCategories.where((c) => c.id != 'phrases'))
          ...c.pairs,
      ];
      final phraseCount = outsidePhrasesPack
          .where((p) => _isPhrase(p.civilianWord) || _isPhrase(p.spyWord))
          .length;
      expect(phraseCount, greaterThanOrEqualTo(20),
          reason: 'only $phraseCount pairs outside the phrases pack use a phrase');
    });
  });

  group('words stay simple', () {
    test('no single word is longer than $_maxWordLength characters', () {
      for (final side in allSides) {
        for (final word in _words(side)) {
          expect(word.length, lessThanOrEqualTo(_maxWordLength),
              reason: '"$word" in "$side" is too long for a party game');
        }
      }
    });

    test('no academic vocabulary', () {
      for (final side in allSides) {
        for (final word in _words(side)) {
          if (word.length < 8) continue;
          for (final ending in _academicEndings) {
            expect(word.endsWith(ending), isFalse,
                reason: '"$word" in "$side" looks like academic vocabulary');
          }
        }
      }
    });

    test('no word from the banned list', () {
      for (final side in allSides) {
        for (final word in _words(side)) {
          expect(_bannedWords, isNot(contains(word)),
              reason: '"$word" in "$side" is too obscure for players');
        }
      }
    });

    test('phrases stay short enough to read at a glance', () {
      for (final side in allSides) {
        expect(_words(side).length, lessThanOrEqualTo(4),
            reason: '"$side" is too long to work as a game card');
      }
    });
  });

  group('pairs stay non-obvious', () {
    test('no pair repeats anywhere in the base, in either direction', () {
      // Order-independent: «Кошка / Собака» and «Собака / Кошка» are one
      // secret at the table, and a pair that comes back reversed is how a
      // rejected pair sneaks past a plain id comparison.
      final seen = <String, String>{};
      for (final pair in allPairs) {
        final previous = seen[pair.historyKey];
        expect(previous, isNull,
            reason: 'duplicate pair ${pair.id} (already present as $previous)');
        seen[pair.historyKey] = pair.id;
      }
    });

    test('both sides are present and different', () {
      for (final pair in allPairs) {
        expect(pair.civilianWord.trim(), isNotEmpty);
        expect(pair.spyWord.trim(), isNotEmpty);
        expect(_normalize(pair.civilianWord), isNot(_normalize(pair.spyWord)),
            reason: 'identical words in ${pair.id}');
      }
    });

    test('neither side contains the other', () {
      // Catches "пицца/пиццерия" — the spy would guess instantly.
      for (final pair in allPairs) {
        final a = _normalize(pair.civilianWord);
        final b = _normalize(pair.spyWord);
        expect(a.contains(b) || b.contains(a), isFalse,
            reason: 'one side contains the other in ${pair.id}');
      }
    });

    test('single-word pairs do not share a stem', () {
      // Catches same-root forms like "машина/автомашина".
      // Phrases are exempt: "ограбление банка / ограбление поезда" is a good
      // pair even though the phrases start with the same word.
      for (final pair in allPairs) {
        if (_isPhrase(pair.civilianWord) || _isPhrase(pair.spyWord)) continue;
        final a = _normalize(pair.civilianWord);
        final b = _normalize(pair.spyWord);
        if (a.length < 5 || b.length < 5) continue;
        expect(a.substring(0, 5), isNot(b.substring(0, 5)),
            reason: 'shared stem in ${pair.id}');
      }
    });

    test('phrase pairs differ in more than word order', () {
      for (final pair in allPairs) {
        if (!_isPhrase(pair.civilianWord) || !_isPhrase(pair.spyWord)) continue;
        final a = _words(pair.civilianWord).toSet();
        final b = _words(pair.spyWord).toSet();
        expect(a.difference(b), isNotEmpty, reason: 'phrases too alike in ${pair.id}');
        expect(b.difference(a), isNotEmpty, reason: 'phrases too alike in ${pair.id}');
      }
    });

    test('no pair matches the forbidden synonym list', () {
      for (final pair in allPairs) {
        final actual = {_normalize(pair.civilianWord), _normalize(pair.spyWord)};
        for (final forbidden in _forbiddenPairs) {
          expect(actual, isNot(equals(forbidden.toSet())),
              reason: 'forbidden pair ${pair.id}');
        }
      }
    });

    test('no single word dominates the base', () {
      final uses = <String, int>{};
      for (final side in allSides) {
        uses.update(_normalize(side), (v) => v + 1, ifAbsent: () => 1);
      }
      final overused = uses.entries.where((e) => e.value > 4).toList();
      expect(overused, isEmpty,
          reason: 'overused: ${overused.map((e) => '${e.key} x${e.value}').join(', ')}');
    });
  });

  group('play value', () {
    test('no pair scored 1-2 ever ships in a category', () {
      for (final category in allWordCategories) {
        for (final pair in category.pairs) {
          expect(pair.score, greaterThanOrEqualTo(3),
              reason: '${category.id}: ${pair.id} scored ${pair.score} — '
                  'it belongs in needs_rework.dart');
        }
      }
    });

    test('every score is within 1-5', () {
      for (final pair in [...allPairs, ...pairsNeedingRework]) {
        expect(pair.score, inInclusiveRange(1, 5), reason: pair.id);
      }
    });

    test('the shipping base is predominantly 4-5', () {
      final prime = allPairs.where((p) => p.isPrime).length;
      final share = prime / allPairs.length;
      expect(share, greaterThanOrEqualTo(0.75),
          reason: 'only ${(share * 100).round()}% of pairs are rated 4-5');
    });

    test('every category can be played entirely from its 4-5 pairs', () {
      for (final category in allWordCategories) {
        final prime = category.pairs.where((p) => p.isPrime).length;
        expect(prime, greaterThanOrEqualTo(20),
            reason: '${category.id} has only $prime pairs rated 4-5');
      }
    });

    test('every difficulty tier of every category has 4-5 pairs to draw', () {
      // Without this the difficulty filter would silently fall back to the
      // weaker 3s for a whole tier.
      for (final category in allWordCategories) {
        for (final level in Difficulty.values) {
          final prime =
              category.pairsOfDifficulty(level).where((p) => p.isPrime).length;
          expect(prime, greaterThanOrEqualTo(3),
              reason: '${category.id}/${level.name} has only $prime pairs rated 4-5');
        }
      }
    });

    test('the hardest tier is hard from ambiguity, not from weak pairs', () {
      // "Очень сложные" must not become a dumping ground for near-synonyms:
      // the average play value there has to hold up against the easy tier.
      for (final category in allWordCategories) {
        final expert = category.pairsOfDifficulty(Difficulty.expert).toList();
        final avg = expert.fold<int>(0, (s, p) => s + p.score) / expert.length;
        expect(avg, greaterThanOrEqualTo(3.5),
            reason: '${category.id} expert tier averages '
                '${avg.toStringAsFixed(2)} — too many weak pairs');
      }
    });

    // Why a pair is parked — a weak score or a spy who cannot recover the
    // word — is checked in spy_guessability_test.dart, which can read the
    // annotations in the source file.
    test('pairs parked for rework are not reachable in game', () {
      final shipping = allPairs.map((p) => p.id).toSet();
      for (final pair in pairsNeedingRework) {
        expect(shipping, isNot(contains(pair.id)),
            reason: '${pair.id} is both shipping and parked');
      }
    });
  });

  group('association tags', () {
    test('every pair carries at least two non-empty tags', () {
      for (final pair in allPairs) {
        expect(pair.tags.length, greaterThanOrEqualTo(2),
            reason: '${pair.id} needs more tags');
        for (final tag in pair.tags) {
          expect(tag.trim(), isNotEmpty, reason: 'empty tag in ${pair.id}');
        }
      }
    });

    test('tags are not just a restatement of the pair words', () {
      for (final pair in allPairs) {
        final words = {_normalize(pair.civilianWord), _normalize(pair.spyWord)};
        for (final tag in pair.tags) {
          expect(words.contains(_normalize(tag)), isFalse,
              reason: 'tag "$tag" repeats a word of ${pair.id}');
        }
      }
    });

    test('tags within a pair are distinct', () {
      for (final pair in allPairs) {
        final normalized = pair.tags.map(_normalize).toSet();
        expect(normalized.length, pair.tags.length,
            reason: 'duplicate tags in ${pair.id}');
      }
    });
  });
}
