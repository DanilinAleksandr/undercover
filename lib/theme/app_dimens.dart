/// Spacing, radius and motion scales.
///
/// Every screen pulls its rhythm from here so the app reads as one game
/// rather than a set of separately-built Flutter screens.
abstract class Gap {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
  static const huge = 40.0;

  /// Standard horizontal page padding.
  static const page = 24.0;
}

abstract class Radii {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 28.0;
  static const pill = 999.0;
}

abstract class Motion {
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 420);
}
