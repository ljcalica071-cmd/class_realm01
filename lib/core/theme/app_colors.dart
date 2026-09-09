import 'package:flutter/material.dart';

class AppColors {
  // Brand / Primary Colors (Academic Navy & Royal Slate)
  static const Color primary = Color(0xFF1E3A8A); // Deep Royal Blue
  static const Color primaryDark = Color(0xFF0F172A); // Dark Slate Blue
  static const Color primaryLight = Color(0xFF3B82F6); // Vibrant Blue
  static const Color accent = Color(0xFF0D9488); // Teal Accent
  static const Color accentLight = Color(0xFF14B8A6);

  // Background & Surfaces
  static const Color background = Color(0xFFF8FAFC); // Very light grey-blue
  static const Color surface = Colors.white;
  static const Color cardSurface = Colors.white;
  static const Color sidebarBg = Color(0xFF0F172A); // Midnight navy
  static const Color sidebarItemActive = Color(0xFF1E293B);

  // Status & Feedback Colors
  static const Color success = Color(0xFF10B981); // Emerald Green
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B); // Amber / Late / Pending
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444); // Rose Red / Absent
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF0284C7); // Sky Blue / Excused
  static const Color infoLight = Color(0xFFE0F2FE);

  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textLight = Colors.white;
  static const Color textLightMuted = Color(0xFF94A3B8);

  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);
  static const Color divider = Color(0xFFE2E8F0);

  // Sync / Offline status colors
  static const Color syncOnline = Color(0xFF10B981);
  static const Color syncOffline = Color(0xFF64748B);
  static const Color syncPending = Color(0xFFF59E0B);
  static const Color syncSyncing = Color(0xFF3B82F6);
  static const Color syncError = Color(0xFFEF4444);
}
