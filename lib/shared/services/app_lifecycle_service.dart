import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/unlock/providers/auth_provider.dart';

/// Provider for the app lifecycle service.
final appLifecycleServiceProvider = Provider<AppLifecycleService>((ref) {
  return AppLifecycleService(ref);
});

/// Service for managing app lifecycle events and session timeout.
///
/// Implements:
/// - Lock on background (mobile)
/// - Lock after inactivity timeout (desktop)
/// - Lock on device restart
class AppLifecycleService with WidgetsBindingObserver {
  final Ref _ref;
  Timer? _inactivityTimer;
  DateTime? _lastActivity;
  bool _isInitialized = false;

  /// Inactivity timeout duration for desktop platforms.
  static const Duration desktopTimeout = Duration(minutes: 5);

  /// Whether to lock immediately on background (mobile only).
  static bool get lockOnBackground =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Whether to use inactivity timeout (desktop only).
  static bool get useInactivityTimeout =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  AppLifecycleService(this._ref);

  /// Initializes the lifecycle service.
  void initialize() {
    if (_isInitialized) return;
    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;
    _resetInactivityTimer();
  }

  /// Disposes the lifecycle service.
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    _isInitialized = false;
  }

  /// Records user activity to reset inactivity timer.
  void recordActivity() {
    _lastActivity = DateTime.now();
    _resetInactivityTimer();
  }

  /// Resets the inactivity timer.
  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();

    if (!useInactivityTimeout) return;

    _inactivityTimer = Timer(desktopTimeout, () {
      _lockDueToInactivity();
    });
  }

  /// Locks the vault due to inactivity.
  void _lockDueToInactivity() {
    _ref.read(authNotifierProvider.notifier).lock();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // On mobile, lock when app goes to background
        if (lockOnBackground) {
          _ref.read(authNotifierProvider.notifier).lock();
        }
      case AppLifecycleState.resumed:
        // Reset timer when app resumes
        _resetInactivityTimer();
      case AppLifecycleState.detached:
        // App is being terminated
        break;
    }
  }

  /// Gets time since last activity.
  Duration? get timeSinceLastActivity {
    if (_lastActivity == null) return null;
    return DateTime.now().difference(_lastActivity!);
  }

  /// Checks if session should be locked due to inactivity.
  bool get shouldLockDueToInactivity {
    if (!useInactivityTimeout) return false;
    final since = timeSinceLastActivity;
    if (since == null) return false;
    return since > desktopTimeout;
  }
}

/// Widget that wraps the app to track user activity.
class ActivityTracker extends ConsumerStatefulWidget {
  const ActivityTracker({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ActivityTracker> createState() => _ActivityTrackerState();
}

class _ActivityTrackerState extends ConsumerState<ActivityTracker> {
  AppLifecycleService? _service;

  @override
  void initState() {
    super.initState();
    // Initialize lifecycle service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _service = ref.read(appLifecycleServiceProvider);
      _service?.initialize();
    });
  }

  @override
  void dispose() {
    // Dispose using stored reference to avoid ref access after dispose
    _service?.dispose();
    super.dispose();
  }

  void _onActivity() {
    _service?.recordActivity();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _onActivity,
      onPanDown: (_) => _onActivity(),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _onActivity(),
        onPointerMove: (_) => _onActivity(),
        child: widget.child,
      ),
    );
  }
}
