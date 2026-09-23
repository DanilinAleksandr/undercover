import '../data/word_hints.dart';
import '../models/difficulty.dart';
import '../models/game_mode.dart';
import '../models/word_hints.dart';

/// How many clues a player may unlock, by how hard the pair is.
///
/// Easy and medium pairs get none — the whole point of those rounds is that
/// the word is common. Hard pairs get the broad hint only; expert pairs can
/// escalate all the way to the near-definition.
int maxHintsFor(Difficulty difficulty) {
  switch (difficulty) {
    case Difficulty.easy:
    case Difficulty.medium:
      return 0;
    case Difficulty.hard:
      return 1;
    case Difficulty.expert:
      return 3;
  }
}

/// The clues available for [word] at [difficulty], in the order they unlock.
///
/// Returns an empty list when the round is not hard enough to deserve help, or
/// when the word has no authored hints yet — the button simply does not appear.
///
/// [mode] is the gate that keeps the three modes apart. Hints are keyed by the
/// bare word, and a word can live in two modes at once: «Замок» is a lock in
/// the words base and a fortress in the places base. Without the gate a places
/// round would hand out a clue written about the other secret entirely.
List<String> hintsFor(String word, Difficulty difficulty,
    {GameMode mode = GameMode.words}) {
  if (mode != GameMode.words) return const [];
  final limit = maxHintsFor(difficulty);
  if (limit == 0) return const [];
  final WordHints? hints = wordHints[word];
  if (hints == null) return const [];
  return hints.all.take(limit).toList();
}
