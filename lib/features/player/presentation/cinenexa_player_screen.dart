import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../domain/playback_source.dart';

class CineNexaPlayerScreen extends StatefulWidget {
  final PlaybackSource source;

  const CineNexaPlayerScreen({
    super.key,
    required this.source,
  });

  @override
  State<CineNexaPlayerScreen> createState() => _CineNexaPlayerScreenState();
}

class _CineNexaPlayerScreenState extends State<CineNexaPlayerScreen> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;
  bool _controlsVisible = true;
  bool _disposed = false;
  Timer? _hideTimer;
  double _volume = 1;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  void _prepare() {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.source.url),
      httpHeaders: widget.source.headers,
    );
    _controller = controller;
    _initializeFuture = controller.initialize().then((_) async {
      await controller.setVolume(_volume);
      if (!_disposed) {
        setState(() {});
        await controller.play();
        _scheduleHide();
      }
    });
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!(_controller?.value.isPlaying ?? false)) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      await controller.pause();
      _hideTimer?.cancel();
      if (mounted) setState(() => _controlsVisible = true);
    } else {
      await controller.play();
      if (mounted) setState(() {});
      _scheduleHide();
    }
  }

  Future<void> _seekRelative(Duration delta) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final duration = controller.value.duration;
    var target = controller.value.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (target > duration) target = duration;
    await controller.seekTo(target);
    if (mounted) setState(() {});
    _scheduleHide();
  }

  String _format(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '${value.inMinutes}:$seconds';
  }

  @override
  void dispose() {
    _disposed = true;
    _hideTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: FutureBuilder<void>(
          future: _initializeFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _PlayerError(
                title: widget.source.title,
                onBack: () => Navigator.pop(context),
              );
            }
            if (snapshot.connectionState != ConnectionState.done ||
                controller == null ||
                !controller.value.isInitialized) {
              return const Center(child: CircularProgressIndicator());
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControls,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: AspectRatio(
                      aspectRatio: controller.value.aspectRatio == 0
                          ? 16 / 9
                          : controller.value.aspectRatio,
                      child: VideoPlayer(controller),
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: _controlsVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: IgnorePointer(
                      ignoring: !_controlsVisible,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xB0000000), Colors.transparent, Color(0xCC000000)],
                            stops: [0, .55, 1],
                          ),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 8, 18, 8),
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed: () => Navigator.pop(context),
                                    icon: const Icon(Icons.arrow_back_rounded),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.source.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                                        ),
                                        if (widget.source.subtitle.isNotEmpty)
                                          Text(
                                            widget.source.subtitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const Text(
                                    'CineNexa Player',
                                    style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton.filledTonal(
                                  tooltip: 'Back 10 seconds',
                                  onPressed: () => _seekRelative(const Duration(seconds: -10)),
                                  icon: const Icon(Icons.replay_10_rounded),
                                ),
                                const SizedBox(width: 18),
                                IconButton.filled(
                                  tooltip: controller.value.isPlaying ? 'Pause' : 'Play',
                                  iconSize: 42,
                                  onPressed: _togglePlayback,
                                  icon: Icon(controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                                ),
                                const SizedBox(width: 18),
                                IconButton.filledTonal(
                                  tooltip: 'Forward 10 seconds',
                                  onPressed: () => _seekRelative(const Duration(seconds: 10)),
                                  icon: const Icon(Icons.forward_10_rounded),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                              child: ValueListenableBuilder<VideoPlayerValue>(
                                valueListenable: controller,
                                builder: (_, value, __) {
                                  final durationMs = value.duration.inMilliseconds;
                                  final positionMs = value.position.inMilliseconds.clamp(0, durationMs == 0 ? 0 : durationMs);
                                  return Column(
                                    children: [
                                      Slider(
                                        value: durationMs == 0 ? 0 : positionMs.toDouble(),
                                        min: 0,
                                        max: durationMs == 0 ? 1 : durationMs.toDouble(),
                                        onChanged: durationMs == 0
                                            ? null
                                            : (v) => controller.seekTo(Duration(milliseconds: v.round())),
                                      ),
                                      Row(
                                        children: [
                                          Text('${_format(value.position)} / ${_format(value.duration)}'),
                                          const Spacer(),
                                          const Icon(Icons.volume_up_rounded, size: 20),
                                          SizedBox(
                                            width: 120,
                                            child: Slider(
                                              value: _volume,
                                              min: 0,
                                              max: 1,
                                              onChanged: (v) {
                                                setState(() => _volume = v);
                                                controller.setVolume(v);
                                                _scheduleHide();
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PlayerError extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _PlayerError({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 52, color: Colors.white54),
              const SizedBox(height: 16),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                'This video could not be played. Check the MP4/HLS URL and access permissions.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded), label: const Text('Back')),
            ],
          ),
        ),
      );
}
