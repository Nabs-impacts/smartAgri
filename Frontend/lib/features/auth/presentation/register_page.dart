import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/strings_provider.dart';
import '../../../core/phone/niger_phone.dart';
import '../../../design_system/app_icons.dart';
import '../../../design_system/app_palette.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_checkbox_tile.dart';
import '../../../design_system/components/app_error_banner.dart';
import '../../../design_system/components/app_text_button.dart';
import '../../../design_system/components/app_text_field.dart';
import '../../../design_system/tokens.dart';
import '../domain/auth_error_messages.dart';
import '../domain/auth_purpose.dart';
import '../domain/consent_choice.dart';
import '../domain/otp_args.dart';
import 'auth_scaffold.dart';
import 'register_controller.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmation = TextEditingController();
  bool _terms = false;
  bool _privacy = false;
  bool _dataSharing = false;
  bool _research = false;

  @override
  void dispose() {
    _lastName.dispose();
    _firstName.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  String get _fullName =>
      '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim();

  String? _validateLastName(AppLocalizations strings, String? value) {
    final String name = value?.trim() ?? '';
    if (name.isEmpty || name.length > 60) {
      return strings.lastNameLength;
    }
    return _validateFullNameLength(strings);
  }

  String? _validateFirstName(AppLocalizations strings, String? value) {
    final String name = value?.trim() ?? '';
    if (name.isEmpty || name.length > 60) {
      return strings.firstNameLength;
    }
    return _validateFullNameLength(strings);
  }

  String? _validateFullNameLength(AppLocalizations strings) {
    final int length = _fullName.length;
    if (length < 2 || length > 120) {
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
          fullName: _fullName,
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
    final RegisterState state = ref.watch(registerControllerProvider);

    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
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
                  onPressed: state.loading ? null : () => context.go('/login'),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
          ],
          Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              children: <Widget>[
                AppTextField(
                  key: const Key('register_last_name_field'),
                  controller: _lastName,
                  hintText: strings.lastNameLabel,
                  textInputAction: TextInputAction.next,
                  validator: (String? value) =>
                      _validateLastName(strings, value),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  key: const Key('register_first_name_field'),
                  controller: _firstName,
                  hintText: strings.firstNameLabel,
                  textInputAction: TextInputAction.next,
                  validator: (String? value) =>
                      _validateFirstName(strings, value),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  key: const Key('register_phone_field'),
                  controller: _phone,
                  hintText: strings.phoneLabel,
                  prefixText: '+227 ',
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: const <NigerPhoneInputFormatter>[
                    NigerPhoneInputFormatter(),
                  ],
                  suffixIcon: Icon(
                    AppIcons.phone,
                    color: context.palette.muted,
                    size: AppSizes.icon,
                  ),
                  validator: (String? value) => _validatePhone(strings, value),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  key: const Key('register_password_field'),
                  controller: _password,
                  hintText: strings.passwordLabel,
                  helperText: strings.passwordRules,
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
            onRead: state.loading ? null : () => context.go('/legal/privacy'),
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
          AppButton(
            key: const Key('register_submit'),
            label: strings.registerSubmit,
            loading: state.loading,
            onPressed: state.loading || !_canSubmit ? null : _submit,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                strings.registerAlreadyAccount,
                style: AppTextStyles.body.copyWith(
                  color: context.palette.muted,
                ),
              ),
              AppTextButton(
                key: const Key('register_login_link'),
                label: strings.signIn,
                onPressed: state.loading ? null : () => context.go('/login'),
              ),
            ],
          ),
        ],
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
    final AppCheckboxTile checkbox = AppCheckboxTile(
      key: checkboxKey,
      label: label,
      value: value,
      maxLines: 4,
      onChanged: onChanged,
    );
    final AppTextButton read = AppTextButton(
      key: readKey,
      label: readLabel,
      variant: AppTextButtonVariant.muted,
      onPressed: onRead,
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 340) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              checkbox,
              Align(alignment: Alignment.centerRight, child: read),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: checkbox),
            read,
          ],
        );
      },
    );
  }
}
