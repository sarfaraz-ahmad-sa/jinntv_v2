import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// JinnTV Theme — Prime Video × Netflix dark streaming palette
// ─────────────────────────────────────────────────────────────────────────────
class JinnTvTheme {
  // Backgrounds (dark navy like Prime Video)
  static const Color bg  = Color(0xFF0F171E); // primary — deepest navy
  static const Color bg2 = Color(0xFF1A242F); // secondary
  static const Color bg3 = Color(0xFF1F2D3A); // tertiary / cards

  // Accent — Prime Video teal
  static const Color teal      = Color(0xFF00A8E1); // primary teal
  static const Color tealDark  = Color(0xFF0077A8); // deeper teal
  static const Color tealLight = Color(0xFF5BC8F5); // highlight teal

  // Legacy aliases (so existing code still compiles)
  static const Color purple = tealDark;
  static const Color pink   = teal;
  static const Color blue   = tealDark;

  // Text / UI
  static const Color whiteSoft = Color(0xCCFFFFFF);
  static const Color card      = Color(0xFF1A2533);
  static const Color border    = Color(0x1AFFFFFF);

  // ── Gradients ──────────────────────────────────────────────────────────────

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bg, bg2, bg3],
  );

  // Primary CTA gradient — teal (Play button, selected chips, etc.)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [tealDark, teal],
  );

  // Accent gradient (admin badges, indicators)
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [tealDark, teal],
  );
}
