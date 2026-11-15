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
      AppNavItem(
        icon: AppIcons.home,
        selectedIcon: AppIcons.homeFill,
        label: strings.navHome,
      ),
      AppNavItem(
        icon: AppIcons.farm,
        selectedIcon: AppIcons.farmFill,
        label: strings.navFarms,
      ),
      AppNavItem(
        icon: AppIcons.tips,
        selectedIcon: AppIcons.tipsFill,
        label: strings.navTips,
      ),
      AppNavItem(
        icon: AppIcons.more,
        selectedIcon: AppIcons.moreFill,
        label: strings.navMore,
      ),
    ];
    return PopScope(
      canPop: navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        navigationShell.goBranch(0);
      },
      child: Scaffold(
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
            centralAction: AppNavAction(
              icon: AppIcons.scan,
              label: strings.navScan,
              onPressed: () => context.push('/diagnostic/new'),
            ),
            onSelected: (int index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
          ),
        ),
      ),
    );
  }
}
