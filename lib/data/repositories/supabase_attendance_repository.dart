import 'dart:async';
import 'dart:convert';

import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/data/datasources/local/app_database.dart';
import 'package:class_realm/data/repositories/attendance_repository.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/attendance_workspace_models.dart';
import 'package:drift/drift.dart' show Value;
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAttendanceRepository implements AttendanceRepository {
  final SupabaseClient? _injectedClient;
  SyncStatus _syncStatus = SyncStatus.online;

  SupabaseAttendanceRepository({SupabaseClient? client})
      : _injectedClient = client;

  SupabaseClient get _client => _injectedClient ?? Supabase.instance.client;

  static final SupabaseAttendanceRepository instance =
      SupabaseAttendanceRepository();

  // =========================================================================
  // Formatting, Normalization & Fault-Tolerant Schema/Network Helpers
  // =========================================================================

  static String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String? _currentUserId() {
    try {
      final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid.trim();
      if (uid != null && uid.isNotEmpty) return uid;
    } catch (_) {}
    final cached = LocalStorageService.getCachedUser()?.id.trim();
    if (cached != null && cached.isNotEmpty) return cached;
    return null;
  }

  static String _normalizeRfidUid(String raw) {
    return raw.trim().toUpperCase();
  }

  static String _hexOnly(String raw) {
    return raw.toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');
  }

  /// Formats DB `time` ('07:42:15', '13:05:00') or 12h string into '07:42 AM' / '01:05 PM'.
  static String? _formatTimeDisplayOrNull(Object? raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty || text == '—' || text.toUpperCase() == 'N/A') {
      return null;
    }

    // Already formatted with AM/PM
    final amPmMatch = RegExp(
      r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (amPmMatch != null) {
      int hour = int.tryParse(amPmMatch.group(1)!) ?? 0;
      final minute = amPmMatch.group(2)!;
      final period = amPmMatch.group(3)!.toUpperCase();
      if (hour == 0) hour = 12;
      if (hour > 12) hour = hour % 12;
      return '${hour.toString().padLeft(2, '0')}:$minute $period';
    }

    // 24-hour HH:mm or HH:mm:ss(.sss)
    final parts = text.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60) {
        final period = h >= 12 ? 'PM' : 'AM';
        int displayHour = h % 12;
        if (displayHour == 0) displayHour = 12;
        return '${displayHour.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
      }
    }
    return text;
  }

  static String _formatTimeDisplay(Object? raw) {
    return _formatTimeDisplayOrNull(raw) ?? '—';
  }

  /// Converts display time ('07:42 AM' or '07:42:15') to Postgres `time` ('07:42:00'), or null.
  static String? _normalizeDbTime(String? raw) {
    if (raw == null) return null;
    final text = raw.trim();
    if (text.isEmpty || text == '—' || text.toUpperCase() == 'N/A') {
      return null;
    }

    final amPmMatch = RegExp(
      r'^(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (amPmMatch != null) {
      int h = int.tryParse(amPmMatch.group(1)!) ?? 0;
      final m = int.tryParse(amPmMatch.group(2)!) ?? 0;
      final s = int.tryParse(amPmMatch.group(3) ?? '0') ?? 0;
      final period = amPmMatch.group(4)!.toUpperCase();
      if (period == 'PM' && h < 12) h += 12;
      if (period == 'AM' && h == 12) h = 0;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }

    final time24Match = RegExp(
      r'^(\d{1,2}):(\d{2})(?::(\d{2}))?',
    ).firstMatch(text);
    if (time24Match != null) {
      final h = int.tryParse(time24Match.group(1)!) ?? 0;
      final m = int.tryParse(time24Match.group(2)!) ?? 0;
      final s = int.tryParse(time24Match.group(3) ?? '0') ?? 0;
      if (h >= 0 && h < 24 && m >= 0 && m < 60 && s >= 0 && s < 60) {
        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
      }
    }
    return null;
  }

  static int? _parseTimeToMinutesSinceMidnight(String? raw) {
    final normalized = _normalizeDbTime(raw);
    if (normalized == null) return null;
    final parts = normalized.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  static int? _parseTimeToSecondsSinceMidnight(String? raw) {
    final normalized = _normalizeDbTime(raw);
    if (normalized == null) return null;
    final parts = normalized.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final s = parts.length >= 3 ? (int.tryParse(parts[2]) ?? 0) : 0;
    return h * 3600 + m * 60 + s;
  }

  static String _formatMinutesAs12h(int totalMinutes) {
    int clamped = totalMinutes % (24 * 60);
    if (clamped < 0) clamped += 24 * 60;
    final h = clamped ~/ 60;
    final m = clamped % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    int dispH = h % 12;
    if (dispH == 0) dispH = 12;
    return '${dispH.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
  }

  static AttendanceSource _safeParseSource(Object? raw) {
    try {
      return _safeParseSource(raw?.toString());
    } catch (_) {
      final lower = (raw?.toString() ?? '').toLowerCase();
      if (lower.contains('rfid')) return AttendanceSource.rfid;
      if (lower.contains('auto') || lower.contains('system')) {
        return AttendanceSource.system;
      }
      return AttendanceSource.manual;
    }
  }

  static AttendanceStatus _parseAttendanceStatus(
    Object? raw, {
    AttendanceStatus fallback = AttendanceStatus.present,
  }) {
    final val = raw?.toString().trim().toLowerCase();
    switch (val) {
      case 'present':
        return AttendanceStatus.present;
      case 'late':
        return AttendanceStatus.late;
      case 'absent':
        return AttendanceStatus.absent;
      case 'excused':
        return AttendanceStatus.excused;
      default:
        return fallback;
    }
  }

  static bool _isMissingSchemaObject(Object error) {
    if (error is PostgrestException) {
      final code = (error.code ?? '').toUpperCase();
      final msg = error.message.toLowerCase();
      if (code == '42703' || // undefined_column
          code == '42P01' || // undefined_table
          code == '42883' || // undefined_function
          code == 'PGRST202' || // function not found in schema cache
          code == 'PGRST204' || // column not found in schema cache
          code == 'PGRST205') { // table not found in schema cache
        return true;
      }
      if (msg.contains('does not exist') ||
          msg.contains('schema cache') ||
          msg.contains('could not find the')) {
        return true;
      }
    }
    final text = error.toString().toLowerCase();
    return text.contains('42703') ||
        text.contains('42p01') ||
        text.contains('42883') ||
        text.contains('pgrst202') ||
        text.contains('pgrst204') ||
        text.contains('pgrst205') ||
        (text.contains('column') && text.contains('does not exist')) ||
        (text.contains('relation') && text.contains('does not exist')) ||
        (text.contains('function') && text.contains('does not exist'));
  }

  static bool _isMissingConflictConstraint(Object error) {
    if (error is PostgrestException) {
      final code = (error.code ?? '').toUpperCase();
      final msg = error.message.toLowerCase();
      if (code == '42P10' ||
          msg.contains('no unique or exclusion constraint')) {
        return true;
      }
    }
    final text = error.toString().toLowerCase();
    return text.contains('42p10') ||
        text.contains('no unique or exclusion constraint');
  }

  static bool _isNetworkError(Object error) {
    if (error is TimeoutException || error is AuthRetryableFetchException) {
      return true;
    }
    final typeName = error.runtimeType.toString().toLowerCase();
    if (typeName.contains('socketexception') ||
        typeName.contains('clientexception') ||
        typeName.contains('handshakeexception')) {
      return true;
    }
    final text = error.toString().toLowerCase();
    return text.contains('socketexception') ||
        text.contains('clientexception') ||
        text.contains('failed host lookup') ||
        text.contains('failed to fetch') ||
        text.contains('xmlhttprequest error') ||
        text.contains('network is unreachable') ||
        text.contains('connection refused') ||
        text.contains('connection reset') ||
        text.contains('connection closed') ||
        text.contains('software caused connection abort') ||
        text.contains('timed out');
  }

  static Map<String, String> _readLocalRfidOverrides() {
    final raw = LocalStorageService.getJson('local_student_rfid_map');
    if (raw is Map) {
      final map = <String, String>{};
      raw.forEach((k, v) {
        final key = k?.toString() ?? '';
        final val = v?.toString().trim() ?? '';
        if (key.isNotEmpty && val.isNotEmpty) {
          map[key] = val.toUpperCase();
        }
      });
      return map;
    }
    return <String, String>{};
  }

  static Future<void> _writeLocalRfidOverride(
    String studentId,
    String? rfidUid, {
    String? previousHolderId,
  }) async {
    final map = Map<String, String>.from(_readLocalRfidOverrides());
    if (previousHolderId != null && previousHolderId.isNotEmpty) {
      map.remove(previousHolderId);
    }
    if (rfidUid != null && rfidUid.trim().isNotEmpty) {
      final norm = _normalizeRfidUid(rfidUid);
      map.removeWhere(
        (key, val) =>
            key != studentId &&
            (val.toUpperCase() == norm ||
                (_hexOnly(norm).isNotEmpty && _hexOnly(val) == _hexOnly(norm))),
      );
      map[studentId] = norm;
    } else {
      map.remove(studentId);
    }
    await LocalStorageService.saveJson('local_student_rfid_map', map);
  }

  static void _invalidateAttendanceCaches() {
    AppDataCache.instance.invalidatePrefix('attendance_');
    AppDataCache.instance.invalidatePrefix('my_attendance_');
    AppDataCache.instance.invalidatePrefix('student_attendance_');
  }

  static void _sortRosterAlphabetically(List<AttendanceRosterStudent> list) {
    list.sort((a, b) {
      final lastCmp = a.lastName.trim().toLowerCase().compareTo(
            b.lastName.trim().toLowerCase(),
          );
      if (lastCmp != 0) return lastCmp;
      final firstCmp = a.firstName.trim().toLowerCase().compareTo(
            b.firstName.trim().toLowerCase(),
          );
      if (firstCmp != 0) return firstCmp;
      return (a.middleName ?? '').trim().toLowerCase().compareTo(
            (b.middleName ?? '').trim().toLowerCase(),
          );
    });
  }

  // =========================================================================
  // Teacher Attendance Workspace Operations
  // =========================================================================

  @override
  Future<AttendanceRosterResult> getAttendanceRosterAndDateRecords({
    required String subjectOfferingId,
    required DateTime date,
  }) async {
    final dateStr = _formatDate(date);
    final cacheKey = 'attendance_workspace_${subjectOfferingId}_$dateStr';

    final memCached = AppDataCache.instance.get<AttendanceRosterResult>(cacheKey);
    if (memCached != null &&
        AppDataCache.instance.isFresh(
          cacheKey,
          ttl: const Duration(seconds: 45),
        )) {
      return memCached;
    }

    try {
      bool cloudHasRfidColumn = true;
      List<dynamic> enrollments;
      try {
        enrollments = await _client
            .from('student_enrollments')
            .select('''
              id,
              student_id,
              status,
              student_profiles (
                student_id,
                lrn,
                rfid_uid,
                first_name,
                middle_name,
                last_name,
                gender
              )
            ''')
            .eq('subject_offering_id', subjectOfferingId)
            .ilike('status', 'enrolled');
      } catch (err) {
        if (_isMissingSchemaObject(err)) {
          cloudHasRfidColumn = false;
          enrollments = await _client
              .from('student_enrollments')
              .select('''
                id,
                student_id,
                status,
                student_profiles (
                  student_id,
                  lrn,
                  first_name,
                  middle_name,
                  last_name,
                  gender
                )
              ''')
              .eq('subject_offering_id', subjectOfferingId)
              .ilike('status', 'enrolled');
        } else {
          rethrow;
        }
      }

      List<dynamic> recordsData;
      try {
        recordsData = await _client
            .from('attendance_records')
            .select(
              'id, student_id, subject_offering_id, attendance_date, status, recording_method, time_in, device_id, remarks, recorded_by, created_at',
            )
            .eq('subject_offering_id', subjectOfferingId)
            .eq('attendance_date', dateStr);
      } catch (err) {
        if (_isMissingSchemaObject(err)) {
          recordsData = await _client
              .from('attendance_records')
              .select(
                'id, student_id, subject_offering_id, attendance_date, status, remarks, recorded_by, created_at',
              )
              .eq('subject_offering_id', subjectOfferingId)
              .eq('attendance_date', dateStr);
        } else {
          rethrow;
        }
      }

      final localRfidFallback =
          cloudHasRfidColumn ? const <String, String>{} : _readLocalRfidOverrides();

      final enrollmentCompanions = <LocalEnrollmentsCompanion>[];
      final studentCompanions = <LocalStudentsCompanion>[];

      final studentsList = enrollments.map((e) {
        final p = e['student_profiles'] as Map<String, dynamic>?;
        final studentId =
            p?['student_id']?.toString() ?? e['student_id']?.toString() ?? '';
        final lrn = p?['lrn']?.toString();
        final rawRfid = p?['rfid_uid']?.toString().trim();
        final resolvedRfid = (rawRfid != null && rawRfid.isNotEmpty)
            ? rawRfid.toUpperCase()
            : localRfidFallback[studentId];
        final firstName = p?['first_name']?.toString() ?? '';
        final middleName = p?['middle_name']?.toString();
        final lastName = p?['last_name']?.toString() ?? '';
        final gender =
            (p?['gender']?.toString() ?? 'unspecified').toLowerCase();

        final enrollmentId = e['id']?.toString() ?? '';
        if (studentId.isNotEmpty) {
          studentCompanions.add(
            LocalStudentsCompanion.insert(
              studentId: studentId,
              lrn: Value(lrn),
              rfidUid: cloudHasRfidColumn
                  ? Value(resolvedRfid)
                  : (resolvedRfid != null
                        ? Value(resolvedRfid)
                        : const Value.absent()),
              firstName: firstName,
              middleName: Value(middleName),
              lastName: lastName,
              gender: Value(gender),
            ),
          );
          if (enrollmentId.isNotEmpty) {
            enrollmentCompanions.add(
              LocalEnrollmentsCompanion.insert(
                id: enrollmentId,
                studentId: studentId,
                subjectOfferingId: subjectOfferingId,
                status: Value(e['status']?.toString() ?? 'enrolled'),
              ),
            );
          }
        }

        return AttendanceRosterStudent(
          studentId: studentId,
          lrn: lrn,
          rfidUid: resolvedRfid,
          firstName: firstName,
          middleName: middleName,
          lastName: lastName,
          gender: gender,
        );
      }).where((s) => s.studentId.isNotEmpty).toList();

      _sortRosterAlphabetically(studentsList);

      final localRecordCompanions = <LocalAttendanceRecordsCompanion>[];
      final recordsList = recordsData.map((r) {
        final idStr = r['id']?.toString();
        final studentId = r['student_id']?.toString() ?? '';
        final status = _parseAttendanceStatus(r['status']);
        final source = _safeParseSource(
          r['recording_method']?.toString() ?? r['source']?.toString(),
        );
        final timeInDisplay = _formatTimeDisplayOrNull(r['time_in']);
        final deviceId = r['device_id']?.toString();
        final remarks = r['remarks']?.toString();
        final recordedBy = r['recorded_by']?.toString();

        if (studentId.isNotEmpty) {
          localRecordCompanions.add(
            LocalAttendanceRecordsCompanion.insert(
              id: idStr ?? '${studentId}_${subjectOfferingId}_$dateStr',
              studentId: studentId,
              subjectOfferingId: subjectOfferingId,
              attendanceDate: dateStr,
              status: status.name,
              recordingMethod: Value(source.toDbString()),
              timeIn: Value(timeInDisplay),
              deviceId: Value(deviceId),
              remarks: Value(remarks),
              source: Value(source.name),
              recordedBy: Value(recordedBy),
              syncStatus: const Value('synced'),
            ),
          );
        }

        return AttendanceWorkspaceRecord(
          id: idStr,
          studentId: studentId,
          subjectOfferingId:
              r['subject_offering_id']?.toString() ?? subjectOfferingId,
          attendanceDate:
              DateTime.tryParse(r['attendance_date']?.toString() ?? '') ?? date,
          status: status,
          source: source,
          remarks: remarks,
          recordedBy: recordedBy,
          timeIn: timeInDisplay,
          deviceId: deviceId,
          createdAt: DateTime.tryParse(r['created_at']?.toString() ?? ''),
        );
      }).toList();

      _syncStatus = SyncStatus.online;

      // Persist to LocalStorageService & Drift SQLite for 0ms instant load & offline resilience
      await LocalStorageService.saveAttendanceRoster(
        subjectOfferingId,
        studentsList.map((s) => s.toJson()).toList(),
      );
      await LocalStorageService.saveAttendanceRecords(
        subjectOfferingId,
        dateStr,
        recordsList.map((r) => r.toJson()).toList(),
      );

      if (!kIsWeb) {
        unawaited(() async {
          try {
            await AppDatabase.instance.upsertStudents(studentCompanions);
            await AppDatabase.instance.upsertEnrollments(enrollmentCompanions);
            await AppDatabase.instance.upsertAttendanceRecords(
              localRecordCompanions,
            );
          } catch (dbErr) {
            debugPrint('Drift attendance cache persistence notice: $dbErr');
          }
        }());
      }

      final result = AttendanceRosterResult(
        students: studentsList,
        records: recordsList,
      );
      AppDataCache.instance.set(cacheKey, result);
      return result;
    } catch (e) {
      debugPrint('Attendance query fallback to local cache: $e');
      if (_isNetworkError(e)) {
        _syncStatus = SyncStatus.offline;
      }

      // 1. Try Drift SQLite first on native platforms
      if (!kIsWeb) {
        try {
          final driftStudents = await AppDatabase.instance
              .getStudentsForOffering(subjectOfferingId);
          final driftRecords = await AppDatabase.instance
              .getAttendanceForOfferingAndDate(subjectOfferingId, dateStr);

          if (driftStudents.isNotEmpty) {
            final localRfidMap = _readLocalRfidOverrides();
            final mappedStudents = driftStudents
                .map(
                  (st) => AttendanceRosterStudent(
                    studentId: st.studentId,
                    lrn: st.lrn,
                    rfidUid: st.rfidUid ?? localRfidMap[st.studentId],
                    firstName: st.firstName,
                    middleName: st.middleName,
                    lastName: st.lastName,
                    gender: st.gender.toLowerCase(),
                  ),
                )
                .toList();
            _sortRosterAlphabetically(mappedStudents);

            final mappedRecords = driftRecords
                .map(
                  (rec) => AttendanceWorkspaceRecord(
                    id: rec.id,
                    studentId: rec.studentId,
                    subjectOfferingId: rec.subjectOfferingId,
                    attendanceDate: DateTime.tryParse(rec.attendanceDate) ?? date,
                    status: _parseAttendanceStatus(rec.status),
                    source: _safeParseSource(
                      rec.recordingMethod.isNotEmpty
                          ? rec.recordingMethod
                          : rec.source,
                    ),
                    remarks: rec.remarks,
                    recordedBy: rec.recordedBy,
                    timeIn: _formatTimeDisplayOrNull(rec.timeIn),
                    deviceId: rec.deviceId,
                  ),
                )
                .toList();

            return AttendanceRosterResult(
              students: mappedStudents,
              records: mappedRecords,
            );
          }
        } catch (driftErr) {
          debugPrint('Drift offline roster fallback notice: $driftErr');
        }
      }

      // 2. Fallback to LocalStorageService JSON cache
      final cachedStudentsRaw = LocalStorageService.getAttendanceRoster(
        subjectOfferingId,
      );
      final cachedRecordsRaw = LocalStorageService.getAttendanceRecords(
        subjectOfferingId,
        dateStr,
      );

      final localRfidMap = _readLocalRfidOverrides();
      final cachedStudents = cachedStudentsRaw.map((m) {
        final s = AttendanceRosterStudent.fromJson(m);
        if (!s.hasRfidAssigned && localRfidMap.containsKey(s.studentId)) {
          return s.copyWith(rfidUid: localRfidMap[s.studentId]);
        }
        return s;
      }).toList();
      _sortRosterAlphabetically(cachedStudents);

      final cachedRecords = cachedRecordsRaw
          .map((m) => AttendanceWorkspaceRecord.fromJson(m))
          .toList();

      return AttendanceRosterResult(
        students: cachedStudents,
        records: cachedRecords,
      );
    }
  }

  Future<void> _upsertAttendanceRows({
    required String subjectOfferingId,
    required String dateStr,
    required List<Map<String, dynamic>> fullRows,
  }) async {
    if (fullRows.isEmpty) return;

    List<Map<String, dynamic>> buildBaseRows() {
      return fullRows
          .map(
            (r) => <String, dynamic>{
              'student_id': r['student_id'],
              'subject_offering_id': r['subject_offering_id'],
              'attendance_date': r['attendance_date'],
              'status': r['status'],
              'remarks': r['remarks'],
              if (r['recorded_by'] != null) 'recorded_by': r['recorded_by'],
            },
          )
          .toList();
    }

    Future<void> fallbackDeleteAndInsert(List<Map<String, dynamic>> rows) async {
      final studentIds = rows
          .map((r) => r['student_id']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      if (studentIds.isNotEmpty) {
        await _client
            .from('attendance_records')
            .delete()
            .eq('subject_offering_id', subjectOfferingId)
            .eq('attendance_date', dateStr)
            .inFilter('student_id', studentIds);
      }
      await _client.from('attendance_records').insert(rows);
    }

    try {
      await _client.from('attendance_records').upsert(
            fullRows,
            onConflict: 'student_id,subject_offering_id,attendance_date',
          );
    } catch (err) {
      if (_isMissingConflictConstraint(err)) {
        try {
          await fallbackDeleteAndInsert(fullRows);
          return;
        } catch (innerErr) {
          if (_isMissingSchemaObject(innerErr)) {
            await fallbackDeleteAndInsert(buildBaseRows());
            return;
          }
          rethrow;
        }
      }

      if (_isMissingSchemaObject(err)) {
        final baseRows = buildBaseRows();
        try {
          await _client.from('attendance_records').upsert(
                baseRows,
                onConflict: 'student_id,subject_offering_id,attendance_date',
              );
        } catch (baseErr) {
          if (_isMissingConflictConstraint(baseErr)) {
            await fallbackDeleteAndInsert(baseRows);
          } else {
            rethrow;
          }
        }
        return;
      }

      rethrow;
    }
  }

  @override
  Future<void> saveAttendanceBatch({
    required String subjectOfferingId,
    required DateTime date,
    required List<AttendanceWorkspaceRecord> records,
    List<String>? deletedStudentIds,
  }) async {
    final dateStr = _formatDate(date);
    final uid = _currentUserId();
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final normalizedRecords = records.map((rec) {
      return rec.copyWith(
        subjectOfferingId: subjectOfferingId,
        attendanceDate: date,
        recordedBy: rec.recordedBy ?? uid,
        timeIn: _formatTimeDisplayOrNull(rec.timeIn),
      );
    }).toList();

    // 1. Immediately persist to LocalStorageService & invalidate SWR caches
    await LocalStorageService.saveAttendanceRecords(
      subjectOfferingId,
      dateStr,
      normalizedRecords.map((r) => r.toJson()).toList(),
    );
    _invalidateAttendanceCaches();

    // Delete any records for students who were cleared/unmarked by teacher
    if (deletedStudentIds != null && deletedStudentIds.isNotEmpty) {
      try {
        await _client
            .from('attendance_records')
            .delete()
            .eq('subject_offering_id', subjectOfferingId)
            .eq('attendance_date', dateStr)
            .inFilter('student_id', deletedStudentIds);
      } catch (err) {
        debugPrint('Failed to delete unmarked attendance records: $err');
      }
    }

    if (normalizedRecords.isEmpty) return;

    final fullRows = normalizedRecords.map((rec) {
      return <String, dynamic>{
        'student_id': rec.studentId,
        'subject_offering_id': subjectOfferingId,
        'attendance_date': dateStr,
        'status': rec.status.name,
        'recording_method': rec.source.toDbString(),
        'time_in': _normalizeDbTime(rec.timeIn),
        'device_id': rec.deviceId,
        'remarks': rec.remarks,
        if ((rec.recordedBy ?? uid) != null &&
            (rec.recordedBy ?? uid)!.isNotEmpty)
          'recorded_by': rec.recordedBy ?? uid,
        'updated_at': nowIso,
      };
    }).toList();

    try {
      await _upsertAttendanceRows(
        subjectOfferingId: subjectOfferingId,
        dateStr: dateStr,
        fullRows: fullRows,
      );

      _syncStatus = SyncStatus.online;
      unawaited(_checkAndTriggerAbsenceAlerts(subjectOfferingId, normalizedRecords));

      if (!kIsWeb) {
        try {
          final syncedCompanions = normalizedRecords.map((rec) {
            return LocalAttendanceRecordsCompanion.insert(
              id: rec.id ?? '${rec.studentId}_${subjectOfferingId}_$dateStr',
              studentId: rec.studentId,
              subjectOfferingId: subjectOfferingId,
              attendanceDate: dateStr,
              status: rec.status.name,
              recordingMethod: Value(rec.source.toDbString()),
              timeIn: Value(rec.timeIn),
              deviceId: Value(rec.deviceId),
              remarks: Value(rec.remarks),
              source: Value(rec.source.name),
              recordedBy: Value(rec.recordedBy ?? uid),
              syncStatus: const Value('synced'),
            );
          }).toList();
          await AppDatabase.instance.upsertAttendanceRecords(syncedCompanions);
        } catch (dbErr) {
          debugPrint('Drift synced batch save notice: $dbErr');
        }
      }
    } catch (e) {
      debugPrint('Attendance batch save offline fallback, queuing: $e');
      _syncStatus = SyncStatus.pendingSync;

      if (!kIsWeb) {
        try {
          final pendingCompanions = normalizedRecords.map((rec) {
            return LocalAttendanceRecordsCompanion.insert(
              id: rec.id ?? '${rec.studentId}_${subjectOfferingId}_$dateStr',
              studentId: rec.studentId,
              subjectOfferingId: subjectOfferingId,
              attendanceDate: dateStr,
              status: rec.status.name,
              recordingMethod: Value(rec.source.toDbString()),
              timeIn: Value(rec.timeIn),
              deviceId: Value(rec.deviceId),
              remarks: Value(rec.remarks),
              source: Value(rec.source.name),
              recordedBy: Value(rec.recordedBy ?? uid),
              syncStatus: const Value('pending'),
            );
          }).toList();
          await AppDatabase.instance.upsertAttendanceRecords(pendingCompanions);

          await AppDatabase.instance.enqueueOfflineAction(
            id: 'batch_save_${subjectOfferingId}_$dateStr',
            action: 'batch_save',
            targetTable: 'attendance_records',
            payloadJson: jsonEncode({
              'subject_offering_id': subjectOfferingId,
              'date': dateStr,
              'records': fullRows,
            }),
          );
        } catch (dbErr) {
          debugPrint('Drift offline batch enqueue notice: $dbErr');
        }
      }

      await LocalStorageService.enqueueOfflineAttendance(
        subjectOfferingId: subjectOfferingId,
        date: dateStr,
        records: normalizedRecords.map((r) => r.toJson()).toList(),
      );
    }
  }

  Future<void> _checkAndTriggerAbsenceAlerts(
    String subjectOfferingId,
    List<AttendanceWorkspaceRecord> records,
  ) async {
    final absentStudents = records
        .where((r) => r.status == AttendanceStatus.absent)
        .map((r) => r.studentId)
        .toSet();
    if (absentStudents.isEmpty) return;

    for (final studentId in absentStudents) {
      try {
        final rows = await _client
            .from('attendance_records')
            .select('id')
            .eq('student_id', studentId)
            .eq('subject_offering_id', subjectOfferingId)
            .eq('status', 'absent');
        final totalAbsences = (rows as List).length;

        if (totalAbsences == 3 || totalAbsences == 5 || totalAbsences >= 10) {
          final profileRes = await _client
              .from('student_profiles')
              .select('first_name, last_name')
              .eq('student_id', studentId)
              .maybeSingle();
          final sName = profileRes != null
              ? '${profileRes['last_name']}, ${profileRes['first_name']}'
              : 'Student';

          final String title;
          final String message;
          if (totalAbsences >= 10) {
            title = 'Critical Absence Warning (10 Absences)';
            message =
                '$sName has reached 10 absences. Student is at imminent risk of drop-out under DepEd SARDO rules. Immediate conference required.';
          } else if (totalAbsences == 5) {
            title = 'Attendance Alert (5 Absences)';
            message =
                '$sName has accumulated 5 absences. Parent-Teacher intervention required.';
          } else {
            title = 'Early Attendance Warning (3 Absences)';
            message =
                '$sName has reached 3 recorded absences. Please coordinate with the teacher.';
          }

          await _client.from('notifications').insert({
            'title': title,
            'message': message,
            'notification_type': 'attendance',
            'target_audience': 'students_parents',
            'is_archived': false,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          });
        }
      } catch (e) {
        debugPrint('Absence notification trigger notice: $e');
      }
    }
  }

  // =========================================================================
  // Schedule, Holiday & Cutoff Configuration (R3)
  // =========================================================================

  @override
  Future<AttendanceScheduleStatus> getScheduleAndCutoffStatus({
    required String subjectOfferingId,
    required DateTime date,
  }) async {
    final dateStr = _formatDate(date);
    final targetDow = date.weekday; // 1 = Monday ... 7 = Sunday

    bool hasPlottedScheduleAnyDay = false;
    bool isScheduledOnDate = false;
    String? startTime;
    String? endTime;
    String? room;

    // 1. Load plotted schedules for this subject offering
    try {
      final schedRows = await _client
          .from('teacher_schedule')
          .select('id, subject_offering_id, day_of_week, start_time, end_time, room, is_active')
          .eq('subject_offering_id', subjectOfferingId)
          .eq('is_active', true)
          .order('start_time', ascending: true);

      final list = (schedRows as List).cast<Map<String, dynamic>>();
      hasPlottedScheduleAnyDay = list.isNotEmpty;

      for (final row in list) {
        final dow = (row['day_of_week'] as num?)?.toInt();
        if (dow == targetDow) {
          isScheduledOnDate = true;
          startTime = row['start_time']?.toString();
          endTime = row['end_time']?.toString();
          room = row['room']?.toString();
          break;
        }
      }

      await LocalStorageService.saveJson(
        'attendance_schedules_$subjectOfferingId',
        list,
      );

      if (!kIsWeb && list.isNotEmpty) {
        unawaited(() async {
          try {
            final companions = list
                .map(
                  (r) => LocalSchedulesCompanion.insert(
                    id: r['id']?.toString() ??
                        '${subjectOfferingId}_${r['day_of_week']}_${r['start_time']}',
                    subjectOfferingId: subjectOfferingId,
                    teacherId: _currentUserId() ?? '',
                    dayOfWeek: (r['day_of_week'] ?? '').toString(),
                    startTime: r['start_time']?.toString() ?? '08:00:00',
                    endTime: r['end_time']?.toString() ?? '09:00:00',
                    room: Value(r['room']?.toString()),
                  ),
                )
                .toList();
            await AppDatabase.instance.upsertSchedules(companions);
          } catch (_) {}
        }());
      }
    } catch (e) {
      debugPrint('Schedule query fallback to local cache: $e');
      bool loadedFromDrift = false;
      if (!kIsWeb) {
        try {
          final localScheds = await AppDatabase.instance
              .getSchedulesForOffering(subjectOfferingId);
          if (localScheds.isNotEmpty) {
            loadedFromDrift = true;
            hasPlottedScheduleAnyDay = true;
            for (final s in localScheds) {
              final dow = int.tryParse(s.dayOfWeek);
              if (dow == targetDow ||
                  s.dayOfWeek.toLowerCase() ==
                      ScheduleModel.dayFromIndex(targetDow).toLowerCase()) {
                isScheduledOnDate = true;
                startTime = s.startTime;
                endTime = s.endTime;
                room = s.room;
                break;
              }
            }
          }
        } catch (_) {}
      }

      if (!loadedFromDrift) {
        final cachedScheds = LocalStorageService.getJson(
          'attendance_schedules_$subjectOfferingId',
        );
        if (cachedScheds is List && cachedScheds.isNotEmpty) {
          hasPlottedScheduleAnyDay = true;
          for (final item in cachedScheds) {
            if (item is Map) {
              final dow = (item['day_of_week'] as num?)?.toInt() ??
                  int.tryParse(item['day_of_week']?.toString() ?? '');
              if (dow == targetDow) {
                isScheduledOnDate = true;
                startTime = item['start_time']?.toString();
                endTime = item['end_time']?.toString();
                room = item['room']?.toString();
                break;
              }
            }
          }
        } else {
          // Unknown offline schedule: do not artificially lock teacher out
          hasPlottedScheduleAnyDay = false;
          isScheduledOnDate = true;
        }
      }
    }

    // 2. Check recognized school holiday on selected date
    bool isHoliday = false;
    String? holidayName;
    try {
      final holidayRow = await _client
          .from('school_holidays')
          .select('holiday_date, holiday_name, is_active')
          .eq('holiday_date', dateStr)
          .eq('is_active', true)
          .maybeSingle();

      if (holidayRow != null) {
        isHoliday = true;
        holidayName = holidayRow['holiday_name']?.toString();
        await LocalStorageService.saveJson('school_holiday_$dateStr', {
          'is_holiday': true,
          'holiday_name': holidayName,
        });
      } else {
        await LocalStorageService.saveJson('school_holiday_$dateStr', {
          'is_holiday': false,
        });
      }
    } catch (e) {
      if (!_isMissingSchemaObject(e)) {
        final cachedHoliday = LocalStorageService.getJson(
          'school_holiday_$dateStr',
        );
        if (cachedHoliday is Map && cachedHoliday['is_holiday'] == true) {
          isHoliday = true;
          holidayName = cachedHoliday['holiday_name']?.toString();
        }
      }
    }

    // 3. Load cutoff configuration (falling back to Drift / LocalStorage / defaults 15/15/45/60)
    AttendanceCutoffConfig cutoffConfig = AttendanceCutoffConfig(
      subjectOfferingId: subjectOfferingId,
    );

    try {
      final cutoffRow = await _client
          .from('attendance_cutoffs')
          .select(
            'subject_offering_id, present_start_mins_before, present_grace_mins, late_cutoff_mins, absent_cutoff_mins',
          )
          .eq('subject_offering_id', subjectOfferingId)
          .maybeSingle();

      if (cutoffRow != null) {
        cutoffConfig = AttendanceCutoffConfig.fromJson(cutoffRow);
        await LocalStorageService.saveJson(
          'attendance_cutoff_$subjectOfferingId',
          cutoffConfig.toJson(),
        );
        if (!kIsWeb) {
          unawaited(
            AppDatabase.instance.upsertCutoffConfig(
              LocalAttendanceCutoffsCompanion.insert(
                subjectOfferingId: subjectOfferingId,
                presentStartMinsBefore: Value(
                  cutoffConfig.presentStartMinsBefore,
                ),
                presentGraceMins: Value(cutoffConfig.presentGraceMins),
                lateCutoffMins: Value(cutoffConfig.lateCutoffMins),
                absentCutoffMins: Value(cutoffConfig.absentCutoffMins),
                updatedAt: Value(DateTime.now()),
              ),
            ),
          );
        }
      } else {
        cutoffConfig = await _loadLocalCutoffConfig(subjectOfferingId);
      }
    } catch (e) {
      cutoffConfig = await _loadLocalCutoffConfig(subjectOfferingId);
    }

    return AttendanceScheduleStatus(
      hasPlottedScheduleAnyDay: hasPlottedScheduleAnyDay,
      isScheduledOnDate: isScheduledOnDate,
      isHoliday: isHoliday,
      holidayName: holidayName,
      startTime: startTime,
      endTime: endTime,
      room: room,
      cutoffConfig: cutoffConfig,
    );
  }

  Future<AttendanceCutoffConfig> _loadLocalCutoffConfig(
    String subjectOfferingId,
  ) async {
    if (!kIsWeb) {
      try {
        final local = await AppDatabase.instance.getCutoffConfig(
          subjectOfferingId,
        );
        if (local != null) {
          return AttendanceCutoffConfig(
            subjectOfferingId: subjectOfferingId,
            presentStartMinsBefore: local.presentStartMinsBefore,
            presentGraceMins: local.presentGraceMins,
            lateCutoffMins: local.lateCutoffMins,
            absentCutoffMins: local.absentCutoffMins,
          );
        }
      } catch (_) {}
    }

    final raw = LocalStorageService.getJson(
      'attendance_cutoff_$subjectOfferingId',
    );
    if (raw is Map) {
      return AttendanceCutoffConfig.fromJson(Map<String, dynamic>.from(raw));
    }
    return AttendanceCutoffConfig(subjectOfferingId: subjectOfferingId);
  }

  @override
  Future<void> saveCutoffConfig(AttendanceCutoffConfig config) async {
    if (config.presentStartMinsBefore < 0 || config.presentGraceMins < 0) {
      throw ArgumentError('Cutoff minute thresholds must not be negative.');
    }
    if (config.presentGraceMins >= config.lateCutoffMins) {
      throw ArgumentError(
        'Present grace period must be strictly less than the Late cutoff.',
      );
    }
    if (config.lateCutoffMins > config.absentCutoffMins) {
      throw ArgumentError(
        'Late cutoff must be less than or equal to the Absent cutoff.',
      );
    }

    await LocalStorageService.saveJson(
      'attendance_cutoff_${config.subjectOfferingId}',
      config.toJson(),
    );

    if (!kIsWeb) {
      try {
        await AppDatabase.instance.upsertCutoffConfig(
          LocalAttendanceCutoffsCompanion.insert(
            subjectOfferingId: config.subjectOfferingId,
            presentStartMinsBefore: Value(config.presentStartMinsBefore),
            presentGraceMins: Value(config.presentGraceMins),
            lateCutoffMins: Value(config.lateCutoffMins),
            absentCutoffMins: Value(config.absentCutoffMins),
            updatedAt: Value(DateTime.now()),
          ),
        );
      } catch (dbErr) {
        debugPrint('Drift cutoff save notice: $dbErr');
      }
    }

    _invalidateAttendanceCaches();

    try {
      await _client.from('attendance_cutoffs').upsert(
        {
          'subject_offering_id': config.subjectOfferingId,
          'present_start_mins_before': config.presentStartMinsBefore,
          'present_grace_mins': config.presentGraceMins,
          'late_cutoff_mins': config.lateCutoffMins,
          'absent_cutoff_mins': config.absentCutoffMins,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'subject_offering_id',
      );
    } catch (e) {
      if (_isMissingSchemaObject(e)) {
        debugPrint(
          'attendance_cutoffs table not yet migrated on cloud; saved locally.',
        );
        return;
      }
      if (_isNetworkError(e)) {
        _syncStatus = SyncStatus.pendingSync;
        if (!kIsWeb) {
          try {
            await AppDatabase.instance.enqueueOfflineAction(
              id: 'cutoff_${config.subjectOfferingId}',
              action: 'save_cutoff_config',
              targetTable: 'attendance_cutoffs',
              payloadJson: jsonEncode(config.toJson()),
            );
          } catch (_) {}
        }
        return;
      }
      rethrow;
    }
  }

  // =========================================================================
  // RFID Card Management & Conflict Checking (R2)
  // =========================================================================

  @override
  Future<RfidCardConflictCheck> checkRfidUidConflict({
    required String rfidUid,
    String? excludeStudentId,
  }) async {
    final cleanUid = _normalizeRfidUid(rfidUid);
    if (cleanUid.isEmpty) {
      return const RfidCardConflictCheck(isTaken: false);
    }
    final cleanHex = _hexOnly(cleanUid);

    try {
      // Exact case-insensitive match first
      final directRows = await _client
          .from('student_profiles')
          .select('student_id, first_name, middle_name, last_name, lrn, rfid_uid')
          .ilike('rfid_uid', cleanUid);

      Map<String, dynamic>? conflictRow;
      for (final row in (directRows as List).cast<Map<String, dynamic>>()) {
        final sid = row['student_id']?.toString() ?? '';
        if (sid.isNotEmpty && sid != excludeStudentId) {
          conflictRow = row;
          break;
        }
      }

      // Secondary hex-normalized check (catches '04:A2:3B:5C' vs '04A23B5C')
      if (conflictRow == null && cleanHex.isNotEmpty) {
        final allAssigned = await _client
            .from('student_profiles')
            .select('student_id, first_name, middle_name, last_name, lrn, rfid_uid')
            .not('rfid_uid', 'is', null);
        for (final row in (allAssigned as List).cast<Map<String, dynamic>>()) {
          final sid = row['student_id']?.toString() ?? '';
          if (sid.isEmpty || sid == excludeStudentId) continue;
          final rowUid = row['rfid_uid']?.toString() ?? '';
          if (_hexOnly(rowUid) == cleanHex) {
            conflictRow = row;
            break;
          }
        }
      }

      if (conflictRow != null) {
        final ln = conflictRow['last_name']?.toString().trim() ?? '';
        final fn = conflictRow['first_name']?.toString().trim() ?? '';
        final formattedName = [
          if (ln.isNotEmpty) '$ln,',
          if (fn.isNotEmpty) fn,
        ].join(' ').trim();

        return RfidCardConflictCheck(
          isTaken: true,
          existingStudentId: conflictRow['student_id']?.toString(),
          existingStudentName:
              formattedName.isNotEmpty ? formattedName : conflictRow['student_id']?.toString(),
          existingLrn: conflictRow['lrn']?.toString(),
        );
      }

      return const RfidCardConflictCheck(isTaken: false);
    } catch (e) {
      debugPrint('RFID conflict check local fallback: $e');

      if (!kIsWeb) {
        try {
          final localMatch = await AppDatabase.instance.findStudentByRfid(
            cleanUid,
          );
          if (localMatch != null && localMatch.studentId != excludeStudentId) {
            return RfidCardConflictCheck(
              isTaken: true,
              existingStudentId: localMatch.studentId,
              existingStudentName:
                  '${localMatch.lastName}, ${localMatch.firstName}'.trim(),
              existingLrn: localMatch.lrn,
            );
          }
        } catch (_) {}
      }

      final localOverrides = _readLocalRfidOverrides();
      for (final entry in localOverrides.entries) {
        if (entry.key == excludeStudentId) continue;
        if (entry.value == cleanUid ||
            (cleanHex.isNotEmpty && _hexOnly(entry.value) == cleanHex)) {
          return RfidCardConflictCheck(
            isTaken: true,
            existingStudentId: entry.key,
          );
        }
      }

      return const RfidCardConflictCheck(isTaken: false);
    }
  }

  @override
  Future<void> assignStudentRfid({
    required String studentId,
    required String? rfidUid,
    bool forceReassign = false,
  }) async {
    final normalizedUid = (rfidUid == null || rfidUid.trim().isEmpty)
        ? null
        : _normalizeRfidUid(rfidUid);

    String? previousHolderId;
    if (normalizedUid != null) {
      final conflict = await checkRfidUidConflict(
        rfidUid: normalizedUid,
        excludeStudentId: studentId,
      );
      if (conflict.isTaken) {
        if (!forceReassign) {
          throw StateError(
            'RFID card $normalizedUid is already assigned to ${conflict.existingStudentName ?? "another student"}.',
          );
        }
        previousHolderId = conflict.existingStudentId;
      }
    }

    try {
      if (previousHolderId != null && previousHolderId.isNotEmpty) {
        await _client
            .from('student_profiles')
            .update({'rfid_uid': null})
            .eq('student_id', previousHolderId);
      } else if (normalizedUid != null) {
        // Also clear any case-variant holder if forceReassign was requested
        if (forceReassign) {
          await _client
              .from('student_profiles')
              .update({'rfid_uid': null})
              .ilike('rfid_uid', normalizedUid)
              .neq('student_id', studentId);
        }
      }

      await _client
          .from('student_profiles')
          .update({'rfid_uid': normalizedUid})
          .eq('student_id', studentId);
    } catch (e) {
      if (_isMissingSchemaObject(e)) {
        debugPrint(
          'rfid_uid column not yet migrated on cloud; storing RFID binding locally.',
        );
      } else if (_isNetworkError(e)) {
        _syncStatus = SyncStatus.pendingSync;
        if (!kIsWeb) {
          try {
            await AppDatabase.instance.enqueueOfflineAction(
              id: 'assign_rfid_$studentId',
              action: 'assign_student_rfid',
              targetTable: 'student_profiles',
              payloadJson: jsonEncode({
                'student_id': studentId,
                'rfid_uid': normalizedUid,
                'force_reassign': forceReassign,
              }),
            );
          } catch (_) {}
        }
      } else {
        rethrow;
      }
    }

    // Update local Drift & LocalStorage overrides immediately
    await _writeLocalRfidOverride(
      studentId,
      normalizedUid,
      previousHolderId: previousHolderId,
    );

    if (!kIsWeb) {
      try {
        if (previousHolderId != null && previousHolderId.isNotEmpty) {
          await AppDatabase.instance.updateStudentRfid(previousHolderId, null);
        }
        await AppDatabase.instance.updateStudentRfid(studentId, normalizedUid);
      } catch (dbErr) {
        debugPrint('Drift updateStudentRfid notice: $dbErr');
      }
    }

    AppDataCache.instance.invalidatePrefix('teacher_students_');
    _invalidateAttendanceCaches();
  }

  // =========================================================================
  // Atomic RFID Scan Execution & 3-Way Offline Conflict Engine (R4)
  // =========================================================================

  @override
  Future<RfidScanOutcome> recordRfidScan({
    required String rfidUid,
    required String subjectOfferingId,
    DateTime? scanTimestamp,
    String deviceId = 'USB_SCANNER',
  }) async {
    final cleanUid = _normalizeRfidUid(rfidUid);
    if (cleanUid.isEmpty) {
      return const RfidScanOutcome(
        success: false,
        code: 'INVALID_CARD_UID',
        message: 'Scanned RFID card UID is empty or invalid.',
      );
    }

    final effectiveTimestamp = scanTimestamp ?? DateTime.now();

    try {
      final rpcResult = await _client.rpc(
        'record_rfid_attendance',
        params: {
          'p_rfid_uid': cleanUid,
          'p_subject_offering_id': subjectOfferingId,
          'p_scan_timestamp': effectiveTimestamp.toUtc().toIso8601String(),
          'p_device_id': deviceId,
        },
      );

      final map = rpcResult is Map
          ? Map<String, dynamic>.from(rpcResult)
          : <String, dynamic>{};
      final outcome = RfidScanOutcome.fromJson(map);

      if (outcome.success &&
          outcome.studentId != null &&
          outcome.status != null) {
        await _persistScanOutcomeLocally(
          subjectOfferingId: subjectOfferingId,
          scanTimestamp: effectiveTimestamp,
          studentId: outcome.studentId!,
          status: outcome.status!,
          timeIn: outcome.timeIn ?? _formatTimeDisplay(effectiveTimestamp.toIso8601String().split('T').last),
          deviceId: deviceId,
          isSynced: true,
        );
      }

      _syncStatus = SyncStatus.online;
      _invalidateAttendanceCaches();
      return outcome;
    } catch (e) {
      if (_isMissingSchemaObject(e)) {
        debugPrint(
          'record_rfid_attendance RPC not yet deployed; using Dart online validation fallback.',
        );
        try {
          return await _recordRfidScanDartOnline(
            cleanUid: cleanUid,
            subjectOfferingId: subjectOfferingId,
            scanTimestamp: effectiveTimestamp,
            deviceId: deviceId,
          );
        } catch (fallbackErr) {
          if (_isNetworkError(fallbackErr)) {
            return _recordRfidScanOffline(
              cleanUid: cleanUid,
              subjectOfferingId: subjectOfferingId,
              scanTimestamp: effectiveTimestamp,
              deviceId: deviceId,
            );
          }
          rethrow;
        }
      }

      if (_isNetworkError(e)) {
        return _recordRfidScanOffline(
          cleanUid: cleanUid,
          subjectOfferingId: subjectOfferingId,
          scanTimestamp: effectiveTimestamp,
          deviceId: deviceId,
        );
      }

      rethrow;
    }
  }

  /// Equivalent server-consistent Dart execution when `003_attendance_overhaul.sql` RPC is not yet deployed.
  Future<RfidScanOutcome> _recordRfidScanDartOnline({
    required String cleanUid,
    required String subjectOfferingId,
    required DateTime scanTimestamp,
    required String deviceId,
  }) async {
    final manilaTime = scanTimestamp.toUtc().add(const Duration(hours: 8));
    final dateStr = _formatDate(manilaTime);
    final scanTime24 =
        '${manilaTime.hour.toString().padLeft(2, '0')}:${manilaTime.minute.toString().padLeft(2, '0')}:${manilaTime.second.toString().padLeft(2, '0')}';
    final scanTimeDisplay = _formatTimeDisplay(scanTime24);

    // 1. Schedule & Holiday & Cutoff check
    final schedStatus = await getScheduleAndCutoffStatus(
      subjectOfferingId: subjectOfferingId,
      date: manilaTime,
    );

    if (schedStatus.isHoliday) {
      return RfidScanOutcome(
        success: false,
        code: 'HOLIDAY_LOCKED',
        message: schedStatus.lockReason ??
            'Recognized school holiday. Attendance scans are disabled.',
      );
    }

    // 2. Lookup student by RFID UID
    String? studentId;
    String? studentName;
    try {
      final rows = await _client
          .from('student_profiles')
          .select('student_id, first_name, last_name, rfid_uid')
          .ilike('rfid_uid', cleanUid);
      if (rows.isNotEmpty) {
        final r = Map<String, dynamic>.from(rows.first as Map);
        studentId = r['student_id']?.toString();
        studentName = '${r['last_name'] ?? ''}, ${r['first_name'] ?? ''}'.trim();
      }
    } catch (err) {
      if (!_isMissingSchemaObject(err)) rethrow;
    }

    if (studentId == null || studentId.isEmpty) {
      final localOverrides = _readLocalRfidOverrides();
      for (final entry in localOverrides.entries) {
        if (entry.value == cleanUid ||
            (_hexOnly(cleanUid).isNotEmpty &&
                _hexOnly(entry.value) == _hexOnly(cleanUid))) {
          studentId = entry.key;
          break;
        }
      }
      if (studentId != null) {
        final p = await _client
            .from('student_profiles')
            .select('first_name, last_name')
            .eq('student_id', studentId)
            .maybeSingle();
        if (p != null) {
          studentName = '${p['last_name'] ?? ''}, ${p['first_name'] ?? ''}'.trim();
        }
      }
    }

    if (studentId == null || studentId.isEmpty) {
      return const RfidScanOutcome(
        success: false,
        code: 'UNREGISTERED_CARD',
        message: 'This RFID card UID is not registered to any student.',
      );
    }

    // 3. Verify enrollment in offering
    final enrollment = await _client
        .from('student_enrollments')
        .select('id, status')
        .eq('student_id', studentId)
        .eq('subject_offering_id', subjectOfferingId)
        .ilike('status', 'enrolled')
        .maybeSingle();

    if (enrollment == null) {
      return RfidScanOutcome(
        success: false,
        code: 'CROSS_SECTION_TAP',
        studentId: studentId,
        studentName: studentName,
        message: '${studentName ?? "Student"} is not enrolled in this class section.',
      );
    }

    // 4. Validate schedule & cutoff window
    if (schedStatus.hasPlottedScheduleAnyDay && !schedStatus.isScheduledOnDate) {
      return RfidScanOutcome(
        success: false,
        code: 'NO_SCHEDULE_TODAY',
        studentId: studentId,
        studentName: studentName,
        message: 'No class session is scheduled for this subject today.',
      );
    }

    AttendanceStatus calculatedStatus = AttendanceStatus.present;
    if (schedStatus.isScheduledOnDate && schedStatus.startTime != null) {
      final cutoffEval = _evaluateCutoffWindow(
        scanTime24: scanTime24,
        startTime: schedStatus.startTime!,
        endTime: schedStatus.endTime,
        cutoff: schedStatus.cutoffConfig,
        studentId: studentId,
        studentName: studentName,
      );
      if (cutoffEval.rejection != null) return cutoffEval.rejection!;
      calculatedStatus = cutoffEval.status!;
    }

    // 5. Inspect existing record & apply 3-way conflict rules
    Map<String, dynamic>? existing;
    try {
      existing = await _client
          .from('attendance_records')
          .select('id, status, recording_method, time_in, remarks')
          .eq('student_id', studentId)
          .eq('subject_offering_id', subjectOfferingId)
          .eq('attendance_date', dateStr)
          .maybeSingle();
    } catch (err) {
      if (_isMissingSchemaObject(err)) {
        existing = await _client
            .from('attendance_records')
            .select('id, status, remarks')
            .eq('student_id', studentId)
            .eq('subject_offering_id', subjectOfferingId)
            .eq('attendance_date', dateStr)
            .maybeSingle();
      } else {
        rethrow;
      }
    }

    if (existing != null) {
      final existingStatus = _parseAttendanceStatus(existing['status']);
      final existingSource = _safeParseSource(
        existing['recording_method']?.toString(),
      );
      final existingTimeDisplay = _formatTimeDisplayOrNull(existing['time_in']);

      if (existingSource == AttendanceSource.manual ||
          existingStatus == AttendanceStatus.excused) {
        return RfidScanOutcome(
          success: true,
          code: 'MANUAL_OVERRIDE_PRESERVED',
          status: existingStatus,
          studentId: studentId,
          studentName: studentName,
          timeIn: existingTimeDisplay,
          message: 'Existing manual teacher mark preserved.',
        );
      }

      if (existingSource == AttendanceSource.system &&
          existingStatus == AttendanceStatus.absent) {
        await _upsertAttendanceRows(
          subjectOfferingId: subjectOfferingId,
          dateStr: dateStr,
          fullRows: [
            {
              'student_id': studentId,
              'subject_offering_id': subjectOfferingId,
              'attendance_date': dateStr,
              'status': calculatedStatus.name,
              'recording_method': 'RFID',
              'time_in': scanTime24,
              'device_id': deviceId,
              'remarks': 'Promoted from System Auto-Absent via delayed RFID tap',
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
          ],
        );
        await _persistScanOutcomeLocally(
          subjectOfferingId: subjectOfferingId,
          scanTimestamp: manilaTime,
          studentId: studentId,
          status: calculatedStatus,
          timeIn: scanTimeDisplay,
          deviceId: deviceId,
          isSynced: true,
        );
        _invalidateAttendanceCaches();
        return RfidScanOutcome(
          success: true,
          code: 'PROMOTED_FROM_AUTO_ABSENT',
          status: calculatedStatus,
          studentId: studentId,
          studentName: studentName,
          timeIn: scanTimeDisplay,
          message: 'Attendance recovered and promoted from System Auto-Absent.',
        );
      }

      if (existingStatus == AttendanceStatus.late &&
          calculatedStatus == AttendanceStatus.present) {
        await _upsertAttendanceRows(
          subjectOfferingId: subjectOfferingId,
          dateStr: dateStr,
          fullRows: [
            {
              'student_id': studentId,
              'subject_offering_id': subjectOfferingId,
              'attendance_date': dateStr,
              'status': 'present',
              'recording_method': 'RFID',
              'time_in': scanTime24,
              'device_id': deviceId,
              'remarks': 'Promoted to Present via earlier physical RFID tap',
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
          ],
        );
        await _persistScanOutcomeLocally(
          subjectOfferingId: subjectOfferingId,
          scanTimestamp: manilaTime,
          studentId: studentId,
          status: AttendanceStatus.present,
          timeIn: scanTimeDisplay,
          deviceId: deviceId,
          isSynced: true,
        );
        _invalidateAttendanceCaches();
        return RfidScanOutcome(
          success: true,
          code: 'PROMOTED_TO_PRESENT',
          status: AttendanceStatus.present,
          studentId: studentId,
          studentName: studentName,
          timeIn: scanTimeDisplay,
          message: 'Attendance promoted to Present based on earlier RFID tap.',
        );
      }

      final existingSecs = _parseTimeToSecondsSinceMidnight(
        existing['time_in']?.toString(),
      );
      final incomingSecs = _parseTimeToSecondsSinceMidnight(scanTime24);
      if (existingStatus == calculatedStatus &&
          existingSecs != null &&
          incomingSecs != null &&
          incomingSecs < existingSecs) {
        await _upsertAttendanceRows(
          subjectOfferingId: subjectOfferingId,
          dateStr: dateStr,
          fullRows: [
            {
              'student_id': studentId,
              'subject_offering_id': subjectOfferingId,
              'attendance_date': dateStr,
              'status': existingStatus.name,
              'recording_method': 'RFID',
              'time_in': scanTime24,
              'device_id': deviceId,
              'remarks': 'Timestamp updated to earlier physical RFID tap',
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
          ],
        );
        await _persistScanOutcomeLocally(
          subjectOfferingId: subjectOfferingId,
          scanTimestamp: manilaTime,
          studentId: studentId,
          status: existingStatus,
          timeIn: scanTimeDisplay,
          deviceId: deviceId,
          isSynced: true,
        );
        _invalidateAttendanceCaches();
        return RfidScanOutcome(
          success: true,
          code: 'TIMESTAMP_PROMOTED',
          status: existingStatus,
          studentId: studentId,
          studentName: studentName,
          timeIn: scanTimeDisplay,
          message: 'Timestamp updated to earlier physical RFID tap.',
        );
      }

      return RfidScanOutcome(
        success: true,
        code: 'IDEMPOTENT_ALREADY_RECORDED',
        status: existingStatus,
        studentId: studentId,
        studentName: studentName,
        timeIn: existingTimeDisplay ?? scanTimeDisplay,
        message: 'Attendance was already recorded for this student today.',
      );
    }

    await _upsertAttendanceRows(
      subjectOfferingId: subjectOfferingId,
      dateStr: dateStr,
      fullRows: [
        {
          'student_id': studentId,
          'subject_offering_id': subjectOfferingId,
          'attendance_date': dateStr,
          'status': calculatedStatus.name,
          'recording_method': 'RFID',
          'time_in': scanTime24,
          'device_id': deviceId,
          'remarks': 'Recorded via $deviceId',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      ],
    );

    await _persistScanOutcomeLocally(
      subjectOfferingId: subjectOfferingId,
      scanTimestamp: manilaTime,
      studentId: studentId,
      status: calculatedStatus,
      timeIn: scanTimeDisplay,
      deviceId: deviceId,
      isSynced: true,
    );
    _invalidateAttendanceCaches();

    return RfidScanOutcome(
      success: true,
      code: 'RECORDED_SUCCESS',
      status: calculatedStatus,
      studentId: studentId,
      studentName: studentName,
      timeIn: scanTimeDisplay,
      message: 'Attendance recorded as ${calculatedStatus.name[0].toUpperCase()}${calculatedStatus.name.substring(1)}.',
    );
  }

  /// Offline Drift SQLite + LocalStorage validation and write-ahead queue enqueue.
  Future<RfidScanOutcome> _recordRfidScanOffline({
    required String cleanUid,
    required String subjectOfferingId,
    required DateTime scanTimestamp,
    required String deviceId,
  }) async {
    _syncStatus = SyncStatus.pendingSync;
    final manilaTime = scanTimestamp.toUtc().add(const Duration(hours: 8));
    final dateStr = _formatDate(manilaTime);
    final scanTime24 =
        '${manilaTime.hour.toString().padLeft(2, '0')}:${manilaTime.minute.toString().padLeft(2, '0')}:${manilaTime.second.toString().padLeft(2, '0')}';
    final scanTimeDisplay = _formatTimeDisplay(scanTime24);

    // 1. Lookup student in Drift or cached roster
    String? studentId;
    String? studentName;
    bool verifiedEnrolled = false;
    bool hasCachedRosterForOffering = false;

    final cachedRosterRaw = LocalStorageService.getAttendanceRoster(
      subjectOfferingId,
    );
    if (cachedRosterRaw.isNotEmpty) {
      hasCachedRosterForOffering = true;
      final localOverrides = _readLocalRfidOverrides();
      for (final raw in cachedRosterRaw) {
        final s = AttendanceRosterStudent.fromJson(raw);
        final effectiveUid = s.rfidUid ?? localOverrides[s.studentId];
        if (effectiveUid != null &&
            (_normalizeRfidUid(effectiveUid) == cleanUid ||
                (_hexOnly(cleanUid).isNotEmpty &&
                    _hexOnly(effectiveUid) == _hexOnly(cleanUid)))) {
          studentId = s.studentId;
          studentName = s.displayName;
          verifiedEnrolled = true;
          break;
        }
      }
    }

    if (studentId == null && !kIsWeb) {
      try {
        final localStudent = await AppDatabase.instance.findStudentByRfid(
          cleanUid,
        );
        if (localStudent != null) {
          studentId = localStudent.studentId;
          studentName =
              '${localStudent.lastName}, ${localStudent.firstName}'.trim();

          final offeringStudents = await AppDatabase.instance
              .getStudentsForOffering(subjectOfferingId);
          if (offeringStudents.isNotEmpty) {
            hasCachedRosterForOffering = true;
            verifiedEnrolled = offeringStudents.any(
              (s) => s.studentId == studentId,
            );
          } else {
            verifiedEnrolled = true;
          }
        }
      } catch (e) {
        debugPrint('Offline Drift student lookup notice: $e');
      }
    }

    if (studentId == null || studentId.isEmpty) {
      return const RfidScanOutcome(
        success: false,
        code: 'UNREGISTERED_CARD',
        message: 'This RFID card UID is not registered to any student.',
        isOfflineQueued: false,
      );
    }

    if (hasCachedRosterForOffering && !verifiedEnrolled) {
      return RfidScanOutcome(
        success: false,
        code: 'CROSS_SECTION_TAP',
        studentId: studentId,
        studentName: studentName,
        message: '${studentName ?? "Student"} is not enrolled in this class section.',
        isOfflineQueued: false,
      );
    }

    // 2. Evaluate cached schedule & cutoff locally
    final schedStatus = await getScheduleAndCutoffStatus(
      subjectOfferingId: subjectOfferingId,
      date: manilaTime,
    );

    if (schedStatus.isHoliday) {
      return RfidScanOutcome(
        success: false,
        code: 'HOLIDAY_LOCKED',
        studentId: studentId,
        studentName: studentName,
        message: schedStatus.lockReason ??
            'Recognized school holiday. Attendance scans are disabled.',
      );
    }

    if (schedStatus.hasPlottedScheduleAnyDay && !schedStatus.isScheduledOnDate) {
      return RfidScanOutcome(
        success: false,
        code: 'NO_SCHEDULE_TODAY',
        studentId: studentId,
        studentName: studentName,
        message: 'No class session is scheduled for this subject today.',
      );
    }

    AttendanceStatus calculatedStatus = AttendanceStatus.present;
    if (schedStatus.isScheduledOnDate && schedStatus.startTime != null) {
      final cutoffEval = _evaluateCutoffWindow(
        scanTime24: scanTime24,
        startTime: schedStatus.startTime!,
        endTime: schedStatus.endTime,
        cutoff: schedStatus.cutoffConfig,
        studentId: studentId,
        studentName: studentName,
      );
      if (cutoffEval.rejection != null) return cutoffEval.rejection!;
      calculatedStatus = cutoffEval.status!;
    }

    // 3. Local 3-way conflict check
    AttendanceWorkspaceRecord? existingLocal;
    final cachedRecordsRaw = LocalStorageService.getAttendanceRecords(
      subjectOfferingId,
      dateStr,
    );
    for (final raw in cachedRecordsRaw) {
      final rec = AttendanceWorkspaceRecord.fromJson(raw);
      if (rec.studentId == studentId) {
        existingLocal = rec;
        break;
      }
    }

    if (existingLocal != null) {
      if (existingLocal.source == AttendanceSource.manual ||
          existingLocal.status == AttendanceStatus.excused) {
        return RfidScanOutcome(
          success: true,
          code: 'MANUAL_OVERRIDE_PRESERVED',
          status: existingLocal.status,
          studentId: studentId,
          studentName: studentName,
          timeIn: existingLocal.timeIn,
          message: 'Existing manual teacher mark preserved.',
          isOfflineQueued: true,
        );
      }
      if (existingLocal.status == AttendanceStatus.present &&
          calculatedStatus != AttendanceStatus.present) {
        return RfidScanOutcome(
          success: true,
          code: 'IDEMPOTENT_ALREADY_RECORDED',
          status: existingLocal.status,
          studentId: studentId,
          studentName: studentName,
          timeIn: existingLocal.timeIn ?? scanTimeDisplay,
          message: 'Attendance was already recorded locally.',
          isOfflineQueued: true,
        );
      }
    }

    // 4. Write to local Drift + LocalStorage & enqueue 'record_rfid_attendance'
    await _persistScanOutcomeLocally(
      subjectOfferingId: subjectOfferingId,
      scanTimestamp: manilaTime,
      studentId: studentId,
      status: calculatedStatus,
      timeIn: scanTimeDisplay,
      deviceId: deviceId,
      isSynced: false,
    );

    final scanPayload = <String, dynamic>{
      'rfid_uid': cleanUid,
      'subject_offering_id': subjectOfferingId,
      'scan_timestamp': scanTimestamp.toUtc().toIso8601String(),
      'device_id': deviceId,
    };

    if (!kIsWeb) {
      try {
        await AppDatabase.instance.enqueueOfflineAction(
          id: 'rfid_${studentId}_${subjectOfferingId}_${dateStr}_${scanTimestamp.millisecondsSinceEpoch}',
          action: 'record_rfid_attendance',
          targetTable: 'attendance_records',
          payloadJson: jsonEncode(scanPayload),
        );
      } catch (dbErr) {
        debugPrint('Drift enqueue record_rfid_attendance notice: $dbErr');
      }
    } else {
      final webScanQueueRaw = LocalStorageService.getJson(
        'offline_rfid_scans_queue',
      );
      final webQueue = webScanQueueRaw is List
          ? webScanQueueRaw
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : <Map<String, dynamic>>[];
      webQueue.add(scanPayload);
      await LocalStorageService.saveJson('offline_rfid_scans_queue', webQueue);
    }

    _invalidateAttendanceCaches();

    return RfidScanOutcome(
      success: true,
      code: 'RECORDED_OFFLINE_QUEUED',
      status: calculatedStatus,
      studentId: studentId,
      studentName: studentName,
      timeIn: scanTimeDisplay,
      message: 'Attendance saved offline and queued for automatic cloud sync.',
      isOfflineQueued: true,
    );
  }

  ({AttendanceStatus? status, RfidScanOutcome? rejection}) _evaluateCutoffWindow({
    required String scanTime24,
    required String startTime,
    required String? endTime,
    required AttendanceCutoffConfig cutoff,
    required String studentId,
    required String? studentName,
  }) {
    final scanMins = _parseTimeToMinutesSinceMidnight(scanTime24);
    final startMins = _parseTimeToMinutesSinceMidnight(startTime);
    final endMins = _parseTimeToMinutesSinceMidnight(endTime);

    if (scanMins == null || startMins == null) {
      return (status: AttendanceStatus.present, rejection: null);
    }

    final openMins = startMins - cutoff.presentStartMinsBefore;
    final graceMins = startMins + cutoff.presentGraceMins;
    final lateMins = startMins + cutoff.lateCutoffMins;
    final absentMins = startMins + cutoff.absentCutoffMins;

    if (scanMins < openMins) {
      return (
        status: null,
        rejection: RfidScanOutcome(
          success: false,
          code: 'BEFORE_WINDOW_OPENS',
          studentId: studentId,
          studentName: studentName,
          message:
              'Too early to scan. Attendance window opens at ${_formatMinutesAs12h(openMins)}.',
        ),
      );
    }

    if (endMins != null && scanMins > endMins) {
      return (
        status: null,
        rejection: RfidScanOutcome(
          success: false,
          code: 'AFTER_CLASS_ENDS',
          studentId: studentId,
          studentName: studentName,
          message:
              'Class ended at ${_formatMinutesAs12h(endMins)}. Scans are closed.',
        ),
      );
    }

    if (scanMins > absentMins) {
      return (
        status: null,
        rejection: RfidScanOutcome(
          success: false,
          code: 'SCANS_CLOSED',
          studentId: studentId,
          studentName: studentName,
          message:
              'Attendance cutoff window closed at ${_formatMinutesAs12h(absentMins)}.',
        ),
      );
    }

    if (scanMins <= graceMins) {
      return (status: AttendanceStatus.present, rejection: null);
    }
    if (scanMins <= lateMins) {
      return (status: AttendanceStatus.late, rejection: null);
    }
    return (status: AttendanceStatus.absent, rejection: null);
  }

  Future<void> _persistScanOutcomeLocally({
    required String subjectOfferingId,
    required DateTime scanTimestamp,
    required String studentId,
    required AttendanceStatus status,
    required String timeIn,
    required String deviceId,
    required bool isSynced,
  }) async {
    final dateStr = _formatDate(scanTimestamp);

    // Update LocalStorageService date records list
    final existingListRaw = LocalStorageService.getAttendanceRecords(
      subjectOfferingId,
      dateStr,
    );
    final updatedRecords = existingListRaw
        .map((m) => AttendanceWorkspaceRecord.fromJson(m))
        .where((r) => r.studentId != studentId)
        .toList();

    final newRec = AttendanceWorkspaceRecord(
      id: '${studentId}_${subjectOfferingId}_$dateStr',
      studentId: studentId,
      subjectOfferingId: subjectOfferingId,
      attendanceDate: scanTimestamp,
      status: status,
      source: AttendanceSource.rfid,
      timeIn: timeIn,
      deviceId: deviceId,
      remarks: 'Recorded via $deviceId',
    );
    updatedRecords.add(newRec);

    await LocalStorageService.saveAttendanceRecords(
      subjectOfferingId,
      dateStr,
      updatedRecords.map((r) => r.toJson()).toList(),
    );

    if (!kIsWeb) {
      try {
        await AppDatabase.instance.upsertAttendanceRecords([
          LocalAttendanceRecordsCompanion.insert(
            id: '${studentId}_${subjectOfferingId}_$dateStr',
            studentId: studentId,
            subjectOfferingId: subjectOfferingId,
            attendanceDate: dateStr,
            status: status.name,
            recordingMethod: const Value('RFID'),
            timeIn: Value(timeIn),
            deviceId: Value(deviceId),
            remarks: Value('Recorded via $deviceId'),
            source: const Value('rfid'),
            syncStatus: Value(isSynced ? 'synced' : 'pending'),
          ),
        ]);
      } catch (dbErr) {
        debugPrint('Drift scan local persist notice: $dbErr');
      }
    }
  }

  // =========================================================================
  // Offline Sync Queue Drain (R4)
  // =========================================================================

  @override
  Future<int> syncOfflineAttendanceQueue() async {
    int syncedCount = 0;
    _syncStatus = SyncStatus.syncing;

    try {
      // 1. Drain Drift OfflineSyncQueue on native platforms
      if (!kIsWeb) {
        final pendingItems = await AppDatabase.instance.getPendingSyncQueue();
        final rfidItems = <OfflineSyncQueueData>[];
        final otherItems = <OfflineSyncQueueData>[];

        for (final item in pendingItems) {
          if (item.action == 'record_rfid_attendance') {
            rfidItems.add(item);
          } else if (item.action == 'batch_save' ||
              item.action == 'save_attendance' ||
              item.action == 'assign_student_rfid' ||
              item.action == 'save_cutoff_config') {
            otherItems.add(item);
          }
        }

        // Drain RFID scans in chunks of up to 50 via batch RPC
        for (var i = 0; i < rfidItems.length; i += 50) {
          final chunk = rfidItems.sublist(
            i,
            i + 50 > rfidItems.length ? rfidItems.length : i + 50,
          );
          final payloads = <Map<String, dynamic>>[];
          for (final item in chunk) {
            try {
              payloads.add(
                Map<String, dynamic>.from(jsonDecode(item.payloadJson) as Map),
              );
            } catch (parseErr) {
              await AppDatabase.instance.markSyncQueueFailed(
                item.id,
                'Invalid JSON payload: $parseErr',
              );
            }
          }

          if (payloads.isEmpty) continue;

          try {
            await _client.rpc(
              'record_rfid_attendance_batch',
              params: {'p_scans': payloads},
            );
            for (final item in chunk) {
              await AppDatabase.instance.markSyncQueueCompleted(item.id);
              syncedCount++;
            }
          } catch (batchErr) {
            if (_isNetworkError(batchErr)) {
              _syncStatus = SyncStatus.pendingSync;
              return syncedCount;
            }
            // Fallback to individual scan replay if batch RPC is not yet deployed
            for (final item in chunk) {
              try {
                final p = Map<String, dynamic>.from(
                  jsonDecode(item.payloadJson) as Map,
                );
                await recordRfidScan(
                  rfidUid: p['rfid_uid']?.toString() ?? '',
                  subjectOfferingId: p['subject_offering_id']?.toString() ?? '',
                  scanTimestamp: DateTime.tryParse(
                    p['scan_timestamp']?.toString() ?? '',
                  ),
                  deviceId: p['device_id']?.toString() ?? 'USB_SCANNER',
                );
                await AppDatabase.instance.markSyncQueueCompleted(item.id);
                syncedCount++;
              } catch (singleErr) {
                if (_isNetworkError(singleErr)) {
                  _syncStatus = SyncStatus.pendingSync;
                  return syncedCount;
                }
                await AppDatabase.instance.markSyncQueueFailed(
                  item.id,
                  singleErr.toString(),
                );
              }
            }
          }
        }

        // Drain batch_save, assign_student_rfid, save_cutoff_config items
        for (final item in otherItems) {
          try {
            final payload = Map<String, dynamic>.from(
              jsonDecode(item.payloadJson) as Map,
            );

            if (item.action == 'batch_save' ||
                item.action == 'save_attendance') {
              final offeringId = payload['subject_offering_id']?.toString() ?? '';
              final dateStr = payload['date']?.toString() ?? '';
              final rawRecords = (payload['records'] as List? ?? []);
              if (offeringId.isNotEmpty &&
                  dateStr.isNotEmpty &&
                  rawRecords.isNotEmpty) {
                final fullRows = rawRecords.map((r) {
                  final map = Map<String, dynamic>.from(r as Map);
                  final source = _safeParseSource(
                    map['recording_method']?.toString() ??
                        map['source']?.toString(),
                  );
                  return <String, dynamic>{
                    'student_id': map['student_id'],
                    'subject_offering_id': offeringId,
                    'attendance_date': dateStr,
                    'status': map['status'],
                    'recording_method': source.toDbString(),
                    'time_in': _normalizeDbTime(map['time_in']?.toString()),
                    'device_id': map['device_id'],
                    'remarks': map['remarks'],
                    if (map['recorded_by'] != null)
                      'recorded_by': map['recorded_by'],
                    'updated_at': DateTime.now().toUtc().toIso8601String(),
                  };
                }).toList();

                await _upsertAttendanceRows(
                  subjectOfferingId: offeringId,
                  dateStr: dateStr,
                  fullRows: fullRows,
                );
                await LocalStorageService.removeOfflineAttendance(
                  '${offeringId}_$dateStr',
                );
              }
            } else if (item.action == 'assign_student_rfid') {
              await assignStudentRfid(
                studentId: payload['student_id']?.toString() ?? '',
                rfidUid: payload['rfid_uid']?.toString(),
                forceReassign: payload['force_reassign'] == true,
              );
            } else if (item.action == 'save_cutoff_config') {
              await saveCutoffConfig(AttendanceCutoffConfig.fromJson(payload));
            }

            await AppDatabase.instance.markSyncQueueCompleted(item.id);
            syncedCount++;
          } catch (itemErr) {
            if (_isNetworkError(itemErr)) {
              _syncStatus = SyncStatus.pendingSync;
              return syncedCount;
            }
            await AppDatabase.instance.markSyncQueueFailed(
              item.id,
              itemErr.toString(),
            );
          }
        }
      }

      // 2. Also drain Web / LocalStorageService offline queues
      final webScansRaw = LocalStorageService.getJson('offline_rfid_scans_queue');
      if (webScansRaw is List && webScansRaw.isNotEmpty) {
        final remaining = <Map<String, dynamic>>[];
        for (final raw in webScansRaw) {
          final p = Map<String, dynamic>.from(raw as Map);
          try {
            final res = await recordRfidScan(
              rfidUid: p['rfid_uid']?.toString() ?? '',
              subjectOfferingId: p['subject_offering_id']?.toString() ?? '',
              scanTimestamp: DateTime.tryParse(
                p['scan_timestamp']?.toString() ?? '',
              ),
              deviceId: p['device_id']?.toString() ?? 'USB_SCANNER',
            );
            if (res.isOfflineQueued) {
              remaining.add(p);
            } else {
              syncedCount++;
            }
          } catch (err) {
            if (_isNetworkError(err)) {
              remaining.add(p);
            }
          }
        }
        await LocalStorageService.saveJson('offline_rfid_scans_queue', remaining);
      }

      final lsBatches = LocalStorageService.getOfflineAttendanceQueue();
      for (final batchItem in lsBatches) {
        final id = batchItem['id']?.toString() ?? '';
        final offeringId = batchItem['subject_offering_id']?.toString() ?? '';
        final dateStr = batchItem['date']?.toString() ?? '';
        final recsRaw = (batchItem['records'] as List? ?? []);
        if (offeringId.isEmpty || dateStr.isEmpty || recsRaw.isEmpty) {
          if (id.isNotEmpty) {
            await LocalStorageService.removeOfflineAttendance(id);
          }
          continue;
        }
        try {
          final fullRows = recsRaw.map((r) {
            final map = Map<String, dynamic>.from(r as Map);
            final src = _safeParseSource(
              map['recording_method']?.toString() ?? map['source']?.toString(),
            );
            return <String, dynamic>{
              'student_id': map['student_id'],
              'subject_offering_id': offeringId,
              'attendance_date': dateStr,
              'status': map['status'],
              'recording_method': src.toDbString(),
              'time_in': _normalizeDbTime(map['time_in']?.toString()),
              'device_id': map['device_id'],
              'remarks': map['remarks'],
              if (map['recorded_by'] != null) 'recorded_by': map['recorded_by'],
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            };
          }).toList();

          await _upsertAttendanceRows(
            subjectOfferingId: offeringId,
            dateStr: dateStr,
            fullRows: fullRows,
          );
          await LocalStorageService.removeOfflineAttendance(id);
          syncedCount++;
        } catch (err) {
          if (_isNetworkError(err)) {
            _syncStatus = SyncStatus.pendingSync;
            return syncedCount;
          }
        }
      }

      _syncStatus = SyncStatus.synced;
      if (syncedCount > 0) {
        _invalidateAttendanceCaches();
      }
      return syncedCount;
    } catch (e) {
      debugPrint('syncOfflineAttendanceQueue notice: $e');
      _syncStatus = _isNetworkError(e)
          ? SyncStatus.pendingSync
          : SyncStatus.syncError;
      return syncedCount;
    }
  }

  // =========================================================================
  // History, Analytics & Record Corrections (R6)
  // =========================================================================

  @override
  Future<AttendancePage<AttendanceWorkspaceRecord>> getAttendanceHistory(
    AttendanceHistoryFilter filter,
  ) async {
    try {
      final startStr = _formatDate(filter.dateRange.startDate);
      final endStr = _formatDate(filter.dateRange.endDate);

      List<dynamic> rows;
      try {
        rows = await _client
            .from('attendance_records')
            .select(
              'id, student_id, subject_offering_id, attendance_date, status, recording_method, time_in, device_id, remarks, recorded_by, created_at',
            )
            .eq('subject_offering_id', filter.subjectOfferingId)
            .gte('attendance_date', startStr)
            .lte('attendance_date', endStr)
            .order('attendance_date', ascending: false)
            .order('id', ascending: false)
            .range(filter.offset, filter.offset + filter.pageSize - 1);
      } catch (err) {
        if (_isMissingSchemaObject(err)) {
          rows = await _client
              .from('attendance_records')
              .select(
                'id, student_id, subject_offering_id, attendance_date, status, remarks, recorded_by, created_at',
              )
              .eq('subject_offering_id', filter.subjectOfferingId)
              .gte('attendance_date', startStr)
              .lte('attendance_date', endStr)
              .order('attendance_date', ascending: false)
              .order('id', ascending: false)
              .range(filter.offset, filter.offset + filter.pageSize - 1);
        } else {
          rethrow;
        }
      }

      final recordList = rows.map((r) {
        final map = Map<String, dynamic>.from(r as Map);
        if (map['time_in'] != null) {
          map['time_in'] = _formatTimeDisplayOrNull(map['time_in']);
        }
        return AttendanceWorkspaceRecord.fromJson(map);
      }).toList();

      return AttendancePage<AttendanceWorkspaceRecord>(
        rows: recordList,
        nextOffset: filter.offset + recordList.length,
        hasMore: recordList.length == filter.pageSize,
      );
    } catch (e) {
      debugPrint('Attendance history query notice: $e');
      return AttendancePage<AttendanceWorkspaceRecord>(
        rows: const [],
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

      final results = await Future.wait<dynamic>([
        _client
            .from('attendance_records')
            .select(
              'id, student_id, subject_offering_id, attendance_date, status, remarks',
            )
            .eq('subject_offering_id', subjectOfferingId)
            .gte('attendance_date', startStr)
            .lte('attendance_date', endStr),
        _client
            .from('student_enrollments')
            .select('''
              student_id,
              student_profiles ( student_id, first_name, middle_name, last_name ),
              subject_offerings (
                sections ( section_name, grade_level )
              )
            ''')
            .eq('subject_offering_id', subjectOfferingId)
            .ilike('status', 'enrolled'),
      ]);

      final records = (results[0] as List).cast<Map<String, dynamic>>();
      final enrollments = (results[1] as List).cast<Map<String, dynamic>>();

      final studentNames = <String, String>{};
      String resolvedSectionLabel = '';

      for (final enr in enrollments) {
        final sid = enr['student_id']?.toString() ?? '';
        final p = enr['student_profiles'] as Map<String, dynamic>?;
        if (sid.isNotEmpty && p != null) {
          final ln = p['last_name']?.toString().trim() ?? '';
          final fn = p['first_name']?.toString().trim() ?? '';
          final mn = p['middle_name']?.toString().trim() ?? '';
          final mi = mn.isNotEmpty ? ' ${mn[0].toUpperCase()}.' : '';
          final name = [
            if (ln.isNotEmpty) '$ln,',
            if (fn.isNotEmpty) '$fn$mi',
          ].join(' ').trim();
          studentNames[sid] = name.isNotEmpty ? name : sid;
        }
        if (resolvedSectionLabel.isEmpty) {
          final off = enr['subject_offerings'] as Map<String, dynamic>?;
          final sec = off?['sections'] as Map<String, dynamic>?;
          if (sec != null) {
            final secName = sec['section_name']?.toString().trim() ?? '';
            final grade = sec['grade_level']?.toString().trim() ?? '';
            resolvedSectionLabel = grade.isNotEmpty && secName.isNotEmpty
                ? 'Grade $grade - $secName'
                : secName;
          }
        }
      }

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
        } else if (status == 'late') {
          late++;
        } else if (status == 'absent') {
          absent++;
          if (sId.isNotEmpty) {
            studentAbsenceCounts[sId] = (studentAbsenceCounts[sId] ?? 0) + 1;
          }
        } else if (status == 'excused') {
          excused++;
        }
      }

      final totalAccounted = present + late + absent;
      final rate = totalAccounted > 0
          ? ((present + late) / totalAccounted) * 100.0
          : null;

      // Populate atRiskStudents (all students with >= 3 absences, sorted descending)
      final atRiskStudents = <AttendanceAtRiskStudent>[];
      studentAbsenceCounts.forEach((sid, count) {
        if (count >= 3) {
          atRiskStudents.add(
            AttendanceAtRiskStudent(
              studentId: sid,
              studentName: studentNames[sid] ?? sid,
              section: resolvedSectionLabel,
              absenceCount: count,
            ),
          );
        }
      });

      atRiskStudents.sort((a, b) {
        final cmp = b.absenceCount.compareTo(a.absenceCount);
        if (cmp != 0) return cmp;
        return a.studentName
            .toLowerCase()
            .compareTo(b.studentName.toLowerCase());
      });

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
        warningCount: atRiskStudents.length,
        presentCount: present,
        lateCount: late,
        absentCount: absent,
        excusedCount: excused,
        trendPoints: trendPoints,
        atRiskStudents: atRiskStudents,
      );
    } catch (e) {
      debugPrint('Attendance analytics query notice: $e');
      return const AttendanceAnalyticsSummary(
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
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw ArgumentError('Correction reason must not be blank.');
    }

    final uid = _currentUserId();
    try {
      await _client.from('attendance_records').update({
        'status': newStatus.name,
        'recording_method': 'Manual',
        'remarks': trimmedReason,
        if (uid != null) 'recorded_by': uid,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', recordId);
    } catch (err) {
      if (_isMissingSchemaObject(err)) {
        await _client.from('attendance_records').update({
          'status': newStatus.name,
          'remarks': trimmedReason,
          if (uid != null) 'recorded_by': uid,
        }).eq('id', recordId);
      } else {
        rethrow;
      }
    }

    _invalidateAttendanceCaches();
  }

  // =========================================================================
  // Student & Parent View-Only Attendance Operations (R6)
  // =========================================================================

  @override
  Future<AttendanceStudentSummary> getMyAttendanceSummary() async {
    final uid = _currentUserId() ?? '';
    if (uid.isEmpty) {
      return AttendanceStudentSummary(
        studentId: uid,
        presentCount: 0,
        lateCount: 0,
        absentCount: 0,
        excusedCount: 0,
        totalDays: 0,
        presenceRate: 0.0,
      );
    }

    final cacheKey = 'my_attendance_summary_$uid';
    final cached = AppDataCache.instance.getCached<AttendanceStudentSummary>(
      cacheKey,
      (json) => AttendanceStudentSummary.fromJson(
        Map<String, dynamic>.from(json as Map),
      ),
    );
    if (cached != null &&
        AppDataCache.instance.isFresh(
          cacheKey,
          ttl: const Duration(minutes: 2),
        )) {
      return cached;
    }

    try {
      final rows = await _client
          .from('attendance_records')
          .select('status')
          .eq('student_id', uid);

      int present = 0;
      int late = 0;
      int absent = 0;
      int excused = 0;

      for (final r in (rows as List? ?? [])) {
        final s = r['status']?.toString().toLowerCase();
        if (s == 'present') {
          present++;
        } else if (s == 'late') {
          late++;
        } else if (s == 'absent') {
          absent++;
        } else if (s == 'excused') {
          excused++;
        }
      }

      final total = present + late + absent + excused;
      final rate = total > 0 ? ((present + late) / total) * 100.0 : 0.0;

      final summary = AttendanceStudentSummary(
        studentId: uid,
        presentCount: present,
        lateCount: late,
        absentCount: absent,
        excusedCount: excused,
        totalDays: total,
        presenceRate: rate,
      );

      unawaited(AppDataCache.instance.setCache(cacheKey, summary.toJson()));
      return summary;
    } catch (e) {
      debugPrint('getMyAttendanceSummary fallback notice: $e');
      if (cached != null) return cached;
      return AttendanceStudentSummary(
        studentId: uid,
        presentCount: 0,
        lateCount: 0,
        absentCount: 0,
        excusedCount: 0,
        totalDays: 0,
        presenceRate: 0.0,
      );
    }
  }

  AttendanceRecord _mapPortalAttendanceRow(
    Map<String, dynamic> row, {
    String fallbackSubject = 'Class',
  }) {
    final subMap = row['subject_offerings'] as Map<String, dynamic>?;
    final subjectName =
        (subMap?['subjects'] as Map<String, dynamic>?)?['subject_name']
                ?.toString()
                .trim() ??
            fallbackSubject;
    final sectionName =
        (subMap?['sections'] as Map<String, dynamic>?)?['section_name']
                ?.toString()
                .trim() ??
            '';

    final profileMap = row['student_profiles'] as Map<String, dynamic>?;
    String studentName = '';
    if (profileMap != null) {
      final fn = profileMap['first_name']?.toString().trim() ?? '';
      final mn = profileMap['middle_name']?.toString().trim() ?? '';
      final ln = profileMap['last_name']?.toString().trim() ?? '';
      studentName = [fn, mn, ln].where((s) => s.isNotEmpty).join(' ');
    }

    final status = _parseAttendanceStatus(
      row['status'],
      fallback: AttendanceStatus.absent,
    );
    final source = _safeParseSource(row['recording_method']?.toString());
    final sourceLabel = source.toDbString(); // 'RFID', 'Manual', 'System'
    final methodDisplay = subjectName.isNotEmpty
        ? '$subjectName • $sourceLabel'
        : sourceLabel;
    final sectionDisplay = subjectName.isNotEmpty
        ? (sectionName.isNotEmpty ? '$subjectName ($sectionName)' : subjectName)
        : sectionName;

    return AttendanceRecord(
      id: row['id']?.toString() ?? '',
      studentId: row['student_id']?.toString() ?? '',
      studentName: studentName,
      section: sectionDisplay.isNotEmpty ? sectionDisplay : subjectName,
      date: DateTime.tryParse(row['attendance_date']?.toString() ?? '') ??
          DateTime.now(),
      status: status,
      timeIn: _formatTimeDisplay(row['time_in']),
      remarks: row['remarks']?.toString(),
      method: methodDisplay,
    );
  }

  Future<List<dynamic>> _queryPortalAttendanceRows({
    String? studentId,
    int? offset,
    int? pageSize,
  }) async {
    Future<List<dynamic>> runSelect(bool includeOverhaulCols) async {
      final cols = includeOverhaulCols
          ? '''
              id, student_id, attendance_date, status, recording_method, time_in, remarks,
              student_profiles ( first_name, middle_name, last_name ),
              subject_offerings (
                subjects ( subject_name ),
                sections ( section_name )
              )
            '''
          : '''
              id, student_id, attendance_date, status, remarks,
              student_profiles ( first_name, middle_name, last_name ),
              subject_offerings (
                subjects ( subject_name ),
                sections ( section_name )
              )
            ''';

      var filterBuilder = _client.from('attendance_records').select(cols);
      if (studentId != null && studentId.isNotEmpty) {
        filterBuilder = filterBuilder.eq('student_id', studentId);
      }

      final ordered = filterBuilder
          .order('attendance_date', ascending: false)
          .order('created_at', ascending: false);

      if (offset != null && pageSize != null) {
        final paged = await ordered.range(offset, offset + pageSize - 1);
        return paged as List<dynamic>;
      }
      final all = await ordered;
      return all as List<dynamic>;
    }

    try {
      return await runSelect(true);
    } catch (err) {
      if (_isMissingSchemaObject(err)) {
        return await runSelect(false);
      }
      rethrow;
    }
  }

  @override
  Future<AttendancePage<AttendanceRecord>> getMyAttendancePage({
    required int offset,
    int pageSize = 20,
  }) async {
    final uid = _currentUserId();
    if (uid == null || uid.isEmpty) {
      return AttendancePage<AttendanceRecord>(
        rows: const [],
        nextOffset: offset,
        hasMore: false,
      );
    }

    try {
      final rows = await _queryPortalAttendanceRows(
        studentId: uid,
        offset: offset,
        pageSize: pageSize,
      );

      final recordList = rows
          .map<AttendanceRecord>(
            (row) => _mapPortalAttendanceRow(
              Map<String, dynamic>.from(row as Map),
              fallbackSubject: 'Class',
            ),
          )
          .toList();

      return AttendancePage<AttendanceRecord>(
        rows: recordList,
        nextOffset: offset + recordList.length,
        hasMore: recordList.length == pageSize,
      );
    } catch (e) {
      debugPrint('getMyAttendancePage notice: $e');
      return AttendancePage<AttendanceRecord>(
        rows: const [],
        nextOffset: offset,
        hasMore: false,
      );
    }
  }

  // =========================================================================
  // Legacy / Shared Portal Methods
  // =========================================================================

  @override
  Future<List<AttendanceRecord>> getAttendanceForStudent(
    String studentId,
  ) async {
    if (studentId.trim().isEmpty) return const [];

    try {
      final rows = await _queryPortalAttendanceRows(studentId: studentId);
      return rows
          .map<AttendanceRecord>(
            (row) => _mapPortalAttendanceRow(
              Map<String, dynamic>.from(row as Map),
              fallbackSubject: 'General',
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('getAttendanceForStudent notice: $e');
      return const [];
    }
  }

  Future<void> markAttendance(AttendanceRecord record) async {
    await _client.from('attendance_records').insert({
      'student_id': record.studentId,
      'attendance_date': _formatDate(record.date),
      'status': record.status.name,
      'remarks': record.remarks,
    });
    _invalidateAttendanceCaches();
  }

  @override
  Future<List<AttendanceRecord>> getAllAttendanceRecords() async {
    try {
      final rows = await _queryPortalAttendanceRows();
      return rows
          .map<AttendanceRecord>(
            (row) => _mapPortalAttendanceRow(
              Map<String, dynamic>.from(row as Map),
              fallbackSubject: 'General',
            ),
          )
          .toList();
    } catch (_) {
      return const [];
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
    _invalidateAttendanceCaches();
  }

  @override
  Future<void> toggleOfflineSync() async {
    await syncOfflineAttendanceQueue();
  }

  @override
  SyncStatus getSyncStatus() => _syncStatus;
}
