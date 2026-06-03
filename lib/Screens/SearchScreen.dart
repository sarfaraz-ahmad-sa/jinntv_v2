import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'home_repo.dart';
import 'home_models.dart';
import 'video_player_screen.dart';
import 'app_shell.dart';
import '../theme/jinntv_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PREFS KEYS
// ─────────────────────────────────────────────────────────────────────────────

const String _kRecentKey = "jinntv_recent_searches";
const String _kViewKey   = "jinntv_search_view_mode"; // "grid" | "list"

// ─────────────────────────────────────────────────────────────────────────────
//  SEARCH SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with TickerProviderStateMixin {
  // ── Palette
  static const Color _bg      = Color(0xFF08090C);
  static const Color _divider = Color(0x14FFFFFF);
  static const Color _accent  = JinnTvTheme.pink;

  // ── API
  static const String _api   = "https://jinntv.com/api_forApp/search.php";
  static const int    _limit = 20;

  // ── Controllers
  final TextEditingController _ctrl   = TextEditingController();
  final FocusNode             _focus  = FocusNode();
  final ScrollController      _scroll = ScrollController();

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;
  late final AnimationController _shimmerCtrl;

  // ── Search state
  Timer?       _debounce;
  http.Client? _client;

  bool    _loading     = false;
  bool    _loadingMore = false;
  bool    _searched    = false;
  bool    _hasMore     = false;
  bool    _focused     = false;

  String  _query           = "";
  String? _error;
  String? _friendlyMessage;
  bool    _fallbackUsed    = false;

  int _page        = 1;
  int _searchToken = 0;

  List<VideoItem> _results        = [];
  List<String>    _recentSearches = [];
  List<String>    _apiSuggestions = [];

  // ── In-memory cache
  final Map<String, List<VideoItem>> _queryCache       = {};
  final Map<String, List<String>>    _suggestionsCache = {};
  final Map<String, String?>         _friendlyCache    = {};
  final Map<String, bool>            _fallbackCache    = {};
  final Map<String, DateTime>        _cacheTime        = {};
  static const Duration _cacheTtl = Duration(minutes: 10);

  // ── Catalog
  late final HomeRepository _homeRepo;
  bool                      _catalogLoading = true;
  List<CatalogCategory>     _catalogCats    = [];

  // ── View preference (persisted via SharedPreferences)
  bool _gridView = true; // default; overridden by _loadPrefs()

  // ──────────────────────────────────────────────────────────────────────────
  //  LIFECYCLE
  // ──────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _client   = http.Client();
    _homeRepo = HomeRepository(ApiClient(baseUrl: "https://jinntv.com"));

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat();

    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });

    _scroll.addListener(_onScroll);
    _loadPrefs();
    _loadCatalog();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _client?.close();
    _ctrl.dispose();
    _focus.dispose();
    _scroll.dispose();
    _fadeCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  PREFS — recent searches + view mode persisted together
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _loadPrefs() async {
    final prefs   = await SharedPreferences.getInstance();
    final recent  = prefs.getStringList(_kRecentKey) ?? [];
    final viewStr = prefs.getString(_kViewKey); // null on first launch
    if (!mounted) return;
    setState(() {
      _recentSearches = recent;
      if (viewStr != null) _gridView = (viewStr == "grid");
    });
  }

  Future<void> _saveRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kRecentKey, _recentSearches);
  }

  Future<void> _saveViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kViewKey, _gridView ? "grid" : "list");
  }

  void _toggleView() {
    setState(() => _gridView = !_gridView);
    _saveViewMode(); // fire-and-forget
    HapticFeedback.selectionClick();
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  CATALOG
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _loadCatalog() async {
    try {
      final resp     = await _homeRepo.fetchCatalog(categoryId: 0, q: "");
      final filtered = resp.categories
          .where((c) => c.name.toLowerCase() != "all" && c.id != 0)
          .take(12)
          .toList();
      if (!mounted) return;
      setState(() { _catalogCats = filtered; _catalogLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _catalogLoading = false);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  HELPERS
  // ──────────────────────────────────────────────────────────────────────────

  void _onScroll() {
    if (!_scroll.hasClients || _loading || _loadingMore || !_hasMore) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) _loadMore();
  }

  bool _isCacheFresh(String q) {
    final t = _cacheTime[q];
    return t != null && DateTime.now().difference(t) <= _cacheTtl;
  }

  void _addToRecent(String q) {
    final n = q.trim();
    if (n.isEmpty) return;
    _recentSearches
      ..remove(n)
      ..insert(0, n);
    if (_recentSearches.length > 15) {
      _recentSearches = _recentSearches.take(15).toList();
    }
    _saveRecentSearches();
  }

  List<String> _buildSuggestions() {
    final q = _ctrl.text.trim().toLowerCase();
    final Set<String> s = {};
    s.addAll(_apiSuggestions.where((e) => e.trim().isNotEmpty));
    if (q.isEmpty) {
      s.addAll(_recentSearches);
      for (final cat in _catalogCats) {
        if (cat.name.trim().isNotEmpty) s.add(cat.name.trim());
      }
      return s.take(12).toList();
    }
    for (final item in _recentSearches) {
      if (item.toLowerCase().contains(q)) s.add(item);
    }
    for (final cat in _catalogCats) {
      if (cat.name.toLowerCase().contains(q)) s.add(cat.name);
    }
    for (final entry in _queryCache.entries) {
      for (final item in entry.value) {
        final t = (item.title ?? "").trim();
        if (t.isNotEmpty && t.toLowerCase().contains(q)) {
          s.add(t);
          if (s.length >= 12) break;
        }
      }
      if (s.length >= 12) break;
    }
    return s.take(12).toList();
  }

  void _handleBack() {
    _focus.unfocus();
    if (Navigator.of(context).canPop()) { Navigator.of(context).pop(); return; }
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppShell()));
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  SEARCH
  // ──────────────────────────────────────────────────────────────────────────

  void _onChanged(String value) {
    final q = value.trim();
    _query  = q;
    _debounce?.cancel();

    if (q.isEmpty) {
      if (!mounted) return;
      setState(() {
        _searched = false; _loading = false; _loadingMore = false;
        _error = null; _friendlyMessage = null; _fallbackUsed = false;
        _results = []; _apiSuggestions = []; _page = 1; _hasMore = false;
      });
      _fadeCtrl.reverse();
      return;
    }

    if (_queryCache.containsKey(q) && _isCacheFresh(q)) {
      if (!mounted) return;
      setState(() {
        _searched = true; _loading = false; _error = null; _page = 1;
        _results         = List<VideoItem>.from(_queryCache[q]!);
        _apiSuggestions  = List<String>.from(_suggestionsCache[q] ?? []);
        _friendlyMessage = _friendlyCache[q];
        _fallbackUsed    = _fallbackCache[q] ?? false;
        _hasMore         = _results.length >= _limit;
      });
      _fadeCtrl.forward(from: 0);
    } else {
      if (mounted) setState(() => _apiSuggestions = _buildSuggestions());
    }

    _debounce = Timer(const Duration(milliseconds: 200), _submitSearch);
    if (mounted) setState(() {});
  }

  Future<void> _search(String q, {bool loadMore = false}) async {
    final int currentToken = ++_searchToken;
    final int nextPage     = loadMore ? _page + 1 : 1;
    if (!mounted) return;

    if (!loadMore) {
      try { _client?.close(); } catch (_) {}
      _client = http.Client();
    }

    setState(() {
      if (loadMore) {
        _loadingMore = true;
      } else {
        _loading = true; _searched = true; _error = null; _page = 1; _hasMore = false;
        if (!_queryCache.containsKey(q) || !_isCacheFresh(q)) _results = [];
      }
    });

    try {
      final uri = Uri.parse(_api).replace(queryParameters: {
        "keyword": q, "page": "$nextPage", "limit": "$_limit",
      });
      final response = await _client!.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) throw Exception("Server error ${response.statusCode}");

      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) throw Exception("Invalid response");

      final bool ok = decoded["ok"] == true;
      final data    = (decoded["data"] is Map<String, dynamic>)
          ? decoded["data"] as Map<String, dynamic> : <String, dynamic>{};

      final itemsRaw = data["items"];
      if (itemsRaw is! List) throw Exception("Invalid items");

      final List<String> suggestions = (data["suggestions"] is List)
          ? (data["suggestions"] as List).map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty).toList()
          : [];

      final List<VideoItem> items = (itemsRaw).whereType<Map>()
          .map((e) => VideoItem.fromJson(Map<String, dynamic>.from(e))).toList();

      final bool hasMore = data["has_more"] == true ||
          ((data["total_pages"] is num) && (data["page"] is num) &&
           (data["page"] as num) < (data["total_pages"] as num));

      final String? friendly     = data["friendly_message"]?.toString();
      final bool    fallbackUsed = data["fallback_used"] == true;

      if (!mounted || currentToken != _searchToken) return;

      setState(() {
        if (loadMore) { _results.addAll(items); _page = nextPage; }
        else {
          _results = items; _page = 1;
          _apiSuggestions = suggestions;
          _friendlyMessage = friendly; _fallbackUsed = fallbackUsed;
        }
        _loading = false; _loadingMore = false;
        _error = ok ? null : (decoded["message"]?.toString() ?? "Search issue");
        _hasMore = hasMore;
      });

      if (!loadMore) {
        _queryCache[q]       = List<VideoItem>.from(_results);
        _suggestionsCache[q] = List<String>.from(_apiSuggestions);
        _friendlyCache[q]    = _friendlyMessage;
        _fallbackCache[q]    = _fallbackUsed;
        _cacheTime[q]        = DateTime.now();
        _fadeCtrl.forward(from: 0);
      }
    } catch (_) {
      if (!mounted || currentToken != _searchToken) return;
      setState(() { _loading = false; _loadingMore = false;
        _error = "Check your connection and try again."; });
    }
  }

  void _submitSearch([String? overrideQuery]) {
    final q = (overrideQuery ?? _ctrl.text).trim();
    if (overrideQuery != null) {
      _ctrl.text = overrideQuery; _query = overrideQuery;
      _ctrl.selection = TextSelection.fromPosition(TextPosition(offset: _ctrl.text.length));
    }
    _debounce?.cancel();
    _focus.unfocus();
    if (q.isEmpty) {
      setState(() { _searched = false; _results = []; _apiSuggestions = [];
        _error = null; _friendlyMessage = null; _page = 1; _hasMore = false; });
      return;
    }
    _addToRecent(q);
    _search(q);
  }

  Future<void> _loadMore() => _search(_ctrl.text.trim(), loadMore: true);

  void _clearSearch() {
    _debounce?.cancel();
    _ctrl.clear(); _query = "";
    _fadeCtrl.reverse();
    if (!mounted) return;
    setState(() {
      _searched = false; _loading = false; _loadingMore = false;
      _error = null; _friendlyMessage = null; _fallbackUsed = false;
      _results = []; _apiSuggestions = []; _page = 1; _hasMore = false;
    });
    _focus.requestFocus();
  }

  void _fillSearch(String text) {
    _ctrl.text = text; _query = text;
    _ctrl.selection = TextSelection.fromPosition(TextPosition(offset: text.length));
    setState(() {});
  }

  void _removeRecent(String text) {
    setState(() => _recentSearches.remove(text));
    _saveRecentSearches();
  }

  void _clearAllRecent() {
    setState(() => _recentSearches.clear());
    _saveRecentSearches();
  }

  void _open(VideoItem v) {
    HapticFeedback.selectionClick();
    Navigator.push(context, MaterialPageRoute(builder: (_) =>
        VideoPlayerScreen(videoId: int.tryParse(v.id ?? "") ?? 0, title: v.title)));
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) { if (!didPop) _handleBack(); },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: _bg,
          body: Stack(
            children: [
              Positioned(top: -130, left: -80,
                  child: _Blob(size: 280, color: JinnTvTheme.purple, opacity: .16)),
              Positioned(top: 50, right: -90,
                  child: _Blob(size: 220, color: JinnTvTheme.pink, opacity: .10)),
              Positioned(bottom: -80, left: 20,
                  child: _Blob(size: 200, color: JinnTvTheme.blue, opacity: .07)),
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _SearchBar(
                      ctrl: _ctrl, focus: _focus, loading: _loading,
                      focused: _focused, query: _query, gridView: _gridView,
                      showToggle: _searched && _results.isNotEmpty,
                      onBack: _handleBack, onChanged: _onChanged,
                      onSubmit: (_) => _submitSearch(),
                      onClear: _clearSearch, onToggleView: _toggleView,
                    ),
                    Container(height: 1, color: _divider),
                    Expanded(child: _body(mq)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(MediaQueryData mq) {
    final currentText     = _ctrl.text.trim();
    final showSuggestions = currentText.isNotEmpty &&
        (!_searched || (_results.isEmpty && !_loading));
    if (!_searched && currentText.isEmpty) return _idleState();
    if (showSuggestions && _results.isEmpty && !_loading) return _suggestionsView();
    if (_loading && _results.isEmpty) return _skeletonView(mq);
    if (_error != null && _results.isEmpty) return _errorView();
    if (_results.isEmpty) return _noResults();
    return _resultsView(mq);
  }

  Widget _idleState() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        if (_catalogLoading)
          const Padding(padding: EdgeInsets.all(28),
            child: Center(child: SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: _accent))))
        else if (_catalogCats.isNotEmpty) ...[
          const _SectionHeader(title: "Browse Topics"),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(spacing: 8, runSpacing: 8,
              children: _catalogCats.map((cat) => _TopicChip(
                label: cat.name,
                onTap: () { _fillSearch(cat.name); _submitSearch(cat.name); },
              )).toList()),
          ),
          const SizedBox(height: 8),
        ],
        if (_recentSearches.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 8, 4),
            child: Row(children: [
              const Expanded(child: Text("Recent Searches",
                style: TextStyle(color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.w700, letterSpacing: .2))),
              TextButton(
                onPressed: _clearAllRecent,
                style: TextButton.styleFrom(foregroundColor: Colors.white38,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: const Text("Clear all", style: TextStyle(fontSize: 12)),
              ),
            ]),
          ),
          ..._recentSearches.map((r) => _RecentTile(
            text: r, onTap: () => _submitSearch(r),
            onFill: () => _fillSearch(r), onRemove: () => _removeRecent(r))),
        ] else
          _emptyHint(),
      ],
    );
  }

  Widget _suggestionsView() {
    final suggestions = _buildSuggestions();
    if (suggestions.isEmpty) return _idleState();
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: suggestions.length,
      separatorBuilder: (_, __) =>
          const Divider(color: Color(0x0FFFFFFF), height: 1, indent: 54, endIndent: 16),
      itemBuilder: (context, i) {
        final s        = suggestions[i];
        final isRecent = _recentSearches.contains(s);
        return _SuggestionTile(text: s, isRecent: isRecent,
            onTap: () => _submitSearch(s), onFill: () => _fillSearch(s));
      },
    );
  }

  Widget _resultsView(MediaQueryData mq) {
    final crossCount = mq.size.width >= 900 ? 4 : mq.size.width >= 600 ? 3 : 2;
    return FadeTransition(
      opacity: _fadeAnim,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _resultsHeader(),
        Expanded(child: RefreshIndicator(
          color: _accent, backgroundColor: const Color(0xFF111318),
          onRefresh: () async => _submitSearch(),
          child: _gridView ? _buildGrid(crossCount) : _buildList(),
        )),
      ]),
    );
  }

  Widget _buildGrid(int crossCount) => GridView.builder(
    controller: _scroll,
    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
    padding: const EdgeInsets.fromLTRB(30, 0, 30, 40),
    itemCount: _results.length + (_loadingMore ? crossCount : 0),
    cacheExtent: 2000,
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossCount,crossAxisSpacing: 10),
    itemBuilder: (_, i) {
      if (i >= _results.length) return const _GridSkeletonCard();
      final v = _results[i];
      return RepaintBoundary(child: _VideoGridCard(
          key: ValueKey(v.id ?? '$i'), video: v, query: _query, onTap: () => _open(v)));
    },
  );

  Widget _buildList() => ListView.separated(
    controller: _scroll,
    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
    padding: const EdgeInsets.only(top: 4, bottom: 40),
    itemCount: _results.length + (_loadingMore ? 2 : 0),
    separatorBuilder: (_, __) =>
        const Divider(color: Color(0x0CFFFFFF), height: 1, indent: 16, endIndent: 16),
    itemBuilder: (_, i) {
      if (i >= _results.length) return const _ListSkeletonCard();
      final v = _results[i];
      return RepaintBoundary(child: _VideoListCard(
          key: ValueKey(v.id ?? '$i'), video: v, query: _query, onTap: () => _open(v)));
    },
  );

  Widget _resultsHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("${_results.length}${_hasMore ? '+' : ''} result${_results.length == 1 ? '' : 's'}",
        style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
      if ((_friendlyMessage ?? '').isNotEmpty)
        Padding(padding: const EdgeInsets.only(top: 2),
          child: Text(_friendlyMessage!,
            style: TextStyle(color: _fallbackUsed
                ? Colors.orangeAccent.withOpacity(.75) : Colors.white38, fontSize: 11.5))),
    ]),
  );

  Widget _emptyHint() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 56),
    child: Column(children: [
      Icon(Icons.search_rounded, color: Color(0x2AFFFFFF), size: 72),
      SizedBox(height: 16),
      Text("Search JinnTV", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
      SizedBox(height: 8),
      Text("Discover shows, episodes and Islamic content",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5)),
    ]),
  );

  Widget _noResults() => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.search_off_rounded, color: Color(0x2AFFFFFF), size: 64),
        const SizedBox(height: 14),
        Text(_friendlyMessage ?? 'No results for "$_query"',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text("Try different keywords or check the spelling",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 13)),
        if (_apiSuggestions.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text("Suggestions",
            style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
            children: _apiSuggestions.map((s) =>
                _TopicChip(label: s, onTap: () => _submitSearch(s))).toList()),
        ],
      ]),
    ),
  );

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_rounded, color: Colors.white30, size: 52),
        const SizedBox(height: 14),
        const Text("No connection",
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(_error ?? "Please try again.", textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white38, fontSize: 13)),
        const SizedBox(height: 20),
        _GradientButton(label: "Retry", onTap: _submitSearch),
      ]),
    ),
  );

  Widget _skeletonView(MediaQueryData mq) {
    final crossCount = mq.size.width >= 900 ? 4 : mq.size.width >= 600 ? 3 : 2;
    return _gridView
        ? GridView.builder(
            itemCount: 8,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 18),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossCount, mainAxisSpacing: 12,
              crossAxisSpacing: 12, childAspectRatio: 0.74),
            itemBuilder: (_, __) => const _GridSkeletonCard())
        : ListView.separated(
            itemCount: 6,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 4),
            separatorBuilder: (_, __) =>
                const Divider(color: Color(0x0CFFFFFF), height: 1, indent: 16, endIndent: 16),
            itemBuilder: (_, __) => const _ListSkeletonCard());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  AMBIENT BLOB
// ─────────────────────────────────────────────────────────────────────────────

class _Blob extends StatelessWidget {
  final double size, opacity;
  final Color color;
  const _Blob({required this.size, required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(opacity)));
}

// ─────────────────────────────────────────────────────────────────────────────
//  SEARCH BAR
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final bool loading, focused, gridView, showToggle;
  final String query;
  final VoidCallback onBack, onClear, onToggleView;
  final ValueChanged<String> onChanged, onSubmit;

  const _SearchBar({
    required this.ctrl, required this.focus, required this.loading,
    required this.focused, required this.gridView, required this.showToggle,
    required this.query, required this.onBack, required this.onChanged,
    required this.onSubmit, required this.onClear, required this.onToggleView,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF08090C),
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
          splashRadius: 22, onPressed: onBack),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF0F1115),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: focused ? JinnTvTheme.pink.withOpacity(.55) : const Color(0x1AFFFFFF),
                width: focused ? 1.5 : 1),
              boxShadow: focused ? [BoxShadow(
                  color: JinnTvTheme.pink.withOpacity(.10), blurRadius: 14, spreadRadius: 1)] : [],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: ctrl, focusNode: focus,
                  onChanged: onChanged, onSubmitted: onSubmit,
                  textInputAction: TextInputAction.search,
                  cursorColor: JinnTvTheme.pink,
                  style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(
                    hintText: "Search on JinnTV",
                    hintStyle: TextStyle(color: Colors.white30, fontWeight: FontWeight.w400, fontSize: 15),
                    border: InputBorder.none, isCollapsed: true),
                ),
              ),
              if (loading)
                const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: JinnTvTheme.pink))
              else if (query.isNotEmpty)
                GestureDetector(onTap: onClear,
                  child: const Icon(Icons.close_rounded, color: Colors.white38, size: 18)),
            ]),
          ),
        ),
        // Animated toggle — appears only when results are showing
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: ScaleTransition(scale: anim, child: child)),
          child: showToggle
              ? Tooltip(
                  message: gridView ? "Switch to list" : "Switch to grid",
                  child: IconButton(
                    key: ValueKey(gridView), splashRadius: 20,
                    icon: Icon(
                      gridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                      color: Colors.white60, size: 22),
                    onPressed: onToggleView))
              : const SizedBox(width: 8, key: ValueKey('empty')),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
    child: Text(title, style: const TextStyle(
        color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: .2)));
}

// ─────────────────────────────────────────────────────────────────────────────
//  TOPIC CHIP
// ─────────────────────────────────────────────────────────────────────────────

class _TopicChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _TopicChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141720),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x1FFFFFFF))),
      child: Text(label, style: const TextStyle(
          color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500))));
}

// ─────────────────────────────────────────────────────────────────────────────
//  SUGGESTION TILE
// ─────────────────────────────────────────────────────────────────────────────

class _SuggestionTile extends StatelessWidget {
  final String text;
  final bool isRecent;
  final VoidCallback onTap, onFill;
  const _SuggestionTile({required this.text, required this.isRecent,
      required this.onTap, required this.onFill});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(children: [
        Icon(isRecent ? Icons.history : Icons.search, color: Colors.white38, size: 20),
        const SizedBox(width: 16),
        Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w500))),
        GestureDetector(
          onTap: onFill,
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Transform.rotate(angle: -0.785398,
              child: const Icon(Icons.arrow_upward_rounded, color: Colors.white24, size: 18)))),
      ])));
}

// ─────────────────────────────────────────────────────────────────────────────
//  RECENT TILE
// ─────────────────────────────────────────────────────────────────────────────

class _RecentTile extends StatelessWidget {
  final String text;
  final VoidCallback onTap, onFill, onRemove;
  const _RecentTile({required this.text, required this.onTap,
      required this.onFill, required this.onRemove});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(children: [
        const Icon(Icons.history, color: Colors.white30, size: 20),
        const SizedBox(width: 14),
        Expanded(child: Text(text,
          style: const TextStyle(color: Colors.white70, fontSize: 14))),
        GestureDetector(
          onTap: onFill,
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Transform.rotate(angle: -0.785398,
              child: const Icon(Icons.arrow_upward_rounded, color: Colors.white24, size: 18)))),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onRemove,
          child: const Padding(
            padding: EdgeInsets.only(left: 6),
            child: Icon(Icons.close, color: Colors.white24, size: 16))),
      ])));
}

// ─────────────────────────────────────────────────────────────────────────────
//  GRADIENT BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GradientButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: JinnTvTheme.primaryGradient,
        borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        child: Text(label, style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)))));
}

// ─────────────────────────────────────────────────────────────────────────────
//  VIDEO GRID CARD
// ─────────────────────────────────────────────────────────────────────────────

class _VideoGridCard extends StatelessWidget {
  final VideoItem video;
  final String query;
  final VoidCallback onTap;
  const _VideoGridCard({super.key, required this.video, required this.query, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final thumb = (video.thumbnailUrl ?? "").trim();
    final title = (video.title ?? "").trim();
    return Material(
      color: const Color(0xFF111318),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: JinnTvTheme.pink.withOpacity(.06),
        highlightColor: Colors.white.withOpacity(.03),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: thumb.isNotEmpty
                ? CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 150), memCacheWidth: 600,
                    placeholder: (_, __) => const _ThumbPlaceholder(),
                    errorWidget: (_, __, ___) => const _ThumbPlaceholder())
                : const _ThumbPlaceholder()),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
            child: _HighlightText(
              text: title.isEmpty ? "Untitled" : title, query: query, maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 13,
                  height: 1.3, fontWeight: FontWeight.w600),
              highlightStyle: TextStyle(color: JinnTvTheme.pink, fontSize: 13,
                  height: 1.3, fontWeight: FontWeight.w700))),
        ])));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  VIDEO LIST CARD
// ─────────────────────────────────────────────────────────────────────────────

class _VideoListCard extends StatelessWidget {
  final VideoItem video;
  final String query;
  final VoidCallback onTap;
  const _VideoListCard({super.key, required this.video, required this.query, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final thumb       = (video.thumbnailUrl ?? "").trim();
    final title       = (video.title ?? "").trim();
    final description = (video.description ?? "").trim();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: SizedBox(width: 130, height: 76,
              child: thumb.isNotEmpty
                  ? CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover,
                      memCacheWidth: 400,
                      placeholder: (_, __) => const _ThumbPlaceholder(),
                      errorWidget: (_, __, ___) => const _ThumbPlaceholder())
                  : const _ThumbPlaceholder())),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _HighlightText(
                text: title.isEmpty ? "Untitled" : title, query: query, maxLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 13.5,
                    height: 1.3, fontWeight: FontWeight.w600),
                highlightStyle: TextStyle(color: JinnTvTheme.pink, fontSize: 13.5,
                    height: 1.3, fontWeight: FontWeight.w700)),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(description, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 11.5, height: 1.4)),
              ],
            ])),
          const Padding(
            padding: EdgeInsets.only(top: 2, left: 4),
            child: Icon(Icons.more_vert, color: Colors.white24, size: 18)),
        ])));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HIGHLIGHT TEXT
// ─────────────────────────────────────────────────────────────────────────────

class _HighlightText extends StatelessWidget {
  final String text, query;
  final int maxLines;
  final TextStyle style, highlightStyle;
  const _HighlightText({required this.text, required this.query, required this.maxLines,
      required this.style, required this.highlightStyle});

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: style);
    }
    final spans  = <TextSpan>[];
    final lower  = text.toLowerCase();
    final qLower = query.toLowerCase();
    int start    = 0;
    while (true) {
      final idx = lower.indexOf(qLower, start);
      if (idx == -1) { spans.add(TextSpan(text: text.substring(start), style: style)); break; }
      if (idx > start) spans.add(TextSpan(text: text.substring(start, idx), style: style));
      spans.add(TextSpan(text: text.substring(idx, idx + query.length), style: highlightStyle));
      start = idx + query.length;
    }
    return Text.rich(TextSpan(children: spans),
        maxLines: maxLines, overflow: TextOverflow.ellipsis);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SKELETONS
// ─────────────────────────────────────────────────────────────────────────────

class _GridSkeletonCard extends StatelessWidget {
  const _GridSkeletonCard();

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF111318),
    borderRadius: BorderRadius.circular(12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        child: AspectRatio(aspectRatio: 16 / 9,
          child: Container(color: Colors.white.withOpacity(.06)))),
      Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 13, decoration: BoxDecoration(
              color: Colors.white.withOpacity(.07), borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 7),
          Container(height: 11, width: 100, decoration: BoxDecoration(
              color: Colors.white.withOpacity(.05), borderRadius: BorderRadius.circular(4))),
        ])),
    ]));
}

class _ListSkeletonCard extends StatelessWidget {
  const _ListSkeletonCard();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: Row(children: [
      Container(width: 130, height: 76,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.07), borderRadius: BorderRadius.circular(9))),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 13, decoration: BoxDecoration(
              color: Colors.white.withOpacity(.07), borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 7),
          Container(height: 11, width: 180, decoration: BoxDecoration(
              color: Colors.white.withOpacity(.05), borderRadius: BorderRadius.circular(4))),
        ])),
    ]));
}

// ─────────────────────────────────────────────────────────────────────────────
//  THUMBNAIL PLACEHOLDER
// ─────────────────────────────────────────────────────────────────────────────

class _ThumbPlaceholder extends StatelessWidget {
  const _ThumbPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFF161A22),
    child: const Center(
      child: Icon(Icons.ondemand_video_rounded, color: Color(0x33FFFFFF), size: 36)));
}

// ─────────────────────────────────────────────────────────────────────────────
//  MODEL
// ─────────────────────────────────────────────────────────────────────────────

class VideoItem {
  final String? id, title, description, thumbnailUrl;
  const VideoItem({this.id, this.title, this.description, this.thumbnailUrl});

  factory VideoItem.fromJson(Map<String, dynamic> j) => VideoItem(
    id: j["id"]?.toString(), title: j["title"]?.toString(),
    description: j["description"]?.toString(), thumbnailUrl: j["thumbnail_url"]?.toString());
}