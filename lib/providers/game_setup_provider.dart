import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/word_pack_registry.dart';
import '../models/content_type.dart';
import '../models/difficulty.dart';
import '../models/game_config.dart';
import '../models/game_mode.dart';

final Set<String> _adultCategoryIds =
    allWordCategories.where((c) => c.isAdult).map((c) => c.id).toSet();

const int kMinPlayers = 3;
const int kMaxPlayers = 12;
const int kDefaultPlayers = 5;

/// Where the party settings live between launches.
///
/// This provider holds the host's *preferences*: what the next party will be
/// dealt with, and what the app should do by default. A round that is already
/// running keeps its own snapshot in [GameSession.config] and is not affected
/// by anything written here — see `GameSessionNotifier.syncLiveSettings` for
/// the five settings a running round is allowed to follow.
///
/// One key per setting rather than a serialised blob: a missing key then
/// simply means "this setting was never touched", which is exactly the
/// migration an older install needs — every default survives, and [showRoles]
/// in particular comes back as true.
abstract class PartySettingsKeys {
  static const gameMode = 'party_game_mode';
  static const adult = 'party_adult';
  static const hints = 'party_hints';
  static const showRoles = 'party_show_roles';
  static const alco = 'party_alco';
  static const fastVoting = 'party_fast_voting';
  static const difficulties = 'party_difficulties';
  static const contentTypes = 'party_content_types';
  static const categories = 'party_categories';
  /// Retired. Listed only so [GameSetupNotifier] can clear it out of an
  /// install that still has it: a value nothing reads is harmless, but one
  /// left lying around invites a future reader.
  static const retiredHardcore = 'party_hardcore';
}

class GameSetupNotifier extends Notifier<GameConfig> {
  late final Future<void> _loading;

  /// True once the host has changed something this session, so a late-arriving
  /// read loses to what is already on screen instead of overwriting it.
  bool _touched = false;

  @override
  GameConfig build() {
    _loading = _restore();
    return GameConfig(
      playerNames: List.generate(kDefaultPlayers, (_) => ''),
    );
  }

  /// Brings back the settings of the last party.
  ///
  /// The line-up is deliberately not part of this: it has its own store and
  /// its own rules about when it may be written. Everything here is a rule of
  /// the game, and each one falls back to its default when the key is absent,
  /// so an install from before this existed keeps playing the way it did.
  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // An install from before hardcore was dropped still carries its key.
      // Nothing reads it any more; clearing it makes sure nothing ever will.
      await prefs.remove(PartySettingsKeys.retiredHardcore);
      if (_touched) return;
      final modeName = prefs.getString(PartySettingsKeys.gameMode);
      state = state.copyWith(
        gameMode:
            GameMode.values.where((m) => m.name == modeName).firstOrNull,
        allowAdultContent: prefs.getBool(PartySettingsKeys.adult),
        hintsEnabled: prefs.getBool(PartySettingsKeys.hints),
        showRoles: prefs.getBool(PartySettingsKeys.showRoles),
        alcoModeEnabled: prefs.getBool(PartySettingsKeys.alco),
        fastVoting: prefs.getBool(PartySettingsKeys.fastVoting),
        selectedDifficulties: _readSet(
            prefs, PartySettingsKeys.difficulties, Difficulty.values),
        selectedContentTypes: _readSet(
            prefs, PartySettingsKeys.contentTypes, ContentType.values),
        selectedCategoryIds:
            prefs.getStringList(PartySettingsKeys.categories)?.toSet(),
      );
    } catch (error) {
      debugPrint('Could not read the party settings: $error');
    }
  }

  static Set<T>? _readSet<T extends Enum>(
      SharedPreferences prefs, String key, List<T> values) {
    final stored = prefs.getStringList(key);
    if (stored == null) return null;
    return {
      for (final name in stored) ...values.where((v) => v.name == name),
    };
  }

  /// Writes the party settings back. Reached from the setting mutators only —
  /// never from the name fields, which change on every keystroke.
  Future<void> _persist() async {
    final config = state;
    try {
      await _loading;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PartySettingsKeys.gameMode, config.gameMode.name);
      await prefs.setBool(PartySettingsKeys.adult, config.allowAdultContent);
      await prefs.setBool(PartySettingsKeys.hints, config.hintsEnabled);
      await prefs.setBool(PartySettingsKeys.showRoles, config.showRoles);
      await prefs.setBool(PartySettingsKeys.alco, config.alcoModeEnabled);
      await prefs.setBool(PartySettingsKeys.fastVoting, config.fastVoting);
      await prefs.setStringList(PartySettingsKeys.difficulties,
          [for (final d in config.selectedDifficulties) d.name]);
      await prefs.setStringList(PartySettingsKeys.contentTypes,
          [for (final t in config.selectedContentTypes) t.name]);
      await prefs.setStringList(
          PartySettingsKeys.categories, config.selectedCategoryIds.toList());
    } catch (error) {
      debugPrint('Could not persist the party settings: $error');
    }
  }

  /// The one way a party setting changes: update, then remember.
  void _applySetting(GameConfig next) {
    _touched = true;
    state = next;
    _persist();
  }

  void setPlayerCount(int count) {
    final clamped = count < kMinPlayers
        ? kMinPlayers
        : (count > kMaxPlayers ? kMaxPlayers : count);
    final current = state.playerNames;
    final names = List<String>.generate(
      clamped,
      (i) => i < current.length ? current[i] : '',
    );
    state = state.copyWith(playerNames: names);
  }

  /// Appends an empty seat, up to [kMaxPlayers]. The list is the only source
  /// of truth for how many people are playing — there is no separate counter
  /// that could drift away from it.
  void addPlayer() {
    if (state.playerNames.length >= kMaxPlayers) return;
    state = state.copyWith(playerNames: [...state.playerNames, '']);
  }

  /// Removes one seat, down to [kMinPlayers].
  void removePlayerAt(int index) {
    if (state.playerNames.length <= kMinPlayers) return;
    if (index < 0 || index >= state.playerNames.length) return;
    final names = [...state.playerNames]..removeAt(index);
    state = state.copyWith(playerNames: names);
  }

  /// Replaces the whole line-up, e.g. with the roster of the last party.
  void setRoster(List<String> names) {
    final clamped = names.take(kMaxPlayers).toList();
    while (clamped.length < kMinPlayers) {
      clamped.add('');
    }
    state = state.copyWith(playerNames: clamped);
  }

  void setPlayerName(int index, String name) {
    if (index < 0 || index >= state.playerNames.length) return;
    final names = [...state.playerNames];
    names[index] = name;
    state = state.copyWith(playerNames: names);
  }

  void setAlcoMode(bool enabled) {
    _applySetting(state.copyWith(alcoModeEnabled: enabled));
  }

  void toggleCategory(String categoryId) {
    final ids = {...state.selectedCategoryIds};
    if (!ids.add(categoryId)) ids.remove(categoryId);
    _applySetting(state.copyWith(selectedCategoryIds: ids));
  }

  void toggleDifficulty(Difficulty difficulty) {
    final levels = {...state.selectedDifficulties};
    if (!levels.add(difficulty)) levels.remove(difficulty);
    _applySetting(state.copyWith(selectedDifficulties: levels));
  }

  void setHintsEnabled(bool enabled) {
    _applySetting(state.copyWith(hintsEnabled: enabled));
  }

  /// Whether the card names the role it belongs to. Presentation only: it
  /// touches no filter, so it neither joins «Хардкор» nor cancels it.
  void setShowRoles(bool enabled) {
    _applySetting(state.copyWith(showRoles: enabled));
  }

  /// Pace of the vote, not a filter: it changes no pair, so it neither joins
  /// «Хардкор» nor cancels it.
  void setFastVoting(bool enabled) {
    _applySetting(state.copyWith(fastVoting: enabled));
  }

  /// Switches what the party is playing.
  ///
  /// Categories belong to a mode, so a selection made in another one is
  /// dropped rather than left to silently empty the pool. Difficulty and the
  /// rest survive: they mean the same thing everywhere.
  void setGameMode(GameMode mode) {
    if (state.gameMode == mode) return;
    _applySetting(state.copyWith(
      gameMode: mode,
      selectedCategoryIds: const {},
    ));
  }

  /// Words, phrases or both — the split inside [GameMode.words]. Empty means
  /// both, so clearing the last selected shape is the same as choosing all.
  void toggleContentType(ContentType type) {
    final types = {...state.selectedContentTypes};
    if (!types.add(type)) types.remove(type);
    _applySetting(state.copyWith(selectedContentTypes: types));
  }

  /// The «Всё» chip of the words/phrases row.
  void clearContentTypes() {
    _applySetting(state.copyWith(selectedContentTypes: const {}));
  }

  void setAllowAdultContent(bool allowed) {
    // Dropping adult categories from the selection keeps the chips in the UI
    // consistent with what the picker will actually consider.
    final ids = allowed
        ? state.selectedCategoryIds
        : state.selectedCategoryIds.where((id) => !_adultCategoryIds.contains(id)).toSet();
    _applySetting(state.copyWith(
      allowAdultContent: allowed,
      selectedCategoryIds: ids,
    ));
  }

  bool get isValid {
    final trimmed = state.playerNames.map((n) => n.trim()).toList();
    if (trimmed.length < kMinPlayers) return false;
    if (trimmed.any((n) => n.isEmpty)) return false;
    final unique = trimmed.map((n) => n.toLowerCase()).toSet();
    return unique.length == trimmed.length;
  }

  void reset() {
    state = build();
  }
}

final gameSetupProvider = NotifierProvider<GameSetupNotifier, GameConfig>(
  GameSetupNotifier.new,
);
