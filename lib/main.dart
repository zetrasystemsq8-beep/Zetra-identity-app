import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  runApp(const ZetraIdApp());
}

class ZetraIdApp extends StatelessWidget {
  const ZetraIdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zetra ID',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _checkZetraId();
  }

  Future<void> _checkZetraId() async {
    final zetraId = await storage.read(key: 'zetra_id');
    if (mounted) {
      if (zetraId != null && zetraId.isNotEmpty) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => DisplayScreen(zetraId: zetraId)),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const EntryScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  final TextEditingController _nameController = TextEditingController();
  final storage = const FlutterSecureStorage();
  bool _isLoading = false;

  Future<void> _generateId() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('https://zetra-backend.onrender.com/api/identity/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': _nameController.text.trim()}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final zetraId = data['zetra_id'];
        await storage.write(key: 'zetra_id', value: zetraId);
        
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => DisplayScreen(zetraId: zetraId)),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to generate ID. Please try again.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zetra ID')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Enter your name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _generateId,
                    child: const Text('Generate your Zetra ID'),
                  ),
          ],
        ),
      ),
    );
  }
}

class DisplayScreen extends StatelessWidget {
  final String zetraId;
  const DisplayScreen({super.key, required this.zetraId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Identity')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Your Zetra ID:', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SelectableText(
                  zetraId,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: zetraId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => InboxScreen(zetraId: zetraId)),
                );
              },
              child: const Text('View Inbox'),
            ),
          ],
        ),
      ),
    );
  }
}

class InboxScreen extends StatefulWidget {
  final String zetraId;
  const InboxScreen({super.key, required this.zetraId});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  List<dynamic> _messages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
  }

  Future<void> _fetchMessages() async {
    setState(() => _loading = true);
    try {
      final response = await http.get(
        Uri.parse('https://zetra-backend.onrender.com/api/identity/${widget.zetraId}/messages'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _messages = jsonDecode(response.body);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading messages: $e')),
        );
      }
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: RefreshIndicator(
        onRefresh: _fetchMessages,
        child: _loading && _messages.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _messages.isEmpty
                ? const Center(child: Text('No messages yet.'))
                : ListView.builder(
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return ListTile(
                        title: Text(msg['sender'] ?? 'Unknown Sender'),
                        subtitle: Text(msg['message'] ?? msg['code'] ?? ''),
                        leading: const Icon(Icons.message),
                      );
                    },
                  ),
      ),
    );
  }
}
