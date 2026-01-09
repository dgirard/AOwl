import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/exchange/presentation/exchange_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/setup/presentation/setup_screen.dart';
import '../features/unlock/presentation/unlock_screen.dart';
import '../features/unlock/providers/auth_provider.dart';
import '../features/unlock/providers/auth_state.dart';
import '../shared/widgets/app_shell.dart';

/// App route paths.
abstract final class AppRoutes {
  static const String setup = '/setup';
  static const String unlock = '/unlock';
  static const String exchange = '/exchange';
  static const String history = '/history';
  static const String settings = '/settings';
}

// Navigation key for root navigator
final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Provider for the app router.
final appRouterProvider = Provider<GoRouter>((ref) {
  final asyncAuthState = ref.watch(authNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.exchange,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final path = state.matchedLocation;

      // Handle loading state
      if (asyncAuthState.isLoading) {
        return null; // Stay on current page while loading
      }

      // Handle error state from async value
      if (asyncAuthState.hasError) {
        return path == AppRoutes.unlock ? null : AppRoutes.unlock;
      }

      // Get the actual auth state
      final authState = asyncAuthState.valueOrNull;

      // Determine where to redirect based on auth state
      return switch (authState) {
        null => null, // Still loading
        AuthStateInitializing() => null, // Wait for initialization
        AuthStateNotConfigured() => path == AppRoutes.setup ? null : AppRoutes.setup,
        AuthStateLocked() => path == AppRoutes.unlock ? null : AppRoutes.unlock,
        AuthStateUnlocked() => (path == AppRoutes.setup || path == AppRoutes.unlock)
            ? AppRoutes.exchange
            : null,
        AuthStateError() => path == AppRoutes.unlock ? null : AppRoutes.unlock,
      };
    },
    routes: [
      // Setup route (outside shell)
      GoRoute(
        path: AppRoutes.setup,
        name: 'setup',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SetupScreen(),
          transitionsBuilder: _fadeTransition,
        ),
      ),

      // Unlock route (outside shell)
      GoRoute(
        path: AppRoutes.unlock,
        name: 'unlock',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const UnlockScreen(),
          transitionsBuilder: _fadeTransition,
        ),
      ),

      // Main app with bottom navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          // Exchange branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.exchange,
                name: 'exchange',
                pageBuilder: (context, state) => CustomTransitionPage(
                  key: state.pageKey,
                  child: const ExchangeScreen(),
                  transitionsBuilder: _fadeTransition,
                ),
              ),
            ],
          ),

          // History/Vault branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.history,
                name: 'history',
                pageBuilder: (context, state) => CustomTransitionPage(
                  key: state.pageKey,
                  child: const HistoryScreen(),
                  transitionsBuilder: _fadeTransition,
                ),
              ),
            ],
          ),

          // Settings branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                name: 'settings',
                pageBuilder: (context, state) => CustomTransitionPage(
                  key: state.pageKey,
                  child: const SettingsScreen(),
                  transitionsBuilder: _fadeTransition,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
    errorPageBuilder: (context, state) => MaterialPage(
      key: state.pageKey,
      child: _ErrorScreen(error: state.error),
    ),
  );
});

Widget _fadeTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return FadeTransition(
    opacity: animation,
    child: child,
  );
}

/// Error screen for routing errors.
class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({this.error});

  final Exception? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Page Not Found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              error?.toString() ?? 'Unknown error',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.exchange),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}
