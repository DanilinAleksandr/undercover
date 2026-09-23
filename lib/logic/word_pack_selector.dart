import 'dart:math';

import '../models/content_type.dart';
import '../models/difficulty.dart';
import '../models/game_mode.dart';
import '../models/word_category.dart';
import '../models/word_pair.dart';

/// Returns the categories a host is allowed to pick from: adult packs only
/// appear once [allowAdultContent] is on.
List<WordCategory> visibleCategories(
  List<WordCategory> categories, {
  required bool allowAdultContent,
}) {
  return categories.where((c) => allowAdultContent || !c.isAdult).toList();
}

/// True when [pair] belongs to [gameMode] and satisfies the filters that live
/// inside that mode.
///
/// The mode is a gate, not a filter: a pair from another mode is never a
/// candidate, whatever the rest of the settings say. Inside the mode the
/// filters intersect as before, and the words/phrases split is ignored outside
/// [GameMode.words] — the other modes have no such distinction.
bool matchesFilters(
  WordPair pair, {
  GameMode gameMode = GameMode.words,
  Set<ContentType> selectedContentTypes = const {},
  Set<Difficulty> selectedDifficulties = const {},
}) {
  if (pair.gameMode != gameMode) return false;
  final contentOk = gameMode != GameMode.words ||
      selectedContentTypes.isEmpty ||
      selectedContentTypes.contains(pair.contentType);
  final difficultyOk =
      selectedDifficulties.isEmpty || selectedDifficulties.contains(pair.difficulty);
  return contentOk && difficultyOk;
}

/// Every pair in [categories] that passes both filters.
///
/// The played-pairs history is *not* applied here — this is the raw filter
/// result, used both by the quality checks and as the input to
/// [playablePairs], which is the one place history is subtracted.
List<WordPair> pairsMatching(
  List<WordCategory> categories, {
  GameMode gameMode = GameMode.words,
  Set<String> selectedCategoryIds = const {},
  Set<ContentType> selectedContentTypes = const {},
  Set<Difficulty> selectedDifficulties = const {},
  bool allowAdultContent = false,
}) {
  final visible =
      visibleCategories(categories, allowAdultContent: allowAdultContent);
  final pool = selectedCategoryIds.isEmpty
      ? visible
      : visible.where((c) => selectedCategoryIds.contains(c.id)).toList();
  return [
    for (final category in pool)
      for (final pair in category.pairs)
        if (matchesFilters(
          pair,
          gameMode: gameMode,
          selectedContentTypes: selectedContentTypes,
          selectedDifficulties: selectedDifficulties,
        ))
          pair,
  ];
}

/// The pairs a round can actually be built from, given the host's filters and
/// what the party has already played.
///
/// The funnel, in order: mode -> categories -> words/phrases (words mode only)
/// -> difficulty (all of that in [pairsMatching]) -> played entries -> the
/// play-value gate. A pair is out as soon as *either* of its sides has been
/// dealt before in this mode, so an answer never comes back with a different
/// partner.
///
/// There is no fallback between modes: a party playing «Места» whose place
/// pool has run out gets an empty pool, never a word pair.
///
/// History is subtracted before the play-value gate on purpose: once every
/// editorially-rated 4-5 pair of a filter is spent, the merely playable 3s
/// become the real pool instead of the screen claiming zero.
///
/// No graceful degradation happens here, and none happens in [pickWordPair]
/// either. The counter on the filter screen is the contract: an impossible
/// combination reads as zero and the round does not start.
List<WordPair> playablePairs(
  List<WordCategory> categories, {
  GameMode gameMode = GameMode.words,
  Set<String> selectedCategoryIds = const {},
  Set<ContentType> selectedContentTypes = const {},
  Set<Difficulty> selectedDifficulties = const {},
  bool allowAdultContent = false,
  Set<String> usedWordKeys = const {},
}) {
  final matching = pairsMatching(
    categories,
    gameMode: gameMode,
    selectedCategoryIds: selectedCategoryIds,
    selectedContentTypes: selectedContentTypes,
    selectedDifficulties: selectedDifficulties,
    allowAdultContent: allowAdultContent,
  );
  final fresh = usedWordKeys.isEmpty
      ? matching
      : matching
          .where((p) => !p.wordKeys.any(usedWordKeys.contains))
          .toList();
  final prime = fresh.where((p) => p.isPrime).toList();
  return prime.isNotEmpty ? prime : fresh;
}

/// Above this many estimated rounds the forecast stops being information.
///
/// "Хватит примерно на 490 партий" tells a host nothing they did not already
/// read from the pair count — it is a line of noise above the start button.
/// The number matters exactly when the pool is running low, so the line is
/// shown only up to and including this many rounds.
const int estimatedGamesVisibilityThreshold = 100;

/// How many playable pairs the current filters leave, split by difficulty.
class WordPoolStats {
  /// Pairs that can still be dealt right now.
  final int total;

  final Map<Difficulty, int> byDifficulty;

  /// Pairs that match the filters but hold a word the party already heard —
  /// the reason the pool is smaller than the base suggests.
  final int blockedByHistory;

  const WordPoolStats(
    this.total,
    this.byDifficulty,
    this.blockedByHistory,
    this.estimatedGames,
  );

  bool get isEmpty => total == 0;

  /// Nothing left to play, and history is the reason. Worth saying out loud,
  /// because the fix is a reset rather than a different filter.
  bool get exhaustedByHistory => total == 0 && blockedByHistory > 0;

  /// Roughly how many rounds the current pool still holds. Zero when the pool
  /// is empty — there is nothing to forecast, and the screen has a better
  /// thing to say.
  ///
  /// Deliberately an estimate, not a promise. A round spends the pair it deals
  /// *and* every other pair sharing one of its two words, so the divisor is
  /// the average of that collateral across the pool ([averageBurnPerGame]).
  /// It is computed from the real pool, not modelled: no forecasting system,
  /// one division.
  final int estimatedGames;

  /// Whether the forecast is worth a line on screen: there is a pool, and it
  /// is small enough for the number to mean something.
  bool get showsForecast =>
      estimatedGames > 0 &&
      estimatedGames <= estimatedGamesVisibilityThreshold;

  int countOf(Difficulty difficulty) => byDifficulty[difficulty] ?? 0;

  /// The difficulties actually present, in tier order — so the breakdown never
  /// shows "0 лёгких" for a filter that excluded easy pairs on purpose.
  List<Difficulty> get presentDifficulties =>
      Difficulty.values.where((d) => countOf(d) > 0).toList();
}

/// Average number of pairs one round takes out of [pool].
///
/// Every round removes the pair it dealt plus any other pair that shares one
/// of its two words — the played history works on words. Averaging that over
/// the pool gives an honest divisor for the next few rounds without pretending
/// to predict a whole evening; it drifts as the pool shrinks, which is why the
/// number is shown as approximate.
double averageBurnPerGame(List<WordPair> pool) {
  if (pool.isEmpty) return 1;
  final uses = <String, int>{};
  for (final pair in pool) {
    for (final key in pair.wordKeys) {
      uses[key] = (uses[key] ?? 0) + 1;
    }
  }
  var burn = 0;
  for (final pair in pool) {
    // 1 for the pair itself, plus the others hanging off each of its words.
    burn += 1;
    for (final key in pair.wordKeys) {
      burn += (uses[key] ?? 1) - 1;
    }
  }
  return burn / pool.length;
}

/// Counts [playablePairs] and, alongside it, how much of this filter the party
/// has already burned through.
WordPoolStats poolStats(
  List<WordCategory> categories, {
  GameMode gameMode = GameMode.words,
  Set<String> selectedCategoryIds = const {},
  Set<ContentType> selectedContentTypes = const {},
  Set<Difficulty> selectedDifficulties = const {},
  bool allowAdultContent = false,
  Set<String> usedWordKeys = const {},
}) {
  final pairs = playablePairs(
    categories,
    gameMode: gameMode,
    selectedCategoryIds: selectedCategoryIds,
    selectedContentTypes: selectedContentTypes,
    selectedDifficulties: selectedDifficulties,
    allowAdultContent: allowAdultContent,
    usedWordKeys: usedWordKeys,
  );
  final counts = <Difficulty, int>{};
  for (final pair in pairs) {
    counts[pair.difficulty] = (counts[pair.difficulty] ?? 0) + 1;
  }
  final blocked = usedWordKeys.isEmpty
      ? 0
      : pairsMatching(
          categories,
          gameMode: gameMode,
          selectedCategoryIds: selectedCategoryIds,
          selectedContentTypes: selectedContentTypes,
          selectedDifficulties: selectedDifficulties,
          allowAdultContent: allowAdultContent,
        ).where((p) => p.wordKeys.any(usedWordKeys.contains)).length;
  final games =
      pairs.isEmpty ? 0 : (pairs.length / averageBurnPerGame(pairs)).floor();
  // A pool that holds anything at all is worth at least one round.
  return WordPoolStats(
      pairs.length, counts, blocked, pairs.isEmpty ? 0 : (games < 1 ? 1 : games));
}

/// Draws a random pair from exactly the pool the filter screen advertised, or
/// returns null when that pool is empty.
///
/// Null is a real answer, not a failure to handle: it means "these filters
/// plus this history leave nothing", and the caller says so instead of
/// quietly playing something the host did not ask for.
WordPair? pickWordPair({
  required List<WordCategory> categories,
  GameMode gameMode = GameMode.words,
  required Set<String> selectedCategoryIds,
  Set<ContentType> selectedContentTypes = const {},
  Set<Difficulty> selectedDifficulties = const {},
  bool allowAdultContent = false,
  Set<String> usedWordKeys = const {},
  Random? random,
}) {
  final candidates = playablePairs(
    categories,
    gameMode: gameMode,
    selectedCategoryIds: selectedCategoryIds,
    selectedContentTypes: selectedContentTypes,
    selectedDifficulties: selectedDifficulties,
    allowAdultContent: allowAdultContent,
    usedWordKeys: usedWordKeys,
  );
  if (candidates.isEmpty) return null;
  return candidates[(random ?? Random()).nextInt(candidates.length)];
}
