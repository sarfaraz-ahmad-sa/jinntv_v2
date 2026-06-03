import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Error type detection helper
// ─────────────────────────────────────────────────────────────────────────────
enum JinnErrorType { noInternet, serverError, empty, timeout }

JinnErrorType detectErrorType(Object? error) {
  if (error == null) return JinnErrorType.serverError;
  final msg = error.toString().toLowerCase();
  if (error is SocketException ||
      msg.contains('socketexception') ||
      msg.contains('no address') ||
      msg.contains('connection refused') ||
      msg.contains('network is unreachable')) {
    return JinnErrorType.noInternet;
  }
  if (error is TimeoutException ||
      msg.contains('timeout') ||
      msg.contains('timed out')) {
    return JinnErrorType.timeout;
  }
  return JinnErrorType.serverError;
}

// ─────────────────────────────────────────────────────────────────────────────
// Main widget
// ─────────────────────────────────────────────────────────────────────────────
class JinnErrorWidget extends StatefulWidget {
  final Object? error;
  final JinnErrorType? type; // override auto-detection
  final String? title;
  final String? subtitle;
  final String? retryLabel;
  final VoidCallback? onRetry;
  final bool showDetails; // show raw error message

  const JinnErrorWidget({
    super.key,
    this.error,
    this.type,
    this.title,
    this.subtitle,
    this.retryLabel,
    this.onRetry,
    this.showDetails = false,
  });

  // ── Convenience constructors ──────────────────────────────────────────────

  const JinnErrorWidget.noInternet({
    super.key,
    this.onRetry,
  })  : error       = null,
        type        = JinnErrorType.noInternet,
        title       = null,
        subtitle    = null,
        retryLabel  = null,
        showDetails = false;

  const JinnErrorWidget.server({
    super.key,
    this.error,
    this.onRetry,
  })  : type        = JinnErrorType.serverError,
        title       = null,
        subtitle    = null,
        retryLabel  = null,
        showDetails = false;

  const JinnErrorWidget.empty({
    super.key,
    this.title,
    this.subtitle,
    this.onRetry,
    this.retryLabel,
  })  : error       = null,
        type        = JinnErrorType.empty,
        showDetails = false;

  @override
  State<JinnErrorWidget> createState() => _JinnErrorWidgetState();
}

class _JinnErrorWidgetState extends State<JinnErrorWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _fadeAnim;
  late Animation<double>   _scaleAnim;
  bool _showRawError = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  JinnErrorType get _type =>
      widget.type ?? detectErrorType(widget.error);

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildIllustration(),
                const SizedBox(height: 28),
                Text(
                  _resolveTitle(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _resolveSubtitle(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.55),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                // Error details toggle
                if (widget.error != null &&
                    _type == JinnErrorType.serverError) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _showRawError = !_showRawError),
                    child: Text(
                      _showRawError ? 'Hide details' : 'Show details',
                      style: TextStyle(
                        color: Colors.white.withOpacity(.35),
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white30,
                      ),
                    ),
                  ),
                  if (_showRawError) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        widget.error.toString(),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
                if (widget.onRetry != null) ...[
                  const SizedBox(height: 28),
                  _buildRetryButton(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIllustration() {
    switch (_type) {
      case JinnErrorType.noInternet:
        return _IllustrationCircle(
          icon: Icons.wifi_off_rounded,
          bgColor: const Color(0xFF1A2D3E),
          iconColor: const Color(0xFF00A8E1),
          ringColor: const Color(0xFF0077A8),
          badge: Icons.close_rounded,
          badgeColor: Colors.redAccent,
        );
      case JinnErrorType.timeout:
        return _IllustrationCircle(
          icon: Icons.hourglass_empty_rounded,
          bgColor: const Color(0xFF2A1F1A),
          iconColor: Colors.orangeAccent,
          ringColor: Colors.orange.shade800,
          badge: Icons.timer_off_rounded,
          badgeColor: Colors.orangeAccent,
        );
      case JinnErrorType.empty:
        return _IllustrationCircle(
          icon: Icons.video_library_outlined,
          bgColor: const Color(0xFF1A2430),
          iconColor: Colors.white38,
          ringColor: Colors.white12,
        );
      case JinnErrorType.serverError:
        return _IllustrationCircle(
          icon: Icons.cloud_off_rounded,
          bgColor: const Color(0xFF271A2A),
          iconColor: Colors.purpleAccent.shade100,
          ringColor: Colors.purple.shade900,
          badge: Icons.warning_amber_rounded,
          badgeColor: Colors.amber,
        );
    }
  }

  Widget _buildRetryButton() {
    final isNoInternet = _type == JinnErrorType.noInternet;
    return GestureDetector(
      onTap: widget.onRetry,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 13),
        decoration: BoxDecoration(
          gradient: isNoInternet
              ? const LinearGradient(
                  colors: [Color(0xFF0077A8), Color(0xFF00A8E1)])
              : null,
          color: isNoInternet ? null : Colors.white.withOpacity(.08),
          borderRadius: BorderRadius.circular(30),
          border: isNoInternet
              ? null
              : Border.all(color: Colors.white.withOpacity(.15)),
          boxShadow: isNoInternet
              ? [BoxShadow(
                  color: const Color(0xFF00A8E1).withOpacity(.35),
                  blurRadius: 16, offset: const Offset(0, 5))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isNoInternet ? Icons.refresh_rounded : Icons.replay_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              widget.retryLabel ?? (isNoInternet ? 'Try Again' : 'Retry'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveTitle() {
    if (widget.title != null) return widget.title!;
    switch (_type) {
      case JinnErrorType.noInternet: return 'No Internet';
      case JinnErrorType.timeout:    return 'Connection Timed Out';
      case JinnErrorType.empty:      return 'Nothing Here Yet';
      case JinnErrorType.serverError:return 'Something Went Wrong';
    }
  }

  String _resolveSubtitle() {
    if (widget.subtitle != null) return widget.subtitle!;
    switch (_type) {
      case JinnErrorType.noInternet:
        return 'Check your Wi-Fi or mobile data and try again.';
      case JinnErrorType.timeout:
        return 'The server took too long to respond. Please try again.';
      case JinnErrorType.empty:
        return 'There is nothing to show here right now.';
      case JinnErrorType.serverError:
        return 'We could not load the content. Please try again.';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Illustration circle with optional badge
// ─────────────────────────────────────────────────────────────────────────────
class _IllustrationCircle extends StatelessWidget {
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final Color ringColor;
  final IconData? badge;
  final Color? badgeColor;

  const _IllustrationCircle({
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.ringColor,
    this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer ring
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ringColor.withOpacity(.4), width: 1.5),
          ),
        ),
        // Middle ring
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ringColor.withOpacity(.2), width: 1),
          ),
        ),
        // Main circle
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor,
            border: Border.all(color: ringColor.withOpacity(.3)),
          ),
          child: Icon(icon, color: iconColor, size: 38),
        ),
        // Badge
        if (badge != null)
          Positioned(
            right: 10,
            bottom: 10,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: badgeColor!.withOpacity(.15),
                border: Border.all(color: badgeColor!.withOpacity(.5)),
              ),
              child: Icon(badge, color: badgeColor, size: 14),
            ),
          ),
      ],
    );
  }
}
