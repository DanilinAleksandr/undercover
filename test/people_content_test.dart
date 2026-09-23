import 'package:flutter_test/flutter_test.dart';
import 'package:undercover/data/word_pack_registry.dart';
import 'package:undercover/logic/word_pack_selector.dart';
import 'package:undercover/models/difficulty.dart';
import 'package:undercover/models/game_mode.dart';

/// Guards for the people mode as a *mode*.
///
/// The craft rules that apply to every pair in the base — no synonyms, no
/// shared stems, tier coverage, prime share — live in word_pack_quality_test.
/// Only what is specific to people is checked here.
void main() {
  final peopleCategories =
      allWordCategories.where((c) => c.id.startsWith('pers_')).toList();
  final peoplePairs = [for (final c in peopleCategories) ...c.pairs];

  String surname(String side) =>
      side.toLowerCase().replaceAll('ё', 'е').split(RegExp(r'[ -]')).last;

  test('every pack under the people prefix declares the people mode', () {
    expect(peopleCategories, isNotEmpty);
    for (final category in peopleCategories) {
      for (final pair in category.pairs) {
        expect(pair.gameMode, GameMode.people, reason: pair.id);
        expect(pair.mode, isNotNull, reason: '${pair.id} relies on the default');
      }
    }
  });

  test('nothing outside those packs claims to be a person', () {
    for (final category in allWordCategories) {
      if (category.id.startsWith('pers_')) continue;
      for (final pair in category.pairs) {
        expect(pair.gameMode, isNot(GameMode.people), reason: pair.id);
      }
    }
  });

  test('no pair puts two people with the same surname on the table', () {
    // «Пётр Капица / Сергей Капица» is unplayable: every association a player
    // gives lands on the surname both of them share, and the vote turns into
    // a coin flip over who was meant.
    for (final pair in peoplePairs) {
      expect(surname(pair.civilianWord), isNot(surname(pair.spyWord)),
          reason: '${pair.id} shares a surname');
    }
  });

  test('the mode is broad rather than one industry', () {
    expect(peopleCategories.length, greaterThanOrEqualTo(8));
    expect(peoplePairs.length, greaterThanOrEqualTo(250));

    // No single category may carry the mode — that is how «Личности» silently
    // becomes «актёры и музыканты».
    for (final category in peopleCategories) {
      expect(category.pairs.length / peoplePairs.length, lessThan(0.2),
          reason: '${category.id} dominates the mode');
    }
  });

  test('every category of the mode survives the quality gate', () {
    for (final category in peopleCategories) {
      final playable = playablePairs(allWordCategories,
          gameMode: GameMode.people, selectedCategoryIds: {category.id});
      expect(playable.length, greaterThanOrEqualTo(20), reason: category.id);
    }
  });

  test('every difficulty of the mode has enough pairs for a whole party', () {
    for (final level in Difficulty.values) {
      final playable = playablePairs(allWordCategories,
          gameMode: GameMode.people, selectedDifficulties: {level});
      expect(playable.length, greaterThanOrEqualTo(30), reason: level.name);
    }
  });

  test('the mode is not mostly easy', () {
    final easy =
        peoplePairs.where((p) => p.difficulty == Difficulty.easy).length;
    final harder = peoplePairs
        .where((p) =>
            p.difficulty == Difficulty.hard ||
            p.difficulty == Difficulty.expert)
        .length;
    expect(easy / peoplePairs.length, lessThan(0.2));
    expect(harder, greaterThan(easy * 2));
  });
}
