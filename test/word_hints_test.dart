import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undercover/app.dart';
import 'package:undercover/providers/game_session_provider.dart';
import 'package:undercover/providers/game_setup_provider.dart';
import 'package:undercover/data/word_hints.dart';
import 'package:undercover/data/word_pack_registry.dart';
import 'package:undercover/logic/hint_policy.dart';
import 'package:undercover/models/difficulty.dart';
import 'package:undercover/models/game_mode.dart';
import 'package:undercover/models/word_pair.dart';

/// A hint must narrow the field without handing over the answer. These checks
/// enforce that mechanically: the clue may not contain the word, a cognate of
/// it, the paired word, or be so short that it is effectively a synonym.

String _norm(String s) => s
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(RegExp(r'[^а-яa-z0-9\s-]'), ' ')
    .replaceAll('-', ' ');

List<String> _tokens(String s) =>
    _norm(s).split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

/// Russian inflects heavily, so an exact-match check is not enough: compare
/// word stems instead. Six characters is long enough that ordinary words do
/// not collide by accident.
String? _stem(String token) => token.length >= 6 ? token.substring(0, 6) : null;

bool _sharesStem(String hint, String word) {
  final wordStems = _tokens(word).map(_stem).whereType<String>().toSet();
  if (wordStems.isEmpty) return false;
  return _tokens(hint).map(_stem).whereType<String>().any(wordStems.contains);
}

/// Words too common to carry meaning — used to tell a real clue from filler.
const _stopWords = {
  'и', 'в', 'во', 'не', 'на', 'что', 'он', 'она', 'оно', 'они', 'с', 'со',
  'как', 'а', 'то', 'все', 'так', 'его', 'но', 'да', 'ты', 'к', 'у', 'же',
  'вы', 'за', 'бы', 'по', 'ее', 'их', 'из', 'о', 'при', 'от', 'для', 'до',
  'над', 'под', 'это', 'этот', 'эта', 'эти', 'там', 'тут', 'тот', 'та', 'те',
  'ли', 'ведь', 'уж', 'вот',
};

Set<String> _contentWords(String s) =>
    _tokens(s).where((t) => t.length > 2 && !_stopWords.contains(t)).toSet();

/// Encyclopedic markers: a party clue should never read like a taxonomy entry.
const _taxonomyMarkers = ['семейств', 'разновидност', 'представител', 'подвид'];

/// Vacuous templates that technically pass every other rule.
const _genericPhrases = [
  'связано с природой',
  'можно встретить в жизни',
  'иногда бывает полезно',
  'встречается часто',
  'связано с жизнью',
];

bool _containsWord(String hint, String word) {
  final hintTokens = _tokens(hint);
  for (final token in _tokens(word)) {
    if (token.length < 4) continue;
    if (hintTokens.contains(token)) return true;
  }
  return false;
}

void main() {
  final hardWords = <String>{};
  final expertWords = <String>{};
  final pairOf = <String, List<WordPair>>{};

  for (final category in allWordCategories) {
    for (final pair in category.pairs) {
      // Hints are authored per word, and a name is not a word anyone can be
      // nudged towards: «Байкал» either is or is not the thing you were
      // thinking of. The people and places modes therefore ship without hints —
      // `hintsFor` finds nothing for them, so the link never appears and the
      // «Подсказки» switch is not even offered there.
      if (pair.gameMode != GameMode.words) continue;
      for (final word in [pair.civilianWord, pair.spyWord]) {
        pairOf.putIfAbsent(word, () => []).add(pair);
        if (pair.difficulty == Difficulty.hard) hardWords.add(word);
        if (pair.difficulty == Difficulty.expert) expertWords.add(word);
      }
    }
  }
  // A word used in both a hard and an expert pair must satisfy the stricter one.
  final softOnlyWords = hardWords.difference(expertWords);

  group('coverage', () {
    test('every word in a hard pair has a soft hint', () {
      final missing = softOnlyWords.where((w) => !wordHints.containsKey(w)).toList()
        ..sort();
      expect(missing, isEmpty,
          reason: '${missing.length} hard words without a hint: '
              '${missing.take(15).join(', ')}');
    });

    test('every word in an expert pair has all three hints', () {
      final missing = <String>[];
      for (final word in expertWords) {
        final hints = wordHints[word];
        if (hints == null || hints.medium == null || hints.strong == null) {
          missing.add(word);
        }
      }
      missing.sort();
      expect(missing, isEmpty,
          reason: '${missing.length} expert words without full hints: '
              '${missing.take(15).join(', ')}');
    });

    test('no hints are authored for words that never need them', () {
      final needed = hardWords.union(expertWords);
      final extra = wordHints.keys.where((w) => !needed.contains(w)).toList()..sort();
      expect(extra, isEmpty,
          reason: 'hints for words that are never hard: ${extra.take(10).join(', ')}');
    });

    test('no word is defined twice across the hint files', () {
      final seen = <String>{};
      final duplicates = <String>[];
      for (final part in hintParts) {
        for (final key in part.keys) {
          if (!seen.add(key)) duplicates.add(key);
        }
      }
      expect(duplicates, isEmpty, reason: 'duplicated: ${duplicates.join(', ')}');
    });
  });

  group('a hint never gives the word away', () {
    test('it does not contain the word itself', () {
      for (final entry in wordHints.entries) {
        for (final hint in entry.value.all) {
          expect(_containsWord(hint, entry.key), isFalse,
              reason: '"${entry.key}" appears in its own hint: "$hint"');
        }
      }
    });

    test('it contains no cognate of the word', () {
      for (final entry in wordHints.entries) {
        for (final hint in entry.value.all) {
          expect(_sharesStem(hint, entry.key), isFalse,
              reason: 'cognate of "${entry.key}" in: "$hint"');
        }
      }
    });

    test('it does not leak the paired word either', () {
      for (final entry in wordHints.entries) {
        for (final pair in pairOf[entry.key] ?? const <WordPair>[]) {
          final other =
              pair.civilianWord == entry.key ? pair.spyWord : pair.civilianWord;
          for (final hint in entry.value.all) {
            expect(_containsWord(hint, other), isFalse,
                reason: 'hint for "${entry.key}" names its pair "$other": "$hint"');
          }
        }
      }
    });

    test('the three levels are distinct from each other', () {
      for (final entry in wordHints.entries) {
        final normalized = entry.value.all.map(_norm).toSet();
        expect(normalized.length, entry.value.all.length,
            reason: 'repeated hint text for "${entry.key}"');
      }
    });

    test('hints stay short enough to read aloud at a table', () {
      for (final entry in wordHints.entries) {
        for (final hint in entry.value.all) {
          expect(hint.length, lessThanOrEqualTo(90),
              reason: 'too long for "${entry.key}": "$hint"');
        }
      }
    });

    test('a clue is at least four words long', () {
      // Anything shorter is a label, not a nudge — and a one-or-two word
      // label is almost always just a synonym of the answer.
      for (final entry in wordHints.entries) {
        for (final hint in entry.value.all) {
          expect(_tokens(hint).length, greaterThanOrEqualTo(4),
              reason: 'too terse for "${entry.key}": "$hint"');
        }
      }
    });

    test('a clue carries real content, not filler', () {
      for (final entry in wordHints.entries) {
        for (final hint in entry.value.all) {
          expect(_contentWords(hint).length, greaterThanOrEqualTo(3),
              reason: 'nothing to grab onto in "${entry.key}": "$hint"');
          for (final generic in _genericPhrases) {
            expect(hint.toLowerCase().contains(generic), isFalse,
                reason: 'empty filler for "${entry.key}": "$hint"');
          }
        }
      }
    });

    test('a clue reads like a nudge, not a dictionary entry', () {
      for (final entry in wordHints.entries) {
        for (final hint in entry.value.all) {
          final lower = _norm(hint);
          expect(lower.startsWith('это '), isFalse,
              reason: 'definitional opener for "${entry.key}": "$hint"');
          for (final marker in _taxonomyMarkers) {
            expect(lower.contains(marker), isFalse,
                reason: 'encyclopedic wording for "${entry.key}": "$hint"');
          }
        }
      }
    });

    test('the same clue is not reused across different words', () {
      final seen = <String, String>{};
      for (final entry in wordHints.entries) {
        for (final hint in entry.value.all) {
          final key = _norm(hint);
          final owner = seen[key];
          expect(owner, isNull,
              reason: 'clue shared by "$owner" and "${entry.key}": "$hint"');
          seen[key] = entry.key;
        }
      }
    });
  });

  group('the levels escalate', () {
    test('each level says something the previous one did not', () {
      // Guards against the «связан с морем / связан с кораблями /
      // помогает кораблям» pattern, where all three clues repeat one idea.
      for (final entry in wordHints.entries) {
        final levels = entry.value.all;
        if (levels.length < 2) continue;
        for (var i = 1; i < levels.length; i++) {
          final previous = _contentWords(levels[i - 1]);
          final current = _contentWords(levels[i]);
          final shared = previous.intersection(current).length;
          final union = previous.union(current).length;
          expect(shared / union, lessThanOrEqualTo(0.34),
              reason: 'levels $i and ${i + 1} of "${entry.key}" overlap too '
                  'much: "${levels[i - 1]}" / "${levels[i]}"');
        }
      }
    });

    test('the strongest level genuinely adds information', () {
      for (final entry in wordHints.entries) {
        final levels = entry.value.all;
        if (levels.length < 3) continue;
        final added =
            _contentWords(levels[2]).difference(_contentWords(levels[0]));
        expect(added.length, greaterThanOrEqualTo(3),
            reason: 'the last clue for "${entry.key}" barely adds to the '
                'first: "${levels[0]}" -> "${levels[2]}"');
      }
    });
  });

  group('policy', () {
    test('easy and medium rounds offer no help at all', () {
      expect(maxHintsFor(Difficulty.easy), 0);
      expect(maxHintsFor(Difficulty.medium), 0);
      for (final category in allWordCategories) {
        for (final pair in category.pairs) {
          if (pair.difficulty == Difficulty.easy ||
              pair.difficulty == Difficulty.medium) {
            expect(hintsFor(pair.civilianWord, pair.difficulty), isEmpty);
            expect(hintsFor(pair.spyWord, pair.difficulty), isEmpty);
          }
        }
      }
    });

    test('hard rounds unlock only the broad nudge', () {
      expect(maxHintsFor(Difficulty.hard), 1);
      for (final word in softOnlyWords) {
        expect(hintsFor(word, Difficulty.hard), hasLength(1));
      }
    });

    test('expert rounds escalate through all three', () {
      expect(maxHintsFor(Difficulty.expert), 3);
      for (final word in expertWords) {
        final hints = hintsFor(word, Difficulty.expert);
        expect(hints, hasLength(3));
        expect(hints.first, wordHints[word]!.soft);
        expect(hints.last, wordHints[word]!.strong);
      }
    });

    test('an unknown word simply gets no hints rather than failing', () {
      expect(hintsFor('несуществующее слово', Difficulty.expert), isEmpty);
    });
  });

  group('in the game', () {
    testWidgets('an expert round offers help only after the card was read, '
        'and escalates on request', (tester) async {
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
      // Force an expert round so all three levels are on offer.
      // The difficulty row sits below the fold on a phone, and a ListView does
      // not build what it cannot show — scroll it in before reaching for it.
      Future<void> scrollTo(String label) async {
        for (var i = 0; i < 12 && find.text(label).evaluate().isEmpty; i++) {
          await tester.drag(find.byType(ListView), const Offset(0, -220));
          await tester.pumpAndSettle();
        }
      }

      // Hints exist for words and phrases, so pin the kind too: an expert
      // round on a personality would legitimately offer no help.
      await scrollTo('Слова');
      await tap('Слова');
      await scrollTo('Очень сложные');
      await tap('Очень сложные');
      expect(container.read(gameSetupProvider).selectedDifficulties,
          {Difficulty.expert});
      await tap('Начать игру');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();
      await tap('Это я, показать карту');

      // Nothing on offer until the player has actually looked.
      expect(find.text('Слово незнакомо?'), findsNothing);

      final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('reveal-card'))));
      await tester.pump(const Duration(milliseconds: 1200));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('Слово незнакомо?'), findsOneWidget);
      await tap('Слово незнакомо?');

      final session = container.read(gameSessionProvider)!;
      final player = session.players[session.currentRevealIndex];
      final word = player.id == session.spyPlayerId
          ? session.wordPair.spyWord
          : session.wordPair.civilianWord;
      final expected = wordHints[word]!;

      // One clue at a time, in order, until the last.
      expect(find.text(expected.soft), findsOneWidget);
      expect(find.text(expected.medium!), findsNothing);
      await tap('Ещё подсказка');
      expect(find.text(expected.medium!), findsOneWidget);
      await tap('Ещё подсказка');
      expect(find.text(expected.strong!), findsOneWidget);
      expect(find.text('Ещё подсказка'), findsNothing);

      // And the clue never spells out the secret.
      for (final hint in expected.all) {
        expect(hint.toLowerCase().contains(word.toLowerCase()), isFalse);
      }
    });

    testWidgets('an easy round never offers a hint', (tester) async {
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
      // The difficulty row sits below the fold on a phone, and a ListView does
      // not build what it cannot show — scroll it in before reaching for it.
      Future<void> scrollTo(String label) async {
        for (var i = 0; i < 12 && find.text(label).evaluate().isEmpty; i++) {
          await tester.drag(find.byType(ListView), const Offset(0, -220));
          await tester.pumpAndSettle();
        }
      }

      await scrollTo('Лёгкие');
      await tap('Лёгкие');
      await tap('Начать игру');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();
      await tap('Это я, показать карту');

      final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('reveal-card'))));
      await tester.pump(const Duration(milliseconds: 1200));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(container.read(gameSessionProvider)!.wordPair.difficulty,
          Difficulty.easy);
      expect(find.text('Слово незнакомо?'), findsNothing);
    });
  });
}
