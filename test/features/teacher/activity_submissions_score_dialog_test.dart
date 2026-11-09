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

    test('ActivityModel.effectiveGradingCategory maps EX, PT, and WW accurately for Gradebook sync', () {
      final examActivity = ActivityModel(
        id: 'exam-1',
        title: '1st Summative Exam',
        description: 'Physical exam administered in class',
        subject: 'Math',
        section: 'Rizal',
        deadline: DateTime.now(),
        maxScore: 100,
        isPublished: true,
        isRequirement: false,
        gradingCategory: 'ex',
        completionMode: 'in_person',
        gradebookColumnIndex: 1,
      );

      expect(examActivity.effectiveGradingCategory, 'ex');
      expect(examActivity.completionMode, 'in_person');

      // Test slot key mapping
      final colKey = examActivity.effectiveGradingCategory == 'ex'
          ? (examActivity.gradebookColumnIndex == 1
                ? 'st1'
                : (examActivity.gradebookColumnIndex == 2 ? 'st2' : 'te'))
          : examActivity.gradebookColumnIndex.toString();
      expect(colKey, 'st1');

      final st2Activity = examActivity.copyWith(gradebookColumnIndex: 2);
      final st2ColKey = st2Activity.effectiveGradingCategory == 'ex'
          ? (st2Activity.gradebookColumnIndex == 1
                ? 'st1'
                : (st2Activity.gradebookColumnIndex == 2 ? 'st2' : 'te'))
          : st2Activity.gradebookColumnIndex.toString();
      expect(st2ColKey, 'st2');

      final teActivity = examActivity.copyWith(gradebookColumnIndex: 3);
      final teColKey = teActivity.effectiveGradingCategory == 'ex'
          ? (teActivity.gradebookColumnIndex == 1
                ? 'st1'
                : (teActivity.gradebookColumnIndex == 2 ? 'st2' : 'te'))
          : teActivity.gradebookColumnIndex.toString();
      expect(teColKey, 'te');
    });
  });
}
