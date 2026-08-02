import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primaryBlue = Color(0xFF155EEF);
  static const Color primaryDark = Color(0xFF0B3FA6);
  static const Color primarySoft = Color(0xFFEAF1FF);

  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Color(0xFFFFFFFF);

  static const Color charcoal = Color(0xFF101828);
  static const Color mutedText = Color(0xFF667085);
  static const Color border = Color(0xFFE4E7EC);

  // Status Colors (added for Dashboard)
  static const Color statusPendingBg = Color(0xFFFEF0C7);
  static const Color statusPendingText = Color(0xFFDC6803);
  static const Color statusSentBg = primarySoft;
  static const Color statusSentText = primaryBlue;
  static const Color statusApprovedBg = Color(0xFFD1FADF);
  static const Color statusApprovedText = Color(0xFF027A48);
  static const Color statusRejectedBg = Color(0xFFFEE4E2);
  static const Color statusRejectedText = Color(0xFFD92D20);
  static const Color statusExpiredBg = Color(0xFFFEF0C7);
  static const Color statusExpiredText = Color(0xFFDC6803);
  static const Color statusDraftBg = Color(0xFFF2F4F7);
  static const Color statusDraftText = Color(0xFF344054);

  // Legacy mappings for locked screens
  static const Color primaryText = charcoal;
  static const Color secondaryText = mutedText;
  static const Color accent = primaryBlue;
  static const Color cardBackground = surface;
  static const Color divider = border;
}
