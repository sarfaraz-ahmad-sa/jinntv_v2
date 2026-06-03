import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/jinntv_theme.dart';
import 'admin_api_screen.dart';

class AboutUsScreen extends StatefulWidget {
  const AboutUsScreen({super.key});

  @override
  State<AboutUsScreen> createState() => _AboutUsScreenState();
}

class _AboutUsScreenState extends State<AboutUsScreen>
    with WidgetsBindingObserver {
  static String get _apiUrl => apiUrl('/jinn-tv-admin/api_about_us.php');

  AboutUsData? _data;
  bool _loading = true;
  bool _refreshing = false;
  bool _isFetching = false;
  bool _leaving = false;
  String? _error;
  DateTime? _lastFetchAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAboutUs(initial: true);
  }

  @override
  void dispose() {
    _leaving = true;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final last = _lastFetchAt;
      if (last == null ||
          DateTime.now().difference(last) > const Duration(minutes: 2)) {
        _loadAboutUs(silent: true);
      }
    }
  }

  Future<void> _loadAboutUs({
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

      final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;

      if (jsonMap['success'] == true && jsonMap['data'] != null) {
        final aboutData =
            AboutUsData.fromJson(jsonMap['data'] as Map<String, dynamic>);

        if (!mounted || _leaving) return;

        _lastFetchAt = DateTime.now();

        setState(() {
          _data = aboutData;
          _error = null;
        });
      } else {
        throw Exception(jsonMap['message'] ?? 'Invalid API response');
      }
    } catch (e) {
      if (_data == null) {
        _data = AboutUsData.fallback();
      }

      if (!mounted || _leaving) return;

      setState(() {
        _error = e.toString();
      });
    } finally {
      _isFetching = false;

      if (!mounted || _leaving) return;

      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data ?? AboutUsData.fallback();

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
              top: 120,
              right: -70,
              child: IgnorePointer(
                child: Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: JinnTvTheme.pink.withOpacity(.15),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              left: 20,
              child: IgnorePointer(
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: JinnTvTheme.blue.withOpacity(.10),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _TopBar(
                    title: 'About',
                    logoUrl: data.logoImage,
                    onBack: () {
                      _leaving = true;
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        Navigator.pushReplacementNamed(context, '/');
                      }
                    },
                  ),
                  Expanded(
                    child: _loading && _data == null
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: JinnTvTheme.pink,
                            ),
                          )
                        : RefreshIndicator(
                            color: JinnTvTheme.pink,
                            onRefresh: () => _loadAboutUs(),
                            child: CustomScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    10,
                                    16,
                                    28,
                                  ),
                                  sliver: SliverList(
                                    delegate: SliverChildListDelegate([
                                      if (_error != null)
                                        Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 12),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.orange.withOpacity(0.12),
                                            borderRadius:
                                                BorderRadius.circular(14),
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
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      _HeroCard(data: data),
                                      const SizedBox(height: 18),
                                      _Section(
                                        title: 'Our Mission',
                                        child: _Paragraph(data.mission),
                                      ),
                                      const SizedBox(height: 16),
                                      _Section(
                                        title: 'Our Vision',
                                        child: _Paragraph(data.vision),
                                      ),
                                      const SizedBox(height: 16),
                                      _Section(
                                        title: 'Our Values',
                                        child: Column(
                                          children: data.values
                                              .map(
                                                (v) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                    bottom: 12,
                                                  ),
                                                  child: _InfoTile(
                                                    title: v.title,
                                                    subtitle: v.description,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      _Section(
                                        title: 'Our Team',
                                        child: _Paragraph(data.team),
                                      ),
                                      const SizedBox(height: 16),
                                      _Section(
                                        title: 'Our Stats',
                                        child: LayoutBuilder(
                                          builder: (context, c) {
                                            final cols =
                                                c.maxWidth >= 700 ? 4 : 2;
                                            return GridView.builder(
                                              shrinkWrap: true,
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              itemCount: data.stats.length,
                                              gridDelegate:
                                                  SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: cols,
                                                mainAxisSpacing: 12,
                                                crossAxisSpacing: 12,
                                                childAspectRatio:
                                                    cols == 4 ? 1.22 : 1.18,
                                              ),
                                              itemBuilder: (context, index) {
                                                return _StatCard(
                                                  item: data.stats[index],
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                      if (_refreshing)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 14),
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
                                    ]),
                                  ),
                                ),
                              ],
                            ),
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

class AboutUsData {
  final String title;
  final String subtitle;
  final String mission;
  final String vision;
  final String team;
  final String heroImage;
  final String logoImage;
  final List<ValueItem> values;
  final List<StatItem> stats;

  const AboutUsData({
    required this.title,
    required this.subtitle,
    required this.mission,
    required this.vision,
    required this.team,
    required this.heroImage,
    required this.logoImage,
    required this.values,
    required this.stats,
  });

  factory AboutUsData.fromJson(Map<String, dynamic> json) {
    final rawValues = (json['values'] as List?) ?? const [];
    final rawStats = (json['stats'] as List?) ?? const [];

    return AboutUsData(
      title: (json['title'] ?? 'JinnTV').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      mission: (json['mission'] ?? '').toString(),
      vision: (json['vision'] ?? '').toString(),
      team: (json['team'] ?? '').toString(),
      heroImage: (json['hero_image'] ?? '').toString(),
      logoImage: (json['logo_image'] ?? '').toString(),
      values: rawValues
          .map((e) => ValueItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      stats: rawStats
          .map((e) => StatItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  factory AboutUsData.fallback() {
    return const AboutUsData(
      title: 'JinnTV',
      subtitle: 'Authentic Islamic stories, series & kids content.',
      mission:
          'JinnTV is dedicated to providing high-quality Islamic content that educates, inspires, and strengthens the faith of Muslims worldwide. We believe in making authentic Islamic knowledge accessible to everyone, regardless of their location or background.',
      vision:
          'We envision a world where Islamic knowledge is easily accessible to all Muslims, helping them deepen their understanding of Islam and practice their faith with confidence and clarity. Through our platform, we aim to build a global community of learners and seekers of knowledge.',
      team:
          'JinnTV is powered by a dedicated team of Islamic scholars, content creators, and technology experts who work together to bring you the best Islamic content. Our team is committed to maintaining the highest standards of authenticity and quality.',
      heroImage: '',
      logoImage: '',
      values: [
        ValueItem(
          'Authenticity',
          'All content is verified by Islamic scholars',
        ),
        ValueItem(
          'Accessibility',
          'Making knowledge available to everyone',
        ),
        ValueItem(
          'Quality',
          'High-quality production and presentation',
        ),
        ValueItem(
          'Community',
          'Building a supportive learning community',
        ),
      ],
      stats: [
        StatItem('500+', 'Videos'),
        StatItem('100K+', 'Subscribers'),
        StatItem('50+', 'Countries'),
        StatItem('10M+', 'Views'),
      ],
    );
  }
}

class ValueItem {
  final String title;
  final String description;

  const ValueItem(this.title, this.description);

  factory ValueItem.fromJson(Map<String, dynamic> json) {
    return ValueItem(
      (json['title'] ?? '').toString(),
      (json['description'] ?? '').toString(),
    );
  }
}

class StatItem {
  final String value;
  final String label;

  const StatItem(this.value, this.label);

  factory StatItem.fromJson(Map<String, dynamic> json) {
    return StatItem(
      (json['value'] ?? '').toString(),
      (json['label'] ?? '').toString(),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final String logoUrl;
  final VoidCallback onBack;

  const _TopBar({
    required this.title,
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
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
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
  final AboutUsData data;

  const _HeroCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: JinnTvTheme.card,
          border: Border.all(color: JinnTvTheme.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _NetworkOrAssetImage(
                  imageUrl: data.heroImage,
                  fallbackAsset: 'assets/images/about-heros.png',
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(.82),
                        Colors.black.withOpacity(.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        data.subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(.88),
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: JinnTvTheme.card,
          border: Border.all(color: JinnTvTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
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
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withOpacity(.82),
        fontSize: 14,
        height: 1.7,
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String title;
  final String subtitle;

  const _InfoTile({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(.04),
        border: Border.all(color: Colors.white.withOpacity(.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: JinnTvTheme.pink,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(.78),
              fontSize: 13.2,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final StatItem item;

  const _StatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: JinnTvTheme.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: JinnTvTheme.pink.withOpacity(.18),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              item.value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkOrAssetImage extends StatelessWidget {
  final String imageUrl;
  final String fallbackAsset;

  const _NetworkOrAssetImage({
    required this.imageUrl,
    required this.fallbackAsset,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        cacheWidth: 1200,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) {
            return child;
          }
          return Container(
            color: const Color(0xFF1A2533),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (_, __, ___) => Image.asset(
          fallbackAsset,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFF1A2533),
            alignment: Alignment.center,
            child: const Icon(
              Icons.ondemand_video_rounded,
              color: Colors.white54,
              size: 42,
            ),
          ),
        ),
      );
    }

    return Image.asset(
      fallbackAsset,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFF1A2533),
        alignment: Alignment.center,
        child: const Icon(
          Icons.ondemand_video_rounded,
          color: Colors.white54,
          size: 42,
        ),
      ),
    );
  }
}