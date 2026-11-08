enum SyncStatus { idle, syncing, offline, error }

class SyncSnapshot {
  const SyncSnapshot({
    required this.status,
    required this.pendingCount,
    required this.failedCount,
    this.lastSyncAt,
  });

  final SyncStatus status;
  final int pendingCount;
  final int failedCount;
  final DateTime? lastSyncAt;
}
