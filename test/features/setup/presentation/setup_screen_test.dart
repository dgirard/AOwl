import 'package:ashare/features/setup/presentation/setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SetupScreen', () {
    testWidgets('renders setup screen with header', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SetupScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify header elements
      expect(find.text('Welcome to AShare'), findsOneWidget);
      expect(find.text('Secure cross-platform sharing'), findsOneWidget);
    });

    testWidgets('shows GitHub repository configuration section',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SetupScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify repository configuration section
      expect(find.text('GitHub Repository'), findsOneWidget);
    });

    testWidgets('shows security credentials section', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SetupScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify security credentials section
      expect(find.text('Security Credentials'), findsOneWidget);
    });

    testWidgets('complete setup button exists', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SetupScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the setup button
      expect(find.text('Complete Setup'), findsOneWidget);
    });

    testWidgets('shows shield icon', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SetupScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check for shield icon
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    });

    testWidgets('scrollable content for long form', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SetupScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should have scrollable content
      expect(find.byType(CustomScrollView), findsOneWidget);
    });
  });
}
