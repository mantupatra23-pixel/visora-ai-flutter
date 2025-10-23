import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pwd = TextEditingController();
  bool _loading = false;
  String? _error;

  void _doLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await ApiService.login(_email.text.trim(), _pwd.text.trim());
      Navigator.pushReplacementNamed(context, '/home', arguments: token);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pwd.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Visora – Ultimate AI Studio',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                TextField(controller: _email, decoration: const InputDecoration(hintText: 'Email')),
                const SizedBox(height: 12),
                TextField(controller: _pwd, decoration: const InputDecoration(hintText: 'Password'), obscureText: true),
                const SizedBox(height: 20),
                if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loading ? null : _doLogin,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
                      backgroundColor: Colors.purpleAccent),
                  child: _loading ? const CircularProgressIndicator() : const Text('Login'),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
