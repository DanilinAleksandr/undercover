import 'package:flutter/widgets.dart';

import 'difficulty.dart';
import 'word_pair.dart';

class WordCategory {
  final String id;
  final String name;
  final IconData icon;
  final List<WordPair> pairs;

  /// Adult-themed content, hidden unless the host explicitly opts in.
  final bool isAdult;

  const WordCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.pairs,
    this.isAdult = false,
  });

  Iterable<WordPair> pairsOfDifficulty(Difficulty difficulty) =>
      pairs.where((p) => p.difficulty == difficulty);
}
