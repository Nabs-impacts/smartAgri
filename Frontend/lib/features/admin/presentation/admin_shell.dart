import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/strings_provider.dart';
import '../../../design_system/components/app_bottom_nav.dart';
import '../../../design_system/tokens.dart';
import '../../profile/data/me_repository.dart';

class AdminShell extends ConsumerWidget {
  const AdminShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(meProvider);
    final AppLocalizations strings = ref.watch(stringsProvider);
    final List<AppNavItem> items = <AppNavItem>[
      AppNavItem(
        icon: Icons.dashboard_outlined,
        label: strings.adminNavOverview,
      ),
      AppNavItem(icon: Icons.bar_chart, label: strings.adminNavYields),
      AppNavItem(icon: Icons.person_outline, label: strings.navProfile),
    ];
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(AppSpacing.lg),
        child: AppBottomNav(
          items: items,
          selectedIndex: navigationShell.currentIndex,
          onSelected: (int index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
        ),
      ),
    );
  }
}
