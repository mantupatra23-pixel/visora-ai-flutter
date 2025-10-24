// lib/main.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Import your screens (adjust paths if you have them in subfolders)
import 'dashboard_screen.dart';
import 'screens/search_screen.dart';
import 'screens/create_video_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/profile_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VisoraApp());
}

class VisoraApp extends StatelessWidget {
  const VisoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Visora AI Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.purple,
        scaffoldBackgroundColor: const Color(0xFF0A0A0D),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
        ),
      ),
      home: const MainShell(),
      routes: {
        '/dashboard': (_) => const DashboardScreen(),
        '/search': (_) => const SearchScreen(),
        '/create': (_) => const CreateVideoScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/profile': (_) => const ProfileScreen(),
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // Keep page widgets so state persists while switching tabs
  final List<Widget> _pages = const [
    DashboardScreen(),
    SearchScreen(),
    SizedBox(), // placeholder for center FAB (Create)
    SettingsScreen(),
    ProfileScreen(),
  ];

  // To handle back button behaviour (exit from main)
  DateTime? _lastBackPressed;

  void _onTapNav(int idx) {
    if (idx == 2) {
      // Center button — open Create menu directly
      _openCreate();
      return;
    }
    setState(() => _currentIndex = idx);
  }

  void _openCreate() {
    // Use Modal Bottom Sheet to choose Script / Image OR open create screen directly
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B0B10),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.edit_note, color: Colors.white),
                title: const Text('Create a Video (Script → Video)', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateVideoScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.image, color: Colors.white),
                title: const Text('Image to Video', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateVideoScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.close, color: Colors.white54),
                title: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }

  // Build bottom navigation with center FAB integrated
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      color: const Color(0xFF09090B),
      child: Row(
        children: [
          _navItem(icon: Icons.home, label: 'Dashboard', index: 0),
          _navItem(icon: Icons.search, label: 'Search', index: 1),
          Expanded(
            child: Center(
              child: FloatingActionButton(
                onPressed: _openCreate,
                backgroundColor: Colors.pinkAccent,
                child: const Icon(Icons.add, size: 28),
              ),
            ),
          ),
          _navItem(icon: Icons.settings, label: 'Settings', index: 3),
          _navItem(icon: Icons.person, label: 'Profile', index: 4),
        ],
      ),
    );
  }

  Widget _navItem({required IconData icon, required String label, required int index}) {
    final bool active = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => _onTapNav(index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? Colors.purpleAccent : Colors.white70),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: active ? Colors.purpleAccent : Colors.white54, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // Back press: require double-tap to exit
  Future<bool> _onWillPop() async {
    if (_lastBackPressed == null || DateTime.now().difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = DateTime.now();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Press back again to exit')));
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // current content: if index==2 show dashboard (or keep previous) — keep it simple: map index to pages array
    Widget body;
    if (_currentIndex == 2) {
      // show create screen directly as sheet when user pressed center button
      body = _pages[0]; // keep showing dashboard by default
    } else {
      body = _pages[_currentIndex == 2 ? 0 : _currentIndex];
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: SafeArea(child: body),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }
}
