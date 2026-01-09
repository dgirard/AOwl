import 'package:ashare/features/unlock/presentation/unlock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Set up larger screen size to avoid overflow errors
  const testScreenSize = Size(414, 896); // iPhone 11 Pro Max size

  group('UnlockScreen', () {
    testWidgets('renders unlock screen', (tester) async {
      tester.view.physicalSize = testScreenSize;
      tester.view.devicePixelRatio = 1.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: UnlockScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify unlock screen is displayed
      expect(find.byType(UnlockScreen), findsOneWidget);
    });

    testWidgets('displays AShare branding', (tester) async {
      tester.view.physicalSize = testScreenSize;
      tester.view.devicePixelRatio = 1.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: UnlockScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show app name
      expect(find.text('AShare'), findsOneWidget);
    });

    testWidgets('shows PIN entry prompt', (tester) async {
      tester.view.physicalSize = testScreenSize;
      tester.view.devicePixelRatio = 1.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: UnlockScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show PIN prompt
      expect(find.text('Enter your PIN'), findsOneWidget);
    });

    testWidgets('shows PIN pad with digit buttons', (tester) async {
      tester.view.physicalSize = testScreenSize;
      tester.view.devicePixelRatio = 1.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: UnlockScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify PIN pad digits are present
      for (var i = 0; i <= 9; i++) {
        expect(find.text('$i'), findsWidgets);
      }
    });

    testWidgets('shows backspace button (unicode symbol)', (tester) async {
      tester.view.physicalSize = testScreenSize;
      tester.view.devicePixelRatio = 1.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: UnlockScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should have a backspace button (unicode symbol)
      expect(find.text('\u232B'), findsOneWidget);
    });

    testWidgets('can tap PIN pad buttons', (tester) async {
      tester.view.physicalSize = testScreenSize;
      tester.view.devicePixelRatio = 1.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: UnlockScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap some digits
      await tester.tap(find.text('1').first);
      await tester.pump();

      await tester.tap(find.text('2').first);
      await tester.pump();

      await tester.tap(find.text('3').first);
      await tester.pump();

      // No exception should be thrown
      expect(find.byType(UnlockScreen), findsOneWidget);
    });

    testWidgets('shows shield icon in header', (tester) async {
      tester.view.physicalSize = testScreenSize;
      tester.view.devicePixelRatio = 1.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: UnlockScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should have shield icon
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    });

    testWidgets('has forgot PIN link', (tester) async {
      tester.view.physicalSize = testScreenSize;
      tester.view.devicePixelRatio = 1.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: UnlockScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should have forgot PIN link
      expect(find.text('Forgot PIN?'), findsOneWidget);
    });
  });
}
