import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/strings_provider.dart';
import '../../../core/phone/niger_phone.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_error_banner.dart';
import '../../../design_system/components/app_text_button.dart';
import '../../../design_system/components/app_text_field.dart';
import '../../../design_system/components/info_text.dart';
import '../../../design_system/tokens.dart';
import '../domain/auth_error_messages.dart';
import 'forgot_password_controller.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final GlobalKey<FormState> _requestFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _resetFormKey = GlobalKey<FormState>();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _code = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmation = TextEditingController();
  Timer? _navigationTimer;
  Timer? _countdownTimer;
  int _resendSeconds = 0;

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _countdownTimer?.cancel();
    _phone.dispose();
    _code.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  String? _validatePhone(AppLocalizations strings, String? value) {
    return NigerPhone.isValid(value ?? '') ? null : strings.phoneInvalid;
  }

  String? _validateCode(AppLocalizations strings, String? value) {
    final String code = value ?? '';
    if (code.isEmpty) {
      return strings.codeRequired;
    }
    if (code.length != 6) {
      return strings.codeInvalidLength;
    }
    return null;
  }

  String? _validatePassword(AppLocalizations strings, String? value) {
    if (value == null || value.length < 8) {
      return strings.passwordMinLength;
    }
    return null;
  }

  String? _validateConfirmation(AppLocalizations strings, String? value) {
    if (value != _password.text) {
      return strings.passwordMismatch;
    }
    return null;
  }

  Future<void> _sendCode() async {
    FocusScope.of(context).unfocus();
    if (!(_requestFormKey.currentState?.validate() ?? false)) {
      return;
    }
    final bool sent = await ref
        .read(forgotPasswordControllerProvider.notifier)
        .requestOtp(_phone.text);
    if (sent && mounted) {
      _startCountdown();
    }
  }

  Future<void> _resendCode() async {
    final bool sent = await ref
        .read(forgotPasswordControllerProvider.notifier)
        .requestOtp(_phone.text);
    if (sent && mounted) {
      _startCountdown();
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _changePassword() async {
    FocusScope.of(context).unfocus();
    if (!(_resetFormKey.currentState?.validate() ?? false)) {
      return;
    }
    await ref
        .read(forgotPasswordControllerProvider.notifier)
        .resetPassword(
          phone: _phone.text,
          code: _code.text,
          newPassword: _password.text,
        );
  }

  void _scheduleReturn() {
    _navigationTimer?.cancel();
    _countdownTimer?.cancel();
    final String phone = _phone.text;
    _navigationTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        context.go('/login?phone=${Uri.encodeComponent(phone)}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    final ForgotPasswordState state = ref.watch(
      forgotPasswordControllerProvider,
    );
    ref.listen<ForgotPasswordState>(forgotPasswordControllerProvider, (
      ForgotPasswordState? previous,
      ForgotPasswordState next,
    ) {
      if (next.success && previous?.success != true) {
        _scheduleReturn();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: AppTextButton(
                  key: const Key('forgot_back'),
                  label: strings.backToLogin,
                  variant: AppTextButtonVariant.muted,
                  onPressed: state.loading ? null : () => context.go('/login'),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (state.success)
                _SuccessView(
                  strings: strings,
                  onReturn: () => context.go(
                    '/login?phone=${Uri.encodeComponent(_phone.text)}',
                  ),
                )
              else ...<Widget>[
                Text(
                  strings.forgotPasswordTitle,
                  style: AppTextStyles.headline,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  strings.forgotPasswordInstructions,
                  style: AppTextStyles.body.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (state.error != null &&
                    state.step == ForgotPasswordStep.request) ...<Widget>[
                  AppErrorBanner(
                    key: const Key('forgot_error'),
                    message: authErrorMessage(state.error!, strings),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (state.step == ForgotPasswordStep.request)
                  _buildRequestStep(strings, state)
                else
                  _buildResetStep(strings, state),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestStep(
    AppLocalizations strings,
    ForgotPasswordState state,
  ) {
    return Form(
      key: _requestFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTextField(
            key: const Key('forgot_phone_field'),
            controller: _phone,
            hintText: strings.phoneLabel,
            prefixText: '+227 ',
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            inputFormatters: const <NigerPhoneInputFormatter>[
              NigerPhoneInputFormatter(),
            ],
            suffixIcon: const Icon(
              Icons.phone_outlined,
              color: AppColors.muted,
              size: AppSizes.icon,
            ),
            validator: (String? value) => _validatePhone(strings, value),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            key: const Key('forgot_send_code'),
            label: strings.sendCode,
            loading: state.loading,
            onPressed: state.loading ? null : _sendCode,
          ),
        ],
      ),
    );
  }

  Widget _buildResetStep(AppLocalizations strings, ForgotPasswordState state) {
    return Form(
      key: _resetFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InfoText(strings.codeSent),
          const SizedBox(height: AppSpacing.lg),
          if (state.error != null) ...<Widget>[
            AppErrorBanner(
              key: const Key('forgot_error'),
              message: authErrorMessage(state.error!, strings),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          AppTextField(
            key: const Key('forgot_code_field'),
            controller: _code,
            hintText: strings.otpCodeHint,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            validator: (String? value) => _validateCode(strings, value),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            key: const Key('forgot_password_field'),
            controller: _password,
            hintText: strings.newPasswordLabel,
            obscure: true,
            textInputAction: TextInputAction.next,
            validator: (String? value) => _validatePassword(strings, value),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            key: const Key('forgot_confirmation_field'),
            controller: _confirmation,
            hintText: strings.confirmPasswordLabel,
            obscure: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _changePassword(),
            validator: (String? value) => _validateConfirmation(strings, value),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            key: const Key('forgot_change_password'),
            label: strings.changePassword,
            loading: state.loading,
            onPressed: state.loading ? null : _changePassword,
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: AppTextButton(
              key: const Key('forgot_resend'),
              label: _resendSeconds > 0
                  ? '${strings.resendCode} ($_resendSeconds s)'
                  : strings.resendCode,
              variant: AppTextButtonVariant.muted,
              onPressed: state.loading || _resendSeconds > 0
                  ? null
                  : _resendCode,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.strings, required this.onReturn});

  final AppLocalizations strings;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const SizedBox(height: AppSpacing.xxl),
        const Icon(
          Icons.check_circle_outline,
          color: AppColors.tertiary,
          size: 64,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          strings.resetSuccess,
          style: AppTextStyles.title,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        AppTextButton(
          key: const Key('forgot_success_return'),
          label: strings.backToLogin,
          onPressed: onReturn,
        ),
      ],
    );
  }
}
