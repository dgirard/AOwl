import 'package:aowl/features/exchange/presentation/exchange_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExchangeScreen', () {
    testWidgets('renders exchange screen', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ExchangeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify exchange screen is displayed
      expect(find.byType(ExchangeScreen), findsOneWidget);
    });

    testWidgets('displays AOwl header', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ExchangeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show app name in header
      expect(find.text('AOwl'), findsOneWidget);
    });

    testWidgets('shows shield icon in header', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ExchangeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should have shield icon
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    });

    testWidgets('has more options menu button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ExchangeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should have more options button
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    });

    testWidgets('shows menu with lock option when tapped', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ExchangeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open menu
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      // Should show lock option
      expect(find.text('Lock Vault'), findsOneWidget);
    });

    testWidgets('shows settings option in menu', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ExchangeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open menu
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      // Should show settings option
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('shows Recent section header', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ExchangeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show recent section
      expect(find.text('Recent'), findsOneWidget);
    });

    testWidgets('shows View All button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ExchangeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show view all button
      expect(find.text('View All'), findsOneWidget);
    });

    testWidgets('has RefreshIndicator for pull-to-refresh', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ExchangeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should have RefreshIndicator
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('uses CustomScrollView for content', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ExchangeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should have CustomScrollView
      expect(find.byType(CustomScrollView), findsOneWidget);
    });
  });
}
