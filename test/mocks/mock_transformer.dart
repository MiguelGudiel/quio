import 'package:quio/core/transformers/transformer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MockTransformer
// ─────────────────────────────────────────────────────────────────────────────

/// A controllable fake [Transformer] for unit tests.
///
/// By default it acts as a transparent pass-through. Override [onTransformRequest]
/// or [onTransformResponse] to inject custom logic or exceptions.
///
/// ```dart
/// final transformer = MockTransformer()
///   ..onTransformResponse = (data) async => jsonDecode(data as String);
/// ```
final class MockTransformer implements Transformer {
  /// Invocations recorded for [transformRequest].
  final List<dynamic> requestCalls = [];

  /// Invocations recorded for [transformResponse].
  final List<dynamic> responseCalls = [];

  /// Override to customise request transformation. Defaults to pass-through.
  Future<dynamic> Function(dynamic data)? onTransformRequest;

  /// Override to customise response transformation. Defaults to pass-through.
  Future<dynamic> Function(dynamic data)? onTransformResponse;

  /// When set, [transformRequest] will throw this object.
  Object? requestError;

  /// When set, [transformResponse] will throw this object.
  Object? responseError;

  @override
  Future<dynamic> transformRequest(dynamic data) async {
    requestCalls.add(data);

    if (requestError != null) throw requestError!;
    return onTransformRequest != null ? onTransformRequest!(data) : data;
  }

  @override
  Future<dynamic> transformResponse(dynamic data) async {
    responseCalls.add(data);

    if (responseError != null) throw responseError!;
    return onTransformResponse != null ? onTransformResponse!(data) : data;
  }

  /// How many times [transformRequest] was called.
  int get requestCallCount => requestCalls.length;

  /// How many times [transformResponse] was called.
  int get responseCallCount => responseCalls.length;

  /// Resets all recorded calls and overrides.
  void reset() {
    requestCalls.clear();
    responseCalls.clear();
    onTransformRequest = null;
    onTransformResponse = null;
    requestError = null;
    responseError = null;
  }
}