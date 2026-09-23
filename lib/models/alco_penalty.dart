enum PenaltyTarget { spy, allCivilians }

class AlcoPenalty {
  final PenaltyTarget target;
  final int sips;
  final bool isFullShot;

  const AlcoPenalty({
    required this.target,
    required this.sips,
    this.isFullShot = false,
  });
}
