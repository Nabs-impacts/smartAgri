import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/strings_provider.dart';
import '../../../core/phone/niger_phone.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_error_banner.dart';
import '../../../design_system/components/app_otp_field.dart';
import '../../../design_system/components/app_text_button.dart';
import '../../../design_system/tokens.dart';
import '../domain/auth_error_messages.dart';
import '../domain/auth_purpose.dart';
import '../domain/otp_args.dart';
import 'otp_controller.dart';

String maskPhone(String phone) {
  final String? normalized = NigerPhone.normalize(phone);
  final String digits = (normalized ?? phone).replaceAll(RegExp(r'\D'), '');
  if (digits.length < 8) {
    return phone;
  }
  final String local = digits.substring(digits.length - 8);
  final String last = local.substring(4);
  return '+227 •• •• ${last.substring(0, 2)} ${last.substring(2)}';
}

class OtpPage extends ConsumerStatefulWidget {
  const OtpPage({required this.args, super.key});

  final OtpArgs args;

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  final GlobalKey<AppOtpFieldState> _otpKey = GlobalKey<AppOtpFieldState>();
  Timer? _countdownTimer;
  int _resendSeconds = 60;
  String _code = '';
  bool _fieldError = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
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

  void _onChanged(String value) {
    setState(() {
      _code = value;
      if (_fieldError && value.isNotEmpty) {
        _fieldError = false;
      }
    });
  }

  Future<void> _verify() async {
    if (_code.length != 6) {
      return;
    }
    FocusScope.of(context).unfocus();
    final bool verified = await ref
        .read(otpControllerProvider.notifier)
        .verify(
          phone: widget.args.phone,
          code: _code,
          purpose: widget.args.purpose,
        );
    if (!verified && mounted) {
      final error = ref.read(otpControllerProvider).error;
      if (error != null && isInvalidCodeError(error)) {
        _otpKey.currentState?.clear();
        setState(() => _fieldError = true);
      }
    }
  }

  Future<void> _resend() async {
    final bool sent = await ref
        .read(otpControllerProvider.notifier)
        .resend(phone: widget.args.phone, purpose: widget.args.purpose);
    if (sent && mounted) {
      _startCountdown();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    final OtpState state = ref.watch(otpControllerProvider);
    final bool login = widget.args.purpose == AuthPurpose.login;

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
                  key: const Key('otp_back'),
                  label: strings.back,
                  variant: AppTextButtonVariant.muted,
                  onPressed: state.loading ? null : () => context.go('/login'),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                login ? strings.otpLoginTitle : strings.otpVerifyPhoneTitle,
                style: AppTextStyles.headline,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                strings.otpInstructions(maskPhone(widget.args.phone)),
                style: AppTextStyles.body.copyWith(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              if (state.error != null) ...<Widget>[
                AppErrorBanner(
                  key: const Key('otp_error'),
                  message: authErrorMessage(state.error!, strings),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              AppOtpField(
                key: _otpKey,
                onChanged: _onChanged,
                error: _fieldError,
                semanticLabel: strings.otpCodeLabel,
                autofocus: true,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                key: const Key('otp_submit'),
                label: strings.otpValidate,
                loading: state.loading,
                onPressed: state.loading || _code.length != 6 ? null : _verify,
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: AppTextButton(
                  key: const Key('otp_resend'),
                  label: _resendSeconds > 0
                      ? '${strings.resendCode} ($_resendSeconds s)'
                      : strings.resendCode,
                  variant: AppTextButtonVariant.muted,
                  onPressed: state.loading || _resendSeconds > 0
                      ? null
                      : _resend,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
