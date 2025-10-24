// lib/screens/generate_video_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class GenerateVideoScreen extends StatefulWidget {
  const GenerateVideoScreen({Key? key}) : super(key: key);

  @override
  State<GenerateVideoScreen> createState() => _GenerateVideoScreenState();
}

class _GenerateVideoScreenState extends State<GenerateVideoScreen> {
  // Backend base (use your live backend)
  final String backendBase = 'https://visora-ai-5nqs.onrender.com';

  final _scriptController = TextEditingController();
  bool _isGenerating = false;
  String? _jobId;
  double _progress = 0;
  String? _resultUrl;

  // user choices
  String _language = 'Hindi';
  String _videoLength = 'Short (0-60s)';
  String _quality = '1080p';
  String _voiceType = 'AI Female';
  String _mood = 'Motivational';
  File? _customVoiceFile;

  // available options (you can extend)
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

  final List<String> lengths = [
    'Short (0-60s)',
    'Medium (1-3min)',
    'Long (3-10min)',
  ];

  final List<String> qualities = ['720p', '1080p', '4K'];

  final List<String> voices = ['AI Female', 'AI Male', 'Narrator', 'Celebrity (paid)'];

  final List<String> moods = [
    'Motivational',
    'Emotional',
    'Calm',
    'Action',
    'Cinematic',
    'Nature'
  ];

  Timer? _pollTimer;

  @override
  void dispose() {
    _scriptController.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> pickCustomVoice() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'ogg'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _customVoiceFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> startGeneration() async {
    final script = _scriptController.text.trim();
    if (script.isEmpty) {
      _showSnack('Please enter the script text.');
      return;
    }

    setState(() {
      _isGenerating = true;
      _progress = 0;
      _resultUrl = null;
      _jobId = null;
    });

    try {
      // Create multipart request
      final uri = Uri.parse('$backendBase/api/generate');
      final request = http.MultipartRequest('POST', uri);

      // Add simple fields
      request.fields['script'] = script;
      request.fields['language'] = _language;
      request.fields['length'] = _videoLength;
      request.fields['quality'] = _quality;
      request.fields['voice_type'] = _voiceType;
      request.fields['mood'] = _mood;

      // If user uploaded custom voice, attach it
      if (_customVoiceFile != null) {
        final fileStream = http.ByteStream(_customVoiceFile!.openRead());
        final length = await _customVoiceFile!.length();
        final multipartFile = http.MultipartFile('voice_file', fileStream, length,
            filename: _customVoiceFile!.path.split('/').last);
        request.files.add(multipartFile);
      }

      // Send
      final streamedResp = await request.send();
      final resp = await http.Response.fromStream(streamedResp);

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final body = json.decode(resp.body);
        // Expecting { jobId: "...", message: "queued" }
        final jobId = body['jobId'] ?? body['id'] ?? body['taskId'];
        if (jobId == null) {
          // maybe backend returned result url directly
          final result = body['result'] ?? body['url'];
          setState(() {
            _resultUrl = result;
            _isGenerating = false;
          });
          return;
        }

        setState(() {
          _jobId = jobId.toString();
        });

        // Poll for status
        _startPolling(jobId.toString());
      } else {
        final text = resp.body;
        _showSnack('Server error: ${resp.statusCode}\n$text');
        setState(() => _isGenerating = false);
      }
    } catch (e) {
      _showSnack('Request failed: $e');
      setState(() => _isGenerating = false);
    }
  }

  void _startPolling(String jobId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      try {
        final statusUri = Uri.parse('$backendBase/api/status/$jobId');
        final r = await http.get(statusUri).timeout(const Duration(seconds: 10));

        if (r.statusCode == 200) {
          final body = json.decode(r.body);
          final status = (body['status'] ?? '').toString().toLowerCase();
          final progress = (body['progress'] ?? body['percent'] ?? 0);
          final resultUrl = body['result'] ?? body['url'] ?? body['download'];

          setState(() {
            _progress = (progress is num) ? (progress.toDouble() / 100.0) : _progress;
          });

          if (status.contains('done') || status.contains('completed') || resultUrl != null) {
            _pollTimer?.cancel();
            setState(() {
              _isGenerating = false;
              _resultUrl = resultUrl?.toString();
              _progress = 1.0;
            });
          } else if (status.contains('failed') || status.contains('error')) {
            _pollTimer?.cancel();
            setState(() {
              _isGenerating = false;
            });
            _showSnack('Generation failed on backend.');
          }
          // else keep polling
        } else {
          // ignore intermittent errors, but stop if many retries happen
        }
      } catch (e) {
        // network hiccup - ignore here and keep polling
      }
    });
  }

  Future<void> openResult() async {
    if (_resultUrl == null) return;
    final url = _resultUrl!;
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      _showSnack('Cannot open URL: $url');
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _buildSelector({
    required String label,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        child,
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Generate AI Video')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: ListView(
            children: [
              TextField(
                controller: _scriptController,
                minLines: 4,
                maxLines: 10,
                decoration: const InputDecoration(
                    labelText: 'Script / Caption',
                    hintText: 'Write what you want the voice to say...',
                    border: OutlineInputBorder()),
              ),
              _buildSelector(
                label: 'Language',
                child: DropdownButtonFormField<String>(
                  value: _language,
                  items: languages.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                  onChanged: (v) => setState(() => _language = v ?? _language),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildSelector(
                      label: 'Video Length',
                      child: DropdownButtonFormField<String>(
                        value: _videoLength,
                        items: lengths.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                        onChanged: (v) => setState(() => _videoLength = v ?? _videoLength),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSelector(
                      label: 'Quality',
                      child: DropdownButtonFormField<String>(
                        value: _quality,
                        items: qualities.map((q) => DropdownMenuItem(value: q, child: Text(q))).toList(),
                        onChanged: (v) => setState(() => _quality = v ?? _quality),
                      ),
                    ),
                  ),
                ],
              ),
              _buildSelector(
                label: 'Voice',
                child: DropdownButtonFormField<String>(
                  value: _voiceType,
                  items: voices.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) => setState(() => _voiceType = v ?? _voiceType),
                ),
              ),
              _buildSelector(
                label: 'Mood / Background Style',
                child: DropdownButtonFormField<String>(
                  value: _mood,
                  items: moods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) => setState(() => _mood = v ?? _mood),
                ),
              ),
              const SizedBox(height: 6),
              Row(children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: Text(_customVoiceFile == null ? 'Upload Custom Voice (opt)' : 'Change Voice File'),
                  onPressed: pickCustomVoice,
                ),
                const SizedBox(width: 12),
                if (_customVoiceFile != null)
                  Expanded(child: Text(_customVoiceFile!.path.split('/').last, overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 14),
              if (_isGenerating) ...[
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 10),
                Text('Generating... ${(_progress * 100).clamp(0, 100).toStringAsFixed(0)}%'),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () {
                    _pollTimer?.cancel();
                    setState(() {
                      _isGenerating = false;
                    });
                  },
                  child: const Text('Cancel'),
                ),
              ] else ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Generate AI Video'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: startGeneration,
                ),
              ],
              const SizedBox(height: 12),
              if (_resultUrl != null)
                Card(
                  color: Colors.grey[50],
                  child: ListTile(
                    title: const Text('Your video is ready'),
                    subtitle: Text(_resultUrl!),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.open_in_new),
                        onPressed: openResult,
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _resultUrl!));
                          _showSnack('URL copied');
                        },
                      ),
                    ]),
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                'Notes:',
                style: theme.textTheme.caption!.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                '• Backend should accept POST /api/generate with fields: script, language, length, quality, voice_type, mood, optional voice_file (multipart).\n'
                '• Backend must return JSON with {"jobId":"..."} or {"result":"url"}.\n'
                '• Poll status at GET /api/status/{jobId} returning {status, progress, result}.\n',
                style: theme.textTheme.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
