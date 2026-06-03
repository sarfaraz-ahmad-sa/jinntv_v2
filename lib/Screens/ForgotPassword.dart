import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/jinntv_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailCtrl = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _submitting = false;
  bool _popScheduled = false;

  // yahan apna actual API endpoint lagao
  static const String _forgotPasswordUrl =
      'https://jinntv.com/api_forApp/forgot_password.php';

  @override
  void dispose() {
    FocusManager.instance.primaryFocus?.unfocus();
    _emailCtrl.dispose();
    super.dispose();
  }

  /// PopScope callback must be synchronous; pop is scheduled on next frame after unfocus.
  void _schedulePopToLogin() {
    if (_popScheduled) return;
    _popScheduled = true;
    FocusManager.instance.primaryFocus?.unfocus();
    FocusScope.of(context).unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _popScheduled = false;
        return;
      }
      _popScheduled = false;
      Navigator.of(context).pop();
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;

    FocusScope.of(context).unfocus();

    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final email = _emailCtrl.text.trim();

    setState(() => _submitting = true);

    try {
      final response = await http.post(
        Uri.parse(_forgotPasswordUrl),
        headers: const {
          'Accept': 'application/json',
        },
        body: {
          'email': email,
        },
      );

      dynamic data;
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        data = null;
      }

      if (!mounted) return;

      final message = data is Map && data['message'] != null
          ? data['message'].toString()
          : (response.statusCode == 200
              ? 'If this email exists, a reset link has been sent.'
              : 'Unable to process request right now.');

      final isSuccess = data is Map
          ? (data['status']?.toString().toLowerCase() == 'success')
          : response.statusCode == 200;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              isSuccess ? Colors.green.shade600 : Colors.red.shade600,
        ),
      );

      if (isSuccess) {
        _emailCtrl.clear();
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Server error: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _schedulePopToLogin();
      },
      child: Scaffold(
      backgroundColor: JinnTvTheme.bg,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: JinnTvTheme.backgroundGradient,
              ),
            ),
          ),

          Positioned(
            top: -90,
            left: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: JinnTvTheme.purple.withOpacity(.22),
              ),
            ),
          ),

          Positioned(
            top: 110,
            right: -70,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: JinnTvTheme.pink.withOpacity(.16),
              ),
            ),
          ),

          Positioned(
            bottom: -70,
            left: 30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: JinnTvTheme.blue.withOpacity(.08),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        child: Image.asset(
                          'assets/images/jinn-tv-logo.png',
                          height: 72,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.ondemand_video_rounded,
                              color: Colors.white,
                              size: 64,
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 26),

                      RepaintBoundary(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: JinnTvTheme.card,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(color: JinnTvTheme.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(.24),
                                    blurRadius: 24,
                                    offset: const Offset(0, 14),
                                  ),
                                ],
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Center(
                                      child: Text(
                                        'Forgot Password?',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 12),

                                    const Center(
                                      child: Text(
                                        "Enter your email address and we'll send you a link to reset your password.",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white70,
                                          height: 1.4,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 24),

                                    _label('Email Address'),
                                    const SizedBox(height: 8),

                                    TextFormField(
                                      controller: _emailCtrl,
                                      keyboardType:
                                          TextInputType.emailAddress,
                                      textInputAction: TextInputAction.done,
                                      autocorrect: false,
                                      enableSuggestions: false,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                      onFieldSubmitted: (_) => _submit(),
                                      validator: (value) {
                                        final email =
                                            (value ?? '').trim();

                                        if (email.isEmpty) {
                                          return 'Please enter your email';
                                        }

                                        final emailRegex = RegExp(
                                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                        );

                                        if (!emailRegex.hasMatch(email)) {
                                          return 'Please enter a valid email';
                                        }

                                        return null;
                                      },
                                      decoration: InputDecoration(
                                        hintText: 'Enter your email',
                                        hintStyle: TextStyle(
                                          color: Colors.white.withOpacity(.38),
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.email_outlined,
                                          color: Colors.white54,
                                        ),
                                        filled: true,
                                        fillColor:
                                            Colors.white.withOpacity(.05),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 16,
                                        ),
                                        errorStyle: const TextStyle(
                                          color: Colors.redAccent,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: Colors.white.withOpacity(.08),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: Colors.white.withOpacity(.08),
                                          ),
                                        ),
                                        focusedBorder:
                                            const OutlineInputBorder(
                                          borderRadius: BorderRadius.all(
                                            Radius.circular(16),
                                          ),
                                          borderSide: BorderSide(
                                            color: JinnTvTheme.pink,
                                            width: 1.4,
                                          ),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          borderSide: const BorderSide(
                                            color: Colors.redAccent,
                                            width: 1.2,
                                          ),
                                        ),
                                        focusedErrorBorder:
                                            OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          borderSide: const BorderSide(
                                            color: Colors.redAccent,
                                            width: 1.4,
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 24),

                                    SizedBox(
                                      width: double.infinity,
                                      height: 54,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient:
                                              JinnTvTheme.primaryGradient,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                          onPressed:
                                              _submitting ? null : _submit,
                                          child: _submitting
                                              ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2.4,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                            Color>(
                                                      Colors.white,
                                                    ),
                                                  ),
                                                )
                                              : const Text(
                                                  'Submit',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 16),

                                    Center(
                                      child: TextButton(
                                        onPressed: _submitting
                                            ? null
                                            : _schedulePopToLogin,
                                        child: const Text(
                                          'Back to Login',
                                          style: TextStyle(
                                            color: JinnTvTheme.pink,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  static Widget _label(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withOpacity(.72),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}