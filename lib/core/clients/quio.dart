import '../adapters/contracts/http_client_adapter.dart';
import '../models/request_options.dart';
import '../models/response.dart';

import '../adapters/factory/adapter_factory_stub.dart'
    if (dart.library.io) '../adapters/factory/adapter_factory_io.dart';

/// High-level HTTP client API.
abstract interface class Quio {
  factory Quio({HttpClientAdapter? adapter}) => _QuioImpl(adapter);

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
  HttpClientAdapter httpClientAdapter;

  _QuioImpl(HttpClientAdapter? adapter)
      : httpClientAdapter = adapter ?? createDefaultAdapter();

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
    final options = RequestOptions(
      path: path,
      method: method,
      data: data,
      queryParameters: queryParameters ?? {},
      headers: headers ?? {},
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
    );

    final response = await httpClientAdapter.fetch(options);
    return response as Response<T>;
  }
}
