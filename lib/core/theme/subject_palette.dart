import 'package:flutter/material.dart';

/// Curated, high-contrast, accessible color palette for teacher subjects.
/// Ensures deterministic unique color assignment per teacher, eliminating duplicates.
class SubjectPalette {
  SubjectPalette._();

  /// 16 distinct, high-contrast, accessible base colors
  static const List<Color> colors = [
    Color(0xFF2563EB), // 0: Royal Blue
    Color(0xFF059669), // 1: Emerald Green
    Color(0xFF7C3AED), // 2: Violet
    Color(0xFFD97706), // 3: Amber Gold
    Color(0xFFE11D48), // 4: Crimson Rose
    Color(0xFF0891B2), // 5: Cyan
    Color(0xFF4F46E5), // 6: Indigo
    Color(0xFF0D9488), // 7: Teal
    Color(0xFFEA580C), // 8: Coral Tangerine
    Color(0xFFC026D3), // 9: Magenta Fuchsia
    Color(0xFF16A34A), // 10: Forest Lime
    Color(0xFF475569), // 11: Slate Blue
    Color(0xFF9333EA), // 12: Purple Plum
    Color(0xFF0284C7), // 13: Deep Ocean
    Color(0xFFBE123C), // 14: Terracotta Ruby
    Color(0xFF854D0E), // 15: Bronze Ochre
  ];

  /// Dark text shades guaranteeing WCAG AA (>= 4.5:1) against pastel light backgrounds
  static const List<Color> darkTextShades = [
    Color(0xFF1E3A8A), // Royal Blue dark
    Color(0xFF064E3B), // Emerald dark
    Color(0xFF4C1D95), // Violet dark
    Color(0xFF78350F), // Amber dark
    Color(0xFF881337), // Crimson dark
    Color(0xFF164E63), // Cyan dark
    Color(0xFF312E81), // Indigo dark
    Color(0xFF134E4A), // Teal dark
    Color(0xFF7C2D12), // Coral dark
    Color(0xFF701A75), // Magenta dark
    Color(0xFF14532D), // Lime dark
    Color(0xFF1E293B), // Slate dark
    Color(0xFF581C87), // Plum dark
    Color(0xFF0C4A6E), // Ocean dark
    Color(0xFF4C0519), // Ruby dark
    Color(0xFF451A03), // Bronze dark
  ];

  /// Light text shades guaranteeing WCAG AA (>= 4.5:1) against dark container backgrounds
  static const List<Color> lightTextShades = [
    Color(0xFF93C5FD), // Royal Blue light
    Color(0xFF6EE7B7), // Emerald light
    Color(0xFFC4B5FD), // Violet light
    Color(0xFFFDE68A), // Amber light
    Color(0xFFFDA4AF), // Crimson light
    Color(0xFF67E8F9), // Cyan light
    Color(0xFFA5B4FC), // Indigo light
    Color(0xFF5EEAD4), // Teal light
    Color(0xFFFDBA74), // Coral light
    Color(0xFFF0ABFC), // Magenta light
    Color(0xFF86EFAC), // Lime light
    Color(0xFFCBD5E1), // Slate light
    Color(0xFFD8B4FE), // Plum light
    Color(0xFF7DD3FC), // Ocean light
    Color(0xFFFECDD3), // Ruby light
    Color(0xFFFDE047), // Bronze light
  ];

  /// Resolves the color index for a subject.
  /// If [teacherSubjectNames] or [index] is supplied, guarantees zero duplicates
  /// for subjects taught by the same teacher.
  static int getIndexForSubject(
    String subjectName, {
    List<String>? teacherSubjectNames,
    int? index,
  }) {
    if (index != null && index >= 0) {
      return index % colors.length;
    }
    final normalized = subjectName.trim().toLowerCase();
    if (teacherSubjectNames != null && teacherSubjectNames.isNotEmpty) {
      final listIndex = teacherSubjectNames.indexWhere(
        (name) => name.trim().toLowerCase() == normalized,
      );
      if (listIndex != -1) {
        return listIndex % colors.length;
      }
    }
    // Fallback deterministic string hash
    return normalized.hashCode.abs() % colors.length;
  }

  /// Returns the primary accent color for a subject.
  static Color getColorForSubject(
    String subjectName, {
    List<String>? teacherSubjectNames,
    int? index,
  }) {
    final idx = getIndexForSubject(
      subjectName,
      teacherSubjectNames: teacherSubjectNames,
      index: index,
    );
    return colors[idx];
  }

  /// Returns a background tint for schedule tiles / badges.
  static Color getPastelBackground(
    Color baseColor, {
    required bool isDark,
  }) {
    if (isDark) {
      return Color.alphaBlend(
        baseColor.withValues(alpha: 0.18),
        const Color(0xFF1E293B),
      );
    }
    return Color.alphaBlend(
      baseColor.withValues(alpha: 0.14),
      Colors.white,
    );
  }

  /// Returns a high-contrast text color compliant with WCAG AA (>= 4.5:1).
  static Color getTextColor(
    Color baseColor, {
    required bool isDark,
  }) {
    final idx = colors.indexOf(baseColor);
    if (idx != -1) {
      return isDark ? lightTextShades[idx] : darkTextShades[idx];
    }
    return isDark ? Colors.white : const Color(0xFF0F172A);
  }
}
