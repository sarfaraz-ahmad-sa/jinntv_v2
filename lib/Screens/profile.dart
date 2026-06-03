import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../db/db_helper.dart';
import 'login.dart';
import 'notifications_screen.dart';
import 'sql_logs_screen.dart';

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

      setState(() {
        _userId = userId;
        _user = user;
        _selectedImageFile = null;
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
        Uri.parse('https://jinntv.com/api_forApp/delete_account.php'),
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
                            colors: [Color(0xff7C3AED), Color(0xffEC4899)],
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
                colors: [Color(0xff7C3AED), Color(0xffEC4899)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xffEC4899).withOpacity(.25),
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
                color: const Color(0xffEC4899),
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
    final name = (_user?['name'] ?? '').toString();
    final email = (_user?['email'] ?? '').toString();
    final phone = (_user?['phoneno'] ?? '').toString();
    final role = (_user?['role'] ?? 'Viewer').toString();
    final status = (_user?['status'] ?? 'Active').toString();
    final joined = (_user?['user_registered'] ?? '').toString();

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
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
              child: IgnorePointer(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xff7C3AED).withOpacity(.18),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 120,
              right: -60,
              child: IgnorePointer(
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xffEC4899).withOpacity(.12),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xffEC4899),
                      ),
                    )
                  : RefreshIndicator(
                      color: const Color(0xffEC4899),
                      onRefresh: () => _loadProfile(),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: (_saving || _deletingAccount)
                                    ? null
                                    : () {
                                        _navigatingAway = true;
                                        Navigator.pop(context);
                                      },
                                icon: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Image.asset(
                                'assets/images/jinn-tv-logo.png',
                                height: 40,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'My Profile',
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: (_saving || _deletingAccount)
                                    ? null
                                    : () {
                                        setState(() {
                                          _isEditing = !_isEditing;
                                          if (!_isEditing) {
                                            _fillControllersFromUser(_user);
                                            _selectedImageFile = null;
                                          }
                                        });
                                      },
                                icon: Icon(
                                  _isEditing
                                      ? Icons.close_rounded
                                      : Icons.edit_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          RepaintBoundary(
                            child: _glassCard(
                              child: Column(
                                children: [
                                  _buildAvatar(name),
                                  const SizedBox(height: 14),
                                  Text(
                                    name.isEmpty ? 'User Name' : name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    email.isEmpty ? 'No email found' : email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(.72),
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xff7C3AED)
                                              .withOpacity(.35),
                                          const Color(0xffEC4899)
                                              .withOpacity(.35),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(.10),
                                      ),
                                    ),
                                    child: Text(
                                      '$role • $status',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          RepaintBoundary(
                            child: _glassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Account Details',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  if (_isEditing) ...[
                                    _buildField(
                                      label: 'Full Name',
                                      controller: _nameCtrl,
                                      icon: Icons.person_outline_rounded,
                                    ),
                                    _buildField(
                                      label: 'Email Address',
                                      controller: _emailCtrl,
                                      icon: Icons.mail_outline_rounded,
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                    _buildField(
                                      label: 'Phone Number',
                                      controller: _phoneCtrl,
                                      icon: Icons.call_outlined,
                                      keyboardType: TextInputType.phone,
                                    ),
                                    const SizedBox(height: 6),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed:
                                            _saving ? null : _saveProfile,
                                        style: ElevatedButton.styleFrom(
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          backgroundColor:
                                              const Color(0xffEC4899),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                        ),
                                        child: _saving
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Text(
                                                'Save Changes',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ] else ...[
                                    _infoRow(
                                      Icons.person_outline_rounded,
                                      'Full Name',
                                      name,
                                    ),
                                    _infoRow(
                                      Icons.mail_outline_rounded,
                                      'Email Address',
                                      email,
                                    ),
                                    _infoRow(
                                      Icons.phone_outlined,
                                      'Phone Number',
                                      phone,
                                    ),
                                    _infoRow(
                                      Icons.badge_outlined,
                                      'User ID',
                                      _userId ?? '',
                                    ),
                                    _infoRow(
                                      Icons.calendar_month_outlined,
                                      'Registered On',
                                      joined,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          RepaintBoundary(
                            child: _glassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'More',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _menuTile(
                                    icon: Icons.notifications_none_rounded,
                                    title: 'Notifications',
                                    subtitle: 'View app notifications',
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const NotificationsScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  if (_isAdmin)
                                    _menuTile(
                                      icon: Icons.receipt_long_outlined,
                                      title: 'App Logs',
                                      subtitle: 'See SQL and API logs',
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const SqlLogsScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                  _menuTile(
                                    icon: Icons.delete_forever_outlined,
                                    title: 'Delete Account',
                                    subtitle:
                                        'Permanently remove your account',
                                    destructive: true,
                                    onTap: _deleteAccount,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: (_saving || _deletingAccount)
                                  ? null
                                  : _logout,
                              icon: _deletingAccount
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.logout_rounded),
                              label: Text(
                                _deletingAccount ? 'Processing...' : 'Logout',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withOpacity(.16),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                backgroundColor:
                                    Colors.white.withOpacity(.04),
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