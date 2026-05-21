import 'request_options.dart';

/// HTTP transaction result.
class Response<T> {
  final T? data;
  final int? statusCode;
  final String? statusMessage;
  final Map<String, List<String>> headers;
  final RequestOptions requestOptions;

  const Response({
    this.data,
    this.statusCode,
    this.statusMessage,
    required this.headers,
    required this.requestOptions,
  });
}
