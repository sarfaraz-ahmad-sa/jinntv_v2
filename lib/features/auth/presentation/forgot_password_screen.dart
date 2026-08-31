import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CineForgotPasswordScreen extends StatefulWidget {
  const CineForgotPasswordScreen({super.key});

  @override
  State<CineForgotPasswordScreen> createState() => _CineForgotPasswordScreenState();
}

class _CineForgotPasswordScreenState extends State<CineForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (!email.contains('@') || _busy) return;
    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent.')));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Could not send reset email.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF08090C),
        appBar: AppBar(title: const Text('Reset password')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Enter your Firebase account email and we will send a secure reset link.', style: TextStyle(color: Colors.white70, height: 1.5)),
                  const SizedBox(height: 18),
                  TextField(controller: _email, keyboardType: TextInputType.emailAddress, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Email address', filled: true, fillColor: const Color(0xFF151922), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _busy ? null : _send, child: Text(_busy ? 'Sending...' : 'Send reset link')),
                ],
              ),
            ),
          ),
        ),
      );
}
