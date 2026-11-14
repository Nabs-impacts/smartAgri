import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/i18n/language_controller.dart';
import '../../../design_system/app_palette.dart';
import '../../../design_system/components/gonata_logo.dart';
import '../../../design_system/components/language_switcher.dart';
import '../../../design_system/tokens.dart';

enum AuthLogoStyle { full, symbol }

class AuthScaffold extends ConsumerWidget {
  const AuthScaffold({
    required this.child,
    this.logoStyle = AuthLogoStyle.full,
    super.key,
  });

  final Widget child;
  final AuthLogoStyle logoStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLanguage language = ref.watch(languageControllerProvider);
    final bool keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final double fullLogoWidth = keyboardOpen ? 132 : 196;
    final double symbolSize = keyboardOpen ? 48 : 72;

    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - AppSpacing.xxl)
                      .clamp(0, double.infinity)
                      .toDouble(),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Align(
                          alignment: Alignment.topRight,
                          child: LanguageSwitcher(
                            value: language,
                            onChanged: (AppLanguage value) => ref
                                .read(languageControllerProvider.notifier)
                                .set(value),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Center(
                          child: logoStyle == AuthLogoStyle.full
                              ? GonataLogo.full(width: fullLogoWidth)
                              : GonataLogo.symbol(size: symbolSize),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        child,
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
