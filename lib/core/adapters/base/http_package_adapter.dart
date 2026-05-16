import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../contracts/http_client_adapter.dart';
import '../../models/request_options.dart';
import '../../models/response.dart';
import '../../models/http_protocol_preference.dart';

/// Base adapter mapping [RequestOptions] to standard [http.Client] implementations.
abstract base class HttpPackageAdapter implements HttpClientAdapter {
  /// The underlying HTTP client engine provided by the concrete implementation.
  http.Client get httpClient;

  @override
  Future<Response<dynamic>> fetch(RequestOptions options) async {
    _warnUnsupportedProtocol(options.protocolPreference);

    final uri = _buildUri(options);
    final request = http.Request(options.method, uri);

    _applyHeaders(request, options.headers);

    if (options.data != null) {
      _applyBody(request, options.data);
    }

    try {
      Future<http.StreamedResponse> responseFuture = httpClient.send(request);

      if (options.connectTimeout != null) {
        responseFuture = responseFuture.timeout(options.connectTimeout!);
      }

      final streamedResponse = await responseFuture;
      
      // TODO: Apply receiveTimeout to stream read operations.
      final response = await http.Response.fromStream(streamedResponse);

      return Response(
        data: response.body, // TODO: Inject ResponseTransformers here.
        statusCode: response.statusCode,
        statusMessage: response.reasonPhrase,
        headers: _extractHeaders(response.headers),
        requestOptions: options,
      );
    } on TimeoutException catch (e) {
      // TODO: Map to specific QuioException.
      throw Exception('Connection timeout execution: $e');
    }
  }

  @override
  void close({bool force = false}) {
    httpClient.close();
  }

  Uri _buildUri(RequestOptions options) {
    final base = Uri.parse(options.path);
    if (options.queryParameters.isEmpty) return base;

    final merged = <String, String>{
      ...base.queryParameters,
      ...options.queryParameters.map((k, v) => MapEntry(k, v.toString())),
    };

    return base.replace(queryParameters: merged);
  }

  void _applyHeaders(http.Request request, Map<String, dynamic> headers) {
    headers.forEach((key, value) {
      request.headers[key] = value.toString();
    });
  }

  void _applyBody(http.Request request, dynamic data) {
    switch (data) {
      case String s:
        request.body = s;
      case List<int> bytes:
        request.bodyBytes = bytes;
      case Map() || List():
        if (!request.headers.containsKey('content-type')) {
          request.headers['content-type'] = 'application/json; charset=utf-8';
        }
        request.body = jsonEncode(data);
      default:
        request.body = data.toString();
    }
  }

  Map<String, List<String>> _extractHeaders(Map<String, String> httpHeaders) {
    final result = <String, List<String>>{};
    // package:http merges duplicate headers via comma-separated strings.
    httpHeaders.forEach((key, value) {
      result[key] = value.split(',').map((e) => e.trim()).toList();
    });
    return result;
  }

  void _warnUnsupportedProtocol(HttpProtocolPreference preference) {
    if (preference == HttpProtocolPreference.http3) {
      // TODO: Refine protocol capability checks via an internal Capability System.
    }
  }
}