abstract interface class Transformer {
  Future<dynamic> transformRequest(dynamic data);
  Future<dynamic> transformResponse(dynamic data);
}
