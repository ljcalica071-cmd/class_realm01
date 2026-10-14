/// Exact DO 15, s. 2026 grade calculations for the SSHS electronic class record.
class DepEdGradingEngine {
  DepEdGradingEngine._();

  static const double writtenWorksWeight = 20;
  static const double performanceTasksWeight = 50;
  static const double examinationsWeight = 30;

  static const Map<String, List<String>> canonicalCategoryIds = {
    'Written Works': ['WW1', 'WW2', 'WW3'],
    'Performance Task': ['PT1'],
    'Examinations': ['EX1', 'EX2', 'EX3'],
  };

  static const Map<String, double> canonicalMaxPoints = {
    'WW1': 20,
    'WW2': 20,
    'WW3': 30,
    'PT1': 100,
    'EX1': 50,
    'EX2': 50,
    'EX3': 100,
  };

  static const List<double> defaultExamSubWeights = [30, 30, 40];

  static double round2(double value) => double.parse(value.toStringAsFixed(2));

  static ComponentMetrics computeComponentMetrics({
    required List<double?> hps,
    required List<double?> scores,
    required double componentWeight,
  }) {
    var totalRaw = 0.0;
    var totalHps = 0.0;
    var encodedCount = 0;

    for (var i = 0; i < hps.length && i < scores.length; i++) {
      final possible = hps[i];
      final score = scores[i];
      if (possible == null || possible <= 0) continue;
      totalHps += possible;
      if (score == null || score < 0 || score > possible) continue;
      totalRaw += score;
      encodedCount++;
    }

    if (encodedCount == 0 || totalHps <= 0) {
      return const ComponentMetrics(
        totalRaw: null,
        totalHps: 0,
        ps: null,
        ws: null,
      );
    }

    final ps = round2((totalRaw / totalHps) * 100);
    return ComponentMetrics(
      totalRaw: totalRaw,
      totalHps: totalHps,
      ps: ps,
      ws: round2(ps * (componentWeight / 100)),
    );
  }

  static ExamMetrics computeExamMetrics({
    required List<double?> hps,
    required List<double?> scores,
    required double examWeight,
    List<double> subWeights = defaultExamSubWeights,
  }) {
    if (hps.length < 3 || scores.length < 3 || subWeights.length != 3) {
      throw ArgumentError(
        'Exam HPS, score, and weight lists must have 3 entries.',
      );
    }

    final subWeightedScores = List<double?>.filled(3, null);
    var activeSubWeightSum = 0.0;
    for (var i = 0; i < 3; i++) {
      final possible = hps[i];
      final score = scores[i];
      final weight = subWeights[i];
      if (weight < 0) {
        throw ArgumentError.value(
          weight,
          'subWeights[$i]',
          'Must not be negative.',
        );
      }
      if (possible == null || possible <= 0) continue;
      activeSubWeightSum += weight;
      if (score == null || score < 0 || score > possible || weight == 0) {
        continue;
      }
      subWeightedScores[i] = round2((score / possible) * weight);
    }

    final hasEncodedExam = subWeightedScores.any((score) => score != null);
    if (!hasEncodedExam || activeSubWeightSum <= 0) {
      return const ExamMetrics(
        wsSt1: null,
        wsSt2: null,
        wsTe: null,
        exPs: null,
        exWs: null,
      );
    }

    final weightedTotal = subWeightedScores.fold<double>(
      0,
      (total, score) => total + (score ?? 0),
    );
    final exPs = round2((weightedTotal / activeSubWeightSum) * 100);
    return ExamMetrics(
      wsSt1: subWeightedScores[0],
      wsSt2: subWeightedScores[1],
      wsTe: subWeightedScores[2],
      exPs: exPs,
      exWs: round2(exPs * (examWeight / 100)),
    );
  }

  static double? computeInitialGrade({
    required double? wwWs,
    required double? ptWs,
    required double? exWs,
    required double exWeight,
  }) {
    if (wwWs == null || ptWs == null) return null;
    if (exWeight > 0 && exWs == null) return null;
    return round2(wwWs + ptWs + (exWeight > 0 ? exWs! : 0));
  }

  static int transmuteDO15(double initialGrade) {
    final grade = round2(initialGrade);
    if (grade >= 99.50) return 100;
    if (grade >= 98.32) return 99;
    if (grade >= 97.14) return 98;
    if (grade >= 95.96) return 97;
    if (grade >= 94.78) return 96;
    if (grade >= 93.60) return 95;
    if (grade >= 92.42) return 94;
    if (grade >= 91.24) return 93;
    if (grade >= 90.06) return 92;
    if (grade >= 88.88) return 91;
    if (grade >= 87.70) return 90;
    if (grade >= 86.52) return 89;
    if (grade >= 85.34) return 88;
    if (grade >= 84.16) return 87;
    if (grade >= 82.98) return 86;
    if (grade >= 81.80) return 85;
    if (grade >= 80.62) return 84;
    if (grade >= 79.44) return 83;
    if (grade >= 78.26) return 82;
    if (grade >= 77.08) return 81;
    if (grade >= 75.90) return 80;
    if (grade >= 74.72) return 79;
    if (grade >= 73.54) return 78;
    if (grade >= 72.36) return 77;
    if (grade >= 71.18) return 76;
    if (grade >= 70.00) return 75;
    if (grade >= 65.34) return 74;
    if (grade >= 60.67) return 73;
    if (grade >= 56.01) return 72;
    if (grade >= 51.34) return 71;
    if (grade >= 46.67) return 70;
    if (grade >= 42.01) return 69;
    if (grade >= 37.34) return 68;
    if (grade >= 32.68) return 67;
    if (grade >= 28.01) return 66;
    if (grade >= 23.35) return 65;
    if (grade >= 18.68) return 64;
    if (grade >= 14.01) return 63;
    if (grade >= 9.35) return 62;
    if (grade >= 4.68) return 61;
    return 60;
  }

  static String getDescriptor(int grade) {
    if (grade >= 90) return 'Advancing';
    if (grade >= 80) return 'Benchmarking';
    if (grade >= 75) return 'Connecting';
    if (grade >= 65) return 'Developing';
    return 'Emerging';
  }

  static String getRemarks(int grade) => grade >= 75 ? 'PASSED' : 'FAILED';

  static int? computeFinalGrade({
    required int termsTaught,
    required List<int> activeTerms,
    required Map<int, int?> termGrades,
    double unitsPerTerm = 2,
    double? totalUnitsEarned,
  }) {
    if (termsTaught < 1 ||
        termsTaught > 3 ||
        activeTerms.length != termsTaught) {
      throw ArgumentError(
        'Active terms must match a termsTaught value from 1 to 3.',
      );
    }
    if (activeTerms.toSet().length != activeTerms.length ||
        activeTerms.any((term) => term < 1 || term > 3)) {
      throw ArgumentError.value(
        activeTerms,
        'activeTerms',
        'Must be unique terms from 1 to 3.',
      );
    }

    var gradeTotal = 0;
    for (final term in activeTerms) {
      final grade = termGrades[term];
      if (grade == null) return null;
      gradeTotal += grade;
    }

    final divisor = totalUnitsEarned ?? (unitsPerTerm * termsTaught);
    if (divisor <= 0) {
      throw ArgumentError.value(
        divisor,
        'totalUnitsEarned',
        'Must be greater than zero.',
      );
    }
    return ((gradeTotal * unitsPerTerm) / divisor).round();
  }

  // Compatibility helpers retained for mock data consumers.
  static double calculateCategoryAverage({
    required String studentId,
    required String category,
    required Map<String, Map<String, double>> assessmentScores,
    Map<String, List<String>>? categoryIds,
    Map<String, double>? maxPoints,
  }) {
    final ids =
        (categoryIds ?? canonicalCategoryIds)[category] ?? const <String>[];
    final points = maxPoints ?? canonicalMaxPoints;
    final scores = ids
        .map<double?>((id) => assessmentScores[id]?[studentId])
        .toList();
    final hps = ids.map<double?>((id) => points[id] ?? 100).toList();

    if (category == 'Examinations') {
      final examScores = List<double?>.generate(
        3,
        (index) => index < scores.length ? scores[index] : null,
      );
      final examHps = List<double?>.generate(
        3,
        (index) => index < hps.length ? hps[index] : null,
      );
      return computeExamMetrics(
            hps: examHps,
            scores: examScores,
            examWeight: 100,
          ).exPs ??
          0;
    }

    return computeComponentMetrics(
          hps: hps,
          scores: scores,
          componentWeight: 100,
        ).ps ??
        0;
  }

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
    return round2(
      ww * (writtenWorksWeight / 100) +
          pt * (performanceTasksWeight / 100) +
          ex * (examinationsWeight / 100),
    );
  }

  static double transmute(double initialGrade) =>
      transmuteDO15(initialGrade).toDouble();
}

class ComponentMetrics {
  final double? totalRaw;
  final double totalHps;
  final double? ps;
  final double? ws;

  const ComponentMetrics({
    required this.totalRaw,
    required this.totalHps,
    required this.ps,
    required this.ws,
  });
}

class ExamMetrics {
  final double? wsSt1;
  final double? wsSt2;
  final double? wsTe;
  final double? exPs;
  final double? exWs;

  const ExamMetrics({
    required this.wsSt1,
    required this.wsSt2,
    required this.wsTe,
    required this.exPs,
    required this.exWs,
  });
}
