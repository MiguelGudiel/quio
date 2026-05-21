# Quio

A modern, high-performance HTTP client for Flutter and Dart, built on native network stacks. Quio relies on native platform engines (Cronet on Android and NSURLSession on iOS and macOS) and uses `dart:io` on other platforms. This results in a clean and user-friendly API without the overhead of a purely Dart transport layer.

## Why Quio

Most Dart HTTP clients sit atop `dart:io`'s `HttpClient`, which is capable but limited: no QUIC/HTTP-3 support, no Brotli decompression, and no access to the platform's own certificate store or connection pooling logic. Quio gets out of the way and lets the OS do what it already does well.

- Native HTTP/2 and HTTP/3 (QUIC) where supported by the platform
- Brotli decompression on Android via Cronet
- Platform certificate validation and connection reuse handled by the OS
- Typed exception hierarchy that maps to specific failure stages in the request pipeline
- Per-request timeout granularity, connection phase and data-receive phase are tracked separately
- Adapter pattern: swap the transport layer without touching application code

---

## Platform Support

| Platform | Networking Backend | HTTP/1.1 | HTTP/2 | HTTP/3 (QUIC) | Brotli |
|---|---|:---:|:---:|:---:|:---:|
| Android | Cronet | Yes | Yes | Yes | Yes |
| iOS | NSURLSession (Cupertino) | Yes | Yes | Negotiated by OS | - |
| macOS | NSURLSession (Cupertino) | Yes | Yes | Negotiated by OS | - |
| Linux | dart:io | Yes | Yes | No | No |
| Windows | dart:io | Yes | Yes | No | No |

The adapter is selected automatically at runtime. You can override it by passing a custom `HttpClientAdapter` to the `Quio` constructor.

---

## Installation

Add Quio to your `pubspec.yaml`:

```yaml
dependencies:
  quio: ^0.0.1
```

Then run:

```sh
flutter pub get
```

---

## Quick Start

```dart
import 'package:quio/quio.dart';

final quio = Quio(
  options: BaseOptions(
    baseUrl: 'https://api.example.com',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ),
);

final response = await quio.get('/users/1');
print(response.statusCode); // 200
print(response.data);       // Raw response body
```

---

## Usage

### Client Configuration

`BaseOptions` defines the defaults applied to every request made by a client instance. Individual requests can override any of these values.

```dart
final quio = Quio(
  options: BaseOptions(
    baseUrl: 'https://api.example.com/v2',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
    headers: {
      'Authorization': 'Bearer <token>',
      'Accept': 'application/json',
    },
    queryParameters: {
      'api_version': '2024-01',
    },
    protocolPreference: HttpProtocolPreference.http2,
  ),
);
```

### GET

```dart
final response = await quio.get(
  '/articles',
  queryParameters: {'page': '1', 'limit': '20'},
);
```

### POST with JSON body

Maps and Lists are automatically serialized to JSON. The `Content-Type` header is set to `application/json` if not already present.

```dart
final response = await quio.post(
  '/articles',
  data: {
    'title': 'Hello, Quio',
    'body': 'Native networking for Flutter.',
    'published': true,
  },
);
```

### PUT and PATCH

```dart
// Full replacement
await quio.put('/articles/42', data: {'title': 'Updated Title', 'body': '...'});

// Partial update
await quio.patch('/articles/42', data: {'title': 'Only the title changed'});
```

### DELETE

```dart
final response = await quio.delete('/articles/42');
print(response.statusCode); // 204
```

### Per-request headers and timeouts

Request-level settings take precedence over the values set in `BaseOptions`.

```dart
final response = await quio.get(
  '/reports/export',
  headers: {'Accept': 'text/csv'},
  connectTimeout: const Duration(seconds: 5),
  receiveTimeout: const Duration(minutes: 2),
);
```

### Sending raw strings or bytes

The `data` field accepts a `String`, a `List<int>`, a `Map`, or a `List`. Anything else is converted via `.toString()`.

```dart
// Send a raw string body
await quio.post(
  '/webhook',
  data: '<xml><event>ping</event></xml>',
  headers: {'Content-Type': 'application/xml'},
);

// Send raw bytes
await quio.post('/upload', data: imageBytes);
```

### Arbitrary HTTP methods

Use `quio.request` to issue any HTTP verb not covered by the named helpers.

```dart
final response = await quio.request(
  '/resources/42',
  method: 'OPTIONS',
);
```

---

## Error Handling

All network failures surface as `QuioException`. The `type` field identifies the stage in the pipeline where the failure occurred, so you can respond to connection issues, server errors, and serialization problems independently.

```dart
import 'package:quio/core/exceptions/quio_exception.dart';

try {
  final response = await quio.get('/users/1');
  // Process response
} on QuioException catch (e) {
  switch (e.type) {
    case QuioErrorType.connectionTimeout:
      // The socket could not be established within connectTimeout.
      print('Connection timed out: ${e.message}');

    case QuioErrorType.receiveTimeout:
      // The server stopped sending data within receiveTimeout.
      print('Response stalled: ${e.message}');

    case QuioErrorType.badResponse:
      // HTTP status outside 2xx.
      print('Server error ${e.response?.statusCode}: ${e.message}');

    case QuioErrorType.connectionError:
      // DNS failure, refused connection, no network, etc.
      print('Network unreachable: ${e.message}');

    case QuioErrorType.badCertificate:
      // TLS handshake failure.
      print('Certificate error: ${e.message}');

    case QuioErrorType.requestSerializationError:
      // The request body could not be encoded.
      print('Serialization failed: ${e.message}');

    default:
      print('Unexpected error [${e.type.name}]: ${e.message}');
  }
}
```

### QuioErrorType reference

| Value | Trigger |
|---|---|
| `connectionTimeout` | Socket not established within `connectTimeout` |
| `receiveTimeout` | Data stream stalled beyond `receiveTimeout` |
| `sendTimeout` | Request body upload timed out |
| `badResponse` | HTTP status code outside the 2xx range |
| `badCertificate` | TLS handshake or certificate validation failure |
| `connectionError` | DNS resolution failure, refused connection, no route to host |
| `requestSerializationError` | Request body could not be encoded |
| `cancel` | Request was cancelled before completion |
| `unknown` | Unclassified transport fault |

### Inspecting the failed request and response

`QuioException` carries the full `RequestOptions` and, when the server did respond, the `Response` at the point of failure.

```dart
} on QuioException catch (e) {
  print(e.requestOptions.uri);      // The URI that was attempted
  print(e.requestOptions.method);   // The HTTP verb
  print(e.response?.statusCode);    // null if no response was received
  print(e.response?.headers);
  print(e.error);                   // The underlying exception, if any
  rethrow;
}
```

---

## Custom Adapters

The `HttpClientAdapter` interface defines the transport contract. Implement it to integrate any HTTP engine.

```dart
import 'package:quio/core/adapters/contracts/http_client_adapter.dart';

class MyCustomAdapter implements HttpClientAdapter {
  @override
  Future<Response<dynamic>> fetch(RequestOptions options) async {
    // Delegate to your chosen engine.
  }

  @override
  void close({bool force = false}) {
    // Release resources.
  }
}

// Inject at construction time.
final quio = Quio(adapter: MyCustomAdapter());
```

---

## Protocol Preference

`HttpProtocolPreference` expresses a hint to the adapter about the desired HTTP version. Actual negotiation depends on adapter capabilities and server support.

```dart
final quio = Quio(
  options: BaseOptions(
    protocolPreference: HttpProtocolPreference.http2,
  ),
);
```

| Value | Behavior |
|---|---|
| `auto` | Let the engine and server negotiate (default) |
| `http1_1` | Prefer HTTP/1.1 |
| `http2` | Prefer HTTP/2 |
| `http3` | Prefer HTTP/3 (requires Cronet on Android); logged as unsupported on dart:io |

---

## Architecture

Quio is structured in three layers.

**Client layer** - `Quio` is the public facade. It merges `BaseOptions` with per-request parameters, builds a `RequestOptions` object, and delegates to the adapter. It also handles the 2xx validation gate and re-wraps unexpected exceptions as `QuioException`.

**Adapter layer** - `HttpClientAdapter` is a single-method interface (`fetch`) that takes a `RequestOptions` and returns a `Response`. Three implementations ship with the library:

- `CronetHttpClientAdapter` - wraps `CronetClient` from the `cronet_http` package. Enables QUIC, HTTP/2, and Brotli at the engine level.
- `CupertinoHttpClientAdapter` - wraps `CupertinoClient` from the `cupertino_http` package, which delegates to `NSURLSession`. Configured with an ephemeral session that permits cellular access and waits for connectivity.
- `IoHttpClientAdapter` - uses `dart:io`'s `HttpClient` directly. Handles header application, body serialization, and stream-level receive timeout injection without any third-party dependency.

The correct adapter is selected by `createDefaultAdapter()` using conditional imports, so no platform detection code reaches your application bundle.

**Model layer** - `RequestOptions`, `Response`, `BaseOptions`, and `QuioException` are plain Dart objects with no platform dependencies. They flow unchanged between the client and the adapter.

### Request pipeline

```
Quio.request()
  └── Merge BaseOptions + per-request overrides → RequestOptions
        └── HttpClientAdapter.fetch(RequestOptions)
              ├── Build platform request
              ├── Apply connectTimeout
              ├── Send request
              ├── Apply receiveTimeout to response stream
              └── Return Response<dynamic>
  └── Validate status code (2xx gate)
  └── Return Response<T> to caller
```

Timeout enforcement is intentionally split: `connectTimeout` is applied to the future returned by the send call; `receiveTimeout` is injected into the response byte stream so that a slow transfer after a fast handshake is caught independently.

---

## Contributing

Pull requests are welcome. Please open an issue first to discuss significant changes.

## License

MIT
