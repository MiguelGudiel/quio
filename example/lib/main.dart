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
  /// Primary Quio client instance.
  /// Configured with a base URL and global timeout constraints.
  final Quio _quio = Quio(
    options: BaseOptions(
      baseUrl: 'https://jsonplaceholder.typicode.com',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Accept': 'application/json',
        'X-Client-Version': '1.0.0',
      },
    ),
  );

  final List<String> _consoleLogs = ['[SYSTEM] Quio engine initialized and ready.'];
  bool _isLoading = false;

  void _appendLog(String message) {
    setState(() {
      _consoleLogs.insert(0, '${DateTime.now().toIso8601String().split('T').last} -> $message');
    });
  }

  /// Processes specific Quio exceptions to demonstrate granular error handling.
  void _handleQuioError(String operation, QuioException e) {
    final buffer = StringBuffer();
    buffer.write('[$operation] FAILED - Type: ${e.type.name}\n');
    
    if (e.response != null) {
      buffer.write('Status Code: ${e.response!.statusCode}\n');
    }
    
    buffer.write('Details: ${e.message}');
    _appendLog(buffer.toString());
  }

  /// Demonstrates a standard HTTP GET request with query parameters.
  Future<void> _executeGetRequest() async {
    setState(() => _isLoading = true);
    try {
      final response = await _quio.get(
        '/users/1',
        queryParameters: {'env': 'production'},
      );

      _appendLog(
        '[GET] SUCCESS - Status: ${response.statusCode}\n'
        'URI: ${response.requestOptions.uri}\n'
        'Payload: ${response.data}',
      );
    } on QuioException catch (e) {
      _handleQuioError('GET', e);
    } catch (e) {
      _appendLog('[GET] FATAL - Unhandled exception: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Demonstrates an HTTP POST request with JSON payload serialization.
  Future<void> _executePostRequest() async {
    setState(() => _isLoading = true);
    try {
      final payload = {
        'title': 'Quio Architecture',
        'body': 'Testing payload serialization',
        'userId': 1,
      };

      final response = await _quio.post(
        '/posts',
        data: payload,
      );

      _appendLog(
        '[POST] SUCCESS - Status: ${response.statusCode}\n'
        'Response Data: ${response.data}',
      );
    } on QuioException catch (e) {
      _handleQuioError('POST', e);
    } catch (e) {
      _appendLog('[POST] FATAL - Unhandled exception: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Demonstrates an HTTP DELETE request.
  /// Intentionally targets an endpoint that might trigger specific server responses.
  Future<void> _executeDeleteRequest() async {
    setState(() => _isLoading = true);
    try {
      final response = await _quio.delete('/posts/1');

      _appendLog(
        '[DELETE] SUCCESS - Status: ${response.statusCode}\n'
        'Response Data: ${response.data}',
      );
    } on QuioException catch (e) {
      _handleQuioError('DELETE', e);
    } catch (e) {
      _appendLog('[DELETE] FATAL - Unhandled exception: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Triggers a deliberate error to demonstrate QuioException handling.
  Future<void> _executeErrorRequest() async {
    setState(() => _isLoading = true);
    try {
      // Endpoint 404 target to force a badResponse QuioErrorType
      await _quio.get('/invalid-endpoint-404');
    } on QuioException catch (e) {
      _handleQuioError('ERROR-TEST', e);
    } catch (e) {
      _appendLog('[ERROR-TEST] FATAL: $e');
    } finally {
      setState(() => _isLoading = false);
    }
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              spacing: 12.0,
              runSpacing: 12.0,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _isLoading ? null : _executeGetRequest,
                  icon: const Icon(Icons.download),
                  label: const Text('GET'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _isLoading ? null : _executePostRequest,
                  icon: const Icon(Icons.upload),
                  label: const Text('POST'),
                ),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _executeDeleteRequest,
                  icon: const Icon(Icons.delete),
                  label: const Text('DELETE'),
                ),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _executeErrorRequest,
                  icon: const Icon(Icons.error_outline),
                  label: const Text('FORCE ERROR'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Container(
              color: const Color(0xFF1E1E1E),
              padding: const EdgeInsets.all(16.0),
              child: ListView.separated(
                itemCount: _consoleLogs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final log = _consoleLogs[index];
                  final isError = log.contains('FAILED') || log.contains('FATAL');
                  
                  return Text(
                    log,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: isError ? Colors.redAccent : Colors.greenAccent,
                      fontSize: 13.0,
                      height: 1.4,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}