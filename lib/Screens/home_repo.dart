import 'api_client.dart';
import 'home_models.dart';
import '../db/db_helper.dart';

class HomeRepository {
  final ApiClient api;
  HomeRepository(this.api);

  static const String _cacheKeyHomeBundle = 'home_bundle_v1';
  static const String _cacheKeyCatalogPrefix = 'catalog_v1';

  /// Cache duration (server config later)
  static const int _ttlSeconds = 60;

  /// Public method used by UI (cache-first)
  Future<HomeBundle> fetchHomeCacheFirst({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await DBHelper.getCachedBundle(_cacheKeyHomeBundle);
      if (cached != null) {
        // ✅ return cache immediately
        _refreshHomeInBackground();
        return cached;
      }
    }

    // ✅ no cache or force refresh => fetch network
    final fresh = await _fetchFromNetworkAndMerge();
    await DBHelper.setCachedBundle(
      _cacheKeyHomeBundle,
      fresh,
      ttlSeconds: _ttlSeconds,
    );
    return fresh;
  }

  /// Manual refresh (pull-to-refresh etc.)
  Future<HomeBundle> refreshHome() => fetchHomeCacheFirst(forceRefresh: true);

  Future<void> _refreshHomeInBackground() async {
    try {
      final fresh = await _fetchFromNetworkAndMerge();
      await DBHelper.setCachedBundle(
        _cacheKeyHomeBundle,
        fresh,
        ttlSeconds: _ttlSeconds,
      );
    } catch (_) {
      // ignore background refresh errors
    }
  }

  /// Fetch + merge slider + sections into HomeBundle
  Future<HomeBundle> _fetchFromNetworkAndMerge() async {
    const epSlider = "/api_forApp/home.php";
    const epSections = "/api_forApp/home_sections.php";

    Map<String, dynamic> sliderJson = const {};
    Map<String, dynamic> sectionsJson = const {};

    // ---- 1) slider endpoint (own try/catch for accurate logs)
    try {
      sliderJson = await api.getJson(epSlider);
      await DBHelper.addApiLog(
        endpoint: epSlider,
        statusCode: 200,
        req: null,
        res: sliderJson,
      );
    } catch (e) {
      await _logEndpointError(epSlider, e);
      rethrow;
    }

    // ---- 2) sections endpoint (own try/catch for accurate logs)
    try {
      sectionsJson = await api.getJson(epSections);
      await DBHelper.addApiLog(
        endpoint: epSections,
        statusCode: 200,
        req: null,
        res: sectionsJson,
      );
    } catch (e) {
      await _logEndpointError(epSections, e);
      rethrow;
    }

    // ---- Parse slider (supports both shapes)
    final slider = _parseSliderItems(sliderJson);

    // ---- Parse sections bundle (home_models HomeBundle expects whole response shape)
    final ok = sectionsJson['ok'] == true;
    final message = (sectionsJson['message'] ?? '').toString();
    final data = (sectionsJson['data'] as Map?)?.cast<String, dynamic>() ?? {};

    final base = (data['base'] ?? '').toString();

    HomeAdItem? belowAd;
    final below = data['below_slider_ad'];
    if (below is Map) {
      belowAd = HomeAdItem.fromJson(below.cast<String, dynamic>());
    }

    final sectionsJsonList = (data['sections'] as List? ?? []);
    final sections = sectionsJsonList
        .whereType<Map>()
        .map((e) => HomeSection.fromJson(e.cast<String, dynamic>()))
        .toList();

    // filter sections according to login + empties
    final cleaned = await _filterSectionsForUser(sections);

    return HomeBundle(
      ok: ok,
      message: message,
      base: base,
      slider: slider,
      belowSliderAd: belowAd,
      sections: cleaned,
    );
  }

  List<HomeSliderItem> _parseSliderItems(Map<String, dynamic> sliderJson) {
    // Some APIs return: { "slider": [...] }
    // Others: { "ok":true, "data": { "slider":[...] } }
    final data = (sliderJson['data'] as Map?)?.cast<String, dynamic>();
    final list = (sliderJson['slider'] is List)
        ? (sliderJson['slider'] as List)
        : ((data?['slider'] is List) ? (data!['slider'] as List) : const []);

    return list
        .whereType<Map>()
        .map((m) => HomeSliderItem.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  Future<List<HomeSection>> _filterSectionsForUser(List<HomeSection> sections) async {
    final isLoggedIn = await DBHelper.isLoggedIn();

    final out = <HomeSection>[];
    for (final s in sections) {
      // needs_user guard
      if (s.needsUser && !isLoggedIn) continue;

      // ✅ Continue Watching empty ho sakta hai — logged in me allow
      if (!s.needsUser && s.items.isEmpty) continue;

      out.add(s);
    }
    return out;
  }

  Future<void> _logEndpointError(String endpoint, Object e) async {
    await DBHelper.addApiLog(
      endpoint: endpoint,
      statusCode: (e is ApiHttpException) ? e.statusCode : 0,
      req: null,
      res: {
        "error": e.toString(),
        if (e is ApiHttpException) "body": e.body,
        if (e is ApiHttpException) "url": e.uri.toString(),
      },
    );
  }

  /// Typed catalog + accurate logs
  Future<CatalogResponse> fetchCatalog({int categoryId = 0, String q = ""}) async {
    final key =
        '$_cacheKeyCatalogPrefix-cat_${categoryId.toString()}-q_${q.trim()}';

    // ---- 1) Preferred: live network (so logs stay accurate)
    const endpoint = "/api_forApp/catalog.php";

    final qs = {
      "category_id": categoryId.toString(),
      "q": q,
    };

    try {
      final json = await api.getJson(endpoint, query: qs);

      await DBHelper.addApiLog(
        endpoint: "$endpoint?category_id=$categoryId&q=$q",
        statusCode: 200,
        req: qs,
        res: json,
      );

      final resp = CatalogResponse.fromJson(json);

      // ✅ Save latest to cache
      await DBHelper.setCachedCatalog(
        key,
        resp,
        ttlSeconds: _ttlSeconds,
      );

      return resp;
    } catch (e) {
      // ---- 2) Network failed => graceful offline fallback from cache (if any)
      final cached = await DBHelper.getCachedCatalog(key);
      if (cached != null) {
        // Fire & forget background refresh (likely to fail again if offline, but logs error)
        _refreshCatalogInBackground(categoryId: categoryId, q: q, key: key);
        return cached;
      }

      await DBHelper.addApiLog(
        endpoint: "$endpoint?category_id=$categoryId&q=$q",
        statusCode: (e is ApiHttpException) ? e.statusCode : 0,
        req: qs,
        res: {
          "error": e.toString(),
          if (e is ApiHttpException) "body": e.body,
          if (e is ApiHttpException) "url": e.uri.toString(),
        },
      );
      rethrow;
    }
  }

  Future<void> _refreshCatalogInBackground({
    required int categoryId,
    required String q,
    required String key,
  }) async {
    const endpoint = "/api_forApp/catalog.php";

    final qs = {
      "category_id": categoryId.toString(),
      "q": q,
    };

    try {
      final json = await api.getJson(endpoint, query: qs);

      await DBHelper.addApiLog(
        endpoint: "$endpoint?category_id=$categoryId&q=$q",
        statusCode: 200,
        req: qs,
        res: json,
      );

      final resp = CatalogResponse.fromJson(json);

      await DBHelper.setCachedCatalog(
        key,
        resp,
        ttlSeconds: _ttlSeconds,
      );
    } catch (e) {
      await DBHelper.addApiLog(
        endpoint: "$endpoint?category_id=$categoryId&q=$q (bg)",
        statusCode: (e is ApiHttpException) ? e.statusCode : 0,
        req: qs,
        res: {
          "error": e.toString(),
          if (e is ApiHttpException) "body": e.body,
          if (e is ApiHttpException) "url": e.uri.toString(),
        },
      );
      // ignore error (background)
    }
  }
}
