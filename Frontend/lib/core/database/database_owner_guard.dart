import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/user_profile.dart';
import '../../features/profile/data/me_repository.dart';
import '../session/session_controller.dart';
import '../session/session_state.dart';
import 'app_database.dart';

class DatabaseOwnerGuard {
  DatabaseOwnerGuard(this.database);

  static const String ownerKey = 'owner_id';

  final AppDatabase database;
  Future<void> _queue = Future<void>.value();

  Future<void> handleUser(String? userId) {
    final Future<void> next = _queue.then((void _) => _apply(userId));
    _queue = next.then<void>(
      (void _) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return next;
  }

  Future<void> _apply(String? userId) async {
    if (userId == null) {
      await database.wipeAll();
      return;
    }
    final String? owner = await database.readMeta(ownerKey);
    if (owner == null) {
      await database.writeMeta(ownerKey, userId);
      return;
    }
    if (owner != userId) {
      await database.wipeAll();
      await database.writeMeta(ownerKey, userId);
    }
  }
}

final Provider<DatabaseOwnerGuard> databaseOwnerGuardProvider =
    Provider<DatabaseOwnerGuard>((Ref ref) {
      final DatabaseOwnerGuard guard = DatabaseOwnerGuard(
        ref.watch(appDatabaseProvider),
      );

      Future<void> apply() async {
        final SessionState session = ref.read(sessionControllerProvider);
        if (session == SessionState.unauthenticated) {
          await guard.handleUser(null);
        } else if (session == SessionState.authenticated) {
          final UserProfile? user = ref.read(currentUserProvider);
          if (user != null) {
            await guard.handleUser(user.id);
          }
        }
      }

      ref.listen<SessionState>(sessionControllerProvider, (
        SessionState? previous,
        SessionState next,
      ) {
        unawaited(apply());
      });
      ref.listen<UserProfile?>(currentUserProvider, (
        UserProfile? previous,
        UserProfile? next,
      ) {
        unawaited(apply());
      });
      unawaited(apply());
      return guard;
    });
