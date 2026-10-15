import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/models/student_dashboard_models.dart';

void main() {
  group('StudentClassworkModel Attachment & Instructions Parsing', () {
    test('parses instructions and attachment with signed URL', () {
      final json = {
        'id': 'cw-100',
        'classwork_type': 'activity',
        'title': 'Trigonometric Identities Worksheet',
        'description': '',
        'instructions': 'Answer odd-numbered items on clean bond paper.',
        'assigned_at': '2026-10-12T08:00:00.000Z',
        'deadline': '2026-10-19T23:59:00.000Z',
        'max_score': 50,
        'subject': {
          'subject_name': 'Pre-Calculus',
          'section_name': 'Section Gauss',
          'grade_level': '11',
        },
        'submission': {
          'status': 'graded',
          'score': 47,
          'feedback': 'Clear work and complete answers.',
        },
        'attachments': [
          {
            'id': 'att-1',
            'file_name': 'Trigo_Worksheet.pdf',
            'mime_type': 'application/pdf',
            'file_size_bytes': 2097152,
            'signed_url':
                'https://storage.mock.local/classwork/signed_url_token',
          },
        ],
      };

      final model = StudentClassworkModel.fromJson(json);

      expect(model.id, 'cw-100');
      expect(model.type, 'activity');
      expect(model.subjectName, 'Pre-Calculus');
      expect(model.sectionName, 'Section Gauss');
      expect(model.gradeLevel, '11');
      expect(model.title, 'Trigonometric Identities Worksheet');
      expect(
        model.instructions,
        'Answer odd-numbered items on clean bond paper.',
      );
      expect(model.status, 'graded');
      expect(model.score, 47);
      expect(model.feedback, 'Clear work and complete answers.');
      expect(model.attachment, isNotNull);
      expect(model.attachment!.fileName, 'Trigo_Worksheet.pdf');
      expect(model.attachment!.mimeType, 'application/pdf');
      expect(model.attachment!.fileSizeBytes, 2097152);
      expect(
        model.attachment!.signedUrl,
        'https://storage.mock.local/classwork/signed_url_token',
      );
    });

    test('handles absent attachment gracefully', () {
      final json = {
        'id': 'cw-101',
        'classwork_type': 'performance_task',
        'title': 'Oral Presentation',
        'instructions': 'Prepare a 5-minute presentation.',
        'max_score': 100,
        'subject': {
          'subject_name': 'Oral Communication',
          'section_name': 'Section Pascal',
          'grade_level': '11',
        },
      };

      final model = StudentClassworkModel.fromJson(json);

      expect(model.id, 'cw-101');
      expect(model.instructions, 'Prepare a 5-minute presentation.');
      expect(model.attachment, isNull);
    });

    test('parses flat classwork and submission fields', () {
      final json = {
        'id': 'cw-102',
        'type': 'assignment',
        'title': 'Research Summary',
        'subject_name': 'English',
        'section_name': 'Section Rizal',
        'grade_level': '12',
        'status': 'graded',
        'score': 18,
        'feedback': 'Well done.',
      };

      final model = StudentClassworkModel.fromJson(json);

      expect(model.type, 'assignment');
      expect(model.subjectName, 'English');
      expect(model.sectionName, 'Section Rizal');
      expect(model.gradeLevel, '12');
      expect(model.status, 'graded');
      expect(model.score, 18);
      expect(model.feedback, 'Well done.');
    });
  });
}
