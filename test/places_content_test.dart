import 'package:flutter_test/flutter_test.dart';
import 'package:undercover/data/word_pack_registry.dart';
import 'package:undercover/logic/word_pack_selector.dart';
import 'package:undercover/models/difficulty.dart';
import 'package:undercover/models/game_mode.dart';

/// Guards for the places mode as a *mode*.
///
/// The per-category craft rules (tier coverage, prime share, no synonyms, no
/// shared stems) are enforced for the whole base by word_pack_quality_test.
/// What is checked here is only what is specific to this mode: that its packs
/// really declare it, that it is broad enough to feel like its own game, and
/// that every filter a host can set still leaves something to play.
void main() {
  final placeCategories =
      allWordCategories.where((c) => c.id.startsWith('place_')).toList();
  final placePairs = [for (final c in placeCategories) ...c.pairs];

  test('every pack under the places prefix declares the places mode', () {
    // A copy-pasted `_mode` const would silently dump a whole pack into the
    // words mode, where it would be unplayable and invisible in review.
    expect(placeCategories, isNotEmpty);
    for (final category in placeCategories) {
      for (final pair in category.pairs) {
        expect(pair.gameMode, GameMode.places, reason: pair.id);
        expect(pair.mode, isNotNull, reason: '${pair.id} relies on the default');
      }
    }
  });

  test('nothing outside those packs claims to be a place', () {
    for (final category in allWordCategories) {
      if (category.id.startsWith('place_')) continue;
      for (final pair in category.pairs) {
        expect(pair.gameMode, isNot(GameMode.places), reason: pair.id);
      }
    }
  });

  test('the mode is broad rather than a handful of landmarks', () {
    expect(placeCategories.length, greaterThanOrEqualTo(8));
    expect(placePairs.length, greaterThanOrEqualTo(300));

    // No single category may carry the mode: with 11 categories the largest
    // must stay well under a fifth of it, or «Места» is really «Города».
    for (final category in placeCategories) {
      expect(category.pairs.length / placePairs.length, lessThan(0.2),
          reason: '${category.id} dominates the mode');
    }
  });

  test('every category of the mode survives the quality gate', () {
    // playablePairs applies the score >= 4 cut. A category that ends up empty
    // there is dead weight: it shows in the filter list and returns nothing.
    for (final category in placeCategories) {
      final playable = playablePairs(allWordCategories,
          gameMode: GameMode.places, selectedCategoryIds: {category.id});
      expect(playable.length, greaterThanOrEqualTo(20), reason: category.id);
    }
  });

  test('every difficulty of the mode has enough pairs for a whole party', () {
    // A party of 6 burns one pair a round. Any single tier has to carry an
    // evening on its own, which is what the hardcore setting assumes.
    for (final level in Difficulty.values) {
      final playable = playablePairs(allWordCategories,
          gameMode: GameMode.places, selectedDifficulties: {level});
      expect(playable.length, greaterThanOrEqualTo(30), reason: level.name);
    }
  });

  test('the mode is not mostly easy', () {
    final easy = placePairs.where((p) => p.difficulty == Difficulty.easy).length;
    final harder = placePairs
        .where((p) =>
            p.difficulty == Difficulty.hard ||
            p.difficulty == Difficulty.expert)
        .length;
    expect(easy / placePairs.length, lessThan(0.2));
    expect(harder, greaterThan(easy * 2));
  });
}
