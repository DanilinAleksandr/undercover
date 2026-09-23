import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Typographic roles.
///
/// Each role has a visibly different weight, tracking and colour so a glance
/// tells you what matters: the secret word is the loudest thing the app ever
/// prints, service labels are the quietest. Screens pick a role instead of
/// inventing a one-off `TextStyle`, which is what kept the old UI feeling
/// like unrelated Material pages.
abstract class AppText {
  /// The logo lock-up. Wide tracking reads as an engraved title.
  static const wordmark = TextStyle(
    fontSize: 38,
    fontWeight: FontWeight.w900,
    letterSpacing: 7,
    height: 1,
  );

  /// The secret word — the single most important object in the app.
  static TextStyle gameWord(BuildContext context, {double size = 40}) =>
      TextStyle(
        color: context.palette.onAccent,
        fontSize: size,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.2,
        height: 1.02,
      );

  /// Screen-level heading.
  static TextStyle title(BuildContext context, {double size = 26}) => TextStyle(
        color: context.palette.textPrimary,
        fontSize: size,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.6,
        height: 1.15,
      );

  /// A person's name when they are the subject of the screen.
  static TextStyle playerName(BuildContext context, {double size = 30}) =>
      TextStyle(
        color: context.palette.textPrimary,
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        height: 1.1,
      );

  static TextStyle body(BuildContext context) => TextStyle(
        color: context.palette.textSecondary,
        fontSize: 14.5,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  /// Quiet service copy: hints, counters, footnotes.
  static TextStyle caption(BuildContext context) => TextStyle(
        color: context.palette.textMuted,
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        height: 1.35,
      );

  /// Small tracked-out label above a block.
  static TextStyle eyebrow(BuildContext context, {Color? color}) => TextStyle(
        color: color ?? context.palette.textMuted,
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 2.2,
      );
}
