import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/services/user_library_service.dart';
import '../features/home/presentation/cine_home_screen.dart';
import '../features/library/presentation/watchlist_screen.dart';
import '../features/more/presentation/cine_more_screen.dart';
import '../features/explore/presentation/explore_screen.dart';
import '../features/search/presentation/cine_search_screen.dart';
import 'widgets/app_bottom_nav.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  StreamSubscription<String>? _tokenRefreshSub;
  final Set<int> _loadedTabs = {0};

  late final List<Widget> _tabs = const [
    CineHomeScreen(),
    CineSearchScreen(),
    ExploreScreen(),
    WatchlistScreen(),
  ];

  @override
  void initState() {
    super.initState();
    UserLibraryService.instance.saveProfileIfNeeded();
    _syncFcm();
  }

  Future<void> _syncFcm() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    Future<void> save(String token) => UserLibraryService.instance.saveFcmToken(
          token,
          platform: Platform.isIOS ? 'ios' : 'android',
        );
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await save(token);
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(save);
  }

  @override
  void dispose() {
    _tokenRefreshSub?.cancel();
    super.dispose();
  }

  Widget _body() => IndexedStack(
        index: _currentIndex.clamp(0, 3),
        children: List.generate(
          _tabs.length,
          (i) => _loadedTabs.contains(i) ? _tabs[i] : const SizedBox.shrink(),
        ),
      );

  void _openMoreSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: .65),
      builder: (_) => Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * .10),
        child: const ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          child: CineMoreScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF08090C),
        body: _body(),
        bottomNavigationBar: AppBottomNav(
          currentIndex: _currentIndex,
          backgroundColor: const Color(0xFF08090C),
          onTap: (i) {
            if (i == 4) {
              _openMoreSheet();
              return;
            }
            setState(() {
              _currentIndex = i;
              _loadedTabs.add(i);
            });
          },
        ),
      );
}
