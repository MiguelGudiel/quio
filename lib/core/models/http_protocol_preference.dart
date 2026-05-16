/// Requested HTTP protocol version. 
/// Actual resolution depends on adapter capabilities and server negotiation.
enum HttpProtocolPreference {
  auto,
  http1_1,
  http2,
  http3,
}