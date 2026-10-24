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
import '../../../design_system/components/app_text_button.dart';
import '../../../design_system/tokens.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/admin_area.dart';
import '../data/farms_providers.dart';
import '../domain/farm.dart';
import 'farm_display.dart';

class FarmsPage extends ConsumerWidget {
  const FarmsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    final AsyncValue<List<Farm>> farms = ref.watch(farmsProvider);
    final List<AdminArea> areas =
        ref.watch(adminAreasProvider).value ?? <AdminArea>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(strings.farmsTitle)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(farmsProvider.notifier).refresh(),
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
                  icon: const Icon(Icons.add),
                  onPressed: () => context.go('/farms/new'),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (farms.isLoading && farms.value == null)
                ..._skeleton()
              else if (farms.hasError && farms.value == null)
                _error(context, ref, strings, farms.error)
              else if ((farms.value ?? <Farm>[]).isEmpty)
                AppCard(
                  child: Text(
                    strings.farmsEmpty,
                    key: const Key('farms_empty'),
                    style: AppTextStyles.body.copyWith(color: AppColors.muted),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                for (final Farm farm in farms.value!) ...<Widget>[
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

  List<Widget> _skeleton() {
    return <Widget>[
      for (int index = 0; index < 3; index++) ...<Widget>[
        Container(
          height: 84,
          decoration: const BoxDecoration(
            color: AppColors.inputFill,
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
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.agriculture_outlined,
                color: AppColors.primary,
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
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.muted,
              size: AppSizes.icon,
            ),
          ],
        ),
      ),
    );
  }
}
