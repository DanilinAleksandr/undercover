enum GamePhase {
  none,
  roleIntro,
  handoff,
  reveal,
  // One open-ended phase: the table decides how many rounds of associations
  // to play, in what order and when to stop. The app only waits for the call
  // to vote.
  association,
  votingHandoff,
  voting,
  voteResult,
  spyGuess,
  winner,
}
