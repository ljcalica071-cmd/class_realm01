import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/data/repositories/supabase_teacher_classwork_repository.dart';

void main() {
  group('SupabaseTeacherClassworkRepository Unit Tests', () {
    test('saveActivity rejects file size > 5 MiB before network invocation', () async {
      final repo = SupabaseTeacherClassworkRepository();

      final oversizedBytes = Uint8List(5 * 1024 * 1024 + 1); // 5 MiB + 1 byte
      final activity = ActivityModel(
        id: '',
        title: 'Activity 1',
        description: 'Desc',
        subject: 'Science',
        section: 'Sec 1',
        deadline: DateTime.now(),
        maxScore: 50,
      );

      expect(
        () => repo.saveActivity(
          activity: activity,
          subjectOfferingId: 'offering-1',
          fileBytes: oversizedBytes,
          fileName: 'oversized.pdf',
          mimeType: 'application/pdf',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('saveActivity rejects disallowed file extension before network invocation', () async {
      final repo = SupabaseTeacherClassworkRepository();

      final validBytes = Uint8List(1024);
      final activity = ActivityModel(
        id: '',
        title: 'Activity 1',
        description: 'Desc',
        subject: 'Science',
        section: 'Sec 1',
        deadline: DateTime.now(),
        maxScore: 50,
      );

      expect(
        () => repo.saveActivity(
          activity: activity,
          subjectOfferingId: 'offering-1',
          fileBytes: validBytes,
          fileName: 'executable.exe',
          mimeType: 'application/octet-stream',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
