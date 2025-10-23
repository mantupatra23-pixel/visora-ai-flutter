import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const VisoraAIApp());
}

class VisoraAIApp extends StatelessWidget {
  const VisoraAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Visora AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.purpleAccent,
          secondary: Colors.deepPurpleAccent,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
