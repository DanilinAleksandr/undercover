import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:undercover/app.dart';

void main() {
  testWidgets('Home screen shows the app title and primary actions', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: UndercoverApp()));
    await tester.pumpAndSettle();

    expect(find.text('UNDERCOVER'), findsOneWidget);
    expect(find.text('Новая игра'), findsOneWidget);
    expect(find.text('Как играть'), findsOneWidget);
  });
}
