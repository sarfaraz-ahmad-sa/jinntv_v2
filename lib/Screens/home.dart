import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_api_screen.dart';

import 'notifications_screen.dart';
import 'privacy_policy.dart';
import 'profile.dart';
import 'sql_logs_screen.dart';
import 'login.dart';
import 'ContactUs.dart';
import 'AboutUs.dart';
import 'video_player_screen.dart';
import 'SearchScreen.dart';
import 'home_models.dart';
import 'SectionViewAllScreen.dart';

import 'widgets/sidebar.dart';
import 'widgets/More_menu.dart';

import 'api_client.dart';
import 'home_repo.dart';
import '../db/db_helper.dart';
import '../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentSlide = 0;

  late final PageController _pageController;
  Timer? _timer;

  // ✅ Home bundle (slider + sections + belowAd) cache-first
  late final HomeRepository repo;
  Future<HomeBundle>? _futureHome;

  int _sliderCount = 0;
  String? _activeUserId;

  // ✅ Chips/Catalog
  String _chip = "All";
  List<CatalogCategory> _catalogCats = [];
  bool _catalogLoading = false;
  String? _catalogError;

  int _selectedCategoryId = 0; // 0 = All
  List<HomeVideoItem> _categoryItems = []; // selected category videos

  // ✅ Double-tap-back-to-exit (like YouTube / Netflix)
  DateTime? _lastBackPressed;

  static const Color _bg = Color(0xFF0B0F14);
  static const Color _appBar = Color(0xFF0F1723);
  static const Color _accent = Color(0xFFB58BFF);

  static const ScrollPhysics _netPhysics = ClampingScrollPhysics();

  String get _base => '$adminBaseUrl/';
  String get _thumbBase => '$adminBaseUrl/jinn-tv-admin/uploads/videos/thumbs/';

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initRepo();
    _initUser();

    _startSliderTimer();
  }

  void _initRepo() {
    repo = HomeRepository(ApiClient(baseUrl: adminBaseUrl));
    _futureHome = repo.fetchHomeCacheFirst();
    _loadCatalogCategories();
  }

  @override
  void dispose() {
    _stopSliderTimer();
    _pageController.dispose();
    super.dispose();
  }

  // ✅ BIG FIX: start/stop slider timer
  void _startSliderTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      if (!_pageController.hasClients) return;
      if (_sliderCount <= 1) return;

      final next = (_currentSlide + 1) % _sliderCount;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
      );

      if (mounted) setState(() => _currentSlide = next);
    });
  }

  void _stopSliderTimer() {
    _timer?.cancel();
    _timer = null;
  }

  // ✅ Back press handler — double tap within 2s to exit app.
  Future<void> _handleBackPress() async {
    // Agar drawer open hai to pehle wo close karo
    final scaffoldState = Scaffold.maybeOf(context);
    if (scaffoldState != null && scaffoldState.isDrawerOpen) {
      Navigator.pop(context);
      return;
    }

    final now = DateTime.now();
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Press back again to exit'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Second tap within 2s → close app
    await SystemNavigator.pop();
  }

  Future<void> _initUser() async {
    final uid = await DBHelper.getActiveUserId();
    if (!mounted) return;
    setState(() => _activeUserId = uid);
  }

  void _reloadHome() {
    setState(() => _futureHome = repo.fetchHomeCacheFirst());
  }

  Future<void> _reloadAll() async {
    _reloadHome();
    await _loadCatalogCategories();
  }

  // ✅ One safe method to open video (pauses slider timer)
  Future<void> _openVideoPlayer({
    String? title,
    String? youtubeId,
    String? mp4Url,
    int? videoId,
  }) async {
    _stopSliderTimer();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          title: title,
          youtubeId: youtubeId,
          mp4Url: mp4Url,
          videoId: videoId,
        ),
      ),
    );

    if (mounted) _startSliderTimer();
  }

  String _absUrl(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    final u = Uri.tryParse(s);
    if (u != null && u.hasScheme) return s;
    return Uri.parse(_base).resolve(s).toString();
  }

  String _thumbToBg(String thumb) {
    final t = thumb.trim();
    if (t.isEmpty) return '';
    final u = Uri.tryParse(t);
    if (u != null && u.hasScheme) return t;
    return _thumbBase + t;
  }

  double _adHeightFromSize(String size, double screenW) {
    final s = size.trim().toLowerCase();
    final parts = s.split('x');
    if (parts.length != 2) return 60;

    final w = double.tryParse(parts[0]) ?? 970;
    final h = double.tryParse(parts[1]) ?? 90;

    final availableW = screenW - 16;
    return availableW * (h / w);
  }

  Widget _netImage(String url, {BoxFit fit = BoxFit.cover, int memW = 900}) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 120),
      memCacheWidth: memW,
      placeholder: (_, __) => Container(
        color: Colors.white10,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        color: Colors.white10,
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_not_supported_outlined,
          color: Colors.white54,
        ),
      ),
    );
  }

  Widget _belowHeroAd(HomeAdItem? ad) {
    if (ad == null) return const SizedBox.shrink();

    final screenW = MediaQuery.of(context).size.width;
    final h =
        ad.size.trim().isEmpty ? 60.0 : _adHeightFromSize(ad.size, screenW);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: GestureDetector(
        onTap: () async {
          final link = ad.link.trim();
          if (link.isEmpty) return;
          final url = Uri.tryParse(link);
          if (url != null && await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            color: Colors.black,
            padding: const EdgeInsets.all(8),
            child: CachedNetworkImage(
              imageUrl: ad.image,
              height: h,
              fit: BoxFit.contain,
              placeholder: (_, __) => SizedBox(
                height: h,
                child: const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => SizedBox(height: h),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionAds(List<HomeAdItem> ads) {
    if (ads.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(9, 0, 9, 0),
      child: Column(
        children: ads.map((ad) {
          final screenW = MediaQuery.of(context).size.width;
          final h =
              ad.size.trim().isEmpty ? 60.0 : _adHeightFromSize(ad.size, screenW);

          return GestureDetector(
            onTap: () async {
              final link = ad.link.trim();
              if (link.isEmpty) return;
              final url = Uri.tryParse(link);
              if (url != null && await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: Colors.transparent,
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 10),
                child: CachedNetworkImage(
                  imageUrl: ad.image,
                  height: h,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => SizedBox(
                    height: h,
                    child: const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => SizedBox(height: h),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _openViewAll(HomeSection sec) {
    Navigator.of(context).push(
      _netflixRoute(
        SectionViewAllScreen(
          title: sec.title,
          items: sec.items,
          thumbToBg: _thumbToBg,
        ),
      ),
    );
  }

  // ✅ IMPORTANT: this must be INSIDE the class
  void _openCategoryViewAll(String title, List<HomeVideoItem> items) {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No videos to show")),
      );
      return;
    }

    Navigator.of(context).push(
      _netflixRoute(
        SectionViewAllScreen(
          title: title,
          items: items,
          thumbToBg: _thumbToBg,
        ),
      ),
    );
  }

  Route _netflixRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      transitionsBuilder: (_, animation, __, child) {
        final slide = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));

        final fade = Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut));

        return SlideTransition(
          position: animation.drive(slide),
          child: FadeTransition(
            opacity: animation.drive(fade),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _loadCatalogCategories() async {
    try {
      final resp = await repo.fetchCatalog(categoryId: 0, q: "");
      if (!mounted) return;

      final filtered = resp.categories.where((c) => c.items.isNotEmpty).toList();
      filtered.sort((a, b) => b.items.length.compareTo(a.items.length));

      setState(() {
        _catalogCats = filtered;
        _catalogError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _catalogError = e.toString());
    }
  }

  Future<void> _selectCategory(int categoryId, String label) async {
    setState(() {
      _selectedCategoryId = categoryId;
      _chip = label;
      _catalogLoading = true;
      _catalogError = null;
      _categoryItems = [];
    });

    if (categoryId == 0) {
      setState(() => _catalogLoading = false);
      return;
    }

    try {
      final resp = await repo.fetchCatalog(categoryId: categoryId, q: "");
      if (!mounted) return;

      CatalogCategory? cat;
      for (final c in resp.categories) {
        if (c.id == categoryId) {
          cat = c;
          break;
        }
      }
      cat ??= resp.categories.isNotEmpty ? resp.categories.first : null;

      final items = cat?.items ?? const <HomeVideoItem>[];

      setState(() {
        _categoryItems = items;
        _catalogLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      // Offline / error fallback: use already-loaded _catalogCats data if possible
      CatalogCategory? localCat;
      for (final c in _catalogCats) {
        if (c.id == categoryId) {
          localCat = c;
          break;
        }
      }

      if (localCat != null && localCat.items.isNotEmpty) {
        setState(() {
          _categoryItems = localCat!.items;
          _catalogLoading = false;
          _catalogError = null;
        });
        return;
      }

      final msg = e.toString().contains('SocketException')
          ? "You're offline. This category is not cached yet."
          : "Unable to load this category. Please try again.";

      setState(() {
        _catalogLoading = false;
        _catalogError = msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // canPop: false → Flutter back button automatically handle nahi karega.
      // Hum manually onPopInvoked me decide karenge: snackbar dikhayein
      // ya app exit karein.
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _handleBackPress();
      },
      child: Scaffold(
      backgroundColor: _bg,
      drawer: AppSidebar(
        onLogout: () => _logout(context),
        onNavigate: (route) {
          Navigator.pop(context);
          switch (route) {
            case 'contact':
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ContactUsScreen()));
              break;
            case 'logs':
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SqlLogsScreen()));
              break;
            case 'about':
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AboutUsScreen()));
              break;
            case 'privacy':
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
              break;
            case 'profile':
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()));
              break;
          }
        },
      ),
      body: FutureBuilder<HomeBundle>(
        future: _futureHome,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return _skeletonHome();
          }
          if (snap.hasError) {
            return _errorBlock("${snap.error}", onRetry: _reloadAll);
          }

          final bundle = snap.data;
          if (bundle == null) {
            return _emptyBlock("Home data missing", onReload: _reloadAll);
          }

          final slider = bundle.slider;
          final sections = bundle.sections;

          if (slider.isEmpty) {
            return _emptyBlock("Home slider empty", onReload: _reloadAll);
          }

          _sliderCount = slider.length;
          _currentSlide = _currentSlide % slider.length;

          return RefreshIndicator(
            onRefresh: _reloadAll,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: _netPhysics),
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  // ✅ Netflix-style: pura top bar (logo + chips) ek saath
                  //    hide hota hai jab scroll-down ho, aur scroll-up par
                  //    immediately reveal hota hai. No overlap.
                  pinned: false,
                  floating: true,
                  snap: true,
                  leadingWidth: 150,
                  toolbarHeight: 56,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(18),
                    ),
                  ),
                  // ✅ Chips ko AppBar ke bottom me daal diya — ab ye logo bar
                  //    ke neeche sit karenge, overlap nahi hoga.
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(48),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                      child: _topflixChips(),
                    ),
                  ),
                  leading: Builder(
                    builder: (context) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => Scaffold.of(context).openDrawer(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),

                          child: Row(
                            children: [
                              Image.asset(
                                'assets/images/jinn-tv-logo.png',
                                height: 40,
                              ),

                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.search_rounded, color: Colors.white),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SearchScreen()),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: ValueListenableBuilder<int>(
                        valueListenable: NotifBus.instance.unread,
                        builder: (_, count, __) {
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.notifications_none_rounded,
                                  color: Colors.white,
                                ),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const NotificationsScreen(),
                                  ),
                                ),
                              ),
                              if (count > 0)
                                Positioned(
                                  right: 6,
                                  top: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: Colors.black,
                                        width: 1.5,
                                      ),
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    child: Text(
                                      count > 99 ? "99+" : "$count",
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 2),
                  ],
                  flexibleSpace: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.88),
                              Colors.black.withOpacity(0.50),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: _heroCard(slider),
                ),

                if (bundle.belowSliderAd != null)
                  SliverToBoxAdapter(child: _belowHeroAd(bundle.belowSliderAd)),

                if (_catalogError != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: _errorInline(_catalogError!),
                    ),
                  ),

                if (_catalogLoading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (_selectedCategoryId != 0)
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _rowHeaderText(
                          _chip,
                          onSeeAll: () => _openCategoryViewAll(_chip, _categoryItems),
                        ),
                        _categoryItems.isEmpty
                            ? _emptyRow("No videos in this category")
                            : _posterRow(_categoryItems),
                      ],
                    ),
                  )
                else if (sections.isEmpty)
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _rowHeaderText(
                          "New Releases",
                          onSeeAll: () => _openCategoryViewAll(
                            "New Releases",
                            const <HomeVideoItem>[],
                          ),
                        ),
                        _emptyRow("No sections available"),
                      ],
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final sec = sections[index];

                        final key = sec.tagId.toString().toLowerCase().trim();
                        final title = sec.title.toLowerCase().trim();

                        final hideMyList = title == "my list" ||
                            title.contains("my list") ||
                            key == "my_list" ||
                            key.contains("my list") ||
                            key.contains("my_list");

                        final hideContinueWatching = title.contains("continue watching") ||
                            (title.contains("continue") &&
                                title.contains("watch")) ||
                            (key.contains("continue") && key.contains("watch")) ||
                            key.contains("continue_watching");

                        if (hideMyList || hideContinueWatching) {
                          return const SizedBox.shrink();
                        }

                        final isTop10 = title.contains("top 10") ||
                            key.contains("top10world") ||
                            key.contains("top_10world");

                        return Column(
                          children: [
                            _rowHeader(sec, onSeeAll: () => _openViewAll(sec)),
                            isTop10 ? _top10Row(sec.items) : _posterRow(sec.items),
                            if (sec.ads.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(15, 0, 12, 2),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    "Advertisements",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              _sectionAds(sec.ads),
                            ],
                          ],
                        );
                      },
                      childCount: sections.length,
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 18)),
              ],
            ),
          );
        },
      ),
      ),
    );
  }

  // ===================== CHIPS =====================

  Widget _topflixChips() {
    const topCount = 4;
    final top = _catalogCats.take(topCount).toList();

    return SizedBox(
      height: 32,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: _netPhysics,
              padding: const EdgeInsets.only(left: 10, right: 8),
              children: [
                _chipBtnDyn(
                  "All",
                  isSelected: _selectedCategoryId == 0,
                  onTap: () => _selectCategory(0, "All"),
                  isPrimary: true,
                ),
                const SizedBox(width: 8),
                ...top.expand((c) => [
                      _chipBtnDyn(
                        c.name,
                        isSelected: _selectedCategoryId == c.id,
                        onTap: () => _selectCategory(c.id, c.name),
                      ),
                      const SizedBox(width: 8),
                    ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: (_catalogCats.length > topCount)
                ? _moreButtonFixed()
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _chipBtnDyn(
    String text, {
    required bool isSelected,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xff723579), Color(0xffDA4775)],
                )
              : null,
          color: isSelected
              ? null
              : (isPrimary
                  ? const Color(0xFF1E293B)
                  : const Color(0xFF111827)),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.white12,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xffDA4775).withOpacity(0.40),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 13,
            height: 1,
          ),
        ),
      ),
    );
  }

  Widget _moreButtonFixed() {
    return InkWell(
      onTap: _openAllCategoriesSheet,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white12),
        ),
        child: const Icon(Icons.apps, size: 16, color: Colors.white),
      ),
    );
  }

  void _openAllCategoriesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B0F14),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        String q = "";
        return StatefulBuilder(
          builder: (context, setSheet) {
            final list = _catalogCats.where((c) {
              if (q.trim().isEmpty) return true;
              return c.name.toLowerCase().contains(q.toLowerCase());
            }).toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 14,
                  right: 14,
                  top: 12,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 14,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 46,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            "All Programs",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white70),
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      onChanged: (v) => setSheet(() => q = v),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Search Programs...",
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
                        prefixIcon: const Icon(Icons.search, color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF111827),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: list.length + 1,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: Colors.white.withOpacity(0.06),
                        ),
                        itemBuilder: (_, i) {
                          if (i == 0) {
                            final selected = _selectedCategoryId == 0;
                            return ListTile(
                              dense: true,
                              title: Text(
                                "All",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: selected
                                      ? FontWeight.w900
                                      : FontWeight.w600,
                                ),
                              ),
                              trailing: selected
                                  ? const Icon(Icons.check, color: Colors.white)
                                  : null,
                              onTap: () {
                                Navigator.pop(context);
                                _selectCategory(0, "All");
                              },
                            );
                          }

                          final c = list[i - 1];
                          final selected = _selectedCategoryId == c.id;

                          return ListTile(
                            dense: true,
                            title: Text(
                              c.name,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: selected
                                    ? FontWeight.w900
                                    : FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              "${c.items.length} videos",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.45),
                                fontSize: 12,
                              ),
                            ),
                            trailing: selected
                                ? const Icon(Icons.check, color: Colors.white)
                                : const Icon(Icons.chevron_right,
                                    color: Colors.white38),
                            onTap: () {
                              Navigator.pop(context);
                              _selectCategory(c.id, c.name);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===================== HERO =====================

  Widget _heroCard(List<HomeSliderItem> slider) {
    final screenHeight = MediaQuery.of(context).size.height;
    final heroH = screenHeight * 0.56;

    return SizedBox(
        height: heroH,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentSlide = i),
              itemCount: slider.length,
              itemBuilder: (_, index) {
                final s = slider[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    RepaintBoundary(
                      child: _netImage(_absUrl(s.backgroundImage),
                          fit: BoxFit.cover),
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Color(0xE6000000),
                            Color(0x00000000),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.sliderTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 23,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            s.page_title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _openVideoPlayer(
                                    videoId: s.videoId,
                                    title: s.sliderTitle,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Color(0xff723579),
                                          Color(0xffDA4775),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xffDA4775)
                                              .withOpacity(0.35),
                                          blurRadius: 14,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.play_arrow_rounded,
                                            size: 24, color: Colors.white),
                                        SizedBox(width: 6),
                                        Text(
                                          "Play",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: Color(0xffB58BFF),
                                      width: 1.5,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 11,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () async {
                                    final userId =
                                        await DBHelper.currentUserId();
                                    final ok = await DBHelper.addToPlaylist(
                                      userId: userId,
                                      videoId: s.videoId.toString(),
                                      title: s.sliderTitle,
                                      thumb: _absUrl(
                                          s.backgroundImage), // slider image as thumb
                                      youtubeId:
                                          null, // agar slider me youtubeId field ho to yahan pass kar do
                                      mp4Url:
                                          null, // agar slider me mp4Url field ho to yahan pass kar do
                                    );

                                    if (!context.mounted) return;

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(ok
                                            ? "Added to Mylist"
                                            : "Already in Mylist"),
                                        duration:
                                            const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.add_rounded, size: 24),
                                  label: const Text(
                                    "My List",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            if (slider.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 18 + 56,
                child: Center(
                  child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    slider.length.clamp(0, 8),
                    (i) {
                      final selected = i == _currentSlide;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(left: 4),
                        width: selected ? 18 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white
                              : Colors.white.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      );
                    },
                  ),
                ),
                ),
              ),
          ],
        ),
      );
  }

  // ===================== ROWS =====================

  Widget _rowHeader(HomeSection sec, {required VoidCallback onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 10, 8, 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              sec.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
          InkWell(
            onTap: onSeeAll,
            borderRadius: BorderRadius.circular(10),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                children: [
                  Text(
                    "More",
                    style: TextStyle(
                      color: Color(0xffB58BFF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Color(0xffB58BFF), size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowHeaderText(String title, {required VoidCallback onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 19,
              ),
            ),
          ),
          InkWell(
            onTap: onSeeAll,
            borderRadius: BorderRadius.circular(10),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                children: [
                  Text(
                    "More",
                    style: TextStyle(
                      color: Color(0xffB58BFF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right, color: Color(0xffB58BFF), size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _posterRow(List<HomeVideoItem> items) {
    if (items.isEmpty) return _emptyRow("No videos");
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: _netPhysics,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        cacheExtent: 600,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final v = items[index];
          final bg = _thumbToBg(v.thumb);
          return _posterCard(
            title: v.title,
            backgroundUrl: bg,
            onTap: () => _openVideoPlayer(
              title: v.title,
              youtubeId: v.youtubeId,
              mp4Url: v.mp4Url,
              videoId: v.id,
            ),
          );
        },
      ),
    );
  }

  Widget _posterCard({
    required String title,
    required String backgroundUrl,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 195,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: RepaintBoundary(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _netImage(backgroundUrl, fit: BoxFit.cover, memW: 400),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Color(0xCC000000),
                              Color(0x00000000),
                            ],
                          ),
                        ),
                      ),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 12,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _top10Row(List<HomeVideoItem> items) {
    if (items.isEmpty) return _emptyRow("No videos");
    final list = items.take(10).toList();

    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: _netPhysics,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        cacheExtent: 600,
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final v = list[index];
          final bg = _thumbToBg(v.thumb);
          final rank = index + 1;

          return _top10Card(
            backgroundUrl: bg,
            rank: rank,
            onTap: () => _openVideoPlayer(
              title: v.title,
              youtubeId: v.youtubeId,
              mp4Url: v.mp4Url,
              videoId: v.id,
            ),
          );
        },
      ),
    );
  }

  Widget _top10Card({
    required String backgroundUrl,
    required int rank,
    required VoidCallback onTap,
  }) {
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = Colors.white.withOpacity(0.22);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 230,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 10,
              bottom: 12,
              child: Text(
                "$rank",
                style: TextStyle(
                  fontSize: 140,
                  fontWeight: FontWeight.w900,
                  foreground: strokePaint,
                  height: 0.70,
                  letterSpacing: -12,
                ),
              ),
            ),
            Positioned(
              left: 70,
              top: 0,
              right: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: RepaintBoundary(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _netImage(backgroundUrl, fit: BoxFit.cover, memW: 500),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== STATES =====================

  Widget _errorBlock(String msg, {required Future<void> Function() onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text("Retry")),
          ],
        ),
      ),
    );
  }

  Widget _errorInline(String msg) {
    return Text(
      msg,
      textAlign: TextAlign.center,
      style: TextStyle(color: Colors.white.withOpacity(0.75)),
    );
  }

  Widget _emptyBlock(String msg, {required Future<void> Function() onReload}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(msg, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: onReload, child: const Text("Reload")),
        ],
      ),
    );
  }

  Widget _emptyRow(String msg) {
    return SizedBox(
      height: 90,
      child: Center(
        child: Text(msg, style: const TextStyle(color: Colors.white70)),
      ),
    );
  }

  // ===================== SKELETON =====================

  Widget _skeletonHome() {
    final screenH = MediaQuery.of(context).size.height;
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 108)),
        // Hero skeleton
        SliverToBoxAdapter(
          child: _ShimmerBox(
            height: screenH * 0.56,
            radius: 0,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 14)),
        // 3 row skeletons
        ...List.generate(3, (_) => SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(15, 14, 8, 10),
                child: _ShimmerBox(width: 130, height: 16, radius: 6),
              ),
              SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  itemCount: 5,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, __) => const _ShimmerBox(
                    width: 195,
                    height: 120,
                    radius: 14,
                  ),
                ),
              ),
            ],
          ),
        )),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }
}

// ===================== SHIMMER BOX =====================

class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox({
    this.width = double.infinity,
    required this.height,
    this.radius = 8,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
    _anim = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
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
        final v = _anim.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                (v - 0.4).clamp(0.0, 1.0),
                v.clamp(0.0, 1.0),
                (v + 0.4).clamp(0.0, 1.0),
              ],
              colors: const [
                Color(0xFF141424),
                Color(0xFF252540),
                Color(0xFF141424),
              ],
            ),
          ),
        );
      },
    );
  }
}