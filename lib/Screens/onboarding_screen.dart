import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/db_helper.dart';
import 'app_shell.dart';
import 'Login.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Onboarding seen flag
// ─────────────────────────────────────────────────────────────────────────────
const String _kOnboardingKey = 'onboarding_seen_v1';

Future<bool> hasSeenOnboarding() async {
  final sp = await SharedPreferences.getInstance();
  return sp.getBool(_kOnboardingKey) ?? false;
}

Future<void> markOnboardingSeen() async {
  final sp = await SharedPreferences.getInstance();
  await sp.setBool(_kOnboardingKey, true);
}

// ─────────────────────────────────────────────────────────────────────────────
// Slide model
// ─────────────────────────────────────────────────────────────────────────────
class _Slide {
  final IconData icon;
  final Color iconColor;
  final Color bgGlow;
  final String title;
  final String subtitle;

  const _Slide({
    required this.icon,
    required this.iconColor,
    required this.bgGlow,
    required this.title,
    required this.subtitle,
  });
}

const _kSlides = [
  _Slide(
    icon: Icons.play_circle_filled_rounded,
    iconColor: Color(0xFF00A8E1),
    bgGlow: Color(0xFF0077A8),
    title: 'Welcome to JinnTV',
    subtitle:
        'Your premium Islamic & family entertainment platform. Thousands of videos at your fingertips.',
  ),
  _Slide(
    icon: Icons.video_collection_rounded,
    iconColor: Color(0xFF5BC8F5),
    bgGlow: Color(0xFF005F80),
    title: 'Explore & Discover',
    subtitle:
        'Browse categories, trending content and curated sections — all in one place.',
  ),
  _Slide(
    icon: Icons.playlist_add_check_rounded,
    iconColor: Color(0xFF00D4AA),
    bgGlow: Color(0xFF006B56),
    title: 'Build Your My List',
    subtitle:
        'Save your favourite videos and continue watching from where you left off.',
  ),
  _Slide(
    icon: Icons.notifications_active_rounded,
    iconColor: Color(0xFF00A8E1),
    bgGlow: Color(0xFF004466),
    title: 'Stay Up to Date',
    subtitle:
        'Get notified about new episodes, live events and exclusive content — never miss a moment.',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Onboarding Screen
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _current = 0;

  // Per-page animation controllers
  late List<AnimationController> _iconCtrls;
  late List<Animation<double>>   _iconScales;
  late List<Animation<double>>   _iconFades;

  @override
  void initState() {
    super.initState();

    _iconCtrls = List.generate(_kSlides.length, (_) =>
      AnimationController(vsync: this, duration: const Duration(milliseconds: 550)));

    _iconScales = _iconCtrls.map((c) =>
      Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeOutBack))).toList();

    _iconFades = _iconCtrls.map((c) =>
      CurvedAnimation(parent: c, curve: Curves.easeOut)).toList();

    // Animate first slide immediately
    _iconCtrls[0].forward();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    for (final c in _iconCtrls) { c.dispose(); }
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _current = index);
    _iconCtrls[index].reset();
    _iconCtrls[index].forward();
  }

  Future<void> _finish() async {
    await markOnboardingSeen();
    if (!mounted) return;

    final loggedIn = await DBHelper.isLoggedIn();
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            loggedIn ? const AppShell() : const LoginScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _next() {
    if (_current < _kSlides.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size   = MediaQuery.of(context).size;
    final isLast = _current == _kSlides.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFF0F171E),
      body: Stack(
        children: [
          // Animated background glow
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            top: -100,
            left: size.width * (_current / _kSlides.length) - 60,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kSlides[_current].bgGlow.withOpacity(.18),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOut,
            bottom: -80,
            right: size.width * (1 - _current / _kSlides.length) - 80,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 700),
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kSlides[_current].bgGlow.withOpacity(.10),
              ),
            ),
          ),

          Column(
            children: [
              const SizedBox(height: 60),

              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: AnimatedOpacity(
                    opacity: isLast ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: TextButton(
                      onPressed: isLast ? null : _finish,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: Colors.white.withOpacity(.45),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Page view
              Expanded(
                child: PageView.builder(
                  controller: _pageCtrl,
                  onPageChanged: _onPageChanged,
                  itemCount: _kSlides.length,
                  itemBuilder: (_, i) => _buildSlide(i),
                ),
              ),

              // Bottom controls
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
                child: Column(
                  children: [
                    // Dot indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_kSlides.length, (i) {
                        final selected = i == _current;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOut,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: selected ? 28 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            gradient: selected
                                ? const LinearGradient(
                                    colors: [Color(0xFF0077A8), Color(0xFF00A8E1)])
                                : null,
                            color: selected ? null : Colors.white.withOpacity(.2),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 32),

                    // CTA button
                    GestureDetector(
                      onTap: _next,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0077A8), Color(0xFF00A8E1)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00A8E1).withOpacity(.35),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isLast ? 'Get Started' : 'Next',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                isLast
                                    ? Icons.rocket_launch_rounded
                                    : Icons.arrow_forward_rounded,
                                key: ValueKey(isLast),
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Login hint
                    if (isLast) ...[
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _finish,
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                                color: Colors.white.withOpacity(.4),
                                fontSize: 13),
                            children: const [
                              TextSpan(text: 'Already have an account? '),
                              TextSpan(
                                text: 'Sign in',
                                style: TextStyle(
                                  color: Color(0xFF00A8E1),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlide(int index) {
    final slide = _kSlides[index];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated icon illustration
          FadeTransition(
            opacity: _iconFades[index],
            child: ScaleTransition(
              scale: _iconScales[index],
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer ring
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: slide.iconColor.withOpacity(.15), width: 1.5),
                    ),
                  ),
                  // Middle ring
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: slide.iconColor.withOpacity(.25), width: 1),
                    ),
                  ),
                  // Main circle
                  Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          slide.bgGlow.withOpacity(.4),
                          slide.bgGlow.withOpacity(.1),
                        ],
                      ),
                      border: Border.all(
                          color: slide.iconColor.withOpacity(.3), width: 1),
                    ),
                    child: Icon(slide.icon, color: slide.iconColor, size: 52),
                  ),
                  // Corner accent dots
                  for (final angle in [0.0, 90.0, 180.0, 270.0])
                    Transform.rotate(
                      angle: angle * 3.14159 / 180,
                      child: Transform.translate(
                        offset: const Offset(0, -78),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: slide.iconColor.withOpacity(.4),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 48),

          // Title
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              height: 1.15,
            ),
          ),

          const SizedBox(height: 16),

          // Subtitle
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(.55),
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
