import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/repositories/attendance_repository.dart';
import 'package:class_realm/features/parent/sub_features/child_details/widgets/parent_attendance_tab.dart';
import 'package:class_realm/features/parent/sub_features/profile/widgets/parent_profile_tab.dart';
import 'package:class_realm/features/student/sub_features/schedule/screens/student_attendance_screen.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/attendance_workspace_models.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/shared/widgets/indicators/app_pull_to_refresh.dart';

class _LiveRefreshAttendanceRepo extends AttendanceRepository {
  AttendanceStudentSummary summary;
  List<AttendanceRecord> rows;
  Completer<void>? refreshGate;
  int fetchCalls = 0;

  _LiveRefreshAttendanceRepo({required this.summary, required this.rows});

  @override
  Future<AttendanceStudentSummary> getMyAttendanceSummary() async {
    fetchCalls++;
    if (refreshGate != null) {
      await refreshGate!.future;
    }
    return summary;
  }

  @override
  Future<AttendancePage<AttendanceRecord>> getMyAttendancePage({
    required int offset,
    int pageSize = 20,
  }) async {
    if (refreshGate != null) {
      await refreshGate!.future;
    }
    return AttendancePage<AttendanceRecord>(
      rows: rows,
      nextOffset: rows.length,
      hasMore: false,
    );
  }

  @override
  Future<List<AttendanceRecord>> getAttendanceForStudent(
    String studentId,
  ) async => rows;

  @override
  Future<List<AttendanceRecord>> getAllAttendanceRecords() async => rows;

  @override
  Future<void> recordAttendance({
    required String studentId,
    required AttendanceStatus status,
  }) async {}

  @override
  Future<void> toggleOfflineSync() async {}

  @override
  SyncStatus getSyncStatus() => SyncStatus.online;

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
  ) async => AttendancePage(rows: const [], nextOffset: 0, hasMore: false);

  @override
  Future<AttendanceAnalyticsSummary> getAttendanceAnalytics({
    required String subjectOfferingId,
    required AttendanceDateRange dateRange,
  }) async => const AttendanceAnalyticsSummary(
    presenceRate: 100.0,
    absencesAndExcuses: 0,
    warningCount: 0,
    presentCount: 0,
    lateCount: 0,
    absentCount: 0,
    excusedCount: 0,
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
  Widget wrapMobile(Widget child, {ThemeData? theme}) {
    return MaterialApp(
      theme: theme ?? AppTheme.lightTheme,
      home: Scaffold(body: child),
    );
  }

  group('AppPullToRefresh Mobile Swipe-Down Tests', () {
    testWidgets(
      'swiping down past threshold shows branded staggeredDotsWave capsule, awaits live onRefresh without hiding content, and settles cleanly',
      (tester) async {
        final completer = Completer<void>();
        var refreshCalls = 0;

        await tester.pumpWidget(
          wrapMobile(
            AppPullToRefresh(
              onRefresh: () {
                refreshCalls++;
                return completer.future;
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 80, child: Text('Enrolled Subject Card')),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Idle state: capsule is not mounted (zero idle CPU & pumpAndSettle safe)
        expect(
          find.byKey(const Key('app_pull_to_refresh_capsule')),
          findsNothing,
        );

        // Simulate mobile swipe-down gesture from top
        await tester.drag(
          find.text('Enrolled Subject Card'),
          const Offset(0, 160),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(refreshCalls, 1);
        // Existing content stays visible during refresh (no white/dark flash)
        expect(find.text('Enrolled Subject Card'), findsOneWidget);
        // Branded primary capsule with wave indicator is visible while fetching
        expect(
          find.byKey(const Key('app_pull_to_refresh_capsule')),
          findsOneWidget,
        );

        // Complete the live fetch -> capsule retracts and unmounts cleanly
        completer.complete();
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('app_pull_to_refresh_capsule')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'short accidental pull below threshold cancels cleanly without triggering onRefresh',
      (tester) async {
        var refreshCalls = 0;

        await tester.pumpWidget(
          wrapMobile(
            AppPullToRefresh(
              onRefresh: () async {
                refreshCalls++;
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 80, child: Text('Short Drag Item')),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.drag(find.text('Short Drag Item'), const Offset(0, 20));
        await tester.pumpAndSettle();

        expect(refreshCalls, 0);
        expect(
          find.byKey(const Key('app_pull_to_refresh_capsule')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'ParentAttendanceTab triggers onRefresh on swipe-down even when empty state is shown',
      (tester) async {
        var parentRefreshed = 0;

        await tester.pumpWidget(
          wrapMobile(
            ParentAttendanceTab(
              attendance: const [],
              onRefresh: () async {
                parentRefreshed++;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('No Attendance Logs Yet'), findsOneWidget);

        await tester.drag(
          find.text('No Attendance Logs Yet'),
          const Offset(0, 160),
        );
        await tester.pumpAndSettle();

        expect(parentRefreshed, 1);
      },
    );

    testWidgets(
      'StudentAttendanceScreen silently re-fetches live records on swipe-down without blanking existing cards',
      (tester) async {
        final repo = _LiveRefreshAttendanceRepo(
          summary: const AttendanceStudentSummary(
            studentId: 'stu-1',
            presentCount: 5,
            totalDays: 5,
            presenceRate: 100.0,
          ),
          rows: [
            AttendanceRecord(
              id: 'r1',
              studentId: 'stu-1',
              section: 'General Mathematics',
              date: DateTime(2026, 10, 30),
              timeIn: '07:35 AM',
              status: AttendanceStatus.present,
              method: 'RFID',
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: StudentAttendanceScreen(repository: repo),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('General Mathematics'), findsOneWidget);
        expect(find.text('5'), findsOneWidget);
        expect(repo.fetchCalls, 1);

        // Prepare live server update behind a completer gate
        final gate = Completer<void>();
        repo.refreshGate = gate;
        repo.summary = const AttendanceStudentSummary(
          studentId: 'stu-1',
          presentCount: 6,
          totalDays: 6,
          presenceRate: 100.0,
        );
        repo.rows = [
          AttendanceRecord(
            id: 'r2',
            studentId: 'stu-1',
            section: 'Earth and Life Science',
            date: DateTime(2026, 10, 31),
            timeIn: '07:32 AM',
            status: AttendanceStatus.present,
            method: 'RFID',
          ),
          ...repo.rows,
        ];

        // Swipe down on the mobile attendance list
        await tester.drag(
          find.text('General Mathematics'),
          const Offset(0, 160),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Existing card stays visible while branded capsule animates
        expect(find.text('General Mathematics'), findsOneWidget);
        expect(
          find.byKey(const Key('app_pull_to_refresh_capsule')),
          findsOneWidget,
        );

        gate.complete();
        await tester.pumpAndSettle();

        expect(repo.fetchCalls, 2);
        expect(find.text('Earth and Life Science'), findsOneWidget);
        expect(find.text('6'), findsOneWidget);
        expect(
          find.byKey(const Key('app_pull_to_refresh_capsule')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'ParentProfileTab hides fake phone number fallback and triggers onRefresh on swipe-down',
      (tester) async {
        var profileRefreshed = 0;
        final parent = UserModel(
          id: 'p-1',
          username: 'parent1',
          fullName: 'Elena Santos',
          email: 'elena.santos@example.com',
          role: UserRole.parent,
          contactNumber: null,
        );
        final child = UserModel(
          id: 's-1',
          username: 'stu1',
          fullName: 'Marco Santos',
          email: 'marco@example.com',
          role: UserRole.student,
          gradeLevel: '11',
          departmentOrSection: 'STEM 11-A',
          lrn: '109876543210',
        );

        await tester.pumpWidget(
          wrapMobile(
            ParentProfileTab(
              parent: parent,
              linkedStudent: child,
              onRefresh: () async {
                profileRefreshed++;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Elena Santos'), findsOneWidget);
        expect(find.text('Not provided'), findsOneWidget);
        expect(find.text('+63 917 123 4567'), findsNothing);

        await tester.drag(find.text('Elena Santos'), const Offset(0, 160));
        await tester.pumpAndSettle();

        expect(profileRefreshed, 1);
      },
    );
  });
}
