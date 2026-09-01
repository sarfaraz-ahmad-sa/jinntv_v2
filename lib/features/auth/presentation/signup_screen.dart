import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/services/user_library_service.dart';
import '../../../Screens/app_shell.dart';

class CineSignupScreen extends StatefulWidget {
  const CineSignupScreen({super.key});

  @override
  State<CineSignupScreen> createState() => _CineSignupScreenState();
}

class _CineSignupScreenState extends State<CineSignupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final result = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      await result.user?.updateDisplayName(_name.text.trim());
      await result.user?.reload();
      await UserLibraryService.instance.saveProfileIfNeeded();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AppShell()), (_) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Could not create account.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF08090C),
        appBar: AppBar(title: const Text('Create CineNexa account')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Form(
                key: _form,
                child: Column(
                  children: [
                    TextFormField(controller: _name, style: const TextStyle(color: Colors.white), decoration: _dec('Your name', Icons.person_outline_rounded), validator: (v) => (v ?? '').trim().length >= 2 ? null : 'Enter your name'),
                    const SizedBox(height: 12),
                    TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, style: const TextStyle(color: Colors.white), decoration: _dec('Email address', Icons.mail_outline_rounded), validator: (v) => (v ?? '').contains('@') ? null : 'Enter a valid email'),
                    const SizedBox(height: 12),
                    TextFormField(controller: _password, obscureText: true, style: const TextStyle(color: Colors.white), decoration: _dec('Password', Icons.lock_outline_rounded), validator: (v) => (v ?? '').length >= 6 ? null : 'Minimum 6 characters'),
                    const SizedBox(height: 22),
                    SizedBox(width: double.infinity, child: FilledButton(onPressed: _busy ? null : _create, child: Text(_busy ? 'Creating...' : 'Create account'))),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  InputDecoration _dec(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFF151922),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      );
}
