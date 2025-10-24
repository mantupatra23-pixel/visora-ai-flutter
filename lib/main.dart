// VISORA v42 – Ultimate AI Studio (Single File Power Build)
// Full app in one file: Home + Create + Templates + Profile + Auto Upload

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

// 🌐 Live Backend Base
const String backendBase = "https://visora-ai-5nqs.onrender.com";

// 🚀 MAIN ENTRY
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const VisoraApp());
}

// 🧱 Root App
class VisoraApp extends StatelessWidget {
  const VisoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Visora – Ultimate AI Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        primaryColor: Colors.deepPurpleAccent,
        scaffoldBackgroundColor: const Color(0xFF0C0C14),
        colorScheme: const ColorScheme.dark().copyWith(
          secondary: Colors.deepPurpleAccent,
          surface: Color(0xFF12121A),
        ),
      ),
      home: const VisoraMainController(),
    );
  }
}

// 🧭 Bottom Navigation Controller
class VisoraMainController extends StatefulWidget {
  const VisoraMainController({super.key});

  @override
  State<VisoraMainController> createState() => _VisoraMainControllerState();
}

class _VisoraMainControllerState extends State<VisoraMainController> {
  int _currentIndex = 0;
  final List<Widget> _pages = const [
    HomeFeedScreen(),
    UltraCreateScreen(),
    TemplateLibraryScreen(),
    VisoraProfileScreen(),
  ];

  void _onTabTapped(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A26),
          border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          backgroundColor: Colors.transparent,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.deepPurpleAccent,
          unselectedItemColor: Colors.white54,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Create'),
            BottomNavigationBarItem(icon: Icon(Icons.video_library_outlined), label: 'Templates'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

// 🏠 HOME FEED (Trending)
class HomeFeedScreen extends StatelessWidget {
  const HomeFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final demoVideos = List.generate(10, (i) => "AI Video #${i + 1}");
    return Scaffold(
      appBar: AppBar(
        title: const Text("🔥 Trending AI Creations"),
        backgroundColor: Colors.deepPurpleAccent,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8,
        ),
        itemCount: demoVideos.length,
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => _showSnack(context, "Coming soon: Video Viewer"),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(demoVideos[i],
                  style: const TextStyle(fontSize: 14, color: Colors.white70)),
            ),
          ),
        ),
      ),
    );
  }
}

// 🧠 TEMPLATE LIBRARY
class TemplateLibraryScreen extends StatelessWidget {
  const TemplateLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final templates = ["Motivational", "Gaming", "Tech", "Vlog", "News", "Business"];
    return Scaffold(
      appBar: AppBar(
        title: const Text("🎨 Template Library"),
        backgroundColor: Colors.deepPurpleAccent,
      ),
      body: ListView.builder(
        itemCount: templates.length,
        padding: const EdgeInsets.all(12),
        itemBuilder: (_, i) => Card(
          color: Colors.white10,
          child: ListTile(
            title: Text(templates[i], style: const TextStyle(color: Colors.white)),
            trailing: const Icon(Icons.play_circle_outline, color: Colors.deepPurpleAccent),
            onTap: () => _showSnack(context, "Template: ${templates[i]} selected"),
          ),
        ),
      ),
    );
  }
}

// 🎬 ULTRA CREATE SCREEN (Full AI Creation)
class UltraCreateScreen extends StatefulWidget {
  const UltraCreateScreen({super.key});

  @override
  State<UltraCreateScreen> createState() => _UltraCreateScreenState();
}

class _UltraCreateScreenState extends State<UltraCreateScreen> {
  final TextEditingController _scriptController = TextEditingController();
  String _selectedLang = 'English';
  String _selectedQuality = 'HD';
  String? _voicePath;
  String? _previewUrl;
  String? _finalUrl;
  bool _isGenerating = false;
  bool _isPreviewing = false;
  WebSocketChannel? _channel;

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  Future<void> _pickVoiceSample() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null) setState(() => _voicePath = result.files.first.path);
  }

  Future<void> _generateVideo() async {
    if (_scriptController.text.isEmpty) return _showSnack('Please enter script');

    setState(() {
      _isGenerating = true;
      _finalUrl = null;
    });

    try {
      final uri = Uri.parse('$backendBase/generate_video');
      final req = http.MultipartRequest('POST', uri)
        ..fields['script'] = _scriptController.text
        ..fields['language'] = _selectedLang
        ..fields['quality'] = _selectedQuality;

      if (_voicePath != null) {
        req.files.add(await http.MultipartFile.fromPath('voice', _voicePath!));
      }

      final res = await req.send();
      final body = await http.Response.fromStream(res);
      if (body.statusCode == 200) {
        final data = jsonDecode(body.body);
        final jobId = data['job_id'];
        _connectWebSocket(jobId);
      } else {
        _showSnack('Failed to start generation');
      }
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  void _connectWebSocket(String jobId) {
    final wsUrl = backendBase.replaceFirst('https', 'wss') + '/status/$jobId';
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    setState(() => _isPreviewing = true);

    _channel!.stream.listen((msg) {
      final data = jsonDecode(msg);
      if (data['preview'] != null) setState(() => _previewUrl = data['preview']);
      if (data['final_url'] != null) {
        setState(() {
          _finalUrl = data['final_url'];
          _isPreviewing = false;
        });
      }
    });
  }

  Future<void> _downloadFinalVideo() async {
    if (_finalUrl == null) return _showSnack('Video not ready');
    try {
      final res = await http.get(Uri.parse(_finalUrl!));
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/visora_final_video.mp4');
      await file.writeAsBytes(res.bodyBytes);
      _showSnack('Saved: ${file.path}');
    } catch (e) {
      _showSnack('Download failed: $e');
    }
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🎬 Ultra AI Creator"), backgroundColor: Colors.deepPurpleAccent),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Script:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _scriptController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: "Enter your video script...",
                filled: true,
                fillColor: Colors.white12,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField(
                    value: _selectedLang,
                    items: ['English', 'Hindi', 'Tamil', 'Telugu']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedLang = v!),
                    decoration: const InputDecoration(labelText: "Language"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField(
                    value: _selectedQuality,
                    items: ['HD', 'Full HD', '4K']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedQuality = v!),
                    decoration: const InputDecoration(labelText: "Quality"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickVoiceSample,
              icon: const Icon(Icons.mic_none),
              label: Text(_voicePath == null ? "Upload Voice Sample" : "Voice Selected ✅"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateVideo,
                icon: const Icon(Icons.play_circle_outline),
                label: Text(_isGenerating ? "Generating..." : "Generate Video"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14)),
              ),
            ),
            if (_isPreviewing && _previewUrl != null) ...[
              const SizedBox(height: 24),
              const Text("Live Preview:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(_previewUrl!, fit: BoxFit.cover),
              ),
            ],
            if (_finalUrl != null) ...[
              const SizedBox(height: 30),
              const Text("✅ Video Ready!"),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _downloadFinalVideo,
                icon: const Icon(Icons.download),
                label: const Text("Download Video"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// 👤 PROFILE SCREEN
class VisoraProfileScreen extends StatelessWidget {
  const VisoraProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text("Profile"), backgroundColor: Colors.deepPurpleAccent),
        body: const Center(child: Text("Login / Upload Integration coming soon", style: TextStyle(color: Colors.white70))),
      );

// 🌐 Global Utils
Future<void> _showSnack(BuildContext ctx, String msg) async =>
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
