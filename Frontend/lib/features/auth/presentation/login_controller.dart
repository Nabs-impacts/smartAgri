import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/session/session_controller.dart';
import '../data/auth_repository.dart';
import '../domain/auth_session.dart';

class LoginState {
  const LoginState({this.loading = false, this.error});

  final bool loading;
  final ApiException? error;
}

class LoginController extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  Future<bool> submit({
    required String phone,
    required String password,
    required bool rememberMe,
  }) async {
    if (state.loading) {
      return false;
    }
    state = const LoginState(loading: true);
    try {
      final AuthSession session = await ref
          .read(authRepositoryProvider)
          .login(phone: phone, password: password);
      await ref
          .read(sessionControllerProvider.notifier)
          .signedIn(session.tokens, rememberMe);
      if (ref.mounted) {
        state = const LoginState();
      }
      return true;
    } on ApiException catch (error) {
      if (ref.mounted) {
        state = LoginState(error: error);
      }
      return false;
    }
  }
}

final NotifierProvider<LoginController, LoginState> loginControllerProvider =
    NotifierProvider.autoDispose<LoginController, LoginState>(
      LoginController.new,
    );
