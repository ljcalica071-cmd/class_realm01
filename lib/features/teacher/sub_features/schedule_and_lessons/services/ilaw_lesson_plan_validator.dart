class DepEdCurriculumCatalog {
  static const Map<String, List<String>> _shsSubjects = {
    'Grade 11': [
      'General Mathematics',
      'Statistics and Probability',
      'Oral Communication in Context',
      'Reading and Writing Skills',
      'Komunikasyon at Pananaliksik sa Wika at Kulturang Pilipino',
      '21st Century Literature from the Philippines and the World',
      'Earth and Life Science',
      'Physical Science',
      'Personal Development',
      'Understanding Culture, Society and Politics',
      'Introduction to the Philosophy of the Human Person',
      'Physical Education and Health 1',
      'Empowerment Technologies',
    ],
    'Grade 12': [
      'Practical Research 1',
      'Practical Research 2',
      'English for Academic and Professional Purposes',
      'Inquiries, Investigations and Immersion',
      'Entrepreneurship',
      'Media and Information Literacy',
      'Contemporary Philippine Arts from the Regions',
      'Physical Education and Health 3',
      'Disaster Readiness and Risk Reduction',
      'Work Immersion / Culminating Activity',
    ],
  };

  static List<String> getStandardSubjects(String gradeLevel) {
    return _shsSubjects[gradeLevel] ?? _shsSubjects['Grade 11']!;
  }

  static List<String> getCompetenciesFor({
    required String gradeLevel,
    required String subject,
    String? term,
    String? quarter,
  }) {
    final effectiveTerm = term ?? quarter ?? 'Term 1';
    final cleanSubject = subject.trim().toLowerCase();

    if (cleanSubject.contains('general math') ||
        cleanSubject.contains('gen math')) {
      return const [
        'M11GM-Ia-1: Represents real-life situations using functions, including piece-wise functions.',
        'M11GM-Ia-3: Solves problems involving functions, domain, and range.',
        'M11GM-Ib-1: Distinguishes rational function, rational equation, and rational inequality.',
        'M11GM-Ib-2: Solves rational equations and inequalities using algebraic methods.',
        'M11GM-Ic-1: Represents real-life situations using one-to-one and inverse functions.',
        'M11GM-Ie-1: Represents real-life situations using exponential functions.',
        'M11GM-Ie-2: Distinguishes exponential function, equation, and inequality.',
        'M11GM-If-1: Represents real-life situations using logarithmic functions.',
      ];
    }

    if (cleanSubject.contains('stat') || cleanSubject.contains('prob')) {
      return const [
        'M11SP-IIIa-1: Illustrates a random variable (discrete and continuous).',
        'M11SP-IIIa-3: Illustrates a probability distribution for a discrete random variable.',
        'M11SP-IIIb-1: Computes the mean and variance of a discrete random variable.',
        'M11SP-IIIc-1: Illustrates a normal random variable and its characteristics.',
        'M11SP-IIIc-2: Identifies regions under the normal curve corresponding to different standard normal scores.',
        'M11SP-IIId-1: Converts a normal random variable to a standard normal variable and vice versa.',
        'M11SP-IIIe-1: Illustrates random sampling and parameter estimation.',
        'M11SP-IVa-1: Formulates null and alternative hypotheses on a population mean.',
      ];
    }

    if (cleanSubject.contains('oral com') || cleanSubject.contains('oral')) {
      return const [
        'EN11/12OC-Ia-2: Explains the nature, elements, and process of communication.',
        'EN11/12OC-Ia-3: Differentiates the various models of communication (linear, transactional, interactive).',
        'EN11/12OC-Ia-6: Identifies strategies to prevent communication breakdowns in intercultural settings.',
        'EN11/12OC-Id-11: Examines sample oral communication activities in academic and workplace contexts.',
        'EN11/12OC-If-14: Distinguishes various types of speeches according to purpose and delivery style.',
        'EN11/12OC-IIcj-24: Employs effective verbal and non-verbal speech delivery techniques.',
      ];
    }

    if (cleanSubject.contains('reading') || cleanSubject.contains('writing')) {
      return const [
        'EN11/12RWS-IIIbf-3: Distinguishes between and among patterns of development in written texts.',
        'EN11/12RWS-IIIgh-4: Evaluates a written text based on organization, coherence, cohesion, and language mechanics.',
        'EN11/12RWS-IVac-8: Explains critical reading as a form of reasoning.',
        'EN11/12RWS-IVac-9: Formulates evaluative statements about a text read, asserting claims and counterclaims.',
        'EN11/12RWS-IVdg-11: Composes a contextualized critique, position paper, or project proposal.',
      ];
    }

    if (cleanSubject.contains('science')) {
      return const [
        'S11/12PS-IIIa-1: Gives evidence for and explains the formation of the light elements in the Big Bang theory.',
        'S11/12PS-IIIc-15: Determines if a molecule is polar or non-polar given its structure and electronegativity.',
        'S11/12PS-IIId-e-18: Relates the physical properties of substances to the intermolecular forces present.',
        'S11/12PS-IIIh-27: Explains how the factors affecting chemical rates of reaction apply to food preservation and materials.',
      ];
    }

    if (cleanSubject.contains('research')) {
      return const [
        'CS_RS11-IIIa-1: Shares research experiences and knowledge in specific academic or technical tracks.',
        'CS_RS11-IIIa-4: Formulates clearly stated research questions, problem statements, and scope of study.',
        'CS_RS11-IIIc-e-1: Selects, synthesizes, and cites relevant related literature ethically.',
        'CS_RS11-IVa-c-1: Chooses appropriate research design, sampling methods, and data collection procedures.',
      ];
    }

    // Default fallback competencies for any other SHS subject
    return [
      'SHS-COMP-01: Analyzes fundamental concepts, principles, and frameworks in $subject.',
      'SHS-COMP-02: Applies inquiry-based critical reasoning to solve contextualized SHS challenges in $subject.',
      'SHS-COMP-03: Evaluates real-world situations and ethical implications within the domain of $subject.',
      'SHS-COMP-04: Creates collaborative, output-oriented artifacts demonstrating mastery of $subject ($effectiveTerm).',
    ];
  }
}

class IlawLessonPlanValidator {
  static const List<String> allowedGrades = ['Grade 11', 'Grade 12'];
  static const List<String> allowedTerms = [
    'Term 1',
    'Term 2',
    'Term 3',
  ];
  // Backward compatibility alias for legacy code:
  static List<String> get allowedQuarters => allowedTerms;

  static const int minSessions = 1;
  static const int maxSessions = 5;

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

  static String? validateTerm(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Please select a term.';
    }
    if (!allowedTerms.contains(trimmed) &&
        !['Quarter 1', 'Quarter 2', 'Quarter 3', 'Quarter 4'].contains(trimmed)) {
      return 'Term must be Term 1, Term 2, or Term 3.';
    }
    return null;
  }

  // Backward compatibility alias:
  static String? validateQuarter(String? value) => validateTerm(value);

  static String? validateNumberOfSessions(int? value) {
    if (value == null) {
      return 'Please select the number of sessions (1 to 5).';
    }
    if (value < minSessions || value > maxSessions) {
      return 'Number of sessions must be between $minSessions and $maxSessions sessions.';
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
