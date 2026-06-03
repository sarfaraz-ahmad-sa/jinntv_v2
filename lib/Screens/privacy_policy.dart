import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/jinntv_theme.dart';
import 'app_shell.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  String? copiedEmail;
  Timer? _copyResetTimer;

  final _kContact = GlobalKey();
  final _kCollection = GlobalKey();
  final _kUse = GlobalKey();
  final _kAccess = GlobalKey();
  final _kChoices = GlobalKey();
  final _kSecurity = GlobalKey();

  final TextEditingController _searchCtrl = TextEditingController();

  static const _emailGeneral = 'salam@jinntv.com';
  static const _emailPrivacy = 'salam@jinntv.com';

  Future<void> _copyText(String text, String fieldTag) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;

    setState(() => copiedEmail = fieldTag);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        content: Text('Copied: $text'),
      ),
    );

    _copyResetTimer?.cancel();
    _copyResetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && copiedEmail == fieldTag) {
        setState(() => copiedEmail = null);
      }
    });
  }

  void _openFullScreen(String title, String value) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenValueView(label: title, value: value),
      ),
    );
  }

  void _jumpTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  void _searchAndJump(String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return;

    if (s.contains('contact') ||
        s.contains('email') ||
        s.contains('privacy@') ||
        s.contains('salam@')) {
      _jumpTo(_kContact);
      return;
    }
    if (s.contains('collect') ||
        s.contains('information') ||
        s.contains('cookie') ||
        s.contains('device')) {
      _jumpTo(_kCollection);
      return;
    }
    if (s.contains('use') ||
        s.contains('personalize') ||
        s.contains('marketing')) {
      _jumpTo(_kUse);
      return;
    }
    if (s.contains('profile') ||
        s.contains('remember me') ||
        s.contains('account')) {
      _jumpTo(_kAccess);
      return;
    }
    if (s.contains('choice') ||
        s.contains('unsubscribe') ||
        s.contains('push')) {
      _jumpTo(_kChoices);
      return;
    }
    if (s.contains('security') || s.contains('safeguard')) {
      _jumpTo(_kSecurity);
      return;
    }

    _jumpTo(_kCollection);
  }

  @override
  void dispose() {
    _copyResetTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _TopHeader(onBack: _handleBack),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 820),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _HeaderCard(
                              title: 'Privacy Policy',
                              subtitle:
                                  'This statement explains our practices and your choices regarding collection, use, and disclosure of certain information, including personal information, by Ishara Foundation ("JinnTV").',
                            ),
                            const SizedBox(height: 12),
                            _SearchBar(
                              controller: _searchCtrl,
                              hint:
                                  'Search & jump (e.g., cookies, security, email)...',
                              onSubmit: _searchAndJump,
                            ),
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _JumpChip(
                                    text: 'Contact',
                                    onTap: () => _jumpTo(_kContact),
                                  ),
                                  _JumpChip(
                                    text: 'Collection',
                                    onTap: () => _jumpTo(_kCollection),
                                  ),
                                  _JumpChip(
                                    text: 'Use',
                                    onTap: () => _jumpTo(_kUse),
                                  ),
                                  _JumpChip(
                                    text: 'Account',
                                    onTap: () => _jumpTo(_kAccess),
                                  ),
                                  _JumpChip(
                                    text: 'Choices',
                                    onTap: () => _jumpTo(_kChoices),
                                  ),
                                  _JumpChip(
                                    text: 'Security',
                                    onTap: () => _jumpTo(_kSecurity),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _SectionCard(
                              key: _kContact,
                              title: 'Contacting Us',
                              icon: Icons.support_agent_rounded,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _Paragraph(
                                    'If you have general questions about your account or customer service, please contact:',
                                  ),
                                  _EmailTileImproved(
                                    email: _emailGeneral,
                                    isCopied: copiedEmail == 'general',
                                    onCopy: () =>
                                        _copyText(_emailGeneral, 'general'),
                                    onFullScreen: () =>
                                        _openFullScreen('Email', _emailGeneral),
                                  ),
                                  const SizedBox(height: 10),
                                  const _Paragraph(
                                    'For questions specifically about this Privacy Statement, or our use of your personal information, cookies or similar technologies, please contact:',
                                  ),
                                  _EmailTileImproved(
                                    email: _emailPrivacy,
                                    isCopied: copiedEmail == 'privacy',
                                    onCopy: () =>
                                        _copyText(_emailPrivacy, 'privacy'),
                                    onFullScreen: () =>
                                        _openFullScreen('Email', _emailPrivacy),
                                  ),
                                  const SizedBox(height: 10),
                                  const _Paragraph(
                                    'The data controller of your personal information is Ishara Foundation. If you contact us for assistance, we may need to authenticate your identity before fulfilling your request.',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _SectionCard(
                              key: _kCollection,
                              title: 'Collection of Information',
                              icon: Icons.inventory_2_rounded,
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _Paragraph(
                                    'We receive and store information about you such as:',
                                  ),
                                  _SubTitle('Information you provide to us'),
                                  _Paragraph(
                                    'We collect information you provide to us including your name, email address, date of birth, and telephone number. This may be collected when you use our service or interact with customer service.',
                                  ),
                                  _SubTitle('Information we collect automatically'),
                                  _BulletItem(
                                    'Your activity on JinnTV such as title selections, shows watched, and search queries.',
                                  ),
                                  _BulletItem(
                                    'Customer service interactions including call logs and chat transcripts.',
                                  ),
                                  _BulletItem(
                                    'Device and software characteristics, IP address and connection type.',
                                  ),
                                  _BulletItem(
                                    'Information collected via cookies, web beacons, and advertising technologies.',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _SectionCard(
                              key: _kUse,
                              title: 'Use of Information',
                              icon: Icons.auto_awesome_rounded,
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _Paragraph(
                                    'We use information to provide, analyze, administer, enhance and personalize our services and marketing efforts, process registrations and payments, and communicate with you.',
                                  ),
                                  _BulletItem(
                                    'Provide personalized content and recommendations.',
                                  ),
                                  _BulletItem(
                                    'Improve user experience and service performance.',
                                  ),
                                  _BulletItem(
                                    'Send service-related communications and promotional updates.',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _SectionCard(
                              key: _kAccess,
                              title: 'Access to Account and Profiles',
                              icon: Icons.manage_accounts_rounded,
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _SubTitle('"Remember me" function'),
                                  _Paragraph(
                                    'For ease of access, you can use "Remember me on this device" when you log in. This helps provide direct account access without requiring re-entry of credentials when your browser revisits the service.',
                                  ),
                                  _SubTitle('Profiles'),
                                  _Paragraph(
                                    'Profiles allow users to have a distinct, personalized JinnTV experience based on interests, including separate watch histories.',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _SectionCard(
                              key: _kChoices,
                              title: 'Your Choices',
                              icon: Icons.tune_rounded,
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _SubTitle('Email & text messages'),
                                  _Paragraph(
                                    'If you no longer want to receive certain communications via email or text message, click "unsubscribe" in the email or reply STOP.',
                                  ),
                                  _SubTitle('Push notifications'),
                                  _Paragraph(
                                    'You can choose to receive mobile push notifications from JinnTV. You can turn them off from device settings.',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _SectionCard(
                              key: _kSecurity,
                              title: 'Security',
                              icon: Icons.security_rounded,
                              child: const _Paragraph(
                                'We use reasonable administrative, logical, physical, and managerial measures to safeguard your personal information.',
                              ),
                            ),
                            const SizedBox(height: 18),
                            Center(
                              child: Text(
                                'Last updated: 2026',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(.58),
                                  fontSize: 12,
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
        ],
      ),
    );
  }
}

/* --------------------------- UI COMPONENTS --------------------------- */

class _TopHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _TopHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          Container(
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: onBack,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            height: 50,
            width: 100,
            padding: const EdgeInsets.all(6),
            child: Image.asset(
              'assets/images/jinn-tv-logo.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Privacy Policy',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _HeaderCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: JinnTvTheme.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: JinnTvTheme.pink.withOpacity(0.20),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.privacy_tip_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        height: 1.35,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onSubmit;

  const _SearchBar({
    required this.controller,
    required this.hint,
    required this.onSubmit,
  });

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      onSubmitted: widget.onSubmit,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(.38)),
        prefixIcon: const Icon(Icons.search, color: Colors.white54),
        suffixIcon: widget.controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear, color: Colors.white54),
                onPressed: () {
                  widget.controller.clear();
                  FocusManager.instance.primaryFocus?.unfocus();
                  setState(() {});
                },
              ),
        filled: true,
        fillColor: Colors.white.withOpacity(.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(.08)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(
            color: JinnTvTheme.pink,
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

class _JumpChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _JumpChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(text),
        onPressed: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        backgroundColor: JinnTvTheme.pink.withOpacity(0.10),
        labelStyle: const TextStyle(
          color: JinnTvTheme.pink,
          fontWeight: FontWeight.w800,
        ),
        shape: StadiumBorder(
          side: BorderSide(color: JinnTvTheme.pink.withOpacity(0.18)),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: JinnTvTheme.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: JinnTvTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: JinnTvTheme.accentGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _SubTitle extends StatelessWidget {
  final String text;
  const _SubTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  final String text;
  const _Paragraph(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(.82),
          fontSize: 14,
          height: 1.55,
        ),
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  const _BulletItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: JinnTvTheme.pink,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(.80),
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmailTileImproved extends StatelessWidget {
  final String email;
  final bool isCopied;
  final VoidCallback onCopy;
  final VoidCallback onFullScreen;

  const _EmailTileImproved({
    required this.email,
    required this.isCopied,
    required this.onCopy,
    required this.onFullScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onCopy();
        },
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(.08)),
          ),
          child: Row(
            children: [
              const Icon(Icons.email_rounded, color: JinnTvTheme.pink),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  email,
                  style: const TextStyle(
                    color: JinnTvTheme.pink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Full screen',
                icon: Icon(
                  Icons.open_in_full,
                  color: Colors.white.withOpacity(.72),
                ),
                onPressed: onFullScreen,
              ),
              _Pill(
                text: isCopied ? 'Copied' : 'Copy',
                icon: isCopied ? Icons.check_rounded : Icons.copy_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final IconData icon;

  const _Pill({super.key, required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: JinnTvTheme.pink.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: JinnTvTheme.pink.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: JinnTvTheme.pink),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: JinnTvTheme.pink,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _FullScreenValueView extends StatelessWidget {
  final String label;
  final String value;

  const _FullScreenValueView({
    required this.label,
    required this.value,
  });

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Copied: $value'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: JinnTvTheme.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: JinnTvTheme.border),
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: JinnTvTheme.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: JinnTvTheme.border),
                        ),
                        child: IconButton(
                          tooltip: 'Copy',
                          icon: const Icon(
                            Icons.copy_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () => _copy(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            color: JinnTvTheme.card,
                            border: Border.all(color: JinnTvTheme.border),
                          ),
                          child: SelectableText(
                            value,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              height: 1.4,
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
        ],
      ),
    );
  }
}