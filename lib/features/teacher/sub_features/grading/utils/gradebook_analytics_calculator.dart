import 'dart:ui';
import 'package:class_realm/core/utils/deped_grading_engine.dart';
import 'package:class_realm/models/user_model.dart';

enum GradeTrend {
  improving,
  declining,
  stable,
  insufficientData,
}

class AssessmentProgressionPoint {
  final String slotKey;
  final String label;
  final String subLabel;
  final String category;
  final double hps;
  final double classAveragePercent;
  final int encodedCount;
  final double? deltaFromPrevious;
  final Color color;

  const AssessmentProgressionPoint({
    required this.slotKey,
    required this.label,
    required this.subLabel,
    required this.category,
    required this.hps,
    required this.classAveragePercent,
    required this.encodedCount,
    this.deltaFromPrevious,
    required this.color,
  });
}

class TermProgressionPoint {
  final int termNumber;
  final String label;
  final String subLabel;
  final double? classAverageGrade;
  final double? passingRate;
  final int encodedCount;
  final Color color;

  const TermProgressionPoint({
    required this.termNumber,
    required this.label,
    required this.subLabel,
    this.classAverageGrade,
    this.passingRate,
    required this.encodedCount,
    required this.color,
  });
}

class DonutSliceData {
  final String label;
  final double pct;
  final double badgeVal;
  final String sub;
  final Color color;
  final String dotLabel;

  const DonutSliceData({
    required this.label,
    required this.pct,
    required this.badgeVal,
    required this.sub,
    required this.color,
    required this.dotLabel,
  });
}

class StudentGradeAnalyticsRow {
  final UserModel student;
  int rank;
  final String displayName;
  final String lrn;
  final double? wwPs;
  final double? wwWs;
  final double? ptPs;
  final double? ptWs;
  final double? exPs;
  final double? exWs;
  final double? initialGrade;
  final int? activeGrade;
  final Map<int, int?> termGrades;
  final int? finalGrade;
  final double? delta;
  final GradeTrend trend;
  final String descriptor;
  final String remarks;

  StudentGradeAnalyticsRow({
    required this.student,
    this.rank = 0,
    required this.displayName,
    required this.lrn,
    this.wwPs,
    this.wwWs,
    this.ptPs,
    this.ptWs,
    this.exPs,
    this.exWs,
    this.initialGrade,
    this.activeGrade,
    required this.termGrades,
    this.finalGrade,
    this.delta,
    required this.trend,
    required this.descriptor,
    required this.remarks,
  });
}

class GradebookAnalyticsSummary {
  final double? classAverage;
  final double? passingRate;
  final int passingCount;
  final int encodedCount;
  final int totalCount;
  final int improvingCount;
  final int needsAttentionCount;
  final int advancingCount;
  final int benchmarkingCount;
  final int connectingCount;
  final int developingCount;
  final double? wwPsAvg;
  final double? ptPsAvg;
  final double? exPsAvg;
  final List<AssessmentProgressionPoint> assessmentPoints;
  final List<TermProgressionPoint> termProgressionPoints;
  final List<DonutSliceData> componentDonutSlices;
  final List<DonutSliceData> distributionDonutSlices;
  final List<StudentGradeAnalyticsRow> studentRows;

  const GradebookAnalyticsSummary({
    this.classAverage,
    this.passingRate,
    this.passingCount = 0,
    this.encodedCount = 0,
    this.totalCount = 0,
    this.improvingCount = 0,
    this.needsAttentionCount = 0,
    this.advancingCount = 0,
    this.benchmarkingCount = 0,
    this.connectingCount = 0,
    this.developingCount = 0,
    this.wwPsAvg,
    this.ptPsAvg,
    this.exPsAvg,
    this.assessmentPoints = const [],
    this.termProgressionPoints = const [],
    this.componentDonutSlices = const [],
    this.distributionDonutSlices = const [],
    this.studentRows = const [],
  });
}

class GradebookAnalyticsCalculator {
  GradebookAnalyticsCalculator._();

  static const Color crSteelBlue = Color(0xFF3A6B88);
  static const Color crEmerald = Color(0xFF10B981);
  static const Color crAmber = Color(0xFFF59E0B);
  static const Color crRed = Color(0xFFEF4444);
  static const Color crSlate = Color(0xFF475569);

  /// Decodes column index from key string, int, or shorthand (st1, st2, te)
  static int? keyToColumnIndex(String category, dynamic rawKey, Map allValues) {
    final keyStr = rawKey.toString().toLowerCase().trim();
    if (category == 'ex') {
      if (keyStr == 'st1' || keyStr == 'ex1') return 0;
      if (keyStr == 'st2' || keyStr == 'ex2') return 1;
      if (keyStr == 'te' || keyStr == 'ex3') return 2;
      final parsed = int.tryParse(keyStr);
      if (parsed != null) {
        if (allValues.containsKey(0) || allValues.containsKey('0')) {
          if (parsed >= 0 && parsed < 3) return parsed;
        } else {
          if (parsed >= 1 && parsed <= 3) return parsed - 1;
          if (parsed == 0) return 0;
        }
      }
      return null;
    }
    final parsed = int.tryParse(keyStr);
    if (parsed != null) {
      if (allValues.containsKey(0) || allValues.containsKey('0')) {
        return parsed;
      } else {
        return parsed > 0 ? parsed - 1 : 0;
      }
    }
    return null;
  }

  /// Parses raw sheet map from Gradebook (either LocalStorage or Supabase) into clean `Map<category, Map<colIdx, double>>`
  static Map<String, dynamic> decodeSheet(Map<String, dynamic>? sheet) {
    if (sheet == null) return {'hps': <String, Map<int, double>>{}, 'scores': <String, Map<String, Map<int, double>>>{}};

    final rawHps = sheet['hps'] ?? sheet['hps_json'];
    final rawScores = sheet['scores'] ?? sheet['scores_json'];

    final decodedHps = <String, Map<int, double>>{
      'ww': {},
      'pt': {},
      'ex': {},
    };

    if (rawHps is Map) {
      for (final cat in const ['ww', 'pt', 'ex']) {
        final catMap = rawHps[cat];
        if (catMap is Map) {
          for (final entry in catMap.entries) {
            final colIdx = keyToColumnIndex(cat, entry.key, catMap);
            if (colIdx != null && entry.value != null && entry.value is num) {
              decodedHps[cat]![colIdx] = (entry.value as num).toDouble();
            }
          }
        }
      }
    }

    final decodedScores = <String, Map<String, Map<int, double>>>{};
    if (rawScores is Map) {
      for (final sEntry in rawScores.entries) {
        if (sEntry.value is! Map) continue;
        final studentId = sEntry.key.toString();
        decodedScores[studentId] = <String, Map<int, double>>{
          'ww': {},
          'pt': {},
          'ex': {},
        };
        for (final catEntry in (sEntry.value as Map).entries) {
          if (catEntry.value is! Map) continue;
          final cat = catEntry.key.toString().toLowerCase();
          if (!decodedScores[studentId]!.containsKey(cat)) continue;
          for (final scoreEntry in (catEntry.value as Map).entries) {
            final colIdx = keyToColumnIndex(cat, scoreEntry.key, catEntry.value as Map);
            if (colIdx != null && scoreEntry.value != null && scoreEntry.value is num) {
              decodedScores[studentId]![cat]![colIdx] = (scoreEntry.value as num).toDouble();
            }
          }
        }
      }
    }

    return {
      'hps': decodedHps,
      'scores': decodedScores,
    };
  }

  /// Core pure computation engine
  static GradebookAnalyticsSummary compute({
    required Map<String, dynamic> subjectOffering,
    required List<UserModel> students,
    required Map<int, Map<String, dynamic>?> termSheets,
    required int selectedTermView, // 1, 2, 3, or 0 (All Terms / Final)
    required List<int> activeTerms,
  }) {
    final wwWeight = (subjectOffering['ww_weight'] as num?)?.toDouble() ?? 20.0;
    final ptWeight = (subjectOffering['pt_weight'] as num?)?.toDouble() ?? 50.0;
    final exWeight = (subjectOffering['ex_weight'] as num?)?.toDouble() ?? 30.0;
    final st1Weight = (subjectOffering['st1_weight'] as num?)?.toDouble() ?? 30.0;
    final st2Weight = (subjectOffering['st2_weight'] as num?)?.toDouble() ?? 30.0;
    final teWeight = (subjectOffering['te_weight'] as num?)?.toDouble() ?? 40.0;
    final termsTaught = (subjectOffering['terms_taught'] as num?)?.toInt() ?? 3;
    final unitsPerTerm = (subjectOffering['units_per_term'] as num?)?.toDouble() ?? 2.0;

    // Decode all active term sheets
    final decodedSheets = <int, Map<String, dynamic>>{};
    for (final t in activeTerms) {
      decodedSheets[t] = decodeSheet(termSheets[t]);
    }

    // 1. Process each student row
    final studentRows = <StudentGradeAnalyticsRow>[];

    for (final student in students) {
      final sId = student.id;
      final termGrades = <int, int?>{};
      final termInitials = <int, double?>{};
      final termWwMetrics = <int, ComponentMetrics>{};
      final termPtMetrics = <int, ComponentMetrics>{};
      final termExMetrics = <int, ExamMetrics>{};

      for (final t in activeTerms) {
        final sheet = decodedSheets[t];
        final hpsMap = sheet?['hps'] as Map<String, Map<int, double>>? ?? {};
        final scoresMap = sheet?['scores'] as Map<String, Map<String, Map<int, double>>>? ?? {};

        final studentScores = scoresMap[sId] ?? {};

        // WW
        final wwHpsCols = (hpsMap['ww']?.keys.toList() ?? [])..sort();
        final wwHpsList = wwHpsCols.map((k) => hpsMap['ww']?[k]).toList();
        final wwScoreList = wwHpsCols.map((k) => studentScores['ww']?[k]).toList();
        final wwMetrics = DepEdGradingEngine.computeComponentMetrics(
          hps: wwHpsList,
          scores: wwScoreList,
          componentWeight: wwWeight,
        );
        termWwMetrics[t] = wwMetrics;

        // PT
        final ptHpsCols = (hpsMap['pt']?.keys.toList() ?? [])..sort();
        final ptHpsList = ptHpsCols.map((k) => hpsMap['pt']?[k]).toList();
        final ptScoreList = ptHpsCols.map((k) => studentScores['pt']?[k]).toList();
        final ptMetrics = DepEdGradingEngine.computeComponentMetrics(
          hps: ptHpsList,
          scores: ptScoreList,
          componentWeight: ptWeight,
        );
        termPtMetrics[t] = ptMetrics;

        // EX
        final exHpsList = List<double?>.generate(3, (i) => hpsMap['ex']?[i]);
        final exScoreList = List<double?>.generate(3, (i) => studentScores['ex']?[i]);
        final exMetrics = DepEdGradingEngine.computeExamMetrics(
          hps: exHpsList,
          scores: exScoreList,
          examWeight: exWeight,
          subWeights: [st1Weight, st2Weight, teWeight],
        );
        termExMetrics[t] = exMetrics;

        // Initial & Transmuted
        final initial = DepEdGradingEngine.computeInitialGrade(
          wwWs: wwMetrics.ws,
          ptWs: ptMetrics.ws,
          exWs: exMetrics.exWs,
          exWeight: exWeight,
        );
        termInitials[t] = initial;
        if (initial != null) {
          termGrades[t] = DepEdGradingEngine.transmuteDO15(initial);
        } else {
          termGrades[t] = null;
        }
      }

      // Compute Final Grade if all active terms have a grade
      int? finalGrade;
      final hasAllActiveTerms = activeTerms.every((t) => termGrades[t] != null);
      if (hasAllActiveTerms) {
        try {
          finalGrade = DepEdGradingEngine.computeFinalGrade(
            termsTaught: termsTaught,
            activeTerms: activeTerms,
            termGrades: termGrades,
            unitsPerTerm: unitsPerTerm,
          );
        } catch (_) {
          finalGrade = null;
        }
      }

      // Determine activeGrade based on selected view
      int? activeGrade;
      double? activeInitial;
      ComponentMetrics? activeWw;
      ComponentMetrics? activePt;
      ExamMetrics? activeEx;

      if (selectedTermView == 0) {
        // All Terms / Final View
        activeGrade = finalGrade ?? termGrades.values.whereType<int>().lastOrNull;
        activeInitial = termInitials.values.whereType<double>().lastOrNull;
        activeWw = termWwMetrics.values.lastOrNull;
        activePt = termPtMetrics.values.lastOrNull;
        activeEx = termExMetrics.values.lastOrNull;
      } else {
        activeGrade = termGrades[selectedTermView];
        activeInitial = termInitials[selectedTermView];
        activeWw = termWwMetrics[selectedTermView];
        activePt = termPtMetrics[selectedTermView];
        activeEx = termExMetrics[selectedTermView];
      }

      // Compute Trend Delta
      double? delta;
      GradeTrend trend = GradeTrend.insufficientData;

      if (selectedTermView == 0 && activeTerms.length > 1) {
        // Multi-term cross-term delta: latest encoded term grade - earliest encoded term grade
        final encodedActiveTerms = activeTerms.where((t) => termGrades[t] != null).toList();
        if (encodedActiveTerms.length >= 2) {
          final first = termGrades[encodedActiveTerms.first]!;
          final last = termGrades[encodedActiveTerms.last]!;
          final diff = (last - first).toDouble();
          delta = diff;
          if (diff >= 1.0) {
            trend = GradeTrend.improving;
          } else if (diff <= -1.0) {
            trend = GradeTrend.declining;
          } else {
            trend = GradeTrend.stable;
          }
        } else if (encodedActiveTerms.length == 1) {
          // Fallback to within-term delta of that single encoded term
          final t = encodedActiveTerms.first;
          delta = _computeWithinTermDelta(decodedSheets[t], sId);
          trend = _trendFromDelta(delta);
        }
      } else {
        // Within-term delta for single term view (or 1-term subject)
        final targetTerm = selectedTermView == 0 ? activeTerms.first : selectedTermView;
        delta = _computeWithinTermDelta(decodedSheets[targetTerm], sId);
        trend = _trendFromDelta(delta);
      }

      final descriptor = activeGrade != null
          ? DepEdGradingEngine.getDescriptor(activeGrade)
          : 'Pending';
      final remarks = activeGrade != null
          ? DepEdGradingEngine.getRemarks(activeGrade)
          : '—';

      studentRows.add(StudentGradeAnalyticsRow(
        student: student,
        displayName: formatLastnameFirst(student),
        lrn: student.lrn ?? '—',
        wwPs: activeWw?.ps,
        wwWs: activeWw?.ws,
        ptPs: activePt?.ps,
        ptWs: activePt?.ws,
        exPs: activeEx?.exPs,
        exWs: activeEx?.exWs,
        initialGrade: activeInitial,
        activeGrade: activeGrade,
        termGrades: termGrades,
        finalGrade: finalGrade,
        delta: delta,
        trend: trend,
        descriptor: descriptor,
        remarks: remarks,
      ));
    }

    // Rank students by activeGrade descending
    studentRows.sort((a, b) {
      final ga = a.activeGrade;
      final gb = b.activeGrade;
      if (ga == null && gb == null) return a.displayName.compareTo(b.displayName);
      if (ga == null) return 1;
      if (gb == null) return -1;
      final gradeCompare = gb.compareTo(ga);
      if (gradeCompare != 0) return gradeCompare;
      return a.displayName.compareTo(b.displayName);
    });

    for (var i = 0; i < studentRows.length; i++) {
      studentRows[i].rank = i + 1;
    }

    // 2. Summary KPI Metrics
    final encodedRows = studentRows.where((r) => r.activeGrade != null).toList();
    final encodedCount = encodedRows.length;
    final totalCount = students.length;

    double? classAverage;
    if (encodedCount > 0) {
      final sum = encodedRows.fold<int>(0, (acc, r) => acc + r.activeGrade!);
      classAverage = DepEdGradingEngine.round2(sum / encodedCount);
    }

    final passingCount = encodedRows.where((r) => r.activeGrade! >= 75).length;
    final passingRate = encodedCount > 0
        ? DepEdGradingEngine.round2((passingCount / encodedCount) * 100)
        : null;

    final improvingCount = studentRows.where((r) => r.trend == GradeTrend.improving).length;
    final needsAttentionCount = studentRows.where((r) =>
        (r.activeGrade != null && r.activeGrade! < 75) ||
        r.trend == GradeTrend.declining
    ).length;

    final advancingCount = studentRows.where((r) => r.activeGrade != null && r.activeGrade! >= 90).length;
    final benchmarkingCount = studentRows.where((r) => r.activeGrade != null && r.activeGrade! >= 80 && r.activeGrade! < 90).length;
    final connectingCount = studentRows.where((r) => r.activeGrade != null && r.activeGrade! >= 75 && r.activeGrade! < 80).length;
    final developingCount = studentRows.where((r) => r.activeGrade != null && r.activeGrade! < 75).length;

    // Component Mastery Averages
    final wwList = studentRows.map((r) => r.wwPs).whereType<double>().toList();
    final ptList = studentRows.map((r) => r.ptPs).whereType<double>().toList();
    final exList = studentRows.map((r) => r.exPs).whereType<double>().toList();

    final wwPsAvg = wwList.isNotEmpty
        ? DepEdGradingEngine.round2(wwList.reduce((a, b) => a + b) / wwList.length)
        : null;
    final ptPsAvg = ptList.isNotEmpty
        ? DepEdGradingEngine.round2(ptList.reduce((a, b) => a + b) / ptList.length)
        : null;
    final exPsAvg = exList.isNotEmpty
        ? DepEdGradingEngine.round2(exList.reduce((a, b) => a + b) / exList.length)
        : null;

    // 3. Term Progression Points (for vertical standing bar chart in Cross-Term view)
    final termPoints = <TermProgressionPoint>[];
    for (final t in activeTerms) {
      final gradesForTerm = studentRows.map((r) => r.termGrades[t]).whereType<int>().toList();
      double? avg;
      double? passRate;
      if (gradesForTerm.isNotEmpty) {
        avg = DepEdGradingEngine.round2(gradesForTerm.reduce((a, b) => a + b) / gradesForTerm.length);
        final pass = gradesForTerm.where((g) => g >= 75).length;
        passRate = DepEdGradingEngine.round2((pass / gradesForTerm.length) * 100);
      }
      termPoints.add(TermProgressionPoint(
        termNumber: t,
        label: 'Term $t',
        subLabel: 'Transmuted',
        classAverageGrade: avg,
        passingRate: passRate,
        encodedCount: gradesForTerm.length,
        color: crSteelBlue,
      ));
    }

    if (activeTerms.length > 1) {
      final finals = studentRows.map((r) => r.finalGrade).whereType<int>().toList();
      double? avg;
      if (finals.isNotEmpty) {
        avg = DepEdGradingEngine.round2(finals.reduce((a, b) => a + b) / finals.length);
      }
      termPoints.add(TermProgressionPoint(
        termNumber: 0,
        label: 'Final Grade',
        subLabel: 'Overall Avg',
        classAverageGrade: avg ?? classAverage,
        passingRate: passingRate,
        encodedCount: finals.length,
        color: crEmerald,
      ));
    }

    // 4. Assessment Points (for vertical standing bar chart in single-term view)
    final targetTerm = selectedTermView == 0 ? activeTerms.first : selectedTermView;
    final targetSheet = decodedSheets[targetTerm];
    final assessmentPoints = _buildAssessmentProgressionPoints(targetSheet, students);

    // 5. Donut Slices: Component Mastery vs Performance Distribution
    final compSlices = <DonutSliceData>[
      DonutSliceData(
        label: 'Performance Tasks (${ptWeight.toInt()}%)',
        pct: ptWeight,
        badgeVal: ptPsAvg ?? 0.0,
        sub: 'PT',
        color: crEmerald,
        dotLabel: 'Perf. Tasks',
      ),
      DonutSliceData(
        label: 'Written Works (${wwWeight.toInt()}%)',
        pct: wwWeight,
        badgeVal: wwPsAvg ?? 0.0,
        sub: 'WW',
        color: crSteelBlue,
        dotLabel: 'Written Works',
      ),
      DonutSliceData(
        label: 'Examinations (${exWeight.toInt()}%)',
        pct: exWeight,
        badgeVal: exPsAvg ?? 0.0,
        sub: 'EX',
        color: crAmber,
        dotLabel: 'Examinations',
      ),
    ];

    final distTotal = encodedCount > 0 ? encodedCount : totalCount;
    final pAdv = distTotal > 0 ? (advancingCount / distTotal) * 100 : 0.0;
    final pBench = distTotal > 0 ? (benchmarkingCount / distTotal) * 100 : 0.0;
    final pBelow80 = distTotal > 0 ? ((connectingCount + developingCount) / distTotal) * 100 : 0.0;

    final distSlices = <DonutSliceData>[
      DonutSliceData(
        label: 'Benchmarking ($benchmarkingCount)',
        pct: DepEdGradingEngine.round2(pBench),
        badgeVal: benchmarkingCount.toDouble(),
        sub: 'Good',
        color: crSteelBlue,
        dotLabel: 'Good (80-89)',
      ),
      DonutSliceData(
        label: 'Advancing ($advancingCount)',
        pct: DepEdGradingEngine.round2(pAdv),
        badgeVal: advancingCount.toDouble(),
        sub: 'Excellent',
        color: crEmerald,
        dotLabel: 'Excellent (90+)',
      ),
      DonutSliceData(
        label: 'Below 80 (${connectingCount + developingCount})',
        pct: DepEdGradingEngine.round2(pBelow80),
        badgeVal: (connectingCount + developingCount).toDouble(),
        sub: 'Needs Aid',
        color: crAmber,
        dotLabel: 'Needs Aid (<80)',
      ),
    ];

    return GradebookAnalyticsSummary(
      classAverage: classAverage,
      passingRate: passingRate,
      passingCount: passingCount,
      encodedCount: encodedCount,
      totalCount: totalCount,
      improvingCount: improvingCount,
      needsAttentionCount: needsAttentionCount,
      advancingCount: advancingCount,
      benchmarkingCount: benchmarkingCount,
      connectingCount: connectingCount,
      developingCount: developingCount,
      wwPsAvg: wwPsAvg,
      ptPsAvg: ptPsAvg,
      exPsAvg: exPsAvg,
      assessmentPoints: assessmentPoints,
      termProgressionPoints: termPoints,
      componentDonutSlices: compSlices,
      distributionDonutSlices: distSlices,
      studentRows: studentRows,
    );
  }

  static double? _computeWithinTermDelta(Map<String, dynamic>? decodedSheet, String studentId) {
    if (decodedSheet == null) return null;
    final hpsMap = decodedSheet['hps'] as Map<String, Map<int, double>>? ?? {};
    final scoresMap = decodedSheet['scores'] as Map<String, Map<String, Map<int, double>>>? ?? {};
    final studentScores = scoresMap[studentId];
    if (studentScores == null) return null;

    final scoredPercentages = <double>[];

    // Canonical order: WW1..10, PT1..10, ST1, ST2, TE
    for (final cat in const ['ww', 'pt', 'ex']) {
      final hpsCols = (hpsMap[cat]?.keys.toList() ?? [])..sort();
      for (final col in hpsCols) {
        final hps = hpsMap[cat]?[col];
        final score = studentScores[cat]?[col];
        if (hps != null && hps > 0 && score != null && score >= 0) {
          scoredPercentages.add((score / hps) * 100);
        }
      }
    }

    if (scoredPercentages.length < 2) return null;

    final mid = scoredPercentages.length ~/ 2;
    final early = scoredPercentages.sublist(0, mid);
    final late = scoredPercentages.sublist(mid);

    final earlyAvg = early.reduce((a, b) => a + b) / early.length;
    final lateAvg = late.reduce((a, b) => a + b) / late.length;

    return DepEdGradingEngine.round2(lateAvg - earlyAvg);
  }

  static GradeTrend _trendFromDelta(double? delta) {
    if (delta == null) return GradeTrend.insufficientData;
    if (delta >= 2.0) return GradeTrend.improving;
    if (delta <= -2.0) return GradeTrend.declining;
    return GradeTrend.stable;
  }

  static List<AssessmentProgressionPoint> _buildAssessmentProgressionPoints(
    Map<String, dynamic>? decodedSheet,
    List<UserModel> students,
  ) {
    if (decodedSheet == null) return const [];
    final hpsMap = decodedSheet['hps'] as Map<String, Map<int, double>>? ?? {};
    final scoresMap = decodedSheet['scores'] as Map<String, Map<String, Map<int, double>>>? ?? {};

    final points = <AssessmentProgressionPoint>[];
    double? lastAvg;

    for (final cat in const ['ww', 'pt', 'ex']) {
      final hpsCols = (hpsMap[cat]?.keys.toList() ?? [])..sort();
      for (final col in hpsCols) {
        final hps = hpsMap[cat]?[col];
        if (hps == null || hps <= 0) continue;

        var totalScore = 0.0;
        var encoded = 0;

        for (final s in students) {
          final score = scoresMap[s.id]?[cat]?[col];
          if (score != null && score >= 0) {
            totalScore += score;
            encoded++;
          }
        }

        if (encoded == 0) continue;

        final avgPct = DepEdGradingEngine.round2(((totalScore / encoded) / hps) * 100);
        final delta = lastAvg != null ? DepEdGradingEngine.round2(avgPct - lastAvg) : null;
        lastAvg = avgPct;

        String slotKey;
        String label;
        String sub;
        Color color;

        if (cat == 'ww') {
          slotKey = 'WW${col + 1}';
          label = 'WW ${col + 1}';
          sub = 'Task ${col + 1}';
          color = crSteelBlue;
        } else if (cat == 'pt') {
          slotKey = 'PT${col + 1}';
          label = 'PT ${col + 1}';
          sub = 'Project ${col + 1}';
          color = crEmerald;
        } else {
          final examLabels = ['ST 1', 'ST 2', 'TE'];
          final examSubs = ['Summative 1', 'Summative 2', 'Term Exam'];
          final idx = col.clamp(0, 2);
          slotKey = examLabels[idx].replaceAll(' ', '');
          label = examLabels[idx];
          sub = examSubs[idx];
          color = crAmber; // Consistently Amber for Examinations across Bar & Donut charts
        }

        points.add(AssessmentProgressionPoint(
          slotKey: slotKey,
          label: label,
          subLabel: sub,
          category: cat,
          hps: hps,
          classAveragePercent: avgPct,
          encodedCount: encoded,
          deltaFromPrevious: delta,
          color: color,
        ));
      }
    }

    return points;
  }

  /// Formats student name into standard DepEd school roster format:
  /// `Lastname, Firstname M.` (e.g. `Calica, Ljay H.`, `Mendoza, Alexander R.`)
  static String formatLastnameFirst(UserModel student) {
    if (student.lastName != null &&
        student.lastName!.trim().isNotEmpty &&
        student.firstName != null &&
        student.firstName!.trim().isNotEmpty) {
      final last = student.lastName!.trim();
      final first = student.firstName!.trim();
      final mi = (student.middleName != null && student.middleName!.trim().isNotEmpty)
          ? ' ${student.middleName!.trim().replaceAll('.', '')[0].toUpperCase()}.'
          : '';
      return '$last, $first$mi';
    }

    final raw = student.fullName.trim();
    if (raw.isEmpty) return '—';

    // If already has comma format (e.g. "Calica, Ljay H.")
    if (raw.contains(',')) {
      return raw;
    }

    // Split "First Middle Last" into "Last, First Middle"
    final tokens = raw.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.length >= 2) {
      final last = tokens.last;
      final rest = tokens.sublist(0, tokens.length - 1).join(' ');
      return '$last, $rest';
    }

    return raw;
  }
}
