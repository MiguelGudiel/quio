import 'http_protocol_preference.dart';

/// Request configuration parameters.
class RequestOptions {
  final String path;
  final String method;
  final Map<String, dynamic> headers;
  final Map<String, dynamic> queryParameters;
  final dynamic data;
  final Duration? connectTimeout;
  final Duration? receiveTimeout;
  final HttpProtocolPreference protocolPreference;

  RequestOptions({
    required this.path,
    this.method = 'GET',
    this.headers = const {},
    this.queryParameters = const {},
    this.data,
    this.connectTimeout,
    this.receiveTimeout,
    this.protocolPreference = HttpProtocolPreference.auto,
  });

  RequestOptions copyWith({
    String? path,
    String? method,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
    dynamic data,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    HttpProtocolPreference? protocolPreference,
  }) {
    return RequestOptions(
      path: path ?? this.path,
      method: method ?? this.method,
      headers: headers ?? this.headers,
      queryParameters: queryParameters ?? this.queryParameters,
      data: data ?? this.data,
      connectTimeout: connectTimeout ?? this.connectTimeout,
      receiveTimeout: receiveTimeout ?? this.receiveTimeout,
      protocolPreference: protocolPreference ?? this.protocolPreference,
    );
  }
}