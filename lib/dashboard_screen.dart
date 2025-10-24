// lib/dashboard_screen.dart
// Visora Dashboard Screen (single-file, backend-connected)
// Requires packages: http, video_player, lottie, google_fonts

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// >>> CHANGE THIS TO YOUR LIVE BACKEND BASE URL <<<
const String backendBase = 'https://visora-ai-5nqs.onrender.com';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Data lists fetched from backend
  List<dynamic> trending = [];
  List<dynamic> recentProjects = [];
  List<dynamic> templates = [];
  List<dynamic> voices = [];

  // UI states
  bool loadingTrending = true;
  bool loadingRecent = true;
  bool loadingTemplates = true;
  bool loadingVoices = true;
  String errorMsg = '';

  // Video player for top trending area
  VideoPlayerController? _topVideoController;
  int _currentTrendingIndex = 0;

  // Periodic refresh timer
  Timer? _refreshTimer;

  // For demo (no auth yet) — use a test user id. Replace with real user id after auth.
  final String userId = 'test_user_001';

  // WebSocket - placeholder if you want live job push
  WebSocketChannel? _wsChannel;

  @override
  void initState() {
    super.initState();
    _initAll();
    // auto refresh every 15 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _initAll());
  }

  Future<void> _initAll() async {
    await Future.wait([
      fetchTrendingVideos(),
      fetchRecentProjects(),
      fetchTemplates(),
      fetchUserVoices(),
    ]);
  }

  // ---------------- BACKEND API CALLS ----------------

  Future<void> fetchTrendingVideos() async {
    setState(() => loadingTrending = true);
    try {
      final resp = await http.get(Uri.parse('$backendBase/trending_videos')).timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) {
        final List<dynamic> list = jsonDecode(resp.body) as List<dynamic>;
        setState(() => trending = list);
        // setup top video controller for first item if exists
        if (trending.isNotEmpty) _playTopTrendingAt(0);
      } else {
        setState(() {
          errorMsg = 'Trending fetch failed (${resp.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        errorMsg = 'Server unreachable for trending';
      });
    } finally {
      setState(() => loadingTrending = false);
    }
  }

  Future<void> fetchRecentProjects() async {
    setState(() => loadingRecent = true);
    try {
      final resp = await http.get(Uri.parse('$backendBase/user/projects?user_id=$userId')).timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) {
        final List<dynamic> list = jsonDecode(resp.body) as List<dynamic>;
        setState(() => recentProjects = list);
      } else {
        setState(() {
          errorMsg = 'Recent projects fetch failed (${resp.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        errorMsg = 'Server unreachable for recent projects';
      });
    } finally {
      setState(() => loadingRecent = false);
    }
  }

  Future<void> fetchTemplates() async {
    setState(() => loadingTemplates = true);
    try {
      final resp = await http.get(Uri.parse('$backendBase/templates')).timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) {
        final List<dynamic> list = jsonDecode(resp.body) as List<dynamic>;
        setState(() => templates = list);
      } else {
        setState(() {
          errorMsg = 'Templates fetch failed (${resp.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        errorMsg = 'Server unreachable for templates';
      });
    } finally {
      setState(() => loadingTemplates = false);
    }
  }

  Future<void> fetchUserVoices() async {
    setState(() => loadingVoices = true);
    try {
      final resp = await http.get(Uri.parse('$backendBase/user/voices?user_id=$userId')).timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) {
        final List<dynamic> list = jsonDecode(resp.body) as List<dynamic>;
        setState(() => voices = list);
      } else {
        setState(() {
          errorMsg = 'Voices fetch failed (${resp.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        errorMsg = 'Server unreachable for voices';
      });
    } finally {
      setState(() => loadingVoices = false);
    }
  }

  // ---------------- VIDEO PLAYER HELPERS ----------------

  Future<void> _playTopTrendingAt(int index) async {
    if (trending.isEmpty) return;
    if (index < 0 || index >= trending.length) return;

    final videoUrl = trending[index]['video_url']?.toString() ?? '';
    if (videoUrl.isEmpty) return;

    try {
      // dispose old
      await _topVideoController?.pause();
      await _topVideoController?.dispose();
    } catch (_) {}

    _topVideoController = VideoPlayerController.network(videoUrl);
    await _topVideoController!.initialize();
    _topVideoController!.setLooping(true);
    _topVideoController!.setVolume(0.0); // mute autoplay
    await _topVideoController!.play();
    setState(() => _currentTrendingIndex = index);
  }

  // tap on trending to open fullscreen player
  void _openFullScreenVideo(String url, String title) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => FullscreenVideoPage(url: url, title: title)));
  }

  // ---------------- UI ACTIONS ----------------

  void _openCreateMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.edit_note),
                title: const Text('Create a Video (Script → Video)'),
                onTap: () {
                  Navigator.pop(ctx);
                  // open create script screen (placeholder)
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateVideoPlaceholder()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Image to Video'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ImageToVideoPlaceholder()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.mic),
                title: const Text('Voice Clone / Manage Voices'),
                onTap: () {
                  Navigator.pop(ctx);
                  // go to voices
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const VoicesPlaceholder()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }

  // quick action: download project
  Future<void> _downloadProject(String downloadUrl) async {
    // For simplicity: open in browser or show toast. Implement actual download logic as needed.
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download started (open link)')));
    // Use url_launcher in real app to open the link
  }

  // ---------------- LIFECYCLE ----------------

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _topVideoController?.dispose();
    _wsChannel?.sink.close();
    super.dispose();
  }

  // ---------------- BUILD UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B10),
      body: SafeArea(
        child: Column(
          children: [
            // TOP: trending video area
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                color: Colors.black,
                child: loadingTrending
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Lottie.asset('assets/lottie/loading.json', width: 90, height: 90),
                            const SizedBox(height: 10),
                            const Text('Loading trending...', style: TextStyle(color: Colors.white70)),
                          ],
                        ),
                      )
                    : trending.isEmpty
                        ? Center(child: Text('No trending videos', style: Theme.of(context).textTheme.bodyLarge))
                        : GestureDetector(
                            onTap: () {
                              final url = trending[_currentTrendingIndex]['video_url']?.toString() ?? '';
                              final title = trending[_currentTrendingIndex]['title']?.toString() ?? 'Video';
                              if (url.isNotEmpty) _openFullScreenVideo(url, title);
                            },
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // video player if ready
                                if (_topVideoController != null && _topVideoController!.value.isInitialized)
                                  FittedBox(
                                    fit: BoxFit.cover,
                                    child: SizedBox(
                                      width: _topVideoController!.value.size.width,
                                      height: _topVideoController!.value.size.height,
                                      child: VideoPlayer(_topVideoController!),
                                    ),
                                  )
                                else
                                  // fallback to thumbnail
                                  Image.network(
                                    trending[_currentTrendingIndex]['thumbnail'] ?? '',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(color: Colors.grey[900]),
                                  ),
                                // overlay
                                Positioned(
                                  left: 12,
                                  top: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                                    child: Text(
                                      trending[_currentTrendingIndex]['title']?.toString() ?? '',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 12,
                                  left: 12,
                                  child: Row(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          // use this template / style
                                          final template = trending[_currentTrendingIndex];
                                          // For now: opens create page prefilled (not implemented)
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Use this template')));
                                        },
                                        icon: const Icon(Icons.playlist_add),
                                        label: const Text('Use this style'),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          // like/save
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to favorites')));
                                        },
                                        icon: const Icon(Icons.favorite_border),
                                        label: const Text('Save'),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.black54),
                                      ),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
              ),
            ),

            // MIDDLE: quick stats / buttons / lists
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF0C0C14),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick stats row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _smallStatCard('Renders', '${recentProjects.length}'),
                          _smallStatCard('Credits', '45'),
                          _smallStatCard('Plan', 'Pro'),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // AI suggestion
                      Card(
                        color: Colors.grey[900],
                        child: ListTile(
                          leading: const Icon(Icons.lightbulb, color: Colors.amber),
                          title: const Text('AI Suggestion'),
                          subtitle: const Text('Try: Create a 30s motivational reel'),
                          trailing: ElevatedButton(
                            onPressed: () {
                              // quick create suggestion
                              _openCreateMenu();
                            },
                            child: const Text('Try Now'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Quick create buttons
                      Row(
                        children: [
                          Expanded(
                              child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateVideoPlaceholder()));
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('Create Video'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                          )),
                          const SizedBox(width: 10),
                          Expanded(
                              child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const ImageToVideoPlaceholder()));
                            },
                            icon: const Icon(Icons.image),
                            label: const Text('Image to Video'),
                          )),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Recent projects horizontal
                      Text('Recent Projects', style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 120,
                        child: loadingRecent
                            ? const Center(child: CircularProgressIndicator())
                            : recentProjects.isEmpty
                                ? const Center(child: Text('No recent projects', style: TextStyle(color: Colors.white70)))
                                : ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: recentProjects.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                                    itemBuilder: (context, i) {
                                      final item = recentProjects[i];
                                      return _recentProjectTile(item);
                                    },
                                  ),
                      ),
                      const SizedBox(height: 14),

                      // Voice shortcuts
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Voice Library', style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        TextButton(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const VoicesPlaceholder()));
                            },
                            child: const Text('Manage')),
                      ]),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 82,
                        child: loadingVoices
                            ? const Center(child: CircularProgressIndicator())
                            : voices.isEmpty
                                ? const Center(child: Text('No saved voices', style: TextStyle(color: Colors.white70)))
                                : ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: voices.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                                    itemBuilder: (context, i) {
                                      final v = voices[i];
                                      return _voiceCard(v);
                                    },
                                  ),
                      ),
                      const SizedBox(height: 14),

                      // Templates carousel
                      Text('Templates', style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 110,
                        child: loadingTemplates
                            ? const Center(child: CircularProgressIndicator())
                            : templates.isEmpty
                                ? const Center(child: Text('No templates', style: TextStyle(color: Colors.white70)))
                                : ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: templates.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                                    itemBuilder: (context, i) {
                                      final t = templates[i];
                                      return _templateCard(t);
                                    },
                                  ),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),
            ),

            // BOTTOM NAV BAR
            _buildBottomNavBar(),
          ],
        ),
      ),
    );
  }

  // ---------------- WIDGETS ----------------

  Widget _smallStatCard(String title, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _recentProjectTile(dynamic item) {
    final thumb = item['thumbnail']?.toString() ?? '';
    final status = item['status']?.toString() ?? 'unknown';
    final jobId = item['job_id']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        // open detail or download
        final downloadUrl = item['download_url']?.toString();
        if (downloadUrl != null) _downloadProject(downloadUrl);
      },
      child: Container(
        width: 200,
        decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              child: thumb.isEmpty
                  ? Container(color: Colors.grey[800])
                  : Image.network(thumb, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey[800])),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(children: [
              Expanded(child: Text('Job $jobId', style: const TextStyle(color: Colors.white70, fontSize: 12))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: status == 'completed' ? Colors.green : Colors.orange, borderRadius: BorderRadius.circular(6)),
                child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 12)),
              )
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _voiceCard(dynamic v) {
    final name = v['name']?.toString() ?? 'Voice';
    final lang = v['language']?.toString() ?? '';
    final previewUrl = v['preview_url']?.toString();
    return Container(
      width: 160,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.grey[850], borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(lang, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const Spacer(),
          Row(children: [
            IconButton(
              onPressed: () {
                // play preview (implement using audio player)
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Playing preview (not implemented)')));
              },
              icon: const Icon(Icons.play_circle_outline, color: Colors.white),
            ),
            IconButton(
              onPressed: () {
                // set as default voice
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Set as default (not implemented)')));
              },
              icon: const Icon(Icons.check, color: Colors.white),
            ),
          ])
        ],
      ),
    );
  }

  Widget _templateCard(dynamic t) {
    final thumb = t['preview']?.toString() ?? '';
    final name = t['name']?.toString() ?? 'Template';
    return GestureDetector(
      onTap: () {
        // prefill create screen with this template
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Template selected: $name')));
      },
      child: Container(
        width: 200,
        decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Expanded(child: thumb.isEmpty ? Container(color: Colors.grey[800]) : Image.network(thumb, fit: BoxFit.cover, width: double.infinity)),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(name, style: const TextStyle(color: Colors.white70)),
          ),
        ]),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      color: const Color(0xFF09090B),
      child: Row(
        children: [
          _navButton(icon: Icons.home, label: 'Dashboard', onTap: () {}),
          _navButton(icon: Icons.search, label: 'Search', onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchPlaceholder()));
          }),
          _centerPlusButton(),
          _navButton(icon: Icons.settings, label: 'Settings', onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPlaceholder()));
          }),
          _navButton(icon: Icons.person, label: 'Profile', onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePlaceholder()));
          }),
        ],
      ),
    );
  }

  Widget _navButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white70),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _centerPlusButton() {
    return Expanded(
      child: Center(
        child: FloatingActionButton(
          onPressed: _openCreateMenu,
          backgroundColor: Colors.pinkAccent,
          child: const Icon(Icons.add, size: 28),
        ),
      ),
    );
  }
}

// ---------------- Placeholder screens for navigation targets ----------------

class CreateVideoPlaceholder extends StatelessWidget {
  const CreateVideoPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Video')),
      body: const Center(child: Text('Create Video screen - implement next')),
    );
  }
}

class ImageToVideoPlaceholder extends StatelessWidget {
  const ImageToVideoPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image to Video')),
      body: const Center(child: Text('Image to Video screen - implement next')),
    );
  }
}

class VoicesPlaceholder extends StatelessWidget {
  const VoicesPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voices')),
      body: const Center(child: Text('Voices management - implement next')),
    );
  }
}

class SearchPlaceholder extends StatelessWidget {
  const SearchPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Search')), body: const Center(child: Text('Search screen')));
  }
}

class SettingsPlaceholder extends StatelessWidget {
  const SettingsPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Settings')), body: const Center(child: Text('Settings screen')));
  }
}

class ProfilePlaceholder extends StatelessWidget {
  const ProfilePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Profile')), body: const Center(child: Text('Profile screen')));
  }
}

// Fullscreen video page
class FullscreenVideoPage extends StatefulWidget {
  final String url;
  final String title;
  const FullscreenVideoPage({required this.url, required this.title, super.key});

  @override
  State<FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<FullscreenVideoPage> {
  VideoPlayerController? _controller;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.url)
      ..initialize().then((_) {
        _controller!.play();
        _controller!.setLooping(true);
        setState(() => loading = false);
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: loading
            ? const CircularProgressIndicator()
            : AspectRatio(aspectRatio: _controller!.value.aspectRatio, child: VideoPlayer(_controller!)),
      ),
    );
  }
}
