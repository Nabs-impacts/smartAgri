import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/strings_provider.dart';
import '../../../core/network/api_error_messages.dart';
import '../../../core/network/api_exception.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/app_error_banner.dart';
import '../../../design_system/components/app_logo.dart';
import '../../../design_system/components/app_photo_tile.dart';
import '../../../design_system/components/app_progress_bar.dart';
import '../../../design_system/components/app_status_chip.dart';
import '../../../design_system/tokens.dart';
import '../data/diagnostic_watcher.dart';
import '../data/diagnostics_repository.dart';
import '../domain/diagnostic.dart';
import '../domain/diagnostic_media.dart';
import '../domain/diagnostic_status.dart';
import '../domain/prediction.dart';
import '../domain/recommendation_info.dart';
import '../domain/severity.dart';

final Provider<bool> diagnosticDemoBannerProvider = Provider<bool>(
  (Ref ref) => AppConfig.diagnosticDemoBanner,
);

class DiagnosticResultPage extends ConsumerStatefulWidget {
  const DiagnosticResultPage({required this.diagnosticId, super.key});

  final String diagnosticId;

  @override
  ConsumerState<DiagnosticResultPage> createState() =>
      _DiagnosticResultPageState();
}

class _DiagnosticResultPageState extends ConsumerState<DiagnosticResultPage> {
  bool _feedbackSent = false;
  bool _feedbackSending = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    final AsyncValue<DiagnosticWatchState> watch = ref.watch(
      diagnosticWatchProvider(widget.diagnosticId),
    );
    final DiagnosticWatchState? state = watch.value;
    final Diagnostic? diagnostic = state?.diagnostic;
    final bool demo = ref.watch(diagnosticDemoBannerProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(strings.diagnosticResultTitle),
        actions: <Widget>[
          PopupMenuButton<String>(
            key: const Key('diagnostic_result_actions'),
            icon: const Icon(Icons.more_vert),
            onSelected: (String value) {
              if (value == 'delete') {
                _confirmDelete(strings);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'delete',
                child: Text(strings.diagnosticDelete),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          key: const Key('diagnostic_result_scroll'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          children: <Widget>[
            if (demo) ...<Widget>[
              _DemoBanner(
                key: const Key('diagnostic_demo_banner'),
                strings: strings,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (watch.hasError)
              _FailureView(
                strings: strings,
                error: watch.error,
                onRetry: _retry,
              )
            else if (state?.timedOut == true)
              _TimeoutView(
                strings: strings,
                onRefresh: () => ref
                    .read(diagnosticWatchProvider(widget.diagnosticId).notifier)
                    .resume(),
              )
            else if (diagnostic == null ||
                diagnostic.status == DiagnosticStatus.pending ||
                diagnostic.status == DiagnosticStatus.processing)
              _ProcessingView(strings: strings, diagnostic: diagnostic)
            else if (diagnostic.status == DiagnosticStatus.needsReview)
              _ExpertView(strings: strings, diagnostic: diagnostic)
            else if (diagnostic.status == DiagnosticStatus.failed)
              _FailureView(
                strings: strings,
                message: diagnostic.error,
                onRetry: _retry,
              )
            else
              _DoneView(
                strings: strings,
                diagnostic: diagnostic,
                feedbackSent: _feedbackSent,
                feedbackSending: _feedbackSending,
                onFeedback: _sendFeedback,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _retry() async {
    final DiagnosticWatchState? current = ref
        .read(diagnosticWatchProvider(widget.diagnosticId))
        .value;
    final Diagnostic? diagnostic = current?.diagnostic;
    if (diagnostic != null && diagnostic.status == DiagnosticStatus.failed) {
      try {
        await ref
            .read(diagnosticsRepositoryProvider)
            .retry(widget.diagnosticId);
      } on ApiException {
        return;
      }
    }
    ref.invalidate(diagnosticWatchProvider(widget.diagnosticId));
  }

  Future<void> _sendFeedback(bool helpful) async {
    if (_feedbackSent || _feedbackSending) {
      return;
    }
    final DiagnosticWatchState? current = ref
        .read(diagnosticWatchProvider(widget.diagnosticId))
        .value;
    final RecommendationInfo? recommendation =
        current?.diagnostic?.recommendation;
    if (recommendation == null) {
      return;
    }
    setState(() => _feedbackSending = true);
    try {
      await ref
          .read(diagnosticsRepositoryProvider)
          .sendFeedback(recommendation.id, helpful: helpful);
      if (mounted) {
        setState(() {
          _feedbackSending = false;
          _feedbackSent = true;
        });
      }
    } on ApiException {
      if (mounted) {
        setState(() => _feedbackSending = false);
      }
    }
  }

  Future<void> _confirmDelete(AppLocalizations strings) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(strings.diagnosticDeleteTitle),
          content: Text(strings.diagnosticDeleteMessage),
          actions: <Widget>[
            AppButton(
              key: const Key('diagnostic_delete_cancel'),
              label: strings.cancel,
              variant: AppButtonVariant.outlined,
              size: AppButtonSize.compact,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            AppButton(
              key: const Key('diagnostic_delete_confirm'),
              label: strings.diagnosticDelete,
              size: AppButtonSize.compact,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref.read(diagnosticsRepositoryProvider).delete(widget.diagnosticId);
      if (mounted) {
        context.go('/home');
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(error, strings))),
        );
      }
    }
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner({required this.strings, super.key});

  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: AppRadii.smallBorder,
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.info_outline,
            color: AppColors.primary,
            size: AppSizes.icon,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              strings.diagnosticDemoBanner,
              style: AppTextStyles.body.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingLogo extends StatefulWidget {
  const _PulsingLogo();

  @override
  State<_PulsingLogo> createState() => _PulsingLogoState();
}

class _PulsingLogoState extends State<_PulsingLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _scale = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1,
          end: 1.08,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1.08,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: const AppLogo(size: 72));
  }
}

class _ProcessingView extends StatelessWidget {
  const _ProcessingView({required this.strings, this.diagnostic});

  final AppLocalizations strings;
  final Diagnostic? diagnostic;

  @override
  Widget build(BuildContext context) {
    final List<DiagnosticMedia> medias =
        diagnostic?.medias ?? <DiagnosticMedia>[];
    return Column(
      children: <Widget>[
        const SizedBox(height: AppSpacing.xxl),
        const _PulsingLogo(),
        const SizedBox(height: AppSpacing.xl),
        Text(
          strings.diagnosticProcessing,
          key: const Key('diagnostic_processing'),
          style: AppTextStyles.title,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          strings.diagnosticProcessingHint,
          style: AppTextStyles.body.copyWith(color: AppColors.muted),
          textAlign: TextAlign.center,
        ),
        if (medias.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            alignment: WrapAlignment.center,
            children: <Widget>[
              for (final DiagnosticMedia media in medias)
                AppPhotoTile(
                  key: Key('diagnostic_result_media_${media.id}'),
                  size: 88,
                  image: media.url == null || media.url!.isEmpty
                      ? null
                      : NetworkImage(media.url!),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DoneView extends StatelessWidget {
  const _DoneView({
    required this.strings,
    required this.diagnostic,
    required this.feedbackSent,
    required this.feedbackSending,
    required this.onFeedback,
  });

  final AppLocalizations strings;
  final Diagnostic diagnostic;
  final bool feedbackSent;
  final bool feedbackSending;
  final ValueChanged<bool> onFeedback;

  @override
  Widget build(BuildContext context) {
    final Prediction? main = _mainPrediction(diagnostic);
    final bool isHealthy = main?.label.kind == 'healthy';
    final double? confidence = diagnostic.confidence ?? main?.confidence;
    final List<Prediction> others = diagnostic.predictions
        .where(
          (Prediction prediction) =>
              prediction.rank >= 2 && prediction.rank <= 3,
        )
        .toList();
    final RecommendationInfo? recommendation = diagnostic.recommendation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      main?.label.name ?? strings.diagnosticHealthy,
                      key: const Key('diagnostic_main_label'),
                      style: AppTextStyles.title,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _severityChip(strings, diagnostic, isHealthy),
                ],
              ),
              if (confidence != null) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  strings.diagnosticConfidence(_percent(confidence)),
                  key: const Key('diagnostic_confidence'),
                  style: AppTextStyles.label,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppProgressBar(value: confidence),
              ],
            ],
          ),
        ),
        if (others.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xl),
          Text(
            strings.diagnosticOtherPossibilities,
            style: AppTextStyles.title,
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (int index = 0; index < others.length; index++) ...<Widget>[
                  if (index > 0) const SizedBox(height: AppSpacing.lg),
                  Text(others[index].label.name, style: AppTextStyles.label),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    strings.diagnosticConfidence(
                      _percent(others[index].confidence),
                    ),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AppProgressBar(
                    value: others[index].confidence,
                    color: AppColors.secondary,
                  ),
                ],
              ],
            ),
          ),
        ],
        if (recommendation != null && recommendation.isPublished) ...<Widget>[
          const SizedBox(height: AppSpacing.xl),
          Text(strings.diagnosticAdvice, style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(recommendation.title, style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.sm),
                Text(recommendation.body, style: AppTextStyles.body),
                ..._stepSections(strings, recommendation),
                const SizedBox(height: AppSpacing.lg),
                if (feedbackSent)
                  Text(
                    strings.diagnosticFeedbackThanks,
                    key: const Key('diagnostic_feedback_thanks'),
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.primary,
                    ),
                  )
                else ...<Widget>[
                  Text(
                    strings.diagnosticFeedbackQuestion,
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: <Widget>[
                      AppButton(
                        key: const Key('diagnostic_feedback_yes'),
                        label: strings.diagnosticFeedbackYes,
                        variant: AppButtonVariant.outlined,
                        size: AppButtonSize.compact,
                        onPressed: feedbackSending
                            ? null
                            : () => onFeedback(true),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AppButton(
                        key: const Key('diagnostic_feedback_no'),
                        label: strings.diagnosticFeedbackNo,
                        variant: AppButtonVariant.outlined,
                        size: AppButtonSize.compact,
                        onPressed: feedbackSending
                            ? null
                            : () => onFeedback(false),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Text(
          strings.diagnosticTechnician,
          key: const Key('diagnostic_technician'),
          style: AppTextStyles.caption.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }

  List<Widget> _stepSections(
    AppLocalizations strings,
    RecommendationInfo recommendation,
  ) {
    const List<String> categories = <String>[
      'cultural',
      'biological',
      'chemical',
      'prevention',
    ];
    final List<Widget> widgets = <Widget>[];
    for (final String category in categories) {
      final List<RecommendationStep> steps = recommendation.steps
          .where(
            (RecommendationStep step) =>
                step.category == category && step.text.isNotEmpty,
          )
          .toList();
      if (steps.isEmpty) {
        continue;
      }
      widgets.add(const SizedBox(height: AppSpacing.lg));
      widgets.add(
        Text(_categoryTitle(strings, category), style: AppTextStyles.label),
      );
      for (final RecommendationStep step in steps) {
        widgets.add(const SizedBox(height: AppSpacing.xs));
        widgets.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('•  ', style: AppTextStyles.body),
              Expanded(child: Text(step.text, style: AppTextStyles.body)),
            ],
          ),
        );
      }
    }
    return widgets;
  }
}

class _ExpertView extends StatelessWidget {
  const _ExpertView({required this.strings, required this.diagnostic});

  final AppLocalizations strings;
  final Diagnostic diagnostic;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.verified_user_outlined,
                    color: AppColors.secondary,
                    size: AppSizes.icon,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      strings.diagnosticExpertReview,
                      key: const Key('diagnostic_expert_review'),
                      style: AppTextStyles.title,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                strings.diagnosticProvisional,
                style: AppTextStyles.caption.copyWith(color: AppColors.muted),
              ),
              for (final Prediction prediction
                  in diagnostic.predictions) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                Text(prediction.label.name, style: AppTextStyles.label),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  strings.diagnosticConfidence(_percent(prediction.confidence)),
                  style: AppTextStyles.caption.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: AppSpacing.xs),
                AppProgressBar(
                  value: prediction.confidence,
                  color: AppColors.secondary,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          strings.diagnosticTechnician,
          key: const Key('diagnostic_technician'),
          style: AppTextStyles.caption.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({
    required this.strings,
    required this.onRetry,
    this.error,
    this.message,
  });

  final AppLocalizations strings;
  final Object? error;
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final String text = error is ApiException
        ? apiErrorMessage(error! as ApiException, strings)
        : message != null && message!.isNotEmpty
        ? message!
        : strings.diagnosticFailed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppErrorBanner(key: const Key('diagnostic_failed'), message: text),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          key: const Key('diagnostic_retry'),
          label: strings.retry,
          onPressed: onRetry,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          key: const Key('diagnostic_new_after_failure'),
          label: strings.diagnosticNewDiagnostic,
          variant: AppButtonVariant.outlined,
          onPressed: () => context.go('/diagnostic/new'),
        ),
      ],
    );
  }
}

class _TimeoutView extends StatelessWidget {
  const _TimeoutView({required this.strings, required this.onRefresh});

  final AppLocalizations strings;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppCard(
          child: Column(
            children: <Widget>[
              const Icon(Icons.schedule, color: AppColors.secondary, size: 32),
              const SizedBox(height: AppSpacing.md),
              Text(
                strings.diagnosticTimeout,
                key: const Key('diagnostic_timeout'),
                style: AppTextStyles.title,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          key: const Key('diagnostic_refresh'),
          label: strings.diagnosticRefresh,
          onPressed: onRefresh,
        ),
      ],
    );
  }
}

Prediction? _mainPrediction(Diagnostic diagnostic) {
  for (final Prediction prediction in diagnostic.predictions) {
    if (prediction.rank == 1) {
      return prediction;
    }
  }
  if (diagnostic.predictions.isNotEmpty) {
    return diagnostic.predictions.first;
  }
  return null;
}

Widget _severityChip(
  AppLocalizations strings,
  Diagnostic diagnostic,
  bool isHealthy,
) {
  if (isHealthy) {
    return AppStatusChip(
      key: const Key('diagnostic_healthy_chip'),
      label: strings.diagnosticHealthy,
      variant: AppStatusChipVariant.success,
    );
  }
  final Severity? severity = diagnostic.severity;
  if (severity == null) {
    return const SizedBox.shrink();
  }
  switch (severity) {
    case Severity.low:
      return AppStatusChip(
        label: strings.diagnosticSeverityLow,
        variant: AppStatusChipVariant.success,
      );
    case Severity.medium:
      return AppStatusChip(
        label: strings.diagnosticSeverityMedium,
        variant: AppStatusChipVariant.warning,
      );
    case Severity.high:
      return AppStatusChip(
        label: strings.diagnosticSeverityHigh,
        variant: AppStatusChipVariant.danger,
      );
  }
}

String _categoryTitle(AppLocalizations strings, String category) {
  switch (category) {
    case 'cultural':
      return strings.diagnosticStepCultural;
    case 'biological':
      return strings.diagnosticStepBiological;
    case 'chemical':
      return strings.diagnosticStepChemical;
    case 'prevention':
      return strings.diagnosticStepPrevention;
    default:
      return category;
  }
}

String _percent(double value) {
  final double percent = value * 100;
  if (percent == percent.roundToDouble()) {
    return percent.toInt().toString();
  }
  return percent.toStringAsFixed(1).replaceAll('.', ',');
}
