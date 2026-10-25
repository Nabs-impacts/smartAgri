enum DiagnosticStatus {
  pending('pending'),
  processing('processing'),
  done('done'),
  needsReview('needs_review'),
  failed('failed');

  const DiagnosticStatus(this.apiValue);

  final String apiValue;

  bool get isTerminal =>
      this == DiagnosticStatus.done ||
      this == DiagnosticStatus.needsReview ||
      this == DiagnosticStatus.failed;

  static DiagnosticStatus fromApi(Object? value) {
    for (final DiagnosticStatus status in DiagnosticStatus.values) {
      if (status.apiValue == value) {
        return status;
      }
    }
    return DiagnosticStatus.pending;
  }
}
