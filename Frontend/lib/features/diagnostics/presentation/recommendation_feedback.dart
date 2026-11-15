import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/strings_provider.dart';
import '../../../core/network/api_exception.dart';
import '../../../design_system/app_palette.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/tokens.dart';
import '../data/diagnostics_repository.dart';

class RecommendationFeedbackPanel extends ConsumerStatefulWidget {
  const RecommendationFeedbackPanel({
    required this.recommendationId,
    this.keyPrefix = 'recommendation',
    super.key,
  });

  final String recommendationId;
  final String keyPrefix;

  @override
  ConsumerState<RecommendationFeedbackPanel> createState() =>
      _RecommendationFeedbackPanelState();
}

class _RecommendationFeedbackPanelState
    extends ConsumerState<RecommendationFeedbackPanel> {
  bool _sending = false;
  bool _sent = false;
  bool _applied = false;

  Future<void> _send(bool helpful) async {
    if (_sending || _sent) {
      return;
    }
    setState(() => _sending = true);
    try {
      await ref
          .read(diagnosticsRepositoryProvider)
          .sendFeedback(
            widget.recommendationId,
            helpful: helpful,
            applied: _applied,
          );
      if (mounted) {
        setState(() {
          _sending = false;
          _sent = true;
        });
      }
    } on ApiException {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    if (_sent) {
      return Text(
        strings.diagnosticFeedbackThanks,
        key: Key('${widget.keyPrefix}_feedback_thanks'),
        style: AppTextStyles.label.copyWith(color: context.palette.primary),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(strings.diagnosticFeedbackQuestion, style: AppTextStyles.body),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            AppButton(
              key: Key('${widget.keyPrefix}_feedback_yes'),
              label: strings.diagnosticFeedbackYes,
              variant: AppButtonVariant.outlined,
              size: AppButtonSize.compact,
              onPressed: _sending ? null : () => _send(true),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppButton(
              key: Key('${widget.keyPrefix}_feedback_no'),
              label: strings.diagnosticFeedbackNo,
              variant: AppButtonVariant.outlined,
              size: AppButtonSize.compact,
              onPressed: _sending ? null : () => _send(false),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            Checkbox(
              key: Key('${widget.keyPrefix}_feedback_applied'),
              value: _applied,
              onChanged: _sending
                  ? null
                  : (bool? value) => setState(() => _applied = value ?? false),
            ),
            Expanded(
              child: Text(strings.feedbackApplied, style: AppTextStyles.body),
            ),
          ],
        ),
      ],
    );
  }
}
