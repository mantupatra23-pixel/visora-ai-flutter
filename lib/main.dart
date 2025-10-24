import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';

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
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0E0E10),
        textTheme: GoogleFonts.poppinsTextTheme(
          ThemeData.dark().textTheme,
        ),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purpleAccent),
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
  late WebSocketChannel _channel;
  String _status = "Waiting for input...";
  String _resultUrl = "";
  double _progress = 0.0;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  void _connectWebSocket() {
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
  }

  Future<void> _generateVideo() async {
    if (_scriptController.text.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _status = "Processing your video...";
      _progress = 0.0;
    });

    final response = await http.post(
      Uri.parse('https://visora-ai-5nqs.onrender.com/generate_video'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "script": _scriptController.text,
        "quality": "HD",
        "language": "auto",
      }),
    );

    if (response.statusCode == 200) {
      setState(() {
        _status = "Video generation started...";
      });
    } else {
      setState(() {
        _status = "Error: ${response.body}";
      });
    }
  }

  void _copyUrl() {
    Clipboard.setData(ClipboardData(text: _resultUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ Link copied to clipboard")),
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
        title: const Text("🎬 Visora – Ultimate AI Studio"),
        centerTitle: true,
        backgroundColor: Colors.purpleAccent.shade400,
        elevation: 5,
      ),
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/lottie/loading.json',
                height: 160,
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.purpleAccent.withOpacity(0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _scriptController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 8,
                      decoration: InputDecoration(
                        hintText: "✍️ Enter your script for video...",
                        hintStyle: const TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isGenerating ? null : _generateVideo,
                icon: const Icon(Icons.auto_fix_high_rounded),
                label: const Text(
                  "Generate AI Video",
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 30),
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.white10,
                color: Colors.purpleAccent,
                minHeight: 6,
              ),
              const SizedBox(height: 10),
              Text(
                _status,
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 25),
              if (_resultUrl.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "🎥 Your Video is Ready!",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.purpleAccent),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        _resultUrl,
                        style: const TextStyle(color: Colors.blueAccent),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                        ),
                        onPressed: _copyUrl,
                        icon: const Icon(Icons.copy),
                        label: const Text("Copy Video Link"),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
