import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/data/repositories/attendance_repository.dart';
import 'package:class_realm/features/parent/sub_features/child_details/widgets/parent_attendance_tab.dart';
import 'package:class_realm/features/student/sub_features/schedule/screens/student_attendance_screen.dart';
import 'package:class_realm/features/teacher/sub_features/attendance/utils/sf2_csv_exporter.dart';
import 'package:class_realm/features/teacher/sub_features/attendance/widgets/attendance_history_analytics_view.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/attendance_workspace_models.dart';
import 'package:class_realm/shared/widgets/empty_state/app_empty_state.dart';

class _FakeAttendanceRepository extends AttendanceRepository {
  AttendanceStudentSummary studentSummary;
  AttendancePage<AttendanceRecord> studentFirstPage;
  Future<AttendancePage<AttendanceRecord>> Function(int offset, int pageSize)?
  onStudentNextPage;

  AttendanceAnalyticsSummary analyticsSummary;
  AttendancePage<AttendanceWorkspaceRecord> historyPage;

  int correctionCalls = 0;
  String? lastCorrectedRecordId;
  AttendanceStatus? lastCorrectedStatus;
  String? lastCorrectionReason;

  _FakeAttendanceRepository({
    AttendanceStudentSummary? studentSummary,
    AttendancePage<AttendanceRecord>? studentFirstPage,
    AttendanceAnalyticsSummary? analyticsSummary,
    AttendancePage<AttendanceWorkspaceRecord>? historyPage,
  }) : studentSummary =
           studentSummary ??
           const AttendanceStudentSummary(
             studentId: 'stu-001',
             presentCount: 8,
             lateCount: 1,
             absentCount: 1,
             excusedCount: 0,
             totalDays: 10,
             presenceRate: 90.0,
           ),
       studentFirstPage =
           studentFirstPage ??
           AttendancePage<AttendanceRecord>(
             rows: const [],
             nextOffset: 0,
             hasMore: false,
           ),
       analyticsSummary =
           analyticsSummary ??
           const AttendanceAnalyticsSummary(
             presenceRate: 88.5,
             absencesAndExcuses: 4,
             warningCount: 1,
             presentCount: 20,
             lateCount: 3,
             absentCount: 3,
             excusedCount: 1,
             trendPoints: [],
             atRiskStudents: [],
           ),
       historyPage =
           historyPage ??
           AttendancePage<AttendanceWorkspaceRecord>(
             rows: const [],
             nextOffset: 0,
             hasMore: false,
           );

  @override
  Future<List<AttendanceRecord>> getAttendanceForStudent(
    String studentId,
  ) async => studentFirstPage.rows;

  @override
  Future<List<AttendanceRecord>> getAllAttendanceRecords() async =>
      studentFirstPage.rows;

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
  }) async {
    return const AttendanceRosterResult(students: [], records: []);
  }

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
  ) async {
    return historyPage;
  }

  @override
  Future<AttendanceAnalyticsSummary> getAttendanceAnalytics({
    required String subjectOfferingId,
    required AttendanceDateRange dateRange,
  }) async {
    return analyticsSummary;
  }

  @override
  Future<void> correctAttendanceRecord({
    required String subjectOfferingId,
    required String recordId,
    required AttendanceStatus newStatus,
    required String reason,
  }) async {
    correctionCalls++;
    lastCorrectedRecordId = recordId;
    lastCorrectedStatus = newStatus;
    lastCorrectionReason = reason;
  }

  @override
  Future<AttendanceStudentSummary> getMyAttendanceSummary() async {
    return studentSummary;
  }

  @override
  Future<AttendancePage<AttendanceRecord>> getMyAttendancePage({
    required int offset,
    int pageSize = 20,
  }) async {
    if (offset > 0 && onStudentNextPage != null) {
      return onStudentNextPage!(offset, pageSize);
    }
    return studentFirstPage;
  }
}

Widget _wrapWithApp(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness, useMaterial3: true),
    home: child,
  );
}

void main() {
  group('Attendance Workspace Domain Models Unit Tests', () {
    test(
      'AttendanceSource.parse normalizes Manual, RFID, and System variants',
      () {
        expect(AttendanceSource.parse('Manual'), AttendanceSource.manual);
        expect(AttendanceSource.parse('manual'), AttendanceSource.manual);
        expect(AttendanceSource.parse(null), AttendanceSource.manual);
        expect(AttendanceSource.parse('   '), AttendanceSource.manual);

        expect(AttendanceSource.parse('RFID'), AttendanceSource.rfid);
        expect(AttendanceSource.parse('rfid'), AttendanceSource.rfid);

        expect(AttendanceSource.parse('System'), AttendanceSource.system);
        expect(AttendanceSource.parse('Auto'), AttendanceSource.system);
        expect(
          AttendanceSource.parse('Auto (System)'),
          AttendanceSource.system,
        );

        expect(AttendanceSource.manual.toDbString(), 'Manual');
        expect(AttendanceSource.rfid.toDbString(), 'RFID');
        expect(AttendanceSource.system.toDbString(), 'System');
      },
    );

    test('AttendanceWorkspaceRecord JSON round-trip preserves recording_method, time_in, and device_id', () {
      final original = AttendanceWorkspaceRecord(
        id: 'rec-101',
        studentId: 'stu-202',
        subjectOfferingId: 'off-303',
        attendanceDate: DateTime(2026, 10, 30),
        status: AttendanceStatus.late,
        source: AttendanceSource.rfid,
        remarks: 'Arrived 10 mins after bell',
        recordedBy: 'teacher-1',
        timeIn: '07:40:15',
        deviceId: 'USB_SCANNER_ROOM_204',
        createdAt: DateTime.utc(2026, 10, 30, 7, 40, 15),
        modifiedBy: 'teacher-1',
      );

      final json = original.toJson();
      expect(json['recording_method'], 'RFID');
      expect(json['time_in'], '07:40:15');
      expect(json['device_id'], 'USB_SCANNER_ROOM_204');

      final restored = AttendanceWorkspaceRecord.fromJson(json);
      expect(restored.id, 'rec-101');
      expect(restored.studentId, 'stu-202');
      expect(restored.subjectOfferingId, 'off-303');
      expect(restored.attendanceDate, DateTime(2026, 10, 30));
      expect(restored.status, AttendanceStatus.late);
      expect(restored.source, AttendanceSource.rfid);
      expect(restored.timeIn, '07:40:15');
      expect(restored.deviceId, 'USB_SCANNER_ROOM_204');
      expect(restored.remarks, 'Arrived 10 mins after bell');
    });

    test('AttendanceRosterStudent formats displayName as "Last, First M." and checks hasRfidAssigned', () {
      const assignedStudent = AttendanceRosterStudent(
        studentId: 'stu-001',
        lrn: '123456789012',
        rfidUid: '04A2B3C4D5',
        firstName: 'Ljay',
        middleName: 'Hernandez',
        lastName: 'Calica',
        gender: 'male',
      );

      expect(assignedStudent.displayName, 'Calica, Ljay H.');
      expect(assignedStudent.hasRfidAssigned, isTrue);

      const unassignedStudent = AttendanceRosterStudent(
        studentId: 'stu-002',
        rfidUid: '   ',
        firstName: 'Maria',
        middleName: null,
        lastName: 'Santos',
        gender: 'female',
      );

      expect(unassignedStudent.displayName, 'Santos, Maria');
      expect(unassignedStudent.hasRfidAssigned, isFalse);
    });

    test('AttendanceScheduleStatus.isLockedByDefault locks holidays and unscheduled days', () {
      const config = AttendanceCutoffConfig(subjectOfferingId: 'off-1');

      const holidayStatus = AttendanceScheduleStatus(
        hasPlottedScheduleAnyDay: true,
        isScheduledOnDate: true,
        isHoliday: true,
        holidayName: 'Bonifacio Day',
        cutoffConfig: config,
      );
      expect(holidayStatus.isLockedByDefault, isTrue);
      expect(holidayStatus.lockReason, contains('Bonifacio Day'));

      const unscheduledDayStatus = AttendanceScheduleStatus(
        hasPlottedScheduleAnyDay: true,
        isScheduledOnDate: false,
        isHoliday: false,
        cutoffConfig: config,
      );
      expect(unscheduledDayStatus.isLockedByDefault, isTrue);
      expect(unscheduledDayStatus.lockReason, isNotNull);

      const scheduledRegularDay = AttendanceScheduleStatus(
        hasPlottedScheduleAnyDay: true,
        isScheduledOnDate: true,
        isHoliday: false,
        cutoffConfig: config,
      );
      expect(scheduledRegularDay.isLockedByDefault, isFalse);
      expect(scheduledRegularDay.lockReason, isNull);
    });

    test(
      'Sf2CsvExporter generates DepEd SF2 summary CSV with codes and KPIs',
      () {
        final csv = Sf2CsvExporter.buildSf2SummaryCsv(
          subjectOfferingId: 'STEM11-GENMATH',
          dateRange: AttendanceDateRange(
            startDate: DateTime(2026, 10, 1),
            endDate: DateTime(2026, 10, 30),
          ),
          summary: const AttendanceAnalyticsSummary(
            presenceRate: 90.0,
            absencesAndExcuses: 3,
            warningCount: 1,
            presentCount: 8,
            lateCount: 1,
            absentCount: 3,
            excusedCount: 0,
            atRiskStudents: [
              AttendanceAtRiskStudent(
                studentId: 'stu-9',
                studentName: 'Calica, Ljay H.',
                section: 'STEM 11-A',
                absenceCount: 3,
              ),
            ],
          ),
          historyRows: [
            AttendanceWorkspaceRecord(
              id: 'r1',
              studentId: 'stu-9',
              subjectOfferingId: 'STEM11-GENMATH',
              attendanceDate: DateTime(2026, 10, 29),
              status: AttendanceStatus.present,
              source: AttendanceSource.rfid,
              timeIn: '07:35 AM',
            ),
          ],
        );

        expect(csv, contains('DepEd School Form 2 (SF2)'));
        expect(csv, contains('90.0%'));
        expect(csv, contains('Calica, Ljay H.'));
        expect(csv, contains('07:35 AM'));
        expect(csv, contains('RFID'));
      },
    );
  });

  group('StudentAttendanceScreen Widget Tests', () {
    testWidgets(
      'renders 90% rate (not 9000%), view-only cards with Time In & provenance, and Early Warning when absentCount >= 3',
      (tester) async {
        final fakeRepo = _FakeAttendanceRepository(
          studentSummary: const AttendanceStudentSummary(
            studentId: 'stu-001',
            presentCount: 24,
            lateCount: 3,
            absentCount: 3,
            excusedCount: 0,
            totalDays: 30,
            presenceRate: 90.0,
          ),
          studentFirstPage: AttendancePage<AttendanceRecord>(
            rows: [
              AttendanceRecord(
                id: 'att-1',
                studentId: 'stu-001',
                section: 'General Mathematics',
                date: DateTime(2026, 10, 30),
                timeIn: '07:42 AM',
                status: AttendanceStatus.present,
                method: 'RFID',
              ),
              AttendanceRecord(
                id: 'att-2',
                studentId: 'stu-001',
                section: 'Oral Communication',
                date: DateTime(2026, 10, 29),
                timeIn: '—',
                status: AttendanceStatus.absent,
                method: 'System',
                remarks: 'Auto-marked after cutoff',
              ),
            ],
            nextOffset: 2,
            hasMore: false,
          ),
        );

        await tester.pumpWidget(
          _wrapWithApp(StudentAttendanceScreen(repository: fakeRepo)),
        );
        await tester.pumpAndSettle();

        // Critical Rate Bug Verification: 90.0 -> 90%, NOT 9000%
        expect(find.text('90%'), findsOneWidget);
        expect(find.text('9000%'), findsNothing);

        // 4 Summary Stat Cards
        expect(find.text('Present'), findsWidgets);
        expect(find.text('Late'), findsWidgets);
        expect(find.text('Absent'), findsWidgets);
        expect(find.text('Rate'), findsOneWidget);

        // Early Warning Banner for >= 3 absences
        expect(find.text('Early Warning: 3 Recorded Absences'), findsOneWidget);

        // Provenance & Time In on strictly view-only cards
        expect(find.text('General Mathematics'), findsOneWidget);
        expect(find.text('Time In: 07:42 AM'), findsOneWidget);
        expect(find.text('RFID'), findsOneWidget);
        expect(find.text('System'), findsOneWidget);

        // Strictly view-only (no Correct / Edit buttons)
        expect(find.text('Correct'), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets(
      'renders AppEmptyState when student attendance records are empty',
      (tester) async {
        final fakeRepo = _FakeAttendanceRepository(
          studentSummary: const AttendanceStudentSummary(
            studentId: 'stu-001',
            presentCount: 0,
            lateCount: 0,
            absentCount: 0,
            excusedCount: 0,
            totalDays: 0,
            presenceRate: 100.0,
          ),
          studentFirstPage: AttendancePage<AttendanceRecord>(
            rows: const [],
            nextOffset: 0,
            hasMore: false,
          ),
        );

        await tester.pumpWidget(
          _wrapWithApp(StudentAttendanceScreen(repository: fakeRepo)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AppEmptyState), findsOneWidget);
        expect(find.text('No Attendance Records Yet'), findsOneWidget);
        expect(
          find.text('Early Warning: You have 3 or more recorded absences.'),
          findsNothing,
        );
      },
    );
  });

  group('ParentAttendanceTab Widget Tests', () {
    testWidgets('renders AppEmptyState when child attendance list is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithApp(const Scaffold(body: ParentAttendanceTab(attendance: []))),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(find.text('No Attendance Logs Yet'), findsOneWidget);
    });

    testWidgets(
      'renders Present/Late/Absent/Rate stat cards and Early Warning banner when 3+ absences exist',
      (tester) async {
        final logs = [
          AttendanceRecord(
            id: 'p1',
            studentId: 'child-1',
            section: 'Earth and Life Science',
            date: DateTime(2026, 10, 26),
            timeIn: '07:50 AM',
            status: AttendanceStatus.present,
            method: 'RFID',
          ),
          AttendanceRecord(
            id: 'p2',
            studentId: 'child-1',
            section: 'Earth and Life Science',
            date: DateTime(2026, 10, 27),
            timeIn: '08:12 AM',
            status: AttendanceStatus.late,
            method: 'Manual',
          ),
          AttendanceRecord(
            id: 'p3',
            studentId: 'child-1',
            section: 'Earth and Life Science',
            date: DateTime(2026, 10, 28),
            timeIn: '—',
            status: AttendanceStatus.absent,
            method: 'System',
          ),
          AttendanceRecord(
            id: 'p4',
            studentId: 'child-1',
            section: 'Earth and Life Science',
            date: DateTime(2026, 10, 29),
            timeIn: '—',
            status: AttendanceStatus.absent,
            method: 'Manual',
          ),
          AttendanceRecord(
            id: 'p5',
            studentId: 'child-1',
            section: 'Earth and Life Science',
            date: DateTime(2026, 10, 30),
            timeIn: '—',
            status: AttendanceStatus.absent,
            method: 'System',
          ),
        ];

        await tester.pumpWidget(
          _wrapWithApp(
            Scaffold(body: ParentAttendanceTab(attendance: logs)),
            brightness: Brightness.dark,
          ),
        );
        await tester.pumpAndSettle();

        // (1 present + 1 late) / 5 totalAccounted * 100 = 40%
        expect(find.text('Present'), findsWidgets);
        expect(find.text('Late'), findsWidgets);
        expect(find.text('Absent'), findsWidgets);
        expect(find.text('Rate'), findsOneWidget);
        expect(find.text('40%'), findsOneWidget);

        // Early Warning Banner
        expect(find.text('Early Warning: 3 Recorded Absences'), findsOneWidget);

        // Provenance & Time In
        expect(find.text('Time In: 07:50 AM'), findsOneWidget);
        expect(find.text('RFID'), findsWidgets);
        expect(find.text('Manual'), findsWidgets);
        expect(find.text('System'), findsWidgets);
        expect(find.text('Correct'), findsNothing);
      },
    );
  });

  group('AttendanceHistoryAnalyticsView Widget Tests', () {
    testWidgets(
      'renders At-Risk students (>= 3 absences) and validates Correction modal inline with zero SnackBars',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final fakeRepo = _FakeAttendanceRepository(
          analyticsSummary: const AttendanceAnalyticsSummary(
            presenceRate: 84.0,
            absencesAndExcuses: 4,
            warningCount: 1,
            presentCount: 18,
            lateCount: 3,
            absentCount: 4,
            excusedCount: 0,
            trendPoints: [],
            atRiskStudents: [
              AttendanceAtRiskStudent(
                studentId: 'stu-009',
                studentName: 'Calica, Ljay H.',
                section: 'STEM 11-A',
                absenceCount: 4,
              ),
            ],
          ),
          historyPage: AttendancePage<AttendanceWorkspaceRecord>(
            rows: [
              AttendanceWorkspaceRecord(
                id: 'hist-001',
                studentId: 'stu-009',
                subjectOfferingId: 'offering-math-11',
                attendanceDate: DateTime(2026, 10, 30),
                status: AttendanceStatus.absent,
                source: AttendanceSource.system,
                timeIn: null,
              ),
            ],
            nextOffset: 1,
            hasMore: false,
          ),
        );

        await tester.pumpWidget(
          _wrapWithApp(
            Scaffold(
              body: SingleChildScrollView(
                child: AttendanceHistoryAnalyticsView(
                  subjectOfferingId: 'offering-math-11',
                  repository: fakeRepo,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify At-Risk student panel renders prominently
        expect(find.text('Calica, Ljay H.'), findsOneWidget);
        expect(find.textContaining('STEM 11-A'), findsOneWidget);
        expect(find.text('3+ Absences — Intervention Needed'), findsOneWidget);

        // Verify History row Time In fallback & System provenance badge
        expect(find.text('—'), findsWidgets);
        expect(find.text('System'), findsOneWidget);

        // Open Correction Modal
        await tester.tap(find.text('Correct'));
        await tester.pumpAndSettle();

        expect(find.text('Correct Attendance Record'), findsOneWidget);
        expect(find.text('Save Correction'), findsOneWidget);

        // Submit empty reason -> must render inline validation error & ZERO SnackBars
        await tester.tap(find.text('Save Correction'));
        await tester.pumpAndSettle();

        expect(
          find.text('Please provide a reason for this attendance correction.'),
          findsOneWidget,
        );
        expect(find.byType(SnackBar), findsNothing);
        expect(fakeRepo.correctionCalls, 0);

        // Typing into Reason field immediately clears inline error
        await tester.enterText(
          find.byKey(const ValueKey('correction_reason_input')),
          'Excused medical clinic slip verified',
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Please provide a reason for this attendance correction.'),
          findsNothing,
        );

        // Save valid correction
        await tester.tap(find.text('Save Correction'));
        await tester.pumpAndSettle();

        expect(fakeRepo.correctionCalls, 1);
        expect(
          fakeRepo.lastCorrectionReason,
          'Excused medical clinic slip verified',
        );
        expect(find.byType(SnackBar), findsNothing);
      },
    );
  });
}
