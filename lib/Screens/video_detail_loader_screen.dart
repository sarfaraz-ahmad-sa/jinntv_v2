// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'api_client.dart';

enum _PlayerMode { none, youtube, mp4 }

class VideoPlayerScreen extends StatefulWidget {
  final String? title;
  final String? youtubeId; // can be id or URL
  final String? mp4Url;    // can be absolute or relative
  final int? videoId;      // (optional) if you later load details from API

  const VideoPlayerScreen({
    super.key,
    this.title,
    this.youtubeId,
    this.mp4Url,
    this.videoId,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  final api = ApiClient(baseUrl: "https://www.jinntv.com");

  YoutubePlayerController? _yt;
  VideoPlayerController? _vp;
  _PlayerMode _mode = _PlayerMode.none;

  bool loading = true;
  String? err;

  String _s(dynamic v) => (v ?? '').toString().trim();

  String _makeAbsoluteUrl(String baseUrl, String url) {
    final s = url.trim();
    if (s.isEmpty) return '';
    final uri = Uri.tryParse(s);
    if (uri != null && uri.hasScheme) return s;
    return Uri.parse(baseUrl).resolve(s).toString();
  }

  String _extractYoutubeId(String input) {
    final s = input.trim();
    if (s.isEmpty) return '';

    // direct 11-char id
    final idLike = RegExp(r'^[a-zA-Z0-9_-]{11}$');
    if (idLike.hasMatch(s)) return s;

    final uri = Uri.tryParse(s);
    if (uri == null) return '';

    // youtu.be/<id>
    if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }

    // youtube.com/watch?v=<id>
    final v = uri.queryParameters['v'];
    if (v != null && v.isNotEmpty) return v;

    // /shorts/<id> or /embed/<id>
    if (uri.pathSegments.length >= 2) {
      final a = uri.pathSegments[0];
      final b = uri.pathSegments[1];
      if (a == 'shorts' || a == 'embed') return b;
    }

    return '';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _yt?.dispose();
    _vp?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = null;
    });

    try {
      await _preparePlayer();
      if (!mounted) return;
      setState(() => loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        err = e.toString();
        loading = false;
      });
    }
  }

  Future<void> _preparePlayer() async {
    // dispose old
    _yt?.dispose();
    _vp?.dispose();
    _yt = null;
    _vp = null;
    _mode = _PlayerMode.none;

    final youtubeRaw = _s(widget.youtubeId);
    final youtubeId = _extractYoutubeId(youtubeRaw);

    final mp4Raw = _s(widget.mp4Url);
    final mp4 = _makeAbsoluteUrl(api.baseUrl, mp4Raw);

    debugPrint("PLAYER => youtubeRaw=$youtubeRaw youtubeId=$youtubeId mp4=$mp4");

    // Prefer YouTube
    if (youtubeId.isNotEmpty) {
      _yt = YoutubePlayerController(
        initialVideoId: youtubeId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          disableDragSeek: false,
          enableCaption: true,
          isLive: false,
        ),
      );
      _mode = _PlayerMode.youtube;
      return;
    }

    // Fallback MP4
    if (mp4.isNotEmpty) {
      final c = VideoPlayerController.networkUrl(Uri.parse(mp4));
      _vp = c;
      await c.initialize();
      await c.setLooping(true);
      await c.play();
      _mode = _PlayerMode.mp4;
      return;
    }

    throw Exception("No playable source: youtubeId/mp4Url empty");
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? "Player";

    if (loading) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (err != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, title: Text(title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              err!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      );
    }

    Widget player;

    if (_mode == _PlayerMode.youtube && _yt != null) {
      player = YoutubePlayer(
        controller: _yt!,
        showVideoProgressIndicator: true,
      );
    } else if (_mode == _PlayerMode.mp4 && _vp != null && _vp!.value.isInitialized) {
      player = AspectRatio(
        aspectRatio: _vp!.value.aspectRatio == 0 ? 16 / 9 : _vp!.value.aspectRatio,
        child: VideoPlayer(_vp!),
      );
    } else {
      player = const Center(
        child: Text("No video", style: TextStyle(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: Text(title)),
      body: Center(child: player),
    );
  }
}
