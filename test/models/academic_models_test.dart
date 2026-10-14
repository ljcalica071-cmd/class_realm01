import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/models/academic_models.dart';

void main() {
  group('ActivityModel Supabase serialization and attachments', () {
    test('round trips basic activity fields with default values', () {
      final now = DateTime(2026, 10, 15, 23, 59);
      final activity = ActivityModel(
        id: 'act-1',
        title: 'Problem Set 1',
        description: 'Complete all rational equations',
        instructions: 'Show full solutions in notebook or PDF.',
        subject: 'General Mathematics',
        section: 'Section Einstein',
        gradeLevel: 'Grade 11',
        deadline: now,
        maxScore: 50.0,
        subjectOfferingId: 'offering-123',
      );

      expect(activity.id, 'act-1');
      expect(activity.title, 'Problem Set 1');
      expect(activity.instructions, 'Show full solutions in notebook or PDF.');
      expect(activity.maxScore, 50.0);
      expect(activity.subjectOfferingId, 'offering-123');
      expect(activity.isRequirement, isFalse);
      expect(activity.attachmentName, isNull);
      expect(activity.storagePath, isNull);
    });

    test('parses from Edge Function json with nested attachment object', () {
      final json = {
        'id': 'classwork-777',
        'subject_offering_id': 'offering-456',
        'classwork_type': 'performance_task',
        'grading_category': 'pt',
        'title': 'Solar System Diorama',
        'description': '',
        'instructions': 'Build a 3D model and submit rubric document.',
        'deadline': '2026-10-20T16:00:00.000Z',
        'assigned_at': '2026-10-12T08:00:00.000Z',
        'max_score': 100,
        'is_published': true,
        'attachment': {
          'id': 'att-101',
          'file_name': 'Rubric_Diorama.pdf',
          'storage_path': 'teacher_1/offering-456/rubric.pdf',
          'mime_type': 'application/pdf',
          'file_size_bytes': 1048576,
        },
        'subject_offerings': {
          'id': 'offering-456',
          'subjects': {'subject_name': 'Earth & Life Science'},
          'sections': {'section_name': 'Archimedes', 'grade_level': 'Grade 11'},
        },
      };

      final activity = ActivityModel.fromJson(json);

      expect(activity.id, 'classwork-777');
      expect(activity.subjectOfferingId, 'offering-456');
      expect(activity.title, 'Solar System Diorama');
      expect(activity.instructions, 'Build a 3D model and submit rubric document.');
      expect(activity.isRequirement, isTrue);
      expect(activity.maxScore, 100.0);
      expect(activity.subject, 'Earth & Life Science');
      expect(activity.section, 'Archimedes');
      expect(activity.gradeLevel, 'Grade 11');
      expect(activity.attachmentName, 'Rubric_Diorama.pdf');
      expect(activity.storagePath, 'teacher_1/offering-456/rubric.pdf');
      expect(activity.mimeType, 'application/pdf');
      expect(activity.fileSizeBytes, 1048576);
    });

    test('parses from Edge Function list json with classwork_attachments array', () {
      final json = {
        'id': 'classwork-888',
        'subject_offering_id': 'offering-123',
        'classwork_type': 'activity',
        'title': 'Worksheet 2',
        'instructions': 'Answer page 45-48',
        'deadline': '2026-10-22T23:59:00.000Z',
        'max_score': 30,
        'classwork_attachments': [
          {
            'id': 'att-202',
            'file_name': 'Worksheet2.docx',
            'storage_path': 'teacher_1/offering-123/worksheet2.docx',
            'mime_type':
                'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'file_size_bytes': 51200,
          }
        ],
      };

      final activity = ActivityModel.fromJson(json);

      expect(activity.id, 'classwork-888');
      expect(activity.isRequirement, isFalse);
      expect(activity.maxScore, 30.0);
      expect(activity.attachmentName, 'Worksheet2.docx');
      expect(activity.storagePath, 'teacher_1/offering-123/worksheet2.docx');
      expect(activity.fileSizeBytes, 51200);
    });

    test('copyWith updates subjectOfferingId and attachment details', () {
      final initial = ActivityModel(
        id: 'act-1',
        title: 'Title',
        description: 'Desc',
        subject: 'Math',
        section: 'Sec A',
        deadline: DateTime.now(),
        maxScore: 20,
      );

      final updated = initial.copyWith(
        subjectOfferingId: 'offering-99',
        attachmentName: 'guide.doc',
        storagePath: 'path/guide.doc',
        mimeType: 'application/msword',
        fileSizeBytes: 2048,
      );

      expect(updated.subjectOfferingId, 'offering-99');
      expect(updated.attachmentName, 'guide.doc');
      expect(updated.storagePath, 'path/guide.doc');
      expect(updated.mimeType, 'application/msword');
      expect(updated.fileSizeBytes, 2048);
    });
  });
}
