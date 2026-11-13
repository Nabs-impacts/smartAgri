import 'package:flutter/material.dart';

import '../../core/i18n/app_language.dart';
import '../../design_system/app_icons.dart';
import '../../design_system/app_palette.dart';
import '../../design_system/components/app_bottom_nav.dart';
import '../../design_system/components/app_button.dart';
import '../../design_system/components/app_card.dart';
import '../../design_system/components/app_checkbox_tile.dart';
import '../../design_system/components/app_choice_chips.dart';
import '../../design_system/components/app_date_field.dart';
import '../../design_system/components/app_error_banner.dart';
import '../../design_system/components/app_icon_button.dart';
import '../../design_system/components/app_otp_field.dart';
import '../../design_system/components/app_photo_tile.dart';
import '../../design_system/components/app_progress_bar.dart';
import '../../design_system/components/app_search_field.dart';
import '../../design_system/components/app_select_field.dart';
import '../../design_system/components/app_status_banner.dart';
import '../../design_system/components/app_status_chip.dart';
import '../../design_system/components/app_text_button.dart';
import '../../design_system/components/app_text_field.dart';
import '../../design_system/components/gonata_logo.dart';
import '../../design_system/components/info_text.dart';
import '../../design_system/components/info_tile.dart';
import '../../design_system/components/language_switcher.dart';
import '../../design_system/theme.dart';
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
  bool _dark = false;
  DateTime? _date = DateTime(2026, 11, 13);
  String? _region = 'niamey';
  String _soil = 'loam';

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _dark ? AppTheme.dark : AppTheme.light,
      child: Builder(
        builder: (BuildContext context) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Galerie du design system'),
              actions: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: AppIconButton(
                    icon: _dark ? AppIcons.sun : AppIcons.visibilityOff,
                    tooltip: _dark
                        ? 'Afficher le thème clair'
                        : 'Afficher le thème sombre',
                    onPressed: () => setState(() => _dark = !_dark),
                    variant: AppIconButtonVariant.square,
                  ),
                ),
              ],
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const _SectionTitle('Marque et typographie'),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        const GonataLogo(size: 64),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Text(
                            'GonaTa',
                            style: AppTextStyles.displayAccent.copyWith(
                              color: context.palette.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Grand chiffre de récolte',
                      style: AppTextStyles.caption.copyWith(
                        color: context.palette.muted,
                      ),
                    ),
                    Text(
                      '1 250 kg',
                      style: AppTextStyles.displayAccent.copyWith(
                        color: context.palette.secondaryText,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Titre de section',
                      style: AppTextStyles.headline.copyWith(
                        color: context.palette.ink,
                      ),
                    ),
                    Text(
                      'Sous-titre de carte',
                      style: AppTextStyles.title.copyWith(
                        color: context.palette.ink,
                      ),
                    ),
                    Text(
                      'Texte courant lisible en plein soleil.',
                      style: AppTextStyles.body.copyWith(
                        color: context.palette.ink,
                      ),
                    ),
                    Text(
                      'Libellé',
                      style: AppTextStyles.label.copyWith(
                        color: context.palette.ink,
                      ),
                    ),
                    Text(
                      'Légende',
                      style: AppTextStyles.caption.copyWith(
                        color: context.palette.muted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const _SectionTitle('Boutons'),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: <Widget>[
                        AppButton(label: 'Principal', onPressed: () {}),
                        AppButton(
                          label: 'Secondaire',
                          onPressed: () {},
                          variant: AppButtonVariant.secondary,
                        ),
                        AppButton(
                          label: 'Contour',
                          onPressed: () {},
                          variant: AppButtonVariant.outlined,
                        ),
                        AppButton(
                          label: 'Inversé',
                          onPressed: () {},
                          variant: AppButtonVariant.inverted,
                        ),
                        AppButton(
                          label: 'Compact',
                          onPressed: () {},
                          size: AppButtonSize.compact,
                        ),
                        AppButton(
                          label: 'Icône',
                          onPressed: () {},
                          icon: const Icon(AppIcons.add),
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
                      onChanged: (bool value) =>
                          setState(() => _checked = value),
                    ),
                    const AppCheckboxTile(
                      label: 'Case désactivée',
                      value: false,
                      onChanged: null,
                    ),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: <Widget>[
                        AppTextButton(
                          label: 'Action discrète',
                          variant: AppTextButtonVariant.muted,
                          onPressed: () {},
                        ),
                        AppTextButton(
                          label: 'Créer un compte',
                          onPressed: () {},
                        ),
                        const AppTextButton(
                          label: 'Texte désactivé',
                          onPressed: null,
                        ),
                      ],
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
                    const AppTextField(
                      hintText: 'Champ désactivé',
                      enabled: false,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const AppSearchField(),
                    const SizedBox(height: AppSpacing.md),
                    AppSelectField<String>(
                      hintText: 'Région',
                      options: const <AppSelectOption<String>>[
                        AppSelectOption<String>(
                          value: 'niamey',
                          label: 'Niamey',
                        ),
                        AppSelectOption<String>(value: 'dosso', label: 'Dosso'),
                        AppSelectOption<String>(
                          value: 'maradi',
                          label: 'Maradi',
                        ),
                      ],
                      value: _region,
                      allowEmpty: true,
                      emptyLabel: 'Aucune région',
                      onChanged: (String? value) =>
                          setState(() => _region = value),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const AppSelectField<String>(
                      hintText: 'Sélection en erreur',
                      options: <AppSelectOption<String>>[],
                      value: null,
                      onChanged: null,
                      errorText: 'Ce champ est obligatoire.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppDateField(
                      hintText: 'Date de semis',
                      value: _date,
                      allowClear: true,
                      onChanged: (DateTime? value) =>
                          setState(() => _date = value),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const AppDateField(
                      hintText: 'Date en erreur',
                      value: null,
                      errorText: 'Choisissez une date.',
                      onChanged: null,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const _SectionTitle('Code à 6 chiffres'),
                    const AppOtpField(),
                    const SizedBox(height: AppSpacing.md),
                    const AppOtpField(error: true),
                    const SizedBox(height: AppSpacing.xl),
                    const _SectionTitle('Pastilles de choix'),
                    AppChoiceChips<String>(
                      options: const <AppChoiceOption<String>>[
                        AppChoiceOption<String>(
                          value: 'sandy',
                          label: 'Sableux',
                        ),
                        AppChoiceOption<String>(
                          value: 'loam',
                          label: 'Limoneux',
                        ),
                        AppChoiceOption<String>(
                          value: 'clay',
                          label: 'Argileux',
                        ),
                      ],
                      value: _soil,
                      onChanged: (String value) =>
                          setState(() => _soil = value),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const AppChoiceChips<String>(
                      options: <AppChoiceOption<String>>[
                        AppChoiceOption<String>(
                          value: 'sandy',
                          label: 'Sableux',
                        ),
                        AppChoiceOption<String>(
                          value: 'loam',
                          label: 'Limoneux',
                        ),
                      ],
                      value: 'sandy',
                      enabled: false,
                      onChanged: _ignoreChoice,
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
                        const AppPhotoTile(loading: true),
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
                    const _SectionTitle('Bandeaux'),
                    const AppStatusBanner(
                      message: 'Synchronisation en cours.',
                      tone: AppStatusBannerTone.info,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppStatusBanner(
                      message: 'Vous êtes hors ligne.',
                      tone: AppStatusBannerTone.warning,
                      actionLabel: 'Réessayer',
                      onAction: _noop,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const AppStatusBanner(
                      message: 'La synchronisation a échoué.',
                      tone: AppStatusBannerTone.error,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const AppErrorBanner(
                      message: 'Une erreur est survenue. Veuillez réessayer.',
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const _SectionTitle('Progression'),
                    const AppProgressBar(value: 0.25),
                    const SizedBox(height: AppSpacing.md),
                    AppProgressBar(
                      value: 0.55,
                      color: context.palette.secondary,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppProgressBar(
                      value: 0.85,
                      color: context.palette.tertiary,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const _SectionTitle('Navigation'),
                    AppBottomNav(
                      items: const <AppNavItem>[
                        AppNavItem(icon: AppIcons.home, label: 'Accueil'),
                        AppNavItem(icon: AppIcons.search, label: 'Recherche'),
                        AppNavItem(icon: AppIcons.profile, label: 'Profil'),
                      ],
                      selectedIndex: _navIndex,
                      onSelected: (int index) =>
                          setState(() => _navIndex = index),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const _SectionTitle('Boutons d’icône'),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: <Widget>[
                        AppIconButton(
                          icon: AppIcons.settings,
                          tooltip: 'Réglages',
                          onPressed: () {},
                        ),
                        AppIconButton(
                          icon: AppIcons.edit,
                          tooltip: 'Modifier',
                          onPressed: () {},
                          variant: AppIconButtonVariant.accentBrown,
                        ),
                        AppIconButton(
                          icon: AppIcons.check,
                          tooltip: 'Valider',
                          onPressed: () {},
                          variant: AppIconButtonVariant.tertiary,
                        ),
                        AppIconButton(
                          icon: AppIcons.delete,
                          tooltip: 'Supprimer',
                          onPressed: () {},
                          variant: AppIconButtonVariant.danger,
                        ),
                        AppIconButton(
                          icon: AppIcons.close,
                          tooltip: 'Contour danger',
                          onPressed: () {},
                          variant: AppIconButtonVariant.dangerOutline,
                        ),
                        const AppIconButton(
                          icon: AppIcons.lock,
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
                          Text(
                            'Carte de démonstration',
                            style: AppTextStyles.title,
                          ),
                          SizedBox(height: AppSpacing.sm),
                          Text(
                            'Contenu de la carte avec bordure et ombre douce.',
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
                        InfoTile(label: 'Vent 15 km/h'),
                        InfoText('Sol propice'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

void _noop() {}

void _ignoreChoice(String value) {}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        title,
        style: AppTextStyles.title.copyWith(color: context.palette.ink),
      ),
    );
  }
}
