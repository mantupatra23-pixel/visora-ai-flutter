import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? token;
  List<String> uploadedAssets = [];
  bool uploading = false;
  final _titleCtl = TextEditingController();
  final _scriptCtl = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments;
    if (args != null && args is String) token = args;
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null) return;
    final path = result.files.single.path;
    if (path == null) return;
    final file = File(path);
    setState(() => uploading = true);
    try {
      final res = await ApiService.uploadFile(file, token ?? '');
      if (res.containsKey('url')) {
        uploadedAssets.add(res['url']);
      } else if (res.containsKey('file')) {
        uploadedAssets.add(res['file']);
      }
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploaded')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload error: $e')));
    } finally {
      setState(() => uploading = false);
    }
  }

  Future<void> _createJob() async {
    if ((token ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login first')));
      return;
    }
    final title = _titleCtl.text.trim();
    final script = _scriptCtl.text.trim();
    if (script.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Script is required')));
      return;
    }
    try {
      final resp = await ApiService.createJob(
        token: token!,
        title: title.isEmpty ? 'Quick Job' : title,
        script: script,
        assetUrls: uploadedAssets,
        language: 'hi',
        quality: '1080p',
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Job created: ${resp['id'] ?? resp['jobId'] ?? 'ok'}')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create job error: $e')));
    }
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _scriptCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visora — Dashboard'),
        actions: [
          IconButton(onPressed: () => Navigator.pushReplacementNamed(context, '/'), icon: const Icon(Icons.logout))
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: _titleCtl, decoration: const InputDecoration(labelText: 'Project Title')),
          const SizedBox(height: 12),
          TextField(controller: _scriptCtl, decoration: const InputDecoration(labelText: 'Write script or idea...'), maxLines: 6),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: uploading ? null : _pickAndUpload,
                icon: const Icon(Icons.upload_file),
                label: Text(uploading ? 'Uploading...' : 'Upload asset'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _createJob,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Generate'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Align(alignment: Alignment.centerLeft, child: Text('Uploaded assets:', style: Theme.of(context).textTheme.titleMedium)),
          const SizedBox(height: 8),
          for (final a in uploadedAssets)
            Card(
              child: ListTile(
                title: Text(a, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => setState(() => uploadedAssets.remove(a)),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
