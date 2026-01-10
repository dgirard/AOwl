import 'package:aowl/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Integration tests for AOwl app.
///
/// These tests verify the app can launch and navigate correctly.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('AOwl App Integration Tests', () {
    testWidgets('app launches successfully', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: AOwlApp(),
        ),
      );

      // Wait for app to initialize
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // App should be rendered
      expect(find.byType(AOwlApp), findsOneWidget);
    });

    testWidgets('app has material app structure', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: AOwlApp(),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should have MaterialApp
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('app shows some form of content', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: AOwlApp(),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should show a Scaffold
      expect(find.byType(Scaffold), findsWidgets);
    });
  });
}
