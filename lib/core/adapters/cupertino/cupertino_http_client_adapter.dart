import 'package:cupertino_http/cupertino_http.dart';
import 'package:http/http.dart' as http;

import '../base/http_package_adapter.dart';

/// Darwin-specific adapter using NSURLSession via [CupertinoClient].
/// 
/// TODO: Implement certificate pinning, background sessions, and explicit HTTP/2/3 configuration.
final class CupertinoHttpClientAdapter extends HttpPackageAdapter {
  @override
  final CupertinoClient httpClient;

  CupertinoHttpClientAdapter() : httpClient = _buildClient();

  static CupertinoClient _buildClient() {
    final config = URLSessionConfiguration.ephemeralSessionConfiguration()
      ..allowsCellularAccess = true
      ..waitsForConnectivity = true;

    return CupertinoClient.fromSessionConfiguration(config);
  }
}