import 'dart:convert';
import 'dart:isolate';

import 'transformer.dart';

final class JsonIsolateTransformer implements Transformer {
  static const int _isolateThresholdBytes = 10 * 1024;

  @override
  Future<dynamic> transformRequest(dynamic data) async {
    if (data is Map || data is List) {
      return Isolate.run(() => _encode(data));
    }
    return data;
  }

  @override
  Future<dynamic> transformResponse(dynamic data) async {
    if (data is! String || data.isEmpty) return data;

    if (data.length < _isolateThresholdBytes) {
      return _decode(data);
    }

    return Isolate.run(() => _decode(data));
  }

  static String _encode(dynamic payload) {
    return jsonEncode(payload);
  }

  static dynamic _decode(String payload) {
    try {
      return jsonDecode(payload);
    } on FormatException {
      // Fallback for non-JSON payloads disguised with JSON content-types
      // or raw string responses.
      return payload;
    }
  }
}