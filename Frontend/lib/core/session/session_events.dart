import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class SessionEvents {
  final StreamController<void> _expired = StreamController<void>.broadcast();

  Stream<void> get sessionExpired => _expired.stream;

  void emitSessionExpired() {
    if (!_expired.isClosed) {
      _expired.add(null);
    }
  }

  Future<void> dispose() => _expired.close();
}

final Provider<SessionEvents> sessionEventsProvider = Provider<SessionEvents>((
  Ref ref,
) {
  final SessionEvents events = SessionEvents();
  ref.onDispose(events.dispose);
  return events;
});
