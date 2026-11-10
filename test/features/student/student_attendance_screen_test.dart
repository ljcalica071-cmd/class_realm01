import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/data/repositories/attendance_repository.dart';
import 'package:class_realm/features/student/sub_features/schedule/screens/student_attendance_screen.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/attendance_workspace_models.dart';

class FakeStudentAttendanceRepository extends AttendanceRepository {
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
  Future<List<AttendanceRecord>> getAttendanceForStudent(
    String studentId,
  ) async => [];
  @override
  Future<List<AttendanceRecord>> getAllAttendanceRecords() async => [];
  @override
  Future<void> recordAttendance({
    required String studentId,
    required AttendanceStatus status,
  }) async {}
  @override
  Future<void> toggleOfflineSync() async {}
  @override
  SyncStatus getSyncStatus() => SyncStatus.synced;
  @override
  Future<AttendanceRosterResult> getAttendanceRosterAndDateRecords({
    required String subjectOfferingId,
    required DateTime date,
  }) async => const AttendanceRosterResult(students: [], records: []);
  @override
  Future<void> saveAttendanceBatch({
    required String subjectOfferingId,
    required DateTime date,
    required List<AttendanceWorkspaceRecord> records,
    List<String>? deletedStudentIds,
  }) async {}
  @override
  Future<AttendancePage<AttendanceWorkspaceRecord>> getAttendanceHistory(
    AttendanceHistoryFilter filter,
  ) async => AttendancePage(rows: [], nextOffset: 0, hasMore: false);
  @override
  Future<AttendanceAnalyticsSummary> getAttendanceAnalytics({
    required String subjectOfferingId,
    required AttendanceDateRange dateRange,
  }) async => AttendanceAnalyticsSummary(
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
  Future<void> correctAttendanceRecord({
    required String subjectOfferingId,
    required String recordId,
    required AttendanceStatus newStatus,
    required String reason,
  }) async {}
}

void main() {
  testWidgets('renders 60-30-10 summary header, clean filter pills, and table pagination', (
    tester,
  ) async {
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
          timeIn: '07:30 AM',
          method: 'General Mathematics • RFID',
          section: 'Section 1',
        ),
      ),
      secondPageRows: [],
    );

    await tester.pumpWidget(
      MaterialApp(home: StudentAttendanceScreen(repository: fakeRepo)),
    );

    // Initial loading
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpAndSettle();

    // Verify AppBar Title & styling
    expect(find.text('My Attendance Logs'), findsOneWidget);

    // Verify summary values (Present, Late, Absent, Rate)
    expect(find.text('15'), findsOneWidget); // Present count
    expect(find.text('75%'), findsOneWidget); // Rate %

    // Verify filter chips have NO (0) counts
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Present'), findsWidgets);
    expect(find.text('Late'), findsWidgets);
    expect(find.text('Absent'), findsWidgets);
    expect(find.text('All (20)'), findsNothing);
    expect(find.text('Present (15)'), findsNothing);

    // Verify Subject selector bar is rendered
    expect(find.text('Subject:'), findsOneWidget);
    expect(find.text('All Subjects'), findsOneWidget);

    // Verify Table Headers
    expect(find.text('DATE & TIME'), findsOneWidget);
    expect(find.text('SUBJECT & INFO'), findsOneWidget);
    expect(find.text('STATUS'), findsOneWidget);

    // Verify Table Row item
    expect(find.text('General Mathematics'), findsWidgets);

    // Verify Table Pagination (Page 1 of 2: 10 per page)
    expect(find.text('Showing 1–10 of 20 logs'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);

    // Tap Next page button
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Verify Page 2 loaded
    expect(find.text('Showing 11–20 of 20 logs'), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);

    // Tap Prev page button
    await tester.tap(find.text('Prev'));
    await tester.pumpAndSettle();
    expect(find.text('Showing 1–10 of 20 logs'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);

    // Tap Subject Filter bar to open modal bottom sheet
    await tester.tap(find.text('Subject:'));
    await tester.pumpAndSettle();

    // Verify Bottom Sheet Modal opened
    expect(find.text('Filter by Subject'), findsOneWidget);
    expect(find.text('Select a subject to view its specific attendance history.'), findsOneWidget);
  });

  testWidgets('renders error state on repository failure', (tester) async {
    final fakeRepo = FakeStudentAttendanceRepository(
      summary: const AttendanceStudentSummary(
        studentId: '',
        presentCount: 0,
        totalDays: 0,
        presenceRate: 0,
      ),
      initialPageRows: [],
      secondPageRows: [],
      shouldThrow: true,
    );

    await tester.pumpWidget(
      MaterialApp(home: StudentAttendanceScreen(repository: fakeRepo)),
    );

    await tester.pumpAndSettle();

    expect(find.text('Unable to Load Attendance'), findsOneWidget);
    expect(find.textContaining('Network failure'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
