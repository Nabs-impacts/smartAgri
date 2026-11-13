import 'package:flutter/material.dart';

import '../app_palette.dart';
import '../tokens.dart';

class AppNavItem {
  const AppNavItem({required this.icon, required this.label});

  final IconData icon;
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
    return Container(
      height: AppSizes.navHeight,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.isDark ? palette.surfaceHigh : palette.surface,
        borderRadius: AppRadii.pillBorder,
        boxShadow: palette.lowShadows,
      ),
      child: Row(
        children: List<Widget>.generate(items.length, (int index) {
          final AppNavItem item = items[index];
          final bool selected = index == selectedIndex;
          return Expanded(
            child: Semantics(
              button: true,
              selected: selected,
              label: item.label,
              child: InkWell(
                key: ValueKey<String>('app_bottom_nav_$index'),
                borderRadius: AppRadii.pillBorder,
                onTap: () => onSelected(index),
                child: Center(
                  child: AnimatedContainer(
                    duration: AppDurations.fast,
                    width: AppSizes.navIndicator,
                    height: AppSizes.navIndicator,
                    decoration: BoxDecoration(
                      color: selected
                          ? palette.primaryContainer
                          : Colors.transparent,
                      borderRadius: AppRadii.pillBorder,
                    ),
                    child: Icon(
                      item.icon,
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
    );
  }
}
