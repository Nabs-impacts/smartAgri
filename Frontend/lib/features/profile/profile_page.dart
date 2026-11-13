import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_language.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/language_controller.dart';
import '../../core/i18n/strings_provider.dart';
import '../../core/network/api_error_messages.dart';
import '../../core/network/api_exception.dart';
import '../../core/phone/niger_phone.dart';
import '../../core/sync/sync_providers.dart';
import '../../core/sync/sync_status.dart';
import '../../core/theme/theme_mode_controller.dart';
import '../../design_system/components/app_button.dart';
import '../../design_system/components/app_card.dart';
import '../../design_system/components/app_choice_chips.dart';
import '../../design_system/components/app_progress_bar.dart';
import '../../design_system/components/app_text_button.dart';
import '../../design_system/components/language_switcher.dart';
import '../../design_system/tokens.dart';
import '../../design_system/app_palette.dart';
import '../auth/data/auth_repository.dart';
import '../auth/domain/user_profile.dart';
import '../privacy/data/data_exporter.dart';
import '../privacy/data/privacy_repository.dart';
import '../sync/sync_format.dart';
import 'data/me_repository.dart';
import '../../design_system/app_icons.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    final AsyncValue<MeData?> me = ref.watch(meProvider);
    final bool stale = ref.watch(meStaleProvider);
    final MeData? data = me.value;

    return Scaffold(
      backgroundColor: context.palette.background,
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
                ..._skeleton(context)
              else if (data == null && me.hasError)
                _error(context, ref, strings, me.error)
              else if (data != null) ...<Widget>[
                _header(context, strings, data.user),
                if (stale) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    strings.profileCachedData,
                    key: const Key('profile_cached'),
                    style: AppTextStyles.caption.copyWith(
                      color: context.palette.muted,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                _languageSection(ref, strings),
                if (!data.user.isAdmin) ...<Widget>[
                  const SizedBox(height: AppSpacing.xl),
                  _usageSection(context, strings, data.quotas),
                  const SizedBox(height: AppSpacing.xl),
                  InkWell(
                    key: const Key('profile_diagnostics'),
                    borderRadius: AppRadii.cardBorder,
                    onTap: () => context.go('/diagnostics'),
                    child: AppCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            AppIcons.plant,
                            color: context.palette.primary,
                            size: AppSizes.icon,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              strings.profileDiagnostics,
                              style: AppTextStyles.label,
                            ),
                          ),
                          Icon(
                            AppIcons.chevronRight,
                            color: context.palette.muted,
                            size: AppSizes.icon,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _PrivacySection(strings: strings),
                  const SizedBox(height: AppSpacing.xl),
                  _SyncSection(strings: strings),
                ],
                const SizedBox(height: AppSpacing.xl),
                _appearanceSection(ref, strings),
                const SizedBox(height: AppSpacing.lg),
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

  List<Widget> _skeleton(BuildContext context) {
    return <Widget>[
      Center(
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: context.palette.inputFill,
            shape: BoxShape.circle,
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      Center(
        child: Container(
          width: 160,
          height: 20,
          decoration: BoxDecoration(
            color: context.palette.inputFill,
            borderRadius: AppRadii.smallBorder,
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      for (int index = 0; index < 3; index++) ...<Widget>[
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: context.palette.inputFill,
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

  Widget _header(
    BuildContext context,
    AppLocalizations strings,
    UserProfile user,
  ) {
    return Column(
      children: <Widget>[
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.palette.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Text(
            _initials(user.fullName),
            key: const Key('profile_initials'),
            style: AppTextStyles.title.copyWith(color: context.palette.ink),
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
          style: AppTextStyles.body.copyWith(color: context.palette.muted),
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

  Widget _appearanceSection(WidgetRef ref, AppLocalizations strings) {
    final ThemeMode mode = ref.watch(themeModeControllerProvider);
    return Column(
      key: const Key('profile_appearance'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(strings.appearanceTitle, style: AppTextStyles.title),
        const SizedBox(height: AppSpacing.md),
        AppChoiceChips<ThemeMode>(
          options: <AppChoiceOption<ThemeMode>>[
            AppChoiceOption<ThemeMode>(
              value: ThemeMode.system,
              label: strings.appearanceSystem,
            ),
            AppChoiceOption<ThemeMode>(
              value: ThemeMode.light,
              label: strings.appearanceLight,
            ),
            AppChoiceOption<ThemeMode>(
              value: ThemeMode.dark,
              label: strings.appearanceDark,
            ),
          ],
          value: mode,
          onChanged: (ThemeMode value) =>
              ref.read(themeModeControllerProvider.notifier).set(value),
        ),
      ],
    );
  }

  Widget _usageSection(
    BuildContext context,
    AppLocalizations strings,
    List<Quota> quotas,
  ) {
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

class _SyncSection extends ConsumerWidget {
  const _SyncSection({required this.strings});

  final AppLocalizations strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SyncSnapshot snapshot = ref.watch(syncStatusProvider);
    final DateTime now = ref.watch(syncClockProvider)();
    final bool syncing = snapshot.status == SyncStatus.syncing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(strings.syncSectionTitle, style: AppTextStyles.title),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      strings.syncLastTitle,
                      style: AppTextStyles.body,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    formatLastSync(strings, snapshot.lastSyncAt, now),
                    key: const Key('profile_sync_last'),
                    style: AppTextStyles.caption.copyWith(
                      color: context.palette.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                strings.syncPendingCount(snapshot.pendingCount),
                key: const Key('profile_sync_pending'),
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.xs),
              InkWell(
                key: const Key('profile_sync_failed'),
                borderRadius: AppRadii.smallBorder,
                onTap: snapshot.failedCount > 0
                    ? () => context.push('/sync/failed')
                    : null,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        strings.syncFailedCount(snapshot.failedCount),
                        style: AppTextStyles.body.copyWith(
                          color: snapshot.failedCount > 0
                              ? context.palette.danger
                              : context.palette.ink,
                        ),
                      ),
                    ),
                    if (snapshot.failedCount > 0)
                      Icon(
                        AppIcons.chevronRight,
                        color: context.palette.danger,
                        size: AppSizes.icon,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  key: const Key('profile_sync_now'),
                  label: strings.syncNowButton,
                  loading: syncing,
                  onPressed: syncing
                      ? null
                      : () => ref.read(syncRunnerProvider)(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
                style: AppTextStyles.caption.copyWith(
                  color: context.palette.muted,
                ),
              ),
            ],
          ),
          if (ratio != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            AppProgressBar(value: ratio, color: _color(context, ratio)),
          ],
        ],
      ),
    );
  }

  Color _color(BuildContext context, double ratio) {
    if (ratio < 0.7) {
      return context.palette.tertiary;
    }
    if (ratio < 1) {
      return context.palette.secondary;
    }
    return context.palette.danger;
  }
}

class _PrivacySection extends ConsumerStatefulWidget {
  const _PrivacySection({required this.strings});

  final AppLocalizations strings;

  @override
  ConsumerState<_PrivacySection> createState() => _PrivacySectionState();
}

class _PrivacySectionState extends ConsumerState<_PrivacySection> {
  bool _exporting = false;

  Future<void> _export() async {
    if (_exporting) {
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _exporting = true);
    try {
      final DataExport export = await ref
          .read(privacyRepositoryProvider)
          .exportData();
      await ref
          .read(dataExporterProvider)
          .saveOrShare(export.bytes, export.fileName);
      messenger.showSnackBar(
        SnackBar(content: Text(widget.strings.privacyExportSuccess)),
      );
    } on ApiException catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(error, widget.strings))),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(widget.strings.privacyExportError)),
      );
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(widget.strings.profilePrivacyTitle, style: AppTextStyles.title),
        const SizedBox(height: AppSpacing.md),
        _PrivacyRow(
          key: const Key('profile_privacy_consents'),
          icon: AppIcons.privacy,
          label: widget.strings.profilePrivacyConsents,
          onTap: () => context.push('/privacy/consents'),
        ),
        const SizedBox(height: AppSpacing.md),
        _PrivacyRow(
          key: const Key('profile_privacy_export'),
          icon: AppIcons.download,
          label: widget.strings.profilePrivacyExport,
          onTap: _exporting ? null : _export,
          trailing: _exporting
              ? SizedBox(
                  width: AppSizes.loadingIndicator,
                  height: AppSizes.loadingIndicator,
                  child: CircularProgressIndicator(
                    strokeWidth: AppSizes.loadingStroke,
                    color: context.palette.primary,
                  ),
                )
              : null,
        ),
        const SizedBox(height: AppSpacing.md),
        _PrivacyRow(
          key: const Key('profile_privacy_delete'),
          icon: AppIcons.delete,
          label: widget.strings.profilePrivacyDelete,
          danger: true,
          onTap: () => context.push('/privacy/delete'),
        ),
      ],
    );
  }
}

class _PrivacyRow extends StatelessWidget {
  const _PrivacyRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final Color color = danger
        ? context.palette.danger
        : context.palette.primary;
    return InkWell(
      borderRadius: AppRadii.cardBorder,
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            Icon(icon, color: color, size: AppSizes.icon),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.label.copyWith(
                  color: danger ? context.palette.danger : context.palette.ink,
                ),
              ),
            ),
            trailing ??
                Icon(
                  AppIcons.chevronRight,
                  color: context.palette.muted,
                  size: AppSizes.icon,
                ),
          ],
        ),
      ),
    );
  }
}
