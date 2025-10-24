// lib/screens/settings_screen.dart
// Visora AI Studio – Settings Screen
// Handles preferences, theme, language, backup, notifications, logout
// Requires: http, shared_preferences, google_fonts, lottie

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';

const String backendBase = 'https://visora-ai-5nqs.onrender.com';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isDarkMode = true;
  bool autoBackup = true;
  bool renderAlerts = true;
  String appLanguage = 'English';
  String defaultQuality = '1080p';
  String plan = 'Free';
  int credits = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _fetchUserData();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = prefs.getBool('isDarkMode') ?? true;
      autoBackup = prefs.getBool('autoBackup') ?? true;
      renderAlerts = prefs.getBool('renderAlerts') ?? true;
      appLanguage = prefs.getString('appLanguage') ?? 'English';
      defaultQuality = prefs.getString('defaultQuality') ?? '1080p';
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
    await prefs.setBool('autoBackup', autoBackup);
    await prefs.setBool('renderAlerts', renderAlerts);
    await prefs.setString('appLanguage', appLanguage);
    await prefs.setString('defaultQuality', defaultQuality);
  }

  Future<void> _fetchUserData() async {
    try {
      final res = await http.get(Uri.parse('$backendBase/user/profile')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          plan = data['plan'] ?? 'Free';
          credits = data['credits'] ?? 0;
        });
      }
    } catch (_) {}
    setState(() => loading = false);
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logged out')));
      Navigator.pop(context);
    }
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(title, style: GoogleFonts.poppins(color: Colors.purpleAccent, fontSize: 16, fontWeight: FontWeight.w600)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08080B),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Settings', style: GoogleFonts.poppins()),
      ),
      body: loading
          ? Center(child: Lottie.asset('assets/lottie/loading.json', width: 100))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _sectionTitle('👤 Account & Plan'),
                Container(
                  decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Plan: $plan', style: const TextStyle(color: Colors.white, fontSize: 14)),
                        Text('Credits Left: $credits', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ]),
                      ElevatedButton(
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upgrade feature coming soon!'))),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                        child: const Text('Upgrade'),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                _sectionTitle('🌐 Language Settings'),
                DropdownButtonFormField<String>(
                  value: appLanguage,
                  dropdownColor: Colors.grey[850],
                  items: ['English', 'Hindi', 'Tamil', 'Telugu', 'Bengali']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white))))
                      .toList(),
                  onChanged: (v) => setState(() => appLanguage = v ?? appLanguage),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),

                const SizedBox(height: 16),

                _sectionTitle('🎞️ Video Preferences'),
                DropdownButtonFormField<String>(
                  value: defaultQuality,
                  dropdownColor: Colors.grey[850],
                  items: ['720p', '1080p', '2K', '4K']
                      .map((q) => DropdownMenuItem(value: q, child: Text(q, style: const TextStyle(color: Colors.white))))
                      .toList(),
                  onChanged: (v) => setState(() => defaultQuality = v ?? defaultQuality),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),

                const SizedBox(height: 16),

                _sectionTitle('☁️ Storage & Cloud'),
                SwitchListTile(
                  value: autoBackup,
                  onChanged: (v) => setState(() => autoBackup = v),
                  title: const Text('Auto Backup to Cloud', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Automatically save rendered videos to Firebase', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  activeColor: Colors.purpleAccent,
                ),

                _sectionTitle('🔔 Notifications & Privacy'),
                SwitchListTile(
                  value: renderAlerts,
                  onChanged: (v) => setState(() => renderAlerts = v),
                  title: const Text('Render Completion Alerts', style: TextStyle(color: Colors.white)),
                  activeColor: Colors.purpleAccent,
                ),

                const SizedBox(height: 8),

                _sectionTitle('🌓 Theme Mode'),
                SwitchListTile(
                  value: isDarkMode,
                  onChanged: (v) => setState(() => isDarkMode = v),
                  title: Text(isDarkMode ? 'Dark Mode' : 'Light Mode', style: const TextStyle(color: Colors.white)),
                  activeColor: Colors.purpleAccent,
                ),

                const SizedBox(height: 8),

                _sectionTitle('ℹ️ About & Support'),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(10)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                    Text('Version: 1.0.0', style: TextStyle(color: Colors.white)),
                    SizedBox(height: 4),
                    Text('Support: support@visora.ai', style: TextStyle(color: Colors.white54)),
                    SizedBox(height: 4),
                    Text('© 2025 Visora AI Studio', style: TextStyle(color: Colors.white54)),
                  ]),
                ),

                const SizedBox(height: 16),

                Center(
                  child: ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                    label: const Text('Logout'),
                  ),
                ),

                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _savePrefs,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Preferences'),
                  ),
                ),
              ]),
            ),
    );
  }
}
