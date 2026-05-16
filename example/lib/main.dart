import 'package:flutter/material.dart';
import 'package:quio/quio.dart';

void main() {
  runApp(const QuioExampleApp());
}

class QuioExampleApp extends StatelessWidget {
  const QuioExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quio Professional Networking',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const NetworkingDashboard(),
    );
  }
}

class NetworkingDashboard extends StatefulWidget {
  const NetworkingDashboard({super.key});

  @override
  State<NetworkingDashboard> createState() => _NetworkingDashboardState();
}

class _NetworkingDashboardState extends State<NetworkingDashboard> {
  // Globally injected client instance.
  final Quio _quio = Quio();

  String _consoleOutput = 'Ready to execute requests...';
  bool _isLoading = false;

  void _log(String message) {
    setState(() {
      _consoleOutput = message;
    });
  }

  Future<void> _executeGetRequest() async {
    setState(() => _isLoading = true);
    try {
      final response = await _quio.get(
        'https://jsonplaceholder.typicode.com/users/1',
        queryParameters: {'env': 'production'},
      );

      _log(
        '[GET] Status: ${response.statusCode}\n'
        'Headers: ${response.headers['content-type']}\n'
        'Data: ${response.data}',
      );
    } catch (e) {
      _log('[GET] Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _executePostRequest() async {
    setState(() => _isLoading = true);
    try {
      final payload = {
        'title': 'Quio Architecture',
        'body': 'Testing payload serialization',
        'userId': 1,
      };

      final response = await _quio.post(
        'https://jsonplaceholder.typicode.com/posts',
        data: payload,
      );

      _log(
        '[POST] Status: ${response.statusCode}\n'
        'Data: ${response.data}',
      );
    } catch (e) {
      _log('[POST] Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _executeDeleteRequest() async {
    setState(() => _isLoading = true);
    try {
      final response = await _quio.delete(
        'https://jsonplaceholder.typicode.com/posts/1',
      );

      _log(
        '[DELETE] Status: ${response.statusCode}\n'
        'Data: ${response.data}',
      );
    } catch (e) {
      _log('[DELETE] Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quio Test Suite'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              spacing: 8.0,
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _executeGetRequest,
                  child: const Text('GET Request'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _executePostRequest,
                  child: const Text('POST Request'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _executeDeleteRequest,
                  child: const Text('DELETE Request'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              color: Colors.black87,
              child: SingleChildScrollView(
                child: Text(
                  _isLoading ? 'Executing...' : _consoleOutput,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: Colors.greenAccent,
                    fontSize: 13.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
