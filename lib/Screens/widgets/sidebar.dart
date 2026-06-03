import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../db/db_helper.dart';

class AppSidebar extends StatefulWidget {
  final Function(String route) onNavigate;
  final VoidCallback onLogout;

  const AppSidebar({
    super.key,
    required this.onNavigate,
    required this.onLogout,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slide;

  Map<String, dynamic>? user;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slide = Tween<Offset>(
      begin: const Offset(-1, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
    loadUser();
  }

  Future<void> loadUser() async {
    final fetchedUser = await DBHelper.fetchUser('3559');
    if (!mounted) return;
    setState(() {
      user = fetchedUser;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
      child: SafeArea(
        child: SlideTransition(
          position: _slide,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/jinn-tv-logo.png',
                      height: 40,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
              ),

              const Divider(color: Colors.white12),

              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.purple,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: Text(
                  user?['display_name']?.toString() ?? '',
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  user?['user_email']?.toString() ?? '',
                  style: const TextStyle(color: Colors.white60),
                ),
                onTap: () => widget.onNavigate('profile'),
              ),

              const Divider(color: Colors.white12),

              _item(Icons.home, 'Home', () => Navigator.pop(context)),
              _item(Icons.search, 'Search', () {}),
              _item(Icons.info_outline, 'About Us',
                  () => widget.onNavigate('about')),
              _item(Icons.email, 'Contact Us',
                  () => widget.onNavigate('contact')),
              _item(Icons.lock, 'Logs', () => widget.onNavigate('logs')),
              _item(Icons.privacy_tip, 'Privacy Policy',
                  () => widget.onNavigate('privacy')),

              const Divider(color: Colors.white12),

              _social(Icons.facebook, 'Facebook',
                  'https://www.facebook.com/jinntvofficial'),
              _social(Icons.camera_alt_outlined, 'Instagram',
                  'https://www.instagram.com/jinntvofficial'),
              _social(Icons.play_circle, 'YouTube',
                  'https://youtube.com/@jinntvofficial'),
              _social(Icons.music_note, 'TikTok',
                  'https://www.tiktok.com/@jinntv1'),
              _social(Icons.business, 'LinkedIn',
                  'https://www.linkedin.com/company/jinn-tv/'),

              const Divider(color: Colors.white12),

              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: widget.onLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white70),
      ),
      onTap: onTap,
    );
  }

  Widget _social(IconData icon, String title, String url) {
    return ListTile(
      leading: Icon(icon, color: Colors.white54),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white54),
      ),
      onTap: () async {
        final uri = Uri.parse(url);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
    );
  }
}