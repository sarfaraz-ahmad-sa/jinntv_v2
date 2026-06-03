import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

enum PlayerMode { none, youtube, mp4 }

class VideoHeroPlayer extends StatefulWidget {
  final PlayerMode mode;
  final YoutubePlayerController? yt;
  final VideoPlayerController? vp;
  final String thumbUrl;
  final Color accent;
  final VoidCallback? onYoutubeFullscreen;
  final Future<void> Function()? onMp4Fullscreen;

  const VideoHeroPlayer({
    super.key,
    required this.mode,
    required this.thumbUrl,
    required this.accent,
    this.yt,
    this.vp,
    this.onYoutubeFullscreen,
    this.onMp4Fullscreen,
  });

  @override
  State<VideoHeroPlayer> createState() => _VideoHeroPlayerState();
}

class _VideoHeroPlayerState extends State<VideoHeroPlayer>
    with SingleTickerProviderStateMixin {
  bool _overlayVisible = true;
  Timer? _overlayTimer;
  Timer? _seekToastTimer;
  String _seekToastText = '';
  bool _showSeekToast = false;

  int _seekSide = 0; // -1 left, 1 right, 0 none
  Timer? _seekFlashTimer;

  late final AnimationController _playPauseAnim;

  @override
  void initState() {
    super.initState();
    _playPauseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scheduleHide();
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    _seekToastTimer?.cancel();
    _seekFlashTimer?.cancel();
    _playPauseAnim.dispose();
    super.dispose();
  }

  void _scheduleHide() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _overlayVisible) {
        setState(() => _overlayVisible = false);
      }
    });
  }

  void _showOverlay({bool autoHide = true}) {
    if (!mounted) return;
    setState(() => _overlayVisible = true);
    if (autoHide) _scheduleHide();
    else _overlayTimer?.cancel();
  }

  void _toggleOverlay() {
    if (!mounted) return;
    final next = !_overlayVisible;
    setState(() => _overlayVisible = next);
    if (next) _scheduleHide();
    else _overlayTimer?.cancel();
  }

  Future<void> _togglePlayPause() async {
    final c = widget.vp;
    if (c == null) return;
    if (c.value.isPlaying) {
      await c.pause();
      _showOverlay(autoHide: false);
    } else {
      await c.play();
      _scheduleHide();
    }
    if (mounted) setState(() {});
  }

  Future<void> _seekBy(Duration d, {int side = 0}) async {
    final c = widget.vp;
    if (c == null || !c.value.isInitialized) return;

    var next = c.value.position + d;
    if (next < Duration.zero) next = Duration.zero;
    if (next > c.value.duration) next = c.value.duration;
    await c.seekTo(next);

    _seekFlashTimer?.cancel();
    setState(() => _seekSide = side);
    _seekFlashTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _seekSide = 0);
    });

    _seekToastTimer?.cancel();
    final sec = d.inSeconds.abs();
    setState(() {
      _seekToastText = d.isNegative ? '-${sec}s' : '+${sec}s';
      _showSeekToast = true;
    });
    _seekToastTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showSeekToast = false);
    });

    _showOverlay(autoHide: true);
    if (mounted) setState(() {});
  }

  void _handleDoubleTap(TapDownDetails d, double width) {
    if (d.localPosition.dx < width / 2) {
      _seekBy(const Duration(seconds: -10), side: -1);
    } else {
      _seekBy(const Duration(seconds: 10), side: 1);
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Widget _thumbImage() {
    final u = widget.thumbUrl.trim();
    if (u.isEmpty) return Container(color: Colors.black);
    return CachedNetworkImage(
      imageUrl: u,
      fit: BoxFit.cover,
      memCacheWidth: 900,
      fadeInDuration: const Duration(milliseconds: 80),
      placeholder: (_, __) => Container(color: Colors.black),
      errorWidget: (_, __, ___) => Container(color: Colors.black),
    );
  }

  // ── YouTube mode ──────────────────────────────────────────────────────────
  Widget _buildYoutube() {
    return RepaintBoundary(
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: YoutubePlayer(
          controller: widget.yt!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: const Color(0xFFFF0000),
          progressColors: const ProgressBarColors(
            playedColor: Color(0xFFFF0000),
            handleColor: Color(0xFFFF0000),
            bufferedColor: Colors.white30,
            backgroundColor: Colors.white12,
          ),
          bottomActions: [
            const SizedBox(width: 10),
            const CurrentPosition(),
            const ProgressBar(isExpanded: true),
            const RemainingDuration(),
            const SizedBox(width: 4),
            // ── Fullscreen button ──
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.fullscreen, color: Colors.white, size: 24),
              onPressed: widget.onYoutubeFullscreen,
            ),
            const SizedBox(width: 4),
          ],
          topActions: const [],
          // Disable the built-in fullscreen so we control it ourselves
          onEnded: (_) {},
        ),
      ),
    );
  }

  // ── MP4 mode ──────────────────────────────────────────────────────────────
  Widget _buildMp4(BoxConstraints bc) {
    final c = widget.vp!;
    final isPlaying = c.value.isPlaying;
    final pos = c.value.position;
    final dur = c.value.duration;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleOverlay,
        onDoubleTapDown: (d) => _handleDoubleTap(d, bc.maxWidth),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: c.value.size.width,
                  height: c.value.size.height,
                  child: VideoPlayer(c),
                ),
              ),
            ),

            if (_seekSide != 0)
              Positioned(
                left: _seekSide < 0 ? 0 : null,
                right: _seekSide > 0 ? 0 : null,
                top: 0,
                bottom: 0,
                width: bc.maxWidth * 0.35,
                child: _SeekFlash(
                  side: _seekSide,
                  accent: widget.accent,
                  seconds: 10,
                ),
              ),

            if (_showSeekToast)
              Center(child: _SeekToast(text: _seekToastText)),

            AnimatedOpacity(
              opacity: _overlayVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_overlayVisible,
                child: _Mp4Overlay(
                  isPlaying: isPlaying,
                  position: _formatDuration(pos),
                  duration: _formatDuration(dur),
                  accent: widget.accent,
                  vp: c,
                  onPlayPause: _togglePlayPause,
                  onSeekBack: () => _seekBy(const Duration(seconds: -10), side: -1),
                  onSeekForward: () => _seekBy(const Duration(seconds: 10), side: 1),
                  onFullscreen: () async {
                    _showOverlay(autoHide: false);
                    await widget.onMp4Fullscreen?.call();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == PlayerMode.youtube && widget.yt != null) {
      return _buildYoutube();
    }

    if (widget.mode == PlayerMode.mp4 &&
        widget.vp != null &&
        widget.vp!.value.isInitialized) {
      return LayoutBuilder(
        builder: (_, bc) => ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: widget.vp!,
          builder: (_, __, ___) => _buildMp4(bc),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _thumbImage(),
          Container(color: Colors.black.withOpacity(0.55)),
          const Center(
            child: SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Seek flash ─────────────────────────────────────────────────────────────
class _SeekFlash extends StatelessWidget {
  final int side;
  final Color accent;
  final int seconds;

  const _SeekFlash({
    required this.side,
    required this.accent,
    required this.seconds,
  });

  @override
  Widget build(BuildContext context) {
    final isLeft = side < 0;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
          colors: [accent.withOpacity(0.25), Colors.transparent],
        ),
        borderRadius: BorderRadius.only(
          topLeft: isLeft ? const Radius.circular(16) : Radius.zero,
          bottomLeft: isLeft ? const Radius.circular(16) : Radius.zero,
          topRight: !isLeft ? const Radius.circular(16) : Radius.zero,
          bottomRight: !isLeft ? const Radius.circular(16) : Radius.zero,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLeft ? Icons.replay_10 : Icons.forward_10,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              isLeft ? '-${seconds}s' : '+${seconds}s',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Seek toast ─────────────────────────────────────────────────────────────
class _SeekToast extends StatelessWidget {
  final String text;
  const _SeekToast({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 15,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── MP4 overlay ────────────────────────────────────────────────────────────
class _Mp4Overlay extends StatelessWidget {
  final bool isPlaying;
  final String position;
  final String duration;
  final Color accent;
  final VideoPlayerController vp;
  final VoidCallback onPlayPause;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekForward;
  final VoidCallback onFullscreen;

  const _Mp4Overlay({
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.accent,
    required this.vp,
    required this.onPlayPause,
    required this.onSeekBack,
    required this.onSeekForward,
    required this.onFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.3, 0.7, 1.0],
          colors: [
            Colors.black.withOpacity(0.5),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.75),
          ],
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CtrlBtn(icon: Icons.replay_10, size: 38, onTap: onSeekBack),
                const SizedBox(width: 24),
                _CtrlBtn(
                  icon: isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  size: 64,
                  onTap: onPlayPause,
                ),
                const SizedBox(width: 24),
                _CtrlBtn(icon: Icons.forward_10, size: 38, onTap: onSeekForward),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: VideoProgressIndicator(
                    vp,
                    allowScrubbing: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    colors: VideoProgressColors(
                      playedColor: const Color(0xFFFF0000),
                      bufferedColor: Colors.white30,
                      backgroundColor: Colors.white.withOpacity(0.2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 8, 8),
                  child: Row(
                    children: [
                      Text(position,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      const Text(' / ',
                          style: TextStyle(color: Colors.white54, fontSize: 12)),
                      Text(duration,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                      const Spacer(),
                      GestureDetector(
                        onTap: onFullscreen,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.fullscreen, color: Colors.white, size: 24),
                        ),
                      ),
                    ],
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

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _CtrlBtn({required this.icon, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: Colors.white, size: size, shadows: [
        Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 12),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MP4 Full Screen Page
// ══════════════════════════════════════════════════════════════════════════════
class Mp4FullScreenPage extends StatefulWidget {
  final VideoPlayerController controller;
  final Color accent;

  const Mp4FullScreenPage({
    super.key,
    required this.controller,
    required this.accent,
  });

  @override
  State<Mp4FullScreenPage> createState() => _Mp4FullScreenPageState();
}

class _Mp4FullScreenPageState extends State<Mp4FullScreenPage> {
  bool _overlay = true;
  Timer? _overlayTimer;
  Timer? _seekToastTimer;
  String _seekToastText = '';
  bool _showSeekToast = false;
  int _seekSide = 0;
  Timer? _seekFlashTimer;

  @override
  void initState() {
    super.initState();
    _enterLandscape();
    _scheduleHide();
    if (!widget.controller.value.isPlaying) widget.controller.play();
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    _seekToastTimer?.cancel();
    _seekFlashTimer?.cancel();
    _exitLandscape();
    super.dispose();
  }

  Future<void> _enterLandscape() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _exitLandscape() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  void _scheduleHide() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _overlay) setState(() => _overlay = false);
    });
  }

  void _toggleOverlay() {
    if (!mounted) return;
    final next = !_overlay;
    setState(() => _overlay = next);
    if (next) _scheduleHide();
    else _overlayTimer?.cancel();
  }

  Future<void> _seekBy(Duration d, {int side = 0}) async {
    final c = widget.controller;
    if (!c.value.isInitialized) return;

    var next = c.value.position + d;
    if (next < Duration.zero) next = Duration.zero;
    if (next > c.value.duration) next = c.value.duration;
    await c.seekTo(next);

    _seekFlashTimer?.cancel();
    setState(() => _seekSide = side);
    _seekFlashTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _seekSide = 0);
    });

    _seekToastTimer?.cancel();
    final sec = d.inSeconds.abs();
    setState(() {
      _seekToastText = d.isNegative ? '-${sec}s' : '+${sec}s';
      _showSeekToast = true;
    });
    _seekToastTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showSeekToast = false);
    });

    _scheduleHide();
    if (mounted) setState(() {});
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: c,
        builder: (_, val, __) {
          final isPlaying = val.isPlaying;
          final pos = val.position;
          final dur = val.duration;

          return LayoutBuilder(
            builder: (_, bc) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleOverlay,
              onDoubleTapDown: (d) {
                if (d.localPosition.dx < bc.maxWidth / 2) {
                  _seekBy(const Duration(seconds: -10), side: -1);
                } else {
                  _seekBy(const Duration(seconds: 10), side: 1);
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: ClipRect(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: val.size.width,
                          height: val.size.height,
                          child: VideoPlayer(c),
                        ),
                      ),
                    ),
                  ),

                  if (_seekSide != 0)
                    Positioned(
                      left: _seekSide < 0 ? 0 : null,
                      right: _seekSide > 0 ? 0 : null,
                      top: 0,
                      bottom: 0,
                      width: bc.maxWidth * 0.3,
                      child: _SeekFlash(
                        side: _seekSide,
                        accent: widget.accent,
                        seconds: 10,
                      ),
                    ),

                  if (_showSeekToast)
                    Center(child: _SeekToast(text: _seekToastText)),

                  AnimatedOpacity(
                    opacity: _overlay ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: !_overlay,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.25, 0.75, 1.0],
                            colors: [
                              Colors.black.withOpacity(0.55),
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withOpacity(0.75),
                            ],
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Top bar
                            Positioned(
                              top: 0, left: 0, right: 0,
                              child: SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 4),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.arrow_back,
                                            color: Colors.white, size: 24),
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Center controls
                            Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _CtrlBtn(
                                    icon: Icons.replay_10,
                                    size: 42,
                                    onTap: () => _seekBy(
                                        const Duration(seconds: -10), side: -1),
                                  ),
                                  const SizedBox(width: 28),
                                  _CtrlBtn(
                                    icon: isPlaying
                                        ? Icons.pause_circle_filled
                                        : Icons.play_circle_filled,
                                    size: 72,
                                    onTap: () async {
                                      if (c.value.isPlaying) {
                                        await c.pause();
                                        if (mounted) {
                                          setState(() => _overlay = true);
                                          _overlayTimer?.cancel();
                                        }
                                      } else {
                                        await c.play();
                                        _scheduleHide();
                                      }
                                      if (mounted) setState(() {});
                                    },
                                  ),
                                  const SizedBox(width: 28),
                                  _CtrlBtn(
                                    icon: Icons.forward_10,
                                    size: 42,
                                    onTap: () => _seekBy(
                                        const Duration(seconds: 10), side: 1),
                                  ),
                                ],
                              ),
                            ),

                            // Bottom bar
                            Positioned(
                              left: 0, right: 0, bottom: bottomPad,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    child: VideoProgressIndicator(
                                      c,
                                      allowScrubbing: true,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      colors: VideoProgressColors(
                                        playedColor: const Color(0xFFFF0000),
                                        bufferedColor: Colors.white30,
                                        backgroundColor:
                                            Colors.white.withOpacity(0.2),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 12),
                                    child: Row(
                                      children: [
                                        Text(_fmt(pos),
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600)),
                                        const Text(' / ',
                                            style: TextStyle(
                                                color: Colors.white54,
                                                fontSize: 13)),
                                        Text(_fmt(dur),
                                            style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 13)),
                                        const Spacer(),
                                        GestureDetector(
                                          onTap: () =>
                                              Navigator.of(context).pop(),
                                          child: const Padding(
                                            padding: EdgeInsets.all(4),
                                            child: Icon(Icons.fullscreen_exit,
                                                color: Colors.white, size: 26),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// YouTube Full Screen Page  ← FIXED: landscape rotation added
// ══════════════════════════════════════════════════════════════════════════════
class YoutubeFullScreenPage extends StatefulWidget {
  final String youtubeId;
  final Color accent;

  const YoutubeFullScreenPage({
    super.key,
    required this.youtubeId,
    required this.accent,
  });

  @override
  State<YoutubeFullScreenPage> createState() => _YoutubeFullScreenPageState();
}

class _YoutubeFullScreenPageState extends State<YoutubeFullScreenPage> {
  late final YoutubePlayerController _controller;
  bool _showBack = true;
  Timer? _backTimer;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.youtubeId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: true,
        forceHD: true,
        useHybridComposition: true,
      ),
    );
    _enterFullscreen();
    _scheduleHideBack();
  }

  @override
  void dispose() {
    _backTimer?.cancel();
    _controller.dispose();
    _exitFullscreen();
    super.dispose();
  }

  Future<void> _enterFullscreen() async {
    // 1. Hide system UI first
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // 2. Then rotate — ORDER MATTERS on Android
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _exitFullscreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  void _scheduleHideBack() {
    _backTimer?.cancel();
    _backTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showBack) setState(() => _showBack = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // resizeToAvoidBottomInset keeps video from jumping when keyboard shows
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: () {
          setState(() => _showBack = !_showBack);
          if (_showBack) _scheduleHideBack();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // YouTube player — fills screen in landscape
            Center(
              child: YoutubePlayer(
                controller: _controller,
                showVideoProgressIndicator: true,
                progressIndicatorColor: const Color(0xFFFF0000),
                progressColors: const ProgressBarColors(
                  playedColor: Color(0xFFFF0000),
                  handleColor: Color(0xFFFF0000),
                  bufferedColor: Colors.white30,
                  backgroundColor: Colors.white12,
                ),
                bottomActions: [
                  const SizedBox(width: 10),
                  const CurrentPosition(),
                  const ProgressBar(isExpanded: true),
                  const RemainingDuration(),
                  const SizedBox(width: 8),
                ],
                topActions: const [],
              ),
            ),

            // Back button overlay
            Positioned(
              top: 0,
              left: 0,
              child: SafeArea(
                child: AnimatedOpacity(
                  opacity: _showBack ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !_showBack,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Material(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(50),
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(50),
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(Icons.arrow_back,
                                color: Colors.white, size: 24),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}