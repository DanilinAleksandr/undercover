import '../models/game_phase.dart';

abstract class RoutePaths {
  static const home = '/';
  static const setup = '/setup';
  static const partySettings = '/setup/party';
  static const roleIntro = '/game/roles';
  static const handoff = '/game/handoff';
  static const reveal = '/game/reveal';
  static const association = '/game/association';
  static const votingHandoff = '/game/voting-handoff';
  static const voting = '/game/voting';
  static const voteResult = '/game/vote-result';
  static const spyGuess = '/game/spy-guess';
  static const winner = '/game/winner';
  static const settings = '/settings';
  static const rules = '/rules';
}

/// Maps the game's current phase to the route that should be showing.
/// Used to drive navigation right after a state-changing provider call.
String pathForPhase(GamePhase phase) {
  switch (phase) {
    case GamePhase.none:
      return RoutePaths.home;
    case GamePhase.roleIntro:
      return RoutePaths.roleIntro;
    case GamePhase.handoff:
      return RoutePaths.handoff;
    case GamePhase.reveal:
      return RoutePaths.reveal;
    case GamePhase.association:
      return RoutePaths.association;
    case GamePhase.votingHandoff:
      return RoutePaths.votingHandoff;
    case GamePhase.voting:
      return RoutePaths.voting;
    case GamePhase.voteResult:
      return RoutePaths.voteResult;
    case GamePhase.spyGuess:
      return RoutePaths.spyGuess;
    case GamePhase.winner:
      return RoutePaths.winner;
  }
}
