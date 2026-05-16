import 'package:quio/core/exceptions/quio_exception.dart';

import '../adapters/contracts/http_client_adapter.dart';
import '../models/base_options.dart';
import '../models/request_options.dart';
import '../models/response.dart';

import '../adapters/factory/adapter_factory_stub.dart'
    if (dart.library.io) '../adapters/factory/adapter_factory_io.dart';

/// High-level HTTP client API.
abstract interface class Quio {
  factory Quio({BaseOptions? options, HttpClientAdapter? adapter}) => 
      _QuioImpl(options, adapter);

  BaseOptions get options;
  set options(BaseOptions baseOptions);

  HttpClientAdapter get httpClientAdapter;
  set httpClientAdapter(HttpClientAdapter adapter);

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  });

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  });

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  });

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  });

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  });

  Future<Response<T>> request<T>(
    String path, {
    dynamic data,
    required String method,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    Duration? connectTimeout,
    Duration? receiveTimeout,
  });
}

class _QuioImpl implements Quio {
  @override
  BaseOptions options;

  @override
  HttpClientAdapter httpClientAdapter;

  _QuioImpl(BaseOptions? options, HttpClientAdapter? adapter)
      : options = options ?? BaseOptions(),
        httpClientAdapter = adapter ?? createDefaultAdapter();

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) =>
      request<T>(path, method: 'GET', queryParameters: queryParameters, headers: headers);

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) =>
      request<T>(path, method: 'POST', data: data, queryParameters: queryParameters, headers: headers);

  @override
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) =>
      request<T>(path, method: 'PUT', data: data, queryParameters: queryParameters, headers: headers);

  @override
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) =>
      request<T>(path, method: 'PATCH', data: data, queryParameters: queryParameters, headers: headers);

  @override
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) =>
      request<T>(path, method: 'DELETE', data: data, queryParameters: queryParameters, headers: headers);

  @override
  Future<Response<T>> request<T>(
    String path, {
    dynamic data,
    required String method,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    Duration? connectTimeout,
    Duration? receiveTimeout,
  }) async {
    final mergedHeaders = <String, dynamic>{
      ...options.headers,
      ...?headers,
    };

    final mergedQueryParams = <String, dynamic>{
      ...options.queryParameters,
      ...?queryParameters,
    };

    final requestOptions = RequestOptions(
      baseUrl: options.baseUrl,
      path: path,
      method: method,
      data: data,
      queryParameters: mergedQueryParams,
      headers: mergedHeaders,
      connectTimeout: connectTimeout ?? options.connectTimeout,
      receiveTimeout: receiveTimeout ?? options.receiveTimeout,
      protocolPreference: options.protocolPreference,
    );

    try {
      final response = await httpClientAdapter.fetch(requestOptions);
      final statusCode = response.statusCode ?? 0;

      if (statusCode < 200 || statusCode >= 300) {
        throw QuioException(
          requestOptions: requestOptions,
          response: response,
          type: QuioErrorType.badResponse,
          message: 'Server responded with an invalid status code: $statusCode',
        );
      }

      return response as Response<T>;
    } on QuioException {
      rethrow;
    } catch (e, stackTrace) {
      throw QuioException(
        requestOptions: requestOptions,
        type: QuioErrorType.unknown,
        error: e,
        stackTrace: stackTrace,
        message: 'Unhandled error execution pipeline: $e',
      );
    }
  }
}
