import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/user_library_service.dart';
import '../../../Screens/app_shell.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';

class CineLoginScreen extends StatefulWidget {
  const CineLoginScreen({super.key});

  @override
  State<CineLoginScreen> createState() => _CineLoginScreenState();
}

class _CineLoginScreenState extends State<CineLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _finishLogin() async {
    // Authentication success should never be blocked by Firestore/profile sync.
    // Navigate immediately, then sync the profile in the background.
    unawaited(
      UserLibraryService.instance
          .saveProfileIfNeeded()
          .timeout(const Duration(seconds: 5))
          .catchError((_) {}),
    );
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppShell()),
      (_) => false,
    );
  }

  Future<void> _login() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _email.text.trim(),
            password: _password.text,
          )
          .timeout(const Duration(seconds: 20));
      await _finishLogin();
    } on FirebaseAuthException catch (e) {
      _message('Login failed [${e.code}]: ${e.message ?? 'Firebase authentication error'}');
    } catch (e) {
      _message('Login failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      debugPrint('[CineNexa Auth] Starting Google Sign-In');
      final account = await GoogleSignIn().signIn().timeout(const Duration(seconds: 30));
      if (account == null) {
        debugPrint('[CineNexa Auth] Google Sign-In cancelled');
        return;
      }
      debugPrint('[CineNexa Auth] Google account selected: ${account.email}');
      final auth = await account.authentication.timeout(const Duration(seconds: 20));
      debugPrint('[CineNexa Auth] Google tokens received: idToken=${auth.idToken != null}, accessToken=${auth.accessToken != null}');
      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      debugPrint('[CineNexa Auth] Signing Google credential into Firebase');
      await FirebaseAuth.instance
          .signInWithCredential(credential)
          .timeout(const Duration(seconds: 20));
      debugPrint('[CineNexa Auth] Firebase Google sign-in successful');
      await _finishLogin();
    } on TimeoutException catch (e) {
      debugPrint('[CineNexa Auth] Google sign-in timeout: $e');
      _message('Google sign-in timed out. Please try again.');
    } on FirebaseAuthException catch (e) {
      debugPrint('[CineNexa Auth] Firebase Google error [${e.code}]: ${e.message}');
      _message('Google sign-in failed [${e.code}]: ${e.message ?? 'Firebase authentication error'}');
    } on PlatformException catch (e) {
      debugPrint('[CineNexa Auth] Google platform error [${e.code}]: ${e.message} ${e.details ?? ''}');
      _message('Google sign-in setup error [${e.code}]: ${e.message ?? 'Check OAuth / macOS configuration'}');
    } catch (e) {
      _message('Google sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apple() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      );
      final credential = OAuthProvider('apple.com').credential(
        idToken: apple.identityToken,
        accessToken: apple.authorizationCode,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      await _finishLogin();
    } on FirebaseAuthException catch (e) {
      _message(e.message ?? 'Apple sign-in failed.');
    } catch (_) {
      _message('Apple sign-in is not available right now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF08090C);
    const accent = Color(0xFFE50914);
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.movie_filter_rounded, size: 54, color: accent),
                    const SizedBox(height: 14),
                    const Text(
                      AppConfig.appName,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -.8),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      AppConfig.appTagline,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54),
                    ),
                    const SizedBox(height: 34),
                    _field(
                      controller: _email,
                      hint: 'Email address',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => (v ?? '').contains('@') ? null : 'Enter a valid email',
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _password,
                      hint: 'Password',
                      icon: Icons.lock_outline_rounded,
                      obscureText: _obscure,
                      validator: (v) => (v ?? '').length >= 6 ? null : 'Minimum 6 characters',
                      suffix: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.white54),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CineForgotPasswordScreen())),
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: accent, padding: const EdgeInsets.symmetric(vertical: 15)),
                      onPressed: _busy ? null : _login,
                      child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Sign in'),
                    ),
                    const SizedBox(height: 18),
                    const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: TextStyle(color: Colors.white38))), Expanded(child: Divider())]),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(onPressed: _busy ? null : _google, icon: const Icon(Icons.g_mobiledata_rounded, size: 28), label: const Text('Continue with Google')),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(onPressed: _busy ? null : _apple, icon: const Icon(Icons.apple_rounded), label: const Text('Continue with Apple')),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('New to CineNexa?', style: TextStyle(color: Colors.white54)),
                        TextButton(onPressed: _busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CineSignupScreen())), child: const Text('Create account')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Authentication is handled by Firebase. No legacy PHP login API is used.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white30, fontSize: 10.5)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.white54),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFF151922),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }
}
