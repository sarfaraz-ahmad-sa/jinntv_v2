import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';

import 'Screens/login.dart';
import 'Screens/app_shell.dart';
import 'Screens/admin_api_screen.dart';

import 'controllers/theme_controller.dart';
import 'db/db_helper.dart';

// ✅ Global navigator key for notification routing
final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

// ✅ Local notifications (for foreground)
final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // background tasks if needed
}

Future<void> _initLocalNotifications() async {
  // ✅ Android init
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

  // ✅ iOS init (REQUIRED when targeting iOS)
  const iosInit = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const initSettings = InitializationSettings(
    android: androidInit,
    iOS: iosInit,
  );

  await _local.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (resp) {
      final payload = resp.payload;
      if (payload != null && payload.isNotEmpty) {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        _handleRedirect(data);
      }
    },
  );

  // ✅ Android channel (only Android)
  if (!kIsWeb && Platform.isAndroid) {
    const channel = AndroidNotificationChannel(
      'jinntv_high',
      'JinnTV Notifications',
      description: 'JinnTV push notifications',
      importance: Importance.high,
    );

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // ✅ iOS permissions (recommended)
  if (!kIsWeb && Platform.isIOS) {
    await _local
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }
}

Future<void> _initFCM() async {
  // ✅ Only mobile (Android/iOS). Skip web/desktop.
  if (kIsWeb) return;
  if (!(Platform.isAndroid || Platform.isIOS)) return;

  // ✅ Permission
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // ✅ Background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

  // ✅ Foreground -> show local notification
  FirebaseMessaging.onMessage.listen((RemoteMessage msg) async {
    final title = msg.notification?.title ?? 'JINNTV';
    final body = msg.notification?.body ?? '';

    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'jinntv_high',
          'JinnTV Notifications',
          channelDescription: 'JinnTV push notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(), // ✅ iOS details added
      ),
      payload: jsonEncode(msg.data), // ✅ carries {redirect: "..."}
    );
  });

  // ✅ Tap when app in background
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) {
    _handleRedirect(msg.data);
  });

  // ✅ Tap when app terminated
  final initial = await FirebaseMessaging.instance.getInitialMessage();
  if (initial != null) {
    _handleRedirect(initial.data);
  }

  // ✅ Safe token handling (no crash on iOS)
  FirebaseMessaging.instance.onTokenRefresh.listen((t) {
    debugPrint("FCM TOKEN (refresh): $t");
  });

  Future<void> _tryGetTokenSafely() async {
    try {
      if (Platform.isIOS) {
        // wait a little for APNS token to arrive
        for (int i = 0; i < 30; i++) {
          final apns = await FirebaseMessaging.instance.getAPNSToken();
          if (apns != null && apns.isNotEmpty) {
            debugPrint("APNS TOKEN: $apns");
            break;
          }
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      final token = await FirebaseMessaging.instance.getToken();
      debugPrint("FCM TOKEN: $token");
    } catch (e) {
      debugPrint("FCM token not ready yet (safe): $e");
    }
  }

  // ignore: unawaited_futures
  _tryGetTokenSafely();
}

/// ✅ Keep it simple now: just route by `redirect`
void _handleRedirect(Map<String, dynamic> data) {
  final redirect = (data['redirect'] ?? '').toString().trim();
  if (redirect.isEmpty) return;

  navKey.currentState?.push(
    MaterialPageRoute(builder: (_) => const AppShell()),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Improves perceived performance (fewer image re-downloads / decodes).
  // Keep conservative for low-end devices.
  PaintingBinding.instance.imageCache.maximumSize = 1500;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 80 << 20; // 80 MB

  // ✅ Load admin base URL before anything else
  await initAdminBaseUrl();

  // ✅ Firebase init
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ local notifications + FCM init (mobile only)
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await _initLocalNotifications();
    await _initFCM();
  }

  // ✅ Desktop SQLite (macOS / Windows / Linux)
  if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  bool loggedIn = false;

  // ✅ Session check (not for web)
  if (!kIsWeb) {
    loggedIn = await DBHelper.isLoggedIn();
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeController(),
      child: MyApp(isLoggedIn: loggedIn),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();

    return MaterialApp(
      navigatorKey: navKey,
      debugShowCheckedModeBanner: false,
      title: 'Jinn TV',
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        overscroll: false,
      ),
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: theme.themeMode,
      home: isLoggedIn ? const AppShell() : const LoginScreen(),
    );
  }
}
