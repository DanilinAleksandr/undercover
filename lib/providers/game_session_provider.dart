import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/game_rules.dart';
import '../logic/word_pack_selector.dart';
import '../models/game_config.dart';
import '../models/game_phase.dart';
import '../models/game_result.dart';
import '../models/game_session.dart';
import '../models/vote.dart';
import 'used_entries_provider.dart';
import 'word_pack_provider.dart';

/// Central state machine for an in-progress game. `null` means no game is
/// currently running (host is on the home/setup screens).
class GameSessionNotifier extends Notifier<GameSession?> {
  @override
  GameSession? build() => null;

  /// Deals a new round, or returns false when the filters plus the played-word
  /// history leave nothing to deal.
  ///
  /// False is never a crash and never a silent fallback: the caller shows the
  /// host what ran out and offers the two honest ways forward — change the
  /// filters, or reset the history.
  bool startGame(GameConfig config) {
    final pair = pickWordPair(
      categories: ref.read(wordPackProvider),
      gameMode: config.gameMode,
      selectedCategoryIds: config.selectedCategoryIds,
      selectedContentTypes: config.selectedContentTypes,
      selectedDifficulties: config.selectedDifficulties,
      allowAdultContent: config.allowAdultContent,
      usedWordKeys: ref.read(usedEntriesProvider)[config.gameMode] ?? const {},
    );
    // No fallback into another mode: a party playing places that has run out
    // of places is told so, never handed a word pair.
    if (pair == null) return false;
    // Both words are spent the moment the pair is dealt — this is the only
    // place the history grows. A setup screen that is opened and abandoned
    // never reaches here, so nothing is recorded for a game that never ran.
    ref.read(usedEntriesProvider.notifier).markUsed(config.gameMode, pair);
    state = createSession(config, pair);
    return true;
  }

  /// Lets a running round follow the five settings that only change how it is
  /// played, never what it was dealt from.
  ///
  /// The mode, the categories, the tiers and the words/phrases split all
  /// shaped the pool this pair came out of; changing them now would
  /// describe a round that was never dealt, so they stay where the party
  /// started. Everything here is presentation or pace, and the table is
  /// allowed to change its mind mid-game.
  void syncLiveSettings(GameConfig preferences) {
    final session = state;
    if (session == null) return;
    state = session.copyWith(
      config: session.config.copyWith(
        alcoModeEnabled: preferences.alcoModeEnabled,
        allowAdultContent: preferences.allowAdultContent,
        hintsEnabled: preferences.hintsEnabled,
        showRoles: preferences.showRoles,
        fastVoting: preferences.fastVoting,
      ),
    );
  }

  void beginHandoffSequence() {
    final session = state;
    if (session == null) return;
    state = session.copyWith(phase: GamePhase.handoff, currentRevealIndex: 0);
  }

  void confirmHandoff() {
    final session = state;
    if (session == null) return;
    state = session.copyWith(phase: GamePhase.reveal);
  }

  void confirmReveal() {
    final session = state;
    if (session == null) return;
    final players = [...session.players];
    final i = session.currentRevealIndex;
    players[i] = players[i].copyWith(hasSeenWord: true);
    if (i + 1 < players.length) {
      state = session.copyWith(
        players: players,
        phase: GamePhase.handoff,
        currentRevealIndex: i + 1,
      );
    } else {
      // The last card closes the pass-and-play part outright: the table talks
      // freely from here, so there is no intro step and no turn order to enter.
      state = session.copyWith(
        players: players,
        phase: GamePhase.association,
      );
    }
  }

  void startVoting() {
    final session = state;
    if (session == null) return;
    state = session.copyWith(
      phase: _phaseBeforeVote(session),
      currentVotingIndex: 0,
    );
  }

  /// Where a voter starts: at the hand-off screen, or straight at the ballot
  /// when the table asked for a fast vote. Nothing else about the vote differs.
  GamePhase _phaseBeforeVote(GameSession session) =>
      session.config.fastVoting ? GamePhase.voting : GamePhase.votingHandoff;

  void confirmVotingHandoff() {
    final session = state;
    if (session == null) return;
    state = session.copyWith(phase: GamePhase.voting);
  }

  void castVote(String targetId) {
    final session = state;
    if (session == null) return;
    final voter = session.players[session.currentVotingIndex];
    final votes = [
      ...session.votes,
      Vote(voterId: voter.id, targetId: targetId),
    ];
    final players = [...session.players];
    players[session.currentVotingIndex] =
        players[session.currentVotingIndex].copyWith(hasVoted: true);

    final next = session.currentVotingIndex + 1;
    if (next < players.length) {
      state = session.copyWith(
        players: players,
        votes: votes,
        phase: _phaseBeforeVote(session),
        currentVotingIndex: next,
      );
    } else {
      final result = tallyVotes(players, votes, session.spyPlayerId);
      state = session.copyWith(
        players: players,
        votes: votes,
        voteResult: result,
        phase: GamePhase.voteResult,
      );
    }
  }

  void proceedFromVoteResult() {
    final session = state;
    if (session == null || session.voteResult == null) return;
    if (session.voteResult!.spyWasCaught) {
      state = session.copyWith(phase: GamePhase.spyGuess);
    } else {
      _finish(spyGuessedCorrectly: null);
    }
  }

  /// Records the spy's spoken guess as judged by the table.
  ///
  /// The word is said out loud, not typed: everyone at the table hears it and
  /// agrees whether it was right, which is faster than one player thumbing it
  /// into a text field while the rest wait.
  void resolveSpyGuess({required bool correct}) {
    if (state == null) return;
    _finish(spyGuessedCorrectly: correct);
  }

  void _finish({required bool? spyGuessedCorrectly}) {
    final session = state;
    if (session == null || session.voteResult == null) return;
    final outcome = deriveOutcome(
      session.voteResult!,
      spyGuessedCorrectly: spyGuessedCorrectly,
    );
    final penalty = derivePenalty(outcome, session.config.alcoModeEnabled);
    state = session.copyWith(
      phase: GamePhase.winner,
      result: GameResult(
        outcome: outcome,
        spyGuessedCorrectly: spyGuessedCorrectly,
        penalty: penalty,
      ),
    );
  }

  /// Same table, fresh roles and a pair the party has not seen.
  ///
  /// Returns false when the history has exhausted the current filters — the
  /// winner screen then offers a reset or a trip back to the filters instead
  /// of replaying the round that just ended.
  bool playAgainSamePlayers() {
    final session = state;
    if (session == null) return false;
    return startGame(session.config);
  }

  void endGame() {
    state = null;
  }
}

final gameSessionProvider =
    NotifierProvider<GameSessionNotifier, GameSession?>(
      GameSessionNotifier.new,
    );
