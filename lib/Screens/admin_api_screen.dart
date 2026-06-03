import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KEYS
// ─────────────────────────────────────────────────────────────────────────────
const String kAdminBaseUrlKey       = 'admin_base_url';
const String kAdminOverridesKey     = 'admin_endpoint_overrides'; // JSON map
const String kDefaultBaseUrl        = 'https://www.jinntv.com';

// ─────────────────────────────────────────────────────────────────────────────
// RUNTIME CACHE
// ─────────────────────────────────────────────────────────────────────────────
String _cachedBaseUrl = kDefaultBaseUrl;
Map<String, String> _cachedOverrides = {};  // path → full URL override

/// Call once in main() before runApp.
Future<void> initAdminBaseUrl() async {
  final sp = await SharedPreferences.getInstance();
  _cachedBaseUrl   = sp.getString(kAdminBaseUrlKey) ?? kDefaultBaseUrl;
  final raw        = sp.getString(kAdminOverridesKey);
  _cachedOverrides = raw != null
      ? Map<String, String>.from(jsonDecode(raw) as Map)
      : {};
}

Future<String> getAdminBaseUrl() async {
  final sp = await SharedPreferences.getInstance();
  return sp.getString(kAdminBaseUrlKey) ?? kDefaultBaseUrl;
}

/// Synchronous getter — safe after initAdminBaseUrl().
String get adminBaseUrl => _cachedBaseUrl;

/// Resolve full URL for a path.
/// Checks per-endpoint override first, then falls back to base URL.
String apiUrl(String path) {
  // Per-endpoint override takes priority
  if (_cachedOverrides.containsKey(path)) {
    return _cachedOverrides[path]!;
  }
  final b = _cachedBaseUrl.endsWith('/')
      ? _cachedBaseUrl.substring(0, _cachedBaseUrl.length - 1)
      : _cachedBaseUrl;
  final p = path.startsWith('/') ? path : '/$path';
  return '$b$p';
}

// ─────────────────────────────────────────────────────────────────────────────
// ENDPOINT DEFINITIONS
// ─────────────────────────────────────────────────────────────────────────────
class ApiEndpointDef {
  final String category;
  final String path;       // relative path — also used as key
  final String method;
  final String desc;
  const ApiEndpointDef({
    required this.category,
    required this.path,
    required this.method,
    required this.desc,
  });
}

const List<ApiEndpointDef> kAllEndpoints = [
  ApiEndpointDef(category:'Home',          path:'/api_forApp/home.php',                        method:'GET',  desc:'Hero slider items'),
  ApiEndpointDef(category:'Home',          path:'/api_forApp/home_sections.php',               method:'GET',  desc:'Home sections + ads'),
  ApiEndpointDef(category:'Catalog',       path:'/api_forApp/catalog.php',                     method:'GET',  desc:'Categories & video list'),
  ApiEndpointDef(category:'Video',         path:'/api_forApp/video_detail.php',                method:'GET',  desc:'Video detail + related'),
  ApiEndpointDef(category:'Video',         path:'/api_forApp/video_action.php',                method:'POST', desc:'Like / dislike / subscribe'),
  ApiEndpointDef(category:'Auth',          path:'/login_app.php',                              method:'POST', desc:'User login'),
  ApiEndpointDef(category:'Auth',          path:'/php_scripts/data.php',                       method:'POST', desc:'User signup'),
  ApiEndpointDef(category:'Auth',          path:'/api_forApp/forgot_password.php',             method:'POST', desc:'Forgot password'),
  ApiEndpointDef(category:'Auth',          path:'/api_forApp/saveFirebaseToken.php',           method:'POST', desc:'Save FCM token'),
  ApiEndpointDef(category:'Notifications', path:'/api_forApp/getNotifications.php',            method:'GET',  desc:'Notifications list'),
  ApiEndpointDef(category:'Notifications', path:'/api_forApp/notificationAck.php',             method:'POST', desc:'Mark notification read'),
  ApiEndpointDef(category:'More',          path:'/api_forApp/get_more_menu_social_links.php',  method:'POST', desc:'Social links'),
  ApiEndpointDef(category:'More',          path:'/api_forApp/get_app_version.php',             method:'GET',  desc:'App update check'),
  ApiEndpointDef(category:'More',          path:'/api_forApp/delete_account.php',              method:'POST', desc:'Delete account'),
  ApiEndpointDef(category:'Content',       path:'/jinn-tv-admin/api_about_us.php',             method:'GET',  desc:'About Us page'),
  ApiEndpointDef(category:'Content',       path:'/jinn-tv-admin/api_support_us.php',           method:'GET',  desc:'Support Us page'),
];

// ─────────────────────────────────────────────────────────────────────────────
// ENVIRONMENT PRESETS
// ─────────────────────────────────────────────────────────────────────────────
class _EnvPreset {
  final String name;
  final String icon;
  final String baseUrl;
  const _EnvPreset(this.name, this.icon, this.baseUrl);
}

const _kPresets = [
  _EnvPreset('Production', '🚀', 'https://www.jinntv.com'),
  _EnvPreset('Staging',    '🧪', 'https://staging.jinntv.com'),
  _EnvPreset('Local',      '💻', 'http://192.168.1.100:8080'),
];

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN API SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class AdminApiScreen extends StatefulWidget {
  const AdminApiScreen({super.key});
  @override
  State<AdminApiScreen> createState() => _AdminApiScreenState();
}

class _AdminApiScreenState extends State<AdminApiScreen>
    with SingleTickerProviderStateMixin {
  static const _bg        = Color(0xFF0F171E);
  static const _teal      = Color(0xFF00A8E1);
  static const _cardColor = Color(0xFF1A242F);
  static const _border    = Color(0x1AFFFFFF);

  late TabController _tabCtrl;

  String _savedBaseUrl = kDefaultBaseUrl;
  Map<String, String> _overrides = {};

  bool _editingBase = false;
  bool _savingBase  = false;
  late TextEditingController _baseCtrl;

  // endpoint test results: path → result string
  final Map<String, String> _testResults = {};
  final Map<String, Color>  _testColors  = {};
  final Set<String>         _testing     = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl  = TabController(length: 3, vsync: this);
    _baseCtrl = TextEditingController(text: _cachedBaseUrl);
    _loadFromPrefs();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _baseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFromPrefs() async {
    final sp  = await SharedPreferences.getInstance();
    final url = sp.getString(kAdminBaseUrlKey) ?? kDefaultBaseUrl;
    final raw = sp.getString(kAdminOverridesKey);
    final ovr = raw != null
        ? Map<String, String>.from(jsonDecode(raw) as Map)
        : <String, String>{};
    if (!mounted) return;
    setState(() {
      _savedBaseUrl  = url;
      _overrides     = ovr;
      _baseCtrl.text = url;
    });
  }

  Future<void> _saveBaseUrl() async {
    final raw = _baseCtrl.text.trim();
    if (raw.isEmpty) return;
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) {
      _snack('Invalid URL — must start with http:// or https://', error: true);
      return;
    }
    setState(() => _savingBase = true);
    final sp = await SharedPreferences.getInstance();
    await sp.setString(kAdminBaseUrlKey, raw);
    _cachedBaseUrl = raw;
    if (!mounted) return;
    setState(() { _savedBaseUrl = raw; _editingBase = false; _savingBase = false; });
    _snack('Base URL saved — restart app to apply everywhere.');
  }

  Future<void> _resetBaseUrl() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(kAdminBaseUrlKey);
    _cachedBaseUrl = kDefaultBaseUrl;
    if (!mounted) return;
    setState(() { _savedBaseUrl = kDefaultBaseUrl; _baseCtrl.text = kDefaultBaseUrl; _editingBase = false; });
    _snack('Reset to default.');
  }

  Future<void> _applyPreset(_EnvPreset p) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(kAdminBaseUrlKey, p.baseUrl);
    _cachedBaseUrl = p.baseUrl;
    if (!mounted) return;
    setState(() { _savedBaseUrl = p.baseUrl; _baseCtrl.text = p.baseUrl; });
    _snack('${p.name} applied — restart to take effect.');
  }

  Future<void> _setEndpointOverride(String path, String fullUrl) async {
    final updated = Map<String, String>.from(_overrides);
    if (fullUrl.isEmpty) {
      updated.remove(path);
    } else {
      updated[path] = fullUrl;
    }
    final sp = await SharedPreferences.getInstance();
    await sp.setString(kAdminOverridesKey, jsonEncode(updated));
    _cachedOverrides = updated;
    if (!mounted) return;
    setState(() => _overrides = updated);
    _snack(fullUrl.isEmpty ? 'Override removed.' : 'Override saved.');
  }

  Future<void> _clearAllOverrides() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(kAdminOverridesKey);
    _cachedOverrides = {};
    if (!mounted) return;
    setState(() => _overrides = {});
    _snack('All overrides cleared.');
  }

  Future<void> _testEndpoint(ApiEndpointDef ep) async {
    final path = ep.path;
    if (_testing.contains(path)) return;
    setState(() {
      _testing.add(path);
      _testResults[path] = 'Testing...';
      _testColors[path]  = Colors.white38;
    });
    final url = apiUrl(path);
    try {
      final sw = Stopwatch()..start();
      final res = await (ep.method == 'GET'
              ? http.get(Uri.parse(url))
              : http.post(Uri.parse(url)))
          .timeout(const Duration(seconds: 8));
      sw.stop();
      if (!mounted) return;
      final ok = res.statusCode >= 200 && res.statusCode < 500;
      setState(() {
        _testResults[path] = '${ok ? "✓" : "✗"} ${res.statusCode} — ${sw.elapsedMilliseconds}ms';
        _testColors[path]  = ok ? Colors.greenAccent : Colors.orangeAccent;
        _testing.remove(path);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testResults[path] = '✗ ${e.toString().split('\n').first}';
        _testColors[path]  = Colors.redAccent;
        _testing.remove(path);
      });
    }
  }

  String _exportConfig() {
    return const JsonEncoder.withIndent('  ').convert({
      'base_url': _savedBaseUrl,
      'overrides': _overrides,
      'exported_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _importConfig(String json) async {
    try {
      final data  = jsonDecode(json) as Map<String, dynamic>;
      final base  = data['base_url']?.toString() ?? kDefaultBaseUrl;
      final ovr   = Map<String, String>.from(data['overrides'] as Map? ?? {});
      final sp    = await SharedPreferences.getInstance();
      await sp.setString(kAdminBaseUrlKey, base);
      await sp.setString(kAdminOverridesKey, jsonEncode(ovr));
      _cachedBaseUrl   = base;
      _cachedOverrides = ovr;
      if (!mounted) return;
      setState(() { _savedBaseUrl = base; _overrides = ovr; _baseCtrl.text = base; });
      _snack('Config imported successfully!');
    } catch (_) {
      _snack('Invalid JSON config.', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.redAccent : const Color(0xFF1A2533),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _snack('Copied!');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          Container(
            color: const Color(0xFF0A1018),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white, size: 20),
                        ),
                        const Expanded(
                          child: Text(
                            'API Manager',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 19,
                            ),
                          ),
                        ),
                        // Export button
                        IconButton(
                          onPressed: _showExportImport,
                          icon: const Icon(Icons.import_export_rounded,
                              color: Colors.white70),
                          tooltip: 'Export / Import',
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0077A8), Color(0xFF00A8E1)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('ADMIN',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  letterSpacing: 1.2)),
                        ),
                      ],
                    ),
                  ),
                  TabBar(
                    controller: _tabCtrl,
                    indicatorColor: _teal,
                    indicatorWeight: 2,
                    labelColor: _teal,
                    unselectedLabelColor: Colors.white38,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                    tabs: const [
                      Tab(text: 'Base URL'),
                      Tab(text: 'Endpoints'),
                      Tab(text: 'Presets'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Tab body ───────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildBaseTab(),
                _buildEndpointsTab(),
                _buildPresetsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── TAB 1: Base URL ──────────────────────────────────────────────────────

  Widget _buildBaseTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionLabel('GLOBAL BASE URL'),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _iconBadge(Icons.link_rounded, _teal),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Base URL',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15)),
                  ),
                  if (!_editingBase)
                    _chip(
                      label: 'Edit',
                      icon: Icons.edit_rounded,
                      onTap: () => setState(() => _editingBase = true),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (!_editingBase) ...[
                _urlBox(_savedBaseUrl),
                if (_savedBaseUrl != kDefaultBaseUrl) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.amber, size: 14),
                    const SizedBox(width: 6),
                    const Text('Custom URL active',
                        style: TextStyle(color: Colors.amber, fontSize: 12)),
                  ]),
                ],
              ] else ...[
                _textField(
                  ctrl: _baseCtrl,
                  hint: kDefaultBaseUrl,
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _gradBtn(
                      label: _savingBase ? 'Saving...' : 'Save',
                      icon: Icons.check_rounded,
                      onTap: _savingBase ? null : _saveBaseUrl,
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _outlineBtn(
                      label: 'Reset Default',
                      icon: Icons.restart_alt_rounded,
                      onTap: _resetBaseUrl,
                    )),
                    const SizedBox(width: 8),
                    _iconOutlineBtn(
                      icon: Icons.close_rounded,
                      onTap: () => setState(() {
                        _editingBase = false;
                        _baseCtrl.text = _savedBaseUrl;
                      }),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 14),
        _sectionLabel('OVERRIDE SUMMARY'),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _iconBadge(Icons.tune_rounded, Colors.orangeAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_overrides.length} endpoint override${_overrides.length == 1 ? '' : 's'} active',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    ),
                  ),
                  if (_overrides.isNotEmpty)
                    _chip(
                      label: 'Clear All',
                      icon: Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                      onTap: _clearAllOverrides,
                    ),
                ],
              ),
              if (_overrides.isNotEmpty) ...[
                const SizedBox(height: 12),
                ..._overrides.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          e.key.split('/').last,
                          style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.value,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontFamily: 'monospace'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── TAB 2: Endpoints ─────────────────────────────────────────────────────

  Widget _buildEndpointsTab() {
    final grouped = <String, List<ApiEndpointDef>>{};
    for (final ep in kAllEndpoints) {
      grouped.putIfAbsent(ep.category, () => []).add(ep);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionLabel('TAP ENDPOINT TO OVERRIDE ITS URL'),
        ...grouped.entries.map((entry) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 12, 0, 6),
              child: Text(
                entry.key.toUpperCase(),
                style: const TextStyle(
                    color: Color(0xFF5BC8F5),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2),
              ),
            ),
            _card(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (int i = 0; i < entry.value.length; i++) ...[
                    if (i > 0)
                      Divider(height: 1, color: Colors.white.withOpacity(0.06)),
                    _endpointRow(entry.value[i]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
        )),
      ],
    );
  }

  Widget _endpointRow(ApiEndpointDef ep) {
    final hasOverride = _overrides.containsKey(ep.path);
    final resolvedUrl = apiUrl(ep.path);
    final testResult  = _testResults[ep.path];
    final testColor   = _testColors[ep.path] ?? Colors.white38;
    final isTesting   = _testing.contains(ep.path);

    return InkWell(
      onTap: () => _showEndpointEditor(ep),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Method badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: ep.method == 'GET'
                        ? Colors.greenAccent.withOpacity(0.15)
                        : Colors.orangeAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    ep.method,
                    style: TextStyle(
                      color: ep.method == 'GET'
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                      fontWeight: FontWeight.w900,
                      fontSize: 9,
                    ),
                  ),
                ),
                if (hasOverride) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'OVERRIDDEN',
                      style: TextStyle(
                          color: Colors.amber,
                          fontSize: 9,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
                const Spacer(),
                // Test button
                GestureDetector(
                  onTap: isTesting ? null : () => _testEndpoint(ep),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: isTesting
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Colors.white54))
                        : const Text('Test',
                            style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded,
                    color: Colors.white24, size: 18),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              ep.path,
              style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              ep.desc,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            if (hasOverride) ...[
              const SizedBox(height: 4),
              Text(
                '→ $resolvedUrl',
                style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 11,
                    fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (testResult != null) ...[
              const SizedBox(height: 4),
              Text(
                testResult,
                style: TextStyle(
                    color: testColor,
                    fontSize: 11,
                    fontFamily: 'monospace'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showEndpointEditor(ApiEndpointDef ep) {
    final ctrl = TextEditingController(
        text: _overrides[ep.path] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F171E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              ep.path,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  fontFamily: 'monospace'),
            ),
            const SizedBox(height: 4),
            Text(ep.desc,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              'Default: ${_savedBaseUrl}${ep.path}',
              style: const TextStyle(
                  color: Colors.white24,
                  fontSize: 11,
                  fontFamily: 'monospace'),
            ),
            const SizedBox(height: 16),
            _textField(
              ctrl: ctrl,
              hint: 'Full URL override (leave empty to use base URL)',
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _gradBtn(
                  label: 'Save Override',
                  icon: Icons.check_rounded,
                  onTap: () {
                    _setEndpointOverride(ep.path, ctrl.text.trim());
                    Navigator.pop(ctx);
                  },
                )),
                const SizedBox(width: 8),
                _iconOutlineBtn(
                  icon: Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                  onTap: () {
                    _setEndpointOverride(ep.path, '');
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── TAB 3: Presets ───────────────────────────────────────────────────────

  Widget _buildPresetsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionLabel('ENVIRONMENT PRESETS'),
        ..._kPresets.map((p) {
          final isActive = _savedBaseUrl == p.baseUrl;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _card(
              child: InkWell(
                onTap: () => _applyPreset(p),
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  children: [
                    Text(p.icon, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15)),
                          const SizedBox(height: 3),
                          Text(p.baseUrl,
                              style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                  fontFamily: 'monospace'),
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF0077A8), Color(0xFF00A8E1)]),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('ACTIVE',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 10)),
                      )
                    else
                      const Icon(Icons.arrow_forward_ios_rounded,
                          color: Colors.white24, size: 16),
                  ],
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 8),
        _sectionLabel('CUSTOM PRESET'),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _textField(ctrl: _baseCtrl, hint: 'https://your-server.com'),
              const SizedBox(height: 10),
              _gradBtn(
                label: 'Apply Custom URL',
                icon: Icons.rocket_launch_rounded,
                onTap: _saveBaseUrl,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Export / Import ──────────────────────────────────────────────────────

  void _showExportImport() {
    final exportJson = _exportConfig();
    final importCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F171E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 16),
            const Text('Export / Import Config',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16)),
            const SizedBox(height: 14),
            _gradBtn(
              label: 'Copy Current Config (JSON)',
              icon: Icons.copy_rounded,
              onTap: () {
                _copy(exportJson);
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 12),
            _textField(
              ctrl: importCtrl,
              hint: 'Paste JSON config here to import...',
              maxLines: 4,
            ),
            const SizedBox(height: 10),
            _outlineBtn(
              label: 'Import Config',
              icon: Icons.download_rounded,
              onTap: () {
                _importConfig(importCtrl.text.trim());
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── REUSABLE WIDGETS ─────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Text(
      text,
      style: const TextStyle(
          color: Colors.white38,
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 0.8),
    ),
  );

  Widget _card({required Widget child, EdgeInsets? padding}) => Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _cardColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
    ),
    child: child,
  );

  Widget _urlBox(String url) => GestureDetector(
    onLongPress: () => _copy(url),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Text(url,
          style: const TextStyle(
              color: Colors.white70,
              fontFamily: 'monospace',
              fontSize: 12.5)),
    ),
  );

  Widget _textField({
    required TextEditingController ctrl,
    required String hint,
    bool autofocus = false,
    int? maxLines,
  }) =>
      TextField(
        controller: ctrl,
        autofocus: autofocus,
        maxLines: maxLines ?? 1,
        style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
          filled: true,
          fillColor: Colors.black26,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF00A8E1), width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );

  Widget _iconBadge(IconData icon, Color color) => Container(
    width: 34, height: 34,
    decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.15)),
    child: Icon(icon, color: color, size: 16),
  );

  Widget _chip({
    required String label,
    required IconData icon,
    VoidCallback? onTap,
    Color? color,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 12, color: color ?? Colors.white54),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: color ?? Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      );

  Widget _gradBtn({required String label, required IconData icon, VoidCallback? onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF0077A8), Color(0xFF00A8E1)]),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(
                color: const Color(0xFF00A8E1).withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 3))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13)),
          ]),
        ),
      );

  Widget _outlineBtn({required String label, required IconData icon, VoidCallback? onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 14, color: Colors.white60),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white60,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ]),
        ),
      );

  Widget _iconOutlineBtn({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: (color ?? Colors.white38).withOpacity(0.4)),
          ),
          child: Icon(icon, size: 18, color: color ?? Colors.white38),
        ),
      );
}
