import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undercover/app.dart';
import 'package:undercover/theme/app_palette.dart';
import 'package:undercover/theme/app_theme.dart';

/// Screens used to hard-code white text, which made the light theme unreadable
/// while the setting to switch to it stayed available. These guard the fix.

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

Color _backdropOf(AppPalette palette) =>
    (palette.background as LinearGradient).colors.first;

void main() {
  group('palette contrast', () {
    for (final entry in {'dark': AppPalette.dark, 'light': AppPalette.light}.entries) {
      test('${entry.key}: body text is readable on the background', () {
        final palette = entry.value;
        final backdrop = _backdropOf(palette);
        expect(_contrast(palette.textPrimary, backdrop), greaterThan(7.0),
            reason: 'primary text must be strongly readable');
        expect(_contrast(palette.textSecondary, backdrop), greaterThan(4.5),
            reason: 'secondary text must meet normal-text contrast');
      });
    }

    test('the two themes are actually different, not both dark', () {
      expect(
        _backdropOf(AppPalette.light).computeLuminance(),
        greaterThan(_backdropOf(AppPalette.dark).computeLuminance() + 0.5),
      );
    });

    test('themes expose the palette extension', () {
      expect(AppTheme.dark.extension<AppPalette>(), isNotNull);
      expect(AppTheme.light.extension<AppPalette>(), isNotNull);
    });
  });

  testWidgets('the app renders in light mode without falling back to white text',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(const ProviderScope(child: UndercoverApp()));
    await tester.pumpAndSettle();

    final context = tester.element(find.text('Новая игра'));
    expect(Theme.of(context).brightness, Brightness.light);
    expect(context.palette.textPrimary, AppPalette.light.textPrimary);

    // Walk into setup to make sure the light surfaces render cleanly too.
    await tester.tap(find.text('Как играть'));
    await tester.pumpAndSettle();
    expect(find.text('Расстановка'), findsOneWidget);
  });
}
