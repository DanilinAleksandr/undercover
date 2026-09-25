import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undercover/app.dart';
import 'package:undercover/data/word_descriptions.dart';
import 'package:undercover/data/word_descriptions/persons.dart';
import 'package:undercover/data/word_pack_registry.dart';
import 'package:undercover/models/game_mode.dart';
import 'package:undercover/models/word_pair.dart';
import 'package:undercover/providers/game_session_provider.dart';
import 'package:undercover/providers/game_setup_provider.dart';

/// Every person in «Личности» carries a line saying who they are and when
/// they were famous, opened from the «Кто это?» link under the card.
///
/// Same reasoning as the job descriptions: if only the obscure names had a
/// line, its presence would tell the table the name is obscure. And one rule
/// of its own — a line describes its own person and never the other side of
/// the pair, or the card becomes a hint about the opposite card.

final _peoplePairs = <WordPair>[
  for (final c in allWordCategories)
    if (c.id.startsWith('pers_')) ...c.pairs,
];

String _norm(String s) => s.toLowerCase().replaceAll('ё', 'е');

/// The part of a name a line could give away: the surname, or the whole name
/// when it is one word. «Капитан» or «Братья» alone point at nobody.
String _surname(String name) => _norm(name).split(RegExp(r'[ -]')).last;

void main() {
  final people = <String>{
    for (final p in _peoplePairs) ...[p.civilianWord, p.spyWord],
  };

  group('coverage', () {
    test('every person of the mode is described', () {
      final missing = people.where((p) => !personDescriptions.containsKey(p))
          .toList()
        ..sort();
      expect(missing, isEmpty,
          reason: '${missing.length} without a line: ${missing.take(20).join(', ')}');
    });

    test('nothing is described that the mode cannot deal', () {
      final extra = personDescriptions.keys
          .where((p) => !people.contains(p))
          .toList()
        ..sort();
      expect(extra, isEmpty, reason: extra.join(', '));
    });
  });

  group('shape', () {
    test('a sphere and a period, separated by «; »', () {
      for (final e in personDescriptions.entries) {
        final parts = e.value.split('; ');
        expect(parts, hasLength(2), reason: '"${e.key}": ${e.value}');
        expect(parts.every((p) => p.trim().isNotEmpty), isTrue,
            reason: '"${e.key}": ${e.value}');
      }
    });

    test('fits on a card: 70 characters at most', () {
      for (final e in personDescriptions.entries) {
        expect(e.value.length, lessThanOrEqualTo(70),
            reason: '"${e.key}": ${e.value.length} chars');
      }
    });

    test('reads as a continuation of the name', () {
      for (final e in personDescriptions.entries) {
        final first = e.value.substring(0, 1);
        expect(first, first.toLowerCase(), reason: '"${e.key}": ${e.value}');
        expect(e.value.endsWith('.'), isFalse, reason: '"${e.key}": ${e.value}');
      }
    });
  });

  group('no hint at the other card', () {
    test('a line never names the other side of any of its pairs', () {
      for (final pair in _peoplePairs) {
        for (final (self, other) in [
          (pair.civilianWord, pair.spyWord),
          (pair.spyWord, pair.civilianWord),
        ]) {
          final line = _norm(personDescriptions[self] ?? '');
          expect(line.contains(_norm(other)), isFalse,
              reason: '"$self" names "$other": $line');
          final surname = _surname(other);
          if (surname.length < 3) continue;
          expect(line.contains(surname), isFalse,
              reason: '"$self" mentions "$surname" from "$other": $line');
        }
      }
    });
  });

  group('each mode reads its own table', () {
    test('a person is described in «Личности» and nowhere else', () {
      const name = 'Стив Джобс';
      expect(descriptionFor(name, GameMode.people), isNotNull);
      expect(descriptionFor(name, GameMode.words), isNull);
      expect(descriptionFor(name, GameMode.places), isNull);
      expect(descriptionFor(name, GameMode.impostor), isNull);
    });

    test('a job is described in «Слова» and not in «Личности»', () {
      expect(descriptionFor('Врач', GameMode.words), isNotNull);
      expect(descriptionFor('Врач', GameMode.people), isNull);
    });
  });

  Future<ProviderContainer> pumpToCard(WidgetTester tester, GameMode mode) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final setup = container.read(gameSetupProvider.notifier);
    // Not a hint: the «Подсказки» switch must not take it away.
    setup.setHintsEnabled(false);
    setup.setGameMode(mode);

    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const UndercoverApp()));
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
    return container;
  }

  testWidgets('on the card: the line waits behind «Кто это?»', (tester) async {
    final container = await pumpToCard(tester, GameMode.people);
    final session = container.read(gameSessionProvider)!;
    expect(session.wordPair.gameMode, GameMode.people);
    final player = session.players[session.currentRevealIndex];
    final name = player.id == session.spyPlayerId
        ? session.wordPair.spyWord
        : session.wordPair.civilianWord;
    final line = personDescriptions[name]!;

    // Before the card is read there is nothing to open.
    expect(find.text('Кто это?'), findsNothing);

    final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('reveal-card'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(name), findsOneWidget);
    // The name is met on its own: the line is not on the card.
    expect(find.text(line), findsNothing);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Кто это?'), findsOneWidget);
    await tester.tap(find.text('Кто это?'));
    await tester.pumpAndSettle();
    expect(find.text(line), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('«Места» have no line and no link', (tester) async {
    await pumpToCard(tester, GameMode.places);
    final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('reveal-card'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Кто это?'), findsNothing);
    expect(find.text('Слово незнакомо?'), findsNothing);
  });
}
