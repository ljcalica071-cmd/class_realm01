import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/attendance_workspace_models.dart';
import 'package:class_realm/data/repositories/attendance_repository.dart';
import 'package:class_realm/core/services/local_storage_service.dart';

class SupabaseAttendanceRepository implements AttendanceRepository {
  final SupabaseClient _client;

  SupabaseAttendanceRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  static final SupabaseAttendanceRepository instance =
      SupabaseAttendanceRepository();

  static String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  // =========================================================================
  // Teacher Attendance Workspace Operations (100% Pure Dart)
  // =========================================================================

  @override
  Future<AttendanceRosterResult> getAttendanceRosterAndDateRecords({
    required String subjectOfferingId,
    required DateTime date,
  }) async {
    final dateStr = _formatDate(date);
    try {
      final enrollments = await _client
          .from('student_enrollments')
          .select('''
            student_id,
            status,
            student_profiles (
              student_id,
              first_name,
              middle_name,
              last_name,
              gender
            )
          ''')
          .eq('subject_offering_id', subjectOfferingId)
          .ilike('status', 'enrolled');

      final recordsData = await _client
          .from('attendance_records')
          .select('id, student_id, subject_offering_id, attendance_date, status, remarks, recorded_by, created_at')
          .eq('subject_offering_id', subjectOfferingId)
          .eq('attendance_date', dateStr);

      final studentsList = (enrollments as List? ?? []).map((e) {
        final p = e['student_profiles'] as Map<String, dynamic>?;
        return AttendanceRosterStudent(
          studentId: e['student_id']?.toString() ?? '',
          firstName: p?['first_name']?.toString() ?? '',
          middleName: p?['middle_name']?.toString(),
          lastName: p?['last_name']?.toString() ?? '',
          gender: p?['gender']?.toString() ?? 'unspecified',
        );
      }).where((s) => s.studentId.isNotEmpty).toList();

      final recordsList = (recordsData as List? ?? []).map((r) {
        AttendanceStatus status;
        switch (r['status']?.toString().toLowerCase()) {
          case 'present':
            status = AttendanceStatus.present;
            break;
          case 'absent':
            status = AttendanceStatus.absent;
            break;
          case 'late':
            status = AttendanceStatus.late;
            break;
          case 'excused':
            status = AttendanceStatus.excused;
            break;
          default:
            status = AttendanceStatus.present;
        }

        return AttendanceWorkspaceRecord(
          id: r['id']?.toString(),
          studentId: r['student_id']?.toString() ?? '',
          subjectOfferingId: r['subject_offering_id']?.toString() ?? '',
          attendanceDate: DateTime.tryParse(r['attendance_date']?.toString() ?? '') ?? date,
          status: status,
          source: AttendanceSource.manual,
          remarks: r['remarks']?.toString(),
          recordedBy: r['recorded_by']?.toString(),
          createdAt: DateTime.tryParse(r['created_at']?.toString() ?? ''),
        );
      }).toList();

      // Cache to local storage
      if (studentsList.isNotEmpty) {
        await LocalStorageService.saveAttendanceRoster(
          subjectOfferingId,
          studentsList.map((s) => s.toJson()).toList(),
        );
      }
      await LocalStorageService.saveAttendanceRecords(
        subjectOfferingId,
        dateStr,
        recordsList.map((r) => r.toJson()).toList(),
      );

      return AttendanceRosterResult(
        students: studentsList,
        records: recordsList,
      );
    } catch (e) {
      debugPrint('Direct attendance query error (falling back to cache): $e');
      final cachedStudentsRaw = LocalStorageService.getAttendanceRoster(subjectOfferingId);
      final cachedRecordsRaw = LocalStorageService.getAttendanceRecords(subjectOfferingId, dateStr);

      final cachedStudents = cachedStudentsRaw
          .map((m) => AttendanceRosterStudent.fromJson(m))
          .toList();
      final cachedRecords = cachedRecordsRaw
          .map((m) => AttendanceWorkspaceRecord.fromJson(m))
          .toList();

      return AttendanceRosterResult(
        students: cachedStudents,
        records: cachedRecords,
      );
    }
  }

  @override
  Future<void> saveAttendanceBatch({
    required String subjectOfferingId,
    required DateTime date,
    required List<AttendanceWorkspaceRecord> records,
  }) async {
    final dateStr = _formatDate(date);
    final user = firebase_auth.FirebaseAuth.instance.currentUser;

    // 1. Immediately persist to LocalStorage
    await LocalStorageService.saveAttendanceRecords(
      subjectOfferingId,
      dateStr,
      records.map((r) => r.toJson()).toList(),
    );

    // 2. Pure Dart Supabase Direct Save
    try {
      if (records.isNotEmpty) {
        // Since we might not have a composite unique constraint explicitly setup yet,
        // we can safely delete existing records for these students on this date and re-insert.
        final studentIds = records.map((r) => r.studentId).toList();
        
        await _client
            .from('attendance_records')
            .delete()
            .eq('subject_offering_id', subjectOfferingId)
            .eq('attendance_date', dateStr)
            .inFilter('student_id', studentIds);

        final rowsToInsert = records.map((r) => {
          'student_id': r.studentId,
          'subject_offering_id': subjectOfferingId,
          'attendance_date': dateStr,
          'status': r.status.name,
          'remarks': r.remarks,
          'recorded_by': user?.uid,
        }).toList();

        await _client.from('attendance_records').insert(rowsToInsert);
      }
    } catch (e) {
      debugPrint('Pure Dart attendance save offline fallback, queuing: $e');
      await LocalStorageService.enqueueOfflineAttendance(
        subjectOfferingId: subjectOfferingId,
        date: dateStr,
        records: records.map((r) => r.toJson()).toList(),
      );
    }
  }

  @override
  Future<AttendancePage<AttendanceWorkspaceRecord>> getAttendanceHistory(
    AttendanceHistoryFilter filter,
  ) async {
    try {
      final startStr = _formatDate(filter.dateRange.startDate);
      final endStr = _formatDate(filter.dateRange.endDate);

      final rows = await _client
          .from('attendance_records')
          .select('id, student_id, subject_offering_id, attendance_date, status, remarks, recorded_by, created_at')
          .eq('subject_offering_id', filter.subjectOfferingId)
          .gte('attendance_date', startStr)
          .lte('attendance_date', endStr)
          .order('attendance_date', ascending: false)
          .order('id', ascending: false)
          .range(filter.offset, filter.offset + filter.pageSize - 1);

      final recordList = (rows as List? ?? []).map((r) {
        return AttendanceWorkspaceRecord.fromJson(r as Map<String, dynamic>);
      }).toList();

      return AttendancePage<AttendanceWorkspaceRecord>(
        rows: recordList,
        nextOffset: filter.offset + recordList.length,
        hasMore: recordList.length == filter.pageSize,
      );
    } catch (e) {
      debugPrint('Direct attendance history query notice: $e');
      return AttendancePage<AttendanceWorkspaceRecord>(
        rows: [],
        nextOffset: filter.offset,
        hasMore: false,
      );
    }
  }

  @override
  Future<AttendanceAnalyticsSummary> getAttendanceAnalytics({
    required String subjectOfferingId,
    required AttendanceDateRange dateRange,
  }) async {
    try {
      final startStr = _formatDate(dateRange.startDate);
      final endStr = _formatDate(dateRange.endDate);

      final rows = await _client
          .from('attendance_records')
          .select('id, student_id, subject_offering_id, attendance_date, status, remarks')
          .eq('subject_offering_id', subjectOfferingId)
          .gte('attendance_date', startStr)
          .lte('attendance_date', endStr);

      final records = (rows as List? ?? []);
      int present = 0;
      int late = 0;
      int absent = 0;
      int excused = 0;
      final studentAbsenceCounts = <String, int>{};

      for (final r in records) {
        final status = r['status']?.toString().toLowerCase();
        final sId = r['student_id']?.toString() ?? '';
        if (status == 'present') {
          present++;
        } else if (status == 'late') late++;
        else if (status == 'absent') {
          absent++;
          studentAbsenceCounts[sId] = (studentAbsenceCounts[sId] ?? 0) + 1;
        } else if (status == 'excused') excused++;
      }

      final totalAccounted = present + late + absent;
      final rate = totalAccounted > 0 ? ((present + late) / totalAccounted) * 100 : null;
      final warningCount = studentAbsenceCounts.values.where((c) => c >= 3).length;

      final dateGroups = <String, List<Map<String, dynamic>>>{};
      for (final r in records) {
        final d = r['attendance_date']?.toString() ?? '';
        if (d.isNotEmpty) {
          (dateGroups[d] ??= []).add(r);
        }
      }
      final sortedDates = dateGroups.keys.toList()..sort();
      final trendPoints = <AttendanceTrendPoint>[];
      for (final d in sortedDates) {
        final dayRecs = dateGroups[d]!;
        int dPres = 0;
        int dAbs = 0;
        for (final dr in dayRecs) {
          final st = dr['status']?.toString().toLowerCase();
          if (st == 'present' || st == 'late') {
            dPres++;
          } else if (st == 'absent' || st == 'excused') {
            dAbs++;
          }
        }
        final parsed = DateTime.tryParse(d);
        final label = parsed != null ? '${parsed.month}/${parsed.day}' : d;
        trendPoints.add(
          AttendanceTrendPoint(
            bucketStart: parsed,
            periodLabel: label,
            presentCount: dPres,
            absentOrExcusedCount: dAbs,
          ),
        );
      }

      return AttendanceAnalyticsSummary(
        presenceRate: rate,
        absencesAndExcuses: absent + excused,
        warningCount: warningCount,
        presentCount: present,
        lateCount: late,
        absentCount: absent,
        excusedCount: excused,
        trendPoints: trendPoints,
        atRiskStudents: [],
      );
    } catch (e) {
      debugPrint('Direct attendance analytics notice: $e');
      return AttendanceAnalyticsSummary(
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
    }
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
    await _client.from('attendance_records').update({
      'status': newStatus.name,
      'remarks': reason.trim(),
    }).eq('id', recordId);
  }

  // =========================================================================
  // Student Self-Service Operations (100% Pure Dart)
  // =========================================================================

  @override
  Future<AttendanceStudentSummary> getMyAttendanceSummary() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? '';
    if (user == null) {
      return AttendanceStudentSummary(
        studentId: uid,
        presentCount: 0,
        totalDays: 0,
        presenceRate: 100.0,
      );
    }

    try {
      final rows = await _client
          .from('attendance_records')
          .select('status')
          .eq('student_id', user.uid);

      int present = 0, absent = 0, late = 0, excused = 0;
      for (final r in rows as List? ?? []) {
        final s = r['status']?.toString().toLowerCase();
        if (s == 'present') {
          present++;
        } else if (s == 'absent') absent++;
        else if (s == 'late') late++;
        else if (s == 'excused') excused++;
      }

      final total = present + absent + late + excused;
      final rate = total > 0 ? ((present + late) / total) * 100.0 : 100.0;

      return AttendanceStudentSummary(
        studentId: uid,
        presentCount: present,
        totalDays: total,
        presenceRate: rate,
      );
    } catch (_) {
      return AttendanceStudentSummary(
        studentId: uid,
        presentCount: 0,
        totalDays: 0,
        presenceRate: 100.0,
      );
    }
  }

  @override
  Future<AttendancePage<AttendanceRecord>> getMyAttendancePage({
    required int offset,
    int pageSize = 20,
  }) async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      return AttendancePage<AttendanceRecord>(
        rows: [],
        nextOffset: offset,
        hasMore: false,
      );
    }

    try {
      final rows = await _client
          .from('attendance_records')
          .select('''
            id, student_id, attendance_date, status, remarks,
            subject_offerings (
              subjects ( subject_name )
            )
          ''')
          .eq('student_id', user.uid)
          .order('attendance_date', ascending: false)
          .range(offset, offset + pageSize - 1);

      final recordList = (rows as List? ?? []).map<AttendanceRecord>((row) {
        final subMap = row['subject_offerings'] as Map<String, dynamic>?;
        final subject =
            (subMap?['subjects'] as Map<String, dynamic>?)?['subject_name'] ??
                'Class';

        AttendanceStatus status;
        switch (row['status']?.toString().toLowerCase()) {
          case 'present':
            status = AttendanceStatus.present;
            break;
          case 'absent':
            status = AttendanceStatus.absent;
            break;
          case 'late':
            status = AttendanceStatus.late;
            break;
          case 'excused':
            status = AttendanceStatus.excused;
            break;
          default:
            status = AttendanceStatus.absent;
        }

        return AttendanceRecord(
          id: row['id']?.toString() ?? '',
          studentId: row['student_id']?.toString() ?? '',
          date: DateTime.tryParse(row['attendance_date']?.toString() ?? '') ??
              DateTime.now(),
          status: status,
          timeIn: 'N/A',
          timeOut: 'N/A',
          remarks: row['remarks']?.toString(),
          method: subject,
        );
      }).toList();

      return AttendancePage<AttendanceRecord>(
        rows: recordList,
        nextOffset: offset + recordList.length,
        hasMore: recordList.length == pageSize,
      );
    } catch (_) {
      return AttendancePage<AttendanceRecord>(
        rows: [],
        nextOffset: offset,
        hasMore: false,
      );
    }
  }

  // =========================================================================
  // Legacy Methods
  // =========================================================================

  @override
  Future<List<AttendanceRecord>> getAttendanceForStudent(String studentId) async {
    final response = await _client
        .from('attendance_records')
        .select('''
          id, student_id, attendance_date, status, remarks,
          subject_offerings (
            subjects ( subject_name )
          )
        ''')
        .eq('student_id', studentId)
        .order('attendance_date', ascending: false);

    return (response as List).map((row) {
      final subMap = row['subject_offerings'] as Map<String, dynamic>?;
      final subject =
          (subMap?['subjects'] as Map<String, dynamic>?)?['subject_name'] ??
              'General';

      AttendanceStatus status;
      switch (row['status']?.toString().toLowerCase()) {
        case 'present':
          status = AttendanceStatus.present;
          break;
        case 'absent':
          status = AttendanceStatus.absent;
          break;
        case 'late':
          status = AttendanceStatus.late;
          break;
        case 'excused':
          status = AttendanceStatus.excused;
          break;
        default:
          status = AttendanceStatus.present;
      }

      return AttendanceRecord(
        id: row['id']?.toString() ?? '',
        studentId: row['student_id']?.toString() ?? '',
        date: DateTime.tryParse(row['attendance_date']?.toString() ?? '') ??
            DateTime.now(),
        status: status,
        timeIn: 'N/A',
        timeOut: 'N/A',
        remarks: row['remarks']?.toString(),
        method: subject,
      );
    }).toList();
  }

  Future<void> markAttendance(AttendanceRecord record) async {
    await _client.from('attendance_records').insert({
      'student_id': record.studentId,
      'attendance_date': _formatDate(record.date),
      'status': record.status.name,
      'remarks': record.remarks,
    });
  }

  @override
  Future<List<AttendanceRecord>> getAllAttendanceRecords() async {
    try {
      final response = await _client
          .from('attendance_records')
          .select('''
            id, student_id, attendance_date, status, remarks,
            subject_offerings (
              subjects ( subject_name )
            )
          ''')
          .order('attendance_date', ascending: false);

      return (response as List).map((row) {
        final subMap = row['subject_offerings'] as Map<String, dynamic>?;
        final subject =
            (subMap?['subjects'] as Map<String, dynamic>?)?['subject_name'] ??
                'General';

        AttendanceStatus status;
        switch (row['status']?.toString().toLowerCase()) {
          case 'present':
            status = AttendanceStatus.present;
            break;
          case 'absent':
            status = AttendanceStatus.absent;
            break;
          case 'late':
            status = AttendanceStatus.late;
            break;
          case 'excused':
            status = AttendanceStatus.excused;
            break;
          default:
            status = AttendanceStatus.present;
        }

        return AttendanceRecord(
          id: row['id']?.toString() ?? '',
          studentId: row['student_id']?.toString() ?? '',
          date: DateTime.tryParse(row['attendance_date']?.toString() ?? '') ??
              DateTime.now(),
          status: status,
          timeIn: 'N/A',
          timeOut: 'N/A',
          remarks: row['remarks']?.toString(),
          method: subject,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> recordAttendance({
    required String studentId,
    required AttendanceStatus status,
  }) async {
    final now = DateTime.now();
    await _client.from('attendance_records').insert({
      'student_id': studentId,
      'attendance_date': _formatDate(now),
      'status': status.name,
    });
  }

  @override
  Future<void> toggleOfflineSync() async {}

  @override
  SyncStatus getSyncStatus() => SyncStatus.online;
}
