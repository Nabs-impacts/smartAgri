import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_motion.dart';
import 'app_skeleton.dart';

class AppAsyncView<T> extends StatelessWidget {
  const AppAsyncView({
    required this.value,
    required this.builder,
    this.loadingBuilder,
    this.errorBuilder,
    this.emptyBuilder,
    this.isEmpty,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(BuildContext context, T data) builder;
  final WidgetBuilder? loadingBuilder;
  final Widget Function(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  )?
  errorBuilder;
  final WidgetBuilder? emptyBuilder;
  final bool Function(T data)? isEmpty;

  Widget _skeleton() {
    return const SkeletonList(count: 3);
  }

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (value.isLoading && !value.hasValue) {
      child = KeyedSubtree(
        key: const ValueKey<String>('async_loading'),
        child: loadingBuilder?.call(context) ?? _skeleton(),
      );
    } else if (value.hasError && !value.hasValue) {
      child = KeyedSubtree(
        key: const ValueKey<String>('async_error'),
        child:
            errorBuilder?.call(context, value.error!, value.stackTrace) ??
            _skeleton(),
      );
    } else {
      final T data = value.requireValue;
      if (isEmpty?.call(data) ?? false) {
        child = KeyedSubtree(
          key: const ValueKey<String>('async_empty'),
          child: emptyBuilder?.call(context) ?? _skeleton(),
        );
      } else {
        child = KeyedSubtree(
          key: const ValueKey<String>('async_data'),
          child: builder(context, data),
        );
      }
    }
    return AnimatedSwitcher(
      duration: AppMotion.mediumFor(context),
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      child: child,
    );
  }
}
