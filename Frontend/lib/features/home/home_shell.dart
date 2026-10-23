import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/strings_provider.dart';
import '../../design_system/components/app_bottom_nav.dart';
import '../../design_system/tokens.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    final List<AppNavItem> items = <AppNavItem>[
      AppNavItem(icon: Icons.home_outlined, label: strings.navHome),
      AppNavItem(icon: Icons.search, label: strings.navSearch),
      AppNavItem(icon: Icons.person_outline, label: strings.navProfile),
    ];
    final List<String> titles = <String>[
      strings.navHome,
      strings.navSearch,
      strings.navProfile,
    ];
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Text(titles[_index], style: AppTextStyles.headline),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(AppSpacing.lg),
        child: AppBottomNav(
          items: items,
          selectedIndex: _index,
          onSelected: (int index) => setState(() => _index = index),
        ),
      ),
    );
  }
}
