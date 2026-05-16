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

    final request = http.Request(options.method, options.uri);

    _applyHeaders(request, options.headers);

    if (options.data != null) {
      _applyBody(request, options.data);
    }

    try {
      Future<http.StreamedResponse> responseFuture = httpClient.send(request);

      // Apply connectTimeout to the initial connection phase.
      if (options.connectTimeout != null) {
        responseFuture = responseFuture.timeout(options.connectTimeout!);
      }

      final streamedResponse = await responseFuture;
      
      // Extract the raw byte stream from the response.
      Stream<List<int>> responseStream = streamedResponse.stream;

      // Apply receiveTimeout to the data stream chunks.
      // This throws a TimeoutException if the gap between chunks exceeds the duration.
      if (options.receiveTimeout != null) {
        responseStream = responseStream.timeout(
          options.receiveTimeout!,
          onTimeout: (EventSink<List<int>> sink) {
            sink.addError(
              TimeoutException(
                'Receive timeout of ${options.receiveTimeout?.inMilliseconds}ms exceeded',
                options.receiveTimeout,
              ),
            );
            sink.close();
          },
        );
      }

      // Reconstruct the StreamedResponse with the timeout-injected stream
      final wrappedStreamedResponse = http.StreamedResponse(
        responseStream,
        streamedResponse.statusCode,
        contentLength: streamedResponse.contentLength,
        request: streamedResponse.request,
        headers: streamedResponse.headers,
        isRedirect: streamedResponse.isRedirect,
        persistentConnection: streamedResponse.persistentConnection,
        reasonPhrase: streamedResponse.reasonPhrase,
      );

      // Process the stream into a final response string
      final response = await http.Response.fromStream(wrappedStreamedResponse);

      return Response(
        data: response.body, // TODO: Inject ResponseTransformers here.
        statusCode: response.statusCode,
        statusMessage: response.reasonPhrase,
        headers: _extractHeaders(response.headers),
        requestOptions: options,
      );
    } on TimeoutException catch (e) {
      // TODO: Map to specific QuioException (e.g. QuioErrorType.connectionTimeout / receiveTimeout).
      throw Exception('Timeout execution: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected adapter error: $e');
    }
  }

  @override
  void close({bool force = false}) {
    httpClient.close();
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
