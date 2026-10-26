import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/session/session_controller.dart';
import '../data/auth_repository.dart';
import '../data/consent_sync_service.dart';
import '../domain/auth_purpose.dart';
import '../domain/auth_session.dart';

class OtpState {
  const OtpState({this.loading = false, this.error});

  final bool loading;
  final ApiException? error;
}

class OtpController extends Notifier<OtpState> {
  @override
  OtpState build() => const OtpState();

  Future<bool> verify({
    required String phone,
    required String code,
    required AuthPurpose purpose,
  }) async {
    if (state.loading) {
      return false;
    }
    state = const OtpState(loading: true);
    try {
      final AuthSession session = await ref
          .read(authRepositoryProvider)
          .verifyOtp(phone: phone, code: code, purpose: purpose);
      await ref
          .read(sessionControllerProvider.notifier)
          .signedIn(session.tokens, true);
      unawaited(ref.read(consentSyncServiceProvider).retryPending());
      if (ref.mounted) {
        state = const OtpState();
      }
      return true;
    } on ApiException catch (error) {
      if (ref.mounted) {
        state = OtpState(error: error);
      }
      return false;
    }
  }

  Future<bool> resend({
    required String phone,
    required AuthPurpose purpose,
  }) async {
    if (state.loading) {
      return false;
    }
    state = const OtpState(loading: true);
    try {
      await ref
          .read(authRepositoryProvider)
          .requestOtp(phone: phone, purpose: purpose);
      if (ref.mounted) {
        state = const OtpState();
      }
      return true;
    } on ApiException catch (error) {
      if (ref.mounted) {
        state = OtpState(error: error);
      }
      return false;
    }
  }
}

final NotifierProvider<OtpController, OtpState> otpControllerProvider =
    NotifierProvider.autoDispose<OtpController, OtpState>(OtpController.new);
