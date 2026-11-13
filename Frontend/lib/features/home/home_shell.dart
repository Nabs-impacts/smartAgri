import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/strings_provider.dart';
import '../../design_system/components/app_bottom_nav.dart';
import '../../design_system/tokens.dart';
import '../profile/data/me_repository.dart';
import '../sync/presentation/sync_banner.dart';
import '../../design_system/app_icons.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(meProvider);
    final AppLocalizations strings = ref.watch(stringsProvider);
    final List<AppNavItem> items = <AppNavItem>[
      AppNavItem(icon: AppIcons.home, label: strings.navHome),
      AppNavItem(icon: AppIcons.search, label: strings.navSearch),
      AppNavItem(icon: AppIcons.profile, label: strings.navProfile),
    ];
    return Scaffold(
      body: Column(
        children: <Widget>[
          const SyncBanner(),
          Expanded(child: navigationShell),
        ],
      ),
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
