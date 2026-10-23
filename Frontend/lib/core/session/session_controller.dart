import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/token_store.dart';
import 'session_events.dart';
import 'session_state.dart';

class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    final TokenStore store = ref.watch(tokenStoreProvider);
    final SessionEvents events = ref.watch(sessionEventsProvider);
    final StreamSubscription<void> subscription = events.sessionExpired.listen((
      void _,
    ) {
      if (ref.mounted) {
        state = SessionState.unauthenticated;
      }
    });
    ref.onDispose(subscription.cancel);
    Future<void>.microtask(() => _restore(store));
    return SessionState.unknown;
  }

  Future<void> _restore(TokenStore store) async {
    final AuthTokens? tokens = await store.read();
    if (!ref.mounted) {
      return;
    }
    state = tokens == null
        ? SessionState.unauthenticated
        : SessionState.authenticated;
  }

  Future<void> signedIn(AuthTokens tokens, bool remember) async {
    await ref
        .read(tokenStoreProvider)
        .save(
          tokens.accessToken,
          tokens.refreshToken,
          tokens.expiresAt.difference(DateTime.now()).inSeconds,
          remember: remember,
        );
    if (ref.mounted) {
      state = SessionState.authenticated;
    }
  }

  Future<void> signedOut() async {
    await ref.read(tokenStoreProvider).clear();
    if (ref.mounted) {
      state = SessionState.unauthenticated;
    }
  }
}

final NotifierProvider<SessionController, SessionState>
sessionControllerProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);
