// lib/services/notification_service.dart
//
// ✅ MERGED: handlers + ACK + routing + foreground heads-up banner + refresh/unread bus
//
// What it does:
// 1) Foreground push aaye => heads-up local notification + ACK(delivered) + UI refresh signal
// 2) User tap (background/terminated) => ACK(opened) + routing + UI refresh signal
// 3) Central routeRedirect() for both push taps + NotificationsScreen taps
//
// Requires pubspec:
//   firebase_messaging
//   http
//   flutter_local_notifications
//   DBHelper.getUserIdInt()

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../db/db_helper.dart';
import '../Screens/video_player_screen.dart';

/// ✅ Simple in-app bus (refresh + unread badge)
class NotifBus {
  NotifBus._();
  static final NotifBus instance = NotifBus._();

  final ValueNotifier<int> unread = ValueNotifier<int>(0);

  final List<VoidCallback> _refreshListeners = [];

  void addRefreshListener(VoidCallback cb) => _refreshListeners.add(cb);
  void removeRefreshListener(VoidCallback cb) => _refreshListeners.remove(cb);

  void bumpRefresh() {
    for (final cb in List<VoidCallback>.from(_refreshListeners)) {
      try {
        cb();
      } catch (_) {}
    }
  }

  void setUnread(int v) => unread.value = v < 0 ? 0 : v;
}

/// ✅ Local notifications helper (heads-up in foreground)
class LocalNotif {
  LocalNotif._();
  static final LocalNotif instance = LocalNotif._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _inited = false;

  Future<void> init() async {
    if (_inited) return;
    _inited = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();

    const init = InitializationSettings(android: androidInit, iOS: iosInit);
    await _plugin.initialize(init);

    // Android channel (safe)
    const channel = AndroidNotificationChannel(
      'jinntv_high',
      'JinnTV Notifications',
      description: 'JinnTV push notifications',
      importance: Importance.max,
    );

    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(channel);
  }

  Future<void> showHeadsUp({required String title, required String body}) async {
    if (kIsWeb) return;

    const androidDetails = AndroidNotificationDetails(
      'jinntv_high',
      'JinnTV Notifications',
      channelDescription: 'JinnTV push notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String _ackUrl =
      "https://jinntv.com/api_forApp/notificationAck.php";
  static const String _listUrl =
      "https://jinntv.com/api_forApp/getNotifications.php";

  bool _inited = false;

  /// ✅ Call in AppShell.initState()
  Future<void> init(BuildContext context) async {
    if (_inited) return;
    _inited = true;

    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;

    // Permission (iOS + Android 13+)
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}

    // Local notif init (foreground heads-up)
    await LocalNotif.instance.init();

    // Foreground receive => delivered ACK + heads-up + in-app banner + refresh
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) async {
      await _ackDelivered(msg);

      final title = msg.notification?.title ?? "JINNTV";
      final body = msg.notification?.body ?? "";
      final redirect = (msg.data["redirect"] ?? "").toString().trim();

      if (body.trim().isNotEmpty) {
        await LocalNotif.instance.showHeadsUp(title: title, body: body);
      }

      // Small in-app banner while user is using the app
      // so notification "runtime" screen pe bhi nazar aaye.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          backgroundColor: const Color(0xFF111827),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              if (body.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
          action: redirect.isEmpty
              ? null
              : SnackBarAction(
                  label: "View",
                  textColor: Colors.white,
                  onPressed: () {
                    routeRedirect(context, redirect);
                  },
                ),
          duration: const Duration(seconds: 4),
        ),
      );

      // UI refresh signal (NotificationsScreen reload)
      NotifBus.instance.bumpRefresh();
      await _refreshUnreadCount();

      debugPrint("FCM onMessage => title=$title data=${msg.data}");
    });

    // Opened from background => opened ACK + refresh + route
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) async {
      await _ackOpened(msg);
      NotifBus.instance.bumpRefresh();
      await _refreshUnreadCount();
      _routeFromMessage(context, msg);
    });

    // Initial unread sync (Home badge shows correct count on app open)
    await _refreshUnreadCount();
  }

  /// ✅ Call once in AppShell.initState() to handle "killed app" tap
  Future<void> handleInitialMessage(BuildContext context) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;

    final msg = await FirebaseMessaging.instance.getInitialMessage();
    if (msg == null) return;

    await _ackOpened(msg);
    NotifBus.instance.bumpRefresh();
    await _refreshUnreadCount();
    _routeFromMessage(context, msg);
  }

  // ---------------- ACKS ----------------

  Future<void> _ackDelivered(RemoteMessage msg) async {
    final nid = msg.data["notification_id"];
    if (nid == null) return;

    final uid = await DBHelper.getUserIdInt();
    if (uid == null || uid <= 0) return;

    await _postAck(
      notificationId: nid.toString(),
      userId: uid.toString(),
      event: "delivered",
    );
  }

  Future<void> _ackOpened(RemoteMessage msg) async {
    final nid = msg.data["notification_id"];
    if (nid == null) return;

    final uid = await DBHelper.getUserIdInt();
    if (uid == null || uid <= 0) return;

    await _postAck(
      notificationId: nid.toString(),
      userId: uid.toString(),
      event: "opened",
    );
  }

  Future<void> _postAck({
    required String notificationId,
    required String userId,
    required String event,
  }) async {
    try {
      final res = await http.post(
        Uri.parse(_ackUrl),
        body: {
          "notification_id": notificationId,
          "user_id": userId,
          "event": event, // delivered/opened
        },
      );
      debugPrint("ACK($event) => ${res.statusCode} ${res.body}");
    } catch (e) {
      debugPrint("ACK($event) error => $e");
    }
  }

  /// Keeps HomeScreen unread badge in sync with server.
  Future<void> _refreshUnreadCount() async {
    try {
      final uid = await DBHelper.getUserIdInt();
      if (uid == null || uid <= 0) return;

      final uri = Uri.parse("$_listUrl?user_id=$uid&limit=1&offset=0");
      final res = await http.get(uri);
      if (res.statusCode != 200) return;

      final json = jsonDecode(res.body);
      if (json is! Map) return;

      final unread = json["unread"];
      final unreadInt =
          (unread is int) ? unread : int.tryParse(unread?.toString() ?? "") ?? 0;
      NotifBus.instance.setUnread(unreadInt);
    } catch (_) {
      // ignore: best-effort badge sync
    }
  }

  // ---------------- ROUTING ----------------

  void _routeFromMessage(BuildContext context, RemoteMessage msg) {
    final redirect = (msg.data["redirect"] ?? "").toString().trim();
    if (redirect.isEmpty) return;
    routeRedirect(context, redirect);
  }

  /// ✅ Use this from NotificationsScreen tap also
  void routeRedirect(BuildContext context, String redirect) {
    if (redirect.trim().isEmpty) return;

    // Examples you can standardize in admin Redirect:
    //  - video:123
    //  - url:https://...
    //  - section:7

    if (redirect.startsWith("video:")) {
      final idStr = redirect.substring("video:".length).trim();
      final vid = int.tryParse(idStr);
      if (vid != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VideoPlayerScreen(videoId: vid),
          ),
        );
      }
      return;
    }

    if (redirect.startsWith("url:")) {
      // Optional: implement webview / external browser open later.
      return;
    }

    if (redirect.startsWith("section:")) {
      // Optional: hook section-deep-link here.
      return;
    }

    // Unknown redirect types are safely ignored (no alert).
  }
}
