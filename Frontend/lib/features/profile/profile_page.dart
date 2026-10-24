import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_language.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/language_controller.dart';
import '../../core/i18n/strings_provider.dart';
import '../../core/network/api_exception.dart';
import '../../core/phone/niger_phone.dart';
import '../../design_system/components/app_button.dart';
import '../../design_system/components/app_card.dart';
import '../../design_system/components/app_progress_bar.dart';
import '../../design_system/components/app_text_button.dart';
import '../../design_system/components/language_switcher.dart';
import '../../design_system/tokens.dart';
import '../auth/data/auth_repository.dart';
import '../auth/domain/user_profile.dart';
import 'data/me_repository.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    final AsyncValue<MeData?> me = ref.watch(meProvider);
    final bool stale = ref.watch(meStaleProvider);
    final MeData? data = me.value;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(meProvider.notifier).refresh(),
          child: ListView(
            key: const Key('profile_scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            children: <Widget>[
              if (data == null && me.isLoading)
                ..._skeleton()
              else if (data == null && me.hasError)
                _error(context, ref, strings, me.error)
              else if (data != null) ...<Widget>[
                _header(strings, data.user),
                if (stale) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    strings.profileCachedData,
                    key: const Key('profile_cached'),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                _languageSection(ref, strings),
                const SizedBox(height: AppSpacing.xl),
                _usageSection(strings, data.quotas),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    key: const Key('profile_logout'),
                    label: strings.profileLogout,
                    variant: AppButtonVariant.outlined,
                    onPressed: () => _confirmLogout(context, ref, strings),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _skeleton() {
    return <Widget>[
      Center(
        child: Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: AppColors.inputFill,
            shape: BoxShape.circle,
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      Center(
        child: Container(
          width: 160,
          height: 20,
          decoration: const BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: AppRadii.smallBorder,
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      for (int index = 0; index < 3; index++) ...<Widget>[
        Container(
          height: 52,
          decoration: const BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: AppRadii.smallBorder,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    ];
  }

  Widget _error(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
    Object? error,
  ) {
    String message = strings.errorGeneric;
    if (error is ApiException) {
      message = error.isNetwork ? strings.errorNetwork : error.message;
    }
    return AppCard(
      child: Column(
        children: <Widget>[
          Text(message, style: AppTextStyles.body, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            key: const Key('profile_retry'),
            label: strings.retry,
            onPressed: () => ref.read(meProvider.notifier).refresh(),
          ),
        ],
      ),
    );
  }

  Widget _header(AppLocalizations strings, UserProfile user) {
    return Column(
      children: <Widget>[
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Text(
            _initials(user.fullName),
            key: const Key('profile_initials'),
            style: AppTextStyles.title.copyWith(color: AppColors.ink),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          user.fullName,
          style: AppTextStyles.title,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _formatPhone(user.phone),
          key: const Key('profile_phone'),
          style: AppTextStyles.body.copyWith(color: AppColors.muted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _languageSection(WidgetRef ref, AppLocalizations strings) {
    final AppLanguage language = ref.watch(languageControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(strings.profileLanguage, style: AppTextStyles.title),
        const SizedBox(height: AppSpacing.md),
        LanguageSwitcher(
          value: language,
          onChanged: (AppLanguage value) =>
              ref.read(languageControllerProvider.notifier).set(value),
        ),
      ],
    );
  }

  Widget _usageSection(AppLocalizations strings, List<Quota> quotas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(strings.profileUsage, style: AppTextStyles.title),
        const SizedBox(height: AppSpacing.md),
        for (final Quota quota in quotas)
          _QuotaRow(
            key: Key('profile_quota_${quota.metric}'),
            label: _quotaLabel(strings, quota.metric),
            quota: quota,
            strings: strings,
          ),
      ],
    );
  }

  String _quotaLabel(AppLocalizations strings, String metric) {
    switch (metric) {
      case 'plots':
        return strings.profileQuotaPlots;
      case 'diagnostics_per_month':
        return strings.profileQuotaDiagnostics;
      case 'storage_mb':
        return strings.profileQuotaStorage;
      case 'llm_messages_per_month':
        return strings.profileQuotaLlm;
      case 'video_analyses_per_month':
        return strings.profileQuotaVideo;
      default:
        return strings.profileQuotaUnknown(metric);
    }
  }

  String _initials(String fullName) {
    final List<String> parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    final String first = parts.first.substring(0, 1);
    final String last = parts.last.substring(0, 1);
    return '$first$last'.toUpperCase();
  }

  String _formatPhone(String phone) {
    final String? normalized = NigerPhone.normalize(phone);
    if (normalized == null) {
      return phone;
    }
    return '+227 ${NigerPhone.format(normalized)}';
  }

  Future<void> _confirmLogout(
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
}

class _QuotaRow extends StatelessWidget {
  const _QuotaRow({
    required this.label,
    required this.quota,
    required this.strings,
    super.key,
  });

  final String label;
  final Quota quota;
  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    final double? ratio = quota.isUnlimited
        ? null
        : quota.limit <= 0
        ? 1
        : quota.used / quota.limit;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(label, style: AppTextStyles.body)),
              const SizedBox(width: AppSpacing.sm),
              Text(
                ratio == null
                    ? strings.profileUnlimited
                    : '${quota.used} / ${quota.limit}',
                style: AppTextStyles.caption.copyWith(color: AppColors.muted),
              ),
            ],
          ),
          if (ratio != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            AppProgressBar(value: ratio, color: _color(ratio)),
          ],
        ],
      ),
    );
  }

  Color _color(double ratio) {
    if (ratio < 0.7) {
      return AppColors.tertiary;
    }
    if (ratio < 1) {
      return AppColors.secondary;
    }
    return AppColors.danger;
  }
}
