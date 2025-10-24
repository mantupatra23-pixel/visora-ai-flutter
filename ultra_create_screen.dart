// lib/ultra_create_screen.dart
// VISORA v41 – UltraCreateScreen (Live Preview + Download)

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

const String backendBase = "https://visora-ai-5nqs.onrender.com";

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
  String? _jobId;
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
    if (result != null && result.files.isNotEmpty) {
      setState(() => _voicePath = result.files.first.path);
    }
  }

  Future<void> _generateVideo() async {
    if (_scriptController.text.isEmpty) {
      _showSnack('Please enter a script');
      return;
    }

    setState(() {
      _isGenerating = true;
      _jobId = null;
      _finalUrl = null;
    });

    try {
      final uri = Uri.parse('$backendBase/generate_video');
      final request = http.MultipartRequest('POST', uri)
        ..fields['script'] = _scriptController.text
        ..fields['language'] = _selectedLang
        ..fields['quality'] = _selectedQuality;

      if (_voicePath != null) {
        request.files.add(await http.MultipartFile.fromPath('voice', _voicePath!));
      }

      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final jobId = data['job_id'];
        setState(() {
          _jobId = jobId;
        });
        _connectWebSocket(jobId);
      } else {
        _showSnack('Failed to start video generation');
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
      if (data['preview'] != null) {
        setState(() => _previewUrl = data['preview']);
      }
      if (data['final_url'] != null) {
        setState(() {
          _finalUrl = data['final_url'];
          _isPreviewing = false;
        });
      }
    }, onError: (err) {
      _showSnack('WebSocket error: $err');
      setState(() => _isPreviewing = false);
    });
  }

  Future<void> _downloadFinalVideo() async {
    if (_finalUrl == null) {
      _showSnack('Final video not available yet');
      return;
    }

    try {
      final response = await http.get(Uri.parse(_finalUrl!));
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/visora_final_video.mp4');
      await file.writeAsBytes(response.bodyBytes);
      _showSnack('Video downloaded: ${file.path}');
    } catch (e) {
      _showSnack('Download failed: $e');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🎬 Ultra AI Creator"),
        backgroundColor: Colors.deepPurpleAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Enter your video script:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _scriptController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: "Type your script here...",
                filled: true,
                fillColor: Colors.white12,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedLang,
                    decoration: const InputDecoration(labelText: "Language"),
                    dropdownColor: const Color(0xFF1E1E28),
                    items: ['English', 'Hindi', 'Tamil', 'Telugu', 'Bengali']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedLang = v!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedQuality,
                    decoration: const InputDecoration(labelText: "Quality"),
                    dropdownColor: const Color(0xFF1E1E28),
                    items: ['HD', 'Full HD', '4K']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedQuality = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _pickVoiceSample,
              icon: const Icon(Icons.mic_none),
              label: Text(_voicePath == null ? "Upload Voice Sample" : "Voice Selected ✅"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateVideo,
                icon: const Icon(Icons.play_circle_outline),
                label: Text(_isGenerating ? "Generating..." : "Generate Video"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 30),
            if (_isPreviewing)
              Column(
                children: [
                  const Text("Live Preview (updates every 10 sec)", style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 12),
                  if (_previewUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(_previewUrl!, fit: BoxFit.cover),
                    )
                  else
                    const CircularProgressIndicator(),
                ],
              ),
            if (_finalUrl != null) ...[
              const SizedBox(height: 30),
              const Text("✅ Video Ready!", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _downloadFinalVideo,
                  icon: const Icon(Icons.download),
                  label: const Text("Download Final Video"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
