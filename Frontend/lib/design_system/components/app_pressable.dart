import 'package:flutter/material.dart';

import '../../core/haptics/app_haptics.dart';
import '../app_motion.dart';
import '../tokens.dart';

class AppPressable extends StatefulWidget {
  const AppPressable({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.haptics = AppHapticType.none,
    this.semanticLabel,
    this.borderRadius,
    this.customBorder,
    this.pressedScale = 0.97,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final AppHapticType haptics;
  final String? semanticLabel;
  final BorderRadius? borderRadius;
  final ShapeBorder? customBorder;
  final double pressedScale;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _pressed = false;

  bool get _interactive => widget.enabled && widget.onTap != null;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) {
      return;
    }
    setState(() => _pressed = value);
  }

  void _handleTap() {
    if (!_interactive) {
      return;
    }
    AppHaptics.trigger(widget.haptics);
    widget.onTap!();
  }

  void _handleLongPress() {
    if (!_interactive) {
      return;
    }
    AppHaptics.trigger(widget.haptics);
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = AnimatedScale(
      scale: _pressed && AppMotion.animationsDisabled(context) == false
          ? widget.pressedScale
          : 1,
      duration: AppMotion.fastFor(context),
      curve: AppMotion.press,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: AppSizes.touchTarget,
          minHeight: AppSizes.touchTarget,
        ),
        child: InkWell(
          onTap: _interactive ? _handleTap : null,
          onLongPress: widget.onLongPress != null && _interactive
              ? _handleLongPress
              : null,
          onHighlightChanged: (bool value) => _setPressed(value),
          borderRadius: widget.borderRadius,
          customBorder: widget.customBorder,
          child: widget.child,
        ),
      ),
    );
    if (widget.semanticLabel == null) {
      return content;
    }
    return Semantics(
      button: true,
      enabled: _interactive,
      label: widget.semanticLabel,
      child: content,
    );
  }
}
