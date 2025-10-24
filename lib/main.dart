import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(const VisoraApp());
}

class VisoraApp extends StatelessWidget {
  const VisoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Visora – Ultimate AI Studio',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const GenerateVideoScreen(),
    );
  }
}

class GenerateVideoScreen extends StatefulWidget {
  const GenerateVideoScreen({super.key});

  @override
  State<GenerateVideoScreen> createState() => _GenerateVideoScreenState();
}

class _GenerateVideoScreenState extends State<GenerateVideoScreen> {
  final TextEditingController _scriptController = TextEditingController();
  String _status = "Idle";
  String _resultUrl = ""; // ✅ Fixed: non-nullable with default empty string
  late WebSocketChannel _channel;
  bool _isGenerating = false;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('wss://visora-ai-5nqs.onrender.com/ws'),
      );

      _channel.stream.listen((message) {
        var data = json.decode(message);
        setState(() {
          _status = data["status"] ?? "Processing...";
          _progress = (data["progress"] ?? 0) / 100;
          if (data.containsKey("url")) {
            _resultUrl = data["url"] ?? "";
          }
        });
      });
    } catch (e) {
      setState(() {
        _status = "WebSocket Error: $e";
      });
    }
  }

  Future<void> _generateVideo() async {
    if (_scriptController.text.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _status = "Generating...";
      _progress = 0.0;
    });

    final url = Uri.parse("https://visora-ai-5nqs.onrender.com/generate_video");
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "script": _scriptController.text,
        "quality": "auto",
        "language": "auto",
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _status = "Render started: ${data['job_id']}";
      });
    } else {
      setState(() {
        _status = "Error: ${response.body}";
      });
    }
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: _resultUrl ?? "")); // ✅ Safe copy
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Link copied to clipboard")),
    );
  }

  @override
  void dispose() {
    _channel.sink.close();
    _scriptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Visora – Ultimate AI Studio"),
        backgroundColor: Colors.purple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Lottie.asset("assets/lottie/loading.json", height: 150),
              const SizedBox(height: 10),
              TextField(
                controller: _scriptController,
                decoration: const InputDecoration(
                  labelText: "Enter your script",
                  border: OutlineInputBorder(),
                ),
                minLines: 3,
                maxLines: 10,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateVideo,
                icon: const Icon(Icons.play_circle_fill),
                label: const Text("Generate Video"),
              ),
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: _progress,
                color: Colors.purpleAccent,
                minHeight: 6,
              ),
              const SizedBox(height: 10),
              Text("Status: $_status"),
              const SizedBox(height: 15),
              if (_resultUrl.isNotEmpty)
                Column(
                  children: [
                    SelectableText(
                      "Result URL: $_resultUrl",
                      style: const TextStyle(color: Colors.blue),
                    ),
                    TextButton.icon(
                      onPressed: _copyLink,
                      icon: const Icon(Icons.copy),
                      label: const Text("Copy Link"),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
