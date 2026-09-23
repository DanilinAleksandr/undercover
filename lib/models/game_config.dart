import 'content_type.dart';
import 'game_mode.dart';
import 'difficulty.dart';

class GameConfig {
  final List<String> playerNames;
  final bool alcoModeEnabled;

  /// Empty means "all non-adult categories".
  final Set<String> selectedCategoryIds;

  /// Empty means "any difficulty".
  final Set<Difficulty> selectedDifficulties;

  /// What the party is playing. Exactly one mode, always.
  final GameMode gameMode;

  /// Words, phrases or both — meaningful only in [GameMode.words], where it
  /// intersects with the difficulty filter. Empty means "both".
  final Set<ContentType> selectedContentTypes;

  /// Adult categories are excluded unless the host turns this on.
  final bool allowAdultContent;

  /// Whether hard and expert rounds may offer their authored clues.
  ///
  /// A per-party setting, not a global switch: the hint system and its access
  /// policy are untouched, the round simply never asks for them. Defaults to
  /// on so an existing table sees no change.
  final bool hintsEnabled;

  /// Skips the "pass the phone to X" screen before every vote.
  ///
  /// A pace setting for a table that is already sitting close together: the
  /// vote itself, who may be picked and how it is counted are untouched — only
  /// the hand-off screen in front of it disappears. Off by default.
  final bool fastVoting;

  /// Whether a card names the role it belongs to.
  ///
  /// Presentation only. Roles are assigned, the pair is drawn, the vote is
  /// counted and the winner decided in exactly the same way either way — the
  /// card simply stops printing «ШПИОН» / «МИРНЫЙ» and stops colouring itself
  /// by role. A table that wants to work the answer out from the words alone
  /// turns it off; on by default, so nothing changes for an existing party.
  final bool showRoles;

  const GameConfig({
    required this.playerNames,
    this.alcoModeEnabled = false,
    this.selectedCategoryIds = const {},
    this.selectedDifficulties = const {},
    this.gameMode = GameMode.words,
    this.selectedContentTypes = const {},
    this.allowAdultContent = false,
    this.hintsEnabled = true,
    this.fastVoting = false,
    this.showRoles = true,
  });

  GameConfig copyWith({
    List<String>? playerNames,
    bool? alcoModeEnabled,
    Set<String>? selectedCategoryIds,
    Set<Difficulty>? selectedDifficulties,
    GameMode? gameMode,
    Set<ContentType>? selectedContentTypes,
    bool? allowAdultContent,
    bool? hintsEnabled,
    bool? fastVoting,
    bool? showRoles,
  }) {
    return GameConfig(
      playerNames: playerNames ?? this.playerNames,
      alcoModeEnabled: alcoModeEnabled ?? this.alcoModeEnabled,
      selectedCategoryIds: selectedCategoryIds ?? this.selectedCategoryIds,
      selectedDifficulties: selectedDifficulties ?? this.selectedDifficulties,
      gameMode: gameMode ?? this.gameMode,
      selectedContentTypes: selectedContentTypes ?? this.selectedContentTypes,
      allowAdultContent: allowAdultContent ?? this.allowAdultContent,
      hintsEnabled: hintsEnabled ?? this.hintsEnabled,
      fastVoting: fastVoting ?? this.fastVoting,
      showRoles: showRoles ?? this.showRoles,
    );
  }

  static const GameConfig initial = GameConfig(playerNames: []);
}
