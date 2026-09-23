import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_mode.dart';
import '../models/word_pair.dart';

/// Where each mode keeps its played entries.
///
/// One store per mode, because the modes do not share content: «Париж» spent
/// as a place must not block a word round, and the same text could legitimately
/// exist in two modes. `used_words` keeps its old name so a player upgrading
/// from the previous version does not lose a single word already played.
const Map<GameMode, String> usedEntriesKeys = {
  GameMode.words: 'used_words',
  GameMode.people: 'used_people',
  GameMode.places: 'used_places',
};

/// Schema version of the stores, so a future change to the format can be
/// recognised instead of guessed.
const String usedEntriesVersionKey = 'used_words_version';
const int usedEntriesVersion = 2;

/// The pair-level history shipped two versions ago. Read once, folded into the
/// words store, then dropped.
const String legacyUsedPairsKey = 'used_pair_keys';

/// Everything the party has already been dealt, one set per mode, normalised
/// by [WordPair.normalizeWord].
///
/// Per side rather than per pair: hearing «Кошка» once spends the word, so
/// «Кошка / Тигр» today rules out «Кошка / Лев» tomorrow. An entry is written
/// the moment a pair is dealt into a round — opening the filters or abandoning
/// setup writes nothing.
///
/// The three sets never see each other. Spending «Париж» in the places mode
/// leaves the words mode untouched, and resetting one mode leaves the other
/// two exactly as they were.
class UsedEntriesNotifier extends Notifier<Map<GameMode, Set<String>>> {
  late final Future<void> _loading;
  final Set<GameMode> _wasReset = {};

  @override
  Map<GameMode, Set<String>> build() {
    _loading = _load();
    return {for (final mode in GameMode.values) mode: const {}};
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loaded = <GameMode, Set<String>>{};
      for (final mode in GameMode.values) {
        if (_wasReset.contains(mode)) continue;
        final stored = <String>{
          ...?prefs.getStringList(usedEntriesKeys[mode]!),
          if (mode == GameMode.words) ..._migrateLegacyPairs(prefs),
        };
        if (stored.isEmpty) continue;
        // Anything already spent in this session wins: the host can reach the
        // setup screen before the disk answers.
        loaded[mode] = {...state[mode]!, ...stored};
      }
      if (loaded.isEmpty) return;
      state = {...state, ...loaded};
      await _write(prefs);
    } catch (error) {
      debugPrint('Could not read the played history: $error');
    }
  }

  /// Turns `кошка|собака` entries from the oldest format into two words. Only
  /// the words mode existed back then, so only it inherits them.
  Iterable<String> _migrateLegacyPairs(SharedPreferences prefs) {
    final legacy = prefs.getStringList(legacyUsedPairsKey);
    if (legacy == null) return const [];
    return legacy
        .expand((entry) => entry.split('|'))
        .map(WordPair.normalizeWord)
        .where((word) => word.isNotEmpty);
  }

  Future<void> _persist() async {
    try {
      await _loading;
      await _write(await SharedPreferences.getInstance());
    } catch (error) {
      debugPrint('Could not persist the played history: $error');
    }
  }

  Future<void> _write(SharedPreferences prefs) async {
    for (final mode in GameMode.values) {
      final entries = state[mode] ?? const <String>{};
      final key = usedEntriesKeys[mode]!;
      if (entries.isEmpty) {
        await prefs.remove(key);
      } else {
        await prefs.setStringList(key, entries.toList());
      }
    }
    await prefs.setInt(usedEntriesVersionKey, usedEntriesVersion);
    if (prefs.containsKey(legacyUsedPairsKey)) {
      await prefs.remove(legacyUsedPairsKey);
    }
  }

  /// What [mode] has already played.
  Set<String> of(GameMode mode) => state[mode] ?? const {};

  /// Marks both sides of [pair] as played in [mode]. Idempotent.
  void markUsed(GameMode mode, WordPair pair) {
    final keys = pair.wordKeys;
    final current = of(mode);
    if (keys.every(current.contains)) return;
    state = {...state, mode: {...current, ...keys}};
    _persist();
  }

  /// Wipes one mode's history. Manual only, and the other modes keep theirs.
  void reset(GameMode mode) {
    _wasReset.add(mode);
    if (of(mode).isEmpty) return;
    state = {...state, mode: const {}};
    _persist();
  }
}

final usedEntriesProvider =
    NotifierProvider<UsedEntriesNotifier, Map<GameMode, Set<String>>>(
        UsedEntriesNotifier.new);
