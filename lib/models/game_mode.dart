/// What the party is playing this evening.
///
/// A mode, not a filter: exactly one is chosen for a round, and the three
/// never mix. A round of «Места» can never be handed a word pair because the
/// place pool ran dry — the modes have separate content, separate pools and
/// separate played histories.
///
/// Inside a mode the ordinary filters still apply (categories, difficulty,
/// 18+, and — in [words] only — the words/phrases split).
enum GameMode {
  words('Слова', 'Обычные слова и словосочетания'),
  people('Личности', 'Известные люди и персонажи'),
  places('Места', 'Города, страны и знаменитые объекты');

  final String label;
  final String hint;

  const GameMode(this.label, this.hint);
}
