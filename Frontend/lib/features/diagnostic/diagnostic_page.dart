import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/strings_provider.dart';
import '../../design_system/tokens.dart';

class DiagnosticPage extends ConsumerWidget {
  const DiagnosticPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              strings.diagnosticComingSoon,
              style: AppTextStyles.title,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
