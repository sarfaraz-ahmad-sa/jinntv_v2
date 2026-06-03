import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

import '../services/notification_service.dart';
import 'app_update_checker.dart';
import '../db/db_helper.dart';

import 'home.dart';
import 'SearchScreen.dart';
import 'AboutUs.dart';
import 'MyPlayListScreen.dart';
import 'widgets/app_bottom_nav.dart';
import 'widgets/More_menu.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  StreamSubscription<String>? _tokenRefreshSub;
  bool _checkedForUpdate = false;

  static const Color _bg = Color(0xFF0B0F14);

  late final List<Widget> _tabs = [
    const HomeScreen(),
    const SearchScreen(),
    const AboutUsScreen(),
    MyPlayListScreen(
      isRootTab: true,
      onBackToHome: () {
        if (mounted) {
          setState(() => _currentIndex = 0);
        }
      },
    ),
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_checkedForUpdate) {
        _checkedForUpdate = true;
        AppUpdateChecker.check(context);
      }
    });

    _ensureFirebaseTokenForLoggedInUser();

    NotificationService.instance.init(context);
    NotificationService.instance.handleInitialMessage(context);
  }

  @override
  void dispose() {
    _tokenRefreshSub?.cancel();
    super.dispose();
  }

  Future<void> _ensureFirebaseTokenForLoggedInUser() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;

    final userId = await DBHelper.getUserIdInt();
    if (userId == null || userId <= 0) return;

    await _saveFirebaseToken(userId);

    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub =
        FirebaseMessaging.instance.onTokenRefresh.listen((_) async {
      final uid = await DBHelper.getUserIdInt();
      if (uid != null && uid > 0) {
        await _saveFirebaseToken(uid);
      }
    });
  }

  Future<void> _saveFirebaseToken(int userId) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;

    final res = await http.post(
      Uri.parse("https://jinntv.com/api_forApp/saveFirebaseToken.php"),
      body: {
        "user_id": userId.toString(),
        "fcm_token": token,
        "device": Platform.isIOS ? "ios" : "android",
      },
    );

    debugPrint("saveFirebaseToken => ${res.statusCode} ${res.body}");
  }

  void _openMoreSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.60),
      builder: (_) {
        return _MoreSheetWrapper(
          child: const MoreScreen(),
          bg: _bg,
        );
      },
    ).then((_) {
      if (!mounted) return;
      setState(() => _currentIndex = 0);
    });
  }

  Widget _body() {
    final idx = _currentIndex.clamp(0, 3);
    return IndexedStack(
      index: idx,
      children: _tabs,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: _body(),
      bottomNavigationBar: AppBottomNav(
        backgroundColor: _bg,
        currentIndex: _currentIndex,
        onTap: (i) {
          if (i == 4) {
            _openMoreSheet();
            return;
          }
          setState(() => _currentIndex = i);
        },
      ),
    );
  }
}

class _MoreSheetWrapper extends StatelessWidget {
  final Widget child;
  final Color bg;

  const _MoreSheetWrapper({
    required this.child,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final top = h * 0.12;

    return Padding(
      padding: EdgeInsets.only(top: top),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: Container(
          color: bg,
          child: SafeArea(
            top: false,
            child: child,
          ),
        ),
      ),
    );
  }
}