// lib/Screens/video_player_screen.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'SearchScreen.dart';
import '../db/db_helper.dart';
import 'login.dart';
import 'video_hero_player.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class SubtitleTrack {
  final String code;
  final String label;
  final String url;
  final bool isDefault;

  const SubtitleTrack({
    required this.code,
    required this.label,
    required this.url,
    this.isDefault = false,
  });

  factory SubtitleTrack.fromApi(Map<String, dynamic> j) {
    String s(dynamic v) => (v ?? '').toString().trim();
    bool b(dynamic v) {
      final x = s(v).toLowerCase();
      return x == '1' || x == 'true' || x == 'yes';
    }

    final code = s(j['code']);
    final label = s(j['label']).isEmpty ? code.toUpperCase() : s(j['label']);
    return SubtitleTrack(
      code: code,
      label: label,
      url: s(j['url']),
      isDefault: b(j['is_default']),
    );
  }

  bool get isValid => code.isNotEmpty && url.isNotEmpty;
}

class AudioTrack {
  final String code;
  final String label;
  final String url;
  final bool isDefault;

  const AudioTrack({
    required this.code,
    required this.label,
    required this.url,
    this.isDefault = false,
  });

  factory AudioTrack.fromApi(Map<String, dynamic> j) {
    String s(dynamic v) => (v ?? '').toString().trim();
    bool b(dynamic v) {
      final x = s(v).toLowerCase();
      return x == '1' || x == 'true' || x == 'yes';
    }

    final code = s(j['code']);
    final label = s(j['label']).isEmpty ? code.toUpperCase() : s(j['label']);
    return AudioTrack(
      code: code,
      label: label,
      url: s(j['url']),
      isDefault: b(j['is_default']),
    );
  }

  bool get isValid => code.isNotEmpty && url.isNotEmpty;
}

class EpisodeItem {
  final int? videoId;
  final String title;
  final String thumbUrl;
  final String? youtubeId;
  final String? mp4Url;
  final String? description;
  final List<String> tags;
  final Duration? duration;

  final int likeCount;
  final int dislikeCount;
  final int subscribeCount;
  final bool subscribeEnabled;
  final String subscribeLabel;
  final String subscribeUrl;
  final String myReaction;
  final bool isSubscribed;

  final String defaultLanguage;
  final List<SubtitleTrack> subtitleTracks;
  final List<AudioTrack> audioTracks;

  const EpisodeItem({
    this.videoId,
    required this.title,
    required this.thumbUrl,
    this.youtubeId,
    this.mp4Url,
    this.description,
    this.tags = const [],
    this.duration,
    this.likeCount = 0,
    this.dislikeCount = 0,
    this.subscribeCount = 0,
    this.subscribeEnabled = false,
    this.subscribeLabel = "Subscribe",
    this.subscribeUrl = "",
    this.myReaction = "none",
    this.isSubscribed = false,
    this.defaultLanguage = "en",
    this.subtitleTracks = const [],
    this.audioTracks = const [],
  });

  static String _s(dynamic v) => (v ?? "").toString().trim();
  static int? _i(dynamic v) => int.tryParse((v ?? "").toString().trim());
  static int _int(dynamic v) => int.tryParse((v ?? "").toString().trim()) ?? 0;
  static bool _bool(dynamic v) {
    final s = (v ?? "").toString().trim().toLowerCase();
    return s == "1" || s == "true" || s == "yes";
  }

  factory EpisodeItem.fromApi(Map<String, dynamic> j) {
    final yt = _s(j["youtube_id"]).isEmpty
        ? _s(j["video_youtube_id"])
        : _s(j["youtube_id"]);
    final mp4 = _s(j["mp4_url"]);

    final keywords = _s(j["page_meta_keywords"]);
    final parsedTags = keywords.isEmpty
        ? const <String>[]
        : keywords
            .split(",")
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .take(12)
            .toList();

    final subtitleRaw = (j["subtitle_tracks"] as List?) ?? const [];
    final audioRaw = (j["audio_tracks"] as List?) ?? const [];

    final subtitles = subtitleRaw
        .whereType<Map>()
        .map((e) => SubtitleTrack.fromApi(Map<String, dynamic>.from(e)))
        .where((e) => e.isValid)
        .toList();

    final audios = audioRaw
        .whereType<Map>()
        .map((e) => AudioTrack.fromApi(Map<String, dynamic>.from(e)))
        .where((e) => e.isValid)
        .toList();

    return EpisodeItem(
      videoId: _i(j["id"]),
      title: _s(j["video_title"]).isEmpty ? _s(j["title"]) : _s(j["video_title"]),
      thumbUrl: _s(j["thumbnail_image"]).isEmpty
          ? _s(j["video_thumbnail_image"])
          : _s(j["thumbnail_image"]),
      youtubeId: yt.isEmpty ? null : yt,
      mp4Url: mp4.isEmpty ? null : mp4,
      description: _s(j["video_description"]).isEmpty
          ? _s(j["description"])
          : _s(j["video_description"]),
      tags: parsedTags,
      likeCount: _int(j["like_count"]),
      dislikeCount: _int(j["dislike_count"]),
      subscribeCount: _int(j["subscribe_count"]),
      subscribeEnabled: _bool(j["subscribe_enabled"]),
      subscribeLabel:
          _s(j["subscribe_label"]).isEmpty ? "Subscribe" : _s(j["subscribe_label"]),
      subscribeUrl: _s(j["subscribe_url"]),
      myReaction: _s(j["my_reaction"]).isEmpty
          ? "none"
          : _s(j["my_reaction"]).toLowerCase(),
      isSubscribed: _bool(j["is_subscribed"]),
      defaultLanguage:
          _s(j["default_language"]).isEmpty ? "en" : _s(j["default_language"]),
      subtitleTracks: subtitles,
      audioTracks: audios,
    );
  }

  bool get isPlayable {
    final yt = (youtubeId ?? "").trim();
    return yt.isNotEmpty;
  }

  bool get hasLanguageOptions => subtitleTracks.isNotEmpty || audioTracks.isNotEmpty;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class VideoPlayerScreen extends StatefulWidget {
  final String? title;
  final String? youtubeId;
  final String? mp4Url;
  final int? videoId;
  final String? thumbUrl;
  final String? description;
  final List<String>? tags;
  final List<EpisodeItem>? moreEpisodes;
  final List<EpisodeItem>? moreLikeThis;

  const VideoPlayerScreen({
    super.key,
    this.title,
    this.youtubeId,
    this.mp4Url,
    this.videoId,
    this.thumbUrl,
    this.description,
    this.tags,
    this.moreEpisodes,
    this.moreLikeThis,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with WidgetsBindingObserver {
  PlayerMode _mode = PlayerMode.none;
  YoutubePlayerController? _yt;
  VideoPlayerController? _vp;
  bool loading = true;
  String? err;

  int _loadGen = 0;
  bool _popping = false;
  bool _disposed = false;
  bool _navigatingAway = false;

  Timer? _debounceStats;
  int _views = 0;
  int _likes = 0;
  int _dislikes = 0;
  int _comments = 0;

  bool _subscribeEnabled = false;
  String _subscribeLabel = "Subscribe";
  String? _subscribeUrl;
  int _subscribeCount = 0;

  DateTime? _publishedAt;
  int _matchPercent = 0;

  bool _liked = false;
  bool _disliked = false;
  bool _addedToList = false;
  bool _isSubscribed = false;
  bool _savingReaction = false;
  bool _savingSubscribe = false;

  String _selectedSubtitleCode = "en";
  String _selectedAudioCode = "en";
  bool _captionsEnabled = true;

  late EpisodeItem _current;
  List<EpisodeItem> _apiEpisodes = [];
  List<EpisodeItem> _apiRelated = [];

  static const Color _accent = Colors.white;

  List<EpisodeItem> get _episodes =>
      _apiEpisodes.isNotEmpty ? _apiEpisodes : (widget.moreEpisodes ?? const []);
  List<EpisodeItem> get _moreLike =>
      _apiRelated.isNotEmpty ? _apiRelated : (widget.moreLikeThis ?? const []);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCurrent();
    _lockPortrait();
    _load();
  }

  void _initCurrent() {
    _current = EpisodeItem(
      videoId: widget.videoId,
      title: (widget.title ?? "Video").trim(),
      thumbUrl: (widget.thumbUrl ?? "").trim(),
      youtubeId: (widget.youtubeId ?? "").trim().isEmpty ? null : widget.youtubeId,
      mp4Url: (widget.mp4Url ?? "").trim().isEmpty ? null : widget.mp4Url,
      description: (widget.description ?? "").trim(),
      tags: widget.tags ?? const ["Kids", "Education", "Islamic Studies"],
    );
    _likes = _current.likeCount;
    _dislikes = _current.dislikeCount;
    _subscribeCount = _current.subscribeCount;
    _subscribeEnabled = _current.subscribeEnabled;
    _subscribeLabel = _current.subscribeLabel;
    _subscribeUrl =
        _current.subscribeUrl.trim().isEmpty ? null : _current.subscribeUrl;
    _liked = _current.myReaction == "like";
    _disliked = _current.myReaction == "dislike";
    _isSubscribed = _current.isSubscribed;
    _selectedSubtitleCode = _current.defaultLanguage;
    _selectedAudioCode = _current.defaultLanguage;
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _debounceStats?.cancel();
    _pauseAll();
    _yt?.dispose();
    _vp?.dispose();
    _yt = null;
    _vp = null;
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  void deactivate() {
    _pauseAll();
    super.deactivate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pauseAll();
    }
  }

  void _pauseAll() {
    try {
      _yt?.pause();
    } catch (_) {}
    try {
      _vp?.pause();
    } catch (_) {}
  }

  void _lockPortrait() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<String?> _getUserId() async {
    final id = await DBHelper.getActiveUserId();
    if (id == null || id.trim().isEmpty) return null;
    return id.trim();
  }

  void _goToLogin() {
    if (!mounted) return;
    _navigatingAway = true;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _fetchVideoDetail(int gen) async {
    final vid = _current.videoId ?? widget.videoId;
    if (vid == null || vid <= 0) return;

    final userId = await _getUserId();
    if (_disposed || gen != _loadGen) return;

    if (userId == null) {
      _goToLogin();
      return;
    }

    final uri = Uri.parse(
      "https://jinntv.com/api_forApp/video_detail.php?vid=$vid&user_id=$userId",
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 12));
    if (_disposed || gen != _loadGen) return;
    if (res.statusCode != 200) throw Exception("API error ${res.statusCode}");

    final decoded = jsonDecode(res.body);
    if (decoded is! Map || decoded["ok"] != true) {
      throw Exception(decoded["message"]?.toString() ?? "API error");
    }

    final data = decoded["data"];
    if (data is! Map) throw Exception("data missing");

    final video = data["video"];
    if (video is! Map) throw Exception("video not found");

    final current = EpisodeItem.fromApi(Map<String, dynamic>.from(video));

    final relList = ((data["related_videos"] as List?) ?? [])
        .whereType<Map>()
        .map((e) => EpisodeItem.fromApi(Map<String, dynamic>.from(e)))
        .where((e) => e.isPlayable)
        .toList();

    // ── FIX: episodes oldest → newest (Ep 1, Ep 2, …) instead of newest → oldest
    final epList = ((data["more_episodes"] as List?) ?? [])
        .whereType<Map>()
        .map((e) => EpisodeItem.fromApi(Map<String, dynamic>.from(e)))
        .where((e) => e.isPlayable)
        .toList()
      ..sort((a, b) => (a.videoId ?? 0).compareTo(b.videoId ?? 0));

    final SubtitleTrack? defaultSub = current.subtitleTracks
        .cast<SubtitleTrack?>()
        .firstWhere(
          (e) => e?.isDefault == true,
          orElse: () =>
              current.subtitleTracks.isNotEmpty ? current.subtitleTracks.first : null,
        );

    final AudioTrack? defaultAudio = current.audioTracks
        .cast<AudioTrack?>()
        .firstWhere(
          (e) => e?.isDefault == true,
          orElse: () => current.audioTracks.isNotEmpty ? current.audioTracks.first : null,
        );

    if (!mounted || gen != _loadGen) return;
    setState(() {
      _current = current;
      _apiRelated = relList;
      _apiEpisodes = epList;
      _likes = current.likeCount;
      _dislikes = current.dislikeCount;
      _subscribeCount = current.subscribeCount;
      _subscribeEnabled = current.subscribeEnabled;
      _subscribeLabel = current.subscribeLabel;
      _subscribeUrl =
          current.subscribeUrl.trim().isEmpty ? null : current.subscribeUrl.trim();
      _liked = current.myReaction == "like";
      _disliked = current.myReaction == "dislike";
      _isSubscribed = current.isSubscribed;
      _selectedSubtitleCode = defaultSub?.code ?? current.defaultLanguage;
      _selectedAudioCode = defaultAudio?.code ?? current.defaultLanguage;
    });
  }

  Future<void> _load() async {
    final gen = ++_loadGen;
    if (!_disposed) {
      setState(() {
        loading = true;
        err = null;
      });
    }

    try {
      await _fetchVideoDetail(gen);
      if (_disposed || gen != _loadGen || _navigatingAway) return;

      await _preparePlayer(gen);
      if (_disposed || gen != _loadGen || _navigatingAway) return;

      if (_mode == PlayerMode.youtube) _scheduleStatsFetch(gen);

      if (!mounted || gen != _loadGen) return;
      setState(() => loading = false);
    } catch (e) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        loading = false;
        err = e.toString();
      });
    }
  }

  Future<void> _preparePlayer(int gen) async {
    if (_disposed || gen != _loadGen) return;

    _pauseAll();
    _yt?.dispose();
    _vp?.dispose();
    _yt = null;
    _vp = null;
    _mode = PlayerMode.none;

    final youtubeId = (_current.youtubeId ?? "").trim();

    if (youtubeId.isNotEmpty) {
      _yt = YoutubePlayerController(
        initialVideoId: youtubeId,
        flags: YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          enableCaption: _captionsEnabled,
          forceHD: true,
          useHybridComposition: true,
        ),
      );
      _mode = PlayerMode.youtube;
      await WakelockPlus.enable();
      return;
    }

    throw Exception("This video is not available for in-app playback.");
  }

  void _scheduleStatsFetch(int gen) {
    _debounceStats?.cancel();
    _debounceStats = Timer(const Duration(milliseconds: 300), () {
      _fetchYoutubeStats(gen);
    });
  }

  Future<void> _fetchYoutubeStats(int gen) async {
    final id = (_current.youtubeId ?? "").trim();
    if (id.isEmpty || _disposed || gen != _loadGen) return;

    try {
      final apiKey = await DBHelper.getYoutubeApiKey();
      if (apiKey == null || apiKey.isEmpty) return;
      final uri = Uri.https("www.googleapis.com", "/youtube/v3/videos", {
        "part": "statistics,snippet",
        "id": id,
        "key": apiKey,
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (_disposed || gen != _loadGen || res.statusCode != 200) return;

      final decoded = jsonDecode(res.body);
      final items = decoded["items"];
      if (items is! List || items.isEmpty) return;

      final item = items.first as Map<String, dynamic>;
      final stats = (item["statistics"] ?? {}) as Map<String, dynamic>;
      final snip = (item["snippet"] ?? {}) as Map<String, dynamic>;

      int toInt(dynamic v) => int.tryParse("${v ?? 0}") ?? 0;

      final views = toInt(stats["viewCount"]);
      final comments = toInt(stats["commentCount"]);
      final publishedAt = DateTime.tryParse("${snip["publishedAt"] ?? ""}");
      final matchPct = _calcMatchPercent(
        views: views,
        likes: _likes,
        comments: comments,
      );

      if (!mounted || gen != _loadGen) return;
      setState(() {
        _views = views;
        _comments = comments;
        _publishedAt = publishedAt;
        _matchPercent = matchPct;
      });
    } catch (_) {}
  }

  int _calcMatchPercent({
    required int views,
    required int likes,
    required int comments,
  }) {
    if (views <= 0) return 0;
    double score = (likes / views * 9000) + (comments / views * 12000);
    int pct = score.round().clamp(0, 99);
    if (views < 200) pct = min(pct, 75);
    if (views < 50) pct = min(pct, 65);
    return pct;
  }

  Future<void> _handleBack() async {
    if (_popping) return;
    _popping = true;
    _navigatingAway = true;
    _loadGen++;
    _debounceStats?.cancel();
    _pauseAll();
    _yt?.dispose();
    _vp?.dispose();
    _yt = null;
    _vp = null;
    WakelockPlus.disable();
    if (mounted) Navigator.of(context).pop();
  }

  void _share() {
    final youtubeId = (_current.youtubeId ?? "").trim();
    final videoId = (_current.videoId ?? 0);

    if (youtubeId.isNotEmpty) {
      Share.share("https://www.youtube.com/watch?v=$youtubeId");
      return;
    }

    if (videoId > 0) {
      Share.share("https://www.jinntv.com/watch/$videoId");
      return;
    }

    _snack("Share link not available");
  }

  Future<void> _openYoutubeFullScreen() async {
    final yt = _yt;
    final youtubeId = (_current.youtubeId ?? "").trim();
    if (yt == null || youtubeId.isEmpty) return;
    try {
      yt.pause();
    } catch (_) {}

    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) =>
            YoutubeFullScreenPage(youtubeId: youtubeId, accent: _accent),
      ),
    );
  }

  Future<void> _openMp4FullScreen() async {
    final vp = _vp;
    if (vp == null || !vp.value.isInitialized) return;
    final wasPlaying = vp.value.isPlaying;
    if (wasPlaying) {
      try {
        await vp.pause();
      } catch (_) {}
    }

    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) =>
            Mp4FullScreenPage(controller: vp, accent: _accent),
      ),
    );

    if (!_disposed && mounted) {
      try {
        await vp.play();
      } catch (_) {}
    }
  }

  Future<void> _saveAction(String action) async {
    final vid = _current.videoId ?? widget.videoId;
    if (vid == null || vid <= 0) return;
    if ((action == "like" || action == "dislike") && _savingReaction) return;
    if ((action == "subscribe" || action == "unsubscribe") && _savingSubscribe) {
      return;
    }

    final userId = await _getUserId();
    if (userId == null) {
      if (!mounted) return;
      _goToLogin();
      return;
    }

    setState(() {
      if (action == "like" || action == "dislike") _savingReaction = true;
      if (action == "subscribe" || action == "unsubscribe") _savingSubscribe = true;
    });

    try {
      final res = await http.post(
        Uri.parse("https://jinntv.com/api_forApp/video_action.php"),
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: {"video_id": vid.toString(), "user_id": userId, "action": action},
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;
      if (res.statusCode != 200) {
        _snack("Server error: ${res.statusCode}");
        return;
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! Map || decoded["ok"] != true) {
        _snack(
          decoded is Map
              ? (decoded["message"]?.toString() ?? "Action failed")
              : "Action failed",
        );
        return;
      }

      final data = decoded["data"] ?? {};
      setState(() {
        _likes = int.tryParse('${data["like_count"] ?? 0}') ?? 0;
        _dislikes = int.tryParse('${data["dislike_count"] ?? 0}') ?? 0;
        _subscribeCount = int.tryParse('${data["subscribe_count"] ?? 0}') ?? 0;
        final reaction = '${data["my_reaction"] ?? "none"}'.trim().toLowerCase();
        _liked = reaction == "like";
        _disliked = reaction == "dislike";
        _isSubscribed = '${data["is_subscribed"] ?? 0}' == '1';
      });
    } on TimeoutException {
      if (mounted) _snack("Request timed out. Try again.");
    } catch (e) {
      if (mounted) _snack("Network error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _savingReaction = false;
          _savingSubscribe = false;
        });
      }
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Future<void> _openItem(EpisodeItem item) async {
  //   final vid = item.videoId;
  //   if (vid != null && vid > 0) {
  //     await Navigator.push(
  //       context,
  //       MaterialPageRoute(builder: (_) => VideoPlayerScreen(videoId: vid)),
  //     );
  //     return;
  //   }
  //   _selectEpisodeInPlace(item);
  // }
    Future<void> _openItem(EpisodeItem item) async {
    _selectEpisodeInPlace(item);
  }

  void _selectEpisodeInPlace(EpisodeItem ep) async {
    _loadGen++;

    _debounceStats?.cancel();

    try {
      _yt?.pause();
      _yt?.dispose();
    } catch (_) {}

    try {
      await _vp?.pause();
      await _vp?.dispose();
    } catch (_) {}

    _yt = null;
    _vp = null;
    _mode = PlayerMode.none;

    if (!mounted) return;

    setState(() {
      _current = ep;
      loading = true;
      err = null;
      _views = 0;
      _likes = ep.likeCount;
      _dislikes = ep.dislikeCount;
      _subscribeCount = ep.subscribeCount;
      _comments = 0;
      _subscribeEnabled = ep.subscribeEnabled;
      _subscribeLabel = ep.subscribeLabel;
      _subscribeUrl = ep.subscribeUrl.trim().isEmpty ? null : ep.subscribeUrl.trim();
      _publishedAt = null;
      _matchPercent = 0;
      _liked = ep.myReaction == "like";
      _disliked = ep.myReaction == "dislike";
      _isSubscribed = ep.isSubscribed;
      _addedToList = false;
      _selectedSubtitleCode = ep.defaultLanguage;
      _selectedAudioCode = ep.defaultLanguage;
      _captionsEnabled = true;
    });

    await _load();
  }

  void _openLanguageSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setM) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Audio & Subtitles",
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                if (_current.subtitleTracks.isNotEmpty) ...[
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _captionsEnabled,
                    activeColor: _accent,
                    onChanged: (v) async {
                      setState(() => _captionsEnabled = v);
                      setM(() {});
                      if (_mode == PlayerMode.youtube) {
                        Navigator.pop(ctx);
                        await _load();
                      }
                    },
                    title: const Text(
                      "Show Subtitles",
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _sheetLabel("Subtitle Language"),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _current.subtitleTracks.map((t) {
                      final sel = _selectedSubtitleCode == t.code;
                      return _ChipBtn(
                        label: t.label,
                        selected: sel,
                        accent: _accent,
                        onTap: () {
                          setState(() => _selectedSubtitleCode = t.code);
                          setM(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_current.audioTracks.isNotEmpty) ...[
                  _sheetLabel("Audio Language"),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _current.audioTracks.map((t) {
                      final sel = _selectedAudioCode == t.code;
                      return _ChipBtn(
                        label: t.label,
                        selected: sel,
                        accent: _accent,
                        onTap: () async {
                          setState(() => _selectedAudioCode = t.code);
                          setM(() {});
                          await _switchAudioTrack(t);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetLabel(String text) => const Text(
        "",
      ).copyWithText(text);

  Future<void> _switchAudioTrack(AudioTrack track) async {
    _snack("Alternate audio is not available in this player mode.");
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _handleBack();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        appBar: _buildAppBar(),
        body: Stack(
          children: [
            if (loading)
              const Center(
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              ),
            if (!loading && err != null) _buildError(err!),
            if (!loading && err == null) _buildBody(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0F0F0F),
      elevation: 0,
      leadingWidth: 48,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: _handleBack,
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset('assets/images/jinn-tv-logo.png', height: 38),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SearchScreen()),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildError(String e) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              Text(
                e,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text("Retry", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );

  // ── FIX: Player is now PINNED at the top. Only the content below scrolls.
  // Previously, the hero player was the first child of a single ListView,
  // so when the user scrolled, the YouTube WebView scrolled off-screen,
  // got recycled/paused, and on scroll-up it restarted from 0:00.
  Widget _buildBody() {
    return Column(
      children: [
        // Sticky video player — never scrolls.
        _buildHero(),
        // Everything below scrolls independently.
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            physics: const ClampingScrollPhysics(),
            children: [
              const SizedBox(height: 12),
              _buildInfoSection(),
              const SizedBox(height: 10),
              _buildActionRow(),
              const Divider(color: Colors.white10, height: 24),
              _buildDescriptionAndTags(),
              const SizedBox(height: 20),
              _buildMoreEpisodes(),
              _buildRelatedVideos(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHero() {
    return VideoHeroPlayer(
      mode: _mode,
      yt: _yt,
      vp: _vp,
      thumbUrl: _current.thumbUrl,
      accent: _accent,
      onMp4Fullscreen: _openMp4FullScreen,
      onYoutubeFullscreen: _openYoutubeFullScreen,
    );
  }

  Widget _buildInfoSection() {
    final year = _publishedAt?.year;
    final showMatch = _matchPercent > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _current.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (showMatch)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F9D58).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "${_matchPercent}% Match",
                    style: const TextStyle(
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              Text(
                _fmtViews(_views),
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              if (year != null)
                Text(
                  "$year",
                  style: const TextStyle(color: Colors.white38, fontSize: 13),
                ),
              _hdBadge(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hdBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white30),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          "HD",
          style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      );

  Widget _buildActionRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _ReactionBtn(
              icon: _liked ? Icons.thumb_up : Icons.thumb_up_outlined,
              label: _fmt(_likes),
              active: _liked,
              accent: _accent,
              loading: _savingReaction,
              onTap: () => _saveAction("like"),
            ),
            const SizedBox(width: 2),
            Container(
              width: 1,
              height: 24,
              color: Colors.white12,
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
            _ReactionBtn(
              icon: _disliked ? Icons.thumb_down : Icons.thumb_down_outlined,
              label: _fmt(_dislikes),
              active: _disliked,
              accent: _accent,
              loading: _savingReaction,
              onTap: () => _saveAction("dislike"),
            ),
            const SizedBox(width: 8),
            _ActionChip(
              icon: Icons.share_outlined,
              label: "Share",
              onTap: _share,
            ),
            const SizedBox(width: 8),
            _ActionChip(
              icon: _addedToList ? Icons.check : Icons.add,
              label: "My List",
              active: _addedToList,
              onTap: () => setState(() => _addedToList = !_addedToList),
            ),
            if (_subscribeEnabled) ...[
              const SizedBox(width: 8),
              _SubscribeBtn(
                isSubscribed: _isSubscribed,
                label: _subscribeLabel,
                count: _subscribeCount,
                loading: _savingSubscribe,
                accent: _accent,
                onTap: () => _saveAction(_isSubscribed ? "unsubscribe" : "subscribe"),
              ),
            ],
            const SizedBox(width: 8),
            if (_current.hasLanguageOptions)
              _ActionChip(
                icon: Icons.closed_caption_outlined,
                label: "CC",
                onTap: _openLanguageSheet,
              ),
            const SizedBox(width: 8),
            if (_comments > 0)
              _ActionChip(
                icon: Icons.comment_outlined,
                label: _fmt(_comments),
                onTap: null,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionAndTags() {
    final desc = (_current.description ?? widget.description ?? "").trim();
    final tags = _current.tags.isNotEmpty
        ? _current.tags
        : (widget.tags ?? const ["Kids", "Education", "Islamic Studies"]);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (desc.isNotEmpty) ...[
            _ExpandableText(text: desc),
            const SizedBox(height: 12),
          ],
          if (tags.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags.take(12).map((t) => _tagChip(t)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _tagChip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          "#$label",
          style: const TextStyle(
            color: Color(0xFF3EA6FF),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _buildMoreEpisodes() {
    // ── FIX: oldest → newest order (Ep 1, Ep 2, …) by ascending videoId.
    final list = _episodes.where((e) => e.isPlayable).toList()
      ..sort((a, b) => (a.videoId ?? 0).compareTo(b.videoId ?? 0));
    if (list.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "More Episodes",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: min(6, list.length),
          itemBuilder: (_, i) => _EpisodeTile(
            ep: list[i],
            accent: _accent,
            onTap: () => _openItem(list[i]),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildRelatedVideos() {
    final list = _moreLike.where((e) => e.isPlayable).toList();
    if (list.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.white10, height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "Up Next",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: min(10, list.length),
          itemBuilder: (_, i) => _RelatedTile(
            video: list[i],
            onTap: () => _openItem(list[i]),
          ),
        ),
      ],
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return "${(n / 1000000).toStringAsFixed(1)}M";
    if (n >= 1000) return "${(n / 1000).toStringAsFixed(1)}K";
    return "$n";
  }

  String _fmtViews(int n) {
    if (n == 0) return "";
    if (n >= 1000000) return "${(n / 1000000).toStringAsFixed(1)}M views";
    if (n >= 1000) return "${(n / 1000).toStringAsFixed(1)}K views";
    return "$n views";
  }
}

class _ReactionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool loading;
  final Color accent;
  final VoidCallback onTap;

  const _ReactionBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.loading,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? Colors.white54 : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? Colors.black : Colors.white, size: 16),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.black : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubscribeBtn extends StatelessWidget {
  final bool isSubscribed;
  final String label;
  final int count;
  final bool loading;
  final Color accent;
  final VoidCallback onTap;

  const _SubscribeBtn({
    required this.isSubscribed,
    required this.label,
    required this.count,
    required this.loading,
    required this.accent,
    required this.onTap,
  });

  String _fmt(int n) {
    if (n >= 1000000) return "${(n / 1000000).toStringAsFixed(1)}M";
    if (n >= 1000) return "${(n / 1000).toStringAsFixed(1)}K";
    return "$n";
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSubscribed ? Colors.white12 : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSubscribed
                  ? Icons.notifications_active_outlined
                  : Icons.subscriptions_outlined,
              color: isSubscribed ? Colors.white : Colors.black,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              isSubscribed ? "Subscribed" : label,
              style: TextStyle(
                color: isSubscribed ? Colors.white : Colors.black,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Text(
                _fmt(count),
                style: TextStyle(
                  color: isSubscribed ? Colors.white60 : Colors.black54,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExpandableText extends StatefulWidget {
  final String text;
  const _ExpandableText({required this.text});

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.text,
            maxLines: _expanded ? null : 3,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _expanded ? "Show less" : "...more",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _ChipBtn({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white12,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.white : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  final EpisodeItem ep;
  final Color accent;
  final VoidCallback onTap;

  const _EpisodeTile({
    required this.ep,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 152,
                height: 86,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: Colors.white10),
                    if (ep.thumbUrl.trim().isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: ep.thumbUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 400,
                        fadeInDuration: const Duration(milliseconds: 80),
                        placeholder: (_, __) => Container(color: Colors.white10),
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.image, color: Colors.white24),
                      ),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ep.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "JinnTV",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                  if ((ep.description ?? "").trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      ep.description!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.more_vert, color: Colors.white38, size: 18),
          ],
        ),
      ),
    );
  }
}

class _RelatedTile extends StatelessWidget {
  final EpisodeItem video;
  final VoidCallback onTap;

  const _RelatedTile({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 140,
                height: 80,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: Colors.white10),
                    if (video.thumbUrl.trim().isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: video.thumbUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 380,
                        fadeInDuration: const Duration(milliseconds: 80),
                        placeholder: (_, __) => Container(color: Colors.white10),
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.image, color: Colors.white24),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "JinnTV",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.more_vert, color: Colors.white38, size: 18),
          ],
        ),
      ),
    );
  }
}

extension on Widget {
  Widget copyWithText(String text) {
    if (this is Text) {
      final t = this as Text;
      return Text(
        text,
        style: t.style,
        textAlign: t.textAlign,
        overflow: t.overflow,
        maxLines: t.maxLines,
      );
    }
    return this;
  }
}