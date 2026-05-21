import '../models/request_options.dart';
import '../models/response.dart';

/// Categorizes the point of failure in the HTTP transaction pipeline.
enum QuioErrorType {
  connectionTimeout,
  sendTimeout,
  receiveTimeout,
  badCertificate,
  badResponse,
  cancel,
  connectionError,
  requestSerializationError,
  unknown,
}

/// Primary exception wrapper for all Quio HTTP operations.
/// Encapsulates the state of the request/response at the moment of failure.
class QuioException implements Exception {
  final RequestOptions requestOptions;
  final Response? response;
  final QuioErrorType type;
  final Object? error;
  final StackTrace? stackTrace;
  final String? message;

  QuioException({
    required this.requestOptions,
    this.response,
    this.type = QuioErrorType.unknown,
    this.error,
    this.stackTrace,
    this.message,
  });

  QuioException copyWith({
    RequestOptions? requestOptions,
    Response? response,
    QuioErrorType? type,
    Object? error,
    StackTrace? stackTrace,
    String? message,
  }) {
    return QuioException(
      requestOptions: requestOptions ?? this.requestOptions,
      response: response ?? this.response,
      type: type ?? this.type,
      error: error ?? this.error,
      stackTrace: stackTrace ?? this.stackTrace,
      message: message ?? this.message,
    );
  }

  @override
  String toString() {
    final buffer =
        StringBuffer()
          ..writeln(
            'QuioException [${type.name}]: ${message ?? "Unhandled transport fault"}',
          )
          ..writeln('Uri: ${requestOptions.method} ${requestOptions.uri}');

    if (response != null) {
      buffer.writeln(
        'Status: ${response!.statusCode} ${response!.statusMessage ?? ""}',
      );
    }

    if (error != null) {
      buffer.writeln('Inner Error: $error');
    }

    return buffer.toString().trim();
  }
}
