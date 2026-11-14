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

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<AppNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final double alignment = items.isEmpty
        ? 0
        : (((selectedIndex + 0.5) / items.length) * 2) - 1;
    return Container(
      height: AppSizes.navHeight,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.isDark ? palette.surfaceHigh : palette.surface,
        borderRadius: AppRadii.pillBorder,
        boxShadow: palette.lowShadows,
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: AnimatedAlign(
              alignment: Alignment(alignment, 0),
              duration: AppMotion.fastFor(context),
              curve: AppMotion.enter,
              child: SizedBox(
                width: AppSizes.navIndicator,
                height: AppSizes.navIndicator,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.primaryContainer,
                    borderRadius: AppRadii.pillBorder,
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: List<Widget>.generate(items.length, (int index) {
              final AppNavItem item = items[index];
              final bool selected = index == selectedIndex;
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: item.label,
                  child: AppPressable(
                    key: ValueKey<String>('app_bottom_nav_$index'),
                    borderRadius: AppRadii.pillBorder,
                    haptics: AppHapticType.tap,
                    onTap: () => onSelected(index),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: AppMotion.fastFor(context),
                        switchInCurve: AppMotion.enter,
                        switchOutCurve: AppMotion.exit,
                        child: Icon(
                          selected
                              ? (item.selectedIcon ?? item.icon)
                              : item.icon,
                          key: ValueKey<bool>(selected),
                          color: selected
                              ? palette.onPrimaryContainer
                              : palette.muted,
                          size: AppSizes.icon,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
