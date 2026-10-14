import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/data/repositories/attendance_repository.dart';
import 'package:class_realm/features/student/sub_features/schedule/screens/student_attendance_screen.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/attendance_workspace_models.dart';

class FakeStudentAttendanceRepository implements AttendanceRepository {
  AttendanceStudentSummary summary;
  List<AttendanceRecord> initialPageRows;
  List<AttendanceRecord> secondPageRows;
  bool shouldThrow;

  FakeStudentAttendanceRepository({
    required this.summary,
    required this.initialPageRows,
    required this.secondPageRows,
    this.shouldThrow = false,
  });

  @override
  Future<AttendanceStudentSummary> getMyAttendanceSummary() async {
    if (shouldThrow) throw Exception('Network failure');
    return summary;
  }

  @override
  Future<AttendancePage<AttendanceRecord>> getMyAttendancePage({
    required int offset,
    int pageSize = 20,
  }) async {
    if (shouldThrow) throw Exception('Network failure');
    if (offset == 0) {
      return AttendancePage(
        rows: initialPageRows,
        nextOffset: initialPageRows.length,
        hasMore: true,
      );
    } else {
      return AttendancePage(
        rows: secondPageRows,
        nextOffset: offset + secondPageRows.length,
        hasMore: false,
      );
    }
  }

  @override
  Future<List<AttendanceRecord>> getAttendanceForStudent(String studentId) async => [];
  @override
  Future<List<AttendanceRecord>> getAllAttendanceRecords() async => [];
  @override
  Future<void> recordAttendance({required String studentId, required AttendanceStatus status}) async {}
  @override
  Future<void> toggleOfflineSync() async {}
  @override
  SyncStatus getSyncStatus() => SyncStatus.synced;
  @override
  Future<AttendanceRosterResult> getAttendanceRosterAndDateRecords({required String subjectOfferingId, required DateTime date}) async =>
      const AttendanceRosterResult(students: [], records: []);
  @override
  Future<void> saveAttendanceBatch({required String subjectOfferingId, required DateTime date, required List<AttendanceWorkspaceRecord> records}) async {}
  @override
  Future<AttendancePage<AttendanceWorkspaceRecord>> getAttendanceHistory(AttendanceHistoryFilter filter) async =>
      AttendancePage(rows: [], nextOffset: 0, hasMore: false);
  @override
  Future<AttendanceAnalyticsSummary> getAttendanceAnalytics({required String subjectOfferingId, required AttendanceDateRange dateRange}) async =>
      AttendanceAnalyticsSummary(
        presenceRate: null,
        absencesAndExcuses: 0,
        warningCount: 0,
        presentCount: 0,
        lateCount: 0,
        absentCount: 0,
        excusedCount: 0,
        trendPoints: [],
        atRiskStudents: [],
      );
  @override
  Future<void> correctAttendanceRecord({required String subjectOfferingId, required String recordId, required AttendanceStatus newStatus, required String reason}) async {}
}

void main() {
  testWidgets('renders server-computed summary header and logs', (tester) async {
    final fakeRepo = FakeStudentAttendanceRepository(
      summary: const AttendanceStudentSummary(
        studentId: 'student-1',
        presentCount: 15,
        totalDays: 20,
        presenceRate: 0.75,
      ),
      initialPageRows: List.generate(
        20,
        (i) => AttendanceRecord(
          id: 'rec-$i',
          studentId: 'student-1',
          date: DateTime(2026, 10, i + 1),
          status: AttendanceStatus.present,
          timeIn: 'N/A',
          timeOut: 'N/A',
          method: 'General Mathematics',
        ),
      ),
      secondPageRows: [
        AttendanceRecord(
          id: 'rec-21',
          studentId: 'student-1',
          date: DateTime(2026, 9, 30),
          status: AttendanceStatus.late,
          timeIn: 'N/A',
          timeOut: 'N/A',
          method: 'General Mathematics',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StudentAttendanceScreen(repository: fakeRepo),
      ),
    );

    // Initial loading
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpAndSettle();

    // Verify summary values
    expect(find.text('15'), findsOneWidget); // Present
    expect(find.text('20'), findsOneWidget); // Total Days
    expect(find.text('75%'), findsOneWidget); // Rate

    // Verify initial records and Load More button
    expect(find.text('Load More Records'), findsOneWidget);

    // Tap Load More Records
    await tester.tap(find.text('Load More Records'));
    await tester.pumpAndSettle();

    // Second page row loaded, Load More button gone because hasMore is false
    expect(find.text('Load More Records'), findsNothing);
  });

  testWidgets('renders error state on repository failure', (tester) async {
    final fakeRepo = FakeStudentAttendanceRepository(
      summary: const AttendanceStudentSummary(studentId: '', presentCount: 0, totalDays: 0, presenceRate: 0),
      initialPageRows: [],
      secondPageRows: [],
      shouldThrow: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StudentAttendanceScreen(repository: fakeRepo),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Error loading attendance'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
