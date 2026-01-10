import 'package:aowl/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AOwl app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: AOwlApp(),
      ),
    );

    // Wait for async initialization
    await tester.pumpAndSettle();

    // App should render without crashing
    expect(find.byType(AOwlApp), findsOneWidget);
  });
}
