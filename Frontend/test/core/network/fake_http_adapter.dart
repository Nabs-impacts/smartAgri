import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef FakeHttpHandler = Future<ResponseBody> Function(RequestOptions options);

class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.handler);

  final FakeHttpHandler handler;
  final List<RequestSnapshot> requests = <RequestSnapshot>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(
      RequestSnapshot(
        method: options.method,
        path: options.path,
        authorization: options.headers['Authorization'] as String?,
        data: options.data,
      ),
    );
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

class RequestSnapshot {
  const RequestSnapshot({
    required this.method,
    required this.path,
    required this.authorization,
    required this.data,
  });

  final String method;
  final String path;
  final String? authorization;
  final Object? data;
}

ResponseBody jsonResponse(int statusCode, Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

ResponseBody errorResponse(int statusCode, String code, String message) {
  return jsonResponse(statusCode, <String, dynamic>{
    'error': <String, dynamic>{
      'code': code,
      'message': message,
      'details': null,
    },
  });
}
