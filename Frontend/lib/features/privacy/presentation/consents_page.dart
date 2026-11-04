import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/strings_provider.dart';
import '../../../core/network/api_exception.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/app_error_banner.dart';
import '../../../design_system/components/app_text_button.dart';
import '../../../design_system/tokens.dart';
import '../../auth/domain/consent_choice.dart';
import '../data/privacy_providers.dart';
import '../data/privacy_repository.dart';

class ConsentsPage extends ConsumerStatefulWidget {
  const ConsentsPage({super.key});

  @override
  ConsumerState<ConsentsPage> createState() => _ConsentsPageState();
}

class _ConsentsPageState extends ConsumerState<ConsentsPage> {
  String? _updateError;

  ConsentRecord? _record(List<ConsentRecord> records, ConsentType type) {
    for (final ConsentRecord record in records) {
      if (record.type == type) {
        return record;
      }
    }
    return null;
  }

  Future<void> _set(ConsentType type, bool accepted) async {
    final AppLocalizations strings = ref.read(stringsProvider);
    setState(() => _updateError = null);
    try {
      await ref.read(consentsProvider.notifier).set(type, accepted);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _updateError = error is ApiException
            ? error.message
            : strings.privacyConsentUpdateError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    final AsyncValue<List<ConsentRecord>> consents = ref.watch(
      consentsProvider,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(strings.profilePrivacyConsents)),
      body: SafeArea(
        child: consents.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stackTrace) => _error(strings),
          data: (List<ConsentRecord> records) => _content(strings, records),
        ),
      ),
    );
  }

  Widget _error(AppLocalizations strings) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: AppCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                strings.privacyConsentsLoadError,
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                key: const Key('privacy_retry'),
                label: strings.retry,
                onPressed: () => ref.invalidate(consentsProvider),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(AppLocalizations strings, List<ConsentRecord> records) {
    final ConsentRecord? terms = _record(records, ConsentType.terms);
    final ConsentRecord? privacy = _record(records, ConsentType.privacy);
    final ConsentRecord? dataSharing = _record(
      records,
      ConsentType.dataSharingGov,
    );
    final ConsentRecord? research = _record(records, ConsentType.research);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: <Widget>[
        if (_updateError != null) ...<Widget>[
          AppErrorBanner(
            key: const Key('privacy_update_error'),
            message: _updateError!,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        _ReadOnlyRow(
          key: const Key('privacy_terms'),
          title: strings.legalTermsTitle,
          accepted: terms?.accepted ?? false,
          acceptedLabel: strings.privacyAccepted,
          rejectedLabel: strings.privacyNotAccepted,
          readKey: const Key('privacy_terms_read'),
          readLabel: strings.readAction,
          onRead: () => context.push('/legal/terms'),
        ),
        const SizedBox(height: AppSpacing.md),
        _ReadOnlyRow(
          key: const Key('privacy_policy'),
          title: strings.legalPrivacyTitle,
          accepted: privacy?.accepted ?? false,
          acceptedLabel: strings.privacyAccepted,
          rejectedLabel: strings.privacyNotAccepted,
          readKey: const Key('privacy_policy_read'),
          readLabel: strings.readAction,
          onRead: () => context.push('/legal/privacy'),
        ),
        const SizedBox(height: AppSpacing.md),
        _SwitchRow(
          key: const Key('privacy_data'),
          title: strings.privacyDataSharingLabel,
          value: dataSharing?.accepted ?? false,
          switchKey: const Key('privacy_data_switch'),
          onChanged: (bool value) => _set(ConsentType.dataSharingGov, value),
        ),
        const SizedBox(height: AppSpacing.md),
        _SwitchRow(
          key: const Key('privacy_research'),
          title: strings.privacyResearchLabel,
          value: research?.accepted ?? false,
          switchKey: const Key('privacy_research_switch'),
          onChanged: (bool value) => _set(ConsentType.research, value),
        ),
      ],
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({
    required this.title,
    required this.accepted,
    required this.acceptedLabel,
    required this.rejectedLabel,
    required this.readKey,
    required this.readLabel,
    required this.onRead,
    super.key,
  });

  final String title;
  final bool accepted;
  final String acceptedLabel;
  final String rejectedLabel;
  final Key readKey;
  final String readLabel;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppTextStyles.body),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  accepted ? acceptedLabel : rejectedLabel,
                  style: AppTextStyles.caption.copyWith(
                    color: accepted ? AppColors.primary : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          AppTextButton(
            key: readKey,
            label: readLabel,
            variant: AppTextButtonVariant.muted,
            onPressed: onRead,
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.switchKey,
    required this.onChanged,
    super.key,
  });

  final String title;
  final bool value;
  final Key switchKey;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(title, style: AppTextStyles.body)),
          Switch(
            key: switchKey,
            value: value,
            activeThumbColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
