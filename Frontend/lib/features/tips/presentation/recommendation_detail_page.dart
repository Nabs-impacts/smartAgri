import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/strings_provider.dart';
import '../../../design_system/app_icons.dart';
import '../../../design_system/app_palette.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/app_skeleton.dart';
import '../../../design_system/components/app_staggered_entrance.dart';
import '../../../design_system/components/app_text_button.dart';
import '../../../design_system/tokens.dart';
import '../../diagnostics/domain/recommendation_info.dart';
import '../../diagnostics/presentation/recommendation_feedback.dart';
import '../data/recommendations_provider.dart';
import '../domain/recommendation.dart';

class RecommendationDetailPage extends ConsumerWidget {
  const RecommendationDetailPage({required this.recommendationId, super.key});

  final String recommendationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    final AsyncValue<Recommendation> recommendation = ref.watch(
      recommendationProvider(recommendationId),
    );
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(title: Text(strings.tipsDetailTitle)),
      body: SafeArea(
        child: recommendation.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: SkeletonList(
              count: 4,
              itemHeight: 64,
              tile: false,
              keyPrefix: 'recommendation_detail_skeleton',
            ),
          ),
          error: (Object error, StackTrace stack) => _ErrorView(
            strings: strings,
            onRetry: () =>
                ref.invalidate(recommendationProvider(recommendationId)),
          ),
          data: (Recommendation data) {
            if (!data.isPublished) {
              return _ErrorView(
                strings: strings,
                onRetry: () =>
                    ref.invalidate(recommendationProvider(recommendationId)),
              );
            }
            return _DetailContent(strings: strings, recommendation: data);
          },
        ),
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({required this.strings, required this.recommendation});

  final AppLocalizations strings;
  final Recommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final List<RecommendationStep> steps = recommendation.steps;
    return ListView(
      key: const Key('recommendation_detail_scroll'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        AppStaggeredEntrance(
          children: <Widget>[
            Text(
              recommendation.title,
              key: const Key('recommendation_detail_title'),
              style: AppTextStyles.display,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              DateFormat('d MMM y', 'fr').format(recommendation.createdAt),
              key: const Key('recommendation_detail_date'),
              style: AppTextStyles.caption.copyWith(
                color: context.palette.muted,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              recommendation.body,
              key: const Key('recommendation_detail_body'),
              style: AppTextStyles.body,
            ),
            if (steps.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              for (int index = 0; index < steps.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: context.palette.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: AppTextStyles.caption.copyWith(
                            color: context.palette.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          steps[index].text,
                          key: Key('recommendation_step_$index'),
                          style: AppTextStyles.body,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (recommendation.diagnosticId != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: AppTextButton(
                  key: const Key('recommendation_see_diagnostic'),
                  label: strings.tipsSeeDiagnostic,
                  onPressed: () => context.push(
                    '/diagnostic/${recommendation.diagnosticId}',
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            RecommendationFeedbackPanel(
              recommendationId: recommendation.id,
              keyPrefix: 'recommendation',
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  AppIcons.warning,
                  size: AppSizes.icon,
                  color: context.palette.muted,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    strings.diagnosticTechnician,
                    key: const Key('recommendation_technician'),
                    style: AppTextStyles.caption.copyWith(
                      color: context.palette.muted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.strings, required this.onRetry});

  final AppLocalizations strings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: AppCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                  key: const Key('recommendation_retry'),
                  label: strings.retry,
                  onPressed: onRetry,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
