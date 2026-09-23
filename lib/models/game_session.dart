import 'game_config.dart';
import 'game_phase.dart';
import 'game_result.dart';
import 'player.dart';
import 'vote.dart';
import 'vote_result.dart';
import 'word_pair.dart';

class GameSession {
  final GameConfig config;
  final List<Player> players;
  final WordPair wordPair;
  final String spyPlayerId;
  final GamePhase phase;
  final int currentRevealIndex;
  final int currentVotingIndex;
  final List<Vote> votes;
  final VoteResult? voteResult;
  final GameResult? result;

  const GameSession({
    required this.config,
    required this.players,
    required this.wordPair,
    required this.spyPlayerId,
    this.phase = GamePhase.roleIntro,
    this.currentRevealIndex = 0,
    this.currentVotingIndex = 0,
    this.votes = const [],
    this.voteResult,
    this.result,
  });

  Player get spyPlayer => players.firstWhere((p) => p.id == spyPlayerId);

  List<Player> get civilians => players.where((p) => p.id != spyPlayerId).toList();

  GameSession copyWith({
    GameConfig? config,
    List<Player>? players,
    WordPair? wordPair,
    String? spyPlayerId,
    GamePhase? phase,
    int? currentRevealIndex,
    int? currentVotingIndex,
    List<Vote>? votes,
    VoteResult? voteResult,
    bool clearVoteResult = false,
    GameResult? result,
    bool clearResult = false,
  }) {
    return GameSession(
      config: config ?? this.config,
      players: players ?? this.players,
      wordPair: wordPair ?? this.wordPair,
      spyPlayerId: spyPlayerId ?? this.spyPlayerId,
      phase: phase ?? this.phase,
      currentRevealIndex: currentRevealIndex ?? this.currentRevealIndex,
      currentVotingIndex: currentVotingIndex ?? this.currentVotingIndex,
      votes: votes ?? this.votes,
      voteResult: clearVoteResult ? null : (voteResult ?? this.voteResult),
      result: clearResult ? null : (result ?? this.result),
    );
  }
}
