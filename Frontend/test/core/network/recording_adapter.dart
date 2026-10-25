import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef RecordingHandler = Future<ResponseBody> Function(
  RequestOptions options,
  RecordedRequest request,
);

class RecordedRequest {
  RecordedRequest({
    required this.method,
    required this.path,
    required this.headers,
    required this.data,
  });

  final String method;
  final String path;
  final Map<String, dynamic> headers;
  final Object? data;
}

class RecordingAdapter implements HttpClientAdapter {
  RecordingAdapter(this.handler);

  final RecordingHandler handler;
  final List<RecordedRequest> requests = <RecordedRequest>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final RecordedRequest request = RecordedRequest(
      method: options.method,
      path: options.path,
      headers: Map<String, dynamic>.of(options.headers),
      data: options.data,
    );
    requests.add(request);
    return handler(options, request);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody body(int statusCode, Object? data) {
  return ResponseBody.fromString(
    data == null ? '' : jsonEncode(data),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}
