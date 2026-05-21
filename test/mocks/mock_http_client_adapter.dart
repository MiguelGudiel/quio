import 'dart:async';

import 'package:quio/core/adapters/contracts/http_client_adapter.dart';
import 'package:quio/core/exceptions/quio_exception.dart';
import 'package:quio/core/models/request_options.dart';
import 'package:quio/core/models/response.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Recorded call — what the adapter actually received
// ─────────────────────────────────────────────────────────────────────────────

/// Snapshot of a single [fetch] invocation. Useful for assertion on arguments.
class RecordedCall {
  final RequestOptions options;
  final DateTime timestamp;

  RecordedCall(this.options) : timestamp = DateTime.now();

  String get method => options.method;
  Uri get uri => options.uri;
  dynamic get data => options.data;
  Map<String, dynamic> get headers => options.headers;
  Map<String, dynamic> get queryParameters => options.queryParameters;

  @override
  String toString() => 'RecordedCall(${options.method} ${options.uri})';
}

// ─────────────────────────────────────────────────────────────────────────────
// Behaviour — what the adapter should do for a given invocation index
// ─────────────────────────────────────────────────────────────────────────────

/// Internal sealed-ish class representing one scheduled behaviour.
abstract class _Behaviour {
  Future<Response<dynamic>> execute(RequestOptions options);
}

class _SuccessBehaviour implements _Behaviour {
  final dynamic body;
  final int statusCode;
  final String statusMessage;
  final Map<String, List<String>> headers;

  _SuccessBehaviour({
    required this.body,
    required this.statusCode,
    required this.statusMessage,
    required this.headers,
  });

  @override
  Future<Response<dynamic>> execute(RequestOptions options) async {
    return Response(
      data: body,
      statusCode: statusCode,
      statusMessage: statusMessage,
      headers: headers,
      requestOptions: options,
    );
  }
}

class _ErrorBehaviour implements _Behaviour {
  final Object error;

  _ErrorBehaviour(this.error);

  @override
  Future<Response<dynamic>> execute(RequestOptions options) {
    return Future.error(error);
  }
}

class _DelayedBehaviour implements _Behaviour {
  final _Behaviour inner;
  final Duration delay;

  _DelayedBehaviour({required this.inner, required this.delay});

  @override
  Future<Response<dynamic>> execute(RequestOptions options) async {
    await Future.delayed(delay);
    return inner.execute(options);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MockHttpClientAdapter
// ─────────────────────────────────────────────────────────────────────────────

/// A programmable fake [HttpClientAdapter] for unit tests.
///
/// **Usage — fixed response:**
/// ```dart
/// final adapter = MockHttpClientAdapter()
///   ..whenFetch().thenReturn(body: '{"id":1}', statusCode: 200);
/// ```
///
/// **Usage — sequence of responses:**
/// ```dart
/// final adapter = MockHttpClientAdapter()
///   ..whenFetch().thenReturnSequence([
///     MockResponse.success(body: '{"id":1}'),
///     MockResponse.success(body: '{"id":2}'),
///     MockResponse.error(QuioException(...)),
///   ]);
/// ```
///
/// **Inspection:**
/// ```dart
/// expect(adapter.callCount, 1);
/// expect(adapter.lastCall.method, 'POST');
/// ```
final class MockHttpClientAdapter implements HttpClientAdapter {
  final List<RecordedCall> _calls = [];
  final List<_Behaviour> _queue = [];
  _Behaviour? _defaultBehaviour;
  bool _isClosed = false;

  // ── Inspection ──────────────────────────────────────────────────────────────

  /// All recorded invocations in chronological order.
  List<RecordedCall> get calls => List.unmodifiable(_calls);

  /// Total number of [fetch] invocations.
  int get callCount => _calls.length;

  /// The most recent call. Throws if no calls have been made.
  RecordedCall get lastCall {
    if (_calls.isEmpty) throw StateError('No calls have been recorded yet.');
    return _calls.last;
  }

  /// The first call. Throws if no calls have been made.
  RecordedCall get firstCall {
    if (_calls.isEmpty) throw StateError('No calls have been recorded yet.');
    return _calls.first;
  }

  /// Whether [close] was called.
  bool get isClosed => _isClosed;

  // ── Fluent DSL ───────────────────────────────────────────────────────────────

  /// Entry point for programming the adapter's behaviour.
  ///
  /// ```dart
  /// adapter.whenFetch().thenReturn(body: '{}', statusCode: 200);
  /// ```
  _AdapterStub whenFetch() => _AdapterStub(this);

  /// Resets all scheduled behaviours and recorded calls.
  void reset() {
    _calls.clear();
    _queue.clear();
    _defaultBehaviour = null;
    _isClosed = false;
  }

  // ── Internal registration (called by _AdapterStub) ───────────────────────

  void _enqueue(_Behaviour b) => _queue.add(b);
  void _setDefault(_Behaviour b) => _defaultBehaviour = b;

  // ── HttpClientAdapter contract ───────────────────────────────────────────────

  @override
  Future<Response<dynamic>> fetch(RequestOptions options) async {
    if (_isClosed) {
      throw StateError('MockHttpClientAdapter has been closed.');
    }

    _calls.add(RecordedCall(options));

    final behaviour = _queue.isNotEmpty
        ? _queue.removeAt(0)
        : _defaultBehaviour ?? _fallback(options);

    return behaviour.execute(options);
  }

  @override
  void close({bool force = false}) => _isClosed = true;

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Default when nothing was programmed — returns 200 OK with empty body.
  _Behaviour _fallback(RequestOptions options) => _SuccessBehaviour(
        body: '',
        statusCode: 200,
        statusMessage: 'OK',
        headers: const {},
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Fluent stub builder
// ─────────────────────────────────────────────────────────────────────────────

/// Returned by [MockHttpClientAdapter.whenFetch] to configure the response.
final class _AdapterStub {
  final MockHttpClientAdapter _adapter;

  _AdapterStub(this._adapter);

  /// Schedules a successful HTTP response for the next call.
  void thenReturn({
    dynamic body = '',
    int statusCode = 200,
    String statusMessage = 'OK',
    Map<String, List<String>> headers = const {
      'content-type': ['application/json'],
    },
    Duration? delay,
  }) {
    _Behaviour b = _SuccessBehaviour(
      body: body,
      statusCode: statusCode,
      statusMessage: statusMessage,
      headers: headers,
    );

    if (delay != null) {
      b = _DelayedBehaviour(inner: b, delay: delay);
    }

    _adapter._enqueue(b);
  }

  /// Schedules a default response returned for every call that has no
  /// explicitly queued behaviour.
  void thenAlwaysReturn({
    dynamic body = '',
    int statusCode = 200,
    String statusMessage = 'OK',
    Map<String, List<String>> headers = const {
      'content-type': ['application/json'],
    },
    Duration? delay,
  }) {
    _Behaviour b = _SuccessBehaviour(
      body: body,
      statusCode: statusCode,
      statusMessage: statusMessage,
      headers: headers,
    );

    if (delay != null) {
      b = _DelayedBehaviour(inner: b, delay: delay);
    }

    _adapter._setDefault(b);
  }

  /// Schedules an error to be thrown for the next call.
  void thenThrow(Object error, {Duration? delay}) {
    _Behaviour b = _ErrorBehaviour(error);

    if (delay != null) {
      b = _DelayedBehaviour(inner: b, delay: delay);
    }

    _adapter._enqueue(b);
  }

  /// Schedules a [QuioException] for the next call. Convenience over [thenThrow].
  void thenThrowQuioException({
    required RequestOptions requestOptions,
    QuioErrorType type = QuioErrorType.unknown,
    String? message,
    int? statusCode,
  }) {
    final response = statusCode != null
        ? Response(
            statusCode: statusCode,
            statusMessage: 'Error',
            headers: const {},
            requestOptions: requestOptions,
          )
        : null;

    thenThrow(QuioException(
      requestOptions: requestOptions,
      response: response,
      type: type,
      message: message,
    ));
  }

  /// Programs a finite sequence of responses consumed in order (FIFO).
  /// After the sequence is exhausted the adapter falls back to [_defaultBehaviour].
  void thenReturnSequence(List<MockResponse> responses) {
    for (final r in responses) {
      if (r._error != null) {
        _adapter._enqueue(_ErrorBehaviour(r._error!));
      } else {
        _adapter._enqueue(_SuccessBehaviour(
          body: r._body,
          statusCode: r._statusCode,
          statusMessage: r._statusMessage,
          headers: r._headers,
        ));
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MockResponse — value object for thenReturnSequence
// ─────────────────────────────────────────────────────────────────────────────

/// Value object used in [_AdapterStub.thenReturnSequence].
final class MockResponse {
  final dynamic _body;
  final int _statusCode;
  final String _statusMessage;
  final Map<String, List<String>> _headers;
  final Object? _error;

  const MockResponse._({
    dynamic body,
    int statusCode = 200,
    String statusMessage = 'OK',
    Map<String, List<String>> headers = const {
      'content-type': ['application/json'],
    },
    Object? error,
  })  : _body = body,
        _statusCode = statusCode,
        _statusMessage = statusMessage,
        _headers = headers,
        _error = error;

  factory MockResponse.success({
    dynamic body = '',
    int statusCode = 200,
    String statusMessage = 'OK',
    Map<String, List<String>> headers = const {
      'content-type': ['application/json'],
    },
  }) =>
      MockResponse._(
        body: body,
        statusCode: statusCode,
        statusMessage: statusMessage,
        headers: headers,
      );

  factory MockResponse.error(Object error) => MockResponse._(error: error);
}
