import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/strings_provider.dart';
import '../../../core/network/api_error_messages.dart';
import '../../../core/network/api_exception.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/app_error_banner.dart';
import '../../../design_system/components/app_text_field.dart';
import '../../../design_system/tokens.dart';
import '../data/privacy_repository.dart';

class DeleteAccountPage extends ConsumerStatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  ConsumerState<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends ConsumerState<DeleteAccountPage> {
  final TextEditingController _confirmation = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  bool get _canDelete =>
      _confirmation.text == PrivacyRepository.deleteConfirmation;

  Future<void> _delete() async {
    FocusScope.of(context).unfocus();
    final AppLocalizations strings = ref.read(stringsProvider);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(privacyRepositoryProvider)
          .deleteAccount(_confirmation.text);
      messenger.showSnackBar(
        SnackBar(content: Text(strings.privacyDeleteSuccess)),
      );
      if (mounted) {
        context.go('/login');
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error =
              error.code == PrivacyRepository.ownerConflictCode ||
                  error.statusCode == 409
              ? error.message
              : apiErrorMessage(error, strings);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = strings.privacyDeleteError);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = ref.watch(stringsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(strings.privacyDeleteTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: <Widget>[
            _warningCard(strings),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              key: const Key('privacy_delete_field'),
              controller: _confirmation,
              hintText: strings.privacyDeleteFieldLabel,
              enabled: !_submitting,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              AppErrorBanner(
                key: const Key('privacy_delete_error'),
                message: _error!,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              key: const Key('privacy_delete_confirm'),
              label: strings.privacyDeleteConfirm,
              variant: AppButtonVariant.inverted,
              loading: _submitting,
              onPressed: _canDelete && !_submitting ? _delete : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _warningCard(AppLocalizations strings) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.danger,
                size: AppSizes.icon,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  strings.privacyDeleteErasedTitle,
                  style: AppTextStyles.title,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _bullet(strings.privacyDeleteErasedIdentity),
          _bullet(strings.privacyDeleteErasedMedia),
          _bullet(strings.privacyDeleteErasedFinal),
          const SizedBox(height: AppSpacing.lg),
          const Divider(color: AppColors.line),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              const Icon(
                Icons.lock_outline,
                color: AppColors.primary,
                size: AppSizes.icon,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  strings.privacyDeleteKeptTitle,
                  style: AppTextStyles.title,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(strings.privacyDeleteKeptStats, style: AppTextStyles.body),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.sm),
            child: Icon(Icons.circle, size: 6, color: AppColors.muted),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}
