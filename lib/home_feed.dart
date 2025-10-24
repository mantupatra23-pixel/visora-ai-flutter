// lib/home_feed.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({Key? key}) : super(key: key);

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  final DatabaseReference _trendingRef = FirebaseDatabase.instance.ref('videos/trending');
  List<VideoItem> _videos = [];
  bool _loading = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _listenTrending();
  }

  void _listenTrending() {
    // realtime listener
    _trendingRef.onValue.listen((event) {
      final map = event.snapshot.value;
      final List<VideoItem> list = [];
      if (map is Map) {
        for (final entry in map.entries) {
          final data = Map<String, dynamic>.from(entry.value as Map);
          list.add(VideoItem.fromMap(entry.key.toString(), data));
        }
      }
      // sort by views/likes (descending) - optional
      list.sort((a, b) => (b.views ?? 0).compareTo(a.views ?? 0));
      setState(() {
        _videos = list;
        _loading = false;
      });
    }, onError: (e) {
      setState(() => _loading = false);
    });
  }

  Future<void> _refresh() async {
    setState(() { _refreshing = true; });
    final snapshot = await _trendingRef.get();
    final map = snapshot.value;
    final List<VideoItem> list = [];
    if (map is Map) {
      for (final entry in map.entries) {
        final data = Map<String, dynamic>.from(entry.value as Map);
        list.add(VideoItem.fromMap(entry.key.toString(), data));
      }
    }
    list.sort((a, b) => (b.views ?? 0).compareTo(a.views ?? 0));
    setState(() {
      _videos = list;
      _refreshing = false;
    });
  }

  void _openVideo(VideoItem item) async {
    // open link in external app/browser
    final url = item.url;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video URL missing')));
      return;
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open video URL')));
    }
  }

  Widget _buildCard(VideoItem item) {
    return GestureDetector(
      onTap: () => _openVideo(item),
      child: Card(
        color: Colors.white10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: (item.thumbnail != null && item.thumbnail!.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: item.thumbnail!,
                        fit: BoxFit.cover,
                        placeholder: (ctx, url) => Container(color: Colors.white12),
                        errorWidget: (ctx, url, err) => Container(color: Colors.white12, child: const Icon(Icons.broken_image)),
                      )
                    : Container(
                        color: Colors.white10,
                        child: const Center(child: Icon(Icons.videocam, size: 48, color: Colors.white24)),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Text(item.title ?? 'Untitled', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.favorite, color: Colors.redAccent, size: 16),
                  const SizedBox(width: 6),
                  Text('${item.likes ?? 0}', style: const TextStyle(color: Colors.white70)),
                  const Spacer(),
                  const Icon(Icons.remove_red_eye, color: Colors.white38, size: 16),
                  const SizedBox(width: 6),
                  Text('${item.views ?? 0}', style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar can be customized to your design
      appBar: AppBar(
        backgroundColor: Colors.deepPurpleAccent,
        title: const Text('🔥 Trending'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _videos.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Text('No trending videos yet', style: TextStyle(color: Colors.white70))),
                    ],
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: _videos.length,
                    itemBuilder: (context, idx) => _buildCard(_videos[idx]),
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // navigate to Create (Ultra Panel) screen
          Navigator.of(context).pushNamed('/create');
        },
        icon: const Icon(Icons.add),
        label: const Text('Create'),
        backgroundColor: Colors.purpleAccent,
      ),
    );
  }
}

class VideoItem {
  final String id;
  final String? title;
  final String? url;
  final String? thumbnail;
  final int? likes;
  final int? views;

  VideoItem({required this.id, this.title, this.url, this.thumbnail, this.likes, this.views});

  factory VideoItem.fromMap(String id, Map<String, dynamic> m) {
    return VideoItem(
      id: id,
      title: m['title']?.toString(),
      url: m['url']?.toString(),
      thumbnail: m['thumbnail']?.toString(),
      likes: (m['likes'] is int) ? m['likes'] as int : (int.tryParse((m['likes'] ?? '0').toString()) ?? 0),
      views: (m['views'] is int) ? m['views'] as int : (int.tryParse((m['views'] ?? '0').toString()) ?? 0),
    );
  }
}
