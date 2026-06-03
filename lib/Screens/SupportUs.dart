import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../theme/jinntv_theme.dart';
import 'app_shell.dart';

class SupportUsScreen extends StatefulWidget {
  const SupportUsScreen({super.key});

  @override
  State<SupportUsScreen> createState() => _SupportUsScreenState();
}

class _SupportUsScreenState extends State<SupportUsScreen>
    with WidgetsBindingObserver {
  static const String _apiUrl =
      'https://jinntv.com/jinn-tv-admin/api_support_us.php';

  SupportUsData? _data;
  bool _loading = true;
  bool _refreshing = false;
  bool _isFetching = false;
  bool _leaving = false;
  String? _error;
  String? _copiedField;

  Timer? _copyResetTimer;
  DateTime? _lastFetchAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSupportUs(initial: true);
  }

  @override
  void dispose() {
    _leaving = true;
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
        _loadSupportUs(silent: true);
      }
    }
  }

  Future<void> _copy(String value, String field) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted || _leaving) return;

    setState(() => _copiedField = field);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Copied: $value'),
        duration: const Duration(seconds: 2),
      ),
    );

    _copyResetTimer?.cancel();
    _copyResetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && !_leaving && _copiedField == field) {
        setState(() => _copiedField = null);
      }
    });
  }

  Future<void> _loadSupportUs({
    bool initial = false,
    bool silent = false,
  }) async {
    if (!mounted || _leaving || _isFetching) return;

    _isFetching = true;

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
      final response = await http
          .get(
            Uri.parse(_apiUrl),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final map = jsonDecode(response.body) as Map<String, dynamic>;

      if (map['success'] == true && map['data'] != null) {
        final data =
            SupportUsData.fromJson(map['data'] as Map<String, dynamic>);

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
        _data = SupportUsData.fallback();
      }

      if (mounted && !_leaving) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      _isFetching = false;

      if (!mounted || _leaving) return;

      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _copyAllBankDetails() async {
    final d = _data ?? SupportUsData.fallback();
    final all = [
      'Bank Name: ${d.bankName}',
      'Account Title: ${d.accountTitle}',
      'Account Number: ${d.accountNumber}',
      'IBAN: ${d.iban}',
      'Branch: ${d.branchName}',
    ].join('\n');

    HapticFeedback.lightImpact();
    await _copy(all, 'all');
  }

  void _openValueFullScreen(String label, String value) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenValueView(label: label, value: value),
      ),
    );
  }

  void _openBankBottomSheet() {
    final d = _data ?? SupportUsData.fallback();

    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              decoration: BoxDecoration(
                color: JinnTvTheme.bg2.withOpacity(.97),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: JinnTvTheme.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                        child: const Icon(
                          Icons.account_balance_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Bank Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _copyAllBankDetails,
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copy All'),
                        style: TextButton.styleFrom(
                          foregroundColor: JinnTvTheme.pink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildCopyRow('Bank Name', d.bankName, 'bank'),
                  _buildCopyRow('Account Title', d.accountTitle, 'title'),
                  _buildCopyRow('Account Number', d.accountNumber, 'account'),
                  _buildCopyRow('IBAN', d.iban, 'iban'),
                  _buildCopyRow('Branch', d.branchName, 'branch'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCopyRow(String label, String value, String fieldKey) {
    return _CopyRowModern(
      label: label,
      value: value,
      isCopied: _copiedField == fieldKey,
      onCopy: () => _copy(value, fieldKey),
      onFullScreen: () => _openValueFullScreen(label, value),
    );
  }

  IconData _mapIcon(String iconName) {
    switch (iconName) {
      case 'videocam_rounded':
        return Icons.videocam_rounded;
      case 'public_rounded':
        return Icons.public_rounded;
      case 'menu_book_rounded':
        return Icons.menu_book_rounded;
      case 'high_quality_rounded':
        return Icons.high_quality_rounded;
      case 'favorite_rounded':
        return Icons.favorite_rounded;
      case 'volunteer_activism_rounded':
        return Icons.volunteer_activism_rounded;
      default:
        return Icons.star_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data ?? SupportUsData.fallback();

    return WillPopScope(
      onWillPop: () async {
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
                      onRefresh: () => _loadSupportUs(),
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: _TopHeader(
                              logoUrl: d.logoImage,
                              onBack: () {
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
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            sliver: SliverToBoxAdapter(
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 900),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (_error != null)
                                        Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 12),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.orange.withOpacity(0.12),
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
                                        primaryCtaText: 'Copy Bank Details',
                                        onPrimaryCtaTap: _openBankBottomSheet,
                                      ),
                                      const SizedBox(height: 18),
                                      const Text(
                                        'Why support us',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        d.whySupportText,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(.82),
                                          fontSize: 14,
                                          height: 1.6,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverToBoxAdapter(
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 900),
                                  child: const Text(
                                    'Ways to support',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            sliver: SliverToBoxAdapter(
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 900),
                                  child: LayoutBuilder(
                                    builder: (context, c) {
                                      final cols = c.maxWidth >= 760 ? 4 : 2;
                                      final features = d.features;

                                      return GridView.builder(
                                        itemCount: features.length,
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: cols,
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 12,
                                          childAspectRatio:
                                              cols == 4 ? 1.35 : 1.25,
                                        ),
                                        itemBuilder: (_, index) {
                                          final f = features[index];
                                          return _FeatureTile(
                                            icon: _mapIcon(f.icon),
                                            title: f.title,
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                            sliver: SliverToBoxAdapter(
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 900),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Ways to support',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      _SectionCard(
                                        title: 'Bank transfer',
                                        icon:
                                            Icons.account_balance_rounded,
                                        trailing: TextButton.icon(
                                          onPressed: _copyAllBankDetails,
                                          icon: const Icon(
                                            Icons.copy_rounded,
                                            size: 18,
                                          ),
                                          label: const Text('Copy All'),
                                          style: TextButton.styleFrom(
                                            foregroundColor:
                                                JinnTvTheme.pink,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            _buildCopyRow('Bank Name',
                                                d.bankName, 'bank'),
                                            _buildCopyRow('Account Title',
                                                d.accountTitle, 'title'),
                                            _buildCopyRow('Account Number',
                                                d.accountNumber, 'account'),
                                            _buildCopyRow(
                                                'IBAN', d.iban, 'iban'),
                                            _buildCopyRow('Branch',
                                                d.branchName, 'branch'),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      _SectionCard(
                                        title: 'Other ways to help',
                                        icon: Icons
                                            .volunteer_activism_rounded,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: List.generate(
                                            d.otherWays.length,
                                            (index) => _BulletLine(
                                                d.otherWays[index]),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      Center(
                                        child: Column(
                                          children: [
                                            Text(
                                              d.closingText,
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withOpacity(.75),
                                                fontSize: 12.5,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              d.closingNote,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight:
                                                    FontWeight.w900,
                                                color: JinnTvTheme.pink,
                                              ),
                                            ),
                                          ],
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
                                      const SizedBox(height: 24),
                                    ],
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

class SupportUsData {
  final String pageTitle;
  final String pageSubtitle;
  final String whySupportText;
  final String bankName;
  final String accountTitle;
  final String accountNumber;
  final String iban;
  final String branchName;
  final List<SupportFeature> features;
  final List<String> otherWays;
  final String closingText;
  final String closingNote;
  final String logoImage;

  const SupportUsData({
    required this.pageTitle,
    required this.pageSubtitle,
    required this.whySupportText,
    required this.bankName,
    required this.accountTitle,
    required this.accountNumber,
    required this.iban,
    required this.branchName,
    required this.features,
    required this.otherWays,
    required this.closingText,
    required this.closingNote,
    required this.logoImage,
  });

  factory SupportUsData.fromJson(Map<String, dynamic> json) {
    final rawFeatures = (json['features'] as List?) ?? const [];
    final rawOtherWays = (json['other_ways'] as List?) ?? const [];

    return SupportUsData(
      pageTitle: (json['page_title'] ?? 'Support JinnTV').toString(),
      pageSubtitle: (json['page_subtitle'] ?? '').toString(),
      whySupportText: (json['why_support_text'] ?? '').toString(),
      bankName: (json['bank_name'] ?? '').toString(),
      accountTitle: (json['account_title'] ?? '').toString(),
      accountNumber: (json['account_number'] ?? '').toString(),
      iban: (json['iban'] ?? '').toString(),
      branchName: (json['branch_name'] ?? '').toString(),
      features: rawFeatures
          .map((e) => SupportFeature.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList(),
      otherWays: rawOtherWays.map((e) => e.toString()).toList(),
      closingText: (json['closing_text'] ?? '').toString(),
      closingNote: (json['closing_note'] ?? '').toString(),
      logoImage: (json['logo_image'] ?? '').toString(),
    );
  }

  factory SupportUsData.fallback() {
    return const SupportUsData(
      pageTitle: 'Support JinnTV',
      pageSubtitle:
          'Help us continue providing quality Islamic content to the global Muslim community.',
      whySupportText:
          'Your donations help us create more high-quality Islamic content, maintain our platform, and reach more Muslims worldwide with authentic knowledge.',
      bankName: 'Meezan Bank Limited',
      accountTitle: 'ISHARA FOUNDATION',
      accountNumber: '0129-0103881491',
      iban: 'PK48 MEZN 0001 2901 0388 1491',
      branchName: 'Muhammad Ali Society Branch',
      features: [
        SupportFeature('New Videos', 'videocam_rounded'),
        SupportFeature('Global Reach', 'public_rounded'),
        SupportFeature('Free Education', 'menu_book_rounded'),
        SupportFeature('Better Quality', 'high_quality_rounded'),
      ],
      otherWays: [
        'Share our videos with family and friends',
        'Subscribe to our YouTube channel',
        'Leave positive reviews and feedback',
        'Volunteer your skills and expertise',
      ],
      closingText: 'May Allah reward you for your generosity and support.',
      closingNote: 'JazakAllah Khair',
      logoImage: '',
    );
  }
}

class SupportFeature {
  final String title;
  final String icon;

  const SupportFeature(this.title, this.icon);

  factory SupportFeature.fromJson(Map<String, dynamic> json) {
    return SupportFeature(
      (json['title'] ?? '').toString(),
      (json['icon'] ?? 'star_rounded').toString(),
    );
  }
}

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
              'Support',
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
  final String primaryCtaText;
  final VoidCallback onPrimaryCtaTap;

  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.primaryCtaText,
    required this.onPrimaryCtaTap,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: JinnTvTheme.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: JinnTvTheme.pink.withOpacity(0.22),
              blurRadius: 18,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.20),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.favorite_rounded,
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
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.88),
                      height: 1.35,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.22),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: onPrimaryCtaTap,
                      child: Text(primaryCtaText),
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
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
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
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;

  const _FeatureTile({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: JinnTvTheme.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: JinnTvTheme.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: JinnTvTheme.accentGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CopyRowModern extends StatelessWidget {
  final String label;
  final String value;
  final bool isCopied;
  final VoidCallback onCopy;
  final VoidCallback onFullScreen;

  const _CopyRowModern({
    required this.label,
    required this.value,
    required this.isCopied,
    required this.onCopy,
    required this.onFullScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.white.withOpacity(.62),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Full screen',
                onPressed: onFullScreen,
                icon: Icon(
                  Icons.open_in_full,
                  color: Colors.white.withOpacity(.72),
                ),
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

class _BulletLine extends StatelessWidget {
  final String text;
  const _BulletLine(this.text);

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
                color: Colors.white.withOpacity(.82),
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