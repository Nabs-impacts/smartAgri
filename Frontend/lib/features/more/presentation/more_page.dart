import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/haptics/app_haptics.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/strings_provider.dart';
import '../../../core/network/api_error_messages.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/phone/niger_phone.dart';
import '../../../core/sync/sync_providers.dart';
import '../../../core/sync/sync_status.dart';
import '../../../design_system/app_icons.dart';
import '../../../design_system/app_palette.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/app_pressable.dart';
import '../../../design_system/components/app_skeleton.dart';
import '../../../design_system/components/app_tab_header.dart';
import '../../../design_system/tokens.dart';
import '../../profile/data/me_repository.dart';
import '../../profile/presentation/logout_dialog.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    final AsyncValue<MeData?> me = ref.watch(meProvider);
    final SyncSnapshot sync = ref.watch(syncStatusProvider);
    final MeData? data = me.value;
    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: ListView(
          key: const Key('more_scroll'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          children: <Widget>[
            AppTabHeader(title: strings.moreTitle),
            if (data != null)
              _AccountCard(
                name: data.user.fullName,
                phone: data.user.phone,
                onTap: () => context.push('/profile'),
              )
            else if (me.hasError)
              AppCard(
                child: Column(
                  children: <Widget>[
                    Text(
                      me.error is ApiException
                          ? apiErrorMessage(me.error! as ApiException, strings)
                          : strings.errorGeneric,
                      style: AppTextStyles.body,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppPressable(
                      key: const Key('more_account_retry'),
                      borderRadius: AppRadii.smallBorder,
                      haptics: AppHapticType.tap,
                      onTap: () => ref.read(meProvider.notifier).refresh(),
                      child: Text(
                        strings.retry,
                        style: AppTextStyles.label.copyWith(
                          color: context.palette.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              const AppCard(child: AppSkeleton(height: 56)),
            const SizedBox(height: AppSpacing.xl),
            _MoreRow(
              key: const Key('more_diagnostics'),
              icon: AppIcons.history,
              title: strings.moreDiagnostics,
              onTap: () => context.push('/diagnostics'),
            ),
            const SizedBox(height: AppSpacing.md),
            _MoreRow(
              key: const Key('more_sync'),
              icon: AppIcons.sync,
              title: strings.moreSync,
              subtitle: _syncLabel(strings, sync),
              onTap: () {
                if (sync.failedCount > 0) {
                  context.push('/sync/failed');
                  return;
                }
                ref.read(syncRunnerProvider)();
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _MoreRow(
              key: const Key('more_privacy'),
              icon: AppIcons.privacy,
              title: strings.morePrivacy,
              onTap: () => context.push('/privacy/consents'),
            ),
            const SizedBox(height: AppSpacing.md),
            _MoreRow(
              key: const Key('more_terms'),
              icon: AppIcons.note,
              title: strings.moreTerms,
              onTap: () => context.push('/legal/terms'),
            ),
            const SizedBox(height: AppSpacing.md),
            _MoreRow(
              key: const Key('more_privacy_policy'),
              icon: AppIcons.lock,
              title: strings.morePrivacyPolicy,
              onTap: () => context.push('/legal/privacy'),
            ),
            const SizedBox(height: AppSpacing.xl),
            _MoreRow(
              key: const Key('more_logout'),
              icon: AppIcons.signOut,
              title: strings.profileLogout,
              danger: true,
              onTap: () => confirmLogout(context, ref, strings),
            ),
          ],
        ),
      ),
    );
  }

  String _syncLabel(AppLocalizations strings, SyncSnapshot snapshot) {
    if (snapshot.failedCount > 0) {
      return strings.moreSyncFailed(snapshot.failedCount);
    }
    if (snapshot.status == SyncStatus.offline) {
      return strings.moreSyncOffline;
    }
    if (snapshot.pendingCount > 0) {
      return strings.moreSyncPending(snapshot.pendingCount);
    }
    return strings.moreSyncUpToDate;
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.name,
    required this.phone,
    required this.onTap,
  });

  final String name;
  final String phone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      key: const Key('more_account'),
      borderRadius: AppRadii.cardBorder,
      haptics: AppHapticType.tap,
      onTap: onTap,
      child: AppCard(
        child: Row(
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.palette.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Text(
                _initials(name),
                key: const Key('more_account_initials'),
                style: AppTextStyles.title.copyWith(
                  color: context.palette.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    style: AppTextStyles.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _maskedPhone(phone),
                    key: const Key('more_account_phone'),
                    style: AppTextStyles.caption.copyWith(
                      color: context.palette.muted,
                    ),
                  ),
                ],
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
    );
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
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  String _maskedPhone(String phone) {
    final String? normalized = NigerPhone.normalize(phone);
    if (normalized == null) {
      return phone;
    }
    final List<String> groups = NigerPhone.format(normalized).split(' ');
    if (groups.length < 3) {
      return '+227 ${NigerPhone.format(normalized)}';
    }
    final String hidden = List<String>.filled(
      groups.length - 2,
      '••',
    ).join(' ');
    return '+227 ${groups.first} $hidden ${groups.last}';
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.danger = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? subtitle;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color color = danger
        ? context.palette.danger
        : context.palette.primary;
    return AppPressable(
      borderRadius: AppRadii.cardBorder,
      haptics: AppHapticType.tap,
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            Icon(icon, color: color, size: AppSizes.icon),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: AppTextStyles.label.copyWith(
                      color: danger
                          ? context.palette.danger
                          : context.palette.ink,
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle!,
                      style: AppTextStyles.caption.copyWith(
                        color: context.palette.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!danger)
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
