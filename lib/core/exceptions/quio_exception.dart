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

  @override
  String toString() {
    var msg = 'QuioException [${type.name}]: ${message ?? "Unhandled transport fault"}';
    if (error != null) {
      msg += '\nUnderlying error: $error';
    }
    return msg;
  }
}