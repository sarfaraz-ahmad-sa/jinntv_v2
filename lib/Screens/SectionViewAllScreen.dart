import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'home_models.dart';
import 'video_player_screen.dart';
import 'MyPlayListScreen.dart';
import '../db/db_helper.dart';

// ─────────────────────────────────────────────
//  SectionViewAllScreen  –  YouTube style
// ─────────────────────────────────────────────
class SectionViewAllScreen extends StatefulWidget {
  final String title;
  final List<HomeVideoItem> items;
  final String Function(String) thumbToBg;

  const SectionViewAllScreen({
    super.key,
    required this.title,
    required this.items,
    required this.thumbToBg,
  });

  @override
  State<SectionViewAllScreen> createState() => _SectionViewAllScreenState();
}

class _SectionViewAllScreenState extends State<SectionViewAllScreen> {
  // ── palette (same as MyPlayListScreen) ───────
  static const _bg      = Color(0xFF0F171E);
  static const _surface = Color(0xFF1A1A1A);
  static const _card    = Color(0xFF212121);
  static const _divider = Color(0xFF2A2A2A);

  // ── state ────────────────────────────────────
  bool   _grid      = true;
  bool   _searching = false;
  String _q         = '';

  late final TextEditingController _searchCtrl;
  late final ScrollController      _scrollCtrl;

  // ── lifecycle ────────────────────────────────
  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: _q);
    _scrollCtrl = ScrollController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── search ───────────────────────────────────
  void _toggleSearch([bool? v]) {
    setState(() {
      _searching = v ?? !_searching;
      if (_searching) {
        _searchCtrl
          ..text = _q
          ..selection = TextSelection.fromPosition(
              TextPosition(offset: _searchCtrl.text.length));
      } else {
        FocusManager.instance.primaryFocus?.unfocus();
      }
    });
  }

  void _applySearch(String v) => setState(() => _q = v.trim());

  List<HomeVideoItem> get _filtered {
    final q = _q.toLowerCase();
    if (q.isEmpty) return widget.items;
    return widget.items
        .where((v) => v.title.toLowerCase().contains(q))
        .toList();
  }

  // ── helpers ───────────────────────────────────
  String _viewsText(HomeVideoItem v) {
    try {
      final dyn = v as dynamic;
      final views = dyn.views ?? dyn.viewCount ?? dyn.totalViews ?? dyn.total_views;
      if (views == null) return '';
      if (views is int) return _formatNum(views);
      final s = views.toString().trim();
      if (s.isEmpty) return '';
      return s.toLowerCase().contains('view') ? s : s;
    } catch (_) { return ''; }
  }

  String _formatNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  String _durationText(HomeVideoItem v) {
    try {
      final dyn = v as dynamic;
      final d = dyn.duration ?? dyn.durationText ?? dyn.length ?? dyn.videoLength;
      if (d == null) return '';
      return d.toString().trim();
    } catch (_) { return ''; }
  }

  // ── image ─────────────────────────────────────
  Widget _netImage(String url) {
    if (url.trim().isEmpty) {
      return Container(color: _card,
        child: const Icon(Icons.videocam_off_outlined,
            color: Colors.white38, size: 22));
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: 480,
      fadeInDuration: const Duration(milliseconds: 120),
      placeholder: (_, __) => Container(color: _card),
      errorWidget: (_, __, ___) => Container(color: _card,
        child: const Icon(Icons.broken_image_outlined,
            color: Colors.white38, size: 20)),
    );
  }

  // ── navigation ───────────────────────────────
  void _open(HomeVideoItem v) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => VideoPlayerScreen(
        title:     v.title,
        youtubeId: v.youtubeId,
        mp4Url:    v.mp4Url,
        videoId:   v.id,
      ),
    ));
  }

  // ── menu ─────────────────────────────────────
  void _openVideoMenu(HomeVideoItem v) {
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
            // handle + preview row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Column(children: [
                Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99)),
                ),
                Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: 80, height: 46,
                      child: _netImage(widget.thumbToBg(v.thumb)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(v.title,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white, fontSize: 13,
                        fontWeight: FontWeight.w600)),
                  ),
                ]),
              ]),
            ),
            const Divider(color: _divider, height: 16),
            _menuTile(Icons.playlist_add_rounded, 'Save to playlist', () async {
              Navigator.pop(context);
              final userId = await DBHelper.currentUserId();
              final ok = await DBHelper.addToPlaylist(
                userId:   userId,
                videoId:  v.id.toString(),
                title:    v.title,
                thumb:    v.thumb,
                youtubeId: v.youtubeId,
                mp4Url:   v.mp4Url,
              );
              if (!context.mounted) return;
              _snack(ok ? 'Saved to playlist' : 'Already in playlist');
            }),
            _menuTile(Icons.video_library_outlined, 'Open My Playlist', () {
              Navigator.pop(context);
              Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MyPlayListScreen()));
            }),
            _menuTile(Icons.share_outlined, 'Share', () => Navigator.pop(context)),
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
      title: Text(label,
        style: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.w500)),
      onTap: onTap,
      horizontalTitleGap: 8,
      dense: true,
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
        style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: _surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    ));
  }

  // ── duration badge ────────────────────────────
  Widget _durBadge(String dur) {
    if (dur.isEmpty) return const SizedBox.shrink();
    return Positioned(
      right: 6, bottom: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.80),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(dur,
          style: const TextStyle(
            color: Colors.white, fontSize: 11,
            fontWeight: FontWeight.w700)),
      ),
    );
  }

  // ── list view ────────────────────────────────
  Widget _listView(List<HomeVideoItem> data) {
    return ListView.builder(
      key: const ValueKey('yt_list'),
      controller: _scrollCtrl,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: data.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) return _sectionHeader(data.length);
        return _listTile(data[i - 1]);
      },
    );
  }

  Widget _listTile(HomeVideoItem v) {
    final poster = widget.thumbToBg(v.thumb);
    final views  = _viewsText(v);
    final dur    = _durationText(v);

    return RepaintBoundary(
      child: InkWell(
        onTap: () => _open(v),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // thumbnail
              Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 160, height: 92,
                    child: _netImage(poster),
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
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ),
                _durBadge(dur),
              ]),
              const SizedBox(width: 10),

              // info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.title,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white, fontSize: 13,
                        fontWeight: FontWeight.w500, height: 1.35)),
                    const SizedBox(height: 4),
                    Text('JinnTV',
                      style: const TextStyle(
                        color: Colors.white54, fontSize: 12)),
                    if (views.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('$views views',
                        style: const TextStyle(
                          color: Colors.white38, fontSize: 12)),
                    ],
                  ],
                ),
              ),

              // more
              InkWell(
                onTap: () => _openVideoMenu(v),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.more_vert_rounded,
                      color: Colors.white.withOpacity(0.7), size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── grid view ────────────────────────────────
  Widget _gridView(List<HomeVideoItem> data, int cross) {
    return CustomScrollView(
      key: const ValueKey('yt_grid'),
      controller: _scrollCtrl,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _sectionHeader(data.length)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _gridCard(data[i]),
              childCount: data.length,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cross,
              crossAxisSpacing: 10,
            ),
          ),
        ),
      ],
    );
  }

  Widget _gridCard(HomeVideoItem v) {
    final poster = widget.thumbToBg(v.thumb);
    final views  = _viewsText(v);
    final dur    = _durationText(v);

    return RepaintBoundary(
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _open(v),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _netImage(poster),
                ),
              ),
              // more button
              Positioned(
                top: 4, right: 4,
                child: InkWell(
                  onTap: () => _openVideoMenu(v),
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.more_vert_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
              ),
              // play
              Positioned.fill(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.48),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ),
              _durBadge(dur),
            ]),
            const SizedBox(height: 6),
            Text(v.title,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white, fontSize: 12.5,
                fontWeight: FontWeight.w500, height: 1.3)),
            const SizedBox(height: 2),
            Text(
              views.isNotEmpty ? 'JinnTV • $views views' : 'JinnTV',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ── section header ────────────────────────────
  Widget _sectionHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$count video${count == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: Colors.white, fontSize: 15,
                  fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(widget.title,
                style: const TextStyle(
                  color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
        _ytChip(
          label: _grid ? 'List' : 'Grid',
          icon: _grid ? Icons.view_agenda_outlined : Icons.grid_view_rounded,
          onTap: () => setState(() => _grid = !_grid),
        ),
      ]),
    );
  }

  Widget _ytChip({
    required String   label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 5),
          Text(label,
            style: const TextStyle(
              color: Colors.white70, fontSize: 12,
              fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  // ── empty state ───────────────────────────────
  Widget _emptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: _surface, shape: BoxShape.circle),
            child: const Icon(Icons.live_tv_rounded,
                size: 44, color: Colors.white38),
          ),
          const SizedBox(height: 20),
          Text(
            _q.trim().isEmpty ? 'No videos found' : 'No results for "$_q"',
            style: const TextStyle(
              color: Colors.white, fontSize: 16,
              fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            _q.trim().isEmpty
                ? 'Try again later or check your connection'
                : 'Try a different keyword',
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
        ],
      ),
    ),
  );

  // ── app bar ───────────────────────────────────
  PreferredSizeWidget _appBar() => AppBar(
    backgroundColor: Colors.black,
    elevation: 0,
    scrolledUnderElevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
      onPressed: () => Navigator.pop(context),
    ),
    titleSpacing: 0,
    title: _searching
        ? _searchField()
        : Text(widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white, fontSize: 17,
              fontWeight: FontWeight.w600)),
    actions: [
      IconButton(
        icon: const Icon(Icons.search_rounded, color: Colors.white),
        onPressed: () => _toggleSearch(true),
      ),
      if (_searching)
        IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () { _toggleSearch(false); _applySearch(''); },
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
        hintText: 'Search in ${widget.title}',
        hintStyle: const TextStyle(color: Colors.white38),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        prefixIcon: const Icon(Icons.search_rounded,
            color: Colors.white38, size: 18),
        suffixIcon: _q.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded,
                    color: Colors.white54, size: 18),
                onPressed: () { _searchCtrl.clear(); _applySearch(''); },
              )
            : null,
      ),
      onChanged: (v) => _applySearch(v),
      onSubmitted: (_) => _toggleSearch(false),
    ),
  );

  // ── build ─────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final w    = MediaQuery.of(context).size.width;
    final data = _filtered;
    final cross = w >= 900 ? 4 : (w >= 650 ? 3 : 2);

    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar(),
      body: data.isEmpty
          ? _emptyState()
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _grid
                  ? _gridView(data, cross)
                  : _listView(data),
            ),
    );
  }
}