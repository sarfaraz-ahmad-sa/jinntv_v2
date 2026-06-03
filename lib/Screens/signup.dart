import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:url_launcher/url_launcher.dart';

// Firebase + Google + Apple
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'app_shell.dart';
import '../db/db_helper.dart';
import '../theme/jinntv_theme.dart';
import 'login.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passCtrl = TextEditingController();

  String fullPhoneNumber = '';

  static const String signupUrl = "https://jinntv.com/php_scripts/data.php";
  static const String loginUrl = "https://jinntv.com/login_app.php";
  static const String privacyPolicyUrl =
      "https://www.jinntv.com/app-privacy-policy";
  static const String termsUrl = "https://www.jinntv.com/termofuse.pdf";

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  bool _obscurePassword = true;
  bool _popScheduled = false;

  @override
  void dispose() {
    FocusManager.instance.primaryFocus?.unfocus();
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

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

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to open link")),
      );
    }
  }

  Future<void> _createAccount() async {
    final name = nameCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final password = passCtrl.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        fullPhoneNumber.isEmpty ||
        password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All fields are required")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(signupUrl),
        body: {
          'fullname': name,
          'uemail': email,
          'phoneno': fullPhoneNumber,
          'upassword': password,
          'isApp': '1',
        },
      );

      if (response.statusCode == 200 && response.body.trim() == "1") {
        if (!kIsWeb) {
          await DBHelper.addLog("Signup success: $email");
          await DBHelper.addusers_signup(
            name: name,
            email: email,
            password: password,
            phone: fullPhoneNumber,
          );
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Success! Your account has been registered successfully",
            ),
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else if (response.body.trim() == "2") {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error! This user already exists")),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Signup failed")),
        );
      }
    } catch (e) {
      debugPrint("SIGNUP ERROR: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("no connection!")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _apiSignupGoogle({
    required String name,
    required String email,
    required String googleUid,
  }) async {
    try {
      final res = await http.post(
        Uri.parse(signupUrl),
        body: {
          'fullname': name.isNotEmpty ? name : 'Google User',
          'uemail': email,
          'phoneno': '',
          'upassword': googleUid,
          'isApp': '1',
          'isGoogle': '1',
          'google_uid': googleUid,
        },
      );

      debugPrint("API SIGNUP(G) STATUS: ${res.statusCode}");
      debugPrint("API SIGNUP(G) BODY: ${res.body}");

      if (res.statusCode != 200) return false;

      final body = res.body.trim();
      return (body == "1" || body == "2");
    } catch (e) {
      debugPrint("API SIGNUP(G) ERROR: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>?> _apiLoginGoogle({
    required String email,
    required String googleUid,
  }) async {
    try {
      final res = await http.post(
        Uri.parse(loginUrl),
        body: {
          'email': email,
          'password': '',
          'isGoogle': '1',
          'google_uid': googleUid,
          'isApp': '1',
        },
      );

      debugPrint("API LOGIN(G) STATUS: ${res.statusCode}");
      debugPrint("API LOGIN(G) BODY: ${res.body}");

      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body);
      if (data is Map<String, dynamic> && data['status'] == 'success') {
        return data;
      }
      return null;
    } catch (e) {
      debugPrint("API LOGIN(G) ERROR: $e");
      return null;
    }
  }

  Future<void> _continueWithGoogle() async {
    setState(() => _isGoogleLoading = true);

    try {
      await GoogleSignIn.instance.initialize();
      final googleUser = await GoogleSignIn.instance.authenticate();
      if (googleUser == null) {
        return;
      }

      final googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final firebaseUser = userCred.user;
      if (firebaseUser == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Google signup error")),
        );
        return;
      }

      final email = (firebaseUser.email ?? '').trim();
      final name = (firebaseUser.displayName ?? '').trim();
      final uid = firebaseUser.uid;

      if (email.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Google email not available")),
        );
        return;
      }

      final ok = await _apiSignupGoogle(
        name: name,
        email: email,
        googleUid: uid,
      );

      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Server signup failed")),
        );
        return;
      }

      final apiData = await _apiLoginGoogle(email: email, googleUid: uid);
      if (apiData == null || apiData['user'] == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Server login failed")),
        );
        return;
      }

      final user = apiData['user'];

      if (!kIsWeb) {
        await DBHelper.addUsers(
          userid: (user['id'] ?? '').toString(),
          username: (user['name'] ?? '').toString(),
          password: '',
          email: (user['email'] ?? '').toString(),
          phoneno: (user['phoneno'] ?? '').toString(),
          user_registered: (user['user_registered'] ?? '').toString(),
          displayName: (user['display_name'] ?? user['name'] ?? '').toString(),
          userRole: (user['user_role'] ?? '').toString(),
          status: (user['status'] ?? '').toString(),
        );

        await DBHelper.saveSession(
          userid: user['id'].toString(),
          email: user['email'].toString(),
        );
        await DBHelper.addLog("Google signup/login success(API): $user");
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint("GOOGLE FIREBASE ERROR: ${e.code} - ${e.message}");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Google signup error")),
      );
    } catch (e) {
      debugPrint("GOOGLE SIGNUP ERROR: $e");

      final msg = e.toString().toLowerCase();
      if (msg.contains('canceled') ||
          msg.contains('cancelled') ||
          msg.contains('aborted') ||
          msg.contains('popup_closed') ||
          msg.contains('sign_in_canceled')) {
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Google signup error")),
      );
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _continueWithApple() async {
    setState(() => _isAppleLoading = true);

    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCred =
          await FirebaseAuth.instance.signInWithCredential(oauthCredential);

      final firebaseUser = userCred.user;
      if (firebaseUser == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Apple signup error")),
        );
        return;
      }

      final email = (firebaseUser.email ?? appleCredential.email ?? '').trim();
      final name = [
        appleCredential.givenName ?? '',
        appleCredential.familyName ?? '',
      ].where((s) => s.isNotEmpty).join(' ');
      final uid = firebaseUser.uid;

      if (email.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Apple email not available")),
        );
        return;
      }

      final ok = await _apiSignupGoogle(
        name: name.isNotEmpty ? name : 'Apple User',
        email: email,
        googleUid: uid,
      );

      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Server signup failed")),
        );
        return;
      }

      final apiData = await _apiLoginGoogle(email: email, googleUid: uid);
      if (apiData == null || apiData['user'] == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Server login failed")),
        );
        return;
      }

      final user = apiData['user'];

      if (!kIsWeb) {
        await DBHelper.addUsers(
          userid: (user['id'] ?? '').toString(),
          username: (user['name'] ?? '').toString(),
          password: '',
          email: (user['email'] ?? '').toString(),
          phoneno: (user['phoneno'] ?? '').toString(),
          user_registered: (user['user_registered'] ?? '').toString(),
          displayName: (user['display_name'] ?? user['name'] ?? '').toString(),
          userRole: (user['user_role'] ?? '').toString(),
          status: (user['status'] ?? '').toString(),
        );

        await DBHelper.saveSession(
          userid: user['id'].toString(),
          email: user['email'].toString(),
        );
        await DBHelper.addLog("Apple signup/login success(API): $user");
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      debugPrint("APPLE AUTH ERROR: ${e.code} - ${e.message}");

      if (e.code == AuthorizationErrorCode.canceled) {
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to sign up with Apple")),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint("APPLE FIREBASE ERROR: ${e.code} - ${e.message}");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Unable to sign up with Apple")),
      );
    } catch (e) {
      debugPrint("APPLE SIGNUP ERROR: $e");

      final msg = e.toString().toLowerCase();
      if (msg.contains('canceled') ||
          msg.contains('cancelled') ||
          msg.contains('aborted')) {
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to sign up with Apple")),
      );
    } finally {
      if (mounted) setState(() => _isAppleLoading = false);
    }
  }

  Widget _socialLogoButton({
    required String text,
    required String asset,
    required Color bgColor,
    required Color textColor,
    required bool loading,
    required VoidCallback? onPressed,
    Color? borderColor,
    Color? logoColor,
    double logoSize = 20,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: bgColor,
          side: BorderSide(
            color: borderColor ?? Colors.transparent,
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onPressed,
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: textColor,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    asset,
                    width: logoSize,
                    height: logoSize,
                    fit: BoxFit.contain,
                    color: logoColor,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.login,
                        color: textColor,
                        size: logoSize,
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Text(
                    text,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _googleButton() {
    return _socialLogoButton(
      text: _isGoogleLoading ? 'Please wait...' : 'Continue with Google',
      asset: 'assets/images/google.png',
      bgColor: Colors.white,
      textColor: Colors.black,
      borderColor: Colors.grey.shade300,
      loading: _isGoogleLoading,
      onPressed: _isGoogleLoading ? null : _continueWithGoogle,
      logoSize: 20,
    );
  }

  Widget _appleButton() {
    return _socialLogoButton(
      text: _isAppleLoading ? 'Please wait...' : 'Continue with Apple',
      asset: 'assets/images/apple.png',
      bgColor: Colors.black,
      textColor: Colors.white,
      borderColor: Colors.grey.shade800,
      loading: _isAppleLoading,
      onPressed: _isAppleLoading ? null : _continueWithApple,
      logoColor: Colors.white,
      logoSize: 18,
    );
  }

  Widget _legalText() {
    final linkStyle = TextStyle(
      color: JinnTvTheme.pink,
      fontSize: 11.8,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: JinnTvTheme.pink,
    );

    final baseStyle = TextStyle(
      color: Colors.white.withOpacity(.48),
      fontSize: 11.5,
      height: 1.5,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text.rich(
        TextSpan(
          style: baseStyle,
          children: [
            const TextSpan(text: 'By continuing, you agree to our '),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: GestureDetector(
                onTap: () => _openExternalUrl(termsUrl),
                child: Text(
                  'Terms of Use',
                  style: linkStyle,
                ),
              ),
            ),
            const TextSpan(text: ' and '),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: GestureDetector(
                onTap: () => _openExternalUrl(privacyPolicyUrl),
                child: Text(
                  'Privacy Policy',
                  style: linkStyle,
                ),
              ),
            ),
            const TextSpan(text: '.'),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
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
            Positioned.fill(
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
                        const SizedBox(height: 8),
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Center(
                                      child: Column(
                                        children: [
                                          Text(
                                            'Create Account',
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(height: 6),
                                          Text(
                                            'Join JinnTV and start your journey',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 26),
                                    _label('Full Name'),
                                    _input(
                                      controller: nameCtrl,
                                      hint: 'Enter your full name',
                                      icon: Icons.person_outline,
                                    ),
                                    const SizedBox(height: 16),
                                    _label('Email'),
                                    _input(
                                      controller: emailCtrl,
                                      hint: 'Enter your email',
                                      icon: Icons.email_outlined,
                                      keyboard: TextInputType.emailAddress,
                                    ),
                                    const SizedBox(height: 16),
                                    _label('WhatsApp No'),
                                    Theme(
                                      data: Theme.of(context).copyWith(
                                        inputDecorationTheme:
                                            InputDecorationTheme(
                                          hintStyle: TextStyle(
                                            color: Colors.white.withOpacity(.38),
                                          ),
                                          filled: true,
                                          fillColor:
                                              Colors.white.withOpacity(.05),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            borderSide: BorderSide(
                                              color:
                                                  Colors.white.withOpacity(.08),
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            borderSide: BorderSide(
                                              color:
                                                  Colors.white.withOpacity(.08),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            borderSide: BorderSide(
                                              color: JinnTvTheme.pink,
                                              width: 1.4,
                                            ),
                                          ),
                                        ),
                                      ),
                                      child: IntlPhoneField(
                                        initialCountryCode: 'PK',
                                        dropdownIconPosition:
                                            IconPosition.trailing,
                                        style:
                                            const TextStyle(color: Colors.white),
                                        dropdownTextStyle:
                                            const TextStyle(color: Colors.white),
                                        decoration: const InputDecoration(
                                          hintText: 'Enter WhatsApp number',
                                        ),
                                        onChanged: (phone) {
                                          fullPhoneNumber = phone.completeNumber;
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _label('Password'),
                                    _input(
                                      controller: passCtrl,
                                      hint: 'Create a password',
                                      icon: Icons.lock_outline,
                                      isPassword: true,
                                      obscureText: _obscurePassword,
                                      suffixIcon: IconButton(
                                        onPressed: () {
                                          setState(() {
                                            _obscurePassword =
                                                !_obscurePassword;
                                          });
                                        },
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: Colors.white54,
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
                                              _isLoading ? null : _createAccount,
                                          child: _isLoading
                                              ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2.2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : const Text(
                                                  'Create Account',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Divider(
                                            color:
                                                Colors.white.withOpacity(.14),
                                          ),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          child: Text(
                                            'OR',
                                            style:
                                                TextStyle(color: Colors.white54),
                                          ),
                                        ),
                                        Expanded(
                                          child: Divider(
                                            color:
                                                Colors.white.withOpacity(.14),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    _googleButton(),
                                    if (!kIsWeb && Platform.isIOS) ...[
                                      const SizedBox(height: 12),
                                      _appleButton(),
                                    ],
                                    const SizedBox(height: 18),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Text(
                                          'Already a member? ',
                                          style:
                                              TextStyle(color: Colors.white60),
                                        ),
                                        GestureDetector(
                                          onTap: _schedulePopToLogin,
                                          child: Text(
                                            'Login',
                                            style: TextStyle(
                                              color: JinnTvTheme.pink,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _legalText(),
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

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(.72),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    TextInputType keyboard = TextInputType.text,
    bool isPassword = false,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: isPassword ? obscureText : false,
      style: const TextStyle(color: Colors.white),
      cursorColor: JinnTvTheme.pink,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(.38)),
        prefixIcon: icon == null
            ? null
            : Icon(icon, color: Colors.white.withOpacity(.62), size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(.05),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: JinnTvTheme.pink, width: 1.4),
        ),
      ),
    );
  }
}