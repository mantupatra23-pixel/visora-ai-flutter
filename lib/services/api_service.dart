import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "https://visora-ai-5nqs.onrender.com/api";

  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/login');
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getProfile(String token) async {
    final url = Uri.parse('$baseUrl/profile');
    final response = await http.get(url, headers: {
      ...headers,
      'Authorization': 'Bearer $token',
    });
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> createVideoJob({
    required String title,
    required String script,
  }) async {
    final url = Uri.parse('$baseUrl/create-job');
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({'title': title, 'script': script}),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getJobStatus(String jobId) async {
    final url = Uri.parse('$baseUrl/job-status/$jobId');
    final response = await http.get(url, headers: headers);
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getTemplates() async {
    final url = Uri.parse('$baseUrl/templates');
    final response = await http.get(url, headers: headers);
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getAdminDashboard() async {
    final url = Uri.parse('$baseUrl/admin/dashboard');
    final response = await http.get(url, headers: headers);
    return _handleResponse(response);
  }

  static Future<void> clearToken() async {
    print("✅ Token cleared successfully (local only).");
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      throw Exception("❌ API Error [${response.statusCode}]: ${response.body}");
    }
  }
}
