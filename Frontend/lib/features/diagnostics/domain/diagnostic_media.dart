class DiagnosticMedia {
  const DiagnosticMedia({required this.id, required this.kind, this.url});

  final String id;
  final String kind;
  final String? url;

  factory DiagnosticMedia.fromJson(Map<String, dynamic> json) {
    return DiagnosticMedia(
      id: json['id'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      url: json['url'] as String?,
    );
  }
}
