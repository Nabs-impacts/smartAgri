import 'package:flutter/material.dart';

import '../app_motion.dart';

class AppCountUp extends StatelessWidget {
  const AppCountUp({
    required this.value,
    required this.format,
    this.style,
    this.duration = const Duration(milliseconds: 600),
    this.textAlign,
    super.key,
  });

  final num value;
  final String Function(num value) format;
  final TextStyle? style;
  final Duration duration;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: AppMotion.duration(context, duration),
      curve: AppMotion.enter,
      builder: (BuildContext context, double current, Widget? child) {
        return Text(
          format(value is int ? current.round() : current),
          style: style,
          textAlign: textAlign,
        );
      },
    );
  }
}
