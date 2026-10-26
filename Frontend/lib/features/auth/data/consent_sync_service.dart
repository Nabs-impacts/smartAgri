import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/session/session_state.dart';
import '../domain/consent_choice.dart';
import 'auth_repository.dart';
import 'pending_consents_store.dart';

class ConsentSyncService {
  ConsentSyncService({required this.repository, required this.store});

  final AuthRepository repository;
  final PendingConsentsStore store;

  bool _running = false;

  Future<void> retryPending() async {
    if (_running) {
      return;
    }
    final List<ConsentChoice> choices = store.read();
    if (choices.isEmpty) {
      return;
    }
    _running = true;
    try {
      await repository.acceptConsents(choices);
      await store.clear();
    } catch (_) {
    } finally {
      _running = false;
    }
  }
}

final Provider<ConsentSyncService> consentSyncServiceProvider =
    Provider<ConsentSyncService>(
      (Ref ref) => ConsentSyncService(
        repository: ref.watch(authRepositoryProvider),
        store: ref.watch(pendingConsentsStoreProvider),
      ),
    );

final Provider<ConsentSyncService> consentSyncStartupProvider =
    Provider<ConsentSyncService>((Ref ref) {
      final ConsentSyncService service = ref.watch(consentSyncServiceProvider);
      if (ref.read(sessionControllerProvider) == SessionState.authenticated) {
        unawaited(service.retryPending());
      }
      ref.listen<SessionState>(sessionControllerProvider, (
        SessionState? previous,
        SessionState next,
      ) {
        if (previous != SessionState.authenticated &&
            next == SessionState.authenticated) {
          unawaited(service.retryPending());
        }
      });
      return service;
    });
