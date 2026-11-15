import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../design_system/components/app_text_button.dart';
import '../../auth/data/auth_repository.dart';

Future<void> confirmLogout(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations strings,
) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text(strings.profileLogout),
        content: Text(strings.profileLogoutMessage),
        actions: <Widget>[
          AppTextButton(
            key: const Key('profile_logout_cancel'),
            label: strings.profileLogoutCancel,
            variant: AppTextButtonVariant.muted,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          AppTextButton(
            key: const Key('profile_logout_confirm'),
            label: strings.profileLogout,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      );
    },
  );
  if (confirmed == true) {
    await ref.read(authRepositoryProvider).logout();
  }
}
