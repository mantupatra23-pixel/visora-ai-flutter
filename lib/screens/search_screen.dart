// lib/screens/search_screen.dart
// Visora Search Screen (Backend Connected + Filters + Tabs)
// Requires: http, lottie, google_fonts packages

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';

/// 🔗 Your live backend base URL:
const String backendBase = 'https://visora-ai-5nqs.onrender.com';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TextEditingController queryCtrl = TextEditingController();

  bool loading = false;
  bool error = false;
  String errorMsg = '';

  List<dynamic> results = [];

  String selectedLang = 'All';
  String selectedQuality = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  Future<void> _performSearch() async {
    final query = queryCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() {
      loading = true;
      error = false;
      results = [];
    });

    final tab = _tabController.index;
    String endpoint = '';
    if (tab == 0) endpoint = '/search/templates?q=$query';
    if (tab == 1) endpoint = '/search/voices?q=$query';
    if (tab == 2) endpoint = '/search/videos?q=$query';
    if (tab == 3) endpoint = '/user/projects?q=$query';

    final url = '$backendBase$endpoint';

    try {
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final List<dynamic> data = jsonDecode(resp.body);
        setState(() {
          results = data;
        });
      } else {
        setState(() {
          error = true;
          errorMsg = 'Server returned ${resp.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        error = true;
        errorMsg = 'Server not reachable';
      });
    } finally {
      setState(() => loading = false);
    }
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          return SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Filter Results', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Language:', style: TextStyle(fontWeight: FontWeight.w500)),
                      DropdownButton<String>(
                        value: selectedLang,
                        items: ['All', 'Hindi', 'English', 'Tamil', 'Telugu', 'Bengali']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (val) {
                          setModalState(() => selectedLang = val ?? 'All');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Quality:', style: TextStyle(fontWeight: FontWeight.w500)),
                      DropdownButton<String>(
                        value: selectedQuality,
                        items: ['All', '720p', '1080p', '4K']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (val) {
                          setModalState(() => selectedQuality = val ?? 'All');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _performSearch();
                    },
                    icon: const Icon(Icons.filter_alt),
                    label: const Text('Apply Filters'),
                  )
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildResultCard(dynamic item) {
    final thumb = item['thumbnail'] ?? item['preview'] ?? '';
    final title = item['title'] ?? item['name'] ?? 'Untitled';
    final desc = item['description'] ?? '';
    return Card(
      color: Colors.grey[900],
      child: ListTile(
        leading: thumb != ''
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(thumb, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image)))
            : const Icon(Icons.image, size: 40, color: Colors.white54),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Opening "$title"')));
        },
      ),
    );
  }

  Widget _buildResults() {
    if (loading) {
      return Center(child: Lottie.asset('assets/lottie/loading.json', width: 100));
    }
    if (error) {
      return Center(child: Text(errorMsg, style: const TextStyle(color: Colors.redAccent)));
    }
    if (results.isEmpty) {
      return const Center(child: Text('No results found', style: TextStyle(color: Colors.white54)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: results.length,
      itemBuilder: (context, i) => _buildResultCard(results[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B10),
      appBar: AppBar(
        title: Text('Search', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(onPressed: _openFilterSheet, icon: const Icon(Icons.filter_alt_outlined)),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.purpleAccent,
          tabs: const [
            Tab(text: 'Templates'),
            Tab(text: 'Voices'),
            Tab(text: 'Videos'),
            Tab(text: 'My Projects'),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.white70),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: queryCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration.collapsed(
                      hintText: 'Search templates, voices, or videos...',
                      hintStyle: TextStyle(color: Colors.white54),
                    ),
                    onSubmitted: (_) => _performSearch(),
                  ),
                ),
                IconButton(
                  onPressed: _performSearch,
                  icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 18),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildResults(),
                _buildResults(),
                _buildResults(),
                _buildResults(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
