import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/models/admin_portal_models.dart';
import 'package:class_realm/models/academic_models.dart';

class AdminRepository {
  static final AdminRepository instance = AdminRepository._internal();
  AdminRepository._internal();

  SupabaseClient get _client => Supabase.instance.client;

  // =========================================================================
  // 1. DURATION & INTERVAL ALGORITHMS (EDGE CASES #17 & #19)
  // =========================================================================

  /// Human-readable duration formatting conforming to concise format:
  /// '01h 01m 01s', '02h 57m 05s', '00h 57m 01s', '00h 00m 40s'
  static String formatHumanReadableDuration(int totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final hrStr = '${hours.toString().padLeft(2, '0')}h';
    final minStr = '${minutes.toString().padLeft(2, '0')}m';
    final secStr = '${seconds.toString().padLeft(2, '0')}s';

    return '$hrStr $minStr $secStr';
  }

  /// Merges overlapping time intervals [login_at, logout_at] (Edge Case #17)
  /// and clips across date boundaries (Edge Case #19)
  static int calculateMergedDurationSeconds(
    List<UserSessionLog> sessions, {
    DateTime? filterStart,
    DateTime? filterEnd,
  }) {
    if (sessions.isEmpty) return 0;
    final now = DateTime.now();

    final intervals = <DateTimeRange>[];

    for (final s in sessions) {
      DateTime start = s.loginAt;
      DateTime end = s.isActive ? now : (s.logoutAt ?? s.lastActiveAt);

      if (end.isBefore(start)) end = start;

      // Clip to filterStart if provided
      if (filterStart != null && start.isBefore(filterStart)) {
        start = filterStart;
      }
      // Clip to filterEnd if provided
      if (filterEnd != null && end.isAfter(filterEnd)) {
        end = filterEnd;
      }

      if (end.isAfter(start)) {
        intervals.add(DateTimeRange(start: start, end: end));
      }
    }

    if (intervals.isEmpty) return 0;

    // Sort intervals by start timestamp
    intervals.sort((a, b) => a.start.compareTo(b.start));

    // Merge overlapping intervals
    final merged = <DateTimeRange>[];
    for (final interval in intervals) {
      if (merged.isEmpty) {
        merged.add(interval);
      } else {
        final last = merged.last;
        if (interval.start.isBefore(last.end) || interval.start.isAtSameMomentAs(last.end)) {
          final newEnd = interval.end.isAfter(last.end) ? interval.end : last.end;
          merged[merged.length - 1] = DateTimeRange(start: last.start, end: newEnd);
        } else {
          merged.add(interval);
        }
      }
    }

    return merged.fold<int>(0, (acc, r) => acc + r.duration.inSeconds);
  }

  /// Splits an interval across midnight into separate daily slices
  static List<DateTimeRange> splitIntervalAtMidnight(DateTime start, DateTime end) {
    if (!end.isAfter(start)) return [];
    final slices = <DateTimeRange>[];
    DateTime currentStart = start;

    while (true) {
      final nextMidnight = DateTime(currentStart.year, currentStart.month, currentStart.day + 1);
      if (end.isBefore(nextMidnight) || end.isAtSameMomentAs(nextMidnight)) {
        slices.add(DateTimeRange(start: currentStart, end: end));
        break;
      } else {
        slices.add(DateTimeRange(start: currentStart, end: nextMidnight));
        currentStart = nextMidnight;
      }
    }
    return slices;
  }

  // =========================================================================
  // 2. SYSTEM SETTINGS & MAINTENANCE MODE (REAL SUPABASE)
  // =========================================================================

  Future<SystemSettingsModel> getSystemSettings() async {
    try {
      final res = await _client
          .from('system_settings')
          .select()
          .eq('id', true)
          .maybeSingle();

      if (res != null) {
        return SystemSettingsModel.fromJson(res);
      }
      return SystemSettingsModel(
        isMaintenanceMode: false,
        maintenanceUpdatedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('AdminRepository getSystemSettings error: $e');
      return SystemSettingsModel(
        isMaintenanceMode: false,
        maintenanceUpdatedAt: DateTime.now(),
      );
    }
  }

  Future<void> setMaintenanceMode(bool isMaintenance, String adminId) async {
    final now = DateTime.now().toIso8601String();
    await _client.from('system_settings').upsert({
      'id': true,
      'is_maintenance_mode': isMaintenance,
      'maintenance_updated_at': now,
      'maintenance_updated_by': adminId,
    });
  }

  Future<List<String>> getActiveUserEmails() async {
    try {
      // Exclude archived and purely mock accounts. Include active and pending_first_login
      final res = await _client
          .from('users')
          .select('email')
          .eq('is_archived', false)
          .not('email', 'in', '("parent","student","teacher")');
          
      final List<String> emails = [];
      for (final row in res as List) {
        if (row['email'] != null && row['email'].toString().isNotEmpty) {
          emails.add(row['email'].toString());
        }
      }
      return emails;
    } catch (e) {
      debugPrint('AdminRepository getActiveUserEmails error: $e');
      return [];
    }
  }

  // =========================================================================
  // 3. SCHOOL YEAR MANAGEMENT & ARCHIVING (REAL SUPABASE)
  // =========================================================================

  Future<List<SchoolYearRecord>> getAllSchoolYears() async {
    try {
      final res = await _client
          .from('school_years')
          .select()
          .order('school_year', ascending: false);

      return (res as List)
          .map((r) => SchoolYearRecord.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('AdminRepository getAllSchoolYears error: $e');
      return [];
    }
  }

  Future<SchoolYearRecord?> getActiveSchoolYear() async {
    try {
      final res = await _client
          .from('school_years')
          .select()
          .eq('is_current', true)
          .maybeSingle();

      if (res != null) {
        return SchoolYearRecord.fromJson(res);
      }
      return null;
    } catch (e) {
      debugPrint('AdminRepository getActiveSchoolYear error: $e');
      return null;
    }
  }

  /// Edge Case #11: Pre-transition audit check
  Future<PreTransitionAuditResult> checkPreTransitionAudit(String currentSchoolYearId) async {
    try {
      // 1. Check unfinalized grades in current school year's sections/offerings
      final gradesRes = await _client
          .from('term_grades')
          .select('id')
          .eq('is_finalized', false)
          .limit(100);

      final unfinalizedCount = (gradesRes as List).length;

      // 2. Check pending classwork submissions
      final subRes = await _client
          .from('student_classwork_submissions')
          .select('id')
          .eq('status', 'pending')
          .limit(100);

      final pendingCount = (subRes as List).length;

      return PreTransitionAuditResult(
        unfinalizedGradesCount: unfinalizedCount,
        pendingSubmissionsCount: pendingCount,
      );
    } catch (e) {
      debugPrint('AdminRepository checkPreTransitionAudit error: $e');
      return const PreTransitionAuditResult(
        unfinalizedGradesCount: 0,
        pendingSubmissionsCount: 0,
      );
    }
  }

  /// Transition to new school year (Edge Cases #11, #13, #14)
  Future<void> transitionToNewSchoolYear(String newSchoolYearString, String adminId) async {
    // 1. Validate consecutive format
    final regex = RegExp(r'^\d{4}-\d{4}$');
    if (!regex.hasMatch(newSchoolYearString)) {
      throw const FormatException('Invalid School Year format. Expected YYYY-YYYY.');
    }
    final parts = newSchoolYearString.split('-');
    final startYear = int.parse(parts[0]);
    final endYear = int.parse(parts[1]);
    if (endYear != startYear + 1) {
      throw const FormatException('End year must be exactly start year + 1.');
    }

    // 2. Archive all existing school years
    await _client
        .from('school_years')
        .update({'is_current': false, 'is_archived': true})
        .eq('is_current', true);

    // 3. Insert or activate new school year
    final syRes = await _client
        .from('school_years')
        .upsert({
          'school_year': newSchoolYearString,
          'is_current': true,
          'is_archived': false,
        }, onConflict: 'school_year')
        .select()
        .single();

    final newSyId = syRes['id'].toString();

    // 4. Seed the 3 fixed Trimester terms for the new School Year
    final terms = [
      {'school_year_id': newSyId, 'term_number': 1, 'term_name': 'Term 1', 'is_archived': false},
      {'school_year_id': newSyId, 'term_number': 2, 'term_name': 'Term 2', 'is_archived': false},
      {'school_year_id': newSyId, 'term_number': 3, 'term_name': 'Term 3', 'is_archived': false},
    ];

    await _client.from('terms').upsert(terms);

    // 5. Update system settings timestamp
    await _client.from('system_settings').update({
      'school_year_updated_at': DateTime.now().toIso8601String(),
    }).eq('id', true);
  }

  // =========================================================================
  // 4. GLOBAL ANNOUNCEMENTS & BROADCASTS (REAL SUPABASE)
  // =========================================================================

  /// Returns real counts of active (non-archived) users grouped by role
  Future<Map<String, int>> getActiveUserCountsByRole() async {
    try {
      // 1. Try dedicated RPC function first (accurate DB-level aggregate)
      try {
        final rpcRes = await _client.rpc('get_active_audience_counts');
        if (rpcRes is Map) {
          return {
            'teachers': (rpcRes['teachers'] as num?)?.toInt() ?? 0,
            'students': (rpcRes['students'] as num?)?.toInt() ?? 0,
            'parents': (rpcRes['parents'] as num?)?.toInt() ?? 0,
            'total': (rpcRes['total'] as num?)?.toInt() ?? 0,
          };
        }
      } catch (rpcErr) {
        debugPrint('getActiveUserCountsByRole RPC notice: $rpcErr');
      }

      // 2. Fallback queries strictly filtering by status == 'active'
      final teacherRes = await _client
          .from('teacher_settings')
          .select('teacher_id')
          .eq('status', 'active');
      final activeTeacherIds = (teacherRes as List)
          .map((r) => r['teacher_id']?.toString())
          .whereType<String>()
          .toList();

      int teachersCount = 0;
      if (activeTeacherIds.isNotEmpty) {
        final validTeachers = await _client
            .from('users')
            .select('id')
            .inFilter('id', activeTeacherIds)
            .eq('is_archived', false);
        teachersCount = (validTeachers as List).length;
      }

      int studentsCount = 0;
      try {
        final studentRes = await _client
            .from('student_settings')
            .select('student_id')
            .eq('status', 'active');
        final activeStudentIds = (studentRes as List)
            .map((r) => r['student_id']?.toString())
            .whereType<String>()
            .toList();
        if (activeStudentIds.isNotEmpty) {
          final validStudents = await _client
              .from('users')
              .select('id')
              .inFilter('id', activeStudentIds)
              .eq('is_archived', false);
          studentsCount = (validStudents as List).length;
        }
      } catch (_) {}

      int parentsCount = 0;
      try {
        final parentRes = await _client
            .from('parent_profiles')
            .select('parent_id')
            .eq('status', 'active');
        final activeParentIds = (parentRes as List)
            .map((r) => r['parent_id']?.toString())
            .whereType<String>()
            .toList();
        if (activeParentIds.isNotEmpty) {
          final validParents = await _client
              .from('users')
              .select('id')
              .inFilter('id', activeParentIds)
              .eq('is_archived', false);
          parentsCount = (validParents as List).length;
        }
      } catch (_) {}

      return {
        'teachers': teachersCount,
        'students': studentsCount,
        'parents': parentsCount,
        'total': teachersCount + studentsCount + parentsCount,
      };
    } catch (e) {
      debugPrint('AdminRepository getActiveUserCountsByRole error: $e');
      return {'teachers': 0, 'students': 0, 'parents': 0, 'total': 0};
    }
  }

  Future<List<AppNotificationModel>> getBroadcastAnnouncements({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final res = await _client
          .from('notifications')
          .select()
          .eq('is_archived', false)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (res as List)
          .map((r) => AppNotificationModel.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('AdminRepository getBroadcastAnnouncements error: $e');
      return [];
    }
  }

  Future<AppNotificationModel> sendBroadcastAnnouncement({
    required String title,
    required String message,
    required String targetAudience,
    required String adminId,
  }) async {
    final cleanTitle = title.trim();
    final cleanMessage = message.trim().replaceAll(RegExp(r'\s+'), ' ');

    if (cleanTitle.length < 3 || cleanTitle.length > 100) {
      throw const FormatException('Title must be between 3 and 100 characters.');
    }
    if (cleanMessage.length < 5 || cleanMessage.length > 1000) {
      throw const FormatException('Message must be between 5 and 1000 characters.');
    }

    final res = await _client
        .from('notifications')
        .insert({
          'title': cleanTitle,
          'message': cleanMessage,
          'target_audience': targetAudience,
          'notification_type': 'announcement',
          'created_by': adminId,
          'is_archived': false,
        })
        .select()
        .single();

    return AppNotificationModel.fromJson(res);
  }

  Future<void> softDeleteAnnouncement(String id) async {
    await _client
        .from('notifications')
        .update({'is_archived': true})
        .eq('id', id);
  }

  // =========================================================================
  // 5. TEACHER ACTIVITY & WORKLOAD TELEMETRY (REAL SUPABASE)
  // =========================================================================

  Future<List<UserSessionLog>> getTeacherSessionLogs({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var filterQuery = _client
          .from('user_session_logs')
          .select()
          .eq('role', 'teacher');

      if (startDate != null) {
        filterQuery = filterQuery.gte('session_date', startDate.toIso8601String().split('T').first);
      }
      if (endDate != null) {
        filterQuery = filterQuery.lte('session_date', endDate.toIso8601String().split('T').first);
      }

      final res = await filterQuery.order('login_at', ascending: false).limit(200);
      final rawLogs = res as List;
      if (rawLogs.isEmpty) return [];

      final teacherIds = rawLogs
          .map((r) => r['user_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      final profilesRes = await _client
          .from('teacher_profiles')
          .select('teacher_id, first_name, last_name, gender')
          .inFilter('teacher_id', teacherIds);

      final nameMap = <String, String>{};
      for (final p in (profilesRes as List)) {
        final id = p['teacher_id'].toString();
        final fn = p['first_name']?.toString() ?? '';
        final ln = p['last_name']?.toString() ?? '';
        final g = p['gender']?.toString().trim().toLowerCase();
        final prefix = (g == 'female' || g == 'f')
            ? "Ma'am "
            : (g == 'male' || g == 'm')
                ? "Sir "
                : "";
        final raw = [fn, ln].where((s) => s.isNotEmpty).join(' ');
        nameMap[id] = raw.isNotEmpty ? '$prefix$raw' : 'Teacher';
      }

      return rawLogs
        .map((r) {
          final uId = r['user_id']?.toString() ?? '';
          final teacherName = nameMap[uId] ?? 'Teacher';
          return UserSessionLog.fromJson(r as Map<String, dynamic>, teacherName: teacherName);
        })
        .where((log) => log.isActive || log.durationSeconds > 0) // Hide zero-second dead sessions
        .toList();
    } catch (e) {
      debugPrint('AdminRepository getTeacherSessionLogs error: $e');
      return [];
    }
  }

  /// Privacy-compliant teacher workload summary: integer counts only!
  Future<List<TeacherWorkloadSummary>> getTeacherWorkloadSummaries(String schoolYearId) async {
    try {
      // 1. Get ONLY active teachers (teacher_settings.status = active), excluding archived and pending_first_login
      final activeSettings = await _client
          .from('teacher_settings')
          .select('teacher_id')
          .eq('status', 'active');
      final activeTeacherIds = (activeSettings as List)
          .map((r) => r['teacher_id']?.toString())
          .whereType<String>()
          .toList();

      if (activeTeacherIds.isEmpty) return [];

      final teachersRes = await _client
          .from('teacher_profiles')
          .select('''
            teacher_id,
            first_name,
            last_name,
            gender,
            users!inner ( is_archived )
          ''')
          .eq('users.is_archived', false)
          .inFilter('teacher_id', activeTeacherIds);

      final teachers = (teachersRes as List);

      // 2. Get subject offerings counts for active school year
      final offeringsRes = await _client
          .from('subject_offerings')
          .select('teacher_id, subject_id, section_id')
          .eq('is_archived', false);

      final offerings = (offeringsRes as List);

      // 3. Get today and week sessions
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = todayStart.subtract(Duration(days: todayStart.weekday - 1)); // Monday

      final sessionsRes = await _client
          .from('user_session_logs')
          .select()
          .eq('role', 'teacher')
          .gte('session_date', weekStart.toIso8601String().split('T').first)
          .order('login_at', ascending: false);

      final sessions = (sessionsRes as List)
          .map((s) => UserSessionLog.fromJson(s as Map<String, dynamic>))
          .toList();

      final summaries = <TeacherWorkloadSummary>[];

      for (final t in teachers) {
        final tId = t['teacher_id'].toString();
        final fn = t['first_name']?.toString() ?? '';
        final ln = t['last_name']?.toString() ?? '';
        final g = t['gender']?.toString().trim().toLowerCase();
        final prefix = (g == 'female' || g == 'f')
            ? "Ma'am "
            : (g == 'male' || g == 'm')
                ? "Sir "
                : "";
        final raw = [fn, ln].where((s) => s.isNotEmpty).join(' ');
        final tName = raw.isNotEmpty ? '$prefix$raw' : 'Teacher';

        final teacherOfferings = offerings.where((o) => o['teacher_id'] == tId).toList();
        final uniqueSubjects = teacherOfferings.map((o) => o['subject_id']).toSet().length;
        final uniqueSections = teacherOfferings.map((o) => o['section_id']).toSet().length;

        final teacherSessions = sessions.where((s) => s.userId == tId).toList();
        final isActiveNow = teacherSessions.any((s) => s.isActive);

        final todayDuration = calculateMergedDurationSeconds(
          teacherSessions.where((s) => !s.loginAt.isBefore(todayStart)).toList(),
          filterStart: todayStart,
        );

        final weekDuration = calculateMergedDurationSeconds(
          teacherSessions,
          filterStart: weekStart,
        );

        summaries.add(
          TeacherWorkloadSummary(
            teacherId: tId,
            teacherName: tName,
            totalSubjectsCount: uniqueSubjects,
            totalSectionsCount: uniqueSections,
            isActiveNow: isActiveNow,
            todayDurationSeconds: todayDuration,
            weekDurationSeconds: weekDuration,
          ),
        );
      }

      return summaries;
    } catch (e) {
      debugPrint('AdminRepository getTeacherWorkloadSummaries error: $e');
      return [];
    }
  }

  /// Dashboard Aggregate KPI metrics (Real Supabase queries)
  Future<Map<String, dynamic>> getDashboardKpiMetrics() async {
    try {
      // 1. Fetch all users from users table
      final usersResponse = await _client
          .from('users')
          .select('id, role, is_archived');
      final userList = List<Map<String, dynamic>>.from(usersResponse as List);

      final teacherUsers = userList.where((u) => u['role'] == 'teacher').toList();
      final studentUsers = userList.where((u) => u['role'] == 'student').toList();
      final parentUsers = userList.where((u) => u['role'] == 'parent').toList();

      // Fetch teacher settings for status
      List<dynamic> teacherSettingsResp = [];
      try {
        teacherSettingsResp = (await _client.from('teacher_settings').select('teacher_id, status')) as List;
      } catch (_) {}
      final teacherSettingsMap = {
        for (var ts in teacherSettingsResp)
          ts['teacher_id']?.toString(): ts['status']?.toString()
      };

      // Fetch student settings for status
      List<dynamic> studentSettingsResp = [];
      try {
        studentSettingsResp = (await _client.from('student_settings').select('student_id, status')) as List;
      } catch (_) {}
      final studentSettingsMap = {
        for (var ss in studentSettingsResp)
          ss['student_id']?.toString(): ss['status']?.toString()
      };

      // Fetch parent profiles for status
      List<dynamic> parentProfilesResp = [];
      try {
        parentProfilesResp = (await _client.from('parent_profiles').select('parent_id, status')) as List;
      } catch (_) {}
      final parentStatusMap = {
        for (var pp in parentProfilesResp)
          pp['parent_id']?.toString(): pp['status']?.toString()
      };

      // 1. Teachers: active / total
      final totalTeachers = teacherUsers.length;
      final activeTeachers = teacherUsers.where((t) {
        final id = t['id']?.toString();
        final isArchived = t['is_archived'] == true;
        final status = teacherSettingsMap[id] ?? 'active';
        return !isArchived && status == 'active';
      }).length;

      // 2. Students: active / total
      final totalStudents = studentUsers.length;
      final activeStudents = studentUsers.where((s) {
        final id = s['id']?.toString();
        final isArchived = s['is_archived'] == true;
        final status = studentSettingsMap[id] ?? 'active';
        return !isArchived && status == 'active';
      }).length;

      // 3. Parents: active / total
      final totalParents = parentUsers.length;
      final activeParents = parentUsers.where((p) {
        final id = p['id']?.toString();
        final isArchived = p['is_archived'] == true;
        final status = parentStatusMap[id] ?? 'active';
        return !isArchived && status == 'active';
      }).length;

      // 4. Pending first login breakdown
      final pendingTeachers = teacherUsers.where((t) {
        final id = t['id']?.toString();
        return teacherSettingsMap[id] == 'pending_first_login';
      }).length;

      final pendingStudents = studentUsers.where((s) {
        final id = s['id']?.toString();
        return studentSettingsMap[id] == 'pending_first_login';
      }).length;

      final pendingParents = parentUsers.where((p) {
        final id = p['id']?.toString();
        return parentStatusMap[id] == 'pending_first_login';
      }).length;

      final totalPendingFirstLogin = pendingTeachers + pendingStudents + pendingParents;

      return {
        'totalTeachers': totalTeachers,
        'activeTeachers': activeTeachers,
        'totalStudents': totalStudents,
        'activeStudents': activeStudents,
        'totalParents': totalParents,
        'activeParents': activeParents,
        'pendingFirstLoginTotal': totalPendingFirstLogin,
        'pendingTeachers': pendingTeachers,
        'pendingStudents': pendingStudents,
        'pendingParents': pendingParents,
      };
    } catch (e) {
      debugPrint('AdminRepository getDashboardKpiMetrics error: $e');
      return {
        'totalTeachers': 0,
        'activeTeachers': 0,
        'totalStudents': 0,
        'activeStudents': 0,
        'totalParents': 0,
        'activeParents': 0,
        'pendingFirstLoginTotal': 0,
        'pendingTeachers': 0,
        'pendingStudents': 0,
        'pendingParents': 0,
      };
    }
  }
}
