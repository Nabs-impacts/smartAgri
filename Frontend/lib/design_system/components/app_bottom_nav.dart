import 'package:flutter/material.dart';

import '../../core/haptics/app_haptics.dart';
import '../app_motion.dart';
import '../app_palette.dart';
import '../tokens.dart';
import 'app_pressable.dart';

class AppNavItem {
  const AppNavItem({
    required this.icon,
    required this.label,
    this.selectedIcon,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String label;
}

class AppNavAction {
  const AppNavAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.centralAction,
    this.centralIndex,
    super.key,
  });

  final List<AppNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final AppNavAction? centralAction;
  final int? centralIndex;

  int get _center {
    final int value = centralIndex ?? items.length ~/ 2;
    return value.clamp(0, items.length);
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool hasAction = centralAction != null;
    final double height = hasAction
        ? AppSizes.navHeight + AppSizes.navOverhang
        : AppSizes.navHeight;
    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: AppSizes.navHeight,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: palette.isDark ? palette.surfaceHigh : palette.surface,
                borderRadius: AppRadii.pillBorder,
                boxShadow: palette.lowShadows,
              ),
              child: Row(children: _slots(context)),
            ),
          ),
          if (centralAction != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(child: _action(context, centralAction!)),
            ),
        ],
      ),
    );
  }

  List<Widget> _slots(BuildContext context) {
    final List<Widget> slots = <Widget>[];
    for (int index = 0; index < items.length; index++) {
      if (centralAction != null && index == _center) {
        slots.add(const Expanded(child: SizedBox.shrink()));
      }
      slots.add(_item(context, index));
    }
    if (centralAction != null && _center >= items.length) {
      slots.add(const Expanded(child: SizedBox.shrink()));
    }
    return slots;
  }

  Widget _item(BuildContext context, int index) {
    final AppNavItem item = items[index];
    final bool selected = index == selectedIndex;
    final AppPalette palette = context.palette;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: item.label,
        excludeSemantics: true,
        child: AppPressable(
          key: ValueKey<String>('app_bottom_nav_$index'),
          borderRadius: AppRadii.pillBorder,
          haptics: AppHapticType.tap,
          onTap: () => onSelected(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                AnimatedContainer(
                  duration: AppMotion.fastFor(context),
                  width: AppSizes.navPillWidth,
                  height: AppSizes.navPillHeight,
                  decoration: BoxDecoration(
                    color: selected
                        ? palette.primaryContainer
                        : Colors.transparent,
                    borderRadius: AppRadii.pillBorder,
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: AppMotion.fastFor(context),
                      switchInCurve: AppMotion.enter,
                      switchOutCurve: AppMotion.exit,
                      child: Icon(
                        selected ? (item.selectedIcon ?? item.icon) : item.icon,
                        key: ValueKey<bool>(selected),
                        color: selected
                            ? palette.onPrimaryContainer
                            : palette.muted,
                        size: AppSizes.icon,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? palette.primary : palette.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _action(BuildContext context, AppNavAction action) {
    final AppPalette palette = context.palette;
    return Semantics(
      button: true,
      label: action.label,
      excludeSemantics: true,
      child: AppPressable(
        key: const ValueKey<String>('app_bottom_nav_scan'),
        borderRadius: AppRadii.pillBorder,
        customBorder: const CircleBorder(),
        haptics: AppHapticType.confirm,
        onTap: action.onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: AppSizes.navAction,
              height: AppSizes.navAction,
              decoration: BoxDecoration(
                color: palette.primary,
                shape: BoxShape.circle,
                boxShadow: palette.mediumShadows,
              ),
              child: Icon(action.icon, color: palette.onPrimary, size: 28),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              action.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: palette.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
