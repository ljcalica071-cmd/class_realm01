class IlawLessonPlanValidator {
  static const List<String> allowedGrades = ['Grade 11', 'Grade 12'];
  static const List<String> allowedQuarters = [
    'Quarter 1',
    'Quarter 2',
    'Quarter 3',
    'Quarter 4',
  ];

  static const int maxSubjectLength = 100;
  static const int maxTopicLength = 120;
  static const int maxCompetencyLength = 500;
  static const int maxStrategyLength = 100;
  static const int minDurationMinutes = 15;
  static const int maxDurationMinutes = 240;

  static const int minSectionLength = 20;
  static const int maxStandardSectionLength = 1500;
  static const int maxProcedureSectionLength = 3000;

  static final RegExp _hasAlphaNumeric = RegExp(r'[A-Za-z0-9]');
  static final RegExp _hasLetter = RegExp(r'[A-Za-z]');

  static String? validateGradeLevel(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Please select a Senior High School grade level.';
    }
    if (!allowedGrades.contains(trimmed)) {
      return 'Grade level must be Grade 11 or Grade 12 for SHS.';
    }
    return null;
  }

  static String? validateQuarter(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Please select a quarter.';
    }
    if (!allowedQuarters.contains(trimmed)) {
      return 'Quarter must be between Quarter 1 and Quarter 4.';
    }
    return null;
  }

  static String? validateSubject(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Subject name is required.';
    }
    if (trimmed.length < 3) {
      return 'Subject name must be at least 3 characters long.';
    }
    if (trimmed.length > maxSubjectLength) {
      return 'Subject name cannot exceed $maxSubjectLength characters.';
    }
    if (!_hasLetter.hasMatch(trimmed)) {
      return 'Subject name must contain valid letters.';
    }
    return null;
  }

  static String? validateTopic(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Lesson topic is required.';
    }
    if (trimmed.length < 3) {
      return 'Lesson topic must be at least 3 characters long.';
    }
    if (trimmed.length > maxTopicLength) {
      return 'Lesson topic cannot exceed $maxTopicLength characters.';
    }
    if (!_hasAlphaNumeric.hasMatch(trimmed)) {
      return 'Lesson topic must contain valid letters or numbers.';
    }
    return null;
  }

  static String? validateDuration(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Lesson duration in minutes is required.';
    }
    final minutes = int.tryParse(trimmed);
    if (minutes == null) {
      return 'Enter a whole number of minutes (e.g., 60).';
    }
    if (minutes < minDurationMinutes || minutes > maxDurationMinutes) {
      return 'Duration must be between $minDurationMinutes and $maxDurationMinutes minutes.';
    }
    return null;
  }

  static String? validateTeachingStrategy(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.length > maxStrategyLength) {
      return 'Teaching approach cannot exceed $maxStrategyLength characters.';
    }
    return null;
  }

  static String? validateCompetency(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.length > maxCompetencyLength) {
      return 'Learning competency cannot exceed $maxCompetencyLength characters.';
    }
    return null;
  }

  static String? validateSectionContent(
    String? value, {
    required String sectionName,
    int minLength = minSectionLength,
    int maxLength = maxStandardSectionLength,
  }) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '$sectionName is required before approving the iLAW plan.';
    }
    if (trimmed.length < minLength) {
      return '$sectionName must be at least $minLength characters long.';
    }
    if (trimmed.length > maxLength) {
      return '$sectionName cannot exceed $maxLength characters.';
    }
    return null;
  }

  /// Strips control characters and XML/prompt delimiter breakouts before sending
  /// teacher inputs to the Gemini API.
  static String sanitizePromptInput(String raw, {int maxLength = 500}) {
    var cleaned = raw
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), ' ')
        .replaceAll(RegExp(r'</?\s*lesson_input\s*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
    if (cleaned.length > maxLength) {
      cleaned = cleaned.substring(0, maxLength).trim();
    }
    return cleaned;
  }

  /// Builds a safe, filesystem-friendly base filename (without extension)
  /// preventing path traversal (`..`, `/`, `\`) and illegal OS filename chars.
  static String sanitizeExportFileName(String subject, String topic) {
    String cleanSegment(String input, int maxLen) {
      final slug = input
          .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      if (slug.isEmpty) return 'Lesson';
      return slug.length > maxLen ? slug.substring(0, maxLen) : slug;
    }

    final safeSub = cleanSegment(subject, 28);
    final safeTop = cleanSegment(topic, 36);
    return 'iLAW_${safeSub}_$safeTop';
  }
}
