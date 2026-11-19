import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/features/teacher/sub_features/grading/utils/gradebook_analytics_calculator.dart';
import 'package:class_realm/models/user_model.dart';

void main() {
  group('GradebookAnalyticsCalculator', () {
    final student1 = UserModel(
      id: 'student_1',
      username: 'student1@classrealm.com',
      fullName: 'Aguilar, Fiona Q.',
      email: 'student1@classrealm.com',
      role: UserRole.student,
      lrn: '120000000116',
      departmentOrSection: 'Section 1',
    );

    final student2 = UserModel(
      id: 'student_2',
      username: 'student2@classrealm.com',
      fullName: 'Mendoza, Karl V.',
      email: 'student2@classrealm.com',
      role: UserRole.student,
      lrn: '120000000108',
      departmentOrSection: 'Section 1',
    );

    test('handles empty / unencoded sheets gracefully with zero mock numbers', () {
      final summary = GradebookAnalyticsCalculator.compute(
        subjectOffering: {
          'id': 'offering_1',
          'ww_weight': 30.0,
          'pt_weight': 50.0,
          'ex_weight': 20.0,
          'terms_taught': 3,
        },
        students: [student1, student2],
        termSheets: {1: null, 2: null, 3: null},
        selectedTermView: 1,
        activeTerms: [1, 2, 3],
      );

      expect(summary.classAverage, isNull);
      expect(summary.passingRate, isNull);
      expect(summary.encodedCount, 0);
      expect(summary.totalCount, 2);
      expect(summary.studentRows.length, 2);
      expect(summary.studentRows.first.activeGrade, isNull);
      expect(summary.studentRows.first.descriptor, 'Pending');
      expect(summary.studentRows.first.remarks, '—');
    });

    test('correctly computes DO 15 transmuted grades and progression in 3-Term subject', () {
      // Setup term sheet 1: Aguilar gets high scores, Mendoza gets lower scores
      final term1Sheet = {
        'hps': {
          'ww': {'0': 20.0, '1': 20.0},
          'pt': {'0': 100.0},
          'ex': {'0': 50.0, '1': 50.0, '2': 100.0},
        },
        'scores': {
          'student_1': {
            'ww': {'0': 19.0, '1': 20.0}, // 97.5% PS
            'pt': {'0': 95.0},             // 95% PS
            'ex': {'0': 45.0, '1': 48.0, '2': 90.0}, // (45/50*30 + 48/50*30 + 90/100*40) = 27 + 28.8 + 36 = 91.8%
          },
          'student_2': {
            'ww': {'0': 14.0, '1': 14.0}, // 70% PS
            'pt': {'0': 72.0},             // 72% PS
            'ex': {'0': 35.0, '1': 35.0, '2': 70.0}, // 70% PS
          },
        },
      };

      final summary = GradebookAnalyticsCalculator.compute(
        subjectOffering: {
          'id': 'offering_1',
          'ww_weight': 30.0,
          'pt_weight': 50.0,
          'ex_weight': 20.0,
          'st1_weight': 30.0,
          'st2_weight': 30.0,
          'te_weight': 40.0,
          'terms_taught': 3,
        },
        students: [student1, student2],
        termSheets: {1: term1Sheet, 2: null, 3: null},
        selectedTermView: 1,
        activeTerms: [1, 2, 3],
      );

      expect(summary.encodedCount, 2);
      expect(summary.totalCount, 2);
      expect(summary.studentRows.first.displayName, 'Aguilar, Fiona Q.');
      expect(summary.studentRows.first.activeGrade, greaterThanOrEqualTo(90));
      expect(summary.studentRows.first.descriptor, 'Advancing');
      expect(summary.studentRows.first.remarks, 'PASSED');

      // Mendoza should have lower grade
      final mendozaRow = summary.studentRows.firstWhere((r) => r.student.id == 'student_2');
      expect(mendozaRow.activeGrade, lessThan(80));
    });

    test('supports 1-Term subject correctly', () {
      // 1-Term subject: Work Immersion taught in Term 3 only
      final term3Sheet = {
        'hps': {
          'ww': {'0': 50.0},
          'pt': {'0': 100.0},
          'ex': {'0': 50.0, '1': 50.0, '2': 100.0},
        },
        'scores': {
          'student_1': {
            'ww': {'0': 48.0},
            'pt': {'0': 96.0},
            'ex': {'0': 45.0, '1': 48.0, '2': 95.0},
          },
        },
      };

      final summary = GradebookAnalyticsCalculator.compute(
        subjectOffering: {
          'id': 'immersion_1',
          'ww_weight': 20.0,
          'pt_weight': 60.0,
          'ex_weight': 20.0,
          'terms_taught': 1,
          'term_block': 'THIRD TERM',
        },
        students: [student1],
        termSheets: {3: term3Sheet},
        selectedTermView: 0, // All terms / Final View
        activeTerms: [3],
      );

      expect(summary.encodedCount, 1);
      expect(summary.studentRows.first.activeGrade, isNotNull);
      expect(summary.studentRows.first.finalGrade, summary.studentRows.first.activeGrade);
      expect(summary.termProgressionPoints.length, 1);
      expect(summary.termProgressionPoints.first.label, 'Term 3');
    });

    test(
      'compareRowsByPerformance sorts by activeGrade desc/asc with initialGrade tie-breaker and no-data at bottom',
      () {
        final noData = StudentGradeAnalyticsRow(
          student: student1,
          displayName: 'Zebra, Alex A.',
          lrn: '100000000001',
          termGrades: {},
          trend: GradeTrend.insufficientData,
          descriptor: 'Pending',
          remarks: '—',
        );
        final lowerTie = StudentGradeAnalyticsRow(
          student: student2,
          displayName: 'Alpha, Bea B.',
          lrn: '100000000002',
          initialGrade: 88.20,
          activeGrade: 92,
          termGrades: {1: 92},
          trend: GradeTrend.stable,
          descriptor: 'Advancing',
          remarks: 'PASSED',
        );
        final higherTie = StudentGradeAnalyticsRow(
          student: student1,
          displayName: 'Castro, Carl C.',
          lrn: '100000000003',
          initialGrade: 89.40,
          activeGrade: 92,
          termGrades: {1: 92},
          trend: GradeTrend.stable,
          descriptor: 'Advancing',
          remarks: 'PASSED',
        );
        final highestGrade = StudentGradeAnalyticsRow(
          student: student2,
          displayName: 'Santos, Dana D.',
          lrn: '100000000004',
          initialGrade: 95.10,
          activeGrade: 96,
          termGrades: {1: 96},
          trend: GradeTrend.improving,
          descriptor: 'Advancing',
          remarks: 'PASSED',
        );

        final descList = [noData, lowerTie, highestGrade, higherTie]
          ..sort(
            (a, b) => GradebookAnalyticsCalculator.compareRowsByPerformance(
              a,
              b,
              descending: true,
            ),
          );
        expect(
          descList.map((r) => r.displayName).toList(),
          ['Santos, Dana D.', 'Castro, Carl C.', 'Alpha, Bea B.', 'Zebra, Alex A.'],
        );

        final ascList = [noData, highestGrade, higherTie, lowerTie]
          ..sort(
            (a, b) => GradebookAnalyticsCalculator.compareRowsByPerformance(
              a,
              b,
              descending: false,
            ),
          );
        expect(
          ascList.map((r) => r.displayName).toList(),
          ['Alpha, Bea B.', 'Castro, Carl C.', 'Santos, Dana D.', 'Zebra, Alex A.'],
        );
      },
    );

    test(
      'compareRowsByPerformance falls back to partialWeightedScore desc/asc when activeGrade is null',
      () {
        final emptyRow = StudentGradeAnalyticsRow(
          student: student1,
          displayName: 'Abad, Amy A.',
          lrn: '100000000010',
          termGrades: {},
          trend: GradeTrend.insufficientData,
          descriptor: 'Pending',
          remarks: '—',
        );
        final midPartial = StudentGradeAnalyticsRow(
          student: student2,
          displayName: 'Bautista, Ben B.',
          lrn: '100000000011',
          wwWs: 18.0,
          ptWs: 48.0, // total 66.0
          termGrades: {},
          trend: GradeTrend.stable,
          descriptor: 'Pending',
          remarks: '—',
        );
        final topPartial = StudentGradeAnalyticsRow(
          student: student1,
          displayName: 'Cruz, Cara C.',
          lrn: '100000000012',
          wwWs: 19.5,
          ptWs: 55.0, // total 74.5
          termGrades: {},
          trend: GradeTrend.improving,
          descriptor: 'Pending',
          remarks: '—',
        );
        final lowPartial = StudentGradeAnalyticsRow(
          student: student2,
          displayName: 'Diaz, Dan D.',
          lrn: '100000000013',
          wwWs: 14.0,
          ptWs: 40.0, // total 54.0
          termGrades: {},
          trend: GradeTrend.declining,
          descriptor: 'Pending',
          remarks: '—',
        );

        final descList = [emptyRow, midPartial, lowPartial, topPartial]
          ..sort(
            (a, b) => GradebookAnalyticsCalculator.compareRowsByPerformance(
              a,
              b,
              descending: true,
            ),
          );
        expect(
          descList.map((r) => r.displayName).toList(),
          ['Cruz, Cara C.', 'Bautista, Ben B.', 'Diaz, Dan D.', 'Abad, Amy A.'],
        );

        final ascList = [emptyRow, topPartial, midPartial, lowPartial]
          ..sort(
            (a, b) => GradebookAnalyticsCalculator.compareRowsByPerformance(
              a,
              b,
              descending: false,
            ),
          );
        expect(
          ascList.map((r) => r.displayName).toList(),
          ['Diaz, Dan D.', 'Bautista, Ben B.', 'Cruz, Cara C.', 'Abad, Amy A.'],
        );
      },
    );
  });
}
