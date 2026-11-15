import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/haptics/app_haptics.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/strings_provider.dart';
import '../../../design_system/app_icons.dart';
import '../../../design_system/app_palette.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/app_pressable.dart';
import '../../../design_system/components/app_skeleton.dart';
import '../../../design_system/components/app_staggered_entrance.dart';
import '../../../design_system/components/app_status_chip.dart';
import '../../../design_system/components/app_tab_header.dart';
import '../../../design_system/tokens.dart';
import '../data/recommendations_provider.dart';
import '../domain/recommendation.dart';

class TipsPage extends ConsumerWidget {
  const TipsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    final AsyncValue<RecommendationsState> recommendations = ref.watch(
      recommendationsProvider,
    );
    final RecommendationsState? state = recommendations.value;
    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(recommendationsProvider.notifier).refresh(),
          child: ListView(
            key: const Key('tips_scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            children: <Widget>[
              AppTabHeader(title: strings.tipsTitle),
              _SoonCard(strings: strings),
              const SizedBox(height: AppSpacing.xl),
              Text(
                strings.tipsRecommendationsTitle,
                style: AppTextStyles.title,
              ),
              const SizedBox(height: AppSpacing.md),
              if (state == null && recommendations.isLoading)
                const SkeletonList(
                  count: 3,
                  itemHeight: 104,
                  tile: false,
                  keyPrefix: 'tips_skeleton',
                )
              else if (state == null && recommendations.hasError)
                _ErrorView(
                  strings: strings,
                  onRetry: () =>
                      ref.read(recommendationsProvider.notifier).refresh(),
                )
              else
                _content(context, ref, strings, state!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
    RecommendationsState state,
  ) {
    if (state.items.isEmpty) {
      return AppCard(
        child: Column(
          children: <Widget>[
            Text(
              strings.tipsEmpty,
              key: const Key('tips_empty'),
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                key: const Key('tips_analyze'),
                label: strings.tipsAnalyze,
                onPressed: () => context.push('/diagnostic/new'),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppStaggeredEntrance(
          children: <Widget>[
            for (final Recommendation recommendation in state.items)
              _RecommendationRow(recommendation: recommendation),
          ],
        ),
        if (state.hasMore) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            key: const Key('tips_load_more'),
            label: strings.tipsLoadMore,
            variant: AppButtonVariant.outlined,
            loading: state.loadingMore,
            onPressed: state.loadingMore
                ? null
                : () => ref.read(recommendationsProvider.notifier).loadMore(),
          ),
        ],
      ],
    );
  }
}

class _SoonCard extends StatelessWidget {
  const _SoonCard({required this.strings});

  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('tips_soon_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                AppIcons.plant,
                color: context.palette.primary,
                size: AppSizes.icon,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(strings.tipsSoonTitle, style: AppTextStyles.title),
              ),
              AppStatusChip(label: strings.tipsSoonBadge),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            strings.tipsSoonBody,
            key: const Key('tips_soon_body'),
            style: AppTextStyles.body.copyWith(color: context.palette.muted),
          ),
        ],
      ),
    );
  }
}

class _RecommendationRow extends StatelessWidget {
  const _RecommendationRow({required this.recommendation});

  final Recommendation recommendation;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      key: Key('tips_row_${recommendation.id}'),
      borderRadius: AppRadii.cardBorder,
      haptics: AppHapticType.tap,
      onTap: () => context.push('/tips/${recommendation.id}'),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              recommendation.title,
              style: AppTextStyles.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              recommendation.body,
              style: AppTextStyles.body.copyWith(color: context.palette.muted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              formatRecommendationDate(recommendation.createdAt),
              key: Key('tips_date_${recommendation.id}'),
              style: AppTextStyles.caption.copyWith(
                color: context.palette.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.strings, required this.onRetry});

  final AppLocalizations strings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('tips_error'),
      child: Column(
        children: <Widget>[
          Text(
            strings.tipsOffline,
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              key: const Key('tips_retry'),
              label: strings.retry,
              onPressed: onRetry,
            ),
          ),
        ],
      ),
    );
  }
}

String formatRecommendationDate(DateTime value) {
  return DateFormat('d MMM y', 'fr').format(value);
}
