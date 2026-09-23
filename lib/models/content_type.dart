/// The shape of a pair inside the «Слова» mode: one word a side, or several.
///
/// A technical classification of the content, not a choice of what to play —
/// that is [GameMode]. This filter only exists in the words mode, where the
/// two buckets partition its pairs exactly.
enum ContentType {
  words('Слова'),
  phrases('Фразы');

  final String label;

  const ContentType(this.label);
}
