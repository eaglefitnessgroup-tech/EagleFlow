import 'package:flutter/material.dart';

class QuotationDocumentTheme {
  QuotationDocumentTheme._();

  // Colors (Neutral presentation-safe for PDF)
  static const Color navy = Color(0xFF0F172A); // Slate 900 (Deep Navy)
  static const Color gold = Color(0xFFD97706); // Amber 600 (Warm Gold)
  static const Color textMain = Color(0xFF334155); // Slate 700
  static const Color textMuted = Color(0xFF64748B); // Slate 500
  static const Color border = Color(0xFFF1F5F9); // Slate 100 (Very subtle)
  static const Color dividerColor = Color(0xFFE2E8F0);
  static const double dividerThickness = 1;
  static const BorderSide dividerBorderSide = BorderSide(
    color: dividerColor,
    width: dividerThickness,
  );
  static const Color background = Colors.white;

  // Typography
  static const String fontFamily = 'IBM Plex Sans Condensed';

  static const TextStyle h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w500,
    color: navy,
    letterSpacing: -0.3,
    height: 1.2,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: navy,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: navy,
    letterSpacing: 0,
    height: 1.4,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textMain,
    letterSpacing: 0,
    height: 1.6,
  );

  static const TextStyle bodyBold = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: navy,
    letterSpacing: 0,
    height: 1.6,
  );

  static const TextStyle small = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: textMuted,
    letterSpacing: 0,
    height: 1.5,
  );

  static const TextStyle smallBold = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: navy,
    letterSpacing: 0,
    height: 1.5,
  );
}
