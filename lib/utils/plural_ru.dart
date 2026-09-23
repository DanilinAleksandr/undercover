import '../models/difficulty.dart';

/// Picks the Russian form that matches [count].
///
/// Russian needs three: one (1, 21, 31 — but not 11), few (2-4, 22-24) and
/// many (everything else, including the teens). Getting this wrong is the
/// fastest way to make an interface look machine-translated, and the filter
/// screen shows these numbers on every tap.
String pluralRu(int count, String one, String few, String many) {
  final mod100 = count % 100;
  if (mod100 >= 11 && mod100 <= 14) return many;
  switch (count % 10) {
    case 1:
      return one;
    case 2:
    case 3:
    case 4:
      return few;
    default:
      return many;
  }
}

/// "1 пара" / "3 пары" / "730 пар".
String pairsLabel(int count) =>
    '$count ${pluralRu(count, 'пара', 'пары', 'пар')}';

/// "1 слово" / "3 слова" / "37 слов".
String wordsLabel(int count) =>
    '$count ${pluralRu(count, 'слово', 'слова', 'слов')}';

/// "1 партия" / "3 партии" / "30 партий".
String gamesLabel(int count) =>
    '$count ${pluralRu(count, 'партия', 'партии', 'партий')}';

/// "142 лёгких" / "1 сложная" — the difficulty read as a counted adjective,
/// which is shorter at the table than "Лёгкие: 142".
String difficultyCountLabel(Difficulty difficulty, int count) {
  final (one, many) = switch (difficulty) {
    Difficulty.easy => ('лёгкая', 'лёгких'),
    Difficulty.medium => ('средняя', 'средних'),
    Difficulty.hard => ('сложная', 'сложных'),
    Difficulty.expert => ('очень сложная', 'очень сложных'),
  };
  return '$count ${pluralRu(count, one, many, many)}';
}
