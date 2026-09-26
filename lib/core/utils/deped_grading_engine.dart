/// DepEd Grading Engine for Senior High School (General Mathematics).
/// 
/// Official DepEd Weights for Senior High School Core Subjects:
/// - Written Works (WW): 20%
/// - Performance Tasks (PT): 50%
/// - Quarterly Examinations (EX): 30%
class DepEdGradingEngine {
  DepEdGradingEngine._();

  static const double writtenWorksWeight = 0.20;
  static const double performanceTasksWeight = 0.50;
  static const double examinationsWeight = 0.30;

  static const Map<String, List<String>> canonicalCategoryIds = {
    'Written Works': ['WW1', 'WW2', 'WW3'],
    'Performance Task': ['PT1'],
    'Examinations': ['EX1', 'EX2', 'EX3'],
  };

  static const Map<String, double> canonicalMaxPoints = {
    'WW1': 20.0,
    'WW2': 20.0,
    'WW3': 30.0,
    'PT1': 100.0,
    'EX1': 50.0,
    'EX2': 50.0,
    'EX3': 100.0,
  };

  static const Map<String, double> examinationSubWeights = {
    'EX1': 0.30, // ST1 (30%)
    'EX2': 0.30, // ST2 (30%)
    'EX3': 0.40, // Term Exam (40%)
  };

  /// Calculates the category percentage score (0 - 100) for a student given the score matrix.
  static double calculateCategoryAverage({
    required String studentId,
    required String category,
    required Map<String, Map<String, double>> assessmentScores,
    Map<String, List<String>>? categoryIds,
    Map<String, double>? maxPoints,
  }) {
    final ids = (categoryIds ?? canonicalCategoryIds)[category] ?? const <String>[];
    if (ids.isEmpty) return 0.0;

    final points = maxPoints ?? canonicalMaxPoints;

    if (category == 'Examinations') {
      return ids.fold<double>(
        0.0,
        (total, id) {
          final maxPts = points[id] ?? 100.0;
          final studentScore = assessmentScores[id]?[studentId] ?? 0.0;
          final weight = examinationSubWeights[id] ?? (1.0 / ids.length);
          return total + ((studentScore / maxPts) * weight);
        },
      ) * 100.0;
    }

    final scores = ids.map((id) {
      final maxPts = points[id] ?? 100.0;
      final studentScore = assessmentScores[id]?[studentId] ?? 0.0;
      return studentScore / maxPts;
    });

    return (scores.reduce((sum, val) => sum + val) / ids.length) * 100.0;
  }

  /// Calculates the overall quarterly initial grade (0 - 100) based on DepEd weights.
  static double calculateQuarterlyGrade({
    required String studentId,
    required Map<String, Map<String, double>> assessmentScores,
  }) {
    final ww = calculateCategoryAverage(
      studentId: studentId,
      category: 'Written Works',
      assessmentScores: assessmentScores,
    );
    final pt = calculateCategoryAverage(
      studentId: studentId,
      category: 'Performance Task',
      assessmentScores: assessmentScores,
    );
    final ex = calculateCategoryAverage(
      studentId: studentId,
      category: 'Examinations',
      assessmentScores: assessmentScores,
    );

    return (ww * writtenWorksWeight) + (pt * performanceTasksWeight) + (ex * examinationsWeight);
  }

  /// DepEd Transmutation Table helper (Maps initial grade to transmuted quarterly grade).
  static double transmute(double initialGrade) {
    if (initialGrade >= 100.0) return 100.0;
    if (initialGrade >= 98.40) return 99.0;
    if (initialGrade >= 96.80) return 98.0;
    if (initialGrade >= 95.20) return 97.0;
    if (initialGrade >= 93.60) return 96.0;
    if (initialGrade >= 92.00) return 95.0;
    if (initialGrade >= 90.40) return 94.0;
    if (initialGrade >= 88.80) return 93.0;
    if (initialGrade >= 87.20) return 92.0;
    if (initialGrade >= 85.60) return 91.0;
    if (initialGrade >= 84.00) return 90.0;
    if (initialGrade >= 82.40) return 89.0;
    if (initialGrade >= 80.80) return 88.0;
    if (initialGrade >= 79.20) return 87.0;
    if (initialGrade >= 77.60) return 86.0;
    if (initialGrade >= 76.00) return 85.0;
    if (initialGrade >= 74.40) return 84.0;
    if (initialGrade >= 72.80) return 83.0;
    if (initialGrade >= 71.20) return 82.0;
    if (initialGrade >= 69.60) return 81.0;
    if (initialGrade >= 68.00) return 80.0;
    if (initialGrade >= 66.40) return 79.0;
    if (initialGrade >= 64.80) return 78.0;
    if (initialGrade >= 63.20) return 77.0;
    if (initialGrade >= 61.60) return 76.0;
    if (initialGrade >= 60.00) return 75.0;
    if (initialGrade >= 56.00) return 74.0;
    if (initialGrade >= 52.00) return 73.0;
    if (initialGrade >= 48.00) return 72.0;
    if (initialGrade >= 44.00) return 71.0;
    if (initialGrade >= 40.00) return 70.0;
    return 60.0 + (initialGrade / 4.0); // Transmutation floor
  }
}
