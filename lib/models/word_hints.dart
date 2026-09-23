/// Escalating clues for one secret word.
///
/// Hints are authored per word and shipped with the base — never generated at
/// runtime — so a player always gets the same, vetted clue. None of them may
/// contain the word itself, a cognate of it, or a straight synonym: a hint
/// should narrow the field, not hand over the answer.
class WordHints {
  /// Broad associative field. Enough to place the word in a world.
  final String soft;

  /// A more concrete property. Only used for expert pairs.
  final String? medium;

  /// Almost a definition, still without naming the thing. Expert pairs only.
  final String? strong;

  const WordHints(this.soft, [this.medium, this.strong]);

  List<String> get all => [soft, ?medium, ?strong];
}
