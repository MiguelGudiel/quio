import '../../models/request_options.dart';
import '../../models/response.dart';

/// Transport layer contract for native API adapters.
abstract interface class HttpClientAdapter {
  Future<Response<dynamic>> fetch(RequestOptions options);

  void close({bool force = false});
}