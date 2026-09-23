import 'dart:math';

import '../models/alco_penalty.dart';
import '../models/game_config.dart';
import '../models/game_result.dart';
import '../models/game_session.dart';
import '../models/player.dart';
import '../models/role.dart';
import '../models/vote.dart';
import '../models/vote_result.dart';
import '../models/word_pair.dart';

({List<Player> players, String spyPlayerId}) assignRoles(
  List<String> playerNames,
) {
  final random = Random();
  final spyIndex = random.nextInt(playerNames.length);
  final players = <Player>[
    for (var i = 0; i < playerNames.length; i++)
      Player(
        id: 'player_$i',
        name: playerNames[i],
        role: i == spyIndex ? Role.spy : Role.civilian,
      ),
  ];
  return (players: players, spyPlayerId: players[spyIndex].id);
}

GameSession createSession(GameConfig config, WordPair wordPair) {
  final assignment = assignRoles(config.playerNames);
  return GameSession(
    config: config,
    players: assignment.players,
    wordPair: wordPair,
    spyPlayerId: assignment.spyPlayerId,
  );
}

VoteResult tallyVotes(
  List<Player> players,
  List<Vote> votes,
  String spyPlayerId,
) {
  final tally = <String, int>{for (final p in players) p.id: 0};
  for (final vote in votes) {
    tally[vote.targetId] = (tally[vote.targetId] ?? 0) + 1;
  }
  final maxVotes = tally.values.isEmpty ? 0 : tally.values.reduce(max);
  final topTargets = tally.entries
      .where((entry) => maxVotes > 0 && entry.value == maxVotes)
      .map((entry) => entry.key)
      .toList();
  final isTie = topTargets.length != 1;
  final majorityTargetId = isTie ? null : topTargets.first;
  final spyWasCaught = !isTie && majorityTargetId == spyPlayerId;
  return VoteResult(
    tally: tally,
    majorityTargetId: majorityTargetId,
    isTie: isTie,
    spyWasCaught: spyWasCaught,
  );
}

/// A tie (no single most-voted player) is treated the same as failing to
/// single out the spy: the spy was not caught and wins automatically.
Outcome deriveOutcome(VoteResult voteResult, {bool? spyGuessedCorrectly}) {
  if (!voteResult.spyWasCaught) return Outcome.spyWinsUncaught;
  return (spyGuessedCorrectly ?? false)
      ? Outcome.spyWinsByGuess
      : Outcome.civiliansWin;
}

AlcoPenalty? derivePenalty(Outcome outcome, bool alcoModeEnabled) {
  if (!alcoModeEnabled) return null;
  switch (outcome) {
    case Outcome.civiliansWin:
      return const AlcoPenalty(
        target: PenaltyTarget.spy,
        sips: 0,
        isFullShot: true,
      );
    case Outcome.spyWinsByGuess:
      return const AlcoPenalty(target: PenaltyTarget.allCivilians, sips: 2);
    case Outcome.spyWinsUncaught:
      return const AlcoPenalty(target: PenaltyTarget.allCivilians, sips: 1);
  }
}
