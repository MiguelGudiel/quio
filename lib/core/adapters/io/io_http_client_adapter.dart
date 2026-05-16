import 'dart:convert';
import 'dart:io';

import '../contracts/http_client_adapter.dart';
import '../../models/http_protocol_preference.dart';
import '../../models/request_options.dart';
import '../../models/response.dart';

/// Native fallback adapter using dart:io. Supports HTTP/1.1 and HTTP/2.
final class IoHttpClientAdapter implements HttpClientAdapter {
  final HttpClient _client = HttpClient();

  @override
  Future<Response<dynamic>> fetch(RequestOptions options) async {
    _applyTimeouts(options);
    _warnUnsupportedProtocol(options.protocolPreference);

    final uri = _buildUri(options);
    final ioRequest = await _client.openUrl(options.method, uri);

    _applyHeaders(ioRequest, options.headers);

    if (options.data != null) {
      _writeBody(ioRequest, options.data);
    }

    final ioResponse = await ioRequest.close();

    final body = await ioResponse
        .transform(utf8.decoder) // Explicit UTF-8 decoding avoids SystemEncoding mismatches.
        .join();

    return Response(
      data: body,
      statusCode: ioResponse.statusCode,
      statusMessage: ioResponse.reasonPhrase,
      headers: _extractHeaders(ioResponse.headers),
      requestOptions: options,
    );
  }

  @override
  void close({bool force = false}) => _client.close(force: force);

  void _applyTimeouts(RequestOptions options) {
    if (options.connectTimeout != null) {
      _client.connectionTimeout = options.connectTimeout;
    }
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

  void _applyHeaders(HttpClientRequest request, Map<String, dynamic> headers) {
    headers.forEach((key, value) => request.headers.add(key, value));
  }

  void _writeBody(HttpClientRequest request, dynamic data) {
    switch (data) {
      case String s:
        request.write(s);
      case List<int> bytes:
        request.add(bytes);
      case Map() || List():
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(data));
      default:
        request.write(data.toString());
    }
  }

  Map<String, List<String>> _extractHeaders(HttpHeaders ioHeaders) {
    final result = <String, List<String>>{};
    ioHeaders.forEach((name, values) => result[name] = values);
    return result;
  }

  void _warnUnsupportedProtocol(HttpProtocolPreference preference) {
    if (preference == HttpProtocolPreference.http3) {
      // ignore: avoid_print
      print(
        '[Quio/IoAdapter] WARNING: HTTP/3 is not supported by dart:io. '
        'The request will proceed with the best protocol available.',
      );
    }
  }
}