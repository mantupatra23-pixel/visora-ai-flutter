import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'job_status_screen.dart';

class CreateVideoScreen extends StatefulWidget {
  const CreateVideoScreen({super.key});
  @override
  State<CreateVideoScreen> createState() => _CreateVideoScreenState();
}

class _CreateVideoScreenState extends State<CreateVideoScreen> {
  final titleController = TextEditingController();
  final scriptController = TextEditingController();
  bool loading = false;

  Future<void> createVideo() async {
    setState(() => loading = true);
    try {
      final res = await ApiService.createVideoJob(
        title: titleController.text,
        script: scriptController.text,
      );
      if (res['success'] == true) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => JobStatusScreen(jobId: res['jobId'] ?? '')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed to create job')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Create Video'),
        backgroundColor: Colors.purpleAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: "Video Title",
                labelStyle: TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: scriptController,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: "Script",
                labelStyle: TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: loading ? null : createVideo,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 50, vertical: 14)),
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Create Video", style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
