import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';

class ApiService {
  static const String baseUrl = 'https://visora-ai-5nqs.onrender.com';

  static Future<String> login(String email, String password) async {
    final uri = Uri.parse('$baseUrl/auth/login');
    final res = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['token'] ?? '';
    } else {
      throw Exception('Login failed: ${res.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> uploadFile(File file, String token) async {
    final uri = Uri.parse('$baseUrl/upload');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
    request.files.add(await http.MultipartFile.fromPath(
      'file',
      file.path,
      contentType: MediaType.parse(mimeType),
    ));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } else {
      throw Exception('Upload failed: ${res.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> createJob({
    required String token,
    required String title,
    required String script,
    List<String>? assetUrls,
    String? language,
    String quality = '1080p',
  }) async {
    final uri = Uri.parse('$baseUrl/create-job');
    final body = {
      'title': title,
      'script': script,
      'assets': assetUrls ?? [],
      'language': language ?? 'hi',
      'quality': quality,
    };
    final res = await http.post(uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body));
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } else {
      throw Exception('Create job failed: ${res.statusCode}');
    }
  }
}
