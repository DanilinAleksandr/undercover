import 'package:flutter/widgets.dart';

import 'difficulty.dart';
import 'game_mode.dart';
import 'word_category.dart';
import 'word_pair.dart';

/// One round of «Самозванец»: the [theme] everybody names things from, and
/// the [decoyTheme] the impostor gets instead.
///
/// Authoring rules — checked where they can be in
/// `test/theme_pack_quality_test.dart`, editorial where they cannot:
///  * the decoy is never a subtype or a synonym of the theme. «Dark Souls» and
///    «Elden Ring» are one theme, not a pair — every item of one belongs to
///    the other too;
///  * the decoy is a real, recognisable topic on its own, close enough in
///    spirit for the impostor to bluff, but not so close that one theme's
///    items fit the other;
///  * both are worded *broadly* — «Souls-игры FromSoftware», not «Dark Souls
///    1» — so the table never argues about where a theme ends.
///
/// [score] follows [WordPair.score]: 5 is clearly different topics of one
/// macro-genre, 1–2 is the same thing twice or guaranteed confusion.
///
/// No tags and no hints: the round is spoken aloud from the players' own
/// knowledge of a topic, so there is no association field to describe.
class ThemePair {
  final String theme;
  final String decoyTheme;
  final Difficulty difficulty;
  final int score;

  const ThemePair(this.theme, this.decoyTheme, this.difficulty, this.score);

  /// The same round in the shape the rest of the game already plays.
  ///
  /// Everything downstream — the deal, the played history, the pool counter,
  /// the vote, the penalty — works on [WordPair] and on player ids, never on
  /// what the word means. The theme is simply the majority's "word" and the
  /// decoy the impostor's, so none of it needs a branch of its own.
  WordPair toWordPair() => WordPair(
        theme,
        decoyTheme,
        difficulty,
        const [],
        score,
        mode: GameMode.impostor,
      );
}

/// A themed pack of [ThemePair]s — the «Самозванец» counterpart of
/// [WordCategory], mirroring its fields.
class ThemeCategory {
  final String id;
  final String name;
  final IconData icon;
  final List<ThemePair> pairs;

  const ThemeCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.pairs,
  });

  WordCategory toWordCategory() => WordCategory(
        id: id,
        name: name,
        icon: icon,
        pairs: [for (final pair in pairs) pair.toWordPair()],
      );
}
