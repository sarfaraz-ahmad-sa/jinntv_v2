import 'dart:async';
import 'package:flutter/foundation.dart';

class NotifBus {
  NotifBus._();
  static final NotifBus instance = NotifBus._();

  // unread badge
  final ValueNotifier<int> unread = ValueNotifier<int>(0);

  // refresh signal for screens
  final StreamController<void> _refreshCtrl = StreamController<void>.broadcast();
  Stream<void> get onRefresh => _refreshCtrl.stream;

  void bumpRefresh() => _refreshCtrl.add(null);

  void setUnread(int v) => unread.value = v;

  void dispose() {
    _refreshCtrl.close();
  }
}
