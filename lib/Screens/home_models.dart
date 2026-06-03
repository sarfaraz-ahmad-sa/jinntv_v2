class HomeBundle {
  final bool ok;
  final String message;
  final String base; // data.base
  final List<HomeSliderItem> slider;
  final HomeAdItem? belowSliderAd;
  final List<HomeSection> sections;

  HomeBundle({
    required this.ok,
    required this.message,
    required this.base,
    required this.slider,
    required this.belowSliderAd,
    required this.sections,
  });

  factory HomeBundle.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as Map?)?.cast<String, dynamic>() ?? {};
    final sliderJson = (data['slider'] as List? ?? []);
    final sectionsJson = (data['sections'] as List? ?? []);
    final below = data['below_slider_ad'];

    HomeAdItem? belowAd;
    if (below is Map) {
      belowAd = HomeAdItem.fromJson(below.cast<String, dynamic>());
    }

    return HomeBundle(
      ok: json['ok'] == true,
      message: (json['message'] ?? '').toString(),
      base: (data['base'] ?? '').toString(),
      slider: sliderJson
          .whereType<Map>()
          .map((e) => HomeSliderItem.fromJson(e.cast<String, dynamic>()))
          .toList(),
      belowSliderAd: belowAd,
      sections: sectionsJson
          .whereType<Map>()
          .map((e) => HomeSection.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "ok": ok,
      "message": message,
      "data": {
        "base": base,
        "slider": slider.map((s) => s.toJson()).toList(),
        "below_slider_ad": belowSliderAd?.toJson(),
        "sections": sections.map((s) => s.toJson()).toList(),
      }
    };
  }
}

/* ================= ADS ================= */

class HomeAdItem {
  final int position;
  final int adId;
  final String adType; // image/video
  final String size;
  final String link;
  final String description;
  final String image;
  final String video;

  HomeAdItem({
    required this.position,
    required this.adId,
    required this.adType,
    required this.size,
    required this.link,
    required this.description,
    required this.image,
    required this.video,
  });

  factory HomeAdItem.fromJson(Map<String, dynamic> json) {
    int _toInt(dynamic v) => int.tryParse('$v') ?? 0;
    String _toStr(dynamic v) => (v ?? '').toString();

    return HomeAdItem(
      position: _toInt(json['position']),
      adId: _toInt(json['ad_id']),
      adType: _toStr(json['ad_type']),
      size: _toStr(json['size']),
      link: _toStr(json['link']),
      description: _toStr(json['description']),
      image: _toStr(json['image']),
      video: _toStr(json['video']),
    );
  }

  Map<String, dynamic> toJson() => {
        "position": position,
        "ad_id": adId,
        "ad_type": adType,
        "size": size,
        "link": link,
        "description": description,
        "image": image,
        "video": video,
      };
}

/* ================= SECTION ================= */

class HomeSection {
  final int tagId;
  final String title;
  final String layout;
  final bool needsUser;
  final List<HomeVideoItem> items;
  final List<HomeAdItem> ads;

  HomeSection({
    required this.tagId,
    required this.title,
    required this.layout,
    required this.needsUser,
    required this.items,
    required this.ads,
  });

  factory HomeSection.fromJson(Map<String, dynamic> json) {
    int _toInt(dynamic v) => int.tryParse('$v') ?? 0;

    final itemsJson = json['items'] as List? ?? [];
    final adsJson = json['ads'] as List? ?? [];

    return HomeSection(
      tagId: _toInt(json['tag_id']),
      title: (json['title'] ?? '').toString(),
      layout: (json['layout'] ?? 'style2').toString(),
      needsUser: json['needs_user'] == true,
      items: itemsJson
          .whereType<Map>()
          .map((e) => HomeVideoItem.fromJson(e.cast<String, dynamic>()))
          .toList(),
      ads: adsJson
          .whereType<Map>()
          .map((e) => HomeAdItem.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        "tag_id": tagId,
        "title": title,
        "layout": layout,
        "needs_user": needsUser,
        "items": items.map((v) => v.toJson()).toList(),
        "ads": ads.map((a) => a.toJson()).toList(),
      };
}

/* ================= VIDEO ================= */

class HomeVideoItem {
  final int id;
  final String slug;
  final String title;
  final String description;
  final String thumb;
  final String youtubeId;
  final String mp4Url;

  final String videoKind; // subscribed/unsubscribed
  final String videoType; // homepage...
  final int videoCategoryId;

  final String episodeHeading;
  final String seasonHeading;

  HomeVideoItem({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.thumb,
    required this.youtubeId,
    required this.mp4Url,
    required this.videoKind,
    required this.videoType,
    required this.videoCategoryId,
    required this.episodeHeading,
    required this.seasonHeading,
  });

  bool get hasYoutube => youtubeId.trim().isNotEmpty;
  bool get hasMp4 => mp4Url.trim().isNotEmpty;

  factory HomeVideoItem.fromJson(Map<String, dynamic> json) {
    int _toInt(dynamic v) => int.tryParse('$v') ?? 0;
    String _toStr(dynamic v) => (v ?? '').toString();

    return HomeVideoItem(
      id: _toInt(json['id']),
      slug: _toStr(json['slug']),
      title: _toStr(json['title']),
      description: _toStr(json['description']),
      thumb: _toStr(json['thumb']),
      youtubeId: _toStr(json['youtube_id']),
      mp4Url: _toStr(json['mp4_url']),
      videoKind: _toStr(json['video_kind']),
      videoType: _toStr(json['video_type']),
      videoCategoryId: _toInt(json['video_category_id']),
      episodeHeading: _toStr(json['episode_heading']),
      seasonHeading: _toStr(json['season_heading']),
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "slug": slug,
        "title": title,
        "description": description,
        "thumb": thumb,
        "youtube_id": youtubeId,
        "mp4_url": mp4Url,
        "video_kind": videoKind,
        "video_type": videoType,
        "video_category_id": videoCategoryId,
        "episode_heading": episodeHeading,
        "season_heading": seasonHeading,
      };
}

/* ================= SLIDER ================= */

class HomeSliderItem {
  final int id;
  final int position;
  final String urlType;
  final String url;
  final String isPlay;
  final String sliderType;
  final String backgroundImage;
  final int videoId;
  final String sliderTitle;
  final String pageTitle;

  HomeSliderItem({
    required this.id,
    required this.position,
    required this.urlType,
    required this.url,
    required this.isPlay,
    required this.sliderType,
    required this.backgroundImage,
    required this.videoId,
    required this.sliderTitle,
    required this.pageTitle,
  });

  // ✅ Backward compatible getters (old UI)
  String get page_title => pageTitle;
  String get slider_title => sliderTitle;

  factory HomeSliderItem.fromJson(Map<String, dynamic> json) {
    int _toInt(dynamic v) => int.tryParse((v ?? 0).toString()) ?? 0;
    String _toStr(dynamic v) => (v ?? '').toString();

    return HomeSliderItem(
      id: _toInt(json['id']),
      position: _toInt(json['position']),
      urlType: _toStr(json['url_type']),
      url: _toStr(json['url']),
      isPlay: _toStr(json['is_play']),
      sliderType: _toStr(json['slider_type']),
      backgroundImage: _toStr(json['background_image']),
      videoId: _toInt(json['video_id']),
      sliderTitle: _toStr(json['slider_title']),
      pageTitle: _toStr(json['page_title']),
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "position": position,
        "url_type": urlType,
        "url": url,
        "is_play": isPlay,
        "slider_type": sliderType,
        "background_image": backgroundImage,
        "video_id": videoId,
        "slider_title": sliderTitle,
        "page_title": pageTitle,
      };
}

/* ================= CATALOG (TYPED) ================= */

class CatalogResponse {
  final bool ok;
  final String message;
  final List<CatalogCategory> categories;
  final int categoryId;

  CatalogResponse({
    required this.ok,
    required this.message,
    required this.categories,
    required this.categoryId,
  });

  factory CatalogResponse.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as Map?)?.cast<String, dynamic>() ?? {};
    final catsJson = (data['categories'] as List? ?? []);
    final filters = (data['filters'] as Map?)?.cast<String, dynamic>() ?? {};
    int _toInt(dynamic v) => int.tryParse('$v') ?? 0;

    return CatalogResponse(
      ok: json['ok'] == true,
      message: (json['message'] ?? '').toString(),
      categoryId: _toInt(filters['category_id']),
      categories: catsJson
          .whereType<Map>()
          .map((e) => CatalogCategory.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }

  /// Used for local caching (mirrors API-ish shape)
  Map<String, dynamic> toJson() {
    return {
      "ok": ok,
      "message": message,
      "data": {
        "filters": {
          "category_id": categoryId,
        },
        "categories": categories.map((c) => c.toJson()).toList(),
      },
    };
  }
}

class CatalogCategory {
  final int id;
  final String name;
  final String slug;
  final List<HomeVideoItem> items;

  CatalogCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.items,
  });

  factory CatalogCategory.fromJson(Map<String, dynamic> json) {
    int _toInt(dynamic v) => int.tryParse('$v') ?? 0;
    final itemsJson = (json['items'] as List? ?? []);

    return CatalogCategory(
      id: _toInt(json['id']),
      name: (json['name'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      items: itemsJson
          .whereType<Map>()
          .map((e) => HomeVideoItem.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "slug": slug,
        "items": items.map((v) => v.toJson()).toList(),
      };
}
