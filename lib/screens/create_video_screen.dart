// lib/screens/create_video_screen.dart
// Visora - Create Video Screen (Script -> Video & Image -> Video)
// Backend connected (POST /generate_video and poll GET /status/{job_id})
//
// Required packages: http, file_picker, lottie, google_fonts, url_launcher

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';

/// <<< CHANGE THIS TO YOUR LIVE BACKEND BASE URL >>>
const String backendBase = 'https://visora-ai-5nqs.onrender.com';

class CreateVideoScreen extends StatefulWidget {
  const CreateVideoScreen({super.key});

  @override
  State<CreateVideoScreen> createState() => _CreateVideoScreenState();
}

class _CreateVideoScreenState extends State<CreateVideoScreen> {
  // Mode: "script" or "image"
  String mode = 'script';

  // Direction: "short" or "long"
  String videoMode = 'short';

  // Form controllers
  final TextEditingController scriptCtrl = TextEditingController();
  final TextEditingController titleCtrl = TextEditingController();
  final TextEditingController captionCtrl = TextEditingController();

  // Options
  String selectedLanguage = 'Hindi';
  String selectedVoice = 'female_01';
  String selectedQuality = '1080p';
  String backgroundMusic = 'auto';

  // Uploaded images (paths or uploaded URLs)
  List<PlatformFile> pickedFiles = [];

  // UI state
  bool isGenerating = false;
  String jobId = '';
  double progress = 0.0;
  String statusText = '';
  String? resultDownloadUrl;
  Timer? _statusPoller;

  // Some demo voice list (in real app fetch from backend)
  final List<Map<String, String>> demoVoices = [
    {'id': 'female_01', 'name': 'Female - Hindi'},
    {'id': 'male_01', 'name': 'Male - Hindi'},
    {'id': 'eng_female', 'name': 'Female - English'},
  ];

  // Quality options
  final List<String> qualityOptions = ['480p', '720p', '1080p', '2K', '4K'];

  @override
  void dispose() {
    _statusPoller?.cancel();
    scriptCtrl.dispose();
    titleCtrl.dispose();
    captionCtrl.dispose();
    super.dispose();
  }

  // ---------------- UI HELPERS ----------------

  Widget _toggleModeButton(String value, IconData icon, String label) {
    final bool active = mode == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => mode = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? Colors.purple : Colors.grey[850],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            Icon(icon, color: Colors.white),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: Colors.white)),
          ]),
        ),
      ),
    );
  }

  Widget _directionSelector() {
    return Row(children: [
      Expanded(
        child: ElevatedButton(
          onPressed: () => setState(() => videoMode = 'short'),
          style: ElevatedButton.styleFrom(backgroundColor: videoMode == 'short' ? Colors.pink : Colors.grey[800]),
          child: const Text('Short (Reel)'),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: ElevatedButton(
          onPressed: () => setState(() => videoMode = 'long'),
          style: ElevatedButton.styleFrom(backgroundColor: videoMode == 'long' ? Colors.pink : Colors.grey[800]),
          child: const Text('Long (YouTube)'),
        ),
      ),
    ]);
  }

  // ---------------- IMAGE PICK ----------------

  Future<void> pickImages() async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.image);
    if (res == null) return;
    setState(() {
      pickedFiles = res.files;
    });
  }

  Future<void> removeImageAt(int idx) async {
    setState(() {
      pickedFiles.removeAt(idx);
    });
  }

  // ---------------- GENERATE / BACKEND ----------------

  Map<String, dynamic> _buildPayload() {
    if (mode == 'script') {
      return {
        "mode": "script",
        "video_mode": videoMode,
        "language": selectedLanguage,
        "voice_id": selectedVoice,
        "quality": selectedQuality,
        "script_text": scriptCtrl.text.trim(),
        "title": titleCtrl.text.trim(),
        "background_music": backgroundMusic,
      };
    } else {
      // Image mode - in this simple flow we upload images first then send urls
      // However for this file, we'll send placeholders and let backend accept multipart later.
      return {
        "mode": "image",
        "video_mode": videoMode,
        "language": selectedLanguage,
        "voice_id": selectedVoice,
        "quality": selectedQuality,
        "caption_text": captionCtrl.text.trim(),
        "image_count": pickedFiles.length,
        "background_music": backgroundMusic,
      };
    }
  }

  Future<void> _generateVideo() async {
    // Basic validation
    if (mode == 'script' && scriptCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Script empty — please add text')));
      return;
    }
    if (mode == 'image' && pickedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one image')));
      return;
    }

    setState(() {
      isGenerating = true;
      progress = 0.01;
      statusText = 'Submitting job...';
      resultDownloadUrl = null;
      jobId = '';
    });

    try {
      // If images present, first upload them to backend (multipart) and get URLs
      List<String> uploadedImageUrls = [];
      if (mode == 'image' && pickedFiles.isNotEmpty) {
        statusText = 'Uploading images...';
        // Simple sequential upload - backend must expose /upload_image (example)
        for (var f in pickedFiles) {
          final uploadResult = await _uploadImageFile(f);
          if (uploadResult != null) uploadedImageUrls.add(uploadResult);
        }
      }

      // Build payload
      final payload = _buildPayload();
      if (mode == 'image') payload['image_urls'] = uploadedImageUrls;

      // POST to /generate_video
      final url = Uri.parse('$backendBase/generate_video');
      final resp = await http.post(url, body: jsonEncode(payload), headers: {'Content-Type': 'application/json'}).timeout(const Duration(seconds: 30));

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final body = jsonDecode(resp.body);
        final id = body['job_id']?.toString() ?? body['id']?.toString() ?? '';
        if (id.isEmpty) {
          setState(() {
            isGenerating = false;
            statusText = 'Server returned no job id';
          });
          return;
        }
        setState(() {
          jobId = id;
          statusText = 'Job queued (ID: $jobId)';
          progress = 0.05;
        });
        // Start polling status
        _startStatusPoller(jobId);
      } else {
        setState(() {
          isGenerating = false;
          statusText = 'Generate failed (${resp.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        isGenerating = false;
        statusText = 'Request failed: $e';
      });
    }
  }

  Future<String?> _uploadImageFile(PlatformFile f) async {
    try {
      final fileBytes = f.bytes;
      final fileName = f.name;
      // if bytes unavailable (mobile), use path
      final uri = Uri.parse('$backendBase/upload_image');
      var request = http.MultipartRequest('POST', uri);
      if (fileBytes != null) {
        request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName));
      } else if (f.path != null) {
        request.files.add(await http.MultipartFile.fromPath('file', f.path!, filename: fileName));
      } else {
        return null;
      }
      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return body['url']?.toString();
      } else {
        // ignore for now
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // ---------------- STATUS POLLING ----------------

  void _startStatusPoller(String id) {
    _statusPoller?.cancel();
    _statusPoller = Timer.periodic(const Duration(seconds: 3), (_) => _pollStatus(id));
  }

  Future<void> _pollStatus(String id) async {
    try {
      final resp = await http.get(Uri.parse('$backendBase/status/$id')).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final st = body['status']?.toString() ?? 'unknown';
        final prog = (body['progress'] is num) ? (body['progress'] as num).toDouble() : null;
        final download = body['download_url']?.toString();

        setState(() {
          statusText = st;
          if (prog != null) progress = prog.clamp(0.0, 1.0);
          if (download != null && download.isNotEmpty) {
            resultDownloadUrl = download;
          }
        });

        if (st.toLowerCase() == 'completed' || st.toLowerCase() == 'done' || resultDownloadUrl != null) {
          // finished
          _statusPoller?.cancel();
          setState(() {
            isGenerating = false;
            progress = 1.0;
            statusText = 'Completed';
          });
          return;
        }
        if (st.toLowerCase() == 'failed' || st.toLowerCase() == 'error') {
          _statusPoller?.cancel();
          setState(() {
            isGenerating = false;
            statusText = 'Failed';
          });
          return;
        }
      } else if (resp.statusCode == 404) {
        // job not found - stop after some time
        setState(() {
          statusText = 'Job not found';
        });
      }
    } catch (e) {
      // ignore transient network errors
      setState(() {
        statusText = 'Waiting...';
      });
    }
  }

  // ---------------- DOWNLOAD & OPEN ----------------

  Future<void> _openDownload() async {
    final url = resultDownloadUrl;
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No download URL')));
      return;
    }
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open link')));
    }
  }

  // ---------------- BUILD ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07070A),
      appBar: AppBar(
        title: Text('Create Video', style: GoogleFonts.poppins()),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            onPressed: () {
              // quick tutorial or help
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('How it works'),
                  content: const Text('Choose Script or Image mode → Select Short/Long → Pick voice & quality → Generate.'),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                ),
              );
            },
            icon: const Icon(Icons.help_outline),
          )
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mode toggle
                  Row(children: [
                    _toggleModeButton('script', Icons.edit_document, 'Script → Video'),
                    const SizedBox(width: 8),
                    _toggleModeButton('image', Icons.image, 'Image → Video'),
                  ]),
                  const SizedBox(height: 12),

                  // Direction selector
                  Text('Video Type', style: GoogleFonts.poppins(color: Colors.white70)),
                  const SizedBox(height: 6),
                  _directionSelector(),
                  const SizedBox(height: 12),

                  // Title
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Optional Title',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Mode-specific area
                  if (mode == 'script') ...[
                    Text('Script', style: GoogleFonts.poppins(color: Colors.white70)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: scriptCtrl,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 8,
                      decoration: InputDecoration(
                        hintText: 'Write or paste your script here...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.grey[900],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                  ] else ...[
                    Text('Images', style: GoogleFonts.poppins(color: Colors.white70)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: pickImages,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Pick Images'),
                        ),
                        const SizedBox(width: 10),
                        if (pickedFiles.isNotEmpty)
                          Text('${pickedFiles.length} selected', style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (pickedFiles.isNotEmpty)
                      SizedBox(
                        height: 110,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: pickedFiles.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final f = pickedFiles[i];
                            return Stack(
                              children: [
                                Container(
                                  width: 140,
                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
                                  child: f.path != null
                                      ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(f.path!), fit: BoxFit.cover))
                                      : ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(f.bytes!, fit: BoxFit.cover)),
                                ),
                                Positioned(
                                  right: 6,
                                  top: 6,
                                  child: InkWell(
                                    onTap: () => removeImageAt(i),
                                    child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.close, size: 18)),
                                  ),
                                )
                              ],
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: captionCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Optional caption / short script for images',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.grey[900],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Language & Voice & Quality
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedLanguage,
                        items: ['Hindi', 'English', 'Tamil', 'Telugu', 'Bengali'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => selectedLanguage = v ?? selectedLanguage),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey[900],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedVoice,
                        items: demoVoices.map((v) => DropdownMenuItem(value: v['id'], child: Text(v['name'] ?? 'Voice'))).toList(),
                        onChanged: (v) => setState(() => selectedVoice = v ?? selectedVoice),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey[900],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedQuality,
                        items: qualityOptions.map((q) => DropdownMenuItem(value: q, child: Text(q))).toList(),
                        onChanged: (v) => setState(() => selectedQuality = v ?? selectedQuality),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey[900],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: backgroundMusic,
                        items: ['auto', 'none', 'soft', 'energetic'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => backgroundMusic = v ?? backgroundMusic),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey[900],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // Generate button & status
                  Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isGenerating ? null : _generateVideo,
                        icon: const Icon(Icons.play_arrow),
                        label: Text(isGenerating ? 'Generating...' : 'Generate Video'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),

                  // Status / progress
                  if (isGenerating) ...[
                    Text(statusText, style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: progress, color: Colors.pinkAccent, backgroundColor: Colors.white12),
                    const SizedBox(height: 8),
                    Text('Job: $jobId', style: const TextStyle(color: Colors.white54)),
                  ],

                  if (!isGenerating && resultDownloadUrl != null) ...[
                    const SizedBox(height: 12),
                    Text('Result ready', style: const TextStyle(color: Colors.greenAccent)),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _openDownload,
                      icon: const Icon(Icons.download),
                      label: const Text('Download Video'),
                    ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),

            // Tiny floating helper / cancel
            if (isGenerating)
              Positioned(
                right: 12,
                top: 12,
                child: FloatingActionButton.small(
                  onPressed: () {
                    // Cancel polling only (backend cancel not implemented)
                    _statusPoller?.cancel();
                    setState(() {
                      isGenerating = false;
                      statusText = 'Cancelled by user';
                    });
                  },
                  backgroundColor: Colors.redAccent,
                  child: const Icon(Icons.close),
                ),
              )
          ],
        ),
      ),
    );
  }
}
