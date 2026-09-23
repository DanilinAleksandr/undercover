class VoteResult {
  final Map<String, int> tally;
  final String? majorityTargetId;
  final bool isTie;
  final bool spyWasCaught;

  const VoteResult({
    required this.tally,
    required this.majorityTargetId,
    required this.isTie,
    required this.spyWasCaught,
  });
}
