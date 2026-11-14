import 'package:flutter/material.dart';

import '../app_motion.dart';
import '../tokens.dart';

class AppStaggeredEntrance extends StatefulWidget {
  const AppStaggeredEntrance({
    required this.children,
    this.maxItems = 8,
    this.delay = const Duration(milliseconds: 30),
    this.spacing = AppSpacing.md,
    super.key,
  });

  final List<Widget> children;
  final int maxItems;
  final Duration delay;
  final double spacing;

  @override
  State<AppStaggeredEntrance> createState() => _AppStaggeredEntranceState();
}

class _AppStaggeredEntranceState extends State<AppStaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;

  int get _animatedCount => widget.children.length < widget.maxItems
      ? widget.children.length
      : widget.maxItems;

  Duration get _duration {
    final int steps = _animatedCount <= 0 ? 0 : _animatedCount - 1;
    return AppMotion.medium + widget.delay * steps;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    if (AppMotion.animationsDisabled(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _item(BuildContext context, Widget child, int index) {
    if (index >= _animatedCount) {
      return child;
    }
    final int steps = _animatedCount - 1;
    final double start = steps <= 0 ? 0 : index / (steps + 1);
    final double end = steps <= 0 ? 1 : (index + 1) / (steps + 1);
    final Animation<double> animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: AppMotion.enter),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (
          int index = 0;
          index < widget.children.length;
          index++
        ) ...<Widget>[
          _item(context, widget.children[index], index),
          if (index < widget.children.length - 1)
            SizedBox(height: widget.spacing),
        ],
      ],
    );
  }
}
