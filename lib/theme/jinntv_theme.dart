import 'package:flutter/material.dart';

class JinnTvTheme {
  static const Color bg = Color(0xff070B1A);
  static const Color bg2 = Color(0xff120E2A);
  static const Color bg3 = Color(0xff1A1033);

  static const Color purple = Color(0xff723579);
  static const Color pink = Color(0xffDA4775);
  static const Color blue = Color(0xff235B99);

  static const Color whiteSoft = Color(0xB3FFFFFF);
  static const Color card = Color(0x14FFFFFF);
  static const Color border = Color(0x1AFFFFFF);

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      bg,
      bg2,
      bg3,
    ],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      purple,
      pink,
    ],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      blue,
      purple,
    ],
  );
}