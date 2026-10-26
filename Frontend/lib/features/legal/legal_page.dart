import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/strings_provider.dart';
import '../../design_system/tokens.dart';

enum LegalDocument { terms, privacy }

class LegalPage extends ConsumerWidget {
  const LegalPage({required this.document, super.key});

  final LegalDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    final String title = document == LegalDocument.terms
        ? strings.legalTermsTitle
        : strings.legalPrivacyTitle;
    final List<String> paragraphs = document == LegalDocument.terms
        ? <String>[strings.legalTermsParagraph1, strings.legalTermsParagraph2]
        : <String>[
            strings.legalPrivacyParagraph1,
            strings.legalPrivacyParagraph2,
          ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: const BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: AppRadii.cardBorder,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(
                      Icons.info_outline,
                      color: AppColors.accentBrown,
                      size: AppSizes.icon,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        strings.legalProvisionalBanner,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.accentBrown,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              for (final String paragraph in paragraphs) ...<Widget>[
                Text(paragraph, style: AppTextStyles.body),
                const SizedBox(height: AppSpacing.lg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
