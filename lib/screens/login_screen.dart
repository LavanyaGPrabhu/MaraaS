import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  bool _signupMode = false;

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      if (_signupMode) {
        await _auth.signUp(_email.text.trim(), _pass.text.trim());
      } else {
        await _auth.signIn(_email.text.trim(), _pass.text.trim());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('MaraaS', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),
                TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 8),
                TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading ? const CircularProgressIndicator() : Text(_signupMode ? 'Sign Up' : 'Sign In'),
                ),
                TextButton(
                  onPressed: () => setState(() => _signupMode = !_signupMode),
                  child: Text(_signupMode ? 'Have an account? Sign in' : 'New here? Create account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
