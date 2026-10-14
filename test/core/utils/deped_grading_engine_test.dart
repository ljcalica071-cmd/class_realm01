import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/core/utils/deped_grading_engine.dart';

void main() {
  group('DepEdGradingEngine', () {
    test('rounds component metrics and excludes scores without valid HPS', () {
      final metrics = DepEdGradingEngine.computeComponentMetrics(
        hps: [10, 0, null, 10],
        scores: [10, 8, 9, null],
        componentWeight: 20,
      );

      expect(metrics.totalRaw, 10);
      expect(metrics.totalHps, 20);
      expect(metrics.ps, 50);
      expect(metrics.ws, 10);
    });

    test('returns null component metrics when no valid scores are encoded', () {
      final metrics = DepEdGradingEngine.computeComponentMetrics(
        hps: [10, null],
        scores: [null, 4],
        componentWeight: 20,
      );

      expect(metrics.totalRaw, isNull);
      expect(metrics.ps, isNull);
      expect(metrics.ws, isNull);
    });

    test('matches the official examination and term-grade benchmark', () {
      final ww = DepEdGradingEngine.computeComponentMetrics(
        hps: [10],
        scores: [10],
        componentWeight: 20,
      );
      final pt = DepEdGradingEngine.computeComponentMetrics(
        hps: [10],
        scores: [10],
        componentWeight: 50,
      );
      final exam = DepEdGradingEngine.computeExamMetrics(
        hps: [3, 1, 1],
        scores: [2, 1, 1],
        examWeight: 30,
      );
      final initialGrade = DepEdGradingEngine.computeInitialGrade(
        wwWs: ww.ws,
        ptWs: pt.ws,
        exWs: exam.exWs,
        exWeight: 30,
      );

      expect(exam.wsSt1, 20);
      expect(exam.wsSt2, 30);
      expect(exam.wsTe, 40);
      expect(exam.exPs, 90);
      expect(exam.exWs, 27);
      expect(initialGrade, 97);
      expect(DepEdGradingEngine.transmuteDO15(initialGrade!), 97);
      expect(DepEdGradingEngine.getDescriptor(97), 'Advancing');
      expect(DepEdGradingEngine.getRemarks(97), 'PASSED');
    });

    test('uses the configured active exam subweights', () {
      final exam = DepEdGradingEngine.computeExamMetrics(
        hps: [null, null, 2],
        scores: [null, null, 1],
        examWeight: 15,
        subWeights: [0, 0, 100],
      );

      expect(exam.wsSt1, isNull);
      expect(exam.wsSt2, isNull);
      expect(exam.wsTe, 50);
      expect(exam.exPs, 50);
      expect(exam.exWs, 7.5);
    });

    test(
      'requires all weighted components before returning an initial grade',
      () {
        expect(
          DepEdGradingEngine.computeInitialGrade(
            wwWs: 20,
            ptWs: null,
            exWs: 27,
            exWeight: 30,
          ),
          isNull,
        );
        expect(
          DepEdGradingEngine.computeInitialGrade(
            wwWs: 20,
            ptWs: 50,
            exWs: null,
            exWeight: 30,
          ),
          isNull,
        );
        expect(
          DepEdGradingEngine.computeInitialGrade(
            wwWs: 40,
            ptWs: 60,
            exWs: null,
            exWeight: 0,
          ),
          100,
        );
      },
    );

    test('maps DO 15 transmutation thresholds and passing line', () {
      expect(DepEdGradingEngine.transmuteDO15(99.50), 100);
      expect(DepEdGradingEngine.transmuteDO15(99.49), 99);
      expect(DepEdGradingEngine.transmuteDO15(95.96), 97);
      expect(DepEdGradingEngine.transmuteDO15(94.00), 95);
      expect(DepEdGradingEngine.transmuteDO15(70.00), 75);
      expect(DepEdGradingEngine.transmuteDO15(69.99), 74);
      expect(DepEdGradingEngine.transmuteDO15(0), 60);
    });

    test('averages only active terms and waits until all are graded', () {
      expect(
        DepEdGradingEngine.computeFinalGrade(
          termsTaught: 1,
          activeTerms: [2],
          termGrades: {1: null, 2: 94, 3: null},
          unitsPerTerm: 3,
          totalUnitsEarned: 3,
        ),
        94,
      );
      expect(
        DepEdGradingEngine.computeFinalGrade(
          termsTaught: 3,
          activeTerms: [1, 2, 3],
          termGrades: {1: 90, 2: 93, 3: null},
        ),
        isNull,
      );
      expect(
        DepEdGradingEngine.computeFinalGrade(
          termsTaught: 3,
          activeTerms: [1, 2, 3],
          termGrades: {1: 90, 2: 93, 3: 97},
        ),
        93,
      );
    });
  });
}
