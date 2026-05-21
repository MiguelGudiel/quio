import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:quio/quio.dart';
import 'package:quio/core/exceptions/quio_exception.dart';

void main() {
  runApp(const QuioExampleApp());
}

/// Main entry point for the Quio SDK example application.
class QuioExampleApp extends StatelessWidget {
  const QuioExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quio SDK Playground',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF263238),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const NetworkingDashboard(),
    );
  }
}

/// Interactive dashboard demonstrating core Quio HTTP operations.
class NetworkingDashboard extends StatefulWidget {
  const NetworkingDashboard({super.key});

  @override
  State<NetworkingDashboard> createState() => _NetworkingDashboardState();
}

class _NetworkingDashboardState extends State<NetworkingDashboard> {
  final Quio _quio = Quio(
    options: BaseOptions(
      baseUrl: 'https://jsonplaceholder.typicode.com',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Accept': 'application/json', 'X-Client-Version': '1.0.0'},
    ),
  );

  // We now store the log as a list of strings (lines) to support lazy rendering.
  List<String> _currentLogLines = [
    'Waiting for operations...',
    'Ready to inspect network traffic.',
  ];
  bool _isErrorLog = false;
  bool _isLoading = false;

  /// Helper to convert raw JSON data into beautifully indented strings.
  String _prettyPrintJson(dynamic json) {
    if (json == null) return 'null';
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(json);
    } catch (_) {
      return json.toString();
    }
  }

  /// Replaces the current log lines with new debug information.
  void _setLog(List<String> lines, {bool isError = false}) {
    setState(() {
      _currentLogLines = lines;
      _isErrorLog = isError;
    });
  }

  /// Builds the debug report and splits it into discrete lines for the UI.
  List<String> _buildDebugReportLines({
    required String method,
    required Uri uri,
    required int elapsedMs,
    int? statusCode,
    String? statusMessage,
    dynamic data,
    Map<String, List<String>>? headers,
    String? errorDetails,
  }) {
    final List<String> lines = [];

    lines.add('====== QUIO NETWORK INSPECTOR ======');
    lines.add('Time    : ${DateTime.now().toIso8601String().split('T').last}');
    lines.add('Request : $method $uri');
    lines.add('Latency : ${elapsedMs}ms');

    if (statusCode != null) {
      lines.add('Status  : $statusCode ${statusMessage ?? ""}');
    }

    if (headers != null && headers.isNotEmpty) {
      lines.add(''); // Empty line for spacing
      lines.add('[Headers]');
      lines.add('Count   : ${headers.length} fields');
      if (headers.containsKey('content-type')) {
        lines.add('Type    : ${headers['content-type']?.first}');
      }
    }

    if (errorDetails != null) {
      lines.add('');
      lines.add('[Error Details]');
      lines.addAll(errorDetails.split('\n'));
    } else if (data != null) {
      lines.add('');
      lines.add('[Payload Metrics]');
      lines.add('Type    : ${data.runtimeType}');

      if (data is List) {
        lines.add('Size    : ${data.length} items');
      } else if (data is Map) {
        lines.add('Size    : ${data.length} keys');
      } else if (data is String) {
        lines.add('Size    : ${data.length} bytes');
      }

      lines.add('');
      lines.add('[Payload Preview]');

      // The critical fix: we pretty print, then split by line, so the UI
      // can render them lazily via ListView.builder.
      final prettyString = _prettyPrintJson(data);
      lines.addAll(prettyString.split('\n'));
    }

    return lines;
  }

  void _handleQuioError(String method, QuioException e, int elapsedMs) {
    _setLog(
      _buildDebugReportLines(
        method: method,
        uri: e.requestOptions.uri,
        elapsedMs: elapsedMs,
        statusCode: e.response?.statusCode,
        statusMessage: e.response?.statusMessage ?? e.type.name,
        headers: e.response?.headers,
        errorDetails: e.message ?? 'Unknown pipeline failure',
      ),
      isError: true,
    );
  }

  Future<void> _executeGetRequest() async {
    setState(() => _isLoading = true);
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _quio.get(
        '/users/1',
        queryParameters: {'env': 'production'},
      );
      stopwatch.stop();

      _setLog(
        _buildDebugReportLines(
          method: 'GET',
          uri: response.requestOptions.uri,
          elapsedMs: stopwatch.elapsedMilliseconds,
          statusCode: response.statusCode,
          statusMessage: response.statusMessage,
          headers: response.headers,
          data: response.data,
        ),
      );
    } on QuioException catch (e) {
      stopwatch.stop();
      _handleQuioError('GET', e, stopwatch.elapsedMilliseconds);
    } catch (e) {
      stopwatch.stop();
      _setLog(['FATAL UNHANDLED EXCEPTION: $e'], isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _executeHeavyGetRequest() async {
    setState(() => _isLoading = true);
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _quio.get('/photos');
      stopwatch.stop();

      _setLog(
        _buildDebugReportLines(
          method: 'GET',
          uri: response.requestOptions.uri,
          elapsedMs: stopwatch.elapsedMilliseconds,
          statusCode: response.statusCode,
          statusMessage: response.statusMessage,
          headers: response.headers,
          data: response.data,
        ),
      );
    } on QuioException catch (e) {
      stopwatch.stop();
      _handleQuioError('GET', e, stopwatch.elapsedMilliseconds);
    } catch (e) {
      stopwatch.stop();
      _setLog(['FATAL UNHANDLED EXCEPTION: $e'], isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _executePostRequest() async {
    setState(() => _isLoading = true);
    final stopwatch = Stopwatch()..start();

    try {
      final payload = {
        'title': 'Quio Architecture',
        'body': 'Testing payload serialization',
        'userId': 1,
      };

      final response = await _quio.post('/posts', data: payload);
      stopwatch.stop();

      _setLog(
        _buildDebugReportLines(
          method: 'POST',
          uri: response.requestOptions.uri,
          elapsedMs: stopwatch.elapsedMilliseconds,
          statusCode: response.statusCode,
          statusMessage: response.statusMessage,
          headers: response.headers,
          data: response.data,
        ),
      );
    } on QuioException catch (e) {
      stopwatch.stop();
      _handleQuioError('POST', e, stopwatch.elapsedMilliseconds);
    } catch (e) {
      stopwatch.stop();
      _setLog(['FATAL UNHANDLED EXCEPTION: $e'], isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _executeDeleteRequest() async {
    setState(() => _isLoading = true);
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _quio.delete('/posts/1');
      stopwatch.stop();

      _setLog(
        _buildDebugReportLines(
          method: 'DELETE',
          uri: response.requestOptions.uri,
          elapsedMs: stopwatch.elapsedMilliseconds,
          statusCode: response.statusCode,
          statusMessage: response.statusMessage,
          headers: response.headers,
          data: response.data,
        ),
      );
    } on QuioException catch (e) {
      stopwatch.stop();
      _handleQuioError('DELETE', e, stopwatch.elapsedMilliseconds);
    } catch (e) {
      stopwatch.stop();
      _setLog(['FATAL UNHANDLED EXCEPTION: $e'], isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _executeErrorRequest() async {
    setState(() => _isLoading = true);
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _quio.get('/invalid-endpoint-404');
      stopwatch.stop();

      _setLog(
        _buildDebugReportLines(
          method: 'GET',
          uri: response.requestOptions.uri,
          elapsedMs: stopwatch.elapsedMilliseconds,
          statusCode: response.statusCode,
          statusMessage: response.statusMessage,
          headers: response.headers,
          data: response.data,
        ),
      );
    } on QuioException catch (e) {
      stopwatch.stop();
      _handleQuioError('GET', e, stopwatch.elapsedMilliseconds);
    } catch (e) {
      stopwatch.stop();
      _setLog(['FATAL UNHANDLED EXCEPTION: $e'], isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildOperationTile({
    required String method,
    required String title,
    required String description,
    required VoidCallback onExecute,
    required Color methodColor,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16.0),
        leading: Container(
          width: 70,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          decoration: BoxDecoration(
            color: methodColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: methodColor.withValues(alpha: 0.5)),
          ),
          child: Text(
            method,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: methodColor,
              letterSpacing: 1.2,
            ),
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(description, style: const TextStyle(fontSize: 13)),
        ),
        trailing: FilledButton.tonal(
          onPressed: _isLoading ? null : onExecute,
          child: const Text('Execute'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quio Test Suite'),
        elevation: 0,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              children: [
                _buildOperationTile(
                  method: 'GET',
                  title: 'Standard Fetch',
                  description:
                      'Retrieves a single user with query parameters. Small payload.',
                  methodColor: Colors.blue,
                  onExecute: _executeGetRequest,
                ),
                _buildOperationTile(
                  method: 'GET',
                  title: 'Heavy Payload (Isolate Test)',
                  description:
                      'Fetches 5,000 photos. Large JSON decoded in background Isolate.',
                  methodColor: Colors.indigo,
                  onExecute: _executeHeavyGetRequest,
                ),
                _buildOperationTile(
                  method: 'POST',
                  title: 'Serialize Payload',
                  description:
                      'Sends a Dart Map serialized to JSON as the request body.',
                  methodColor: Colors.green,
                  onExecute: _executePostRequest,
                ),
                _buildOperationTile(
                  method: 'DELETE',
                  title: 'Remove Resource',
                  description: 'Triggers a standard HTTP DELETE operation.',
                  methodColor: Colors.orange,
                  onExecute: _executeDeleteRequest,
                ),
                _buildOperationTile(
                  method: 'ERROR',
                  title: 'Force 404 Exception',
                  description:
                      'Hits a non-existent endpoint to test QuioException handling.',
                  methodColor: Colors.red,
                  onExecute: _executeErrorRequest,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              color: const Color(0xFF1E1E1E),
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: SelectionArea(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: _currentLogLines.length,
                  itemBuilder: (context, index) {
                    return Text(
                      _currentLogLines[index],
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color:
                            _isErrorLog ? Colors.redAccent : Colors.greenAccent,
                        fontSize: 13.0,
                        height: 1.4,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
