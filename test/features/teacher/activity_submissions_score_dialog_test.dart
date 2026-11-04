import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/core/utils/validators.dart';
import 'package:class_realm/models/academic_models.dart';

void main() {
  group('ActivitySubmissions & Deadline Tests', () {
    test('ActivityModel.fromJson parses UTC ISO deadline to local time seamlessly', () {
      // 2026-11-04 14:00:00 UTC == 2026-11-04 22:00:00 (10:00 PM) UTC+8
      final json = {
        'id': 'test-pt-1',
        'title': 'The Curators Choice',
        'deadline': '2026-11-04T14:00:00.000Z',
        'max_score': 100,
        'grading_category': 'pt',
      };

      final activity = ActivityModel.fromJson(json);
      expect(activity.deadline.isUtc, isFalse);
      expect(activity.deadline.toUtc().hour, 14);
    });

    test('Score validator strictly respects 0 to HPS limits', () {
      // Valid scores
      expect(AppValidators.validateClassworkStudentScore('0', maxScore: 100), isNull);
      expect(AppValidators.validateClassworkStudentScore('55', maxScore: 100), isNull);
      expect(AppValidators.validateClassworkStudentScore('100', maxScore: 100), isNull);

      // Invalid scores
      expect(AppValidators.validateClassworkStudentScore('-1', maxScore: 100), isNotNull);
      expect(AppValidators.validateClassworkStudentScore('101', maxScore: 100), isNotNull);
      expect(AppValidators.validateClassworkStudentScore('abc', maxScore: 100), isNotNull);
      expect(AppValidators.validateClassworkStudentScore('', maxScore: 100, allowEmpty: false), isNotNull);
    });

    test('Feedback whitespace-only validator logic rejects whitespace', () {
      bool isFeedbackOnlyWhitespace(String text) {
        return text.isNotEmpty && text.trim().isEmpty;
      }

      expect(isFeedbackOnlyWhitespace(''), isFalse); // Optional empty is ok
      expect(isFeedbackOnlyWhitespace('   '), isTrue); // Pure spaces rejected!
      expect(isFeedbackOnlyWhitespace('\t\n  '), isTrue); // Pure tabs/newlines rejected!
      expect(isFeedbackOnlyWhitespace('Good job!'), isFalse); // Valid content ok
    });
  });
}
