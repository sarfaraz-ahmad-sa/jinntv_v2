import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────
// Key used to persist the custom base URL
// ─────────────────────────────────────────────
const String kAdminBaseUrlKey = 'admin_base_url';
const String kDefaultBaseUrl  = 'https://www.jinntv.com';

// ─────────────────────────────────────────────
// Runtime cache — loaded once in main() before
// runApp. All screens read this synchronously.
// ─────────────────────────────────────────────
String _cachedBaseUrl = kDefaultBaseUrl;

/// Call this ONCE in main() before runApp.
Future<void> initAdminBaseUrl() async {
  _cachedBaseUrl = await getAdminBaseUrl();
}

/// Synchronous getter — use anywhere after init.
String get adminBaseUrl => _cachedBaseUrl;

/// Build a full API URL from a relative path.
/// e.g. apiUrl('/api_forApp/login.php')
String apiUrl(String path) {
  final b = _cachedBaseUrl.endsWith('/')
      ? _cachedBaseUrl.substring(0, _cachedBaseUrl.length - 1)
      : _cachedBaseUrl;
  final p = path.startsWith('/') ? path : '/$path';
  return '$b$p';
}

// ─────────────────────────────────────────────
// All known API endpoints in the app
// ─────────────────────────────────────────────
const List<_ApiEndpoint> _kEndpoints = [
  _ApiEndpoint(
    category: 'Home',
    path: '/api_forApp/home.php',
    method: 'GET',
    desc: 'Hero slider items',
  ),
  _ApiEndpoint(
    category: 'Home',
    path: '/api_forApp/home_sections.php',
    method: 'GET',
    desc: 'Home sections + ads',
  ),
  _ApiEndpoint(
    category: 'Catalog',
    path: '/api_forApp/catalog.php',
    method: 'GET',
    desc: 'Categories & video list',
  ),
  _ApiEndpoint(
    category: 'More',
    path: '/api_forApp/get_more_menu_social_links.php',
    method: 'POST',
    desc: 'Social links (requires user_id)',
  ),
  _ApiEndpoint(
    category: 'Auth',
    path: '/api_forApp/login.php',
    method: 'POST',
    desc: 'User login',
  ),
  _ApiEndpoint(
    category: 'Auth',
    path: '/api_forApp/signup.php',
    method: 'POST',
    desc: 'User registration',
  ),
  _ApiEndpoint(
    category: 'Auth',
    path: '/api_forApp/forgot_password.php',
    method: 'POST',
    desc: 'Forgot password',
  ),
  _ApiEndpoint(
    category: 'Notifications',
    path: '/api_forApp/notifications.php',
    method: 'POST',
    desc: 'Push notifications list',
  ),
];

class _ApiEndpoint {
  final String category;
  final String path;
  final String method;
  final String desc;
  const _ApiEndpoint({
    required this.category,
    required this.path,
    required this.method,
    required this.desc,
  });
}

// ─────────────────────────────────────────────
// Helper — read saved base URL
// ─────────────────────────────────────────────
Future<String> getAdminBaseUrl() async {
  final sp = await SharedPreferences.getInstance();
  return sp.getString(kAdminBaseUrlKey) ?? kDefaultBaseUrl;
}

// ─────────────────────────────────────────────
// Admin API Screen
// ─────────────────────────────────────────────
class AdminApiScreen extends StatefulWidget {
  const AdminApiScreen({super.key});

  @override
  State<AdminApiScreen> createState() => _AdminApiScreenState();
}

class _AdminApiScreenState extends State<AdminApiScreen> {
  static const _bg       = Color(0xff070B1A);
  static const _purple   = Color(0xff7C3AED);
  static const _pink     = Color(0xffEC4899);
  static const _card     = Color(0x0DFFFFFF);
  static const _border   = Color(0x17FFFFFF);

  String _savedUrl = kDefaultBaseUrl;
  bool   _editing  = false;
  bool   _saving   = false;
  bool   _testing  = false;
  String _testResult = '';
  Color  _testColor  = Colors.white54;

  late TextEditingController _urlCtrl;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController();
    _loadSaved();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final url = await getAdminBaseUrl();
    if (!mounted) return;
    setState(() {
      _savedUrl = url;
      _urlCtrl.text = url;
    });
  }

  Future<void> _saveUrl() async {
    final raw = _urlCtrl.text.trim();
    if (raw.isEmpty) return;

    // basic validation
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) {
      _showSnack('Invalid URL — must start with https://', error: true);
      return;
    }

    setState(() => _saving = true);

    final sp = await SharedPreferences.getInstance();
    await sp.setString(kAdminBaseUrlKey, raw);

    if (!mounted) return;
    setState(() {
      _savedUrl = raw;
      _editing  = false;
      _saving   = false;
    });
    _showSnack('Base URL saved. Restart app to apply.');
  }

  Future<void> _resetDefault() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(kAdminBaseUrlKey);
    if (!mounted) return;
    setState(() {
      _savedUrl = kDefaultBaseUrl;
      _urlCtrl.text = kDefaultBaseUrl;
      _editing = false;
    });
    _showSnack('Reset to default URL.');
  }

  Future<void> _testConnection() async {
    if (_testing) return;
    setState(() {
      _testing    = true;
      _testResult = 'Testing...';
      _testColor  = Colors.white54;
    });

    final url = _savedUrl.endsWith('/') ? _savedUrl : '$_savedUrl/';

    try {
      final stopwatch = Stopwatch()..start();
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      stopwatch.stop();

      if (!mounted) return;
      setState(() {
        _testResult = '✓ ${res.statusCode} — ${stopwatch.elapsedMilliseconds} ms';
        _testColor  = Colors.greenAccent;
        _testing    = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testResult = '✗ ${e.toString().split('\n').first}';
        _testColor  = Colors.redAccent;
        _testing    = false;
      });
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.redAccent : const Color(0xFF1E293B),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnack('Copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    // Group endpoints by category
    final grouped = <String, List<_ApiEndpoint>>{};
    for (final ep in _kEndpoints) {
      grouped.putIfAbsent(ep.category, () => []).add(ep);
    }

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xff070B1A), Color(0xff120E2A), Color(0xff1D1033)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // decorative blobs
          Positioned(
            top: -60, left: -40,
            child: _blob(200, _purple, 0.18),
          ),
          Positioned(
            top: 140, right: -50,
            child: _blob(160, _pink, 0.14),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              children: [
                _header(),
                const SizedBox(height: 22),

                // ── BASE URL CARD ──────────────────────────
                _sectionLabel('BASE URL'),
                _glassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _iconBadge(Icons.link_rounded, _purple),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'API Base URL',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (!_editing)
                            _chipBtn(
                              label: 'Edit',
                              icon: Icons.edit_rounded,
                              onTap: () => setState(() => _editing = true),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!_editing) ...[
                        GestureDetector(
                          onLongPress: () => _copyToClipboard(_savedUrl),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _border),
                            ),
                            child: Text(
                              _savedUrl,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        if (_savedUrl != kDefaultBaseUrl)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    color: Colors.amber, size: 14),
                                const SizedBox(width: 6),
                                const Text(
                                  'Custom URL active — not default',
                                  style: TextStyle(
                                      color: Colors.amber, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                      ] else ...[
                        TextField(
                          controller: _urlCtrl,
                          autofocus: true,
                          style: const TextStyle(
                              color: Colors.white, fontFamily: 'monospace'),
                          decoration: InputDecoration(
                            hintText: 'https://www.jinntv.com',
                            hintStyle:
                                TextStyle(color: Colors.white.withOpacity(0.3)),
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Color(0xff7C3AED), width: 1.5),
                            ),
                            prefixIcon: const Icon(Icons.link_rounded,
                                color: Colors.white38),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _gradientBtn(
                                label: _saving ? 'Saving...' : 'Save',
                                icon: Icons.check_rounded,
                                onTap: _saving ? null : _saveUrl,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _outlineBtn(
                                label: 'Reset Default',
                                icon: Icons.restart_alt_rounded,
                                onTap: _resetDefault,
                              ),
                            ),
                            const SizedBox(width: 10),
                            _outlineIconBtn(
                              icon: Icons.close_rounded,
                              onTap: () => setState(() {
                                _editing = false;
                                _urlCtrl.text = _savedUrl;
                              }),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── CONNECTION TEST ────────────────────────
                _sectionLabel('CONNECTION TEST'),
                _glassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _iconBadge(Icons.wifi_rounded,
                              _testResult.startsWith('✓')
                                  ? Colors.greenAccent
                                  : _testResult.startsWith('✗')
                                      ? Colors.redAccent
                                      : Colors.white38),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Test Connection',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15),
                            ),
                          ),
                          _chipBtn(
                            label: _testing ? 'Testing...' : 'Ping',
                            icon: _testing
                                ? Icons.hourglass_top_rounded
                                : Icons.send_rounded,
                            onTap: _testing ? null : _testConnection,
                          ),
                        ],
                      ),
                      if (_testResult.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _border),
                          ),
                          child: Text(
                            _testResult,
                            style: TextStyle(
                              color: _testColor,
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // ── ENDPOINTS ─────────────────────────────
                _sectionLabel('API ENDPOINTS'),
                ...grouped.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 10, 0, 6),
                        child: Text(
                          entry.key.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xffB58BFF),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      _glassCard(
                        child: Column(
                          children: [
                            for (int i = 0; i < entry.value.length; i++) ...[
                              if (i > 0)
                                Divider(
                                    height: 1,
                                    color: Colors.white.withOpacity(0.07)),
                              _endpointTile(entry.value[i]),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  );
                }),

                const SizedBox(height: 22),

                // ── DEFAULT INFO ──────────────────────────
                _sectionLabel('INFO'),
                _glassCard(
                  child: Column(
                    children: [
                      _infoRow('Default URL', kDefaultBaseUrl),
                      Divider(
                          height: 1, color: Colors.white.withOpacity(0.07)),
                      _infoRow('Active URL', _savedUrl),
                      Divider(
                          height: 1, color: Colors.white.withOpacity(0.07)),
                      _infoRow(
                          'Status',
                          _savedUrl == kDefaultBaseUrl
                              ? 'Production (default)'
                              : 'Custom override active'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── WIDGETS ───────────────────────────────────

  Widget _header() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'API Settings',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xff7C3AED), Color(0xffEC4899)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'ADMIN',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white54,
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _endpointTile(_ApiEndpoint ep) {
    final fullUrl = '${_savedUrl.replaceAll(RegExp(r'/$'), '')}${ep.path}';
    final isGet = ep.method == 'GET';

    return InkWell(
      onLongPress: () => _copyToClipboard(fullUrl),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: isGet
                    ? Colors.greenAccent.withOpacity(0.15)
                    : Colors.orangeAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                ep.method,
                style: TextStyle(
                  color: isGet ? Colors.greenAccent : Colors.orangeAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ep.path,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    ep.desc,
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded,
                  color: Colors.white24, size: 16),
              onPressed: () => _copyToClipboard(fullUrl),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBadge(IconData icon, Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.15),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }

  Widget _chipBtn({
    required String label,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white70),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gradientBtn({
    required String label,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xff7C3AED), Color(0xffEC4899)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xffEC4899).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _outlineBtn({
    required String label,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: Colors.white70),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _outlineIconBtn({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, size: 18, color: Colors.white54),
      ),
    );
  }

  Widget _blob(double size, Color color, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(opacity),
      ),
    );
  }
}
