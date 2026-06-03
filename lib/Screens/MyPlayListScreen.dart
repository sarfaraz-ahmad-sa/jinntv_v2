import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../db/db_helper.dart';
import 'video_player_screen.dart';

// ─────────────────────────────────────────────
//  MyPlayListScreen  –  YouTube Downloads style
// ─────────────────────────────────────────────
class MyPlayListScreen extends StatefulWidget {
  final bool isRootTab;
  final VoidCallback? onBackToHome;

  const MyPlayListScreen({
    super.key,
    this.isRootTab = false,
    this.onBackToHome,
  });

  @override
  State<MyPlayListScreen> createState() => _MyPlayListScreenState();
}

class _MyPlayListScreenState extends State<MyPlayListScreen>
    with SingleTickerProviderStateMixin {
  static const _bg = Color(0xFF0F0F0F);
  static const _surface = Color(0xFF1A1A1A);
  static const _card = Color(0xFF212121);
  static const _accent = Color(0xFFFF0000);
  static const _divider = Color(0xFF2A2A2A);

  bool _loading = true;
  bool _busy = false;
  bool _leaving = false;
  bool _grid = false;
  bool _searching = false;
  bool _selectMode = false;

  String _q = '';
  String _sort = 'Newest';
  String _userId = '';

  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _filtered = [];
  final Set<String> _selected = {};

  late final TextEditingController _searchCtrl;
  late final ScrollController _scrollCtrl;
  late final AnimationController _fabAnim;

  bool _fabVisible = true;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _scrollCtrl = ScrollController()..addListener(_onScroll);
    _fabAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1,
    );
    _load(initial: true);
  }

  @override
  void dispose() {
    _leaving = true;
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _fabAnim.dispose();
    super.dispose();
  }

  void _onScroll() {
    final dir = _scrollCtrl.position.userScrollDirection;
    if (dir == ScrollDirection.reverse && _fabVisible) {
      _fabVisible = false;
      _fabAnim.reverse();
    } else if (dir == ScrollDirection.forward && !_fabVisible) {
      _fabVisible = true;
      _fabAnim.forward();
    }
  }

  Future<void> _load({bool initial = false}) async {
    if (_busy || _leaving) return;
    if (initial && mounted) setState(() => _loading = true);
    try {
      final uid = await DBHelper.currentUserId();
      if (_leaving || !mounted) return;
      final data = await DBHelper.getPlaylist(uid);
      if (_leaving || !mounted) return;
      _userId = uid;
      _rows = List<Map<String, dynamic>>.from(data);
      _rebuildFiltered();
    } catch (e) {
      if (mounted && !_leaving) {
        _snack('Failed to load: $e', error: true);
      }
    } finally {
      if (mounted && !_leaving) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    if (_busy || _leaving) return;
    await _load();
    if (mounted && !_leaving) setState(() {});
  }

  void _rebuildFiltered() {
    final q = _q.trim().toLowerCase();
    List<Map<String, dynamic>> list = q.isEmpty
        ? List.from(_rows)
        : _rows.where((r) => _titleOf(r).toLowerCase().contains(q)).toList();

    if (_sort == 'A-Z') {
      list.sort((a, b) =>
          _titleOf(a).toLowerCase().compareTo(_titleOf(b).toLowerCase()));
    } else if (_sort == 'Z-A') {
      list.sort((a, b) =>
          _titleOf(b).toLowerCase().compareTo(_titleOf(a).toLowerCase()));
    } else {
      DateTime _dt(dynamic v) {
        final s = (v ?? '').toString().trim();
        return s.isEmpty
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : DateTime.tryParse(s) ?? DateTime.fromMillisecondsSinceEpoch(0);
      }

      list.sort((a, b) => _dt(b['created_at'] ?? b['createdAt'])
          .compareTo(_dt(a['created_at'] ?? a['createdAt'])));
    }
    _filtered = list;
  }

  String _idOf(Map<String, dynamic> r) => (r['video_id'] ?? '').toString();
  String _titleOf(Map<String, dynamic> r) => (r['title'] ?? '').toString();

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString().trim());
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted || _leaving) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: error ? Colors.red.shade900 : _surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      ),
    );
  }

  void _toggleSearch([bool? v]) {
    if (_busy || _leaving) return;
    setState(() {
      _searching = v ?? !_searching;
      if (_searching) {
        _searchCtrl
          ..text = _q
          ..selection = TextSelection.fromPosition(
            TextPosition(offset: _searchCtrl.text.length),
          );
      } else {
        FocusManager.instance.primaryFocus?.unfocus();
      }
    });
  }

  void _applySearch(String v) {
    _q = v;
    _rebuildFiltered();
    if (mounted && !_leaving) setState(() {});
  }

  Future<void> _handleBack() async {
    if (_busy) return;

    if (_selectMode) {
      _toggleSelectMode(false);
      return;
    }

    if (widget.isRootTab) {
      widget.onBackToHome?.call();
      return;
    }

    _leaving = true;
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _open(Map<String, dynamic> r) {
    if (_busy || _leaving) return;
    if (_selectMode) {
      _toggleSelect(r);
      return;
    }
    _leaving = true;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          title: _titleOf(r),
          youtubeId: (r['youtube_id'] ?? '').toString(),
          mp4Url: (r['mp4_url'] ?? '').toString(),
          videoId: _toInt(r['video_id']),
        ),
      ),
    ).then((_) {
      if (mounted) _leaving = false;
    });
  }

  Future<void> _remove(String videoId) async {
    if (_busy || _leaving) return;
    setState(() => _busy = true);
    try {
      await DBHelper.removeFromPlaylist(userId: _userId, videoId: videoId);
      _rows.removeWhere((e) => _idOf(e) == videoId);
      _selected.remove(videoId);
      if (_selected.isEmpty) _selectMode = false;
      _rebuildFiltered();
      if (!mounted || _leaving) return;
      setState(() {});
      _snack('Removed from playlist');
    } catch (e) {
      _snack('Remove failed: $e', error: true);
    } finally {
      if (mounted && !_leaving) setState(() => _busy = false);
    }
  }

  Future<void> _removeMany(List<String> ids) async {
    if (_busy || _leaving || ids.isEmpty) return;
    setState(() => _busy = true);
    try {
      for (final id in ids) {
        await DBHelper.removeFromPlaylist(userId: _userId, videoId: id);
      }
      final s = ids.toSet();
      _rows.removeWhere((e) => s.contains(_idOf(e)));
      _selected.clear();
      _selectMode = false;
      _rebuildFiltered();
      if (!mounted || _leaving) return;
      setState(() {});
      _snack('Removed ${ids.length} video(s)');
    } catch (e) {
      _snack('Bulk remove failed: $e', error: true);
    } finally {
      if (mounted && !_leaving) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmSheet({
    required String title,
    required String body,
    String confirmLabel = 'Remove',
  }) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Colors.white12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(
                        confirmLabel,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return ok == true;
  }

  Future<void> _confirmRemove(String id) async {
    if (await _confirmSheet(
      title: 'Remove from playlist?',
      body: 'This video will be removed from your playlist.',
    )) {
      await _remove(id);
    }
  }

  void _toggleSelectMode([bool? v]) {
    if (_busy || _leaving) return;
    setState(() {
      _selectMode = v ?? !_selectMode;
      if (!_selectMode) _selected.clear();
    });
  }

  void _toggleSelect(Map<String, dynamic> r) {
    final id = _idOf(r);
    setState(() {
      _selectMode = true;
      if (_selected.contains(id)) {
        _selected.remove(id);
        if (_selected.isEmpty) _selectMode = false;
      } else {
        _selected.add(id);
      }
    });
  }

  void _openRowMenu(Map<String, dynamic> r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          width: 80,
                          height: 46,
                          child: _thumbWidget((r['thumb'] ?? '').toString()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _titleOf(r),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: _divider, height: 16),
            _menuTile(Icons.play_circle_outline_rounded, 'Play', () {
              Navigator.pop(context);
              _open(r);
            }),
            _menuTile(Icons.check_circle_outline_rounded, 'Select', () {
              Navigator.pop(context);
              _toggleSelect(r);
            }),
            _menuTile(Icons.delete_outline_rounded, 'Remove from playlist', () {
              Navigator.pop(context);
              _confirmRemove(_idOf(r));
            }, color: Colors.red.shade400),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _menuTile(IconData icon, String label, VoidCallback onTap,
      {Color? color}) {
    final c = color ?? Colors.white;
    return ListTile(
      leading: Icon(icon, color: c, size: 22),
      title: Text(
        label,
        style:
            TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.w500),
      ),
      onTap: onTap,
      horizontalTitleGap: 8,
      dense: true,
    );
  }

  void _openSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Sort by',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            ...['Newest', 'A-Z', 'Z-A'].map(
              (s) => ListTile(
                leading: Icon(
                  _sort == s
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: _sort == s ? Colors.white : Colors.white38,
                  size: 20,
                ),
                title: Text(
                  s,
                  style: TextStyle(
                    color: _sort == s ? Colors.white : Colors.white70,
                    fontWeight:
                        _sort == s ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _sort = s;
                    _rebuildFiltered();
                  });
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _thumbWidget(String url) {
    if (url.isEmpty) {
      return Container(
        color: _card,
        child: const Icon(
          Icons.videocam_off_outlined,
          color: Colors.white38,
          size: 22,
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: 480,
      fadeInDuration: const Duration(milliseconds: 120),
      placeholder: (_, __) => Container(color: _card),
      errorWidget: (_, __, ___) => Container(
        color: _card,
        child: const Icon(
          Icons.broken_image_outlined,
          color: Colors.white38,
          size: 20,
        ),
      ),
    );
  }

  Widget _listItem(Map<String, dynamic> r) {
    final videoId = _idOf(r);
    final title = _titleOf(r);
    final thumb = (r['thumb'] ?? '').toString();
    final selected = _selected.contains(videoId);

    return RepaintBoundary(
      child: Dismissible(
        key: ValueKey('pl_$videoId'),
        direction:
            _selectMode ? DismissDirection.none : DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: Colors.red.shade900.withOpacity(0.85),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 26),
              SizedBox(height: 4),
              Text(
                'Remove',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        confirmDismiss: (_) => _confirmSheet(
          title: 'Remove from playlist?',
          body: 'This video will be removed from your playlist.',
        ),
        onDismissed: (_) => _remove(videoId),
        child: InkWell(
          onTap: () => _open(r),
          onLongPress: () => _toggleSelect(r),
          child: Container(
            color:
                selected ? Colors.white.withOpacity(0.05) : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectMode) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 14, right: 6),
                    child: _selectCircle(selected),
                  ),
                ],
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        width: 160,
                        height: 92,
                        child: _thumbWidget(thumb),
                      ),
                    ),
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'JinnTV',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: const [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 12,
                            color: Colors.white38,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Saved',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => _openRowMenu(r),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.more_vert_rounded,
                      color: Colors.white.withOpacity(0.7),
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _gridItem(Map<String, dynamic> r) {
    final id = _idOf(r);
    final title = _titleOf(r);
    final thumb = (r['thumb'] ?? '').toString();
    final selected = _selected.contains(id);

    return RepaintBoundary(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _open(r),
        onLongPress: () => _toggleSelect(r),
        child: Container(
          color:
              selected ? Colors.white.withOpacity(0.05) : Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _thumbWidget(thumb),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: () => _openRowMenu(r),
                      borderRadius: BorderRadius.circular(99),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.more_vert_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.50),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  if (_selectMode)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: _selectCircle(selected),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'JinnTV',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectCircle(bool selected) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? Colors.white : Colors.transparent,
          border: Border.all(
            color: selected ? Colors.white : Colors.white54,
            width: 1.8,
          ),
        ),
        child: selected
            ? const Icon(Icons.check_rounded, color: Colors.black, size: 14)
            : null,
      );

  Widget _sectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_filtered.length} video${_filtered.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sorted by: $_sort',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          _ytChip(
            label: _sort,
            icon: Icons.swap_vert_rounded,
            onTap: _openSortSheet,
          ),
          const SizedBox(width: 8),
          _ytChip(
            label: _grid ? 'List' : 'Grid',
            icon: _grid ? Icons.view_agenda_outlined : Icons.grid_view_rounded,
            onTap: () => setState(() => _grid = !_grid),
          ),
        ],
      ),
    );
  }

  Widget _ytChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _busy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _surface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.download_for_offline_outlined,
                  size: 48,
                  color: Colors.white38,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _q.trim().isEmpty
                    ? 'Your playlist is empty'
                    : 'No results for "$_q"',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _q.trim().isEmpty
                    ? 'Save videos to watch them later'
                    : 'Try a different keyword',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ),
      );

  PreferredSizeWidget _appBar() => AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: _busy ? null : _handleBack,
        ),
        titleSpacing: 0,
        title: _searching
            ? _searchField()
            : const Text(
                'My Playlist',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
        actions: [
          if (!_searching && !_selectMode) ...[
            IconButton(
              icon: const Icon(Icons.search_rounded, color: Colors.white),
              onPressed: _busy ? null : () => _toggleSearch(true),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              onPressed: _busy ? null : _openSortSheet,
            ),
          ],
          if (_searching)
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () {
                _toggleSearch(false);
                _applySearch('');
              },
            ),
          if (_selectMode)
            TextButton(
              onPressed: () => _toggleSelectMode(false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      );

  Widget _searchField() => Container(
        height: 38,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: TextField(
          controller: _searchCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          cursorColor: Colors.white,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search in playlist',
            hintStyle: const TextStyle(color: Colors.white38),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Colors.white38,
              size: 18,
            ),
            suffixIcon: _q.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.clear_rounded,
                      color: Colors.white54,
                      size: 18,
                    ),
                    onPressed: () {
                      _searchCtrl.clear();
                      _applySearch('');
                    },
                  )
                : null,
          ),
          onChanged: _applySearch,
          onSubmitted: (_) => _toggleSearch(false),
        ),
      );

  Widget _selectionBar() {
    if (!_selectMode) return const SizedBox.shrink();
    final count = _selected.length;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(
          color: _surface,
          border: Border(top: BorderSide(color: _divider)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$count selected',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () {
                final visible = _filtered.map(_idOf).toSet();
                setState(() => _selected.addAll(visible));
              },
              icon: const Icon(Icons.select_all_rounded, size: 18),
              label: const Text(
                'Select all',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            const SizedBox(width: 6),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: count == 0
                  ? null
                  : () async {
                      if (await _confirmSheet(
                        title: 'Remove $count video${count > 1 ? 's' : ''}?',
                        body:
                            'Selected videos will be removed from your playlist.',
                      )) {
                        await _removeMany(_selected.toList());
                      }
                    },
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(
                'Remove ($count)',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(double w) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_filtered.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        color: Colors.white,
        backgroundColor: _surface,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 100),
            _emptyState(),
          ],
        ),
      );
    }

    final crossCount = w >= 900 ? 4 : (w >= 600 ? 3 : 2);

    return RefreshIndicator(
      onRefresh: _refresh,
      color: Colors.white,
      backgroundColor: _surface,
      child: _grid
          ? CustomScrollView(
              controller: _scrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _sectionHeader()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _gridItem(_filtered[i]),
                      childCount: _filtered.length,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossCount,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.82,
                    ),
                  ),
                ),
              ],
            )
          : ListView.builder(
              controller: _scrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _filtered.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) return _sectionHeader();
                return _listItem(_filtered[i - 1]);
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return WillPopScope(
      onWillPop: () async {
        if (_selectMode) {
          _toggleSelectMode(false);
          return false;
        }
        if (_busy) return false;
        if (widget.isRootTab) {
          widget.onBackToHome?.call();
          return false;
        }
        _leaving = true;
        return true;
      },
      child: Scaffold(
        backgroundColor: _bg,
        appBar: _appBar(),
        bottomNavigationBar: _selectionBar(),
        body: _body(w),
      ),
    );
  }
}