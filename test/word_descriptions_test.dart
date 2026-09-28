import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undercover/app.dart';
import 'package:undercover/data/word_descriptions.dart';
import 'package:undercover/data/word_packs/people.dart';
import 'package:undercover/models/game_mode.dart';
import 'package:undercover/providers/game_session_provider.dart';
import 'package:undercover/providers/game_setup_provider.dart';
import 'package:undercover/providers/word_pack_provider.dart';
import 'package:undercover/models/difficulty.dart';
import 'package:undercover/models/word_category.dart';
import 'package:undercover/models/word_pair.dart';
import 'package:undercover/data/word_hints.dart';

/// A description explains a player's own word to the player holding it. The
/// judgement — whether a given line actually helps — is editorial, so these
/// tests guard the two things that are objectively checkable: that the cover
/// is complete, and that a line fits on a card.
///
/// Completeness is the load-bearing one. If only the unusual words carried a
/// description, its presence or absence would itself tell the table how rare
/// the word is, and the interface would leak what the card is trying to hide.

/// The two entries in the people pack that are not jobs.
///
/// «Голос / Походка» is a pair about recognising a person, parked in this
/// category because that is where it belongs thematically. Nothing to define.
const _notJobs = {'Голос', 'Походка'};

void main() {
  final packWords = <String>{
    for (final pair in peopleCategory.pairs) ...[
      pair.civilianWord,
      pair.spyWord,
    ],
  }..removeAll(_notJobs);

  group('coverage', () {
    test('every job in the people pack is described', () {
      final missing = packWords.where((w) => !wordDescriptions.containsKey(w)).toList()
        ..sort();
      expect(missing, isEmpty,
          reason: '${missing.length} words without a description: '
              '${missing.take(15).join(', ')}');
    });

    test('nothing is described that the pack does not contain', () {
      final extra = wordDescriptions.keys
          .where((w) => !packWords.contains(w))
          .toList()
        ..sort();
      expect(extra, isEmpty,
          reason: 'descriptions for words nobody can draw: ${extra.join(', ')}');
    });

    test('the two non-jobs are deliberately left out', () {
      // Pinned by name so that dropping the exception later is a decision,
      // not an accident.
      for (final word in _notJobs) {
        expect(wordDescriptions.containsKey(word), isFalse, reason: word);
      }
    });
  });

  group('a description fits on a card', () {
    test('none is empty', () {
      for (final entry in wordDescriptions.entries) {
        expect(entry.value.trim(), isNotEmpty, reason: entry.key);
      }
    });

    test('none is longer than 70 characters', () {
      // The line sits between the word and the bottom caption on a 320pt
      // phone. Longer than this and it wraps into a paragraph.
      for (final entry in wordDescriptions.entries) {
        expect(entry.value.length, lessThanOrEqualTo(70),
            reason: '"${entry.key}": ${entry.value.length} chars');
      }
    });

    test('it reads as a continuation of the word, not a sentence', () {
      // «Крановщик» + «управляет подъёмным краном». A capital letter or a
      // full stop would break that reading.
      for (final entry in wordDescriptions.entries) {
        final first = entry.value.substring(0, 1);
        expect(first, first.toLowerCase(),
            reason: '"${entry.key}" starts with a capital: "${entry.value}"');
        expect(entry.value.endsWith('.'), isFalse,
            reason: '"${entry.key}" ends with a full stop');
      }
    });

    test('no two words share the same description', () {
      final seen = <String, String>{};
      for (final entry in wordDescriptions.entries) {
        final owner = seen[entry.value];
        expect(owner, isNull,
            reason: 'shared by "$owner" and "${entry.key}": "${entry.value}"');
        seen[entry.value] = entry.key;
      }
    });
  });

  group('on the card', () {
    testWidgets('the meaning waits behind the link, even with hints off',
        (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      // The description is not a hint: it must survive the switch being off.
      container.read(gameSetupProvider.notifier).setHintsEnabled(false);
      // The jobs live in the words mode, in the «Люди и профессии» pack —
      // GameMode.people is the personalities mode and a different base.
      container.read(gameSetupProvider.notifier).setGameMode(GameMode.words);
      container.read(gameSetupProvider.notifier).toggleCategory('people');

      await tester.pumpWidget(
        UncontrolledProviderScope(
            container: container, child: const UndercoverApp()),
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
      await tap('Начать игру');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();
      await tap('Это я, показать карту');

      final session = container.read(gameSessionProvider)!;
      expect(session.config.hintsEnabled, isFalse);
      expect(session.wordPair.gameMode, GameMode.words);
      final player = session.players[session.currentRevealIndex];
      final word = player.id == session.spyPlayerId
          ? session.wordPair.spyWord
          : session.wordPair.civilianWord;
      // Without this the checks below would pass vacuously on a word drawn
      // from some other pack.
      expect(packWords.contains(word) || _notJobs.contains(word), isTrue,
          reason: '"$word" is not from the jobs pack — the filter did not hold');
      final description = wordDescriptions[word];

      expect(find.text('Слово незнакомо?'), findsNothing,
          reason: 'offered before the card was read');

      // The card flips back the moment the finger lifts, so the card itself
      // has to be checked while the gesture is still down.
      final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('reveal-card'))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(word), findsOneWidget);
      if (description != null) {
        // A player who recognised the word is not handed its meaning.
        expect(find.text(description), findsNothing,
            reason: 'the meaning of "$word" is printed on the card');
      }
      await gesture.up();
      await tester.pumpAndSettle();

      if (description == null) return;
      await tap('Слово незнакомо?');
      expect(find.text(description), findsOneWidget,
          reason: 'the sheet does not hold the meaning of "$word"');
      expect(find.text('ОПРЕДЕЛЕНИЕ'), findsOneWidget);
    });
    testWidgets('with hints too: the hints escalate first, the meaning last',
        (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Both sides are jobs with three authored hints and a description, so
      // whoever holds the first card gets the full sheet.
      const pair = WordPair('Завхоз', 'Прораб', Difficulty.expert,
          ['стройка', 'инвентарь'], 5);
      for (final w in [pair.civilianWord, pair.spyWord]) {
        expect(wordHints[w]!.all, hasLength(3), reason: w);
        expect(wordDescriptions[w], isNotNull, reason: w);
      }
      final container = ProviderContainer(overrides: [
        wordPackProvider.overrideWithValue(const [
          WordCategory(id: 'j', name: 'Jobs', icon: Icons.work, pairs: [pair]),
        ]),
      ]);
      addTearDown(container.dispose);
      container
          .read(gameSetupProvider.notifier)
          .setRoster(const ['Аня', 'Боря', 'Вика']);

      await tester.pumpWidget(UncontrolledProviderScope(
          container: container, child: const UndercoverApp()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Новая игра'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Далее'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Начать игру'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Это я, показать карту'));
      await tester.pumpAndSettle();

      final session = container.read(gameSessionProvider)!;
      final player = session.players[session.currentRevealIndex];
      final word = player.id == session.spyPlayerId
          ? session.wordPair.spyWord
          : session.wordPair.civilianWord;
      final hints = wordHints[word]!.all;

      final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('reveal-card'))));
      await tester.pump(const Duration(milliseconds: 1200));
      await gesture.up();
      await tester.pumpAndSettle();

      // One link for both kinds of help, not two.
      expect(find.text('Слово незнакомо?'), findsOneWidget);
      await tester.tap(find.text('Слово незнакомо?'));
      await tester.pumpAndSettle();
      expect(find.text(hints.first), findsOneWidget);
      expect(find.text(wordDescriptions[word]!), findsNothing,
          reason: 'the meaning opened before the softest hint was spent');

      for (var i = 0; i < hints.length; i++) {
        await tester.tap(find.text('Ещё подсказка'));
        await tester.pumpAndSettle();
      }
      expect(find.text(wordDescriptions[word]!), findsOneWidget);
      expect(find.text('ОПРЕДЕЛЕНИЕ'), findsOneWidget);
      expect(find.text('Это всё, что можно подсказать'), findsOneWidget);
    });
  });
}
