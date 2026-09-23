import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the last line-up is kept, next to the other settings rather than
/// instead of them.
const String lastRosterKey = 'last_roster';

/// The names, in order, of the last table that actually sat down to play.
///
/// Only the line-up: no roles, no words, no votes, nothing about a round. The
/// same people play several evenings in a row, and retyping five names every
/// time is the most boring part of the app.
///
/// Written on a confirmed change — leaving the names step forward, or starting
/// a round — never on a keystroke. An edit the host abandons by backing out
/// therefore never becomes the saved roster.
class LastRosterNotifier extends Notifier<List<String>> {
  late final Future<void> _loading;
  bool _wasCleared = false;

  @override
  List<String> build() {
    _loading = _load();
    return const [];
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(lastRosterKey);
      if (_wasCleared || stored == null || stored.isEmpty) return;
      // A roster remembered in this session already wins: it is newer.
      if (state.isEmpty) state = List.unmodifiable(stored);
    } catch (error) {
      debugPrint('Could not read the last roster: $error');
    }
  }

  Future<void> _persist() async {
    try {
      await _loading;
      final prefs = await SharedPreferences.getInstance();
      if (state.isEmpty) {
        await prefs.remove(lastRosterKey);
      } else {
        await prefs.setStringList(lastRosterKey, state);
      }
    } catch (error) {
      debugPrint('Could not persist the last roster: $error');
    }
  }

  /// Stores [names] as the line-up to offer next time.
  ///
  /// Blank entries are dropped: a half-filled setup that was confirmed anyway
  /// should not come back as an empty row.
  void remember(List<String> names) {
    final cleaned = [
      for (final name in names)
        if (name.trim().isNotEmpty) name.trim(),
    ];
    if (cleaned.isEmpty || listEquals(cleaned, state)) return;
    state = List.unmodifiable(cleaned);
    _persist();
  }

  /// Forgets the saved line-up. Manual only.
  void clear() {
    _wasCleared = true;
    if (state.isEmpty) return;
    state = const [];
    _persist();
  }
}

final lastRosterProvider =
    NotifierProvider<LastRosterNotifier, List<String>>(LastRosterNotifier.new);
