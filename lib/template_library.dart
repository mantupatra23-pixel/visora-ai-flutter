// lib/template_library.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class TemplateLibraryScreen extends StatefulWidget {
  const TemplateLibraryScreen({Key? key}) : super(key: key);

  @override
  State<TemplateLibraryScreen> createState() => _TemplateLibraryScreenState();
}

class _TemplateLibraryScreenState extends State<TemplateLibraryScreen> {
  final DatabaseReference _templatesRef = FirebaseDatabase.instance.ref('templates');
  Map<String, List<TemplateItem>> _categories = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
    _templatesRef.onValue.listen((event) {
      _loadTemplatesFromSnapshot(event.snapshot);
    });
  }

  void _loadTemplates() async {
    final snap = await _templatesRef.get();
    _loadTemplatesFromSnapshot(snap);
  }

  void _loadTemplatesFromSnapshot(DataSnapshot snapshot) {
    final map = snapshot.value;
    final Map<String, List<TemplateItem>> temp = {};
    if (map is Map) {
      for (final catEntry in map.entries) {
        final catKey = catEntry.key.toString();
        final items = <TemplateItem>[];
        if (catEntry.value is Map) {
          final entries = Map<String, dynamic>.from(catEntry.value as Map);
          for (final e in entries.entries) {
            final t = TemplateItem.fromMap(e.key.toString(), Map<String, dynamic>.from(e.value as Map));
            items.add(t);
          }
        }
        temp[catKey] = items;
      }
    }
    setState(() {
      _categories = temp;
      _loading = false;
    });
  }

  void _useTemplate(TemplateItem t) {
    // navigate to create screen and pass template data (script etc.)
    Navigator.of(context).pushNamed('/create', arguments: {
      'template_id': t.id,
      'script': t.script,
      'title': t.title,
    });
  }

  Widget _buildCategory(String cat, List<TemplateItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text(cat, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, idx) {
              final tpl = items[idx];
              return GestureDetector(
                onTap: () => _useTemplate(tpl),
                child: Container(
                  width: 140,
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                        child: tpl.thumbnail != null && tpl.thumbnail!.isNotEmpty
                            ? CachedNetworkImage(imageUrl: tpl.thumbnail!, height: 100, width: 140, fit: BoxFit.cover)
                            : Container(height: 100, color: Colors.white12, child: const Icon(Icons.image, size: 36)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(tpl.title ?? 'Template', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
                      ),
                      ElevatedButton(onPressed: () => _useTemplate(tpl), child: const Text('Use')),
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemCount: items.length,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = _categories.keys.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Templates'), backgroundColor: Colors.deepPurpleAccent),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, idx) {
                final key = categories[idx];
                final items = _categories[key] ?? [];
                if (items.isEmpty) return const SizedBox.shrink();
                return _buildCategory(key, items);
              },
            ),
    );
  }
}

class TemplateItem {
  final String id;
  final String? title;
  final String? script;
  final String? thumbnail;

  TemplateItem({required this.id, this.title, this.script, this.thumbnail});

  factory TemplateItem.fromMap(String id, Map<String, dynamic> m) {
    return TemplateItem(
      id: id,
      title: m['title']?.toString(),
      script: m['script']?.toString(),
      thumbnail: m['thumbnail']?.toString(),
    );
  }
}
