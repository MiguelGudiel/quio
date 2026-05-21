import 'package:cronet_http/cronet_http.dart';
import 'package:http/http.dart' as http;

import '../base/http_package_adapter.dart';

/// Android-specific adapter using Cronet.
///
/// TODO: Implement disk/memory cache mode, per-host QUIC hints, and certificate transparency checks.
final class CronetHttpClientAdapter extends HttpPackageAdapter {
  @override
  final CronetClient httpClient;

  CronetHttpClientAdapter() : httpClient = _buildClient();

  static CronetClient _buildClient() {
    final engine = CronetEngine.build(
      enableQuic: true,
      enableHttp2: true,
      enableBrotli: true,
    );

    return CronetClient.fromCronetEngine(engine);
  }
}
