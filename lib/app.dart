import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'shared/services/app_lifecycle_service.dart';
import 'shared/theme/app_theme.dart';

/// The main AOwl application widget.
class AOwlApp extends ConsumerWidget {
  const AOwlApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return ActivityTracker(
      child: MaterialApp.router(
        title: 'AOwl',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        routerConfig: router,
      ),
    );
  }
}
