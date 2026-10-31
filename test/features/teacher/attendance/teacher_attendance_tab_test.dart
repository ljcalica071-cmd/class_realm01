import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/attendance_workspace_models.dart';
import 'package:class_realm/data/repositories/attendance_repository.dart';
import 'package:class_realm/features/teacher/sub_features/attendance/widgets/teacher_attendance_tab.dart';

class TabMockAttendanceRepository extends AttendanceRepository {
  List<AttendanceRosterStudent> rosterStudents = [];
  List<AttendanceWorkspaceRecord> dateRecords = [];
  bool saveBatchCalled = false;
  List<AttendanceWorkspaceRecord> savedBatchRecords = [];

  @override
  Future<AttendanceRosterResult> getAttendanceRosterAndDateRecords({
    required String subjectOfferingId,
    required DateTime date,
  }) async {
    return AttendanceRosterResult(
      students: rosterStudents,
      records: dateRecords,
    );
  }

  @override
  Future<void> saveAttendanceBatch({
    required String subjectOfferingId,
    required DateTime date,
    required List<AttendanceWorkspaceRecord> records, List<String>? deletedStudentIds,
  }) async {
    saveBatchCalled = true;
    savedBatchRecords = records;
  }

  @override
  Future<AttendanceAnalyticsSummary> getAttendanceAnalytics({
    required String subjectOfferingId,
    required AttendanceDateRange dateRange,
  }) async {
    return AttendanceAnalyticsSummary(
      presenceRate: 90.0,
      absencesAndExcuses: 2,
      warningCount: 0,
      presentCount: 9,
      lateCount: 1,
      absentCount: 1,
      excusedCount: 1,
      trendPoints: const [],
      atRiskStudents: const [],
    );
  }

  @override
  Future<AttendancePage<AttendanceWorkspaceRecord>> getAttendanceHistory(
    AttendanceHistoryFilter filter,
  ) async {
    return AttendancePage(rows: [], nextOffset: 0, hasMore: false);
  }

  @override
  Future<void> correctAttendanceRecord({
    required String subjectOfferingId,
    required String recordId,
    required AttendanceStatus newStatus,
    required String reason,
  }) async {}

  @override
  Future<AttendanceStudentSummary> getMyAttendanceSummary() async =>
      throw UnimplementedError();

  @override
  Future<AttendancePage<AttendanceRecord>> getMyAttendancePage({
    required int offset,
    int pageSize = 20,
  }) async => throw UnimplementedError();

  @override
  Future<List<AttendanceRecord>> getAllAttendanceRecords() async => [];

  @override
  Future<List<AttendanceRecord>> getAttendanceForStudent(
    String studentId,
  ) async => [];

  @override
  SyncStatus getSyncStatus() => SyncStatus.online;

  @override
  Future<void> recordAttendance({
    required String studentId,
    required AttendanceStatus status,
  }) async {}

  @override
  Future<void> toggleOfflineSync() async {}
}

void main() {
  group('TeacherAttendanceTab', () {
    late TabMockAttendanceRepository mockRepo;

    setUp(() {
      mockRepo = TabMockAttendanceRepository();
    });

    testWidgets('shows live RFID Ready scanner status badge', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TeacherAttendanceTab(
                repository: mockRepo,
                initialSubjects: const [
                  {
                    'id': 'sub-1',
                    'subject_name': 'General Mathematics',
                    'grade_level': 11,
                    'section_name': 'STEM-11A',
                  },
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('RFID Ready'), findsOneWidget);
    });

    testWidgets(
      'switches between Take Attendance and Analytics & History views',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: TeacherAttendanceTab(
                  repository: mockRepo,
                  initialSubjects: const [
                    {
                      'id': 'sub-1',
                      'subject_name': 'General Mathematics',
                      'grade_level': 11,
                      'section_name': 'STEM-11A',
                    },
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final historyBtn = find.text('Analytics & History');
        expect(historyBtn, findsOneWidget);
        await tester.tap(historyBtn);
        await tester.pumpAndSettle();

        // In History & Analytics view, Attendance Audit & History Logs is visible
        expect(find.text('Attendance Audit & History Logs'), findsOneWidget);

        final takeBtn = find.text('Take Attendance');
        expect(takeBtn, findsOneWidget);
        await tester.tap(takeBtn);
        await tester.pumpAndSettle();

        expect(find.text('RFID Ready'), findsOneWidget);
      },
    );

    testWidgets(
      'saves batch attendance without marking unselected students absent',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        mockRepo.rosterStudents = [
          AttendanceRosterStudent(
            studentId: 's1',
            firstName: 'Juan',
            lastName: 'Dela Cruz',
            gender: 'male',
          ),
          AttendanceRosterStudent(
            studentId: 's2',
            firstName: 'Maria',
            lastName: 'Santos',
            gender: 'female',
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: TeacherAttendanceTab(
                  repository: mockRepo,
                  initialSubjects: const [
                    {
                      'id': 'sub-1',
                      'subject_name': 'General Mathematics',
                      'grade_level': 11,
                      'section_name': 'STEM-11A',
                    },
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Mark s1 as Present
        final markPresent = find.byTooltip('Mark Present').first;
        await tester.ensureVisible(markPresent);
        await tester.tap(markPresent);
        await tester.pumpAndSettle();

        // Click Save Attendance button
        final saveBtn = find.textContaining('Save Attendance');
        expect(saveBtn, findsOneWidget);
        await tester.ensureVisible(saveBtn);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        expect(mockRepo.saveBatchCalled, isTrue);
        // Only s1 was marked, s2 should NOT be silently marked absent!
        expect(mockRepo.savedBatchRecords.length, 1);
        expect(mockRepo.savedBatchRecords.first.studentId, 's1');
        expect(
          mockRepo.savedBatchRecords.first.status,
          AttendanceStatus.present,
        );
      },
    );
  });
}
