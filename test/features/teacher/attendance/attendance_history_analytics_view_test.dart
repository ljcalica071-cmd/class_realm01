import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/attendance_workspace_models.dart';
import 'package:class_realm/data/repositories/attendance_repository.dart';
import 'package:class_realm/features/teacher/sub_features/attendance/widgets/attendance_history_analytics_view.dart';

class MockAttendanceRepository extends AttendanceRepository {
  AttendanceAnalyticsSummary? analyticsSummary;
  AttendancePage<AttendanceWorkspaceRecord>? historyPage;
  bool throwAnalyticsError = false;
  bool throwHistoryError = false;
  String? lastCorrectedRecordId;
  AttendanceStatus? lastCorrectedStatus;
  String? lastCorrectedReason;

  @override
  Future<AttendanceAnalyticsSummary> getAttendanceAnalytics({
    required String subjectOfferingId,
    required AttendanceDateRange dateRange,
  }) async {
    if (throwAnalyticsError) {
      throw Exception('Analytics network error');
    }
    return analyticsSummary ??
        AttendanceAnalyticsSummary(
          presenceRate: 85.0,
          absencesAndExcuses: 5,
          warningCount: 1,
          presentCount: 15,
          lateCount: 2,
          absentCount: 3,
          excusedCount: 2,
          trendPoints: [
            AttendanceTrendPoint(
              bucketStart: DateTime(2026, 10, 1),
              presentCount: 8,
              absentOrExcusedCount: 1,
            ),
            AttendanceTrendPoint(
              bucketStart: DateTime(2026, 10, 2),
              presentCount: 9,
              absentOrExcusedCount: 2,
            ),
          ],
          atRiskStudents: const [
            AttendanceAtRiskStudent(
              studentId: 's1',
              studentName: 'Dela Cruz, Juan H.',
              section: 'STEM-11A',
              absenceCount: 3,
            ),
          ],
        );
  }

  @override
  Future<AttendancePage<AttendanceWorkspaceRecord>> getAttendanceHistory(
    AttendanceHistoryFilter filter,
  ) async {
    if (throwHistoryError) {
      throw Exception('History network error');
    }
    return historyPage ??
        AttendancePage<AttendanceWorkspaceRecord>(
          rows: [
            AttendanceWorkspaceRecord(
              id: 'rec-1',
              studentId: 's1',
              subjectOfferingId: filter.subjectOfferingId,
              attendanceDate: DateTime(2026, 10, 2),
              status: AttendanceStatus.absent,
              source: AttendanceSource.manual,
              createdAt: DateTime(2026, 10, 2, 8, 30),
              recordedBy: 'teacher-1',
            ),
          ],
          nextOffset: 1,
          hasMore: false,
        );
  }

  @override
  Future<void> correctAttendanceRecord({
    required String subjectOfferingId,
    required String recordId,
    required AttendanceStatus newStatus,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw ArgumentError('Correction reason must not be blank.');
    }
    lastCorrectedRecordId = recordId;
    lastCorrectedStatus = newStatus;
    lastCorrectedReason = reason;
  }

  @override
  Future<AttendanceRosterResult> getAttendanceRosterAndDateRecords({
    required String subjectOfferingId,
    required DateTime date,
  }) async => throw UnimplementedError();

  @override
  Future<void> saveAttendanceBatch({
    required String subjectOfferingId,
    required DateTime date,
    required List<AttendanceWorkspaceRecord> records,
    List<String>? deletedStudentIds,
  }) async => throw UnimplementedError();

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
  Future<List<AttendanceRecord>> getAttendanceForStudent(String studentId) async =>
      [];

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
  group('AttendanceHistoryAnalyticsView', () {
    late MockAttendanceRepository repository;

    setUp(() {
      repository = MockAttendanceRepository();
    });

    testWidgets('renders KPI cards, at-risk list, and paginated logs', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AttendanceHistoryAnalyticsView(
                subjectOfferingId: 'offering-101',
                repository: repository,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check KPI values (6 redesigned KPI cards)
      expect(find.text('85.0%'), findsOneWidget); // Presence Rate
      expect(find.text('15'), findsWidgets); // Present
      expect(find.text('3'), findsWidgets); // Absent
      expect(find.text('1'), findsWidgets); // Early Warning count

      // Check At-Risk student display
      expect(find.text('Dela Cruz, Juan H.'), findsWidgets);
      expect(find.textContaining('3 Absences'), findsWidgets);

      // Check log row
      expect(find.text('rec-1'), findsNothing); // internal id not raw text
      expect(find.text('Manual'), findsWidgets);
    });

    testWidgets('handles custom date range validation when start is after end', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AttendanceHistoryAnalyticsView(
                subjectOfferingId: 'offering-101',
                repository: repository,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Select Custom filter
      final customTab = find.text('Custom');
      expect(customTab, findsOneWidget);
      await tester.tap(customTab);
      await tester.pumpAndSettle();

      expect(find.textContaining('Start Date:'), findsOneWidget);
      expect(find.textContaining('End Date:'), findsOneWidget);
    });

    testWidgets('handles correction dialog requiring a reason and updates record', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AttendanceHistoryAnalyticsView(
                subjectOfferingId: 'offering-101',
                repository: repository,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Correct button
      final correctBtn = find.text('Correct');
      expect(correctBtn, findsOneWidget);
      await tester.ensureVisible(correctBtn);
      await tester.tap(correctBtn);
      await tester.pumpAndSettle();

      // Dialog should be visible
      expect(find.text('Correct Attendance Record'), findsOneWidget);
      expect(
        find.text('Please provide a reason for this attendance correction.'),
        findsNothing,
      );

      // Try submitting without reason: shows inline validation error & zero SnackBars
      final submitBtn = find.text('Save Correction');
      expect(submitBtn, findsOneWidget);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(
        find.text('Please provide a reason for this attendance correction.'),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);

      // Enter a reason
      await tester.enterText(
        find.byKey(const ValueKey('correction_reason_input')),
        'Medical certificate presented',
      );
      await tester.pumpAndSettle();

      // Tap submit
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(repository.lastCorrectedRecordId, 'rec-1');
      expect(repository.lastCorrectedReason, 'Medical certificate presented');
    });
  });
}
