import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Global theme notifier — persists across navigation
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier(ThemeMode.light); // Default: Light Mode

  // =============================================
  // 60-30-10 PALETTE (Based on 4th reference image)
  // =============================================

  // LIGHT MODE
  static const Color _lightBg = Color(0xFFF5F5F5);       // 60% — warm off-white
  static const Color _lightSurface = Color(0xFFE8EBE2);  // 30% — warm sage
  static const Color _lightCard = Color(0xFFFFFFFF);      // Card surface
  static const Color _lightAccent = Color(0xFF487898);    // 10% — steel blue
  static const Color _lightText = Color(0xFF111827);      // Primary text — max contrast

  // DARK MODE
  static const Color _darkBg = Color(0xFF111827);         // 60%
  static const Color _darkSurface = Color(0xFF1F2937);    // 30%
  static const Color _darkCard = Color(0xFF263040);       // Card surface
  static const Color _darkAccent = Color(0xFF60A5FA);     // 10%
  static const Color _darkText = Color(0xFFF9FAFB);       // Primary text

  // =============================================
  // CATEGORICAL / RAINBOW COLORS
  // Use these for section headers, badges, chips
  // =============================================
  static const Color catBlue   = Color(0xFF2563EB); // Written Works, Classwork, Info
  static const Color catGreen  = Color(0xFF16A34A); // Performance Task, Present, Success
  static const Color catPurple = Color(0xFF7C3AED); // Summative Tests, Quizzes
  static const Color catOrange = Color(0xFFD97706); // Quarterly Exam, Late, Warning
  static const Color catRed    = Color(0xFFDC2626); // Absent, Error, Danger
  static const Color catTeal   = Color(0xFF0D9488); // RFID, Attendance sync
  static const Color catPink   = Color(0xFFDB2777); // Parent features
  static const Color catSlate  = Color(0xFF475569); // Neutral, Excused, N/A

  // --- LIGHT THEME ---
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: _lightAccent,
      scaffoldBackgroundColor: _lightBg,
      textTheme: GoogleFonts.interTextTheme().apply(
        bodyColor: _lightText,
        displayColor: _lightText,
      ),
      colorScheme: const ColorScheme.light(
        primary: _lightAccent,
        secondary: _lightSurface,
        surface: _lightCard,
        onPrimary: Colors.white,
        onSurface: _lightText,
        onSecondary: _lightText,
      ),
      cardTheme: CardThemeData(
        color: _lightCard,
        elevation: 2, // Added subtle shadow for premium look
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE4E7EC), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _lightAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE4E7EC),
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _lightAccent, // Matched the web theme (steel blue)
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _lightAccent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }

  // --- DARK THEME ---
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: _darkAccent,
      scaffoldBackgroundColor: _darkBg,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: _darkText,
        displayColor: _darkText,
      ),
      colorScheme: const ColorScheme.dark(
        primary: _darkAccent,
        secondary: _darkSurface,
        surface: _darkCard,
        onPrimary: Colors.white,
        onSurface: _darkText,
      ),
      cardTheme: CardThemeData(
        color: _darkCard,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _darkAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.07),
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _darkCard,
        elevation: 0,
        iconTheme: const IconThemeData(color: _darkText),
        titleTextStyle: GoogleFonts.inter(
          color: _darkText,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _darkAccent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }
}
