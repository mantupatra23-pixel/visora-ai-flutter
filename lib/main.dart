// lib/main.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:web_socket_channel/io.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const VisoraApp());
}

class VisoraApp extends StatelessWidget {
  const VisoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Visora – Ultimate AI Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F1020),
        primaryColor: Colors.deepPurpleAccent,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurpleAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          ),
        ),
      ),
      home: const GenerateVideoScreen(),
    );
  }
}

/// -----------------
/// CONFIG: Backend
/// -----------------
const String backendBase = 'https://visora-ai-5nqs.onrender.com'; // <-- your live backend

/// -----------------
/// API helpers (simple)
/// -----------------
class Api {
  static Future<Map<String, dynamic>> generateVideo({
    required String script,
    required String language,
    required String length,
    required String quality,
    required String voiceType,
    required String mood,
    File? voiceFile,
  }) async {
    final uri = Uri.parse('$backendBase/api/generate');
    final request = http.MultipartRequest('POST', uri);

    request.fields['script'] = script;
    request.fields['language'] = language;
    request.fields['length'] = length;
    request.fields['quality'] = quality;
    request.fields['voice_type'] = voiceType;
    request.fields['mood'] = mood;

    if (voiceFile != null) {
      final stream = http.ByteStream(voiceFile.openRead());
      final len = await voiceFile.length();
      request.files.add(http.MultipartFile('voice_file', stream, len, filename: voiceFile.path.split('/').last));
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Server error ${response.statusCode}: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> getStatus(String jobId) async {
    final uri = Uri.parse('$backendBase/api/status/$jobId');
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } else {
      throw Exception('Status error ${res.statusCode}');
    }
  }
}

/// -----------------
/// LivePreview Widget (websocket)
/// -----------------
class LivePreview extends StatefulWidget {
  final String jobId;
  const LivePreview({required this.jobId, super.key});

  @override
  State<LivePreview> createState() => _LivePreviewState();
}

class _LivePreviewState extends State<LivePreview> {
  IOWebSocketChannel? _channel;
  String? _base64Image;
  double _progress = 0.0;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _connectWs();
  }

  void _connectWs() {
    try {
      final ws = backendBase.replaceFirst('https', 'wss').replaceFirst('http', 'ws');
      final uri = '$ws/ws/preview/${widget.jobId}';
      _channel = IOWebSocketChannel.connect(uri);
      _sub = _channel!.stream.listen((message) {
        // message may be JSON object or string
        try {
          final dynamic data = (message is String) ? jsonDecode(message) : message;
          if (data is Map && data['type'] == 'frame') {
            setState(() {
              _base64Image = data['image'];
              final p = data['progress'];
              if (p is num) _progress = (p / 100).clamp(0.0, 1.0);
            });
          }
        } catch (_) {
          // ignore parse errors
        }
      }, onError: (e) {
        // ignore
      }, onDone: () {
        // connection closed
      });
    } catch (e) {
      // ignore connection failure
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_base64Image != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              base64Decode(_base64Image!),
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          )
        else
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: _progress),
        const SizedBox(height: 6),
        Text('Rendering ${(_progress * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}

/// -----------------
/// Main Generate Screen
/// -----------------
class GenerateVideoScreen extends StatefulWidget {
  const GenerateVideoScreen({super.key});

  @override
  State<GenerateVideoScreen> createState() => _GenerateVideoScreenState();
}

class _GenerateVideoScreenState extends State<GenerateVideoScreen> {
  final TextEditingController _scriptCtl = TextEditingController();
  bool _isGenerating = false;
  String? _jobId;
  double _progress = 0.0;
  String? _resultUrl;
  File? _voiceFile;

  // user options
  String _language = 'Hindi';
  String _length = 'Short (0-60s)';
  String _quality = '1080p';
  String _voiceType = 'AI Female';
  String _mood = 'Motivational';

  final List<String> languages = [
    'English',
    'Hindi',
    'Bengali',
    'Tamil',
    'Telugu',
    'Marathi',
    'Gujarati',
    'Punjabi',
    'Odia',
    'Malayalam',
    'Kannada'
  ];

  final List<String> lengths = ['Short (0-60s)', 'Medium (1-3min)', 'Long (3-10min)'];
  final List<String> qualities = ['720p', '1080p', '4K'];
  final List<String> voices = ['AI Female', 'AI Male', 'Narrator', 'Celebrity (paid)'];
  final List<String> moods = ['Motivational', 'Emotional', 'Calm', 'Action', 'Cinematic', 'Nature'];

  Timer? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scriptCtl.dispose();
    super.dispose();
  }

  Future<void> _pickVoiceFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['mp3', 'wav', 'm4a', 'ogg']);
      if (res != null && res.files.single.path != null) {
        setState(() {
          _voiceFile = File(res.files.single.path!);
        });
      }
    } catch (e) {
      _showSnack('File pick failed: $e');
    }
  }

  Future<void> _startGenerate() async {
    final script = _scriptCtl.text.trim();
    if (script.isEmpty) {
      _showSnack('Please enter script text.');
      return;
    }

    setState(() {
      _isGenerating = true;
      _progress = 0;
      _resultUrl = null;
      _jobId = null;
    });

    try {
      final res = await Api.generateVideo(
        script: script,
        language: _language,
        length: _length,
        quality: _quality,
        voiceType: _voiceType,
        mood: _mood,
        voiceFile: _voiceFile,
      );

      // backend may return jobId under jobId, id, taskId or job_id
      final String? jobId = (res['jobId'] ?? res['id'] ?? res['taskId'] ?? res['job_id'])?.toString();
      final String? result = (res['result'] ?? res['url'] ?? res['download'])?.toString();

      if (jobId != null) {
        setState(() {
          _jobId = jobId;
        });
        // start polling and show websocket live preview widget
        _startPolling(jobId);
      } else if (result != null) {
        // synchronous response
        setState(() {
          _resultUrl = result;
          _isGenerating = false;
          _progress = 1.0;
        });
      } else {
        // unexpected but show response
        _showSnack('Unexpected response: ${res.toString()}');
        setState(() => _isGenerating = false);
      }
    } catch (e) {
      _showSnack('Generate failed: $e');
      setState(() => _isGenerating = false);
    }
  }

  void _startPolling(String jobId) {
    _pollTimer?.cancel();
    // start quick immediate fetch
    _pollStatusOnce(jobId);
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _pollStatusOnce(jobId));
  }

  Future<void> _pollStatusOnce(String jobId) async {
    try {
      final resp = await Api.getStatus(jobId);
      final status = (resp['status'] ?? '').toString().toLowerCase();
      final progressVal = resp['progress'] ?? resp['percent'] ?? 0;
      final result = (resp['result'] ?? resp['url'] ?? resp['download'])?.toString();

      setState(() {
        if (progressVal is num) _progress = (progressVal.toDouble() / 100.0).clamp(0.0, 1.0);
        if (result != null) _resultUrl = result;
      });

      if (status.contains('complete') || status.contains('done') || _resultUrl != null) {
        _pollTimer?.cancel();
        setState(() {
          _isGenerating = false;
          _progress = 1.0;
        });
      } else if (status.contains('failed') || status.contains('error')) {
        _pollTimer?.cancel();
        setState(() {
          _isGenerating = false;
        });
        _showSnack('Generation failed on server.');
      }
    } catch (e) {
      // ignore transient errors but don't crash
    }
  }

  Future<void> _openResult() async {
    if (_resultUrl == null) return;
    final uri = Uri.parse(_resultUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnack('Cannot open URL.');
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _buildSelector<T>(String label, T value, List<T> options, ValueChanged<T?> onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white70)),
      const SizedBox(height: 6),
      DropdownButtonFormField<T>(
        value: value,
        items: options.map((o) => DropdownMenuItem<T>(value: o, child: Text(o.toString()))).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFF121221),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visora — AI Video Generator'),
        backgroundColor: const Color(0xFF0B0B1A),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _scriptCtl,
              minLines: 4,
              maxLines: 10,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type your script here...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF0D0D14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            _buildSelector<String>('Language', _language, languages, (v) => setState(() => _language = v ?? _language)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _buildSelector<String>('Length', _length, lengths, (v) => setState(() => _length = v ?? _length))),
              const SizedBox(width: 10),
              Expanded(child: _buildSelector<String>('Quality', _quality, qualities, (v) => setState(() => _quality = v ?? _quality))),
            ]),
            const SizedBox(height: 8),
            _buildSelector<String>('Voice', _voiceType, voices, (v) => setState(() => _voiceType = v ?? _voiceType)),
            const SizedBox(height: 8),
            _buildSelector<String>('Mood', _mood, moods, (v) => setState(() => _mood = v ?? _mood)),
            const SizedBox(height: 12),
            Row(children: [
              ElevatedButton.icon(
                onPressed: _pickVoiceFile,
                icon: const Icon(Icons.upload_file),
                label: Text(_voiceFile == null ? 'Upload Voice (opt)' : 'Change Voice'),
              ),
              const SizedBox(width: 12),
              if (_voiceFile != null) Expanded(child: Text(_voiceFile!.path.split('/').last, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 14),
            if (_isGenerating) ...[
              if (_jobId != null) LivePreview(jobId: _jobId!),
              if (_jobId == null) LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text('Generating... ${(_progress * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  _pollTimer?.cancel();
                  setState(() {
                    _isGenerating = false;
                    _jobId = null;
                    _progress = 0;
                  });
                },
                child: const Text('Cancel'),
              ),
            ] else ...[
              ElevatedButton.icon(
                onPressed: _startGenerate,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Generate AI Video'),
              ),
            ],
            const SizedBox(height: 16),
            if (_resultUrl != null)
              Card(
                color: const Color(0xFF0B0B1A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  title: const Text('Video ready', style: TextStyle(color: Colors.white)),
                  subtitle: Text(_resultUrl!, style: const TextStyle(color: Colors.white70), maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.open_in_new), onPressed: _openResult),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _resultUrl));
                        _showSnack('Link copied');
                      },
                    ),
                  ]),
                ),
              ),
            const SizedBox(height: 28),
            const Text('Notes:', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text(
              '• Backend must accept POST /api/generate (multipart) and return {jobId} OR {result}.\n'
              '• WebSocket path: /ws/preview/{jobId} should stream JSON {type:"frame", progress, image(base64)} every ~10s.\n'
              '• GET /api/status/{jobId} returns {status,progress,result}.',
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
