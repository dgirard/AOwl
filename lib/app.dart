import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'shared/services/app_lifecycle_service.dart';
import 'shared/theme/app_theme.dart';

/// The main AShare application widget.
class AShareApp extends ConsumerWidget {
  const AShareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return ActivityTracker(
      child: MaterialApp.router(
        title: 'AShare',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        routerConfig: router,
      ),
    );
  }
}
