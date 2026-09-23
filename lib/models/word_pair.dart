import 'content_type.dart';
import 'difficulty.dart';
import 'game_mode.dart';

/// One round's secret words: [civilianWord] goes to the majority, [spyWord]
/// to the spy. The two must be associatively adjacent but never synonyms or
/// a plain subtype of one another — the spy has to reason, not just recognise.
///
/// [tags] lists the shared association space of the pair (the concepts both
/// words can plausibly evoke). They are content metadata used by the quality
/// checks in `test/word_pack_quality_test.dart`.
///
/// [score] is the play-value rating from the editorial pass, 1–5:
///  * 5 — excellent: wide shared field, several natural associations per word,
///    no giveaway;
///  * 4 — good: solid overlap, still needs thinking;
///  * 3 — playable but thin (a little obvious or a little flat) — kept in the
///    base but only drawn when the 4–5 pool runs dry;
///  * 1–2 — synonyms, obvious subtypes or dead ends. These never ship in a
///    category; they live in `data/needs_rework.dart` awaiting a rewrite.
class WordPair {
  final String civilianWord;
  final String spyWord;
  final Difficulty difficulty;
  final List<String> tags;
  final int score;

  /// Which mode this pair belongs to.
  ///
  /// Optional on purpose: the original base declares nothing and plays in
  /// [GameMode.words], so not one of those entries had to be touched when the
  /// personality and place modes arrived.
  final GameMode? mode;

  const WordPair(
    this.civilianWord,
    this.spyWord,
    this.difficulty,
    this.tags,
    this.score, {
    this.mode,
  });

  /// The mode this pair can be dealt in.
  GameMode get gameMode => mode ?? GameMode.words;

  /// Words or phrases — the shape of the pair, used by the filter that only
  /// exists inside the words mode.
  ContentType get contentType =>
      isPhrase ? ContentType.phrases : ContentType.words;

  String get id => '$civilianWord/$spyWord';

  /// Stable identity of the pair, used to spot the same secret written twice
  /// in the base — including written backwards.
  ///
  /// Order-independent and spelling-tolerant on purpose: «Кошка / Собака» and
  /// «Собака / Кошка» are the same secret at the table, and which side the
  /// spy gets is decided per round.
  String get historyKey {
    final a = normalizeWord(civilianWord);
    final b = normalizeWord(spyWord);
    return a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a';
  }

  /// The two words of the pair as history keys.
  ///
  /// The played history is kept per *word*, not per pair: once the table has
  /// heard «Кошка», every future pair containing it is spent too, so nobody
  /// gets a familiar word in a new disguise.
  List<String> get wordKeys => [
        normalizeWord(civilianWord),
        normalizeWord(spyWord),
      ];

  /// Canonical form of one word or phrase: trimmed, lower case, ё folded into
  /// е and inner whitespace collapsed. Phrases go through the same funnel as
  /// single words, so both live in one history.
  static String normalizeWord(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('ё', 'е')
      .replaceAll(RegExp(r'\s+'), ' ');

  /// Pairs good enough to be the default draw pool.
  bool get isPrime => score >= 4;

  /// True when either side is more than one word.
  ///
  /// Phrase pairs live all over the base, not just in the "Словосочетания"
  /// category, so the content filter is derived from the pair itself rather
  /// than from which file it happens to sit in. Together with [isWordsOnly]
  /// this splits the base cleanly in two.
  bool get isPhrase => _wordCount(civilianWord) > 1 || _wordCount(spyWord) > 1;

  /// True when both sides are single words.
  bool get isWordsOnly => !isPhrase;

  static int _wordCount(String value) =>
      value.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
}
