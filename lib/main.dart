// lib/main.dart
// Visora - Single-file frontend (final)
// Assumes pubspec contains packages: http, file_picker, image_picker, web_socket_channel, url_launcher, google_fonts, lottie, flutter_svg, firebase_core (optional)
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Optional firebase imports (keep, but ensure firebase is configured on platform)
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Optional: initialize firebase if config exists. If not, app continues without crash.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    // No Firebase configured — proceed but show limited functionality
    debugPrint('Firebase init skipped or failed: $e');
  }

  runApp(const VisoraApp());
}

/// >>> SET YOUR BACKEND BASE URL HERE <<<
/// Use the live backend URL: e.g. https://visora-ai-5nqs.onrender.com
const String backendBase = 'https://visora-ai-5nqs.onrender.com';

class VisoraApp extends StatelessWidget {
  const VisoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Visora – Ultimate AI Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        scaffoldBackgroundColor: const Color(0xFF0C0C14),
        primaryColor: Colors.deepPurpleAccent,
        colorScheme: ColorScheme.fromSwatch().copyWith(secondary: Colors.pinkAccent),
      ),
      home: const UltraCreateScreen(),
    );
  }
}

class UltraCreateScreen extends StatefulWidget {
  const UltraCreateScreen({super.key});

  @override
  State<UltraCreateScreen> createState() => _UltraCreateScreenState();
}

class _UltraCreateScreenState extends State<UltraCreateScreen> {
  final TextEditingController _scriptController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();

  // Options
  String _language = 'hi-IN'; // default Hindi (use IETF tag)
  String _quality = '1080p';
  String _voiceGender = 'female';

  // file picks
  File? _voiceSampleFile;
  XFile? _thumbnailFile;
  bool _isLoading = false;
  String? _jobId;
  String? _resultUrl;
  String _statusText = 'Idle';

  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;

  // Helper to show snack
  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.redAccent : Colors.green,
      ),
    );
  }

  Future<void> _pickVoiceSample() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      setState(() => _voiceSampleFile = File(result.files.single.path!));
      _showSnack('Voice sample selected');
    }
  }

  Future<void> _pickThumbnail() async {
    final ImagePicker img = ImagePicker();
    final XFile? image = await img.pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (image != null) {
      setState(() => _thumbnailFile = image);
      _showSnack('Thumbnail selected');
    }
  }

  Future<Map<String, dynamic>?> _startGeneration() async {
    // Validate script
    final script = _scriptController.text.trim();
    if (script.isEmpty) {
      _showSnack('Please enter a script', error: true);
      return null;
    }

    setState(() {
      _isLoading = true;
      _statusText = 'Submitting job...';
    });

    try {
      final uri = Uri.parse('$backendBase/generate_video');
      final request = http.MultipartRequest('POST', uri);
      request.fields['script'] = script;
      request.fields['language'] = _language;
      request.fields['quality'] = _quality;
      request.fields['voice_gender'] = _voiceGender;
      request.fields['title'] = _titleController.text.trim();

      if (_voiceSampleFile != null) {
        request.files.add(await http.MultipartFile.fromPath('voice_sample', _voiceSampleFile!.path));
      }

      if (_thumbnailFile != null) {
        request.files.add(await http.MultipartFile.fromPath('thumbnail', _thumbnailFile!.path));
      }

      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final jsonResp = jsonDecode(resp.body) as Map<String, dynamic>;
        return jsonResp;
      } else {
        debugPrint('Generate API error ${resp.statusCode}: ${resp.body}');
        _showSnack('Server rejected job: ${resp.statusCode}', error: true);
        return null;
      }
    } catch (e) {
      debugPrint('startGeneration error: $e');
      _showSnack('Failed to submit job', error: true);
      return null;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onCreatePressed() async {
    final resp = await _startGeneration();
    if (resp == null) return;
    final String jobId = resp['job_id']?.toString() ?? '';
    if (jobId.isEmpty) {
      _showSnack('Invalid job response', error: true);
      return;
    }
    setState(() {
      _jobId = jobId;
      _statusText = 'Job submitted: $jobId';
    });
    _connectWebSocket(jobId);
    _showSnack('Job started: $jobId');
  }

  void _connectWebSocket(String jobId) {
    // Close previous if any
    _wsSubscription?.cancel();
    _wsChannel?.sink.close();

    // WebSocket endpoint assumed: ws://backend/socket or wss://
    // Backend must accept: /ws/{job_id} or a general ws route. We'll try /ws/job/<id>
    final wsUri = Uri.parse(backendBase.replaceFirst('http', 'ws') + '/ws/job/$jobId');
    try {
      _wsChannel = WebSocketChannel.connect(wsUri);
    } catch (e) {
      debugPrint('WS connect failed: $e');
      _showSnack('Websocket connect failed', error: true);
      return;
    }

    _wsSubscription = _wsChannel!.stream.listen((event) {
      debugPrint('WS event: $event');
      try {
        final data = (event is String) ? jsonDecode(event) : event;
        if (data is Map && data.containsKey('status')) {
          setState(() {
            _statusText = data['status'].toString();
            if (data.containsKey('progress')) {
              _statusText += ' • ${data['progress']}%';
            }
            if (data.containsKey('result_url')) {
              _resultUrl = data['result_url']?.toString();
            }
          });
        } else {
          // plain string
          setState(() => _statusText = event.toString());
        }
      } catch (ex) {
        setState(() => _statusText = event.toString());
      }
    }, onDone: () {
      debugPrint('WS closed');
    }, onError: (err) {
      debugPrint('WS error: $err');
      _showSnack('WS error', error: true);
    });
  }

  Future<void> _fetchStatusManually() async {
    if (_jobId == null) {
      _showSnack('No job to check', error: true);
      return;
    }
    try {
      final r = await http.get(Uri.parse('$backendBase/status/$_jobId'));
      if (r.statusCode == 200) {
        final map = jsonDecode(r.body) as Map<String, dynamic>;
        setState(() {
          _statusText = map['status']?.toString() ?? _statusText;
          if (map.containsKey('result_url')) _resultUrl = map['result_url']?.toString();
        });
        _showSnack('Status updated');
      } else {
        _showSnack('Status fetch failed', error: true);
      }
    } catch (e) {
      debugPrint('status fetch error: $e');
      _showSnack('Could not fetch status', error: true);
    }
  }

  Future<void> _downloadResult() async {
    if (_resultUrl == null || _resultUrl!.isEmpty) {
      _showSnack('Result not ready', error: true);
      return;
    }
    final uri = Uri.parse(_resultUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnack('Cannot open download URL', error: true);
    }
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _wsChannel?.sink.close();
    _scriptController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Visora – Ultimate AI Studio', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text('Create videos from text • Multi-language • Live preview', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildOptionsCard() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title (optional)'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _scriptController,
            decoration: const InputDecoration(labelText: 'Script (what you want in video)'),
            maxLines: 6,
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _language,
                items: const [
                  DropdownMenuItem(value: 'hi-IN', child: Text('Hindi (hi-IN)')),
                  DropdownMenuItem(value: 'en-US', child: Text('English (en-US)')),
                  DropdownMenuItem(value: 'bn-IN', child: Text('Bengali (bn-IN)')),
                  DropdownMenuItem(value: 'te-IN', child: Text('Telugu (te-IN)')),
                ],
                onChanged: (v) => setState(() => _language = v ?? _language),
                decoration: const InputDecoration(labelText: 'Language'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _quality,
                items: const [
                  DropdownMenuItem(value: '480p', child: Text('480p')),
                  DropdownMenuItem(value: '720p', child: Text('720p')),
                  DropdownMenuItem(value: '1080p', child: Text('1080p')),
                ],
                onChanged: (v) => setState(() => _quality = v ?? _quality),
                decoration: const InputDecoration(labelText: 'Quality'),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _voiceGender,
                items: const [
                  DropdownMenuItem(value: 'female', child: Text('Female Voice')),
                  DropdownMenuItem(value: 'male', child: Text('Male Voice')),
                ],
                onChanged: (v) => setState(() => _voiceGender = v ?? _voiceGender),
                decoration: const InputDecoration(labelText: 'Voice'),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _pickVoiceSample,
              icon: const Icon(Icons.mic),
              label: Text(_voiceSampleFile == null ? 'Add Voice Sample' : 'Voice Added'),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            ElevatedButton.icon(
              onPressed: _pickThumbnail,
              icon: const Icon(Icons.image),
              label: Text(_thumbnailFile == null ? 'Pick Thumbnail' : 'Thumbnail'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _onCreatePressed,
                child: _isLoading ? const SizedBox(height: 18, child: CircularProgressIndicator()) : const Text('Create Video'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _buildLivePreview() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: 260,
        child: Stack(
          children: [
            // Placeholder area for the final video / live frames
            Positioned.fill(
              child: _resultUrl == null
                  ? Container(color: Colors.grey.shade300)
                  : Image.network(_resultUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade300)),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Row(children: [
                IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchStatusManually),
                IconButton(icon: const Icon(Icons.download), onPressed: _downloadResult),
              ]),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Expanded(child: Text(_statusText, style: const TextStyle(color: Colors.white))),
                    if (_isLoading) const SizedBox(width: 8, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtras() {
    return Column(children: [
      ListTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('Backend Base'),
        subtitle: Text(backendBase, style: const TextStyle(fontSize: 12)),
      ),
      ListTile(
        leading: const Icon(Icons.check_circle_outline),
        title: const Text('Real-time WebSocket'),
        subtitle: const Text('Connected to job WebSocket for live progress'),
        trailing: Icon(_wsChannel != null ? Icons.toggle_on : Icons.toggle_off, color: _wsChannel != null ? Colors.green : Colors.grey),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visora – Ultimate AI Studio'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildOptionsCard(),
              _buildLivePreview(),
              const SizedBox(height: 8),
              _buildExtras(),
              const SizedBox(height: 20),
              Center(
                child: Lottie.asset(
                  'assets/lottie/loading.json',
                  width: 70,
                  height: 70,
                  repeat: true,
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
