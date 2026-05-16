import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../contracts/http_client_adapter.dart';
import '../../models/request_options.dart';
import '../../models/response.dart';
import '../../models/http_protocol_preference.dart';
import '../../exceptions/quio_exception.dart';

/// Base adapter mapping [RequestOptions] to standard [http.Client] implementations.
abstract base class HttpPackageAdapter implements HttpClientAdapter {
  /// The underlying HTTP client engine provided by the concrete implementation.
  http.Client get httpClient;

  @override
  Future<Response<dynamic>> fetch(RequestOptions options) async {
    _warnUnsupportedProtocol(options.protocolPreference);

    final request = http.Request(options.method, options.uri);

    try {
      _applyHeaders(request, options.headers);

      if (options.data != null) {
        _applyBody(request, options.data);
      }

      Future<http.StreamedResponse> responseFuture = httpClient.send(request);

      // Connection phase timeout. Applies strictly to the initial handshake.
      if (options.connectTimeout != null) {
        responseFuture = responseFuture.timeout(
          options.connectTimeout!,
          onTimeout: () => throw TimeoutException(
            'Connection timeout of ${options.connectTimeout?.inMilliseconds}ms exceeded',
            options.connectTimeout,
          ),
        );
      }

      final streamedResponse = await responseFuture;
      
      Stream<List<int>> responseStream = streamedResponse.stream;

      // Data transmission phase timeout. 
      // Injected into the stream pipeline to catch stalling during chunk reads.
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

      final response = await http.Response.fromStream(wrappedStreamedResponse);

      return Response(
        data: response.body, // TODO: Inject ResponseTransformers here.
        statusCode: response.statusCode,
        statusMessage: response.reasonPhrase,
        headers: _extractHeaders(response.headers),
        requestOptions: options,
      );
    } on JsonUnsupportedObjectError catch (e, stackTrace) {
      throw QuioException(
        requestOptions: options,
        type: QuioErrorType.requestSerializationError,
        error: e,
        stackTrace: stackTrace,
        message: 'Failed to serialize request payload: Unsupported object.',
      );
    } on http.ClientException catch (e, stackTrace) {
      throw QuioException(
        requestOptions: options,
        type: QuioErrorType.connectionError,
        error: e,
        stackTrace: stackTrace,
        message: e.message,
      );
    } on TimeoutException catch (e, stackTrace) {
      // Disambiguate timeout origins based on the pipeline stage that threw.
      final isConnectTimeout = e.message?.startsWith('Connection') ?? false;
      
      throw QuioException(
        requestOptions: options,
        type: isConnectTimeout ? QuioErrorType.connectionTimeout : QuioErrorType.receiveTimeout,
        error: e,
        stackTrace: stackTrace,
        message: e.message,
      );
    } catch (e, stackTrace) {
      throw QuioException(
        requestOptions: options,
        type: QuioErrorType.unknown,
        error: e,
        stackTrace: stackTrace,
        message: 'Engine adapter encountered an unhandled fault.',
      );
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
