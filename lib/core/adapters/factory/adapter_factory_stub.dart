import '../contracts/http_client_adapter.dart';

/// Fallback stub for unsupported platforms.
HttpClientAdapter createDefaultAdapter() =>
    throw UnsupportedError(
      'Cannot create a client without dart:io or dart:html.',
    );
