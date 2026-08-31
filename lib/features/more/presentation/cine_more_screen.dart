import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/config/app_config.dart';
import '../../auth/presentation/login_screen.dart';

class CineMoreScreen extends StatefulWidget {
  const CineMoreScreen({super.key});

  @override
  State<CineMoreScreen> createState() => _CineMoreScreenState();
}

class _CineMoreScreenState extends State<CineMoreScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((p) {
      if (mounted) setState(() => _version = '${p.version}+${p.buildNumber}');
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const CineLoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: const Color(0xFF08090C),
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: const Color(0xFF151922), borderRadius: BorderRadius.circular(18)),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFE50914),
                  backgroundImage: (user?.photoURL ?? '').isNotEmpty ? NetworkImage(user!.photoURL!) : null,
                  child: (user?.photoURL ?? '').isEmpty ? const Icon(Icons.person_rounded, color: Colors.white) : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((user?.displayName ?? '').trim().isEmpty ? 'CineNexa Viewer' : user!.displayName!, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(user?.email ?? 'Signed in with Firebase', style: const TextStyle(color: Colors.white54, fontSize: 12.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _tile(Icons.info_outline_rounded, 'About CineNexa', 'Movies, TV series, trailers and legal watch availability', () => _showAbout(context)),
          _tile(Icons.security_rounded, 'Privacy', 'Firebase authentication and your saved list', () => _showPrivacy(context)),
          _tile(Icons.cloud_outlined, 'Content API setup', AppConfig.usesTmdbProxy ? 'Secure Cloudflare proxy enabled' : AppConfig.tmdbAccessToken.isNotEmpty ? 'Direct TMDB development token enabled' : 'TMDB is not configured yet', () => _showApi(context)),
          const Divider(height: 30),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: const Text('Sign out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
            onTap: _logout,
          ),
          const SizedBox(height: 28),
          Text('CineNexa ${_version.isEmpty ? '' : 'v$_version'} • © 2026', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white30, fontSize: 11)),
          const SizedBox(height: 7),
          const Text('This product uses the TMDB API but is not endorsed or certified by TMDB.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white24, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String title, String subtitle, VoidCallback tap) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        leading: Icon(icon, color: Colors.white70),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white30),
        onTap: tap,
      );

  void _showAbout(BuildContext context) => _sheet(
        context,
        'About CineNexa',
        'CineNexa is a modern entertainment discovery experience for browsing movies, TV series, seasons, episodes, trailers, cast information, personalized recommendations and country-based watch-provider availability. Full copyrighted movies are not hosted by CineNexa unless you later connect content you own or license.',
      );

  void _showPrivacy(BuildContext context) => _sheet(
        context,
        'Privacy',
        'Account authentication is handled by Firebase. Your saved movies, saved TV series, recent viewing activity and personalization preferences use local-first storage and, where enabled, best-effort Firestore synchronization under your Firebase user account. CineNexa no longer sends login credentials to the legacy PHP API.',
      );

  void _showApi(BuildContext context) => _sheet(
        context,
        'Content API',
        'Production: deploy the included cloudflare-worker folder and start Flutter with --dart-define=TMDB_PROXY_URL=https://your-worker.workers.dev. Development fallback: --dart-define=TMDB_ACCESS_TOKEN=YOUR_TMDB_READ_TOKEN.',
      );

  void _sheet(BuildContext context, String title, String body) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151922),
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Text(body, style: const TextStyle(color: Colors.white70, height: 1.55)),
          ],
        ),
      ),
    );
  }
}
