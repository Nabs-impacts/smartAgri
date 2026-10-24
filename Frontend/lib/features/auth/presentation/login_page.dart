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
import 'login_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _rememberMe = true;
  bool _prefilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) {
      return;
    }
    _prefilled = true;
    final String? phone = GoRouterState.of(context)
        .uri
        .queryParameters['phone'];
    if (phone != null && phone.isNotEmpty) {
      _phone.text = NigerPhone.format(phone);
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await ref
        .read(loginControllerProvider.notifier)
        .submit(
          phone: _phone.text,
          password: _password.text,
          rememberMe: _rememberMe,
        );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    final AppLanguage language = ref.watch(languageControllerProvider);
    final LoginState state = ref.watch(loginControllerProvider);
    final double width = max(200, MediaQuery.sizeOf(context).width * 0.6);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double topHeight = (constraints.maxHeight * 0.38)
                .clamp(160.0, 320.0)
                .toDouble();
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: max(0, constraints.maxHeight - AppSpacing.xxl),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(
                      height: topHeight,
                      child: Stack(
                        children: <Widget>[
                          Align(
                            alignment: Alignment.topRight,
                            child: LanguageSwitcher(
                              value: language,
                              onChanged: (AppLanguage value) => ref
                                  .read(languageControllerProvider.notifier)
                                  .set(value),
                            ),
                          ),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const AppLogo(
                                  variant: AppLogoVariant.green,
                                  size: 88,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  strings.appName,
                                  style: AppTextStyles.headline,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (state.error != null) ...<Widget>[
                      AppErrorBanner(
                        key: const Key('login_error'),
                        message: authErrorMessage(state.error!, strings),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    Form(
                      key: _formKey,
                      child: Column(
                        children: <Widget>[
                          AppTextField(
                            key: const Key('login_phone_field'),
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
                                NigerPhone.isValid(value ?? '')
                                ? null
                                : strings.phoneInvalid,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            key: const Key('login_password_field'),
                            controller: _password,
                            hintText: strings.passwordLabel,
                            obscure: true,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                            validator: (String? value) =>
                                value == null || value.isEmpty
                                ? strings.passwordRequired
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: AppCheckboxTile(
                            key: const Key('login_remember'),
                            label: strings.rememberMe,
                            value: _rememberMe,
                            onChanged: (bool value) =>
                                setState(() => _rememberMe = value),
                          ),
                        ),
                        AppTextButton(
                          key: const Key('login_forgot'),
                          label: strings.forgotPassword,
                          variant: AppTextButtonVariant.muted,
                          onPressed: state.loading
                              ? null
                              : () => context.go('/forgot-password'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Center(
                      child: SizedBox(
                        width: width,
                        child: AppButton(
                          key: const Key('login_submit'),
                          label: strings.signIn,
                          loading: state.loading,
                          onPressed: state.loading ? null : _submit,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Center(
                      child: AppTextButton(
                        key: const Key('login_register'),
                        label: strings.createAccount,
                        onPressed: state.loading
                            ? null
                            : () => context.go('/register'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
