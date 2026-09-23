import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:undercover/data/needs_rework.dart';
import 'package:undercover/data/word_pack_registry.dart';
import 'package:undercover/models/difficulty.dart';
import 'package:undercover/models/word_pair.dart';

/// Guards the bookkeeping of the spy-guessability pass, not its judgement.
///
/// Whether a spy can actually recover a word from five spoken associations is
/// an editorial call that no assertion can make — these tests only check the
/// things that are objectively true or false: that every parked pair states
/// why it was parked, that the annotations are well formed, that nothing is
/// parked twice, and that the base stayed playable after the removals.

const _annotated = r'''spy_guessability''';

class _Parked {
  final String id;
  final int? guessability;
  final bool hasReason;
  final bool hasRework;
  const _Parked(this.id, this.guessability, this.hasReason, this.hasRework);
}

/// Reads `needs_rework.dart` and pairs every entry with the comment block
/// directly above it.
List<_Parked> _readParkedSource() {
  final file = File('lib/data/needs_rework.dart');
  if (!file.existsSync()) {
    throw StateError('tests must run from the project root: ${file.absolute}');
  }
  final lines = file.readAsLinesSync();
  final entry = RegExp(r"^\s*WordPair\('([^']+)', '([^']+)'");
  final guess = RegExp(r'^\s*//\s*spy_guessability:\s*(\d)');
  final reason = RegExp(r'^\s*//\s*reason:\s*"(.+)"\s*$');
  final rework = RegExp(r'^\s*//\s*rework:\s*(\S.*)$');

  final parsed = <_Parked>[];
  int? pendingGuess;
  var pendingReason = false;
  var pendingRework = false;
  for (final line in lines) {
    final g = guess.firstMatch(line);
    if (g != null) {
      pendingGuess = int.parse(g.group(1)!);
      continue;
    }
    if (reason.hasMatch(line)) {
      pendingReason = true;
      continue;
    }
    if (rework.hasMatch(line)) {
      pendingRework = true;
      continue;
    }
    final e = entry.firstMatch(line);
    if (e != null) {
      parsed.add(_Parked(
          '${e.group(1)}/${e.group(2)}', pendingGuess, pendingReason, pendingRework));
      pendingGuess = null;
      pendingReason = false;
      pendingRework = false;
    }
  }
  return parsed;
}

void main() {
  final parkedSource = _readParkedSource();

  group('the rework list stays honest', () {
    test('the source parses into exactly the pairs the app exposes', () {
      expect(parkedSource.map((p) => p.id).toList(),
          pairsNeedingRework.map((p) => p.id).toList());
    });

    test('every parked pair states why it was parked', () {
      // Two reasons exist. The original editorial pass parked pairs scored
      // 1-2. The spy-guessability pass parks pairs that read fine on paper but
      // leave the spy with nothing to aim at — those keep their score and must
      // carry the annotation instead.
      for (var i = 0; i < pairsNeedingRework.length; i++) {
        final pair = pairsNeedingRework[i];
        final source = parkedSource[i];
        final weakScore = pair.score <= 2;
        final annotated = source.guessability != null;
        expect(weakScore || annotated, isTrue,
            reason: '${pair.id} is parked with score ${pair.score} and no '
                'spy_guessability annotation — nothing says why');
      }
    });

    test('every annotation is well formed', () {
      for (final entry in parkedSource.where((p) => p.guessability != null)) {
        expect(entry.guessability, inInclusiveRange(1, 2),
            reason: '${entry.id}: only 1 and 2 are parking grades, '
                '3-5 stays in the game');
        expect(entry.hasReason, isTrue,
            reason: '${entry.id} has a grade but no reason');
        expect(entry.hasRework, isTrue,
            reason: '${entry.id} has a reason but no way to fix it');
      }
    });

    test('nothing is parked twice', () {
      final seen = <String>{};
      final duplicates = <String>[];
      for (final pair in pairsNeedingRework) {
        // Order-independent, same as the played-pairs history: a pair parked
        // once must not come back as its own mirror image.
        if (!seen.add(pair.historyKey)) duplicates.add(pair.id);
      }
      expect(duplicates, isEmpty, reason: 'parked twice: ${duplicates.join(', ')}');
    });
  });

  group('the base survived the removals', () {
    final shipping = [
      for (final category in allWordCategories) ...category.pairs,
    ];

    test('no parked pair is still reachable, in either direction', () {
      final live = shipping.map((p) => p.historyKey).toSet();
      for (final pair in pairsNeedingRework) {
        expect(live, isNot(contains(pair.historyKey)),
            reason: '${pair.id} is both shipping and parked');
      }
    });

    test('the swapped pairs kept both of their words', () {
      // The cheapest fix in this pass was turning a pair around so the
      // recoverable word is the one the majority holds. Nothing is lost that
      // way, so both words must still be in the base — just on the other side.
      const swapped = {
        'Равнодушие/Терпимость',
        'Болтовня/Разговор',
        'Попытка/Ход',
        'Слабость/Порок',
        'Молчание/Соучастие',
        'Больная тема/Старая рана',
        'Шум/Звук',
      };
      final ids = shipping.map((p) => p.id).toSet();
      for (final id in swapped) {
        expect(ids, contains(id), reason: '$id lost its swap');
        final reversed = id.split('/').reversed.join('/');
        expect(ids, isNot(contains(reversed)),
            reason: '$id exists in both directions');
      }
    });
  });

  group('the annotation vocabulary is the documented one', () {
    test('the file explains the grading before using it', () {
      final source = File('lib/data/needs_rework.dart').readAsStringSync();
      expect(source.contains(_annotated), isTrue);
      // A future reader must find the rule next to the data, not in a commit
      // message: the header of the pass block carries it.
      expect(source.contains('Spy-guessability pass'), isTrue);
    });

    test('no shipping pair carries a parking annotation by mistake', () {
      for (final file in Directory('lib/data/word_packs')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        expect(file.readAsStringSync().contains(_annotated), isFalse,
            reason: '${file.path} annotates a pair that is still in the game');
      }
    });
  });

  group('the shape of the base after the pass', () {
    test('the tiers are still populated in the intended proportions', () {
      final byTier = <Difficulty, int>{};
      for (final category in allWordCategories) {
        for (final pair in category.pairs) {
          byTier[pair.difficulty] = (byTier[pair.difficulty] ?? 0) + 1;
        }
      }
      final total = byTier.values.fold<int>(0, (a, b) => a + b);
      expect(total, greaterThanOrEqualTo(800),
          reason: 'the pass must not eat the base');
      // Medium is the working tier of a party and has to stay the largest.
      expect(byTier[Difficulty.medium], greaterThan(byTier[Difficulty.easy]!));
      expect(byTier[Difficulty.medium], greaterThan(byTier[Difficulty.hard]!));
      for (final level in Difficulty.values) {
        expect(byTier[level], greaterThanOrEqualTo(100), reason: level.name);
      }
    });

    test('no word carries hints it no longer needs', () {
      // Parking a hard pair can orphan its hints; word_hints_test owns the
      // full rule, this one just pins the pass-specific casualties.
      const orphaned = ['Сила', 'Опыт', 'Уважение', 'Копчёное', 'Громкость'];
      final live = <String>{
        for (final category in allWordCategories)
          for (final pair in category.pairs)
            if (pair.difficulty == Difficulty.hard ||
                pair.difficulty == Difficulty.expert) ...[
              pair.civilianWord,
              pair.spyWord,
            ],
      };
      for (final word in orphaned) {
        expect(live, isNot(contains(word)),
            reason: '$word came back into a hard tier without its hints');
      }
    });
  });
}

/// Kept close to the tests so a reader of this file sees what a parked entry
/// is supposed to look like.
const WordPair exampleParkedShape =
    WordPair('Сила', 'Воля', Difficulty.expert, ['внутри человека'], 3);
