import 'package:flutter/material.dart';

import '../../core/i18n/app_language.dart';
import '../../design_system/components/app_bottom_nav.dart';
import '../../design_system/components/app_button.dart';
import '../../design_system/components/app_card.dart';
import '../../design_system/components/app_choice_chips.dart';
import '../../design_system/components/app_checkbox_tile.dart';
import '../../design_system/components/app_error_banner.dart';
import '../../design_system/components/app_icon_button.dart';
import '../../design_system/components/app_logo.dart';
import '../../design_system/components/app_photo_tile.dart';
import '../../design_system/components/app_progress_bar.dart';
import '../../design_system/components/app_search_field.dart';
import '../../design_system/components/app_select_field.dart';
import '../../design_system/components/app_status_chip.dart';
import '../../design_system/components/app_text_button.dart';
import '../../design_system/components/app_text_field.dart';
import '../../design_system/components/info_text.dart';
import '../../design_system/components/info_tile.dart';
import '../../design_system/components/language_switcher.dart';
import '../../design_system/tokens.dart';

class DesignGalleryPage extends StatefulWidget {
  const DesignGalleryPage({super.key});

  @override
  State<DesignGalleryPage> createState() => _DesignGalleryPageState();
}

class _DesignGalleryPageState extends State<DesignGalleryPage> {
  int _navIndex = 0;
  AppLanguage _language = AppLanguage.fr;
  bool _checked = true;
  String? _region = 'niamey';
  String _soil = 'loam';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Galerie du design system')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _SectionTitle('Boutons'),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: <Widget>[
                  AppButton(label: 'Primary', onPressed: () {}),
                  AppButton(
                    label: 'Secondary',
                    onPressed: () {},
                    variant: AppButtonVariant.secondary,
                  ),
                  AppButton(
                    label: 'Inverted',
                    onPressed: () {},
                    variant: AppButtonVariant.inverted,
                  ),
                  AppButton(
                    label: 'Outlined',
                    onPressed: () {},
                    variant: AppButtonVariant.outlined,
                  ),
                  AppButton(
                    label: 'Compact',
                    onPressed: () {},
                    size: AppButtonSize.compact,
                  ),
                  AppButton(
                    label: 'Icône',
                    onPressed: () {},
                    icon: const Icon(Icons.add),
                  ),
                  const AppButton(
                    label: 'Chargement',
                    onPressed: null,
                    loading: true,
                  ),
                  const AppButton(label: 'Désactivé', onPressed: null),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              const _SectionTitle('Cases et boutons texte'),
              AppCheckboxTile(
                label: 'Se souvenir de moi',
                value: _checked,
                onChanged: (bool value) => setState(() => _checked = value),
              ),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: <Widget>[
                  AppTextButton(
                    label: 'Mot de passe oublié',
                    variant: AppTextButtonVariant.muted,
                    onPressed: () {},
                  ),
                  AppTextButton(label: 'Créer un compte', onPressed: () {}),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              const _SectionTitle('Bandeau d’erreur'),
              const AppErrorBanner(
                message: 'Une erreur est survenue. Veuillez réessayer.',
              ),
              const SizedBox(height: AppSpacing.xl),
              const _SectionTitle('Champs'),
              const AppTextField(hintText: 'Numéro de téléphone'),
              const SizedBox(height: AppSpacing.md),
              const AppTextField(hintText: 'Mot de passe', obscure: true),
              const SizedBox(height: AppSpacing.md),
              const AppTextField(
                hintText: 'Champ en erreur',
                errorText: 'Ce champ est obligatoire.',
              ),
              const SizedBox(height: AppSpacing.md),
              const AppSearchField(),
              const SizedBox(height: AppSpacing.md),
              AppSelectField<String>(
                hintText: 'Région',
                options: const <AppSelectOption<String>>[
                  AppSelectOption<String>(value: 'niamey', label: 'Niamey'),
                  AppSelectOption<String>(value: 'dosso', label: 'Dosso'),
                  AppSelectOption<String>(value: 'maradi', label: 'Maradi'),
                ],
                value: _region,
                allowEmpty: true,
                emptyLabel: 'Aucune région',
                onChanged: (String? value) => setState(() => _region = value),
              ),
              const SizedBox(height: AppSpacing.md),
              const AppSelectField<String>(
                hintText: 'Champ en erreur',
                options: <AppSelectOption<String>>[],
                value: null,
                onChanged: null,
                errorText: 'Ce champ est obligatoire.',
              ),
              const SizedBox(height: AppSpacing.xl),
              const _SectionTitle('Pastilles de choix'),
              AppChoiceChips<String>(
                options: const <AppChoiceOption<String>>[
                  AppChoiceOption<String>(value: 'sandy', label: 'Sableux'),
                  AppChoiceOption<String>(value: 'loam', label: 'Limoneux'),
                  AppChoiceOption<String>(value: 'clay', label: 'Argileux'),
                ],
                value: _soil,
                onChanged: (String value) => setState(() => _soil = value),
              ),
              const SizedBox(height: AppSpacing.xl),
              const _SectionTitle('Photos'),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: <Widget>[
                  AppPhotoTile(
                    image: const AssetImage('assets/icons/app_icon.png'),
                    onDelete: () {},
                  ),
                  const AppPhotoTile(onAdd: _noop),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              const _SectionTitle('Pastilles de statut'),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: const <Widget>[
                  AppStatusChip(
                    label: 'Succès',
                    variant: AppStatusChipVariant.success,
                  ),
                  AppStatusChip(
                    label: 'Attention',
                    variant: AppStatusChipVariant.warning,
                  ),
                  AppStatusChip(
                    label: 'Danger',
                    variant: AppStatusChipVariant.danger,
                  ),
                  AppStatusChip(label: 'Neutre'),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              const _SectionTitle('Progression'),
              const AppProgressBar(value: 0.25),
              const SizedBox(height: AppSpacing.md),
              const AppProgressBar(value: 0.55, color: AppColors.secondary),
              const SizedBox(height: AppSpacing.md),
              const AppProgressBar(value: 0.85, color: AppColors.tertiary),
              const SizedBox(height: AppSpacing.xl),
              const _SectionTitle('Navigation'),
              AppBottomNav(
                items: const <AppNavItem>[
                  AppNavItem(icon: Icons.home_outlined, label: 'Accueil'),
                  AppNavItem(icon: Icons.search, label: 'Recherche'),
                  AppNavItem(icon: Icons.person_outline, label: 'Profil'),
                ],
                selectedIndex: _navIndex,
                onSelected: (int index) => setState(() => _navIndex = index),
              ),
              const SizedBox(height: AppSpacing.xl),
              const _SectionTitle('Boutons d’icône'),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: <Widget>[
                  AppIconButton(
                    icon: Icons.tune,
                    tooltip: 'Réglages',
                    onPressed: () {},
                  ),
                  AppIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: 'Modifier',
                    onPressed: () {},
                    variant: AppIconButtonVariant.accentBrown,
                  ),
                  AppIconButton(
                    icon: Icons.check,
                    tooltip: 'Valider',
                    onPressed: () {},
                    variant: AppIconButtonVariant.tertiary,
                  ),
                  AppIconButton(
                    icon: Icons.delete_outline,
                    tooltip: 'Supprimer',
                    onPressed: () {},
                    variant: AppIconButtonVariant.danger,
                  ),
                  const AppIconButton(
                    icon: Icons.lock_outline,
                    tooltip: 'Désactivé',
                    onPressed: null,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              const _SectionTitle('Carte'),
              const AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Carte de démonstration', style: AppTextStyles.title),
                    SizedBox(height: AppSpacing.sm),
                    Text(
                      'Contenu de la carte avec bordure et ombre légère.',
                      style: AppTextStyles.body,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const _SectionTitle('Langues'),
              LanguageSwitcher(
                value: _language,
                onChanged: (AppLanguage language) =>
                    setState(() => _language = language),
              ),
              const SizedBox(height: AppSpacing.xl),
              const _SectionTitle('Informations'),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: const <Widget>[
                  InfoTile(label: 'Vent 15km/h'),
                  InfoText('Sol propice'),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              const _SectionTitle('Logo'),
              const Row(
                children: <Widget>[
                  AppLogo(),
                  SizedBox(width: AppSpacing.lg),
                  AppLogo(variant: AppLogoVariant.lime, size: 64),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _noop() {}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(title, style: AppTextStyles.title),
    );
  }
}
