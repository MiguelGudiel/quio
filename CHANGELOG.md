# Changelog

All notable changes to this project will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.0.1] - Unreleased

### Added

- `Quio` client with `get`, `post`, `put`, `patch`, `delete`, and `request` methods.
- `BaseOptions` for global client configuration: `baseUrl`, `headers`, `queryParameters`, `connectTimeout`, `receiveTimeout`, and `protocolPreference`.
- Per-request overrides for headers, query parameters, and timeouts that take precedence over `BaseOptions`.
- `RequestOptions` with URI resolution logic that normalizes base URL concatenation and merges query parameters from both global and request-level sources.
- `Response<T>` model carrying `data`, `statusCode`, `statusMessage`, `headers`, and `requestOptions`.
- `QuioException` with a `QuioErrorType` enum covering `connectionTimeout`, `receiveTimeout`, `sendTimeout`, `badResponse`, `badCertificate`, `connectionError`, `requestSerializationError`, `cancel`, and `unknown`.
- `HttpClientAdapter` interface defining the transport contract (`fetch` and `close`).
- `CronetHttpClientAdapter` for Android: delegates to `CronetClient` with QUIC, HTTP/2, and Brotli enabled at the engine level.
- `CupertinoHttpClientAdapter` for iOS and macOS: delegates to `CupertinoClient` backed by `NSURLSession` with an ephemeral session configuration.
- `IoHttpClientAdapter` as the `dart:io` fallback for Linux, Windows, and any unsupported platform. Implements stream-level receive timeout injection independently of the connection phase.
- `HttpPackageAdapter` base class shared by the Cronet and Cupertino adapters, providing header application, body serialization, and timeout pipeline logic over any `http.Client`.
- Automatic adapter selection via conditional imports (`adapter_factory_io.dart` / `adapter_factory_stub.dart`), with no platform detection code leaking into application scope.
- `HttpProtocolPreference` enum (`auto`, `http1_1`, `http2`, `http3`) for expressing a transport hint to the active adapter.
- Split timeout enforcement: `connectTimeout` governs the socket establishment phase; `receiveTimeout` is injected into the response byte stream to catch stalling during data transfer.
- Typed body serialization: `Map` and `List` payloads are JSON-encoded with automatic `Content-Type` assignment; `String` and `List<int>` are sent as-is; other types fall back to `.toString()`.
- 2xx status validation gate in the client layer: responses outside this range are wrapped and thrown as `QuioException` with type `badResponse`.
