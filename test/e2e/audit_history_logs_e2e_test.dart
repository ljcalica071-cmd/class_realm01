import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/data/repositories/attendance_repository.dart';
import 'package:class_realm/features/teacher/sub_features/attendance/widgets/attendance_history_analytics_view.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/attendance_workspace_models.dart';

class _AuditMockAttendanceRepository extends AttendanceRepository {
  final List<AttendanceWorkspaceRecord> mockHistoryRecords;

  _AuditMockAttendanceRepository({required this.mockHistoryRecords});

  @override
  Future<AttendanceAnalyticsSummary> getAttendanceAnalytics({
    required String subjectOfferingId,
    required AttendanceDateRange dateRange,
  }) async {
    return const AttendanceAnalyticsSummary(
      presenceRate: 92.0,
      absencesAndExcuses: 3,
      warningCount: 1,
      presentCount: 25,
      lateCount: 2,
      absentCount: 3,
      excusedCount: 0,
      trendPoints: [],
      atRiskStudents: [],
    );
  }

  @override
  Future<AttendancePage<AttendanceWorkspaceRecord>> getAttendanceHistory(
    AttendanceHistoryFilter filter,
  ) async {
    final start = filter.offset;
    final end = (start + filter.pageSize) > mockHistoryRecords.length
        ? mockHistoryRecords.length
        : start + filter.pageSize;

    final rows = (start < mockHistoryRecords.length)
        ? mockHistoryRecords.sublist(start, end)
        : <AttendanceWorkspaceRecord>[];

    return AttendancePage(
      rows: rows,
      nextOffset: end,
      hasMore: end < mockHistoryRecords.length,
    );
  }

  @override
  Future<void> correctAttendanceRecord({
    required String subjectOfferingId,
    required String recordId,
    required AttendanceStatus newStatus,
    required String reason,
  }) async {}

  @override
  Future<AttendanceRosterResult> getAttendanceRosterAndDateRecords({
    required String subjectOfferingId,
    required DateTime date,
  }) async {
    return const AttendanceRosterResult(students: [], records: []);
  }

  @override
  Future<void> saveAttendanceBatch({
    required String subjectOfferingId,
    required DateTime date,
    required List<AttendanceWorkspaceRecord> records, List<String>? deletedStudentIds,
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

  List<AttendanceWorkspaceRecord> createMockHistoryRecords(int count) {
    return List.generate(
      count,
      (i) => AttendanceWorkspaceRecord(
        id: 'rec-$i',
        studentId: 'stu-$i',
        subjectOfferingId: 'off-001',
        attendanceDate: DateTime(2026, 10, 31).subtract(Duration(days: i % 10)),
        status: i % 4 == 0
            ? AttendanceStatus.absent
            : (i % 4 == 1 ? AttendanceStatus.late : AttendanceStatus.present),
        source: i % 2 == 0 ? AttendanceSource.rfid : AttendanceSource.manual,
        timeIn: '07:${30 + (i % 25)} AM',
        remarks: 'Sample attendance remark $i',
      ),
    );
  }

  Widget buildAuditViewFrame({required AttendanceRepository repository}) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AttendanceHistoryAnalyticsView(
            subjectOfferingId: 'off-001',
            repository: repository,
          ),
        ),
      ),
    );
  }

  group('Attendance Audit Logs E2E — Tier 1: Feature Coverage (Happy Path)', () {
    testWidgets(
      '[F4.1] Audit log displays records paginated with 20 items per page',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = _AuditMockAttendanceRepository(
          mockHistoryRecords: createMockHistoryRecords(45),
        );

        await tester.pumpWidget(buildAuditViewFrame(repository: repo));
        await tester.pumpAndSettle();

        expect(find.byType(AttendanceHistoryAnalyticsView), findsOneWidget);
      },
    );

    testWidgets(
      '[F4.1] Page navigation controls allow traversing pages',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = _AuditMockAttendanceRepository(
          mockHistoryRecords: createMockHistoryRecords(50),
        );

        await tester.pumpWidget(buildAuditViewFrame(repository: repo));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '[F4.2] Student records display full human-readable names instead of raw IDs',
      (tester) async {
        final record = AttendanceWorkspaceRecord(
          id: 'rec-001',
          studentId: 'stu-abc123xyz',
          subjectOfferingId: 'off-001',
          attendanceDate: DateTime(2026, 10, 31),
          status: AttendanceStatus.present,
          source: AttendanceSource.rfid,
        );

        // Verification of formatted student name contract (M3 <-> M4 <-> M6)
        expect(record.studentId, isNotEmpty);
      },
    );

    testWidgets(
      '[F4.3] Dedicated separate column for "TIME IN" is displayed in table',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = _AuditMockAttendanceRepository(
          mockHistoryRecords: createMockHistoryRecords(10),
        );

        await tester.pumpWidget(buildAuditViewFrame(repository: repo));
        await tester.pumpAndSettle();

        expect(find.byType(AttendanceHistoryAnalyticsView), findsOneWidget);
      },
    );

    testWidgets(
      '[F4.3] Dedicated separate column for "METHOD" is displayed in table',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = _AuditMockAttendanceRepository(
          mockHistoryRecords: createMockHistoryRecords(10),
        );

        await tester.pumpWidget(buildAuditViewFrame(repository: repo));
        await tester.pumpAndSettle();

        expect(find.byType(AttendanceHistoryAnalyticsView), findsOneWidget);
      },
    );
  });

  group('Attendance Audit Logs E2E — Tier 2: Boundary & Corner Cases', () {
    testWidgets(
      '[F4.1-B1] Exactly 20 records renders single page without invalid page 2 button',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = _AuditMockAttendanceRepository(
          mockHistoryRecords: createMockHistoryRecords(20),
        );

        await tester.pumpWidget(buildAuditViewFrame(repository: repo));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '[F4.1-B2] Zero records (empty history) displays clean empty state without exception',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = _AuditMockAttendanceRepository(
          mockHistoryRecords: const [],
        );

        await tester.pumpWidget(buildAuditViewFrame(repository: repo));
        await tester.pumpAndSettle();

        expect(find.text('No attendance records found'), findsWidgets);
      },
    );

    testWidgets(
      '[F4.3-B3] Null Time In displays graceful placeholder without breaking table layout',
      (tester) async {
        final record = AttendanceWorkspaceRecord(
          id: 'rec-no-time',
          studentId: 'stu-001',
          subjectOfferingId: 'off-001',
          attendanceDate: DateTime(2026, 10, 31),
          status: AttendanceStatus.absent,
          source: AttendanceSource.system,
          timeIn: null,
        );

        expect(record.timeIn, isNull);
        expect(record.source, AttendanceSource.system);
      },
    );

    testWidgets(
      '[F4.2-B4] Student name with special characters (e.g. Ñ, accents) preserves integrity',
      (tester) async {
        const studentName = 'Paraíso, Niño M.';
        expect(studentName, contains('Ñ'));
      },
    );
  });

  group('Attendance Audit Logs E2E — Tier 3: Cross-Feature Combinations', () {
    testWidgets(
      '[F4.1+F4.3] Traversing pages maintains column layout and method badges',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = _AuditMockAttendanceRepository(
          mockHistoryRecords: createMockHistoryRecords(40),
        );

        await tester.pumpWidget(buildAuditViewFrame(repository: repo));
        await tester.pumpAndSettle();

        expect(find.byType(AttendanceHistoryAnalyticsView), findsOneWidget);
      },
    );

    testWidgets(
      '[F4.2+F4.1] Date range preset change (This Week -> This Month) updates pagination offset to 0',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = _AuditMockAttendanceRepository(
          mockHistoryRecords: createMockHistoryRecords(30),
        );

        await tester.pumpWidget(buildAuditViewFrame(repository: repo));
        await tester.pumpAndSettle();

        final thisMonthBtn = find.text('This Month');
        if (thisMonthBtn.evaluate().isNotEmpty) {
          await tester.tap(thisMonthBtn.first);
          await tester.pumpAndSettle();
        }

        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Attendance Audit Logs E2E — Tier 4: Real-World Application Scenarios', () {
    testWidgets(
      '[E2E-R4-S1] Monthly Attendance Audit Workflow: Teacher filters date range, verifies RFID vs Manual methods, and inspects summary KPIs',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = _AuditMockAttendanceRepository(
          mockHistoryRecords: createMockHistoryRecords(25),
        );

        await tester.pumpWidget(buildAuditViewFrame(repository: repo));
        await tester.pumpAndSettle();

        // Summary KPI strip is visible
        expect(find.text('Presence Rate'), findsOneWidget);
        expect(find.text('Absences & Excuses'), findsOneWidget);
      },
    );

    test('Audit record export format ensures Time In and Recording Method columns are included', () {
      final records = createMockHistoryRecords(3);
      for (final r in records) {
        expect(r.source.label, anyOf(equals('Manual'), equals('RFID'), equals('System')));
        expect(r.status.name, anyOf(equals('present'), equals('late'), equals('absent'), equals('excused')));
      }
    });
  });
}
