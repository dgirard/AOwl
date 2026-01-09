import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Wraps a child widget with staggered list animation.
class AnimatedListItem extends StatelessWidget {
  const AnimatedListItem({
    super.key,
    required this.index,
    required this.child,
    this.delay = const Duration(milliseconds: 50),
  });

  final int index;
  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return child
        .animate()
        .fadeIn(
          duration: 300.ms,
          delay: delay * index,
        )
        .slideX(
          begin: 0.1,
          end: 0,
          duration: 300.ms,
          delay: delay * index,
          curve: Curves.easeOut,
        );
  }
}

/// Extension for easy animation of list widgets.
extension AnimatedListExtension on Widget {
  /// Animates the widget as a list item with staggered delay.
  Widget animateListItem(int index, {Duration delay = const Duration(milliseconds: 50)}) {
    return AnimatedListItem(
      index: index,
      delay: delay,
      child: this,
    );
  }
}
