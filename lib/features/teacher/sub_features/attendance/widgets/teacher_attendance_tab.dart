import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/repositories/attendance_repository.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/data/repositories/supabase_attendance_repository.dart';
import 'package:class_realm/features/teacher/sub_features/attendance/widgets/attendance_cutoff_dialog.dart';
import 'package:class_realm/features/teacher/sub_features/attendance/widgets/attendance_history_analytics_view.dart';
import 'package:class_realm/features/teacher/sub_features/attendance/widgets/attendance_roster_table.dart';
import 'package:class_realm/models/attendance_workspace_models.dart';
import 'package:class_realm/shared/widgets/modals/rfid_assignment_modal.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/shared/widgets/shimmer_loading.dart';
import 'package:class_realm/widgets/common/app_date_picker_field.dart';

enum _WorkspaceNoticeTone { success, warning, error, info }

class _WorkspaceInlineNotice {
  final _WorkspaceNoticeTone tone;
  final String title;
  final String message;
  final String? code;
  final String? scannedUid;
  final AttendanceStatus? status;
  final String? timeIn;

  const _WorkspaceInlineNotice({
    required this.tone,
    required this.title,
    required this.message,
    this.code,
    this.scannedUid,
    this.status,
    this.timeIn,
  });
}

class TeacherAttendanceTab extends StatefulWidget {
  final AttendanceRepository? repository;
  final List<Map<String, dynamic>>? initialSubjects;

  const TeacherAttendanceTab({
    super.key,
    this.repository,
    this.initialSubjects,
  });

  @override
  State<TeacherAttendanceTab> createState() => _TeacherAttendanceTabState();
}

class _TeacherAttendanceTabState extends State<TeacherAttendanceTab> {
  static final RegExp _hexUidRegex = RegExp(r'^[A-Fa-f0-9]{8,14}$');

  late final AttendanceRepository _repository;

  // USB / Keyboard-Wedge RFID Scanner State
  final FocusNode _scannerFocusNode = FocusNode();
  String _rfidBuffer = '';
  DateTime? _lastScannerKeyTime;
  bool _isProcessingScan = false;

  // Supabase Realtime Channel for Standalone ESP32 Sync
  RealtimeChannel? _attendanceRealtimeChannel;
  String? _subscribedOfferingId;

  List<Map<String, dynamic>> _teacherSubjects = [];
  String? _selectedGradeLevel;
  String? _selectedSubjectName;
  String? _selectedSubjectId;
  String? _subjectsLoadError;
  bool _isLoadingSubjects = true;

  String _selectedAttendanceView = 'Take Attendance';
  DateTime _attendanceSelectedDate = DateTime.now();
  String _attendanceSearchQuery = '';

  List<AttendanceRosterStudent> _rosterStudents = [];
  final Map<String, String?> _existingRecordIds = {};
  final Map<String, AttendanceStatus?> _tempAttendanceStates = {};
  Map<String, AttendanceStatus?> _initialAttendanceStates = {};
  final Map<String, String> _tempAttendanceRemarks = {};
  Map<String, String> _initialAttendanceRemarks = {};
  final Map<String, AttendanceSource> _tempAttendanceSources = {};
  final Map<String, String?> _tempAttendanceTimesIn = {};
  final Map<String, String?> _tempAttendanceDeviceIds = {};

  AttendanceScheduleStatus? _scheduleStatus;
  bool _manualMakeupOverride = false;
  _WorkspaceInlineNotice? _inlineNotice;

  bool _isLoadingRoster = false;
  String? _rosterLoadError;
  bool _isSavingBatch = false;
  bool _isOffline = false;
  String? _inlineLinkingStudentId;
  final GlobalKey<AttendanceHistoryAnalyticsViewState> _analyticsViewKey =
      GlobalKey<AttendanceHistoryAnalyticsViewState>();
  AttendanceDatePreset _selectedAnalyticsPreset = AttendanceDatePreset.thisWeek;
  late DateTime _analyticsCustomStartDate;
  late DateTime _analyticsCustomEndDate;

  int _rosterLoadRequest = 0;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupabaseAttendanceRepository.instance;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final min2026 = DateTime(2026, 1, 1);
    final sevenDaysAgo = today.subtract(const Duration(days: 7));
    _analyticsCustomStartDate = sevenDaysAgo.isBefore(min2026) ? min2026 : sevenDaysAgo;
    _analyticsCustomEndDate = today;
    HardwareKeyboard.instance.addHandler(_handleGlobalHardwareKey);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasEditableFocus()) {
        _scannerFocusNode.requestFocus();
      }
    });

    if (widget.initialSubjects != null) {
      _teacherSubjects = widget.initialSubjects!;
      _syncFilterSelection();
      _isLoadingSubjects = false;
      if (_selectedSubjectId != null) {
        _subscribeOfferingRealtime(_selectedSubjectId!);
        _loadRosterAndRecords(_selectedSubjectId!, _attendanceSelectedDate);
      }
    } else {
      _loadSubjects();
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalHardwareKey);
    _unsubscribeRealtime();
    _scannerFocusNode.dispose();
    super.dispose();
  }

  // ===========================================================================
  // Dirty State & Schedule Lock Helpers
  // ===========================================================================

  int get _dirtyCount {
    final allIds = <String>{
      ..._rosterStudents.map((s) => s.studentId),
      ..._tempAttendanceStates.keys,
      ..._initialAttendanceStates.keys,
      ..._tempAttendanceRemarks.keys,
      ..._initialAttendanceRemarks.keys,
    };
    int changed = 0;
    for (final sid in allIds) {
      final curStatus = _tempAttendanceStates[sid];
      final initStatus = _initialAttendanceStates[sid];
      final curRemark = (_tempAttendanceRemarks[sid] ?? '').trim();
      final initRemark = (_initialAttendanceRemarks[sid] ?? '').trim();
      if (curStatus != initStatus || curRemark != initRemark) {
        changed++;
      }
    }
    return changed;
  }

  bool get _isDirty => _dirtyCount > 0;

  bool get _isEffectivelyLocked {
    final sched = _scheduleStatus;
    if (sched == null) return false;
    if (sched.isHoliday) return true; // Holidays stay strictly locked
    return sched.isLockedByDefault && !_manualMakeupOverride;
  }

  AttendanceCutoffConfig get _activeCutoffConfig {
    final sid = _selectedSubjectId ?? '';
    return _scheduleStatus?.cutoffConfig ??
        AttendanceCutoffConfig(subjectOfferingId: sid);
  }

  // ===========================================================================
  // Cascading Subject / Section Helpers
  // ===========================================================================

  String _normalizeGradeLevel(dynamic g) {
    if (g == null) return 'Grade 11';
    final s = g.toString().trim();
    if (s.toLowerCase().startsWith('grade')) return s;
    return 'Grade $s';
  }

  List<String> get _gradeLevels {
    final set = <String>{};
    for (final s in _teacherSubjects) {
      final g = s['grade_level'];
      if (g != null) {
        set.add(_normalizeGradeLevel(g));
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  List<String> get _availableSubjects {
    final set = <String>{};
    for (final s in _teacherSubjects) {
      if (_normalizeGradeLevel(s['grade_level']) == _selectedGradeLevel) {
        final name = s['subject_name']?.toString().trim();
        if (name != null && name.isNotEmpty) {
          set.add(name);
        }
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  List<Map<String, dynamic>> get _availableSections {
    return _teacherSubjects.where((s) {
      final matchesGrade =
          _normalizeGradeLevel(s['grade_level']) == _selectedGradeLevel;
      final matchesSubject =
          (s['subject_name']?.toString().trim() ?? '') == _selectedSubjectName;
      return matchesGrade && matchesSubject;
    }).toList();
  }

  String _formatSectionDisplay(String secName) {
    final clean = secName.trim();
    if (clean.toLowerCase().startsWith('section')) {
      return clean;
    }
    return 'Section $clean';
  }

  Map<String, dynamic>? get _currentOffering {
    for (final subject in _teacherSubjects) {
      if (subject['id']?.toString() == _selectedSubjectId) {
        return subject;
      }
    }
    return null;
  }

  String _subjectLabel(Map<String, dynamic> subject) {
    final grade = _normalizeGradeLevel(subject['grade_level']);
    final section = _formatSectionDisplay(
      subject['section_name']?.toString() ?? 'Section',
    );
    final name = subject['subject_name']?.toString() ?? '';
    return [
      if (grade.isNotEmpty) grade,
      if (section.isNotEmpty) section,
      if (name.isNotEmpty) name,
    ].join(' • ');
  }

  String get _selectedSubjectLabel {
    final current = _currentOffering;
    if (current == null) return 'No subject or section selected';
    return _subjectLabel(current);
  }

  String? get _scheduleWindowSummary {
    final sched = _scheduleStatus;
    if (sched == null) return null;
    final start = sched.startTime?.trim();
    final end = sched.endTime?.trim();
    if (start == null || start.isEmpty) return null;
    final formattedStart = _formatClockShort(start);
    final formattedEnd = (end != null && end.isNotEmpty)
        ? _formatClockShort(end)
        : null;
    final roomPart = (sched.room != null && sched.room!.trim().isNotEmpty)
        ? ' • Room ${sched.room!.trim()}'
        : '';
    return formattedEnd != null
        ? '$formattedStart – $formattedEnd$roomPart'
        : '$formattedStart$roomPart';
  }

  static String _formatClockShort(String raw) {
    final parts = raw.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null && h >= 0 && h < 24) {
        final period = h >= 12 ? 'PM' : 'AM';
        final h12 = h % 12 == 0 ? 12 : h % 12;
        return '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
      }
    }
    return raw;
  }

  void _syncFilterSelection() {
    if (_teacherSubjects.isEmpty) {
      _selectedGradeLevel = null;
      _selectedSubjectName = null;
      _selectedSubjectId = null;
      return;
    }

    final grades = _gradeLevels;
    if (_selectedGradeLevel == null || !grades.contains(_selectedGradeLevel)) {
      _selectedGradeLevel = grades.isNotEmpty ? grades.first : null;
    }

    final subjects = _availableSubjects;
    if (_selectedSubjectName == null ||
        !subjects.contains(_selectedSubjectName)) {
      _selectedSubjectName = subjects.isNotEmpty ? subjects.first : null;
    }

    final sections = _availableSections;
    final matchingOffering = sections.firstWhere(
      (s) => s['id']?.toString() == _selectedSubjectId,
      orElse: () => sections.isNotEmpty ? sections.first : {},
    );
    _selectedSubjectId = matchingOffering['id']?.toString();
  }

  // ===========================================================================
  // Data Loading & Realtime Subscription
  // ===========================================================================

  void _unsubscribeRealtime() {
    final existing = _attendanceRealtimeChannel;
    _attendanceRealtimeChannel = null;
    _subscribedOfferingId = null;
    if (existing != null) {
      try {
        Supabase.instance.client.removeChannel(existing);
      } catch (_) {}
    }
  }

  void _subscribeOfferingRealtime(String subjectOfferingId) {
    if (_subscribedOfferingId == subjectOfferingId &&
        _attendanceRealtimeChannel != null) {
      return;
    }
    _unsubscribeRealtime();
    try {
      final client = Supabase.instance.client;
      _subscribedOfferingId = subjectOfferingId;
      _attendanceRealtimeChannel = client
          .channel('attendance_offering_$subjectOfferingId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'attendance_records',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'subject_offering_id',
              value: subjectOfferingId,
            ),
            callback: _handleRealtimeAttendancePayload,
          )
          .subscribe();
    } catch (_) {
      // Safe no-op in offline/unit-test environments where Supabase isn't initialized
      _subscribedOfferingId = null;
      _attendanceRealtimeChannel = null;
    }
  }

  void _handleRealtimeAttendancePayload(PostgresChangePayload payload) {
    if (!mounted) return;
    final row = payload.newRecord;
    if (row.isEmpty) return;

    final rowDate = row['attendance_date']?.toString() ?? '';
    final activeDate = _formatDate(_attendanceSelectedDate);
    if (rowDate.isNotEmpty && !rowDate.startsWith(activeDate)) return;

    final studentId = row['student_id']?.toString() ?? '';
    if (studentId.isEmpty) return;

    final statusRaw = row['status']?.toString().trim().toLowerCase() ?? '';
    AttendanceStatus? parsedStatus;
    for (final s in AttendanceStatus.values) {
      if (s.name == statusRaw) {
        parsedStatus = s;
        break;
      }
    }
    if (parsedStatus == null) return;

    final source = AttendanceSource.parse(
      row['recording_method']?.toString() ?? row['source']?.toString(),
    );
    final timeIn = row['time_in']?.toString();
    final deviceId = row['device_id']?.toString();
    final remarks = row['remarks']?.toString();
    final recId = row['id']?.toString();

    final matchedStudent = _rosterStudents
        .cast<AttendanceRosterStudent?>()
        .firstWhere((s) => s?.studentId == studentId, orElse: () => null);

    setState(() {
      if (recId != null && recId.isNotEmpty) {
        _existingRecordIds[studentId] = recId;
      }
      _tempAttendanceStates[studentId] = parsedStatus;
      _initialAttendanceStates[studentId] = parsedStatus;
      _tempAttendanceSources[studentId] = source;
      if (timeIn != null && timeIn.isNotEmpty) {
        _tempAttendanceTimesIn[studentId] = timeIn;
      }
      if (deviceId != null && deviceId.isNotEmpty) {
        _tempAttendanceDeviceIds[studentId] = deviceId;
      }
      if (remarks != null && remarks.trim().isNotEmpty) {
        _tempAttendanceRemarks[studentId] = remarks.trim();
        _initialAttendanceRemarks[studentId] = remarks.trim();
      }

      if (source == AttendanceSource.rfid &&
          deviceId != null &&
          deviceId != 'USB_SCANNER') {
        final nameLabel = matchedStudent?.displayName ?? studentId;
        _inlineNotice = _WorkspaceInlineNotice(
          tone: _WorkspaceNoticeTone.success,
          title: 'Live ESP32 RFID Scan Synced',
          message:
              '$nameLabel marked ${parsedStatus!.name.toUpperCase()}${timeIn != null ? ' at ${_formatClockFromAny(timeIn)}' : ''}.',
          status: parsedStatus,
          timeIn: timeIn,
        );
      }
    });
  }

  Future<void> _loadSubjects() async {
    final teacherId = AuthRepository.instance.currentUser?.id;
    if (teacherId == null) {
      setState(() {
        _isLoadingSubjects = false;
        _subjectsLoadError = 'Log in as a teacher to load your classes.';
      });
      return;
    }

    final cached = SubjectRepository.instance.getCachedTeacherSubjects(
      teacherId,
    );
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _teacherSubjects = cached;
        _syncFilterSelection();
        _isLoadingSubjects = false;
        _subjectsLoadError = null;
      });
      if (_selectedSubjectId != null) {
        _subscribeOfferingRealtime(_selectedSubjectId!);
        _loadRosterAndRecords(_selectedSubjectId!, _attendanceSelectedDate);
      }
    }

    try {
      var subjects = await SubjectRepository.instance.getTeacherSubjects(
        teacherId,
      );
      try {
        final schedRows = await Supabase.instance.client
            .from('teacher_schedule')
            .select('subject_offering_id')
            .eq('is_active', true);
        final scheduledOfferingIds = (schedRows as List)
            .map((r) => r['subject_offering_id']?.toString())
            .whereType<String>()
            .toSet();
        if (scheduledOfferingIds.isNotEmpty) {
          subjects = subjects
              .where((s) => scheduledOfferingIds.contains(s['id']?.toString()))
              .toList();
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _teacherSubjects = subjects;
        _syncFilterSelection();
        _isLoadingSubjects = false;
        _subjectsLoadError = null;
        _isOffline = false;
      });
      if (_selectedSubjectId != null) {
        _subscribeOfferingRealtime(_selectedSubjectId!);
        await _loadRosterAndRecords(
          _selectedSubjectId!,
          _attendanceSelectedDate,
        );
      }
    } catch (error) {
      debugPrint('Attendance subjects load notice: $error');
      if (!mounted) return;
      if (_teacherSubjects.isNotEmpty) {
        setState(() {
          _isLoadingSubjects = false;
          _isOffline = true;
          _subjectsLoadError = null;
        });
      } else {
        setState(() {
          _isLoadingSubjects = false;
          _isOffline = true;
          _subjectsLoadError =
              'Unable to connect to database. Please check your network.';
        });
      }
    }
  }

  Future<void> _loadRosterAndRecords(
    String subjectOfferingId,
    DateTime date,
  ) async {
    final request = ++_rosterLoadRequest;
    final dateStr = _formatDate(date);

    // 1. Instant local cache hydrate if switching into empty state
    try {
      final cachedRoster = LocalStorageService.getAttendanceRoster(
        subjectOfferingId,
      );
      final cachedRecords = LocalStorageService.getAttendanceRecords(
        subjectOfferingId,
        dateStr,
      );
      if (cachedRoster.isNotEmpty && _rosterStudents.isEmpty) {
        final cachedStudents = cachedRoster
            .map((m) => AttendanceRosterStudent.fromJson(m))
            .toList();
        _applyLoadedRecords(
          cachedStudents,
          cachedRecords.map(AttendanceWorkspaceRecord.fromJson).toList(),
        );
      } else if (_rosterStudents.isEmpty) {
        setState(() {
          _isLoadingRoster = true;
          _rosterLoadError = null;
        });
      }
    } catch (_) {
      if (_rosterStudents.isEmpty) {
        setState(() {
          _isLoadingRoster = true;
          _rosterLoadError = null;
        });
      }
    }

    try {
      final results = await Future.wait([
        _repository.getAttendanceRosterAndDateRecords(
          subjectOfferingId: subjectOfferingId,
          date: date,
        ),
        _repository.getScheduleAndCutoffStatus(
          subjectOfferingId: subjectOfferingId,
          date: date,
        ),
      ]);
      if (!mounted || request != _rosterLoadRequest) return;

      final rosterResult = results[0] as AttendanceRosterResult;
      final scheduleStatus = results[1] as AttendanceScheduleStatus;

      setState(() {
        _scheduleStatus = scheduleStatus;
        _isOffline = false;
        _rosterLoadError = null;
      });
      _applyLoadedRecords(rosterResult.students, rosterResult.records);

      // Flush any offline queued scans silently when back online
      unawaited(_repository.syncOfflineAttendanceQueue().catchError((_) => 0));
    } catch (error) {
      debugPrint('Attendance roster load notice: $error');
      if (!mounted || request != _rosterLoadRequest) return;
      if (_rosterStudents.isNotEmpty) {
        setState(() {
          _isLoadingRoster = false;
          _isOffline = true;
        });
      } else {
        setState(() {
          _isLoadingRoster = false;
          _rosterLoadError = 'Unable to fetch student roster. Please check your network connection.';
        });
      }
    }
  }

  void _applyLoadedRecords(
    List<AttendanceRosterStudent> students,
    List<AttendanceWorkspaceRecord> records,
  ) {
    final ids = <String, String?>{};
    final states = <String, AttendanceStatus?>{};
    final remarks = <String, String>{};
    final sources = <String, AttendanceSource>{};
    final times = <String, String?>{};
    final devices = <String, String?>{};

    for (final rec in records) {
      ids[rec.studentId] = rec.id;
      states[rec.studentId] = rec.status;
      sources[rec.studentId] = rec.source;
      if (rec.timeIn != null && rec.timeIn!.trim().isNotEmpty) {
        times[rec.studentId] = rec.timeIn!.trim();
      }
      if (rec.deviceId != null && rec.deviceId!.trim().isNotEmpty) {
        devices[rec.studentId] = rec.deviceId!.trim();
      }
      if (rec.remarks != null && rec.remarks!.trim().isNotEmpty) {
        remarks[rec.studentId] = rec.remarks!.trim();
      }
    }

    setState(() {
      _rosterStudents = students;
      _existingRecordIds
        ..clear()
        ..addAll(ids);
      _tempAttendanceStates
        ..clear()
        ..addAll(states);
      _initialAttendanceStates = Map.from(states);
      _tempAttendanceRemarks
        ..clear()
        ..addAll(remarks);
      _initialAttendanceRemarks = Map.from(remarks);
      _tempAttendanceSources
        ..clear()
        ..addAll(sources);
      _tempAttendanceTimesIn
        ..clear()
        ..addAll(times);
      _tempAttendanceDeviceIds
        ..clear()
        ..addAll(devices);
      _isLoadingRoster = false;
    });
  }

  // ===========================================================================
  // Live USB / Keyboard-Wedge RFID Scanning
  // ===========================================================================

  bool _hasEditableFocus() {
    final primaryFocus = FocusManager.instance.primaryFocus;
    final ctx = primaryFocus?.context;
    if (ctx == null) return false;
    if (ctx.widget is EditableText) return true;
    return ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  bool _handleGlobalHardwareKey(KeyEvent event) {
    if (!mounted) return false;
    if (_selectedAttendanceView != 'Take Attendance') return false;
    if (_selectedSubjectId == null) return false;

    // Ignore when a modal/dialog route is active above this tab
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;

    // Ignore when user is actively typing inside a TextField
    if (_hasEditableFocus()) return false;

    if (event is KeyDownEvent) {
      final now = DateTime.now();
      if (_lastScannerKeyTime != null &&
          now.difference(_lastScannerKeyTime!).inMilliseconds > 1500) {
        _rfidBuffer = '';
      }
      _lastScannerKeyTime = now;

      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        final rawScanned = _rfidBuffer.trim().toUpperCase();
        _rfidBuffer = '';
        if (rawScanned.isNotEmpty) {
          if (_inlineLinkingStudentId != null) {
            final targetId = _inlineLinkingStudentId!;
            setState(() => _inlineLinkingStudentId = null);
            unawaited(_assignRfidDirectly(targetId, rawScanned));
            return true;
          }
          _processScannedRfid(rawScanned);
          return true;
        }
      } else {
        final char = event.character;
        if (char != null && char.trim().isNotEmpty) {
          _rfidBuffer += char.trim().toUpperCase();
        }
      }
    }
    return false;
  }

  Future<void> _processScannedRfid(String scannedUid) async {
    if (_selectedSubjectId == null || _isProcessingScan) return;

    if (!_hexUidRegex.hasMatch(scannedUid)) {
      setState(() {
        _inlineNotice = _WorkspaceInlineNotice(
          tone: _WorkspaceNoticeTone.warning,
          title: 'Invalid RFID Card Format',
          message:
              'Scanned code "$scannedUid" is not a valid 8–14 character hexadecimal RFID UID.',
          code: 'INVALID_UID',
        );
      });
      return;
    }

    if (_isEffectivelyLocked) {
      setState(() {
        _inlineNotice = _WorkspaceInlineNotice(
          tone: _WorkspaceNoticeTone.warning,
          title: 'RFID Scan Blocked — Session Locked',
          message: _scheduleStatus?.lockReason ?? 'Enable Make-Up Class Override to record RFID scans for this unscheduled session.',
          code: 'SCHEDULE_LOCKED',
          scannedUid: scannedUid,
        );
      });
      return;
    }

    setState(() => _isProcessingScan = true);

    try {
      final outcome = await _repository.recordRfidScan(
        rfidUid: scannedUid,
        subjectOfferingId: _selectedSubjectId!,
        scanTimestamp: DateTime.now(),
        deviceId: 'USB_SCANNER',
      );
      if (!mounted) return;

      final matchedStudent = _rosterStudents
          .cast<AttendanceRosterStudent?>()
          .firstWhere(
            (s) =>
                (outcome.studentId != null &&
                    s?.studentId == outcome.studentId) ||
                (s?.rfidUid?.trim().toUpperCase() == scannedUid),
            orElse: () => null,
          );

      setState(() {
        _isProcessingScan = false;
        if (outcome.isOfflineQueued) {
          _isOffline = true;
        }

        if (outcome.success) {
          final targetId = outcome.studentId ?? matchedStudent?.studentId;
          final effectiveStatus = outcome.status ?? AttendanceStatus.present;
          final effectiveTime =
              outcome.timeIn ?? _formatTimeHHmmss(DateTime.now());
          if (targetId != null) {
            _tempAttendanceStates[targetId] = effectiveStatus;
            _initialAttendanceStates[targetId] = effectiveStatus;
            _tempAttendanceSources[targetId] = AttendanceSource.rfid;
            _tempAttendanceTimesIn[targetId] = effectiveTime;
            _tempAttendanceDeviceIds[targetId] = 'USB_SCANNER';
          }

          final studentDisplay =
              outcome.studentName ?? matchedStudent?.displayName ?? scannedUid;
          _inlineNotice = _WorkspaceInlineNotice(
            tone: outcome.isOfflineQueued
                ? _WorkspaceNoticeTone.warning
                : _WorkspaceNoticeTone.success,
            title: outcome.isOfflineQueued
                ? 'RFID Scan Queued Offline'
                : (outcome.code == 'PROMOTED_PRESENT'
                      ? 'RFID Scan Recorded — Status Promoted'
                      : 'RFID Scan Recorded'),
            message: outcome.message.isNotEmpty
                ? outcome.message
                : '$studentDisplay marked ${effectiveStatus.name.toUpperCase()} at ${_formatClockFromAny(effectiveTime)}.',
            code: outcome.code,
            scannedUid: scannedUid,
            status: effectiveStatus,
            timeIn: effectiveTime,
          );
        } else {
          final isUnregistered = outcome.code == 'UNREGISTERED_CARD';
          _inlineNotice = _WorkspaceInlineNotice(
            tone: isUnregistered
                ? _WorkspaceNoticeTone.warning
                : _WorkspaceNoticeTone.error,
            title: isUnregistered
                ? 'Unregistered RFID Card ($scannedUid)'
                : 'RFID Scan Not Recorded',
            message: outcome.message.isNotEmpty
                ? outcome.message
                : 'Card $scannedUid could not be recorded for this class session.',
            code: outcome.code,
            scannedUid: scannedUid,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessingScan = false;
        _inlineNotice = _WorkspaceInlineNotice(
          tone: _WorkspaceNoticeTone.error,
          title: 'RFID Scanner Error',
          message: AppModals.sanitizeErrorMessage(e),
          scannedUid: scannedUid,
        );
      });
    }
  }

  // ===========================================================================
  // RFID Card Linking & Unregistered Card Quick-Assign
  // ===========================================================================

  Future<void> _assignRfidDirectly(String studentId, String scannedUid) async {
    try {
      await _repository.assignStudentRfid(
        studentId: studentId,
        rfidUid: scannedUid,
      );
      if (!mounted) return;
      final matched = _rosterStudents
          .cast<AttendanceRosterStudent?>()
          .firstWhere((s) => s?.studentId == studentId, orElse: () => null);
      final studentName = matched?.displayName ?? studentId;
      setState(() {
        _rosterStudents = _rosterStudents
            .map(
              (s) => s.studentId == studentId
                  ? s.copyWith(rfidUid: scannedUid)
                  : s,
            )
            .toList();
        _inlineNotice = _WorkspaceInlineNotice(
          tone: _WorkspaceNoticeTone.success,
          title: 'RFID Card Linked',
          message: 'Card $scannedUid has been linked to $studentName.',
          scannedUid: scannedUid,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _inlineNotice = _WorkspaceInlineNotice(
          tone: _WorkspaceNoticeTone.error,
          title: 'Card Linking Failed',
          message: 'Unable to link RFID card: $e',
        );
      });
    }
  }

  Future<void> _openLinkRfidForStudent(
    AttendanceRosterStudent student, {
    String? prefillUid,
  }) async {
    final result = await RfidAssignmentModal.show(
      context,
      studentId: student.studentId,
      studentName: student.displayName,
      lrn: student.lrn,
      currentRfidUid: student.rfidUid,
      prefillRfidUid: prefillUid,
      repository: _repository,
    );

    if (result == null || !mounted) return;

    final isUnlinked = result.isEmpty;
    setState(() {
      _rosterStudents = _rosterStudents.map((s) {
        if (s.studentId == student.studentId) {
          return isUnlinked
              ? s.copyWith(clearRfidUid: true)
              : s.copyWith(rfidUid: result);
        }
        // Clear any previous student in this roster who held the reassigned UID
        if (!isUnlinked &&
            s.rfidUid?.trim().toUpperCase() == result.toUpperCase()) {
          return s.copyWith(clearRfidUid: true);
        }
        return s;
      }).toList();

      _inlineNotice = _WorkspaceInlineNotice(
        tone: _WorkspaceNoticeTone.success,
        title: isUnlinked ? 'RFID Card Unlinked' : 'RFID Card Linked',
        message: isUnlinked
            ? 'Unlinked RFID card from ${student.displayName}.'
            : 'RFID card $result is now linked to ${student.displayName}.',
      );
    });
  }

  Future<void> _openAssignUnregisteredCardPicker(String scannedUid) async {
    if (_rosterStudents.isEmpty) return;

    final sorted = List<AttendanceRosterStudent>.from(_rosterStudents)
      ..sort((a, b) {
        final cmp = a.lastName.toLowerCase().compareTo(
          b.lastName.toLowerCase(),
        );
        if (cmp != 0) return cmp;
        return a.firstName.toLowerCase().compareTo(b.firstName.toLowerCase());
      });

    final chosen = await _SelectStudentForRfidDialog.show(
      context,
      students: sorted,
      scannedUid: scannedUid,
    );
    if (chosen == null || !mounted) return;

    await _openLinkRfidForStudent(chosen, prefillUid: scannedUid);
  }

  // ===========================================================================
  // Cutoff Rules, Override & Batch Save Actions
  // ===========================================================================

  Future<void> _openCutoffRulesDialog() async {
    if (_selectedSubjectId == null) return;
    final updated = await AttendanceCutoffDialog.show(
      context,
      initialConfig: _activeCutoffConfig,
      subjectLabel: _selectedSubjectLabel,
      scheduleTimeLabel: _scheduleWindowSummary,
      repository: _repository,
    );
    if (updated == null || !mounted) return;

    setState(() {
      final prev = _scheduleStatus;
      _scheduleStatus = AttendanceScheduleStatus(
        hasPlottedScheduleAnyDay: prev?.hasPlottedScheduleAnyDay ?? false,
        isScheduledOnDate: prev?.isScheduledOnDate ?? true,
        isHoliday: prev?.isHoliday ?? false,
        holidayName: prev?.holidayName,
        startTime: prev?.startTime,
        endTime: prev?.endTime,
        room: prev?.room,
        cutoffConfig: updated,
      );
      _inlineNotice = _WorkspaceInlineNotice(
        tone: _WorkspaceNoticeTone.success,
        title: 'Cutoff Rules Saved',
        message:
            'Present grace: +${updated.presentGraceMins}m • Late cutoff: +${updated.lateCutoffMins}m • Auto-Absent: +${updated.absentCutoffMins}m.',
      );
    });
  }

  Future<void> _confirmMakeupOverride() async {
    final confirmed = await AppModals.showConfirmDialog(
      context: context,
      title: 'Enable Make-Up Class Override?',
      message:
          'No regular session is plotted for $_selectedSubjectLabel on ${_formatDate(_attendanceSelectedDate)}. Enable make-up class override to unlock manual attendance and live RFID scanning for this date?',
      confirmLabel: 'Enable Override',
      confirmColor: AppTheme.catOrange,
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _manualMakeupOverride = true;
      _inlineNotice = _WorkspaceInlineNotice(
        tone: _WorkspaceNoticeTone.info,
        title: 'Make-Up Class Override Active',
        message: 'Attendance recording and RFID scanning are unlocked for this make-up session.',
      );
    });
  }

  void _markAllPresent() {
    if (_isEffectivelyLocked) return;
    final nowStr = _formatTimeHHmmss(DateTime.now());
    setState(() {
      for (final s in _rosterStudents) {
        _tempAttendanceStates[s.studentId] = AttendanceStatus.present;
        _tempAttendanceSources[s.studentId] = AttendanceSource.manual;
        _tempAttendanceTimesIn[s.studentId] ??= nowStr;
        _tempAttendanceDeviceIds.remove(s.studentId);
        if (_tempAttendanceRemarks[s.studentId] == 'Auto-Absent') {
          _tempAttendanceRemarks.remove(s.studentId);
        }
      }
    });
  }

  void _autoAbsentUnmarked() {
    if (_isEffectivelyLocked) return;
    int affected = 0;
    setState(() {
      for (final student in _rosterStudents) {
        if (_tempAttendanceStates[student.studentId] == null) {
          _tempAttendanceStates[student.studentId] = AttendanceStatus.absent;
          _tempAttendanceSources[student.studentId] = AttendanceSource.system;
          _tempAttendanceTimesIn.remove(student.studentId);
          _tempAttendanceDeviceIds.remove(student.studentId);
          _tempAttendanceRemarks[student.studentId] = 'Auto-Absent';
          affected++;
        }
      }
      if (affected > 0) {
        _inlineNotice = _WorkspaceInlineNotice(
          tone: _WorkspaceNoticeTone.info,
          title: 'Auto-Absent Applied to Unmarked Students',
          message:
              'Marked $affected unmarked student${affected == 1 ? '' : 's'} as Absent (System). Click Save Attendance to commit changes.',
        );
      }
    });
  }

  Future<bool> _promptDiscardIfDirty() async {
    if (!_isDirty) return true;

    final shouldDiscard = await AppModals.showConfirmDialog(
      context: context,
      title: 'Discard Unsaved Attendance Changes?',
      message:
          'You have $_dirtyCount unsaved attendance change${_dirtyCount == 1 ? '' : 's'}. Switching class, date, or view will discard these changes.',
      confirmLabel: 'Discard Changes',
      cancelLabel: 'Keep Editing',
      confirmColor: AppTheme.catRed,
    );
    return shouldDiscard == true;
  }

  Future<void> _onGradeLevelChanged(String? newGrade) async {
    if (newGrade == null || newGrade == _selectedGradeLevel) return;
    if (!await _promptDiscardIfDirty()) return;

    setState(() {
      _selectedGradeLevel = newGrade;
      final subs = _availableSubjects;
      _selectedSubjectName = subs.isNotEmpty ? subs.first : null;
      final secs = _availableSections;
      _selectedSubjectId = secs.isNotEmpty
          ? secs.first['id']?.toString()
          : null;
      _manualMakeupOverride = false;
      _inlineNotice = null;
      _rosterStudents = [];
    });

    if (_selectedSubjectId != null) {
      _subscribeOfferingRealtime(_selectedSubjectId!);
      _loadRosterAndRecords(_selectedSubjectId!, _attendanceSelectedDate);
    }
  }

  Future<void> _onSubjectNameChanged(String? newSubject) async {
    if (newSubject == null || newSubject == _selectedSubjectName) return;
    if (!await _promptDiscardIfDirty()) return;

    setState(() {
      _selectedSubjectName = newSubject;
      final secs = _availableSections;
      _selectedSubjectId = secs.isNotEmpty
          ? secs.first['id']?.toString()
          : null;
      _manualMakeupOverride = false;
      _inlineNotice = null;
      _rosterStudents = [];
    });

    if (_selectedSubjectId != null) {
      _subscribeOfferingRealtime(_selectedSubjectId!);
      _loadRosterAndRecords(_selectedSubjectId!, _attendanceSelectedDate);
    }
  }

  Future<void> _onSectionChanged(String? newOfferingId) async {
    if (newOfferingId == null || newOfferingId == _selectedSubjectId) return;
    if (!await _promptDiscardIfDirty()) return;

    setState(() {
      _selectedSubjectId = newOfferingId;
      _manualMakeupOverride = false;
      _inlineNotice = null;
      _rosterStudents = [];
    });

    _subscribeOfferingRealtime(newOfferingId);
    _loadRosterAndRecords(newOfferingId, _attendanceSelectedDate);
  }

  Future<void> _onDateChanged(DateTime newDate) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final min2026 = DateTime(2026, 1, 1);
    final targetDate = DateTime(newDate.year, newDate.month, newDate.day);
    if (targetDate.isAfter(today) || targetDate.isBefore(min2026)) return;
    if (_isSameDay(newDate, _attendanceSelectedDate)) return;
    if (!await _promptDiscardIfDirty()) return;

    setState(() {
      _attendanceSelectedDate = newDate;
      _manualMakeupOverride = false;
      _inlineNotice = null;
    });
    if (_selectedSubjectId != null) {
      _loadRosterAndRecords(_selectedSubjectId!, newDate);
    }
  }

  Future<void> _onViewModeChanged(String targetView) async {
    if (targetView == _selectedAttendanceView) return;
    if (_selectedAttendanceView == 'Take Attendance' &&
        !await _promptDiscardIfDirty()) {
      return;
    }
    setState(() => _selectedAttendanceView = targetView);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _saveBatch() async {
    if (_selectedSubjectId == null || _isSavingBatch || _isEffectivelyLocked) {
      return;
    }
    setState(() => _isSavingBatch = true);

    try {
      final recordsToSave = <AttendanceWorkspaceRecord>[];
      final studentIdsToDelete = <String>[];
      for (final student in _rosterStudents) {
        final currentStatus = _tempAttendanceStates[student.studentId];
        if (currentStatus == null) {
          studentIdsToDelete.add(student.studentId);
          continue;
        }
        final finalRemark = _tempAttendanceRemarks[student.studentId];
        final source =
            _tempAttendanceSources[student.studentId] ??
            AttendanceSource.manual;
        final timeIn = _tempAttendanceTimesIn[student.studentId];
        final deviceId = _tempAttendanceDeviceIds[student.studentId];

        recordsToSave.add(
          AttendanceWorkspaceRecord(
            id: _existingRecordIds[student.studentId],
            studentId: student.studentId,
            subjectOfferingId: _selectedSubjectId!,
            attendanceDate: _attendanceSelectedDate,
            status: currentStatus,
            source: source,
            remarks: (finalRemark != null && finalRemark.trim().isNotEmpty)
                ? finalRemark.trim()
                : null,
            timeIn: timeIn,
            deviceId: deviceId,
          ),
        );
      }

      await _repository.saveAttendanceBatch(
        subjectOfferingId: _selectedSubjectId!,
        date: _attendanceSelectedDate,
        records: recordsToSave,
        deletedStudentIds: studentIdsToDelete,
      );

      for (final id in studentIdsToDelete) {
        _existingRecordIds.remove(id);
      }

      if (!mounted) return;
      setState(() {
        _initialAttendanceStates = Map.from(_tempAttendanceStates);
        _initialAttendanceRemarks = Map.from(_tempAttendanceRemarks);
        _isSavingBatch = false;
        _inlineNotice = null;
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Attendance saved (${recordsToSave.length} record${recordsToSave.length == 1 ? '' : 's'}) for ${_formatDate(_attendanceSelectedDate)}.',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Save batch notice: $e');
      if (!mounted) return;
      setState(() => _isSavingBatch = false);
      await AppModals.showErrorDialog(
        context: context,
        title: 'Failed to Save Attendance',
        message: e.toString(),
      );
    }
  }

  // ===========================================================================
  // Formatting Utilities
  // ===========================================================================

  static String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _formatTimeHHmmss(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  static String _formatClockFromAny(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt != null) {
      final local = dt.toLocal();
      return _formatClockShort(
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}',
      );
    }
    return _formatClockShort(raw);
  }

  // ===========================================================================
  // UI Build
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    int countStatus(AttendanceStatus status) => _rosterStudents
        .where((s) => _tempAttendanceStates[s.studentId] == status)
        .length;

    final presentCount = countStatus(AttendanceStatus.present);
    final lateCount = countStatus(AttendanceStatus.late);
    final absentCount = countStatus(AttendanceStatus.absent);
    final excusedCount = countStatus(AttendanceStatus.excused);
    final rfidLinkedCount = _rosterStudents
        .where((s) => s.hasRfidAssigned)
        .length;
    final totalCount = _rosterStudents.length;

    return Focus(
      focusNode: _scannerFocusNode,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── PERSISTENT TOP ACTION HEADER ──
            _buildPersistentTopHeader(theme, isDark),
            const SizedBox(height: 16),

            if (_isLoadingSubjects && _teacherSubjects.isEmpty)
              const ShimmerAttendanceSkeleton()
            else if (_subjectsLoadError != null && _teacherSubjects.isEmpty)
              _buildErrorContainer(
                theme,
                _subjectsLoadError!,
                onRetry: _loadSubjects,
              )
            else if (_teacherSubjects.isEmpty)
              _buildNoClassesAvailable(theme)
            else ...[

              // ── CASCADING FILTERS & DATE SELECTOR ──
              _buildClassAndDateControls(theme, isDark),
              const SizedBox(height: 14),

              if (_selectedAttendanceView == 'Take Attendance') ...[
                // ── SCHEDULE / HOLIDAY GUARD BANNER (R3) ──
                if (_scheduleStatus != null &&
                    _scheduleStatus!.isLockedByDefault)
                  _buildScheduleGuardBanner(theme, isDark),

                // ── LIVE SCAN / WORKSPACE INLINE FEEDBACK BANNER ──
                if (_inlineNotice != null)
                  _buildInlineWorkspaceNotice(theme, isDark, _inlineNotice!),

                // ── KPI METRIC STRIP ──
                _buildKpiSummaryStrip(
                  theme: theme,
                  isDark: isDark,
                  totalCount: totalCount,
                  rfidLinkedCount: rfidLinkedCount,
                  presentCount: presentCount,
                  lateCount: lateCount,
                  absentCount: absentCount,
                  excusedCount: excusedCount,
                ),
                const SizedBox(height: 14),

                // ── DEPED SF2 COMPACT UNIFIED ROSTER TABLE ──
                AttendanceRosterTable(
                  students: _rosterStudents,
                  statuses: _tempAttendanceStates,
                  sources: _tempAttendanceSources,
                  timesIn: _tempAttendanceTimesIn,
                  remarks: _tempAttendanceRemarks,
                  searchQuery: _attendanceSearchQuery,
                  onSearchChanged: (q) =>
                      setState(() => _attendanceSearchQuery = q),
                  isLocked: _isEffectivelyLocked,
                  isLoading: _isLoadingRoster,
                  errorMessage: _rosterLoadError,
                  onRetry: _selectedSubjectId != null
                      ? () => _loadRosterAndRecords(
                          _selectedSubjectId!,
                          _attendanceSelectedDate,
                        )
                      : null,
                  onStatusChanged: (studentId, newStatus) {
                    setState(() {
                      if (newStatus == null) {
                        _tempAttendanceStates.remove(studentId);
                        _tempAttendanceSources.remove(studentId);
                        _tempAttendanceTimesIn.remove(studentId);
                        _tempAttendanceDeviceIds.remove(studentId);
                      } else {
                        _tempAttendanceStates[studentId] = newStatus;
                        _tempAttendanceSources[studentId] =
                            AttendanceSource.manual;
                        _tempAttendanceDeviceIds.remove(studentId);
                        if (newStatus == AttendanceStatus.present ||
                            newStatus == AttendanceStatus.late) {
                          _tempAttendanceTimesIn[studentId] ??=
                              _formatTimeHHmmss(DateTime.now());
                        } else {
                          _tempAttendanceTimesIn.remove(studentId);
                        }
                      }
                    });
                  },
                  onRemarkChanged: (studentId, remark) {
                    setState(() {
                      if (remark == null || remark.isEmpty) {
                        _tempAttendanceRemarks.remove(studentId);
                      } else {
                        _tempAttendanceRemarks[studentId] = remark;
                      }
                    });
                  },
                  onLinkRfidTap: _openLinkRfidForStudent,
                  onMarkAllPresent: _markAllPresent,
                  onAutoAbsentUnmarked: _autoAbsentUnmarked,
                  linkingStudentId: _inlineLinkingStudentId,
                  onStartLinkingRfid: (student) => setState(
                    () => _inlineLinkingStudentId = student.studentId,
                  ),
                  onCancelLinkingRfid: () =>
                      setState(() => _inlineLinkingStudentId = null),
                  onSaveAttendance: _isEffectivelyLocked ? null : _saveBatch,
                  dirtyCount: _dirtyCount,
                  isSavingBatch: _isSavingBatch,
                ),
              ] else ...[
                if (_selectedSubjectId != null)
                  AttendanceHistoryAnalyticsView(
                    key: _analyticsViewKey,
                    subjectOfferingId: _selectedSubjectId!,
                    repository: _repository,
                    students: _rosterStudents,
                    hideFilterBar: true,
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPersistentTopHeader(ThemeData theme, bool isDark) {
    // Live RFID Scanner Status Indicator
    final String scannerLabel;
    final Color scannerColor;
    final IconData scannerIcon;
    if (_isEffectivelyLocked) {
      scannerLabel = 'Schedule Locked';
      scannerColor = _scheduleStatus?.isHoliday == true
          ? AppTheme.catRed
          : AppTheme.catOrange;
      scannerIcon = LucideIcons.lock;
    } else if (_isOffline) {
      scannerLabel = 'Offline Spool';
      scannerColor = AppTheme.catOrange;
      scannerIcon = LucideIcons.databaseBackup;
    } else {
      scannerLabel = 'RFID Ready';
      scannerColor = AppTheme.catTeal;
      scannerIcon = Icons.contactless_rounded;
    }

    final scheduleSummary = _scheduleWindowSummary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(
            alpha: isDark ? 0.12 : 0.1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          // Title & Active Offering Subtitle
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.calendarCheck2,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Attendance Workspace',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                  // Live RFID Scanner Status Pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scannerColor.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: scannerColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isProcessingScan)
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scannerColor,
                            ),
                          )
                        else
                          Icon(
                            scannerIcon,
                            size: 13.5,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.9)
                                : scannerColor,
                          ),
                        const SizedBox(width: 5),
                        Text(
                          scannerLabel,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.92)
                                : scannerColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                scheduleSummary != null
                    ? '$_selectedSubjectLabel • $scheduleSummary'
                    : _selectedSubjectLabel,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.64),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          // Action Controls: Cutoff Rules before Mode Toggle + Analytics & History
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (_selectedSubjectId != null)
                AppSecondaryButton(
                  label: 'Cutoff Rules',
                  icon: LucideIcons.clock4,
                  height: 38,
                  onPressed: _openCutoffRulesDialog,
                ),

              // Mode Toggle
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(
                    alpha: isDark ? 0.08 : 0.05,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _selectedAttendanceView == 'Take Attendance'
                        ? AppButton.primary(
                            icon: LucideIcons.clipboardCheck,
                            label: 'Take Attendance',
                            isSmall: true,
                            onPressed: () {},
                          )
                        : AppButton.ghost(
                            icon: LucideIcons.clipboardCheck,
                            label: 'Take Attendance',
                            isSmall: true,
                            onPressed: () =>
                                _onViewModeChanged('Take Attendance'),
                          ),
                    const SizedBox(width: 4),
                    _selectedAttendanceView == 'Analytics & History'
                        ? AppButton.primary(
                            icon: LucideIcons.barChart3,
                            label: 'Analytics & History',
                            isSmall: true,
                            onPressed: () {},
                          )
                        : AppButton.ghost(
                            icon: LucideIcons.barChart3,
                            label: 'Analytics & History',
                            isSmall: true,
                            onPressed: () =>
                                _onViewModeChanged('Analytics & History'),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsPresetBtn(
    String label,
    AttendanceDatePreset preset,
    ThemeData theme,
  ) {
    final isSelected = _selectedAnalyticsPreset == preset;
    return isSelected
        ? AppButton.primary(label: label, isSmall: true, onPressed: () {})
        : AppButton.outline(
            label: label,
            isSmall: true,
            onPressed: () {
              setState(() => _selectedAnalyticsPreset = preset);
              if (preset == AttendanceDatePreset.custom) {
                if (!_analyticsCustomStartDate.isAfter(_analyticsCustomEndDate)) {
                  _analyticsViewKey.currentState?.setCustomRange(
                    _analyticsCustomStartDate,
                    _analyticsCustomEndDate,
                  );
                }
              } else {
                _analyticsViewKey.currentState?.setPreset(preset);
              }
            },
          );
  }

  Widget _buildClassAndDateControls(ThemeData theme, bool isDark) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final min2026 = DateTime(2026, 1, 1);
    final isToday = _isSameDay(_attendanceSelectedDate, now);
    final isSelectedTodayOrFuture = !_attendanceSelectedDate.isBefore(today);
    final isEarliestAllowed = !_attendanceSelectedDate.isAfter(min2026);
    final borderColor = theme.colorScheme.onSurface.withValues(
      alpha: isDark ? 0.14 : 0.12,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              _buildFilterDropdown(
                label: 'Grade Level',
                icon: LucideIcons.graduationCap,
                value: _selectedGradeLevel,
                items: _gradeLevels,
                onChanged: _onGradeLevelChanged,
                itemLabel: (val) => val,
                theme: theme,
                isDark: isDark,
              ),
              _buildFilterDropdown(
                label: 'Subject',
                icon: LucideIcons.bookOpen,
                value: _selectedSubjectName,
                items: _availableSubjects,
                onChanged: _onSubjectNameChanged,
                itemLabel: (val) => val,
                theme: theme,
                isDark: isDark,
              ),
              _buildFilterDropdown(
                label: 'Section',
                icon: LucideIcons.users,
                value: _selectedSubjectId,
                items: _availableSections
                    .map((s) => s['id']?.toString() ?? '')
                    .toList(),
                onChanged: _onSectionChanged,
                itemLabel: (id) {
                  final match = _availableSections.firstWhere(
                    (s) => s['id']?.toString() == id,
                    orElse: () => {},
                  );
                  return _formatSectionDisplay(
                    match['section_name']?.toString() ?? 'Section',
                  );
                },
                theme: theme,
                isDark: isDark,
              ),
            ],
          ),

          if (_selectedAttendanceView == 'Take Attendance')
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Session Date',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: isDark ? 0.18 : 0.16,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: isEarliestAllowed
                                ? '2026 is the earliest allowed date'
                                : 'Previous Day',
                            icon: Icon(
                              LucideIcons.chevronLeft,
                              size: 15,
                              color: isEarliestAllowed
                                  ? theme.colorScheme.onSurface.withValues(
                                      alpha: 0.25,
                                    )
                                  : theme.colorScheme.onSurface,
                            ),
                            onPressed: isEarliestAllowed
                                ? null
                                : () => _onDateChanged(
                                      _attendanceSelectedDate.subtract(
                                        const Duration(days: 1),
                                      ),
                                    ),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            constraints: const BoxConstraints(),
                          ),
                          InkWell(
                            onTap: () async {
                              final initial = _attendanceSelectedDate.isBefore(min2026)
                                  ? min2026
                                  : (_attendanceSelectedDate.isAfter(today)
                                      ? today
                                      : _attendanceSelectedDate);
                              final picked = await showAppDatePickerDialog(
                                context,
                                initialDate: initial,
                                firstDate: min2026,
                                lastDate: today,
                                title: 'Select Attendance Date',
                              );
                              if (picked != null) {
                                _onDateChanged(picked);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.calendar,
                                    size: 14,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatDate(_attendanceSelectedDate),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: isSelectedTodayOrFuture
                                ? 'Future dates are locked'
                                : 'Next Day',
                            icon: Icon(
                              LucideIcons.chevronRight,
                              size: 15,
                              color: isSelectedTodayOrFuture
                                  ? theme.colorScheme.onSurface.withValues(
                                      alpha: 0.25,
                                    )
                                  : theme.colorScheme.onSurface,
                            ),
                            onPressed: isSelectedTodayOrFuture
                                ? null
                                : () => _onDateChanged(
                                      _attendanceSelectedDate.add(
                                        const Duration(days: 1),
                                      ),
                                    ),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!isToday)
                  SizedBox(
                    height: 38,
                    child: AppButton.outline(
                      label: 'Today',
                      isSmall: true,
                      onPressed: () => _onDateChanged(DateTime.now()),
                    ),
                  ),
              ],
            )
          else ...[
            // Inside filter box for Analytics & History: presets + Export CSV
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildAnalyticsPresetBtn(
                  'This Week',
                  AttendanceDatePreset.thisWeek,
                  theme,
                ),
                _buildAnalyticsPresetBtn(
                  'This Month',
                  AttendanceDatePreset.thisMonth,
                  theme,
                ),
                _buildAnalyticsPresetBtn(
                  'Custom',
                  AttendanceDatePreset.custom,
                  theme,
                ),
                AppButton.outline(
                  label: 'Export CSV',
                  icon: Icons.download_rounded,
                  isSmall: true,
                  onPressed: () =>
                      _analyticsViewKey.currentState?.exportSf2Csv(),
                ),
              ],
            ),
            if (_selectedAnalyticsPreset == AttendanceDatePreset.custom) ...[
              const SizedBox(height: 12),
              _buildAnalyticsCustomDateRangeRow(theme, isDark, today, min2026),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildAnalyticsCustomDateRangeRow(
    ThemeData theme,
    bool isDark,
    DateTime today,
    DateTime min2026,
  ) {
    final hasRangeError =
        _analyticsCustomStartDate.isAfter(_analyticsCustomEndDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            InkWell(
              onTap: () async {
                final initial = _analyticsCustomStartDate.isAfter(today)
                    ? today
                    : (_analyticsCustomStartDate.isBefore(min2026)
                        ? min2026
                        : _analyticsCustomStartDate);
                final picked = await showAppDatePickerDialog(
                  context,
                  initialDate: initial,
                  firstDate: min2026,
                  lastDate: today,
                  title: 'Select Start Date',
                );
                if (picked != null) {
                  setState(() => _analyticsCustomStartDate = picked);
                  if (!_analyticsCustomStartDate
                      .isAfter(_analyticsCustomEndDate)) {
                    _analyticsViewKey.currentState?.setCustomRange(
                      _analyticsCustomStartDate,
                      _analyticsCustomEndDate,
                    );
                  }
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasRangeError
                        ? const Color(0xFFDC2626)
                        : theme.colorScheme.onSurface.withValues(
                            alpha: isDark ? 0.2 : 0.16,
                          ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.calendar,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Start: ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Icon(
              LucideIcons.arrowRight,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            InkWell(
              onTap: () async {
                final initial = _analyticsCustomEndDate.isAfter(today)
                    ? today
                    : (_analyticsCustomEndDate.isBefore(min2026)
                        ? min2026
                        : _analyticsCustomEndDate);
                final picked = await showAppDatePickerDialog(
                  context,
                  initialDate: initial,
                  firstDate: min2026,
                  lastDate: today,
                  title: 'Select End Date',
                );
                if (picked != null) {
                  setState(() => _analyticsCustomEndDate = picked);
                  if (!_analyticsCustomStartDate
                      .isAfter(_analyticsCustomEndDate)) {
                    _analyticsViewKey.currentState?.setCustomRange(
                      _analyticsCustomStartDate,
                      _analyticsCustomEndDate,
                    );
                  }
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasRangeError
                        ? const Color(0xFFDC2626)
                        : theme.colorScheme.onSurface.withValues(
                            alpha: isDark ? 0.2 : 0.16,
                          ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.calendar,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'End: ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (hasRangeError) ...[
          const SizedBox(height: 6),
          const Row(
            children: [
              Icon(Icons.error_outline, size: 13, color: Color(0xFFDC2626)),
              SizedBox(width: 4),
              Text(
                'Start date cannot be after end date.',
                style: TextStyle(
                  color: Color(0xFFDC2626),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required String Function(String) itemLabel,
    required ThemeData theme,
    required bool isDark,
  }) {
    final validValue = (value != null && items.contains(value))
        ? value
        : (items.isNotEmpty ? items.first : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(
                alpha: isDark ? 0.18 : 0.16,
              ),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: validValue,
              dropdownColor: theme.colorScheme.surface,
              icon: Icon(
                LucideIcons.chevronDown,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
              isDense: true,
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 13.5, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(itemLabel(item)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleGuardBanner(ThemeData theme, bool isDark) {
    final sched = _scheduleStatus!;
    final isHoliday = sched.isHoliday;

    if (_manualMakeupOverride && !isHoliday) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: AppTheme.catTeal.withValues(alpha: isDark ? 0.16 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.catTeal.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.unlock, size: 18, color: AppTheme.catTeal),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Make-Up Class Override Enabled — Attendance and RFID scanning are unlocked for this session.',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() => _manualMakeupOverride = false);
              },
              child: const Text(
                'Re-Lock',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

    final bannerColor = isHoliday ? AppTheme.catRed : AppTheme.catOrange;
    final reason =
        sched.lockReason ??
        'Attendance is locked because no class session is scheduled on this date.';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: bannerColor.withValues(alpha: 0.38),
          width: 1.2,
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isHoliday ? LucideIcons.calendarOff : LucideIcons.lock,
                size: 18,
                color: bannerColor,
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHoliday
                          ? 'Holiday Lock Enforced'
                          : 'Unscheduled Session — Attendance Locked',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? Colors.white
                            : (isHoliday
                                  ? const Color(0xFF991B1B)
                                  : const Color(0xFF92400E)),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reason,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.82,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isHoliday)
            AppButton(
              label: 'Enable Make-Up Class Override',
              icon: LucideIcons.unlock,
              type: AppButtonType.warning,
              isSmall: true,
              onPressed: _confirmMakeupOverride,
            ),
        ],
      ),
    );
  }

  Widget _buildInlineWorkspaceNotice(
    ThemeData theme,
    bool isDark,
    _WorkspaceInlineNotice notice,
  ) {
    final Color accent;
    final IconData icon;
    switch (notice.tone) {
      case _WorkspaceNoticeTone.success:
        accent = AppTheme.catGreen;
        icon = LucideIcons.checkCircle2;
        break;
      case _WorkspaceNoticeTone.warning:
        accent = AppTheme.catOrange;
        icon = LucideIcons.alertTriangle;
        break;
      case _WorkspaceNoticeTone.error:
        accent = AppTheme.catRed;
        icon = LucideIcons.alertCircle;
        break;
      case _WorkspaceNoticeTone.info:
        accent = theme.colorScheme.primary;
        icon = LucideIcons.info;
        break;
    }

    final showQuickAssign =
        notice.code == 'UNREGISTERED_CARD' &&
        notice.scannedUid != null &&
        _rosterStudents.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  notice.message,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          if (showQuickAssign) ...[
            const SizedBox(width: 10),
            AppButton.primary(
              label: 'Assign Card',
              icon: Icons.contactless_rounded,
              isSmall: true,
              onPressed: () =>
                  _openAssignUnregisteredCardPicker(notice.scannedUid!),
            ),
          ],
          IconButton(
            tooltip: 'Dismiss',
            icon: Icon(
              LucideIcons.x,
              size: 15,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _inlineNotice = null),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSummaryStrip({
    required ThemeData theme,
    required bool isDark,
    required int totalCount,
    required int rfidLinkedCount,
    required int presentCount,
    required int lateCount,
    required int absentCount,
    required int excusedCount,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 820;

        final cards = [
          _buildKpiBadge(
            theme: theme,
            isDark: isDark,
            count: presentCount,
            label: 'PRESENT',
            icon: LucideIcons.checkCircle2,
            accent: AppTheme.catGreen,
          ),
          _buildKpiBadge(
            theme: theme,
            isDark: isDark,
            count: lateCount,
            label: 'LATE',
            icon: LucideIcons.clock,
            accent: AppTheme.catOrange,
          ),
          _buildKpiBadge(
            theme: theme,
            isDark: isDark,
            count: absentCount,
            label: 'ABSENT',
            icon: LucideIcons.xCircle,
            accent: AppTheme.catRed,
          ),
          _buildKpiBadge(
            theme: theme,
            isDark: isDark,
            count: excusedCount,
            label: 'EXCUSED',
            icon: LucideIcons.shieldCheck,
            accent: AppTheme.catBlue,
          ),
          _buildKpiBadge(
            theme: theme,
            isDark: isDark,
            count: rfidLinkedCount,
            suffix: '/$totalCount',
            label: 'RFID LINKED',
            icon: Icons.contactless_rounded,
            accent: AppTheme.catTeal,
          ),
        ];

        if (isWide) {
          return Row(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: cards[i]),
              ],
            ],
          );
        }

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: cards
              .map(
                (c) =>
                    SizedBox(width: (constraints.maxWidth - 10) / 2, child: c),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildKpiBadge({
    required ThemeData theme,
    required bool isDark,
    required int count,
    String? suffix,
    required String label,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surface
            : accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.35 : 0.22),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.2 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 15, color: accent),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$count',
                        style: TextStyle(
                          color: isDark ? theme.colorScheme.onSurface : accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          height: 1.1,
                        ),
                      ),
                      if (suffix != null)
                        TextSpan(
                          text: suffix,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.55,
                            ),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildErrorContainer(
    ThemeData theme,
    String message, {
    VoidCallback? onRetry,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.catRed.withValues(alpha: 0.25)),
      ),
      child: AppEmptyState(
        icon: LucideIcons.alertCircle,
        title: 'Unable to Load Workspace',
        message: message,
        actionLabel: onRetry != null ? 'Retry' : null,
        onAction: onRetry,
      ),
    );
  }

  Widget _buildNoClassesAvailable(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: AppEmptyState(
        icon: LucideIcons.school,
        title: 'No Classes Available Yet',
        message: 'Set up your subjects and class sections in the Classroom Setup tab before recording attendance.',
        actionLabel: 'Reload Classes',
        onAction: _loadSubjects,
      ),
    );
  }
}

/// Quick student selector modal launched when an unregistered RFID card is tapped
/// during live attendance taking (`code == 'UNREGISTERED_CARD'`).
class _SelectStudentForRfidDialog extends StatefulWidget {
  final List<AttendanceRosterStudent> students;
  final String scannedUid;

  const _SelectStudentForRfidDialog({
    required this.students,
    required this.scannedUid,
  });

  static Future<AttendanceRosterStudent?> show(
    BuildContext context, {
    required List<AttendanceRosterStudent> students,
    required String scannedUid,
  }) {
    final theme = Theme.of(context);
    return showDialog<AttendanceRosterStudent>(
      context: context,
      builder: (ctx) => Theme(
        data: theme,
        child: _SelectStudentForRfidDialog(
          students: students,
          scannedUid: scannedUid,
        ),
      ),
    );
  }

  @override
  State<_SelectStudentForRfidDialog> createState() =>
      _SelectStudentForRfidDialogState();
}

class _SelectStudentForRfidDialogState
    extends State<_SelectStudentForRfidDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final q = _query.trim().toLowerCase();

    final filtered = widget.students.where((s) {
      if (q.isEmpty) return true;
      return s.displayName.toLowerCase().contains(q) ||
          (s.lrn ?? '').toLowerCase().contains(q);
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.contactless_rounded,
                    color: AppTheme.catTeal,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Assign Scanned Card (${widget.scannedUid})',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Select a student from this class to link RFID card ${widget.scannedUid}:',
                style: TextStyle(
                  fontSize: 12.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Search student or LRN...',
                  prefixIcon: const Icon(LucideIcons.search, size: 16),
                  isDense: true,
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.14,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No matching students found.',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.07,
                          ),
                        ),
                        itemBuilder: (context, index) {
                          final s = filtered[index];
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            title: Text(
                              s.displayName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            subtitle: s.lrn != null && s.lrn!.isNotEmpty
                                ? Text(
                                    'LRN: ${s.lrn}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.55),
                                    ),
                                  )
                                : null,
                            trailing: s.hasRfidAssigned
                                ? Text(
                                    s.rfidUid!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      color: AppTheme.catTeal,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                : Text(
                                    'Unassigned',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.45),
                                    ),
                                  ),
                            onTap: () => Navigator.of(context).pop(s),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: AppSecondaryButton(
                  label: 'Cancel',
                  height: 40,
                  onPressed: () => Navigator.of(context).pop(null),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
