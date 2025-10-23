import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class JobStatusScreen extends StatefulWidget {
  final String jobId;
  const JobStatusScreen({super.key, required this.jobId});

  @override
  State<JobStatusScreen> createState() => _JobStatusScreenState();
}

class _JobStatusScreenState extends State<JobStatusScreen> {
  Map<String, dynamic>? job;
  bool loading = true;

  Future<void> fetchStatus() async {
    try {
      final res = await ApiService.getJobStatus(widget.jobId);
      setState(() => job = res);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    fetchStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Job Status"),
        backgroundColor: Colors.purpleAccent,
      ),
      body: Center(
        child: loading
            ? const CircularProgressIndicator(color: Colors.purpleAccent)
            : job == null
                ? const Text("No job data found", style: TextStyle(color: Colors.white))
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      "Status: ${job!['status'] ?? 'Unknown'}\n\nVideo URL: ${job!['videoUrl'] ?? 'Processing...'}",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
      ),
    );
  }
}
