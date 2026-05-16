import 'http_protocol_preference.dart';

/// Global default configurations for the Quio client instance.
class BaseOptions {
  String baseUrl;
  Map<String, dynamic> headers;
  Map<String, dynamic> queryParameters;
  Duration? connectTimeout;
  Duration? receiveTimeout;
  HttpProtocolPreference protocolPreference;

  BaseOptions({
    this.baseUrl = '',
    this.headers = const {},
    this.queryParameters = const {},
    this.connectTimeout,
    this.receiveTimeout,
    this.protocolPreference = HttpProtocolPreference.auto,
  });
}