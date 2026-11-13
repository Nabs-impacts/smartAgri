import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/strings_provider.dart';
import '../../../core/network/api_error_messages.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/sync/sync_providers.dart';
import '../../../core/sync/sync_status.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/app_error_banner.dart';
import '../../../design_system/components/app_text_button.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/app_palette.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/admin_area.dart';
import '../data/farms_providers.dart';
import '../domain/farm.dart';
import 'farm_display.dart';
import '../../../design_system/app_icons.dart';

class FarmsPage extends ConsumerWidget {
  const FarmsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    final AsyncValue<List<Farm>> farms = ref.watch(farmsProvider);
    final SyncSnapshot sync = ref.watch(syncStatusProvider);
    final List<Farm> farmsValue = farms.value ?? const <Farm>[];
    final bool firstSyncLoading =
        farmsValue.isEmpty &&
        sync.lastSyncAt == null &&
        sync.status != SyncStatus.offline;
    final List<AdminArea> areas =
        ref.watch(adminAreasProvider).value ?? <AdminArea>[];

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(title: Text(strings.farmsTitle)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(syncRunnerProvider)();
          },
          child: ListView(
            key: const Key('farms_scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            children: <Widget>[
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  key: const Key('farms_add'),
                  label: strings.farmAdd,
                  icon: const Icon(AppIcons.add),
                  onPressed: () => context.go('/farms/new'),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              if ((farms.isLoading && farms.value == null) || firstSyncLoading)
                ..._skeleton(context)
              else if (farms.hasError && farms.value == null)
                _error(context, ref, strings, farms.error)
              else if (farmsValue.isEmpty)
                AppCard(
                  child: Text(
                    strings.farmsEmpty,
                    key: const Key('farms_empty'),
                    style: AppTextStyles.body.copyWith(
                      color: context.palette.muted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                for (final Farm farm in farmsValue) ...<Widget>[
                  _FarmTile(
                    farm: farm,
                    region: farmRegionName(farm, areas),
                    onTap: () => context.go('/farms/${farm.id}'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _skeleton(BuildContext context) {
    return <Widget>[
      for (int index = 0; index < 3; index++) ...<Widget>[
        Container(
          key: Key('farms_skeleton_$index'),
          height: 84,
          decoration: BoxDecoration(
            color: context.palette.inputFill,
            borderRadius: AppRadii.cardBorder,
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
    final String message = error is ApiException
        ? apiErrorMessage(error, strings)
        : strings.errorGeneric;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppErrorBanner(message: message),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: AppTextButton(
            key: const Key('farms_retry'),
            label: strings.retry,
            onPressed: () => ref.read(farmsProvider.notifier).refresh(),
          ),
        ),
      ],
    );
  }
}

class _FarmTile extends StatelessWidget {
  const _FarmTile({
    required this.farm,
    required this.region,
    required this.onTap,
  });

  final Farm farm;
  final String? region;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('farm_card_${farm.id}'),
      borderRadius: AppRadii.cardBorder,
      onTap: onTap,
      child: AppCard(
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.palette.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                AppIcons.harvest,
                color: context.palette.primary,
                size: AppSizes.icon,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(farm.name, style: AppTextStyles.title),
                  if (farm.village != null &&
                      farm.village!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Text(farm.village!, style: AppTextStyles.body),
                  ],
                  if (region != null && region!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      region!,
                      style: AppTextStyles.caption.copyWith(
                        color: context.palette.muted,
                      ),
                    ),
                  ],
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
}
