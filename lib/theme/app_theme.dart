import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_palette.dart';
import 'app_text.dart';

abstract class AppTheme {
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.plum,
      brightness: Brightness.dark,
      surface: AppColors.ink700,
      primary: AppColors.plum,
      secondary: AppColors.deepTeal,
      tertiary: AppColors.gold,
    );
    return _base(scheme, AppPalette.dark, AppColors.ink900);
  }

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.plum,
      brightness: Brightness.light,
      surface: AppColors.paper000,
      primary: AppColors.plum,
      secondary: AppColors.deepTeal,
      tertiary: AppColors.goldDeep,
    );
    return _base(scheme, AppPalette.light, AppColors.paper100);
  }

  static ThemeData _base(ColorScheme scheme, AppPalette palette, Color backdrop) {
    final isDark = scheme.brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: [palette],
      scaffoldBackgroundColor: backdrop,
      textTheme: TextTheme(
        displayMedium: AppText.wordmark.copyWith(color: palette.textPrimary),
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: -0.6,
          color: palette.textPrimary,
        ),
        headlineSmall: TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: palette.textPrimary,
        ),
        titleLarge: TextStyle(fontWeight: FontWeight.w800, color: palette.textPrimary),
        titleMedium: TextStyle(
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
          letterSpacing: -0.1,
        ),
        bodyLarge: TextStyle(height: 1.5, color: palette.textSecondary),
        bodyMedium: TextStyle(height: 1.5, color: palette.textSecondary),
        labelLarge: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.3),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: palette.textPrimary,
        titleTextStyle: TextStyle(
          color: palette.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.ink600 : AppColors.paper000,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.xl),
          side: BorderSide(color: palette.border),
        ),
        titleTextStyle: TextStyle(
          color: palette.textPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.3,
        ),
        contentTextStyle: TextStyle(
          color: palette.textSecondary,
          fontSize: 14.5,
          height: 1.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.cardFill,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(color: palette.border),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.gold,
        selectionHandleColor: AppColors.gold,
      ),
      dividerTheme: DividerThemeData(color: palette.border, thickness: 1, space: 1),
    );
  }
}
