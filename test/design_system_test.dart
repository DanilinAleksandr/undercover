import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undercover/app.dart';
import 'package:undercover/theme/app_colors.dart';
import 'package:undercover/theme/app_palette.dart';
import 'package:undercover/theme/app_text.dart';

/// Guards for the art direction itself.
///
/// The visual identity is a product decision as much as the rules are: a
/// near-black table, muted role colours, gold reserved for what matters, and a
/// type scale where the secret word outranks everything. These lock that in so
/// a later tweak cannot quietly drift the app back to stock Material.

double _saturation(Color c) => HSLColor.fromColor(c).saturation;

void main() {
  group('art direction', () {
    test('the table is near-black, not navy-grey', () {
      expect(AppColors.ink900.computeLuminance(), lessThan(0.02));
      expect(AppColors.ink800.computeLuminance(), lessThan(0.03));
    });

    test('role colours stay muted rather than neon', () {
      for (final entry in {
        'crimson': AppColors.crimson,
        'plum': AppColors.plum,
        'deepTeal': AppColors.deepTeal,
        'steel': AppColors.steel,
      }.entries) {
        expect(_saturation(entry.value), lessThan(0.72),
            reason: '${entry.key} is too saturated for the dark-fantasy look');
        expect(_saturation(entry.value), greaterThan(0.20),
            reason: '${entry.key} has gone grey and lost its role identity');
      }
    });

    test('spy and civilian gradients are clearly distinguishable', () {
      final spy = HSLColor.fromColor(AppColors.spyGradient.colors.first).hue;
      final civilian =
          HSLColor.fromColor(AppColors.civilianGradient.colors.first).hue;
      final delta = (spy - civilian).abs();
      expect(delta > 60 && delta < 300, isTrue,
          reason: 'the two sides must not read as the same colour family');
    });

    test('gold is a warm accent, not another role colour', () {
      final hue = HSLColor.fromColor(AppColors.gold).hue;
      expect(hue, greaterThan(30));
      expect(hue, lessThan(60));
    });
  });

  group('type scale', () {
    testWidgets('roles are ordered so the secret word dominates',
        (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: const [AppPalette.dark]),
          home: Builder(builder: (c) {
            context = c;
            return const SizedBox();
          }),
        ),
      );

      final word = AppText.gameWord(context).fontSize!;
      final name = AppText.playerName(context).fontSize!;
      final title = AppText.title(context).fontSize!;
      final body = AppText.body(context).fontSize!;
      final caption = AppText.caption(context).fontSize!;
      final eyebrow = AppText.eyebrow(context).fontSize!;

      expect(word, greaterThan(title));
      expect(word, greaterThan(name));
      expect(title, greaterThan(body));
      expect(body, greaterThan(caption));
      expect(caption, greaterThan(eyebrow));

      // Weight must separate the roles too, not just size.
      expect(AppText.gameWord(context).fontWeight, FontWeight.w900);
      expect(AppText.body(context).fontWeight, FontWeight.w400);
      // Tracked-out small caps are what make a label read as a label.
      expect(AppText.eyebrow(context).letterSpacing, greaterThan(1.5));
    });
  });

  group('motion', () {
    testWidgets('no screen in the main flow animates forever', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ProviderScope(child: UndercoverApp()));

      // A looping animation would keep the frame dirty forever and drain the
      // battery through a long party; pumpAndSettle catches exactly that.
      await tester.pumpAndSettle();
      expect(find.text('UNDERCOVER'), findsOneWidget);

      await tester.tap(find.text('Как играть'));
      await tester.pumpAndSettle();
      expect(find.text('Расстановка'), findsOneWidget);
    });
  });
}
