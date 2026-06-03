import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../db/db_helper.dart';
import '../services/notification_service.dart';
import 'admin_api_screen.dart';

// ─── Time-ago cache (avoids recomputing on every build) ───────────────────────
final _timeAgoCache = <String, String>{};

String _timeAgo(String createdAt) {
  if (createdAt.isEmpty) return '';
  final cached = _timeAgoCache[createdAt];
  if (cached != null) return cached;

  DateTime? dt;
  try {
    dt = DateTime.tryParse(createdAt.replaceFirst(' ', 'T'));
  } catch (_) {}

  if (dt == null) {
    _timeAgoCache[createdAt] = createdAt;
    return createdAt;
  }

  final diff = DateTime.now().difference(dt);
  final String result;

  if (diff.inSeconds < 60) {
    result = '${diff.inSeconds}s';
  } else if (diff.inMinutes < 60) {
    result = '${diff.inMinutes}m';
  } else if (diff.inHours < 24) {
    result = '${diff.inHours}h';
  } else if (diff.inDays < 7) {
    result = '${diff.inDays}d';
  } else {
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 5) {
      result = '${weeks}w';
    } else {
      final months = (diff.inDays / 30).floor();
      result = months < 12 ? '${months}mo' : '${(diff.inDays / 365).floor()}y';
    }
  }

  _timeAgoCache[createdAt] = result;
  return result;
}

// ─── Model ────────────────────────────────────────────────────────────────────
@immutable
class NotifItem {
  final int notificationId;
  final String title;
  final String body;
  final String redirect;
  final String createdAt;
  final String status;
  final bool isRead;

  const NotifItem({
    required this.notificationId,
    required this.title,
    required this.body,
    required this.redirect,
    required this.createdAt,
    required this.status,
    required this.isRead,
  });

  factory NotifItem.fromJson(Map<String, dynamic> m) {
    final status = (m['status'] ?? '').toString();
    final isRead = (m['is_read'] == 1) || status == 'opened';
    return NotifItem(
      notificationId: int.tryParse(m['notification_id'].toString()) ?? 0,
      title: (m['title'] ?? '').toString(),
      body: (m['body'] ?? '').toString(),
      redirect: (m['redirect'] ?? '').toString(),
      createdAt: (m['created_at'] ?? '').toString(),
      status: status,
      isRead: isRead,
    );
  }

  NotifItem copyWith({String? status, bool? isRead}) => NotifItem(
        notificationId: notificationId,
        title: title,
        body: body,
        redirect: redirect,
        createdAt: createdAt,
        status: status ?? this.status,
        isRead: isRead ?? this.isRead,
      );
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _pink = Color(0xFF00A8E1);
  static const _card = Color(0xFF1A2533);

  // Separate ValueNotifier so badge rebuilds don't rebuild the whole tree.
  final _unreadNotifier = ValueNotifier<int>(0);

  final _scroll = ScrollController();
  final List<NotifItem> _items = [];

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _showUnreadOnly = false;

  int? _userId;
  String? _error;

  static const int _limit = 20;
  int _offset = 0;

  late final VoidCallback _refreshCb;

  // ── lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _refreshCb = () {
      if (mounted) _fetchFirst();
    };
    NotifBus.instance.addRefreshListener(_refreshCb);

    _scroll.addListener(_onScroll);
    _boot();
  }

  @override
  void dispose() {
    NotifBus.instance.removeRefreshListener(_refreshCb);
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _unreadNotifier.dispose();
    super.dispose();
  }

  // ── scroll ─────────────────────────────────────────────────────────────────
  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 280) {
      _loadMore();
    }
  }

  // ── data ───────────────────────────────────────────────────────────────────
  Future<void> _boot() async {
    final uid = await DBHelper.getUserIdInt();
    if (!mounted) return;

    _userId = uid;

    if (uid == null || uid <= 0) {
      setState(() {
        _loading = false;
        _error = 'User not logged in';
      });
      return;
    }

    await _fetchFirst();
  }

  Uri _listUri(int offset) => Uri.parse(
        apiUrl('/api_forApp/getNotifications.php') +
        '?user_id=$_userId&limit=$_limit&offset=$offset',
      );

  Future<void> _fetchFirst() async {
    final uid = _userId;
    if (uid == null || uid <= 0) return;

    setState(() {
      _loading = true;
      _error = null;
      _offset = 0;
      _hasMore = true;
      _items.clear();
    });

    try {
      final res = await http.get(_listUri(0));
      if (!mounted) return;
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

      final json = jsonDecode(res.body);
      if (json is! Map || json['status'] != 'success') throw Exception('Bad response');

      final unreadRaw = json['unread'] ?? 0;
      final unread = unreadRaw is int ? unreadRaw : int.tryParse(unreadRaw.toString()) ?? 0;

      final parsed = ((json['items'] as List?) ?? [])
          .whereType<Map>()
          .map((m) => NotifItem.fromJson(m.cast<String, dynamic>()))
          .toList(growable: false);

      _unreadNotifier.value = unread;
      NotifBus.instance.setUnread(unread);

      setState(() {
        _items.addAll(parsed);
        _offset = parsed.length;
        _hasMore = parsed.length == _limit;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load notifications';
      });
    }
  }

  Future<void> _loadMore() async {
    final uid = _userId;
    if (uid == null || uid <= 0) return;

    setState(() => _loadingMore = true);

    try {
      final res = await http.get(_listUri(_offset));
      if (!mounted) return;
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

      final json = jsonDecode(res.body);
      if (json is! Map || json['status'] != 'success') throw Exception('Bad response');

      final parsed = ((json['items'] as List?) ?? [])
          .whereType<Map>()
          .map((m) => NotifItem.fromJson(m.cast<String, dynamic>()))
          .toList(growable: false);

      final unreadRaw = json['unread'] ?? _unreadNotifier.value;
      final unread = unreadRaw is int ? unreadRaw : int.tryParse(unreadRaw.toString()) ?? _unreadNotifier.value;

      _unreadNotifier.value = unread;
      NotifBus.instance.setUnread(unread);

      setState(() {
        _items.addAll(parsed);
        _offset += parsed.length;
        _hasMore = parsed.length == _limit;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _onTap(NotifItem item) async {
    if (!item.isRead) {
      final idx = _items.indexWhere((x) => x.notificationId == item.notificationId);
      if (idx >= 0) {
        _items[idx] = _items[idx].copyWith(isRead: true, status: 'opened');
      }

      final newUnread = (_unreadNotifier.value - 1).clamp(0, 9999);
      _unreadNotifier.value = newUnread;
      NotifBus.instance.setUnread(newUnread);

      // Rebuild list without touching badge (badge uses ValueNotifier)
      setState(() {});

      // Fire-and-forget ACK
      _ackOpened(item);
    }

    if (!mounted) return;
    NotificationService.instance.routeRedirect(context, item.redirect);
  }

  Future<void> _ackOpened(NotifItem item) async {
    final uid = _userId;
    if (uid == null || uid <= 0) return;
    try {
      await http.post(
        Uri.parse(apiUrl('/api_forApp/notificationAck.php')),
        body: {
          'notification_id': item.notificationId.toString(),
          'user_id': uid.toString(),
          'event': 'opened',
        },
      );
    } catch (_) {}
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final visibleItems = _showUnreadOnly
        ? _items.where((n) => !n.isRead).toList(growable: false)
        : _items;

    return Scaffold(
      backgroundColor: const Color(0xFF0F171E),
      body: Stack(
        children: [
          // Background gradient — const so it never rebuilds
          const _Background(),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          if (Navigator.canPop(context)) Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Image.asset(
                        'assets/images/jinn-tv-logo.png',
                        height: 40,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.ondemand_video_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Notifications',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      // Badge rebuilds independently — no full tree rebuild
                      ValueListenableBuilder<int>(
                        valueListenable: _unreadNotifier,
                        builder: (_, count, __) => _Badge(count: count),
                      ),
                    ],
                  ),
                ),

                // Body
                Expanded(
                  child: _loading
                      ? const _ShimmerList()
                      : _error != null
                          ? _EmptyState(
                              title: _error!,
                              subtitle: 'Pull to refresh',
                              onRetry: _fetchFirst,
                            )
                          : RefreshIndicator(
                              color: _pink,
                              onRefresh: _fetchFirst,
                              child: ListView.builder(
                                controller: _scroll,
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
                                // +2: header row + footer row
                                itemCount: visibleItems.isEmpty
                                    ? 2
                                    : visibleItems.length + 2,
                                itemBuilder: (context, i) {
                                  // Header filter bar
                                  if (i == 0) {
                                    return ValueListenableBuilder<int>(
                                      valueListenable: _unreadNotifier,
                                      builder: (_, unread, __) => _HeaderFilterBar(
                                        totalCount: _items.length,
                                        unreadCount: unread,
                                        showUnreadOnly: _showUnreadOnly,
                                        onChanged: (v) =>
                                            setState(() => _showUnreadOnly = v),
                                      ),
                                    );
                                  }

                                  // Empty state (inside list so pull-to-refresh works)
                                  if (visibleItems.isEmpty && i == 1) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 48),
                                      child: _EmptyState(
                                        title: _showUnreadOnly
                                            ? 'No unread notifications'
                                            : 'No notifications yet',
                                        subtitle: _showUnreadOnly
                                            ? "You're up to date."
                                            : "We'll let you know when there's something new.",
                                        onRetry: _fetchFirst,
                                      ),
                                    );
                                  }

                                  // Footer
                                  if (i == visibleItems.length + 1) {
                                    if (_loadingMore) {
                                      return const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 18),
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            color: _pink,
                                          ),
                                        ),
                                      );
                                    }
                                    if (!_hasMore && _items.isNotEmpty) {
                                      return const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 18),
                                        child: Center(
                                          child: Text(
                                            "You're all caught up",
                                            style: TextStyle(color: Colors.white70),
                                          ),
                                        ),
                                      );
                                    }
                                    return const SizedBox(height: 10);
                                  }

                                  // Tile — wrapped in RepaintBoundary so scrolling
                                  // doesn't trigger unnecessary repaints of siblings.
                                  final item = visibleItems[i - 1];
                                  return RepaintBoundary(
                                    child: _NotifTile(
                                      key: ValueKey(item.notificationId),
                                      item: item,
                                      onTap: () => _onTap(item),
                                    ),
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Background (const — never rebuilds) ──────────────────────────────────────
class _Background extends StatelessWidget {
  const _Background();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F171E), Color(0xFF1A242F), Color(0xFF1F2D3A)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Positioned(
          top: -80,
          left: -50,
          child: _GlowCircle(size: 220, color: Color(0xFF0077A8), opacity: .22),
        ),
        Positioned(
          top: 120,
          right: -60,
          child: _GlowCircle(size: 180, color: Color(0xFF00A8E1), opacity: .16),
        ),
      ],
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  const _GlowCircle({required this.size, required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(opacity),
        ),
      );
}

// ─── Badge ────────────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    final text = count <= 0 ? '0' : (count > 99 ? '99+' : '$count');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: count > 0 ? Colors.redAccent : Colors.white12,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ─── Shimmer loading list ─────────────────────────────────────────────────────
class _ShimmerList extends StatefulWidget {
  const _ShimmerList();

  @override
  State<_ShimmerList> createState() => _ShimmerListState();
}

class _ShimmerListState extends State<_ShimmerList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final shimmerColor =
            Color.lerp(const Color(0xFF1A2533), const Color(0xFF374151), _anim.value)!;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 20),
          itemCount: 7,
          itemBuilder: (_, __) => _ShimmerTile(color: shimmerColor),
        );
      },
    );
  }
}

class _ShimmerTile extends StatelessWidget {
  final Color color;
  const _ShimmerTile({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 13,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 11,
                  width: MediaQuery.of(context).size.width * .55,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Notification tile ────────────────────────────────────────────────────────
class _NotifTile extends StatelessWidget {
  final NotifItem item;
  final VoidCallback onTap;

  const _NotifTile({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !item.isRead;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: isUnread
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A2533), Color(0xFF0F172A)],
              )
            : null,
        color: isUnread ? null : const Color(0xFF1A2533),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUnread
              ? Colors.deepPurpleAccent.withOpacity(.5)
              : Colors.white10,
          width: isUnread ? 1.2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isUnread ? .35 : .22),
            blurRadius: isUnread ? 18 : 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          splashColor: Colors.white10,
          highlightColor: Colors.white.withOpacity(.04),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AvatarDot(unread: isUnread),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title.isEmpty ? 'JINNTV' : item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: isUnread
                                    ? FontWeight.w900
                                    : FontWeight.w700,
                                fontSize: 15.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _timeAgo(item.createdAt),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _StatusPill(status: item.status),
                          if (isUnread) ...[
                            const SizedBox(width: 8),
                            const Text(
                              'NEW',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                          const Spacer(),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Avatar dot ───────────────────────────────────────────────────────────────
class _AvatarDot extends StatelessWidget {
  final bool unread;
  const _AvatarDot({required this.unread});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.notifications_rounded, color: Colors.white70),
        ),
        if (unread)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF0F171E), width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Status pill ──────────────────────────────────────────────────────────────
class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final text = status.trim().isEmpty ? 'sent' : status.toLowerCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─── Header filter bar ────────────────────────────────────────────────────────
class _HeaderFilterBar extends StatelessWidget {
  final int totalCount;
  final int unreadCount;
  final bool showUnreadOnly;
  final ValueChanged<bool> onChanged;

  const _HeaderFilterBar({
    required this.totalCount,
    required this.unreadCount,
    required this.showUnreadOnly,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasUnread ? 'You have $unreadCount unread' : "You're all caught up",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _FilterChipButton(
                label: 'All',
                count: totalCount,
                isSelected: !showUnreadOnly,
                onTap: () => onChanged(false),
              ),
              const SizedBox(width: 8),
              _FilterChipButton(
                label: 'Unread',
                count: unreadCount,
                isSelected: showUnreadOnly,
                onTap: hasUnread ? () => onChanged(true) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Filter chip button ───────────────────────────────────────────────────────
class _FilterChipButton extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback? onTap;

  const _FilterChipButton({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final bg = isSelected ? Colors.white : const Color(0xFF1A2533);
    final txt = isSelected ? Colors.black : Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? bg : const Color(0xFF050816),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: enabled ? txt : Colors.white38,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: enabled
                    ? (isSelected ? Colors.black : Colors.white12)
                    : Colors.white10,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: TextStyle(
                  color: enabled
                      ? (isSelected ? Colors.white : Colors.white70)
                      : Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final Future<void> Function() onRetry;

  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 70),
        const Icon(Icons.notifications_off, size: 48, color: Colors.white54),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 18),
        Center(
          child: OutlinedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}