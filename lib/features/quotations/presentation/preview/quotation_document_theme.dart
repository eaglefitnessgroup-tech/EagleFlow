import 'package:flutter/material.dart';

class QuotationDocumentTheme {
  QuotationDocumentTheme._();

  // Colors (Neutral presentation-safe for PDF)
  static const Color navy = Color(0xFF0F172A); // Slate 900 (Deep Navy)
  static const Color gold = Color(0xFFD97706); // Amber 600 (Warm Gold)
  static const Color textMain = Color(0xFF334155); // Slate 700
  static const Color textMuted = Color(0xFF64748B); // Slate 500
  static const Color border = Color(0xFFF1F5F9); // Slate 100 (Very subtle)
  static const Color background = Colors.white;

  // Typography
  static const TextStyle h1 = TextStyle(
    fontFamily: 'IBM Plex Sans Condensed',
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: navy,
    letterSpacing: 1.5,
    height: 1.2,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: 'IBM Plex Sans Condensed',
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: navy,
    height: 1.3,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: 'IBM Plex Sans Condensed',
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: navy,
    letterSpacing: 0.5,
    height: 1.4,
  );

  static const TextStyle body = TextStyle(
    fontFamily: 'IBM Plex Sans Condensed',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textMain,
    height: 1.6,
  );

  static const TextStyle bodyBold = TextStyle(
    fontFamily: 'IBM Plex Sans Condensed',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: navy,
    height: 1.6,
  );

  static const TextStyle small = TextStyle(
    fontFamily: 'IBM Plex Sans Condensed',
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: textMuted,
    height: 1.5,
  );

  static const TextStyle smallBold = TextStyle(
    fontFamily: 'IBM Plex Sans Condensed',
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: navy,
    height: 1.5,
  );
}
