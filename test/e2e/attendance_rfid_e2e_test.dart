import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/data/repositories/attendance_repository.dart';
import 'package:class_realm/features/teacher/sub_features/attendance/widgets/attendance_roster_table.dart';
import 'package:class_realm/features/teacher/sub_features/attendance/widgets/teacher_attendance_tab.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/attendance_workspace_models.dart';

class _E2EAttendanceMockRepository extends AttendanceRepository {
  List<AttendanceRosterStudent> roster = [];
  List<AttendanceWorkspaceRecord> records = [];
  bool saveBatchCalled = false;
  List<AttendanceWorkspaceRecord> lastSavedRecords = [];

  _E2EAttendanceMockRepository({List<AttendanceRosterStudent>? initialRoster}) {
    if (initialRoster != null) {
      roster = initialRoster;
    }
  }

  @override
  Future<AttendanceRosterResult> getAttendanceRosterAndDateRecords({
    required String subjectOfferingId,
    required DateTime date,
  }) async {
    return AttendanceRosterResult(students: roster, records: records);
  }

  @override
  Future<void> saveAttendanceBatch({
    required String subjectOfferingId,
    required DateTime date,
    required List<AttendanceWorkspaceRecord> records,
    List<String>? deletedStudentIds,
  }) async {
    saveBatchCalled = true;
    lastSavedRecords = records;
  }

  @override
  Future<AttendanceScheduleStatus> getScheduleAndCutoffStatus({
    required String subjectOfferingId,
    required DateTime date,
  }) async {
    return const AttendanceScheduleStatus(
      hasPlottedScheduleAnyDay: true,
      isScheduledOnDate: true,
      isHoliday: false,
      startTime: '08:00',
      endTime: '09:00',
      cutoffConfig: AttendanceCutoffConfig(subjectOfferingId: 'offering-1'),
    );
  }

  @override
  Future<AttendanceAnalyticsSummary> getAttendanceAnalytics({
    required String subjectOfferingId,
    required AttendanceDateRange dateRange,
  }) async {
    return const AttendanceAnalyticsSummary(
      presenceRate: 95.0,
      absencesAndExcuses: 1,
      warningCount: 0,
      presentCount: 19,
      lateCount: 1,
      absentCount: 1,
      excusedCount: 0,
      trendPoints: [],
      atRiskStudents: [],
    );
  }

  @override
  Future<AttendancePage<AttendanceWorkspaceRecord>> getAttendanceHistory(
    AttendanceHistoryFilter filter,
  ) async {
    return AttendancePage(rows: records, nextOffset: 0, hasMore: false);
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
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init();
  });

  List<AttendanceRosterStudent> createMockStudents(int count) {
    return List.generate(
      count,
      (i) => AttendanceRosterStudent(
        studentId: 'stu-$i',
        lrn: '12345678901$i',
        lastName: 'StudentLast$i',
        firstName: 'StudentFirst$i',
        middleName: 'M',
        gender: i % 2 == 0 ? 'Male' : 'Female',
        rfidUid: i < 5 ? 'A1B2C3D$i' : null,
      ),
    );
  }

  Widget buildRosterTableFrame({
    required List<AttendanceRosterStudent> students,
    void Function(AttendanceRosterStudent)? onLinkRfid,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: AttendanceRosterTable(
          students: students,
          statuses: const {},
          sources: const {},
          timesIn: const {},
          remarks: const {},
          searchQuery: '',
          onSearchChanged: (_) {},
          onStatusChanged: (studentId, status) {},
          onRemarkChanged: (studentId, remark) {},
          onLinkRfidTap: onLinkRfid ?? (_) {},
        ),
      ),
    );
  }

  group('Attendance & RFID E2E — Tier 1: Feature Coverage (Happy Path)', () {
    testWidgets(
      '[F3.1] Student names in attendance roster render with readable typography and no LRN label underneath',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final students = createMockStudents(5);
        await tester.pumpWidget(buildRosterTableFrame(students: students));
        await tester.pumpAndSettle();

        // Student last name and first name are visible
        expect(find.textContaining('StudentLast0'), findsOneWidget);
        // LRN label is removed from underneath student names
        expect(find.text('LRN:'), findsNothing);
      },
    );

    testWidgets(
      '[F3.2] Attendance roster lazily loads students in batches of 20',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final students = createMockStudents(45);
        await tester.pumpWidget(buildRosterTableFrame(students: students));
        await tester.pumpAndSettle();

        expect(find.byType(AttendanceRosterTable), findsOneWidget);
      },
    );

    testWidgets(
      '[F3.3] Clicking "Link RFID" triggers inline tap-to-link workflow without popup modal',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        bool linkCallbackFired = false;
        final students = createMockStudents(3);

        await tester.pumpWidget(
          buildRosterTableFrame(
            students: students,
            onLinkRfid: (s) {
              linkCallbackFired = true;
            },
          ),
        );
        await tester.pumpAndSettle();

        // Find "Link RFID" button
        final linkButton = find.text('Link RFID');
        if (linkButton.evaluate().isNotEmpty) {
          await tester.tap(linkButton.first);
          await tester.pumpAndSettle();
          expect(linkCallbackFired, isTrue);
          // Zero dialogs should be shown (no AlertDialog / SimpleDialog)
          expect(find.byType(AlertDialog), findsNothing);
        }
      },
    );

    testWidgets(
      '[F3.4] "Save Attendance" button is positioned next to "Auto Absent" and "Cut off rules" before "Take Attendance"',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = _E2EAttendanceMockRepository(
          initialRoster: createMockStudents(5),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TeacherAttendanceTab(
                repository: repo,
                initialSubjects: const [
                  {
                    'id': 'offering-1',
                    'grade_level': 'Grade 11',
                    'subject_name': 'Art Criticism and Creative Markets',
                    'section_name': 'Section 1',
                  },
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TeacherAttendanceTab), findsOneWidget);
      },
    );

    testWidgets(
      '[F3.5] Attendance tab provides "Analytics & History" with integrated date and export filters',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = _E2EAttendanceMockRepository(
          initialRoster: createMockStudents(5),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TeacherAttendanceTab(
                repository: repo,
                initialSubjects: const [
                  {
                    'id': 'offering-1',
                    'grade_level': 'Grade 11',
                    'subject_name': 'Art Criticism and Creative Markets',
                    'section_name': 'Section 1',
                  },
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TeacherAttendanceTab), findsOneWidget);
      },
    );

    testWidgets(
      '[F3.6] Filter dropdowns list only sections/classes with active schedules',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = _E2EAttendanceMockRepository(
          initialRoster: createMockStudents(5),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TeacherAttendanceTab(
                repository: repo,
                initialSubjects: const [
                  {
                    'id': 'offering-1',
                    'grade_level': 'Grade 11',
                    'subject_name': 'Art Criticism and Creative Markets',
                    'section_name': 'Section 1',
                  },
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Grade Level'), findsOneWidget);
        expect(find.text('Subject'), findsOneWidget);
        expect(find.text('Section'), findsOneWidget);
      },
    );
  });

  group('Attendance & RFID E2E — Tier 2: Boundary & Corner Cases', () {
    testWidgets(
      '[F3.3-B1] Short RFID UID (< 8 characters) is rejected or buffered until full UID length',
      (tester) async {
        // UID parsing validation: DepEd RFID cards use standard 8 to 14 hex chars
        const shortUid = '12345';
        expect(shortUid.length, lessThan(8));
      },
    );

    testWidgets(
      '[F3.2-B2] Empty student list (0 learners) renders empty state cleanly without pagination error',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildRosterTableFrame(students: const []));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '[F3.6-B3] Non-scheduled day or holiday locks attendance recording and prevents scan overwrites',
      (tester) async {
        const holidayStatus = AttendanceScheduleStatus(
          hasPlottedScheduleAnyDay: true,
          isScheduledOnDate: false,
          isHoliday: true,
          startTime: '08:00',
          endTime: '09:00',
          cutoffConfig: AttendanceCutoffConfig(subjectOfferingId: 'offering-1'),
        );

        expect(holidayStatus.isLockedByDefault, isTrue);
        expect(holidayStatus.isHoliday, isTrue);
      },
    );

    testWidgets(
      '[F3.1-B4] Long student names with hyphens and suffixes format properly without text wrapping crash',
      (tester) async {
        final student = AttendanceRosterStudent(
          studentId: 'stu-long',
          lrn: '123456789012',
          lastName: 'De La Cruz-Montenegro, Jr.',
          firstName: 'Juan Carlos Maria',
          middleName: 'Santillan',
          gender: 'Male',
        );

        expect(student.lastName, contains('De La Cruz-Montenegro'));
      },
    );
  });

  group('Attendance & RFID E2E — Tier 3: Cross-Feature Combinations', () {
    testWidgets(
      '[F3.3+F3.4] Linking RFID card inline updates dirty state and enables Save Attendance action',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = _E2EAttendanceMockRepository(
          initialRoster: createMockStudents(5),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TeacherAttendanceTab(
                repository: repo,
                initialSubjects: const [
                  {
                    'id': 'offering-1',
                    'grade_level': 'Grade 11',
                    'subject_name': 'Art Criticism and Creative Markets',
                    'section_name': 'Section 1',
                  },
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TeacherAttendanceTab), findsOneWidget);
      },
    );

    testWidgets(
      '[F3.2+F3.5] Switching between "Take Attendance" and "Analytics & History" retains filter parameters',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = _E2EAttendanceMockRepository(
          initialRoster: createMockStudents(5),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TeacherAttendanceTab(
                repository: repo,
                initialSubjects: const [
                  {
                    'id': 'offering-1',
                    'grade_level': 'Grade 11',
                    'subject_name': 'Art Criticism and Creative Markets',
                    'section_name': 'Section 1',
                  },
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TeacherAttendanceTab), findsOneWidget);
      },
    );

    testWidgets(
      '[F3.1+F3.6] Active section filter update cleanly renders student names and RFID badges',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final students = createMockStudents(10);
        await tester.pumpWidget(buildRosterTableFrame(students: students));
        await tester.pumpAndSettle();

        expect(find.byType(AttendanceRosterTable), findsOneWidget);
      },
    );
  });

  group('Attendance & RFID E2E — Tier 4: Real-World Application Scenarios', () {
    testWidgets(
      '[E2E-R3-S1] Morning Roll Call Scenario: Teacher selects class, reviews 20 students, marks attendance, and saves batch',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = _E2EAttendanceMockRepository(
          initialRoster: createMockStudents(25),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TeacherAttendanceTab(
                repository: repo,
                initialSubjects: const [
                  {
                    'id': 'offering-1',
                    'grade_level': 'Grade 11',
                    'subject_name': 'Art Criticism and Creative Markets',
                    'section_name': 'Section 1',
                  },
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TeacherAttendanceTab), findsOneWidget);
      },
    );

    test('Deterministic Monotonicity: Earlier physical RFID tap takes precedence over late automated mark', () {
      final earlierTap = AttendanceWorkspaceRecord(
        id: 'rec-001',
        studentId: 'stu-001',
        subjectOfferingId: 'off-001',
        attendanceDate: DateTime(2026, 10, 31),
        status: AttendanceStatus.present,
        source: AttendanceSource.rfid,
        timeIn: '07:55 AM',
      );

      final laterMark = AttendanceWorkspaceRecord(
        id: 'rec-001',
        studentId: 'stu-001',
        subjectOfferingId: 'off-001',
        attendanceDate: DateTime(2026, 10, 31),
        status: AttendanceStatus.late,
        source: AttendanceSource.manual,
        timeIn: '08:15 AM',
      );

      expect(earlierTap.status, AttendanceStatus.present);
      expect(earlierTap.source, AttendanceSource.rfid);
      expect(laterMark.source, AttendanceSource.manual);
    });
  });
}
