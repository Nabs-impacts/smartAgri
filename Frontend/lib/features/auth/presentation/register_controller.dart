import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/language_controller.dart';
import '../../../core/network/api_exception.dart';
import '../data/auth_repository.dart';
import '../data/pending_consents_store.dart';
import '../domain/consent_choice.dart';

class RegisterState {
  const RegisterState({
    this.loading = false,
    this.error,
    this.phoneAlreadyUsed = false,
  });

  final bool loading;
  final ApiException? error;
  final bool phoneAlreadyUsed;
}

class RegisterController extends Notifier<RegisterState> {
  @override
  RegisterState build() => const RegisterState();

  Future<bool> submit({
    required String fullName,
    required String phone,
    required String password,
    required List<ConsentChoice> consents,
  }) async {
    if (state.loading) {
      return false;
    }
    state = const RegisterState(loading: true);
    try {
      final String language = ref.read(languageControllerProvider).apiCode;
      await ref
          .read(authRepositoryProvider)
          .register(
            phone: phone,
            fullName: fullName,
            language: language,
            password: password,
          );
      await ref.read(pendingConsentsStoreProvider).add(consents);
      if (ref.mounted) {
        state = const RegisterState();
      }
      return true;
    } on ApiException catch (error) {
      if (ref.mounted) {
        state = RegisterState(
          error: error,
          phoneAlreadyUsed: error.code == 'CONFLICT' || error.statusCode == 409,
        );
      }
      return false;
    }
  }
}

final NotifierProvider<RegisterController, RegisterState>
registerControllerProvider =
    NotifierProvider.autoDispose<RegisterController, RegisterState>(
      RegisterController.new,
    );
