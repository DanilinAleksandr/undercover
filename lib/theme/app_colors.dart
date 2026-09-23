import 'package:flutter/material.dart';

/// Palette for the game's "dark fantasy party" identity.
///
/// The base is near-black ink so the table feels like a dim room. Roles are
/// carried by muted, slightly desaturated colours — crimson/plum for the spy,
/// deep teal/steel for the civilians — and gold is reserved for the few things
/// that must feel valuable: the alco penalty, a winning tally, a chosen token.
/// Deliberately not neon: saturation is what makes an app read as cheap.
abstract class AppColors {
  // Ink — surfaces, darkest first.
  static const ink900 = Color(0xFF07080D);
  static const ink800 = Color(0xFF0C0E16);
  static const ink700 = Color(0xFF131624);
  static const ink600 = Color(0xFF1B1F30);

  // Parchment — the light theme's paper.
  static const paper100 = Color(0xFFF5F2EC);
  static const paper200 = Color(0xFFE8E3D9);
  static const paper000 = Color(0xFFFFFDF9);

  // Roles.
  static const crimson = Color(0xFF8E2F4E);
  static const plum = Color(0xFF5C2E86);
  static const deepTeal = Color(0xFF17656B);
  static const steel = Color(0xFF2C4C8F);

  // Accent metal.
  static const gold = Color(0xFFD9A94C);
  static const goldDeep = Color(0xFF9A6F22);

  /// Kept as the single "brand" hue for seeds and focus rings.
  static const violet = plum;
  static const magenta = crimson;
  static const teal = deepTeal;
  static const blue = steel;
  static const amber = gold;
  static const amberDeep = goldDeep;

  static const spyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [crimson, plum],
  );

  static const civilianGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [deepTeal, steel],
  );

  static const alcoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gold, goldDeep],
  );

  /// Thin sheen laid over cards and buttons — reads as a lit edge and is what
  /// separates a "premium" surface from a flat Material rectangle.
  static const sheen = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x14FFFFFF), Color(0x00FFFFFF)],
    stops: [0.0, 0.6],
  );

  static const backgroundGradientDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [ink900, ink800, ink900],
    stops: [0.0, 0.55, 1.0],
  );

  static const backgroundGradientLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [paper100, paper200],
  );
}
