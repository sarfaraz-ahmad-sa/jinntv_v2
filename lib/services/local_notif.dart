import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotif {
  LocalNotif._();
  static final LocalNotif instance = LocalNotif._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _inited = false;

  Future<void> init() async {
    if (_inited) return;
    _inited = true;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();

    const init = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(init);
  }

  Future<void> showHeadsUp({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;

    // const androidDetails = AndroidNotificationDetails(
    //   'jinntv_high',
    //   'JinnTV Notifications',
    //   channelDescription: 'JinnTV push notifications',
    //   importance: Importance.max,
    //   priority: Priority.high,
    // );

   const androidDetails = AndroidNotificationDetails(
  'jinntv_high',
  'JinnTV Notifications',
  channelDescription: 'JinnTV push notifications',
  importance: Importance.max,
  priority: Priority.high,
  icon: 'ic_notification', // ✅ IMPORTANT (no @drawable here)
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
