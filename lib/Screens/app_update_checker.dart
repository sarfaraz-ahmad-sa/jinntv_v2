import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateChecker {
  static Future<void> check(BuildContext context) async {
    try {
      // ── Android: Google Play native in-app update ─────────────────────────
      if (Platform.isAndroid) {
        await _checkAndroid(context);
        return;
      }

      // ── iOS: Custom dialog → App Store ────────────────────────────────────
      if (Platform.isIOS) {
        await _checkIOS(context);
        return;
      }
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ANDROID — Google Play native flow
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> _checkAndroid(BuildContext context) async {
    try {
      final updateInfo = await InAppUpdate.checkForUpdate();

      if (updateInfo.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }

      // Flexible = user can use app while downloading
      // Immediate = fullscreen block (force update)
      final isFlexible = updateInfo.immediateUpdateAllowed == false ||
          updateInfo.flexibleUpdateAllowed == true;

      if (isFlexible && updateInfo.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        await InAppUpdate.completeFlexibleUpdate();
      } else if (updateInfo.immediateUpdateAllowed) {
        // Fullscreen force update — blocks app until updated
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (_) {
      // Play Store not available (e.g. emulator/debug) — fallback to custom
      await _checkViaApi(context);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // iOS — Custom dialog via our API
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> _checkIOS(BuildContext context) async {
    await _checkViaApi(context);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // API fallback (iOS always, Android fallback)
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> _checkViaApi(BuildContext context) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      final res = await http
          .get(Uri.parse('https://jinntv.com/api_forApp/get_app_version.php'))
          .timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) return;

      final decoded = jsonDecode(res.body);
      if (decoded is! Map || decoded['ok'] != true) return;

      final data = decoded['data'];
      if (data is! Map) return;

      final platformKey = Platform.isIOS ? 'ios' : 'android';
      final platformData = data[platformKey];
      if (platformData is! Map) return;

      final latestVersion =
          (platformData['latest_version'] ?? '').toString().trim();
      final minVersion =
          (platformData['min_version'] ?? '').toString().trim();
      final forceUpdate = platformData['force_update'] == true;
      final storeUrl = (platformData['store_url'] ?? '').toString().trim();
      final message =
          (data['message'] ?? 'A new version is available.').toString();

      if (latestVersion.isEmpty || storeUrl.isEmpty) return;

      final mustForce = _isOlder(currentVersion, minVersion);
      final shouldShow = _isOlder(currentVersion, latestVersion);

      if (!shouldShow) return;
      if (!context.mounted) return;

      _showDialog(
        context,
        message: message,
        storeUrl: storeUrl,
        forceUpdate: mustForce || forceUpdate,
      );
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Version compare
  // ══════════════════════════════════════════════════════════════════════════
  static bool _isOlder(String current, String target) {
    if (target.isEmpty) return false;
    final c = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final t = target.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLen = c.length > t.length ? c.length : t.length;

    for (int i = 0; i < maxLen; i++) {
      final cv = i < c.length ? c[i] : 0;
      final tv = i < t.length ? t[i] : 0;
      if (cv < tv) return true;
      if (cv > tv) return false;
    }
    return false;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Custom dialog (iOS + Android fallback)
  // ══════════════════════════════════════════════════════════════════════════
  static void _showDialog(
    BuildContext context, {
    required String message,
    required String storeUrl,
    required bool forceUpdate,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (_) => WillPopScope(
        onWillPop: () async => !forceUpdate,
        child: AlertDialog(
          backgroundColor: const Color(0xFF120E2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '🚀 Update Available',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            if (!forceUpdate)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Later',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffEC4899),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final uri = Uri.parse(storeUrl);
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              child: const Text(
                'Update Now',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}