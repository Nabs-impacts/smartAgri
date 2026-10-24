import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/auth_repository.dart';
import '../domain/auth_purpose.dart';

enum ForgotPasswordStep { request, reset }

class ForgotPasswordState {
  const ForgotPasswordState({
    this.step = ForgotPasswordStep.request,
    this.loading = false,
    this.error,
    this.success = false,
  });

  final ForgotPasswordStep step;
  final bool loading;
  final ApiException? error;
  final bool success;

  ForgotPasswordState copyWith({
    ForgotPasswordStep? step,
    bool? loading,
    ApiException? error,
    bool clearError = false,
    bool? success,
  }) {
    return ForgotPasswordState(
      step: step ?? this.step,
      loading: loading ?? this.loading,
      error: clearError ? null : error ?? this.error,
      success: success ?? this.success,
    );
  }
}

class ForgotPasswordController extends Notifier<ForgotPasswordState> {
  @override
  ForgotPasswordState build() => const ForgotPasswordState();

  Future<bool> requestOtp(String phone) async {
    if (state.loading) {
      return false;
    }
    state = state.copyWith(loading: true, clearError: true, success: false);
    try {
      await ref
          .read(authRepositoryProvider)
          .requestOtp(phone: phone, purpose: AuthPurpose.resetPassword);
      if (!ref.mounted) {
        return false;
      }
      state = state.copyWith(step: ForgotPasswordStep.reset, loading: false);
      return true;
    } on ApiException catch (error) {
      if (ref.mounted) {
        state = state.copyWith(loading: false, error: error);
      }
      return false;
    }
  }

  Future<bool> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    if (state.loading) {
      return false;
    }
    state = state.copyWith(loading: true, clearError: true, success: false);
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPassword(phone: phone, code: code, newPassword: newPassword);
      if (!ref.mounted) {
        return false;
      }
      state = state.copyWith(loading: false, success: true);
      return true;
    } on ApiException catch (error) {
      if (ref.mounted) {
        state = state.copyWith(loading: false, error: error);
      }
      return false;
    }
  }
}

final NotifierProvider<ForgotPasswordController, ForgotPasswordState>
forgotPasswordControllerProvider =
    NotifierProvider.autoDispose<ForgotPasswordController, ForgotPasswordState>(
      ForgotPasswordController.new,
    );
