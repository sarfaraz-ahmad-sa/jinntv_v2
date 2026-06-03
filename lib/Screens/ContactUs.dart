import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';

import '../theme/jinntv_theme.dart';
import 'app_shell.dart';

class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _subject = TextEditingController();
  final _message = TextEditingController();

  final _nameNode = FocusNode();
  final _emailNode = FocusNode();
  final _subjectNode = FocusNode();
  final _messageNode = FocusNode();

  bool _submitting = false;
  bool _loading = true;
  bool _refreshing = false;
  bool _isFetchingContent = false;
  bool _leaving = false;
  String? _error;

  String? _copiedKey;
  String _fullPhoneNumber = '';
  PhoneNumber? _phoneObj;
  DateTime? _lastFetchAt;

  static const _contentApiUrl =
      'https://jinntv.com/jinn-tv-admin/api_contact_us.php';

  ContactUsData? _data;
  Timer? _copyResetTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadContactContent(initial: true);
  }

  @override
  void dispose() {
    _leaving = true;

    _name.dispose();
    _email.dispose();
    _subject.dispose();
    _message.dispose();

    _nameNode.dispose();
    _emailNode.dispose();
    _subjectNode.dispose();
    _messageNode.dispose();

    WidgetsBinding.instance.removeObserver(this);
    _copyResetTimer?.cancel();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final last = _lastFetchAt;
      if (last == null ||
          DateTime.now().difference(last) > const Duration(minutes: 2)) {
        _loadContactContent(silent: true);
      }
    }
  }

  Future<void> _loadContactContent({
    bool initial = false,
    bool silent = false,
  }) async {
    if (!mounted || _leaving || _isFetchingContent) return;

    _isFetchingContent = true;

    if (initial) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else if (!silent) {
      setState(() {
        _refreshing = true;
        _error = null;
      });
    }

    try {
      final res = await http
          .get(
            Uri.parse(_contentApiUrl),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }

      final map = jsonDecode(res.body) as Map<String, dynamic>;

      if (map['success'] == true && map['data'] != null) {
        final data =
            ContactUsData.fromJson(map['data'] as Map<String, dynamic>);

        if (!mounted || _leaving) return;

        _lastFetchAt = DateTime.now();

        setState(() {
          _data = data;
          _error = null;
        });
      } else {
        throw Exception(map['message'] ?? 'Invalid API response');
      }
    } catch (e) {
      if (_data == null) {
        _data = ContactUsData.fallback();
      }

      if (!mounted || _leaving) return;

      setState(() {
        _error = e.toString();
      });
    } finally {
      _isFetchingContent = false;

      if (!mounted || _leaving) return;

      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  bool _isValidEmail(String v) {
    final s = v.trim();
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return re.hasMatch(s);
  }

  Future<void> _copy(String value, String key) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted || _leaving) return;

    setState(() => _copiedKey = key);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        content: Text('Copied: $value'),
      ),
    );

    _copyResetTimer?.cancel();
    _copyResetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && !_leaving && _copiedKey == key) {
        setState(() => _copiedKey = null);
      }
    });
  }

  void _openFullScreen(String label, String value) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenValueView(label: label, value: value),
      ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final d = _data ?? ContactUsData.fallback();
    final endpoint = d.contactSubmitUrl.trim();

    if (endpoint.isEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Contact submit URL is not configured.'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final uri = Uri.parse(endpoint);

      final body = <String, String>{
        'contact_name': _name.text.trim(),
        'contactemail': _email.text.trim(),
        'phoneno': _fullPhoneNumber.trim(),
        'subject': _subject.text.trim(),
        'message': _message.text.trim(),
        'isApp': '1',
      };

      final res = await http
          .post(
            uri,
            headers: const {
              'Content-Type':
                  'application/x-www-form-urlencoded; charset=UTF-8',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted || _leaving) return;

      final server = res.body.trim();
      final success = res.statusCode == 200 && server == '1';

      setState(() => _submitting = false);

      ScaffoldMessenger.of(context).clearSnackBars();

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Message sent successfully!'),
          ),
        );

        _name.clear();
        _email.clear();
        _subject.clear();
        _message.clear();

        _fullPhoneNumber = '';
        _phoneObj = null;

        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Failed. Server: "$server" (HTTP ${res.statusCode})'),
          ),
        );
      }
    } on TimeoutException {
      if (!mounted || _leaving) return;

      setState(() => _submitting = false);

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Request timeout. Please try again.'),
        ),
      );
    } catch (e) {
      if (!mounted || _leaving) return;

      setState(() => _submitting = false);

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Error: $e'),
        ),
      );
    }
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String value,
    required String keyName,
  }) {
    return _ActionTile(
      icon: icon,
      title: title,
      value: value,
      isCopied: _copiedKey == keyName,
      onCopy: () => _copy(value, keyName),
      onFullScreen: () => _openFullScreen(title, value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _data ?? ContactUsData.fallback();

    return WillPopScope(
      onWillPop: () async {
        if (_submitting) return false;
        _leaving = true;
        return true;
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
              child: IgnorePointer(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: JinnTvTheme.purple.withOpacity(.22),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 110,
              right: -70,
              child: IgnorePointer(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: JinnTvTheme.pink.withOpacity(.16),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -70,
              left: 30,
              child: IgnorePointer(
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: JinnTvTheme.blue.withOpacity(.08),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: _loading && _data == null
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: JinnTvTheme.pink,
                      ),
                    )
                  : RefreshIndicator(
                      color: JinnTvTheme.pink,
                      onRefresh: () => _loadContactContent(),
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: _TopHeader(
                              logoUrl: d.logoImage,
                              onBack: () {
                                if (_submitting) return;
                                _leaving = true;
                                if (Navigator.canPop(context)) {
                                  Navigator.pop(context);
                                } else {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const AppShell(),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 860),
                                  child: Form(
                                    key: _formKey,
                                    child: AbsorbPointer(
                                      absorbing: _submitting,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (_error != null)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                bottom: 12,
                                              ),
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.withOpacity(
                                                  0.12,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: Colors.orange
                                                      .withOpacity(0.30),
                                                ),
                                              ),
                                              child: Text(
                                                'Sync issue. Showing available content.',
                                                style: TextStyle(
                                                  color: Colors.orange.shade200,
                                                  fontSize: 12.5,
                                                ),
                                              ),
                                            ),
                                          _HeroCard(
                                            title: d.pageTitle,
                                            subtitle: d.pageSubtitle,
                                          ),
                                          const SizedBox(height: 14),
                                          _SectionCard(
                                            title: 'Contact details',
                                            icon: Icons.contact_mail_rounded,
                                            child: LayoutBuilder(
                                              builder: (context, c) {
                                                final isWide =
                                                    c.maxWidth >= 720;

                                                final tiles = <Widget>[
                                                  _buildActionTile(
                                                    icon: Icons.email_rounded,
                                                    title: 'Email',
                                                    value: d.supportEmail,
                                                    keyName: 'email',
                                                  ),
                                                  _buildActionTile(
                                                    icon: Icons.phone_rounded,
                                                    title: 'Phone',
                                                    value: d.supportPhone,
                                                    keyName: 'phone',
                                                  ),
                                                  _buildActionTile(
                                                    icon: Icons.location_on_rounded,
                                                    title: 'Address',
                                                    value: d.supportAddress,
                                                    keyName: 'address',
                                                  ),
                                                ];

                                                if (!isWide) {
                                                  return Column(
                                                    children: [
                                                      for (int i = 0;
                                                          i < tiles.length;
                                                          i++) ...[
                                                        tiles[i],
                                                        if (i !=
                                                            tiles.length - 1)
                                                          const SizedBox(
                                                            height: 10,
                                                          ),
                                                      ],
                                                    ],
                                                  );
                                                }

                                                return Wrap(
                                                  spacing: 12,
                                                  runSpacing: 12,
                                                  children: tiles
                                                      .map(
                                                        (w) => SizedBox(
                                                          width:
                                                              (c.maxWidth - 12) /
                                                                  2,
                                                          child: w,
                                                        ),
                                                      )
                                                      .toList(),
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          _SectionCard(
                                            title: 'Send a message',
                                            icon: Icons.edit_rounded,
                                            child: Column(
                                              children: [
                                                _Field(
                                                  label: 'Name *',
                                                  hint: 'Your full name',
                                                  controller: _name,
                                                  focusNode: _nameNode,
                                                  textInputAction:
                                                      TextInputAction.next,
                                                  keyboardType:
                                                      TextInputType.name,
                                                  onSubmitted: (_) =>
                                                      _emailNode.requestFocus(),
                                                  validator: (v) =>
                                                      (v == null ||
                                                              v.trim().isEmpty)
                                                          ? 'Name is required'
                                                          : null,
                                                ),
                                                _Field(
                                                  label: 'Email *',
                                                  hint:
                                                      'your.email@example.com',
                                                  controller: _email,
                                                  focusNode: _emailNode,
                                                  textInputAction:
                                                      TextInputAction.next,
                                                  keyboardType:
                                                      TextInputType
                                                          .emailAddress,
                                                  onSubmitted: (_) =>
                                                      FocusScope.of(context)
                                                          .nextFocus(),
                                                  validator: (v) {
                                                    if (v == null ||
                                                        v.trim().isEmpty) {
                                                      return 'Email is required';
                                                    }
                                                    if (!_isValidEmail(v)) {
                                                      return 'Enter a valid email';
                                                    }
                                                    return null;
                                                  },
                                                ),
                                                _PhoneField(
                                                  label: 'Phone (optional)',
                                                  initialCountryCode: 'PK',
                                                  onChanged: (phone) {
                                                    _phoneObj = phone;
                                                    _fullPhoneNumber =
                                                        phone.completeNumber;
                                                  },
                                                  validator: (phone) {
                                                    if (phone == null) {
                                                      return null;
                                                    }
                                                    if (phone.number
                                                        .trim()
                                                        .isEmpty) {
                                                      return null;
                                                    }

                                                    try {
                                                      final ok =
                                                          phone.isValidNumber();
                                                      if (!ok) {
                                                        return 'Enter a valid phone number';
                                                      }
                                                    } catch (_) {
                                                      if (phone.number
                                                              .trim()
                                                              .length <
                                                          7) {
                                                        return 'Enter a valid phone number';
                                                      }
                                                    }
                                                    return null;
                                                  },
                                                ),
                                                _Field(
                                                  label: 'Subject *',
                                                  hint:
                                                      'What is this regarding?',
                                                  controller: _subject,
                                                  focusNode: _subjectNode,
                                                  textInputAction:
                                                      TextInputAction.next,
                                                  onSubmitted: (_) =>
                                                      _messageNode
                                                          .requestFocus(),
                                                  validator: (v) =>
                                                      (v == null ||
                                                              v.trim().isEmpty)
                                                          ? 'Subject is required'
                                                          : null,
                                                ),
                                                _Field(
                                                  label: 'Message *',
                                                  hint: 'Tell us more…',
                                                  controller: _message,
                                                  focusNode: _messageNode,
                                                  textInputAction:
                                                      TextInputAction.newline,
                                                  maxLines: 5,
                                                  keyboardType:
                                                      TextInputType.multiline,
                                                  validator: (v) =>
                                                      (v == null ||
                                                              v.trim().isEmpty)
                                                          ? 'Message is required'
                                                          : null,
                                                ),
                                                const SizedBox(height: 6),
                                                SizedBox(
                                                  width: double.infinity,
                                                  child: DecoratedBox(
                                                    decoration: BoxDecoration(
                                                      gradient: JinnTvTheme
                                                          .primaryGradient,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        16,
                                                      ),
                                                    ),
                                                    child: ElevatedButton.icon(
                                                      onPressed: _submitting
                                                          ? null
                                                          : _submit,
                                                      icon: _submitting
                                                          ? const SizedBox(
                                                              width: 18,
                                                              height: 18,
                                                              child:
                                                                  CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                                color:
                                                                    Colors.white,
                                                              ),
                                                            )
                                                          : const Icon(
                                                              Icons.send_rounded,
                                                            ),
                                                      label: Text(
                                                        _submitting
                                                            ? 'Sending…'
                                                            : 'Send message',
                                                      ),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.transparent,
                                                        shadowColor:
                                                            Colors.transparent,
                                                        foregroundColor:
                                                            Colors.white,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                          vertical: 14,
                                                        ),
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(16),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 18),
                                          Center(
                                            child: Text(
                                              d.responseNote,
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withOpacity(.65),
                                                fontSize: 12.5,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          if (_refreshing)
                                            const Padding(
                                              padding:
                                                  EdgeInsets.only(top: 12),
                                              child: Center(
                                                child: SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2.2,
                                                    color: JinnTvTheme.pink,
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
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class ContactUsData {
  final String pageTitle;
  final String pageSubtitle;
  final String supportEmail;
  final String supportPhone;
  final String supportAddress;
  final String responseNote;
  final String logoImage;
  final String contactSubmitUrl;

  const ContactUsData({
    required this.pageTitle,
    required this.pageSubtitle,
    required this.supportEmail,
    required this.supportPhone,
    required this.supportAddress,
    required this.responseNote,
    required this.logoImage,
    required this.contactSubmitUrl,
  });

  factory ContactUsData.fromJson(Map<String, dynamic> json) {
    return ContactUsData(
      pageTitle: (json['page_title'] ?? 'Get in touch').toString(),
      pageSubtitle: (json['page_subtitle'] ?? '').toString(),
      supportEmail: (json['support_email'] ?? '').toString(),
      supportPhone: (json['support_phone'] ?? '').toString(),
      supportAddress: (json['support_address'] ?? '').toString(),
      responseNote: (json['response_note'] ?? '').toString(),
      logoImage: (json['logo_image'] ?? '').toString(),
      contactSubmitUrl: (json['contact_submit_url'] ?? '').toString(),
    );
  }

  factory ContactUsData.fallback() {
    return const ContactUsData(
      pageTitle: 'Get in touch',
      pageSubtitle:
          'Have questions or feedback? Send us a message and we’ll respond as soon as possible.',
      supportEmail: 'support@jinntv.com',
      supportPhone: '+1 (555) 123-4567',
      supportAddress: '123 Islamic Center, City, Country',
      responseNote: 'We typically respond within 24–48 hours.',
      logoImage: '',
      contactSubmitUrl: 'https://www.jinntv.com/php_scripts/data.php',
    );
  }
}

/* --------------------------- UI COMPONENTS --------------------------- */

class _TopHeader extends StatelessWidget {
  final String logoUrl;
  final VoidCallback onBack;

  const _TopHeader({
    required this.logoUrl,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
            onPressed: onBack,
          ),
          const SizedBox(width: 5),
          SizedBox(
            width: 120,
            child: logoUrl.isNotEmpty
                ? Image.network(
                    logoUrl,
                    fit: BoxFit.contain,
                    cacheWidth: 300,
                    frameBuilder:
                        (context, child, frame, wasSynchronouslyLoaded) {
                      if (wasSynchronouslyLoaded || frame != null) {
                        return child;
                      }
                      return const SizedBox(
                        height: 40,
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Image.asset(
                      'assets/images/jinn-tv-logo.png',
                      fit: BoxFit.contain,
                    ),
                  )
                : Image.asset(
                    'assets/images/jinn-tv-logo.png',
                    fit: BoxFit.contain,
                  ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Contact Us',
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

class _HeroCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _HeroCard({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
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
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.20),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                color: Colors.white,
                size: 28,
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
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      height: 1.35,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
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
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool isCopied;
  final VoidCallback onCopy;
  final VoidCallback onFullScreen;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.isCopied,
    required this.onCopy,
    required this.onFullScreen,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onCopy();
      },
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: JinnTvTheme.accentGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.65),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ],
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
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: isCopied
                  ? const _Pill(
                      key: ValueKey('copied'),
                      text: 'Copied',
                      icon: Icons.check_rounded,
                    )
                  : const _Pill(
                      key: ValueKey('copy'),
                      text: 'Copy',
                      icon: Icons.copy_rounded,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final int maxLines;
  final TextInputAction textInputAction;
  final void Function(String)? onSubmitted;

  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    required this.focusNode,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(.70),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            focusNode: focusNode,
            validator: validator,
            keyboardType: keyboardType,
            maxLines: maxLines,
            textInputAction: textInputAction,
            onFieldSubmitted: onSubmitted,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withOpacity(.38)),
              filled: true,
              fillColor: Colors.white.withOpacity(.05),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
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
                  width: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  final String label;
  final String initialCountryCode;
  final void Function(PhoneNumber phone) onChanged;
  final String? Function(PhoneNumber?)? validator;

  const _PhoneField({
    required this.label,
    required this.initialCountryCode,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(.70),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme: InputDecorationTheme(
                hintStyle: TextStyle(color: Colors.white.withOpacity(.38)),
                filled: true,
                fillColor: Colors.white.withOpacity(.05),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
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
                    width: 1.6,
                  ),
                ),
              ),
            ),
            child: IntlPhoneField(
              initialCountryCode: initialCountryCode,
              dropdownIconPosition: IconPosition.trailing,
              style: const TextStyle(color: Colors.white),
              dropdownTextStyle: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Enter phone number',
              ),
              onChanged: onChanged,
              validator: validator,
            ),
          ),
        ],
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}