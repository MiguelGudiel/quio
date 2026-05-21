import 'dart:io';
import '../contracts/http_client_adapter.dart';
import '../../adapters/io/io_http_client_adapter.dart';
import '../../adapters/cupertino/cupertino_http_client_adapter.dart';
import '../../adapters/cronet/cronet_http_client_adapter.dart';

/// Resolves the optimal native client adapter for the current platform.
HttpClientAdapter createDefaultAdapter() {
  if (Platform.isIOS || Platform.isMacOS) {
    return CupertinoHttpClientAdapter();
  } else if (Platform.isAndroid) {
    return CronetHttpClientAdapter();
  }

  return IoHttpClientAdapter();
}
