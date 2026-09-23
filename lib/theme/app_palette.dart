import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Theme-aware surface and text colours.
///
/// Screens used to hard-code `Colors.white` for every label, which made the
/// light theme unreadable. They now read their colours from here, so both
/// themes stay legible while keeping the same "spy noir" identity.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  /// Fill for translucent cards and chips sitting on the background.
  final Color cardFill;
  final Color cardFillStrong;
  final Color border;
  final Color borderStrong;

  /// Colour that reads correctly on top of a role gradient.
  final Color onAccent;
  final Color onAccentMuted;

  final Gradient background;

  /// Face-down secret card: deliberately neutral so the reveal is a surprise.
  final Color cardBack;
  final Color cardBackPattern;

  const AppPalette({
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.cardFill,
    required this.cardFillStrong,
    required this.border,
    required this.borderStrong,
    required this.onAccent,
    required this.onAccentMuted,
    required this.background,
    required this.cardBack,
    required this.cardBackPattern,
  });

  static const dark = AppPalette(
    textPrimary: Color(0xFFF3EFE7),
    textSecondary: Color(0xB8F3EFE7),
    textMuted: Color(0x80F3EFE7),
    cardFill: Color(0x0FFFFFFF),
    cardFillStrong: Color(0x1AFFFFFF),
    border: Color(0x1FFFFFFF),
    borderStrong: Color(0x38FFFFFF),
    onAccent: Color(0xFFFFF8EE),
    onAccentMuted: Color(0xCCFFF8EE),
    background: AppColors.backgroundGradientDark,
    cardBack: AppColors.ink600,
    cardBackPattern: Color(0x1AD9A94C),
  );

  static const light = AppPalette(
    textPrimary: Color(0xFF15131C),
    textSecondary: Color(0xB815131C),
    textMuted: Color(0x8015131C),
    cardFill: Color(0x0D15131C),
    cardFillStrong: Color(0x1A15131C),
    border: Color(0x2115131C),
    borderStrong: Color(0x3815131C),
    onAccent: Color(0xFFFFF8EE),
    onAccentMuted: Color(0xCCFFF8EE),
    background: AppColors.backgroundGradientLight,
    cardBack: Color(0xFF20243A),
    cardBackPattern: Color(0x33D9A94C),
  );

  @override
  AppPalette copyWith({
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? cardFill,
    Color? cardFillStrong,
    Color? border,
    Color? borderStrong,
    Color? onAccent,
    Color? onAccentMuted,
    Gradient? background,
    Color? cardBack,
    Color? cardBackPattern,
  }) {
    return AppPalette(
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      cardFill: cardFill ?? this.cardFill,
      cardFillStrong: cardFillStrong ?? this.cardFillStrong,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      onAccent: onAccent ?? this.onAccent,
      onAccentMuted: onAccentMuted ?? this.onAccentMuted,
      background: background ?? this.background,
      cardBack: cardBack ?? this.cardBack,
      cardBackPattern: cardBackPattern ?? this.cardBackPattern,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      cardFill: Color.lerp(cardFill, other.cardFill, t)!,
      cardFillStrong: Color.lerp(cardFillStrong, other.cardFillStrong, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      onAccentMuted: Color.lerp(onAccentMuted, other.onAccentMuted, t)!,
      background: Gradient.lerp(background, other.background, t) ?? background,
      cardBack: Color.lerp(cardBack, other.cardBack, t)!,
      cardBackPattern: Color.lerp(cardBackPattern, other.cardBackPattern, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  /// Palette for the current theme. Falls back to the dark identity so a
  /// widget can never end up with null colours.
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}
