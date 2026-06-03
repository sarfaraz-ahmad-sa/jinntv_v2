import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../db/db_helper.dart';
import 'login.dart';
import 'notifications_screen.dart';
import 'sql_logs_screen.dart';
import 'admin_api_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _isEditing = false;
  bool _navigatingAway = false;
  bool _deletingAccount = false;

  String? _userId;
  Map<String, dynamic>? _user;

  // Stats
  int _watchCount    = 0;
  int _playlistCount = 0;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  File? _selectedImageFile;
  String? _remoteProfileImage;

  bool get _isAdmin {
    final email = (_user?['email'] ?? '').toString().toLowerCase().trim();
    return email == 'support@cartzlink.com' ||
        email == 'sarfaraz@cartzlink.com';
  }

  @override
  void initState() {
    super.initState();
    _loadProfile(initial: true);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _fillControllersFromUser(Map<String, dynamic>? user) {
    final name = (user?['name'] ?? '').toString();
    final email = (user?['email'] ?? '').toString();
    final phone = (user?['phoneno'] ?? '').toString();
    final profileImage = (user?['profile_image'] ?? '').toString();

    _nameCtrl.value = TextEditingValue(
      text: name,
      selection: TextSelection.collapsed(offset: name.length),
    );
    _emailCtrl.value = TextEditingValue(
      text: email,
      selection: TextSelection.collapsed(offset: email.length),
    );
    _phoneCtrl.value = TextEditingValue(
      text: phone,
      selection: TextSelection.collapsed(offset: phone.length),
    );
    _remoteProfileImage = profileImage.isEmpty ? null : profileImage;
  }

  Future<void> _pickProfileImage() async {
    if (!_isEditing || _saving || _deletingAccount) return;

    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (picked == null || !mounted) return;

      setState(() {
        _selectedImageFile = File(picked.path);
      });
    } catch (e) {
      await DBHelper.addLog("Profile image pick error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to pick image: $e')),
      );
    }
  }

  Future<void> _loadProfile({bool initial = false}) async {
    if (!mounted || _saving || _navigatingAway || _deletingAccount) return;

    if (initial) {
      setState(() => _loading = true);
    }

    try {
      final userId = await DBHelper.getActiveUserId();

      if (!mounted || _navigatingAway) return;

      if (userId == null || userId.trim().isEmpty) {
        _goToLogin();
        return;
      }

      final user = await DBHelper.fetchUser(userId);

      if (!mounted || _navigatingAway) return;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load profile')),
        );
        setState(() => _loading = false);
        return;
      }

      // Load stats
      final watchHistory  = await DBHelper.getContinueWatching(userId);
      final playlist      = await DBHelper.getPlaylist(userId);

      setState(() {
        _userId        = userId;
        _user          = user;
        _selectedImageFile = null;
        _watchCount    = watchHistory.length;
        _playlistCount = playlist.length;
      });

      _fillControllersFromUser(user);
    } catch (e) {
      await DBHelper.addLog("Profile load error: $e");
      if (mounted && !_navigatingAway) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
      }
    } finally {
      if (mounted && !_navigatingAway) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_userId == null || _saving || _navigatingAway || _deletingAccount) {
      return;
    }

    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      await DBHelper.updateUserProfile(
        userId: _userId!,
        name: name,
        phone: phone,
        email: email,
        imageFile: _selectedImageFile,
      );

      final refreshed = await DBHelper.fetchUser(_userId!);

      if (!mounted || _navigatingAway) return;

      setState(() {
        _user = refreshed ??
            {
              'name': name,
              'email': email,
              'phoneno': phone,
              'profile_image': _remoteProfileImage ?? '',
              'user_registered': (_user?['user_registered'] ?? '').toString(),
              'role': (_user?['role'] ?? 'customer').toString(),
              'status': (_user?['status'] ?? 'active').toString(),
            };
        _isEditing = false;
        _selectedImageFile = null;
      });

      _fillControllersFromUser(_user);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      await DBHelper.addLog("Profile update error: $e");
      if (!mounted || _navigatingAway) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      if (mounted && !_navigatingAway) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteAccount() async {
    if (_userId == null || _saving || _deletingAccount || _navigatingAway) {
      return;
    }

    final email = (_user?['email'] ?? '').toString();

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: !_deletingAccount,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to permanently delete your account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    FocusScope.of(context).unfocus();
    setState(() => _deletingAccount = true);

    try {
      final res = await http.post(
        Uri.parse(apiUrl('/api_forApp/delete_account.php')),
        body: {
          'user_id': _userId!,
          'email': email,
          'reason': 'User requested account deletion from app',
        },
      );

      final dynamic data = jsonDecode(res.body);

      if (data is Map && data['status'] == 'success') {
        await DBHelper.logout();

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      } else {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (data is Map ? data['message'] : null)?.toString() ??
                  'Delete failed',
            ),
          ),
        );
      }
    } catch (e) {
      await DBHelper.addLog("Delete account error: $e");
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete account')),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingAccount = false);
      }
    }
  }

  Future<void> _logout() async {
    if (_saving || _deletingAccount) return;
    _navigatingAway = true;
    await DBHelper.logout();
    if (!mounted) return;
    _goToLogin();
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  String _initials(String text) {
    final parts = text.trim().split(' ').where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Future<bool> _onWillPop() async {
    if (_saving || _deletingAccount) return false;
    _navigatingAway = true;
    return true;
  }

  Widget _glassCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withOpacity(0.07),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        enabled: !_saving && !_deletingAccount,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(.7)),
          prefixIcon: Icon(icon, color: Colors.white70),
          filled: true,
          fillColor: Colors.white.withOpacity(.06),
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
            borderSide: const BorderSide(color: Color(0xffD946EF), width: 1.2),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.07)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(.08),
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
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? '—' : value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final Color titleColor = destructive ? Colors.redAccent : Colors.white;
    final Color subtitleColor = destructive
        ? Colors.redAccent.withOpacity(.75)
        : Colors.white.withOpacity(.65);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: (_saving || _deletingAccount) ? null : onTap,
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white.withOpacity(.05),
              border: Border.all(color: Colors.white.withOpacity(.07)),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: destructive
                        ? const LinearGradient(
                            colors: [Color(0xffEF4444), Color(0xffDC2626)],
                          )
                        : const LinearGradient(
                            colors: [Color(0xFF0077A8), Color(0xFF00A8E1)],
                          ),
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
                          color: titleColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white70),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String name) {
    final hasLocal = _selectedImageFile != null;
    final hasRemote = (_remoteProfileImage ?? '').trim().isNotEmpty;

    return GestureDetector(
      onTap: _isEditing ? _pickProfileImage : null,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 105,
            height: 105,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF0077A8), Color(0xFF00A8E1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00A8E1).withOpacity(.25),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipOval(
              child: hasLocal
                  ? Image.file(_selectedImageFile!, fit: BoxFit.cover)
                  : hasRemote
                      ? Image.network(
                          _remoteProfileImage!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              _initials(name.isEmpty ? 'User' : name),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            _initials(name.isEmpty ? 'User' : name),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
            ),
          ),
          if (_isEditing)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00A8E1),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name   = (_user?['name']             ?? '').toString();
    final email  = (_user?['email']            ?? '').toString();
    final phone  = (_user?['phoneno']          ?? '').toString();
    final role   = (_user?['role']             ?? 'Viewer').toString();
    final status = (_user?['status']           ?? 'Active').toString();
    final joined = (_user?['user_registered']  ?? '').toString();

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F171E),
        body: Stack(
          children: [
            // Background gradient
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F171E), Color(0xFF1A242F), Color(0xFF1F2D3A)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SizedBox.expand(),
            ),
            // Decorative blobs
            Positioned(top: -80, left: -50,
              child: IgnorePointer(child: Container(width: 220, height: 220,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: const Color(0xFF0077A8).withOpacity(.18))))),
            Positioned(top: 130, right: -60,
              child: IgnorePointer(child: Container(width: 170, height: 170,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: const Color(0xFF00A8E1).withOpacity(.10))))),

            SafeArea(
              child: _loading
                  ? _buildLoadingSkeleton()
                  : RefreshIndicator(
                      color: const Color(0xFF00A8E1),
                      onRefresh: () => _loadProfile(),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
                        children: [
                          // ── Top bar ────────────────────────────────────
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: (_saving || _deletingAccount) ? null
                                      : () { _navigatingAway = true; Navigator.pop(context); },
                                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                      color: Colors.white, size: 20),
                                ),
                                const Expanded(
                                  child: Text('My Profile',
                                    style: TextStyle(color: Colors.white,
                                        fontWeight: FontWeight.w900, fontSize: 20)),
                                ),
                                IconButton(
                                  onPressed: (_saving || _deletingAccount) ? null
                                      : () => setState(() {
                                        _isEditing = !_isEditing;
                                        if (!_isEditing) {
                                          _fillControllersFromUser(_user);
                                          _selectedImageFile = null;
                                        }
                                      }),
                                  icon: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: Icon(
                                      _isEditing ? Icons.close_rounded : Icons.edit_rounded,
                                      key: ValueKey(_isEditing),
                                      color: _isEditing ? Colors.redAccent : const Color(0xFF00A8E1),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ── Hero section ───────────────────────────────
                          Container(
                            margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF162436), Color(0xFF1A2B3C)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white.withOpacity(.08)),
                            ),
                            child: Column(
                              children: [
                                // Avatar
                                _buildAvatar(name),
                                const SizedBox(height: 16),
                                // Name
                                Text(
                                  name.isEmpty ? 'User Name' : name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                // Email
                                Text(
                                  email.isEmpty ? '—' : email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(.55),
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                // Role badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [
                                      const Color(0xFF0077A8).withOpacity(.3),
                                      const Color(0xFF00A8E1).withOpacity(.3),
                                    ]),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                        color: const Color(0xFF00A8E1).withOpacity(.3)),
                                  ),
                                  child: Text(
                                    '$role • $status',
                                    style: const TextStyle(
                                      color: Color(0xFF5BC8F5),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 22),
                                // Stats row
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(.2),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      _statItem('$_watchCount', 'Watching'),
                                      _statDivider(),
                                      _statItem('$_playlistCount', 'My List'),
                                      _statDivider(),
                                      _statItem(_userId ?? '—', 'User ID'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),
                          _sectionLabel('ACCOUNT DETAILS'),

                          // ── Account Details ────────────────────────────
                          _premiumCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_isEditing) ...[
                                  _buildField(label: 'Full Name',
                                      controller: _nameCtrl,
                                      icon: Icons.person_outline_rounded),
                                  _buildField(label: 'Email Address',
                                      controller: _emailCtrl,
                                      icon: Icons.mail_outline_rounded,
                                      keyboardType: TextInputType.emailAddress),
                                  _buildField(label: 'Phone Number',
                                      controller: _phoneCtrl,
                                      icon: Icons.call_outlined,
                                      keyboardType: TextInputType.phone),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: _saving ? null : _saveProfile,
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF0077A8), Color(0xFF00A8E1)],
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [BoxShadow(
                                          color: const Color(0xFF00A8E1).withOpacity(.3),
                                          blurRadius: 12, offset: const Offset(0, 4))],
                                      ),
                                      child: Center(
                                        child: _saving
                                            ? const SizedBox(width: 20, height: 20,
                                                child: CircularProgressIndicator(
                                                    strokeWidth: 2, color: Colors.white))
                                            : const Text('Save Changes',
                                                style: TextStyle(color: Colors.white,
                                                    fontSize: 15, fontWeight: FontWeight.w800)),
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  _premiumInfoRow(Icons.person_outline_rounded,   'Full Name',     name),
                                  _premiumInfoRow(Icons.mail_outline_rounded,     'Email',         email),
                                  _premiumInfoRow(Icons.phone_outlined,           'Phone',         phone),
                                  _premiumInfoRow(Icons.badge_outlined,           'User ID',       _userId ?? ''),
                                  _premiumInfoRow(Icons.calendar_month_outlined,  'Registered',    joined, last: true),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),
                          _sectionLabel('SETTINGS'),

                          // ── Actions ────────────────────────────────────
                          _premiumCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                _premiumActionTile(
                                  icon: Icons.notifications_none_rounded,
                                  iconBg: const Color(0xFF0077A8),
                                  title: 'Notifications',
                                  subtitle: 'View app notifications',
                                  onTap: () => Navigator.push(context,
                                      MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                                ),
                                _tileDivider(),
                                if (_isAdmin) ...[
                                  _premiumActionTile(
                                    icon: Icons.receipt_long_outlined,
                                    iconBg: const Color(0xFF1F5F8A),
                                    title: 'App Logs',
                                    subtitle: 'SQL and API debug logs',
                                    onTap: () => Navigator.push(context,
                                        MaterialPageRoute(builder: (_) => const SqlLogsScreen())),
                                  ),
                                  _tileDivider(),
                                ],
                                _premiumActionTile(
                                  icon: Icons.delete_forever_rounded,
                                  iconBg: Colors.redAccent.shade700,
                                  title: 'Delete Account',
                                  subtitle: 'Permanently remove your account',
                                  destructive: true,
                                  onTap: _deleteAccount,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── Logout ─────────────────────────────────────
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: GestureDetector(
                              onTap: (_saving || _deletingAccount) ? null : _logout,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.redAccent.withOpacity(.3)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _deletingAccount
                                        ? const SizedBox(width: 18, height: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2, color: Colors.redAccent))
                                        : const Icon(Icons.logout_rounded,
                                            color: Colors.redAccent, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      _deletingAccount ? 'Processing...' : 'Logout',
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
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

  // ── Premium widget helpers ─────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 0, 16, 8),
    child: Text(text, style: const TextStyle(
      color: Colors.white38, fontWeight: FontWeight.w800,
      fontSize: 11, letterSpacing: 1.0)),
  );

  Widget _premiumCard({required Widget child, EdgeInsets? padding}) =>
    Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF162030),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(.07)),
      ),
      child: child,
    );

  Widget _statItem(String val, String label) => Expanded(
    child: Column(children: [
      Text(val, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.w900, fontSize: 18)),
      const SizedBox(height: 3),
      Text(label, style: TextStyle(color: Colors.white.withOpacity(.45),
          fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _statDivider() => Container(
    width: 1, height: 32,
    color: Colors.white.withOpacity(.08),
  );

  Widget _tileDivider() => Divider(
    height: 1, indent: 68, endIndent: 0,
    color: Colors.white.withOpacity(.06),
  );

  Widget _premiumInfoRow(IconData icon, String label, String value,
      {bool last = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00A8E1).withOpacity(.12),
                ),
                child: Icon(icon, color: const Color(0xFF00A8E1), size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(
                        color: Colors.white.withOpacity(.45),
                        fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(value.isEmpty ? '—' : value,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w700, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!last) Divider(height: 1, color: Colors.white.withOpacity(.05)),
      ],
    );
  }

  Widget _premiumActionTile({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    return InkWell(
      onTap: (_saving || _deletingAccount) ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: iconBg.withOpacity(.85)),
              child: Icon(icon, color: Colors.white, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(
                      color: destructive ? Colors.redAccent : Colors.white,
                      fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(
                      color: Colors.white.withOpacity(.4), fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.white.withOpacity(.2), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 10),
        _skelBox(40, radius: 20),
        const SizedBox(height: 24),
        _skelBox(280, radius: 24),
        const SizedBox(height: 20),
        _skelBox(20, radius: 4, width: 120),
        const SizedBox(height: 10),
        _skelBox(200, radius: 20),
        const SizedBox(height: 20),
        _skelBox(20, radius: 4, width: 100),
        const SizedBox(height: 10),
        _skelBox(180, radius: 20),
      ],
    );
  }

  Widget _skelBox(double h, {double? width, double radius = 8}) =>
    Container(
      width: width ?? double.infinity,
      height: h,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
}