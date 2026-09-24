/// What the party is playing this evening.
///
/// A mode, not a filter: exactly one is chosen for a round, and the four
/// never mix. A round of «Места» can never be handed a word pair because the
/// place pool ran dry — the modes have separate content, separate pools and
/// separate played histories.
///
/// Inside a mode the ordinary filters still apply (categories, difficulty,
/// 18+, and — in [words] only — the words/phrases split).
enum GameMode {
  words('Слова', 'Обычные слова и словосочетания'),
  people('Личности', 'Известные люди и персонажи'),
  places('Места', 'Города, страны и знаменитые объекты'),

  /// Not a pair of words but a pair of topics: everybody names things from
  /// the real theme, and one player bluffs from a neighbouring one — or from
  /// nothing at all, see [GameConfig.impostorSeesDecoy].
  impostor('Самозванец', 'Общая тема на всех, у одного — подставная');

  final String label;
  final String hint;

  const GameMode(this.label, this.hint);
}
