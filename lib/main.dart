import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'core/config/app_config.dart';
import 'core/theme/cine_theme.dart';
import 'features/auth/presentation/login_screen.dart';
import 'Screens/app_shell.dart';
import 'Screens/onboarding_screen.dart';
import 'firebase_options.dart';

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kDebugMode) {
    debugPrint('CineNexa Firebase project: ${Firebase.app().options.projectId}');
  }
}

Future<void> _initLocalNotifications() async {
  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    ),
  );

  await _local.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (response) {
      final payload = response.payload;
      if (payload == null || payload.isEmpty) return;
      try {
        _handleRedirect((jsonDecode(payload) as Map).cast<String, dynamic>());
      } catch (_) {}
    },
  );

  if (!kIsWeb && Platform.isAndroid) {
    const channel = AndroidNotificationChannel(
      'cinenexa_high',
      'CineNexa Notifications',
      description: 'CineNexa updates and recommendations',
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }
}

Future<void> _initFCM() async {
  if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;

  await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

  FirebaseMessaging.onMessage.listen((msg) async {
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      msg.notification?.title ?? AppConfig.appName,
      msg.notification?.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'cinenexa_high',
          'CineNexa Notifications',
          channelDescription: 'CineNexa updates and recommendations',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(msg.data),
    );
  });

  FirebaseMessaging.onMessageOpenedApp.listen((msg) => _handleRedirect(msg.data));
  final initial = await FirebaseMessaging.instance.getInitialMessage();
  if (initial != null) _handleRedirect(initial.data);
}

void _handleRedirect(Map<String, dynamic> data) {
  if (FirebaseAuth.instance.currentUser == null) return;
  navKey.currentState?.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const AppShell()),
    (_) => false,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache.maximumSize = 1500;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 80 << 20;

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kDebugMode) {
    debugPrint('[CineNexa Firebase] project=${Firebase.app().options.projectId} appId=${Firebase.app().options.appId}');
  }

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await _initLocalNotifications();
    await _initFCM();
  }

  final seenOnboarding = kIsWeb ? true : await hasSeenOnboarding();
  runApp(CineNexaApp(seenOnboarding: seenOnboarding));
}

class CineNexaApp extends StatelessWidget {
  final bool seenOnboarding;
  const CineNexaApp({super.key, required this.seenOnboarding});

  @override
  Widget build(BuildContext context) => MaterialApp(
        navigatorKey: navKey,
        debugShowCheckedModeBanner: false,
        title: AppConfig.appName,
        themeMode: ThemeMode.dark,
        theme: _theme(),
        darkTheme: _theme(),
        home: !seenOnboarding
            ? const OnboardingScreen()
            : FirebaseAuth.instance.currentUser != null
                ? const AppShell()
                : const CineLoginScreen(),
      );

  ThemeData _theme() => CineTheme.dark();
}
