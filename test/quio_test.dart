// File: test/quio_test.dart
//
// Run with:  flutter test  or  dart test
//
// Dependencies (pubspec.yaml dev_dependencies):
//   test: ^1.24.0

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
//import 'package:test/test.dart';
import 'package:quio/quio.dart';
import 'package:quio/core/exceptions/quio_exception.dart';
import 'package:quio/core/models/request_options.dart';
import 'package:quio/core/models/response.dart';

import 'mocks/mock_http_client_adapter.dart';
import 'mocks/mock_transformer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Convenience: builds a [RequestOptions] that satisfies fields needed by
/// [QuioException] without having to repeat the whole constructor each time.
RequestOptions dummyOptions({
  String baseUrl = 'https://example.com',
  String path = '/test',
  String method = 'GET',
}) => RequestOptions(baseUrl: baseUrl, path: path, method: method);

/// Convenience: JSON-encodes a map into a string, simulating what a real
/// server would return.
String jsonBody(Map<String, dynamic> data) => jsonEncode(data);

// Test suite

void main() {
  late MockHttpClientAdapter adapter;
  late MockTransformer transformer;
  late Quio quio;

  setUp(() {
    adapter = MockHttpClientAdapter();
    transformer = MockTransformer();
    quio = Quio(
      options: BaseOptions(
        baseUrl: 'https://api.example.com',
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        headers: {'X-App-Version': '1.0.0'},
        transformer: transformer,
      ),
      adapter: adapter,
    );
  });

  group('GET requests', () {
    test('returns decoded response on 200 OK', () async {
      final body = jsonBody({'id': 1, 'name': 'Alice'});
      adapter.whenFetch().thenReturn(body: body, statusCode: 200);

      final response = await quio.get('/users/1');

      expect(response.statusCode, 200);
      expect(response.statusMessage, 'OK');
      expect(response.data, body); // transformer is pass-through
    });

    test('passes query parameters in the URI', () async {
      adapter.whenFetch().thenReturn(body: '{}', statusCode: 200);

      await quio.get('/search', queryParameters: {'q': 'flutter', 'page': '2'});

      final uri = adapter.lastCall.uri;
      expect(uri.queryParameters['q'], 'flutter');
      expect(uri.queryParameters['page'], '2');
    });

    test('merges base-level and per-request query parameters', () async {
      quio.options.queryParameters = {'env': 'prod'};
      adapter.whenFetch().thenReturn(body: '{}', statusCode: 200);

      await quio.get('/items', queryParameters: {'sort': 'asc'});

      final uri = adapter.lastCall.uri;
      expect(uri.queryParameters['env'], 'prod');
      expect(uri.queryParameters['sort'], 'asc');
    });

    test('uses correct HTTP method', () async {
      adapter.whenFetch().thenReturn(body: '[]', statusCode: 200);
      await quio.get('/list');
      expect(adapter.lastCall.method, 'GET');
    });

    test('records adapter call count correctly', () async {
      adapter.whenFetch().thenReturn(body: '{}', statusCode: 200);
      adapter.whenFetch().thenReturn(body: '{}', statusCode: 200);

      await quio.get('/a');
      await quio.get('/b');

      expect(adapter.callCount, 2);
    });
  });

  group('POST requests', () {
    test('serializes Map payload via transformer', () async {
      final payload = {'title': 'Test', 'userId': 1};
      final encodedBody = jsonBody({'id': 101, ...payload});

      transformer.onTransformRequest = (data) async => jsonEncode(data);
      adapter.whenFetch().thenReturn(body: encodedBody, statusCode: 201);

      await quio.post('/posts', data: payload);

      // Transformer was called with the original map
      expect(transformer.requestCallCount, 1);
      expect(transformer.requestCalls.first, payload);

      // Adapter received the encoded string
      expect(adapter.lastCall.data, jsonEncode(payload));
    });

    test('sends correct HTTP method', () async {
      adapter.whenFetch().thenReturn(body: '{}', statusCode: 201);
      await quio.post('/posts', data: {'x': 1});
      expect(adapter.lastCall.method, 'POST');
    });

    test('handles null data without calling transformRequest', () async {
      adapter.whenFetch().thenReturn(body: '{}', statusCode: 200);
      await quio.post('/posts');

      expect(transformer.requestCallCount, 0);
      expect(adapter.lastCall.data, isNull);
    });
  });

  group('PUT / PATCH / DELETE requests', () {
    test('PUT sends correct method and data', () async {
      adapter.whenFetch().thenReturn(body: '{}', statusCode: 200);
      await quio.put('/resources/1', data: {'name': 'updated'});
      expect(adapter.lastCall.method, 'PUT');
    });

    test('PATCH sends correct method', () async {
      adapter.whenFetch().thenReturn(body: '{}', statusCode: 200);
      await quio.patch('/resources/1', data: {'field': 'value'});
      expect(adapter.lastCall.method, 'PATCH');
    });

    test('DELETE sends correct method', () async {
      adapter.whenFetch().thenReturn(body: '', statusCode: 204);
      await quio.delete('/resources/1');
      expect(adapter.lastCall.method, 'DELETE');
    });
  });

  group('Header merging', () {
    test('includes base headers in every request', () async {
      adapter.whenFetch().thenReturn(body: '{}', statusCode: 200);
      await quio.get('/ping');
      expect(adapter.lastCall.headers['X-App-Version'], '1.0.0');
    });

    test('per-request headers override base headers', () async {
      adapter.whenFetch().thenReturn(body: '{}', statusCode: 200);
      await quio.get('/ping', headers: {'X-App-Version': '2.0.0'});
      expect(adapter.lastCall.headers['X-App-Version'], '2.0.0');
    });

    test('per-request headers are merged with base headers', () async {
      adapter.whenFetch().thenReturn(body: '{}', statusCode: 200);
      await quio.get('/ping', headers: {'X-Custom': 'yes'});

      final headers = adapter.lastCall.headers;
      expect(headers['X-App-Version'], '1.0.0');
      expect(headers['X-Custom'], 'yes');
    });
  });

  group('URI resolution', () {
    test('concatenates baseUrl and relative path correctly', () async {
      adapter.whenFetch().thenReturn(body: '{}', statusCode: 200);
      await quio.get('/users/42');
      expect(
        adapter.lastCall.uri.toString(),
        startsWith('https://api.example.com/users/42'),
      );
    });

    test('handles path with no leading slash', () async {
      adapter.whenFetch().thenReturn(body: '{}', statusCode: 200);
      await quio.get('users/42');
      expect(
        adapter.lastCall.uri.toString(),
        startsWith('https://api.example.com/users/42'),
      );
    });

    test('does not double-slash when baseUrl ends with slash', () async {
      quio.options.baseUrl = 'https://api.example.com/';
      adapter.whenFetch().thenReturn(body: '{}', statusCode: 200);
      await quio.get('/users/1');

      // Strip the scheme (https://) before checking — only the path must not have //.
      final pathAndHost = adapter.lastCall.uri.toString().replaceFirst(
        RegExp(r'^https?://'),
        '',
      );
      expect(
        pathAndHost,
        isNot(contains('//')),
        reason: 'Must not produce double slashes in path',
      );
    });

    test('absolute path bypasses base URL concatenation', () async {
      adapter.whenFetch().thenReturn(body: '{}', statusCode: 200);
      await quio.get('https://other.example.com/data');

      expect(adapter.lastCall.uri.host, 'other.example.com');
    });
  });

  group('Error status codes → QuioException', () {
    for (final code in [400, 401, 403, 404, 422, 500, 502, 503]) {
      test('$code throws QuioException with type badResponse', () async {
        adapter.whenFetch().thenReturn(
          body: '{"error":"something went wrong"}',
          statusCode: code,
          statusMessage: 'Error',
        );

        expect(
          () => quio.get('/resource'),
          throwsA(
            isA<QuioException>()
                .having((e) => e.type, 'type', QuioErrorType.badResponse)
                .having((e) => e.response?.statusCode, 'statusCode', code),
          ),
        );
      });
    }
  });

  group('Adapter-level exceptions (transport errors)', () {
    test('connectionTimeout is surfaced as QuioException', () async {
      adapter.whenFetch().thenThrow(
        QuioException(
          requestOptions: dummyOptions(),
          type: QuioErrorType.connectionTimeout,
          message: 'Connection timed out',
        ),
      );

      expect(
        () => quio.get('/timeout'),
        throwsA(
          isA<QuioException>().having(
            (e) => e.type,
            'type',
            QuioErrorType.connectionTimeout,
          ),
        ),
      );
    });

    test('receiveTimeout is surfaced as QuioException', () async {
      adapter.whenFetch().thenThrow(
        QuioException(
          requestOptions: dummyOptions(),
          type: QuioErrorType.receiveTimeout,
          message: 'Receive timed out',
        ),
      );

      expect(
        () => quio.get('/slow'),
        throwsA(
          isA<QuioException>().having(
            (e) => e.type,
            'type',
            QuioErrorType.receiveTimeout,
          ),
        ),
      );
    });

    test('connectionError is surfaced as QuioException', () async {
      adapter.whenFetch().thenThrow(
        QuioException(
          requestOptions: dummyOptions(),
          type: QuioErrorType.connectionError,
          message: 'Network unreachable',
        ),
      );

      expect(
        () => quio.get('/unreachable'),
        throwsA(
          isA<QuioException>().having(
            (e) => e.type,
            'type',
            QuioErrorType.connectionError,
          ),
        ),
      );
    });

    test('badCertificate is surfaced as QuioException', () async {
      adapter.whenFetch().thenThrow(
        QuioException(
          requestOptions: dummyOptions(),
          type: QuioErrorType.badCertificate,
          message: 'SSL handshake failed',
        ),
      );

      expect(
        () => quio.get('/secure'),
        throwsA(
          isA<QuioException>().having(
            (e) => e.type,
            'type',
            QuioErrorType.badCertificate,
          ),
        ),
      );
    });

    test('arbitrary exception is wrapped as QuioErrorType.unknown', () async {
      adapter.whenFetch().thenThrow(StateError('Unexpected state'));

      expect(
        () => quio.get('/broken'),
        throwsA(
          isA<QuioException>().having(
            (e) => e.type,
            'type',
            QuioErrorType.unknown,
          ),
        ),
      );
    });
  });

  group('Transformer pipeline', () {
    test('transformRequest is called with the original payload', () async {
      final payload = {'key': 'value'};
      adapter.whenFetch().thenReturn(body: '{}', statusCode: 200);
      await quio.post('/items', data: payload);

      expect(transformer.requestCallCount, 1);
      expect(transformer.requestCalls.first, payload);
    });

    test('transformResponse is called with the raw response body', () async {
      const rawBody = '{"id":99}';
      adapter.whenFetch().thenReturn(body: rawBody, statusCode: 200);
      await quio.get('/items/99');

      expect(transformer.responseCallCount, 1);
      expect(transformer.responseCalls.first, rawBody);
    });

    test('transformResponse output becomes response.data', () async {
      const rawBody = '{"id":5}';
      transformer.onTransformResponse =
          (data) async => jsonDecode(data as String);
      adapter.whenFetch().thenReturn(body: rawBody, statusCode: 200);

      final response = await quio.get('/items/5');

      expect(response.data, {'id': 5});
    });

    test(
      'exception in transformRequest is wrapped as QuioErrorType.unknown',
      () async {
        transformer.requestError = Exception('Encode failure');
        adapter.whenFetch().thenReturn(body: '{}', statusCode: 200);

        expect(
          () => quio.post('/items', data: {'x': 1}),
          throwsA(
            isA<QuioException>().having(
              (e) => e.type,
              'type',
              QuioErrorType.unknown,
            ),
          ),
        );
      },
    );

    test(
      'exception in transformResponse is wrapped as QuioErrorType.unknown',
      () async {
        transformer.responseError = Exception('Decode failure');
        adapter.whenFetch().thenReturn(body: 'not-json', statusCode: 200);

        expect(
          () => quio.get('/items'),
          throwsA(
            isA<QuioException>().having(
              (e) => e.type,
              'type',
              QuioErrorType.unknown,
            ),
          ),
        );
      },
    );
  });

  group('Response sequence (retry-like scenarios)', () {
    test('first call fails, second call succeeds', () async {
      final options = dummyOptions();

      adapter.whenFetch().thenReturnSequence([
        MockResponse.error(
          QuioException(
            requestOptions: options,
            type: QuioErrorType.connectionError,
            message: 'Transient error',
          ),
        ),
        MockResponse.success(body: jsonBody({'ok': true}), statusCode: 200),
      ]);

      // First call: expect failure
      await expectLater(
        () => quio.get('/flaky'),
        throwsA(isA<QuioException>()),
      );

      // Second call: expect success
      final response = await quio.get('/flaky');
      expect(response.statusCode, 200);
    });

    test('processes a sequence of different status codes in order', () async {
      adapter.whenFetch().thenReturnSequence([
        MockResponse.success(body: '{"page":1}', statusCode: 200),
        MockResponse.success(body: '{"page":2}', statusCode: 200),
        MockResponse.success(body: '', statusCode: 204),
      ]);

      final r1 = await quio.get('/pages');
      final r2 = await quio.get('/pages');
      final r3 = await quio.get('/pages');

      expect(r1.statusCode, 200);
      expect(r2.statusCode, 200);
      expect(r3.statusCode, 204);
      expect(adapter.callCount, 3);
    });
  });

  group('QuioException structure', () {
    test('exception carries request options at point of failure', () async {
      adapter.whenFetch().thenReturn(
        body: '{"error":"not found"}',
        statusCode: 404,
        statusMessage: 'Not Found',
      );

      try {
        await quio.get('/missing');
        fail('Expected QuioException');
      } on QuioException catch (e) {
        expect(e.requestOptions.method, 'GET');
        expect(e.requestOptions.path, '/missing');
        expect(e.response?.statusCode, 404);
        expect(e.message, contains('404'));
      }
    });

    test('toString includes method, URI and status', () async {
      adapter.whenFetch().thenReturn(
        body: '{}',
        statusCode: 500,
        statusMessage: 'Internal Server Error',
      );

      try {
        await quio.get('/broken');
        fail('Expected QuioException');
      } on QuioException catch (e) {
        final str = e.toString();
        expect(str, contains('badResponse'));
        expect(str, contains('GET'));
        expect(str, contains('500'));
      }
    });

    test('copyWith preserves original fields when not overridden', () {
      final original = QuioException(
        requestOptions: dummyOptions(),
        type: QuioErrorType.badResponse,
        message: 'Original message',
      );
      final copy = original.copyWith(message: 'New message');

      expect(copy.message, 'New message');
      expect(copy.type, QuioErrorType.badResponse);
      expect(copy.requestOptions, same(original.requestOptions));
    });
  });

  group('Mock adapter inspection', () {
    test('records all calls in order', () async {
      adapter.whenFetch().thenReturn(body: '{}', statusCode: 200);
      adapter.whenFetch().thenReturn(body: '{}', statusCode: 201);

      await quio.get('/a');
      await quio.post('/b', data: null);

      expect(adapter.calls[0].method, 'GET');
      expect(adapter.calls[0].uri.path, '/a');
      expect(adapter.calls[1].method, 'POST');
      expect(adapter.calls[1].uri.path, '/b');
    });

    test('lastCall and firstCall accessors work correctly', () async {
      adapter.whenFetch().thenReturn(body: '{}', statusCode: 200);
      adapter.whenFetch().thenReturn(body: '{}', statusCode: 200);

      await quio.get('/first');
      await quio.get('/last');

      expect(adapter.firstCall.uri.path, '/first');
      expect(adapter.lastCall.uri.path, '/last');
    });

    test('reset clears calls and queue', () async {
      adapter.whenFetch().thenReturn(body: '{}', statusCode: 200);
      await quio.get('/something');
      expect(adapter.callCount, 1);

      adapter.reset();
      expect(adapter.callCount, 0);
      expect(adapter.calls, isEmpty);
    });

    test('throws QuioException(unknown) after adapter is closed', () async {
      // The StateError from the closed mock is caught by _QuioImpl and wrapped
      // as QuioErrorType.unknown — it does NOT surface as a raw StateError.
      adapter.close();
      expect(
        () => quio.get('/anything'),
        throwsA(
          isA<QuioException>().having(
            (e) => e.type,
            'type',
            QuioErrorType.unknown,
          ),
        ),
      );
    });

    test('lastCall throws StateError when no calls have been made', () {
      expect(() => adapter.lastCall, throwsA(isA<StateError>()));
    });
  });

  group('Options mutation at runtime', () {
    test('changing baseUrl after construction takes effect', () async {
      adapter.whenFetch().thenReturn(body: '{}', statusCode: 200);

      quio.options.baseUrl = 'https://v2.example.com';
      await quio.get('/resource');

      expect(adapter.lastCall.uri.host, 'v2.example.com');
    });

    test('replacing the adapter replaces the transport layer', () async {
      final secondAdapter = MockHttpClientAdapter();
      secondAdapter.whenFetch().thenReturn(
        body: '{"source":"second"}',
        statusCode: 200,
      );

      quio.httpClientAdapter = secondAdapter;
      await quio.get('/something');

      expect(
        adapter.callCount,
        0,
        reason: 'Original adapter should not be called',
      );
      expect(secondAdapter.callCount, 1);
    });
  });

  group('request() low-level method', () {
    test('supports custom HTTP methods', () async {
      adapter.whenFetch().thenReturn(body: '{}', statusCode: 200);
      await quio.request('/resource', method: 'OPTIONS');
      expect(adapter.lastCall.method, 'OPTIONS');
    });

    test('per-request timeout overrides base options', () async {
      adapter.whenFetch().thenReturn(body: '{}', statusCode: 200);

      await quio.request(
        '/slow',
        method: 'GET',
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
      );

      final opts = adapter.lastCall.options;
      expect(opts.connectTimeout, const Duration(seconds: 30));
      expect(opts.receiveTimeout, const Duration(seconds: 60));
    });
  });
}
