import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/language_controller.dart';
import '../../../core/i18n/strings_provider.dart';
import '../../../core/phone/niger_phone.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_checkbox_tile.dart';
import '../../../design_system/components/app_error_banner.dart';
import '../../../design_system/components/app_logo.dart';
import '../../../design_system/components/app_text_button.dart';
import '../../../design_system/components/app_text_field.dart';
import '../../../design_system/components/language_switcher.dart';
import '../../../design_system/tokens.dart';
import '../domain/auth_error_messages.dart';
import '../domain/auth_purpose.dart';
import '../domain/consent_choice.dart';
import '../domain/otp_args.dart';
import 'register_controller.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _fullName = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmation = TextEditingController();
  bool _terms = false;
  bool _privacy = false;
  bool _dataSharing = false;
  bool _research = false;

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  String? _validateFullName(AppLocalizations strings, String? value) {
    final String name = value?.trim() ?? '';
    if (name.length < 2 || name.length > 120) {
      return strings.fullNameLength;
    }
    return null;
  }

  String? _validatePhone(AppLocalizations strings, String? value) {
    return NigerPhone.isValid(value ?? '') ? null : strings.phoneInvalid;
  }

  String? _validatePassword(AppLocalizations strings, String? value) {
    final int length = value?.length ?? 0;
    if (length < 8 || length > 128) {
      return strings.passwordLength;
    }
    return null;
  }

  String? _validateConfirmation(AppLocalizations strings, String? value) {
    if (value != _password.text) {
      return strings.passwordMismatch;
    }
    return null;
  }

  bool get _canSubmit => _terms && _privacy;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false) || !_canSubmit) {
      return;
    }
    final String phone = NigerPhone.normalize(_phone.text) ?? _phone.text;
    final List<ConsentChoice> consents = <ConsentChoice>[
      const ConsentChoice(type: ConsentType.terms, accepted: true),
      const ConsentChoice(type: ConsentType.privacy, accepted: true),
      ConsentChoice(type: ConsentType.dataSharingGov, accepted: _dataSharing),
      ConsentChoice(type: ConsentType.research, accepted: _research),
    ];
    final bool registered = await ref
        .read(registerControllerProvider.notifier)
        .submit(
          fullName: _fullName.text.trim(),
          phone: _phone.text,
          password: _password.text,
          consents: consents,
        );
    if (registered && mounted) {
      context.go(
        '/otp',
        extra: OtpArgs(phone: phone, purpose: AuthPurpose.verifyPhone),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    final AppLanguage language = ref.watch(languageControllerProvider);
    final RegisterState state = ref.watch(registerControllerProvider);
    final double width = max(200, MediaQuery.sizeOf(context).width * 0.6);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Align(
                alignment: Alignment.topRight,
                child: LanguageSwitcher(
                  value: language,
                  onChanged: (AppLanguage value) =>
                      ref.read(languageControllerProvider.notifier).set(value),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Center(
                child: AppLogo(variant: AppLogoVariant.green, size: 64),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                strings.registerTitle,
                style: AppTextStyles.headline,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              if (state.error != null) ...<Widget>[
                AppErrorBanner(
                  key: const Key('register_error'),
                  message: authErrorMessage(state.error!, strings),
                ),
                if (state.phoneAlreadyUsed) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AppTextButton(
                      key: const Key('register_go_login'),
                      label: strings.signIn,
                      onPressed: state.loading
                          ? null
                          : () => context.go('/login'),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
              ],
              Form(
                key: _formKey,
                child: Column(
                  children: <Widget>[
                    AppTextField(
                      key: const Key('register_name_field'),
                      controller: _fullName,
                      hintText: strings.fullNameLabel,
                      textInputAction: TextInputAction.next,
                      validator: (String? value) =>
                          _validateFullName(strings, value),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      key: const Key('register_phone_field'),
                      controller: _phone,
                      hintText: strings.phoneLabel,
                      prefixText: '+227 ',
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      inputFormatters: const <NigerPhoneInputFormatter>[
                        NigerPhoneInputFormatter(),
                      ],
                      suffixIcon: const Icon(
                        Icons.phone_outlined,
                        color: AppColors.muted,
                        size: AppSizes.icon,
                      ),
                      validator: (String? value) =>
                          _validatePhone(strings, value),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      key: const Key('register_password_field'),
                      controller: _password,
                      hintText: strings.passwordLabel,
                      obscure: true,
                      autofillHints: const <String>[AutofillHints.newPassword],
                      textInputAction: TextInputAction.next,
                      validator: (String? value) =>
                          _validatePassword(strings, value),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      key: const Key('register_confirm_field'),
                      controller: _confirmation,
                      hintText: strings.confirmPasswordLabel,
                      obscure: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      validator: (String? value) =>
                          _validateConfirmation(strings, value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _ConsentRow(
                checkboxKey: const Key('register_consent_terms'),
                label: strings.registerTermsConsent,
                readLabel: strings.readAction,
                value: _terms,
                onChanged: state.loading
                    ? null
                    : (bool value) => setState(() => _terms = value),
                readKey: const Key('register_read_terms'),
                onRead: state.loading ? null : () => context.go('/legal/terms'),
              ),
              _ConsentRow(
                checkboxKey: const Key('register_consent_privacy'),
                label: strings.registerPrivacyConsent,
                readLabel: strings.readAction,
                value: _privacy,
                onChanged: state.loading
                    ? null
                    : (bool value) => setState(() => _privacy = value),
                readKey: const Key('register_read_privacy'),
                onRead: state.loading
                    ? null
                    : () => context.go('/legal/privacy'),
              ),
              AppCheckboxTile(
                key: const Key('register_consent_data'),
                label: strings.registerDataSharingConsent,
                value: _dataSharing,
                maxLines: 5,
                onChanged: state.loading
                    ? null
                    : (bool value) => setState(() => _dataSharing = value),
              ),
              AppCheckboxTile(
                key: const Key('register_consent_research'),
                label: strings.registerResearchConsent,
                value: _research,
                maxLines: 4,
                onChanged: state.loading
                    ? null
                    : (bool value) => setState(() => _research = value),
              ),
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: SizedBox(
                  width: width,
                  child: AppButton(
                    key: const Key('register_submit'),
                    label: strings.registerSubmit,
                    loading: state.loading,
                    onPressed: state.loading || !_canSubmit ? null : _submit,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: AppTextButton(
                  key: const Key('register_login_link'),
                  label: strings.registerAlreadyAccount,
                  variant: AppTextButtonVariant.muted,
                  onPressed: state.loading ? null : () => context.go('/login'),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.checkboxKey,
    required this.label,
    required this.readLabel,
    required this.value,
    required this.onChanged,
    required this.readKey,
    required this.onRead,
  });

  final Key checkboxKey;
  final String label;
  final String readLabel;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Key readKey;
  final VoidCallback? onRead;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: AppCheckboxTile(
            key: checkboxKey,
            label: label,
            value: value,
            maxLines: 4,
            onChanged: onChanged,
          ),
        ),
        AppTextButton(
          key: readKey,
          label: readLabel,
          variant: AppTextButtonVariant.muted,
          onPressed: onRead,
        ),
      ],
    );
  }
}
