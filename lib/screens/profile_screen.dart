// lib/screens/profile_screen.dart
// VISORA AI STUDIO – PROFILE SCREEN
// Backend connected + monthly stats + uploads + credits + share + editable profile
//
// Required packages: http, google_fonts, lottie, share_plus, cached_network_image

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';

const String backendBase = 'https://visora-ai-5nqs.onrender.com';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool loading = true;
  Map<String, dynamic>? profile;
  Map<String, dynamic>? stats;
  Map<String, dynamic>? credits;
  List<dynamic> uploads = [];
  List<dynamic> activities = [];

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('$backendBase/user/profile')),
        http.get(Uri.parse('$backendBase/user/stats')),
        http.get(Uri.parse('$backendBase/user/credits')),
        http.get(Uri.parse('$backendBase/user/uploads')),
        http.get(Uri.parse('$backendBase/user/activity')),
      ]);

      setState(() {
        profile = _safeDecode(responses[0]);
        stats = _safeDecode(responses[1]);
        credits = _safeDecode(responses[2]);
        uploads = _safeListDecode(responses[3]);
        activities = _safeListDecode(responses[4]);
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching data: $e')),
      );
    }
  }

  Map<String, dynamic>? _safeDecode(http.Response res) {
    try {
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return {};
  }

  List<dynamic> _safeListDecode(http.Response res) {
    try {
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return [];
  }

  void _shareApp() {
    const link = 'https://play.google.com/store/apps/details?id=com.visora.ai';
    Share.share('🎬 Try Visora AI Studio — the ultimate AI video maker!\n$link');
  }

  Future<void> _editProfile() async {
    final nameCtrl = TextEditingController(text: profile?['name'] ?? '');
    final countryCtrl = TextEditingController(text: profile?['country'] ?? '');

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name', labelStyle: TextStyle(color: Colors.white)),
              style: const TextStyle(color: Colors.white),
            ),
            TextField(
              controller: countryCtrl,
              decoration: const InputDecoration(labelText: 'Country', labelStyle: TextStyle(color: Colors.white)),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              final body = {
                "name": nameCtrl.text.trim(),
                "country": countryCtrl.text.trim(),
              };
              await http.post(Uri.parse('$backendBase/user/profile/edit'),
                  body: jsonEncode(body), headers: {'Content-Type': 'application/json'});
              if (mounted) {
                Navigator.pop(context);
                _fetchAllData();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
            child: const Text('Save'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0D),
        body: Center(child: Lottie.asset('assets/lottie/loading.json', width: 100)),
      );
    }

    final user = profile ?? {};
    final used = stats?['used'] ?? 0;
    final limit = stats?['limit'] ?? 100;
    final remaining = stats?['remaining'] ?? (limit - used);
    final progress = limit == 0 ? 0.0 : used / limit;
    final creditCount = credits?['credits'] ?? 0;
    final revenue = credits?['revenue'] ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0D),
      appBar: AppBar(
        title: Text('Profile', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.black,
        actions: [
          IconButton(onPressed: _editProfile, icon: const Icon(Icons.edit)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Profile Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: CachedNetworkImageProvider(
                    user['photo'] ??
                        'https://cdn-icons-png.flaticon.com/512/1077/1077012.png',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user['name'] ?? 'User',
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                    Text(user['plan'] ?? 'Free Plan', style: const TextStyle(color: Colors.white70)),
                    Text(user['country'] ?? 'Unknown', style: const TextStyle(color: Colors.white54)),
                  ]),
                )
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Monthly Stats
          Text('🎬 Monthly Usage', style: GoogleFonts.poppins(color: Colors.purpleAccent, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Used: $used / $limit videos', style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: progress, color: Colors.purpleAccent, backgroundColor: Colors.white12),
                const SizedBox(height: 4),
                Text('Remaining: $remaining', style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Credits and Revenue
          Text('💰 Credits & Earnings', style: GoogleFonts.poppins(color: Colors.purpleAccent, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Credits: $creditCount', style: const TextStyle(color: Colors.white)),
                  Text('Revenue: ₹$revenue', style: const TextStyle(color: Colors.white70)),
                ]),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                  child: const Text('Upgrade'),
                )
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Uploads
          Text('📦 Recent Uploads', style: GoogleFonts.poppins(color: Colors.purpleAccent, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          SizedBox(
            height: 140,
            child: uploads.isEmpty
                ? const Center(child: Text('No uploads yet', style: TextStyle(color: Colors.white54)))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: uploads.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final u = uploads[i];
                      return InkWell(
                        onTap: () => ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('Playing ${u['title']}...'))),
                        child: Container(
                          width: 160,
                          decoration: BoxDecoration(color: Colors.grey[850], borderRadius: BorderRadius.circular(10)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
                                child: CachedNetworkImage(
                                  imageUrl: u['thumbnail'] ?? '',
                                  height: 90,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported, color: Colors.white54),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(u['title'] ?? 'Untitled',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          const SizedBox(height: 20),

          // Share App
          Text('📤 Share Visora App', style: GoogleFonts.poppins(color: Colors.purpleAccent, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Expanded(
                child: Text(
                  'Invite friends to use Visora AI and earn bonus credits!',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _shareApp,
                icon: const Icon(Icons.share),
                label: const Text('Share'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
              )
            ]),
          ),

          const SizedBox(height: 20),

          // Activity feed
          Text('🔔 Recent Activity', style: GoogleFonts.poppins(color: Colors.purpleAccent, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          activities.isEmpty
              ? const Text('No recent activity', style: TextStyle(color: Colors.white54))
              : Column(
                  children: activities.map((a) {
                    return ListTile(
                      title: Text(a['message'] ?? '', style: const TextStyle(color: Colors.white)),
                      subtitle: Text(a['time'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    );
                  }).toList(),
                ),

          const SizedBox(height: 50),
        ]),
      ),
    );
  }
}
