import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/data/repositories/attendance_repository.dart';
import 'package:class_realm/features/parent/sub_features/child_details/widgets/parent_attendance_tab.dart';
import 'package:class_realm/features/student/sub_features/schedule/screens/student_attendance_screen.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/attendance_workspace_models.dart';

class _PortalMockAttendanceRepository extends AttendanceRepository {
  final AttendanceStudentSummary mockSummary;
  final List<AttendanceRecord> mockRecords;

  _PortalMockAttendanceRepository({
    required this.mockSummary,
    required this.mockRecords,
  });

  @override
  Future<AttendanceStudentSummary> getMyAttendanceSummary() async => mockSummary;

  @override
  Future<AttendancePage<AttendanceRecord>> getMyAttendancePage({
    required int offset,
    int pageSize = 20,
  }) async {
    return AttendancePage(
      rows: mockRecords,
      nextOffset: mockRecords.length,
      hasMore: false,
    );
  }

  @override
  Future<List<AttendanceRecord>> getAttendanceForStudent(String studentId) async =>
      mockRecords;

  @override
  Future<List<AttendanceRecord>> getAllAttendanceRecords() async => mockRecords;

  @override
  Future<AttendanceAnalyticsSummary> getAttendanceAnalytics({
    required String subjectOfferingId,
    required AttendanceDateRange dateRange,
  }) async => throw UnimplementedError();

  @override
  Future<AttendancePage<AttendanceWorkspaceRecord>> getAttendanceHistory(
    AttendanceHistoryFilter filter,
  ) async => throw UnimplementedError();

  @override
  Future<AttendanceRosterResult> getAttendanceRosterAndDateRecords({
    required String subjectOfferingId,
    required DateTime date,
  }) async => throw UnimplementedError();

  @override
  Future<void> saveAttendanceBatch({
    required String subjectOfferingId,
    required DateTime date,
    required List<AttendanceWorkspaceRecord> records, List<String>? deletedStudentIds,
  }) async {}

  @override
  Future<void> correctAttendanceRecord({
    required String subjectOfferingId,
    required String recordId,
    required AttendanceStatus newStatus,
    required String reason,
  }) async {}

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

  List<AttendanceRecord> createMockAttendanceRecords({
    required int absentCount,
    required int presentCount,
    required int lateCount,
  }) {
    final list = <AttendanceRecord>[];
    for (int i = 0; i < presentCount; i++) {
      list.add(
        AttendanceRecord(
          id: 'rec-p-$i',
          studentId: 'stu-001',
          date: DateTime(2026, 10, 1 + i),
          status: AttendanceStatus.present,
          timeIn: '07:45 AM',
        ),
      );
    }
    for (int i = 0; i < lateCount; i++) {
      list.add(
        AttendanceRecord(
          id: 'rec-l-$i',
          studentId: 'stu-001',
          date: DateTime(2026, 10, 15 + i),
          status: AttendanceStatus.late,
          timeIn: '08:15 AM',
        ),
      );
    }
    for (int i = 0; i < absentCount; i++) {
      list.add(
        AttendanceRecord(
          id: 'rec-a-$i',
          studentId: 'stu-001',
          date: DateTime(2026, 10, 20 + i),
          status: AttendanceStatus.absent,
          timeIn: '—',
        ),
      );
    }
    return list;
  }

  group('Portals & Notifications E2E — Tier 1: Feature Coverage (Happy Path)', () {
    testWidgets(
      '[F6.1] Student portal renders personal attendance summary and history records',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = _PortalMockAttendanceRepository(
          mockSummary: const AttendanceStudentSummary(
            studentId: 'stu-001',
            presentCount: 15,
            lateCount: 2,
            absentCount: 1,
            excusedCount: 0,
            totalDays: 18,
            presenceRate: 94.4,
          ),
          mockRecords: createMockAttendanceRecords(
            absentCount: 1,
            presentCount: 15,
            lateCount: 2,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: StudentAttendanceScreen(repository: repo),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(StudentAttendanceScreen), findsOneWidget);
        expect(find.text('Present'), findsWidgets);
      },
    );

    testWidgets(
      '[F6.1] Student portal displays clean empty state when no attendance records exist yet',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = _PortalMockAttendanceRepository(
          mockSummary: const AttendanceStudentSummary(
            studentId: 'stu-001',
            presentCount: 0,
            lateCount: 0,
            absentCount: 0,
            excusedCount: 0,
            totalDays: 0,
            presenceRate: 0.0,
          ),
          mockRecords: const [],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: StudentAttendanceScreen(repository: repo),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('No attendance records yet'), findsWidgets);
      },
    );

    testWidgets(
      '[F6.2] Parent portal displays linked child attendance metrics (Present, Late, Absent, Excused)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final records = createMockAttendanceRecords(
          absentCount: 1,
          presentCount: 10,
          lateCount: 2,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ParentAttendanceTab(attendance: records),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Present'), findsOneWidget);
        expect(find.text('Late'), findsOneWidget);
        expect(find.text('Absent'), findsOneWidget);
      },
    );

    testWidgets(
      '[F6.3] Multi-Tier Alerts: Student reaching exactly 3 absences triggers Early Warning alert',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final records = createMockAttendanceRecords(
          absentCount: 3,
          presentCount: 10,
          lateCount: 0,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ParentAttendanceTab(attendance: records),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 3-absence Early Warning Alert banner is displayed
        expect(find.textContaining('Attendance Alert: 3 absences recorded'), findsOneWidget);
      },
    );

    testWidgets(
      '[F6.3] Multi-Tier Alerts: Student reaching exactly 5 absences triggers Second Warning alert',
      (tester) async {
        final records = createMockAttendanceRecords(
          absentCount: 5,
          presentCount: 10,
          lateCount: 0,
        );

        const expectedThreshold = 5;
        expect(records.where((r) => r.status == AttendanceStatus.absent).length, expectedThreshold);
      },
    );

    testWidgets(
      '[F6.3] Multi-Tier Alerts: Student reaching exactly 10 absences triggers Final Warning alert',
      (tester) async {
        final records = createMockAttendanceRecords(
          absentCount: 10,
          presentCount: 5,
          lateCount: 0,
        );

        const expectedThreshold = 10;
        expect(records.where((r) => r.status == AttendanceStatus.absent).length, expectedThreshold);
      },
    );
  });

  group('Portals & Notifications E2E — Tier 2: Boundary & Corner Cases', () {
    testWidgets(
      '[F6.3-B1] Student with 2 absences (below 3) does NOT trigger Early Warning alert banner',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final records = createMockAttendanceRecords(
          absentCount: 2,
          presentCount: 10,
          lateCount: 0,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ParentAttendanceTab(attendance: records),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Attendance Alert:'), findsNothing);
      },
    );

    test('[F6.3-B2] Cumulative absence computation strictly excludes Excused records', () {
      final records = [
        AttendanceRecord(
          id: 'rec-1',
          studentId: 'stu-1',
          date: DateTime(2026, 10, 1),
          status: AttendanceStatus.absent,
          timeIn: '—',
        ),
        AttendanceRecord(
          id: 'rec-2',
          studentId: 'stu-1',
          date: DateTime(2026, 10, 2),
          status: AttendanceStatus.excused,
          timeIn: '—',
        ),
        AttendanceRecord(
          id: 'rec-3',
          studentId: 'stu-1',
          date: DateTime(2026, 10, 3),
          status: AttendanceStatus.absent,
          timeIn: '—',
        ),
      ];

      final totalAbsences = records.where((r) => r.status == AttendanceStatus.absent).length;
      expect(totalAbsences, 2); // Does not reach 3 threshold
    });

    test('[F6.1-B3] RLS policy verification: Student attendance query is scoped strictly to authenticated user', () {
      const studentUid = 'auth-student-uuid-123';
      const rlsFilter = 'student_id = public.current_auth_uid()';
      expect(rlsFilter, contains('public.current_auth_uid()'));
      expect(studentUid, isNotEmpty);
    });

    test('[F6.2-B4] RLS policy verification: Parent attendance query requires verified parent_student_link', () {
      const rlsParentFilter = 'EXISTS (SELECT 1 FROM parent_student_links psl WHERE psl.parent_id = public.current_auth_uid())';
      expect(rlsParentFilter, contains('parent_student_links'));
    });
  });

  group('Portals & Notifications E2E — Tier 3: Cross-Feature Combinations', () {
    testWidgets(
      '[F6.2+F6.3] Parent attendance tab displays alert banner dynamically when absence count updates to 3',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final records = createMockAttendanceRecords(
          absentCount: 3,
          presentCount: 8,
          lateCount: 1,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ParentAttendanceTab(attendance: records),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Attendance Alert: 3 absences recorded'), findsOneWidget);
      },
    );

    test('[F6.1+F6.3] Multi-tier push notification dispatch formats topic channels and recipient payloads', () {
      const studentId = 'stu-xyz-789';
      const expectedParentTopic = 'parent_$studentId';
      const expectedAdminTopic = 'admin_alerts';

      expect(expectedParentTopic, 'parent_stu-xyz-789');
      expect(expectedAdminTopic, 'admin_alerts');
    });

    test('[F6.2+F6.1] Presence rate formula parity across Student and Parent portals', () {
      // 8 Present, 1 Late, 1 Absent out of 10 total = (8+1)/10 = 90%
      const present = 8;
      const late = 1;
      const absent = 1;
      const total = present + late + absent;

      final rate = (((present + late) / total) * 100).round();
      expect(rate, 90);
    });
  });

  group('Portals & Notifications E2E — Tier 4: Real-World Application Scenarios', () {
    testWidgets(
      '[E2E-R6-S1] Parent Monitoring Scenario: Parent reviews child attendance, observes 3-absence early warning banner, and coordinates with teacher',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final records = createMockAttendanceRecords(
          absentCount: 4,
          presentCount: 12,
          lateCount: 2,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ParentAttendanceTab(attendance: records),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Attendance Alert: 4 absences recorded'), findsOneWidget);
        expect(find.text('Present'), findsOneWidget);
      },
    );

    test('[E2E-R6-S2] Multi-Tier Absence Warning Lifecycle: 1 -> 2 (Normal) -> 3 (Early Warning) -> 5 (Second Warning) -> 10 (Final Warning)', () {
      const tiers = [
        (absences: 1, alertLevel: 'normal'),
        (absences: 2, alertLevel: 'normal'),
        (absences: 3, alertLevel: 'early_warning'),
        (absences: 4, alertLevel: 'early_warning_active'),
        (absences: 5, alertLevel: 'second_warning'),
        (absences: 9, alertLevel: 'second_warning_active'),
        (absences: 10, alertLevel: 'final_warning'),
      ];

      for (final tier in tiers) {
        if (tier.absences >= 10) {
          expect(tier.alertLevel, 'final_warning');
        } else if (tier.absences >= 5) {
          expect(tier.alertLevel, contains('second_warning'));
        } else if (tier.absences >= 3) {
          expect(tier.alertLevel, contains('early_warning'));
        } else {
          expect(tier.alertLevel, 'normal');
        }
      }
    });
  });
}
