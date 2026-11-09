enum CycleStatus {
  planned('planned'),
  growing('growing'),
  harvested('harvested'),
  failed('failed');

  const CycleStatus(this.code);

  final String code;

  static CycleStatus fromCode(Object? value) {
    for (final CycleStatus status in CycleStatus.values) {
      if (status.code == value) {
        return status;
      }
    }
    return CycleStatus.planned;
  }

  bool canTransitionTo(CycleStatus next) {
    if (next == this) {
      return true;
    }
    return switch (this) {
      CycleStatus.planned => next == CycleStatus.growing,
      CycleStatus.growing =>
        next == CycleStatus.harvested || next == CycleStatus.failed,
      CycleStatus.harvested || CycleStatus.failed => false,
    };
  }
}
