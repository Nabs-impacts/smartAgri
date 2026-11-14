import 'package:flutter/material.dart';

import '../app_motion.dart';
import '../app_palette.dart';
import '../tokens.dart';

class AppSkeletonScope extends StatefulWidget {
  const AppSkeletonScope({required this.child, super.key});

  final Widget child;

  @override
  State<AppSkeletonScope> createState() => _AppSkeletonScopeState();
}

class _AppSkeletonScopeState extends State<AppSkeletonScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  bool _disabled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool disabled = AppMotion.animationsDisabled(context);
    if (disabled == _disabled && _controller.isAnimating == !disabled) {
      return;
    }
    _disabled = disabled;
    if (disabled) {
      _controller.stop();
      _controller.value = 0.35;
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SkeletonInherited(animation: _controller, child: widget.child);
  }
}

class _SkeletonInherited extends InheritedWidget {
  const _SkeletonInherited({required this.animation, required super.child});

  final Animation<double> animation;

  static Animation<double>? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_SkeletonInherited>()
        ?.animation;
  }

  @override
  bool updateShouldNotify(_SkeletonInherited oldWidget) =>
      oldWidget.animation != animation;
}

class AppSkeleton extends StatelessWidget {
  const AppSkeleton({
    this.width,
    this.height = 16,
    this.borderRadius = AppRadii.smallBorder,
    super.key,
  });

  final double? width;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Color base = palette.inputFill;
    final Color highlight = palette.isDark
        ? palette.surfaceHigh
        : palette.surfaceRaised;
    final Animation<double>? animation = _SkeletonInherited.maybeOf(context);
    final Widget block = SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(color: base, borderRadius: borderRadius),
      ),
    );
    if (animation == null || AppMotion.animationsDisabled(context)) {
      return block;
    }
    return SizedBox(
      width: width,
      height: height,
      child: AnimatedBuilder(
        animation: animation,
        builder: (BuildContext context, Widget? child) {
          final double value = animation.value;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: LinearGradient(
                begin: Alignment(-3 + 6 * value, 0),
                end: Alignment(-1 + 6 * value, 0),
                colors: <Color>[base, highlight, base],
                stops: const <double>[0.25, 0.5, 0.75],
              ),
            ),
            child: child,
          );
        },
      ),
    );
  }
}

class SkeletonLine extends StatelessWidget {
  const SkeletonLine({this.width, this.height = 14, super.key});

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(width: width, height: height);
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    this.width,
    this.height = 72,
    this.borderRadius = AppRadii.cardBorder,
    super.key,
  });

  final double? width;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      width: width,
      height: height,
      borderRadius: borderRadius,
    );
  }
}

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({this.height = 84, this.child, super.key});

  final double height;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadii.cardBorder,
          border: Border.all(
            color: context.palette.line,
            width: AppSizes.border,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: child ?? const AppSkeleton(height: double.infinity),
        ),
      ),
    );
  }
}

class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({this.height = 84, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SkeletonCard(
      height: height,
      child: Row(
        children: <Widget>[
          const AppSkeleton(
            width: 44,
            height: 44,
            borderRadius: AppRadii.pillBorder,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const <Widget>[
                SkeletonLine(width: 160),
                SizedBox(height: AppSpacing.sm),
                SkeletonLine(width: 100, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({
    this.count = 3,
    this.itemHeight = 84,
    this.spacing = AppSpacing.md,
    this.tile = true,
    this.keyPrefix,
    super.key,
  });

  final int count;
  final double itemHeight;
  final double spacing;
  final bool tile;
  final String? keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int index = 0; index < count; index++) ...<Widget>[
          if (tile)
            SkeletonListTile(
              key: keyPrefix == null ? null : Key('${keyPrefix}_$index'),
              height: itemHeight,
            )
          else
            SkeletonCard(
              key: keyPrefix == null ? null : Key('${keyPrefix}_$index'),
              height: itemHeight,
            ),
          if (index < count - 1) SizedBox(height: spacing),
        ],
      ],
    );
  }
}
