import 'package:ashare/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Integration tests for AShare app.
///
/// These tests verify the app can launch and navigate correctly.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('AShare App Integration Tests', () {
    testWidgets('app launches successfully', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: AShareApp(),
        ),
      );

      // Wait for app to initialize
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // App should be rendered
      expect(find.byType(AShareApp), findsOneWidget);
    });

    testWidgets('app has material app structure', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: AShareApp(),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should have MaterialApp
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('app shows some form of content', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: AShareApp(),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should show a Scaffold
      expect(find.byType(Scaffold), findsWidgets);
    });
  });
}
