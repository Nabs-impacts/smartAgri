import 'package:flutter/material.dart';

import '../tokens.dart';
import '../app_palette.dart';

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
    return Container(
      height: AppSizes.navHeight,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: AppRadii.pillBorder,
        boxShadow: AppShadows.card,
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
                    width: AppSizes.navCircle,
                    height: AppSizes.navCircle,
                    decoration: BoxDecoration(
                      color: selected
                          ? context.palette.primary
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      item.icon,
                      color: selected
                          ? context.palette.onPrimary
                          : context.palette.muted,
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
