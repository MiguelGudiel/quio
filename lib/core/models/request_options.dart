import 'http_protocol_preference.dart';
import '../transformers/transformer.dart';

/// Configuration for an impending HTTP request.
class RequestOptions {
  final String baseUrl;
  final String path;
  final String method;
  final Map<String, dynamic> headers;
  final Map<String, dynamic> queryParameters;
  final dynamic data;
  final Duration? connectTimeout;
  final Duration? receiveTimeout;
  final HttpProtocolPreference protocolPreference;
  final Transformer? transformer;

  RequestOptions({
    this.baseUrl = '',
    required this.path,
    this.method = 'GET',
    this.headers = const {},
    this.queryParameters = const {},
    this.data,
    this.connectTimeout,
    this.receiveTimeout,
    this.protocolPreference = HttpProtocolPreference.auto,
    this.transformer,
  });

  /// Resolves the final absolute URI.
  /// Handles base URL concatenation and query parameter merging.
  Uri get uri {
    String fullUrl = path;
    
    // Fast path: bypass concatenation if path is already an absolute URL.
    if (!fullUrl.startsWith(RegExp(r'^https?://'))) {
      if (baseUrl.isNotEmpty) {
        // Normalize slashes to prevent mangled URIs.
        if (baseUrl.endsWith('/') && fullUrl.startsWith('/')) {
          fullUrl = baseUrl + fullUrl.substring(1);
        } else if (!baseUrl.endsWith('/') && !fullUrl.startsWith('/')) {
          fullUrl = '$baseUrl/$fullUrl';
        } else {
          fullUrl = baseUrl + fullUrl;
        }
      }
    }

    final baseUri = Uri.parse(fullUrl);
    if (queryParameters.isEmpty) return baseUri;

    final mergedQuery = <String, String>{
      ...baseUri.queryParameters,
      ...queryParameters.map((k, v) => MapEntry(k, v.toString())),
    };

    return baseUri.replace(queryParameters: mergedQuery);
  }

  RequestOptions copyWith({
    String? baseUrl,
    String? path,
    String? method,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
    dynamic data,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    HttpProtocolPreference? protocolPreference,
    Transformer? transformer,
  }) {
    return RequestOptions(
      baseUrl: baseUrl ?? this.baseUrl,
      path: path ?? this.path,
      method: method ?? this.method,
      headers: headers ?? this.headers,
      queryParameters: queryParameters ?? this.queryParameters,
      data: data ?? this.data,
      connectTimeout: connectTimeout ?? this.connectTimeout,
      receiveTimeout: receiveTimeout ?? this.receiveTimeout,
      protocolPreference: protocolPreference ?? this.protocolPreference,
      transformer: transformer ?? this.transformer,
    );
  }
}
