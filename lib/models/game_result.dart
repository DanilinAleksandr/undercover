import 'alco_penalty.dart';

enum Outcome { spyWinsByGuess, civiliansWin, spyWinsUncaught }

class GameResult {
  final Outcome outcome;
  final bool? spyGuessedCorrectly;
  final AlcoPenalty? penalty;

  const GameResult({
    required this.outcome,
    this.spyGuessedCorrectly,
    this.penalty,
  });

  bool get spyWon =>
      outcome == Outcome.spyWinsByGuess || outcome == Outcome.spyWinsUncaught;
}
