import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

import '../privacy_policy.dart';
import '../profile.dart';
import '../Login.dart';
import '../ContactUs.dart';
import '../AboutUs.dart';
import '../SearchScreen.dart';
import '../MyPlayListScreen.dart';
import '../sql_logs_screen.dart';
import '../../db/db_helper.dart';

class SocialLinkModel {
  final int id;
  final String title;
  final String url;
  final String iconKey;
  final int sortOrder;

  SocialLinkModel({
    required this.id,
    required this.title,
    required this.url,
    required this.iconKey,
    required this.sortOrder,
  });

  factory SocialLinkModel.fromJson(Map<String, dynamic> json) {
    return SocialLinkModel(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      title: json['title']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      iconKey: json['icon_key']?.toString() ?? '',
      sortOrder: json['sort_order'] is int
          ? json['sort_order']
          : int.tryParse('${json['sort_order']}') ?? 0,
    );
  }
}

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  bool _loadingSocial = true;
  List<SocialLinkModel> _socialLinks = [];
  String _userEmail = '';
  String _profileName = 'Profile';
  String _profileImage = '';
  String _cacheSizeText = '';

  bool get _isAdmin {
    return _userEmail == 'support@cartzlink.com' ||
        _userEmail == 'sarfaraz@cartzlink.com';
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSocialLinks();
    _loadCacheSize();
  }

  Future<void> _loadCacheSize() async {
    try {
      int totalBytes = 0;

      final tempDir = await getTemporaryDirectory();
      totalBytes += await _getDirectorySize(tempDir);

      final cacheDir = await getApplicationCacheDirectory();
      totalBytes += await _getDirectorySize(cacheDir);

      if (!mounted) return;

      setState(() {
        _cacheSizeText = _formatBytes(totalBytes);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cacheSizeText = '';
      });
    }
  }

  Future<int> _getDirectorySize(Directory dir) async {
    int size = 0;

    if (!await dir.exists()) return 0;

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      try {
        if (entity is File) {
          size += await entity.length();
        }
      } catch (_) {}
    }

    return size;
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';

    final kb = bytes / 1024;
    final mb = kb / 1024;
    final gb = mb / 1024;

    if (gb >= 1) {
      return '${gb.toStringAsFixed(2)} GB';
    }

    if (mb >= 1) {
      return '${mb.toStringAsFixed(1)} MB';
    }

    return '${kb.toStringAsFixed(0)} KB';
  }

  Future<void> _loadUserData() async {
    try {
      final session = await DBHelper.getSession();
      final userId = await DBHelper.getActiveUserId();
      final user = userId == null ? null : await DBHelper.fetchUser(userId);

      if (!mounted) return;

      setState(() {
        _userEmail = (session?['email'] ?? user?['email'] ?? '')
            .toString()
            .toLowerCase()
            .trim();
        _profileName = (user?['name'] ?? 'Profile').toString().trim().isEmpty
            ? 'Profile'
            : (user?['name'] ?? 'Profile').toString().trim();
        _profileImage = (user?['profile_image'] ?? '').toString().trim();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _userEmail = '';
        _profileName = 'Profile';
        _profileImage = '';
      });
    }
  }

  Future<void> _loadSocialLinks() async {
    if (!mounted) return;

    setState(() {
      _loadingSocial = true;
      _socialLinks = [];
    });

    try {
      final String? userId = await DBHelper.getActiveUserId();

      if (userId == null || userId.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _loadingSocial = false;
          _socialLinks = [];
        });
        return;
      }

      final response = await http.post(
        Uri.parse('https://jinntv.com/api_forApp/get_more_menu_social_links.php'),
        headers: {
          'Accept': 'application/json',
        },
        body: {
          'user_id': userId.trim(),
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic> &&
            decoded['success'] == true &&
            decoded['data'] is List) {
          final List items = decoded['data'] as List;

          final parsed = items
              .map((e) => SocialLinkModel.fromJson(Map<String, dynamic>.from(e)))
              .toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

          if (!mounted) return;
          setState(() {
            _socialLinks = parsed;
            _loadingSocial = false;
          });
          return;
        }
      }

      if (!mounted) return;
      setState(() {
        _socialLinks = [];
        _loadingSocial = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _socialLinks = [];
        _loadingSocial = false;
      });
    }
  }

  IconData _getSocialIcon(String key) {
    switch (key.toLowerCase()) {
      case 'facebook':
        return Icons.facebook;
      case 'instagram':
        return Icons.camera_alt_outlined;
      case 'youtube':
        return Icons.play_circle_outline_rounded;
      case 'tiktok':
        return Icons.music_note_rounded;
      case 'linkedin':
        return Icons.business_center_outlined;
      case 'twitter':
      case 'x':
        return Icons.alternate_email_rounded;
      default:
        return Icons.public;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff070B1A),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xff070B1A),
                  Color(0xff120E2A),
                  Color(0xff1D1033),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            top: -80,
            left: -50,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xff7C3AED).withOpacity(.22),
              ),
            ),
          ),
          Positioned(
            top: 120,
            right: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xffEC4899).withOpacity(.16),
              ),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await _loadUserData();
                await _loadSocialLinks();
                await _loadCacheSize();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
                children: [
                  _header(context),
                  const SizedBox(height: 18),

                  _profileCard(context),
                  const SizedBox(height: 16),

                  _sectionTitle("General"),
                  _sectionBox(
                    context,
                    children: [
                      _moreTile(
                        context,
                        icon: Icons.search_rounded,
                        title: "Search",
                        subtitle: "Find videos quickly",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SearchScreen(),
                          ),
                        ),
                      ),
                      _divider(),
                      _moreTile(
                        context,
                        icon: Icons.playlist_play_rounded,
                        title: "My PlayList",
                        subtitle: "Saved videos",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MyPlayListScreen(),
                          ),
                        ),
                      ),
                      if (_isAdmin) ...[
                        _divider(),
                        _moreTile(
                          context,
                          icon: Icons.receipt_long_outlined,
                          title: 'App Logs',
                          subtitle: 'See SQL and API logs',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SqlLogsScreen(),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),
                  _sectionTitle("Contact"),
                  _sectionBox(
                    context,
                    children: [
                      _moreTile(
                        context,
                        icon: Icons.call_outlined,
                        title: "Contact Us",
                        subtitle: "Get in touch",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ContactUsScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  _sectionTitle("Legal"),
                  _sectionBox(
                    context,
                    children: [
                      _moreTile(
                        context,
                        icon: Icons.info_outline_rounded,
                        title: "About Us",
                        subtitle: "Learn about JinnTV",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AboutUsScreen(),
                          ),
                        ),
                      ),
                      _divider(),
                      _moreTile(
                        context,
                        icon: Icons.privacy_tip_outlined,
                        title: "Privacy Policy",
                        subtitle: "Read our policy",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PrivacyPolicyScreen(),
                          ),
                        ),
                      ),
                      _divider(),
                      _moreTile(
                        context,
                        icon: Icons.privacy_tip_outlined,
                        title: "App Privacy Policy",
                        subtitle: "Read our app policy",
                        onTap: () async {
                          final uri = Uri.parse(
                            "https://www.jinntv.com/app-privacy-policy",
                          );
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  _sectionTitle("Storage"),
                  _sectionBox(
                    context,
                    children: [
                      _moreTile(
                        context,
                        icon: Icons.cleaning_services_outlined,
                        title: "Clear Cache",
                        subtitle: _cacheSizeText.isEmpty
                            ? "Clear temporary app cache data"
                            : "Temporary data: $_cacheSizeText",
                        onTap: () async {
                          await _confirmClearCache();
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  _sectionTitle("Social"),
                  _sectionBox(
                    context,
                    children: _buildSocialSection(),
                  ),

                  const SizedBox(height: 16),
                  _sectionBox(
                    context,
                    children: [
                      _moreTile(
                        context,
                        icon: Icons.logout_rounded,
                        title: "Logout",
                        subtitle: "Sign out from this device",
                        destructive: true,
                        onTap: () => _confirmLogout(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),
                  const Center(
                    child: Text(
                      "JinnTV v1.0.0 • © 2026",
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
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

  List<Widget> _buildSocialSection() {
    if (_loadingSocial) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ];
    }

    if (_socialLinks.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(
            children: [
              const Text(
                'No social links available',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _loadSocialLinks,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ];
    }

    final List<Widget> widgets = [];

    for (int i = 0; i < _socialLinks.length; i++) {
      final item = _socialLinks[i];
      widgets.add(_social(_getSocialIcon(item.iconKey), item.title, item.url));
      if (i != _socialLinks.length - 1) {
        widgets.add(_divider());
      }
    }

    return widgets;
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            "More",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _profileCard(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.22),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xff7C3AED), Color(0xffEC4899)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: ClipOval(
                  child: _profileImage.isNotEmpty
                      ? Image.network(
                          _profileImage,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                            );
                          },
                        )
                      : const Icon(Icons.person_rounded, color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _profileName.isEmpty ? "Profile" : _profileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Manage your account & preferences",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withOpacity(0.10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                  if (!mounted) return;
                  await _loadUserData();
                },
                child: const Text(
                  "Open",
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w900,
          fontSize: 13,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _sectionBox(BuildContext context, {required List<Widget> children}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.09)),
          ),
          child: Column(children: children),
        ),
      ),
    );
  }

  Widget _divider() =>
      Divider(height: 1, color: Colors.white.withOpacity(0.08));

  Widget _moreTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final titleColor = destructive ? Colors.redAccent : Colors.white;
    final subColor =
        destructive ? Colors.redAccent.withOpacity(0.75) : Colors.white54;
    final iconColor = destructive ? Colors.redAccent : Colors.white70;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.06),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: subColor, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
    );
  }

  Widget _social(IconData icon, String title, String url) {
    return ListTile(
      onTap: () => _openUrl(url),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.06),
        ),
        child: Icon(icon, color: Colors.white70, size: 18),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _confirmClearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0B0F14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text(
          'Clear Cache?',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          _cacheSizeText.isEmpty || _cacheSizeText == '0 MB'
              ? 'This will clear temporary app cache data. Your login, profile and playlist will not be deleted.'
              : 'This will clear about $_cacheSizeText temporary app cache data. Your login, profile and playlist will not be deleted.',
          style: const TextStyle(
            color: Colors.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _clearCache();
    }
  }

  Future<void> _clearCache() async {
    try {
      await DefaultCacheManager().emptyCache();

      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      await DBHelper.clearAppCache();

      if (!mounted) return;

      setState(() {
        _cacheSizeText = '0 MB';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('App cache cleared successfully'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear cache: $e'),
        ),
      );
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (_) => const _LogoutDialog(),
    );

    if (confirm != true) return;

    try {
      await DBHelper.logout();
    } catch (_) {}

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }
}

class _LogoutDialog extends StatelessWidget {
  const _LogoutDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 26),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0F14).withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.logout, color: Colors.redAccent, size: 34),
                const SizedBox(height: 12),
                const Text(
                  "Logout?",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "You'll need to sign in again to access your account.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          "Logout",
                          style: TextStyle(fontWeight: FontWeight.w900),
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
    );
  }
}