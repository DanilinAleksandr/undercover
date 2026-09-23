enum Difficulty {
  easy('Лёгкие'),
  medium('Средние'),
  hard('Сложные'),
  expert('Очень сложные');

  final String label;

  const Difficulty(this.label);
}
