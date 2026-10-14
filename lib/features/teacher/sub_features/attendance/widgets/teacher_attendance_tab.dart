import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/attendance_workspace_models.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/data/repositories/attendance_repository.dart';
import 'package:class_realm/data/repositories/supabase_attendance_repository.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/features/teacher/sub_features/attendance/widgets/attendance_roster_list.dart';
import 'package:class_realm/features/teacher/sub_features/attendance/widgets/attendance_history_analytics_view.dart';
import 'package:class_realm/widgets/common/app_date_picker_field.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

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
  late final AttendanceRepository _repository;

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
  final Map<String, AttendanceStatus?> _tempAttendanceStates = {};
  final Map<String, String> _tempAttendanceRemarks = {};
  Map<String, AttendanceStatus?> _initialAttendanceStates = {};

  bool _isLoadingRoster = false;
  String? _rosterLoadError;
  bool _isSavingBatch = false;
  bool _isOffline = false;

  int _rosterLoadRequest = 0;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupabaseAttendanceRepository.instance;
    if (widget.initialSubjects != null) {
      _teacherSubjects = widget.initialSubjects!;
      _syncFilterSelection();
      _isLoadingSubjects = false;
      if (_selectedSubjectId != null) {
        _loadRosterAndRecords(_selectedSubjectId!, _attendanceSelectedDate);
      }
    } else {
      _loadSubjects();
    }
  }

  bool get _isDirty {
    if (_tempAttendanceStates.length != _initialAttendanceStates.length) {
      return true;
    }
    for (final entry in _tempAttendanceStates.entries) {
      if (_initialAttendanceStates[entry.key] != entry.value) {
        return true;
      }
    }
    return false;
  }

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
    final list = set.toList();
    list.sort();
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
    final list = set.toList();
    list.sort();
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
    if (_selectedSubjectName == null || !subjects.contains(_selectedSubjectName)) {
      _selectedSubjectName = subjects.isNotEmpty ? subjects.first : null;
    }

    final sections = _availableSections;
    final matchingOffering = sections.firstWhere(
      (s) => s['id']?.toString() == _selectedSubjectId,
      orElse: () => sections.isNotEmpty ? sections.first : {},
    );
    _selectedSubjectId = matchingOffering['id']?.toString();
  }

  Future<void> _loadSubjects() async {
    final teacherId = AuthRepository.instance.currentUser?.id;
    if (teacherId == null) {
      setState(() {
        _isLoadingSubjects = false;
        _subjectsLoadError = 'Sign in as a teacher to load your classes.';
      });
      return;
    }

    // 1. FAST LOCAL STORAGE LOAD (Instant UI render with 0ms latency)
    final cached = SubjectRepository.instance.getCachedTeacherSubjects(teacherId);
    if (cached.isNotEmpty) {
      if (mounted) {
        setState(() {
          _teacherSubjects = cached;
          _syncFilterSelection();
          _isLoadingSubjects = false;
          _subjectsLoadError = null;
        });
        if (_selectedSubjectId != null) {
          _loadRosterAndRecords(_selectedSubjectId!, _attendanceSelectedDate);
        }
      }
    }

    // 2. Fetch fresh from database in the background
    try {
      final subjects = await SubjectRepository.instance.getTeacherSubjects(
        teacherId,
      );
      if (!mounted) return;
      setState(() {
        _teacherSubjects = subjects;
        _syncFilterSelection();
        _isLoadingSubjects = false;
        _subjectsLoadError = null;
        _isOffline = false;
      });
      if (_selectedSubjectId != null) {
        await _loadRosterAndRecords(_selectedSubjectId!, _attendanceSelectedDate);
      }
    } catch (error) {
      debugPrint('Attendance subjects load notice: $error');
      if (!mounted) return;
      if (_teacherSubjects.isNotEmpty) {
        // Keep cached classes on screen, mark as offline
        setState(() {
          _isLoadingSubjects = false;
          _isOffline = true;
          _subjectsLoadError = null;
        });
      } else {
        setState(() {
          _isLoadingSubjects = false;
          _isOffline = true;
          _subjectsLoadError = 'Unable to connect to database. Please check your network.';
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

    // 1. Instant local storage retrieval for roster and marks
    final cachedRoster = LocalStorageService.getAttendanceRoster(subjectOfferingId);
    final cachedRecords = LocalStorageService.getAttendanceRecords(subjectOfferingId, dateStr);
    if (cachedRoster.isNotEmpty && _rosterStudents.isEmpty) {
      final cachedStudents = cachedRoster.map((m) => AttendanceRosterStudent.fromJson(m)).toList();
      final states = <String, AttendanceStatus?>{};
      final remarks = <String, String>{};
      for (final recMap in cachedRecords) {
        final rec = AttendanceWorkspaceRecord.fromJson(recMap);
        states[rec.studentId] = rec.status;
        if (rec.remarks != null && rec.remarks!.isNotEmpty) {
          remarks[rec.studentId] = rec.remarks!;
        }
      }
      setState(() {
        _rosterStudents = cachedStudents;
        _tempAttendanceStates.clear();
        _tempAttendanceStates.addAll(states);
        _initialAttendanceStates = Map.from(states);
        _tempAttendanceRemarks.clear();
        _tempAttendanceRemarks.addAll(remarks);
        _isLoadingRoster = false;
      });
    } else if (_rosterStudents.isEmpty) {
      setState(() {
        _isLoadingRoster = true;
        _rosterLoadError = null;
      });
    }

    try {
      final result = await _repository.getAttendanceRosterAndDateRecords(
        subjectOfferingId: subjectOfferingId,
        date: date,
      );
      if (!mounted || request != _rosterLoadRequest) return;

      final states = <String, AttendanceStatus?>{};
      final remarks = <String, String>{};
      for (final rec in result.records) {
        states[rec.studentId] = rec.status;
        if (rec.remarks != null && rec.remarks!.isNotEmpty) {
          remarks[rec.studentId] = rec.remarks!;
        }
      }

      var students = result.students;
      if (students.isEmpty) {
        final currentSectionName =
            _currentOffering?['section_name']?.toString() ?? '';
        final fallbackStudents = MockDatabase.instance.users
            .where((u) =>
                u.role == UserRole.student &&
                !u.isArchived &&
                (u.departmentOrSection?.toLowerCase().trim() ==
                        currentSectionName.toLowerCase().trim() ||
                    currentSectionName.isEmpty))
            .map((u) => AttendanceRosterStudent(
                  studentId: u.id,
                  firstName: u.firstName ?? '',
                  middleName: u.middleName,
                  lastName: u.lastName ?? '',
                  gender: u.gender ?? 'unspecified',
                ))
            .toList();
        if (fallbackStudents.isNotEmpty) {
          students = fallbackStudents;
        }
      }

      // 8:00 PM Auto-Absent cutoff: if viewing past date or today past 8:00 PM
      final now = DateTime.now();
      final isPastDay = date.year < now.year ||
          (date.year == now.year && date.month < now.month) ||
          (date.year == now.year && date.month == now.month && date.day < now.day);
      final isTodayPast8Pm = (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day &&
          now.hour >= 20);

      if (isPastDay || isTodayPast8Pm) {
        for (final s in students) {
          if (!states.containsKey(s.studentId)) {
            states[s.studentId] = AttendanceStatus.absent;
            remarks[s.studentId] = 'Auto-Absent';
          }
        }
      }

      setState(() {
        _rosterStudents = students;
        _tempAttendanceStates.clear();
        _tempAttendanceStates.addAll(states);
        _tempAttendanceRemarks.clear();
        _tempAttendanceRemarks.addAll(remarks);
        _initialAttendanceStates = Map.from(states);
        _isLoadingRoster = false;
        _isOffline = false;
      });
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
          _rosterLoadError = 'Unable to fetch student roster. Please check network connection.';
        });
      }
    }
  }

  void _autoAbsentUnmarked() {
    setState(() {
      for (final student in _rosterStudents) {
        if (_tempAttendanceStates[student.studentId] == null) {
          _tempAttendanceStates[student.studentId] = AttendanceStatus.absent;
          _tempAttendanceRemarks[student.studentId] = 'Auto-Absent';
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unmarked students have been set to Auto-Absent.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<bool> _promptDiscardIfDirty() async {
    if (!_isDirty) return true;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved Attendance Changes'),
        content: const Text(
          'You have unsaved attendance marks. Switching class or date will discard these changes. Proceed anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Editing'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.catRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard Changes'),
          ),
        ],
      ),
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
      _selectedSubjectId = secs.isNotEmpty ? secs.first['id']?.toString() : null;
    });

    if (_selectedSubjectId != null) {
      _loadRosterAndRecords(_selectedSubjectId!, _attendanceSelectedDate);
    }
  }

  Future<void> _onSubjectNameChanged(String? newSubject) async {
    if (newSubject == null || newSubject == _selectedSubjectName) return;
    if (!await _promptDiscardIfDirty()) return;

    setState(() {
      _selectedSubjectName = newSubject;
      final secs = _availableSections;
      _selectedSubjectId = secs.isNotEmpty ? secs.first['id']?.toString() : null;
    });

    if (_selectedSubjectId != null) {
      _loadRosterAndRecords(_selectedSubjectId!, _attendanceSelectedDate);
    }
  }

  Future<void> _onSectionChanged(String? newOfferingId) async {
    if (newOfferingId == null || newOfferingId == _selectedSubjectId) return;
    if (!await _promptDiscardIfDirty()) return;

    setState(() {
      _selectedSubjectId = newOfferingId;
    });

    _loadRosterAndRecords(newOfferingId, _attendanceSelectedDate);
  }

  Future<void> _onDateChanged(DateTime newDate) async {
    if (_isSameDay(newDate, _attendanceSelectedDate)) return;
    if (!await _promptDiscardIfDirty()) return;

    setState(() {
      _attendanceSelectedDate = newDate;
    });
    if (_selectedSubjectId != null) {
      _loadRosterAndRecords(_selectedSubjectId!, newDate);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _saveBatch() async {
    if (_selectedSubjectId == null) return;
    setState(() => _isSavingBatch = true);

    try {
      final recordsToSave = <AttendanceWorkspaceRecord>[];
      for (final student in _rosterStudents) {
        final currentStatus = _tempAttendanceStates[student.studentId];
        if (currentStatus == null) continue;
        final finalRemark = _tempAttendanceRemarks[student.studentId];

        recordsToSave.add(
          AttendanceWorkspaceRecord(
            id: null,
            studentId: student.studentId,
            subjectOfferingId: _selectedSubjectId!,
            attendanceDate: _attendanceSelectedDate,
            status: currentStatus,
            source: AttendanceSource.manual,
            remarks: finalRemark,
          ),
        );
      }

      await _repository.saveAttendanceBatch(
        subjectOfferingId: _selectedSubjectId!,
        date: _attendanceSelectedDate,
        records: recordsToSave,
      );

      if (!mounted) return;
      setState(() {
        _initialAttendanceStates = Map.from(_tempAttendanceStates);
        _isSavingBatch = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Attendance for ${_formatDate(_attendanceSelectedDate)} saved successfully!',
          ),
          backgroundColor: AppTheme.catGreen,
        ),
      );
    } catch (e) {
      debugPrint('Save batch notice: $e');
      if (!mounted) return;
      setState(() => _isSavingBatch = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save attendance: $e'),
          backgroundColor: AppTheme.catRed,
        ),
      );
    }
  }

  String _subjectLabel(Map<String, dynamic> subject) {
    final grade = _normalizeGradeLevel(subject['grade_level']);
    final section = _formatSectionDisplay(subject['section_name']?.toString() ?? 'Section');
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

  Widget _buildClassFilters(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.filter,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Class & Section Selection',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Your Classes (${_teacherSubjects.length})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Grade Level Selector
              _buildFilterDropdown(
                label: 'Grade Level',
                icon: LucideIcons.graduationCap,
                value: _selectedGradeLevel,
                items: _gradeLevels,
                onChanged: _onGradeLevelChanged,
                itemLabel: (val) => val,
                theme: theme,
              ),

              // Subject Selector
              _buildFilterDropdown(
                label: 'Subject',
                icon: LucideIcons.bookOpen,
                value: _selectedSubjectName,
                items: _availableSubjects,
                onChanged: _onSubjectNameChanged,
                itemLabel: (val) => val,
                theme: theme,
              ),

              // Section Selector
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
              ),
            ],
          ),
        ],
      ),
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
  }) {
    final validValue =
        (value != null && items.contains(value))
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
              color: theme.colorScheme.onSurface.withValues(alpha: 0.16),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: validValue,
              icon: const Icon(LucideIcons.chevronDown, size: 14),
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              isDense: true,
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 13, color: theme.colorScheme.primary),
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

  static String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Live counts across entire selected roster
    int countStatus(AttendanceStatus status) => _rosterStudents
        .where((s) => _tempAttendanceStates[s.studentId] == status)
        .length;

    final presentCount = countStatus(AttendanceStatus.present);
    final absentCount = countStatus(AttendanceStatus.absent);
    final lateCount = countStatus(AttendanceStatus.late);
    final excusedCount = countStatus(AttendanceStatus.excused);
    final unmarkedCount = _rosterStudents
        .where((s) => _tempAttendanceStates[s.studentId] == null)
        .length;
    final totalCount = _rosterStudents.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & View Switcher Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _selectedSubjectLabel,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
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
                          : AppButton.outline(
                              icon: LucideIcons.clipboardCheck,
                              label: 'Take Attendance',
                              isSmall: true,
                              onPressed: () => setState(
                                () => _selectedAttendanceView = 'Take Attendance',
                              ),
                            ),
                      const SizedBox(width: 6),
                      _selectedAttendanceView == 'History & Analytics'
                          ? AppButton.primary(
                              icon: LucideIcons.barChart3,
                              label: 'History & Analytics',
                              isSmall: true,
                              onPressed: () {},
                            )
                          : AppButton.outline(
                              icon: LucideIcons.barChart3,
                              label: 'History & Analytics',
                              isSmall: true,
                              onPressed: () => setState(
                                () => _selectedAttendanceView = 'History & Analytics',
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_isLoadingSubjects && _teacherSubjects.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: LoadingAnimationWidget.staggeredDotsWave(
                  color: theme.colorScheme.primary,
                  size: 40,
                ),
              ),
            )
          else if (_subjectsLoadError != null && _teacherSubjects.isEmpty)
            _buildErrorContainer(theme, _subjectsLoadError!, onRetry: _loadSubjects)
          else if (_teacherSubjects.isEmpty)
            _buildNoClassesAvailable(theme)
          else ...[
            if (_isOffline)
              _buildOfflineBanner(theme),
            _buildClassFilters(theme),
            const SizedBox(height: 16),
            if (_selectedAttendanceView == 'Take Attendance') ...[
              // Controls row
              _buildTakeAttendanceControls(
                theme,
                totalCount: totalCount,
                presentCount: presentCount,
                absentCount: absentCount,
                lateCount: lateCount,
                excusedCount: excusedCount,
                unmarkedCount: unmarkedCount,
              ),
              const SizedBox(height: 16),

              // Roster list
              AttendanceRosterList(
                students: _rosterStudents,
                statuses: _tempAttendanceStates,
                remarks: _tempAttendanceRemarks,
                searchQuery: _attendanceSearchQuery,
                isLoading: _isLoadingRoster,
                errorMessage: _rosterLoadError,
                onRetry: _selectedSubjectId != null
                    ? () => _loadRosterAndRecords(
                          _selectedSubjectId!,
                          _attendanceSelectedDate,
                        )
                    : null,
                onStatusChanged: (entry) {
                  setState(() {
                    if (entry.value == null) {
                      _tempAttendanceStates.remove(entry.key);
                      _tempAttendanceRemarks.remove(entry.key);
                    } else {
                      _tempAttendanceStates[entry.key] = entry.value;
                    }
                  });
                },
              ),
              const SizedBox(height: 24),

              // Bottom Action Save Attendance Bar
              if (_rosterStudents.isNotEmpty && !_isLoadingRoster)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _isSavingBatch
                        ? const CircularProgressIndicator()
                        : AppButton.primary(
                            icon: LucideIcons.check,
                            label:
                                'Save Attendance for ${_formatDate(_attendanceSelectedDate)}${_isDirty ? ' (Unsaved)' : ''}',
                            onPressed: _saveBatch,
                          ),
                    const SizedBox(width: 12),
                    AppButton.danger(
                      icon: LucideIcons.trash2,
                      label: 'Clear All',
                      onPressed: () {
                        setState(() {
                          _tempAttendanceStates.clear();
                        });
                      },
                    ),
                  ],
                ),
            ] else ...[
              // History & Analytics View
              if (_selectedSubjectId != null)
                AttendanceHistoryAnalyticsView(
                  subjectOfferingId: _selectedSubjectId!,
                  repository: _repository,
                ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildTakeAttendanceControls(
    ThemeData theme, {
    required int totalCount,
    required int presentCount,
    required int absentCount,
    required int lateCount,
    required int excusedCount,
    required int unmarkedCount,
  }) {
    final isToday = _isSameDay(_attendanceSelectedDate, DateTime.now());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // RFID Hardware status banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.radio,
                  size: 15,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
                const Text(
                  'RFID Hardware Not Connected',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.catGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Manual Entry Active',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.catGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Responsive Search, Date Navigator, and Enrollment count row
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 720;

              final searchField = TextField(
                onChanged: (value) =>
                    setState(() => _attendanceSearchQuery = value),
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Search student name or ID...',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  prefixIcon: Icon(
                    LucideIcons.search,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  suffixIcon: _attendanceSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(LucideIcons.x, size: 14),
                          onPressed: () =>
                              setState(() => _attendanceSearchQuery = ''),
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.15,
                      ),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.15,
                      ),
                    ),
                  ),
                ),
              );

              final dateNavigator = Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Previous Day',
                      icon: const Icon(LucideIcons.chevronLeft, size: 16),
                      onPressed: () => _onDateChanged(
                        _attendanceSelectedDate.subtract(const Duration(days: 1)),
                      ),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                    InkWell(
                      onTap: () async {
                        final picked = await showAppDatePickerDialog(
                          context,
                          initialDate: _attendanceSelectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
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
                            const Icon(
                              LucideIcons.calendar,
                              size: 15,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatDate(_attendanceSelectedDate),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next Day',
                      icon: const Icon(LucideIcons.chevronRight, size: 16),
                      onPressed: () => _onDateChanged(
                        _attendanceSelectedDate.add(const Duration(days: 1)),
                      ),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              );

              final enrolledBadge = Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.catGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.catGreen.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.users,
                      size: 15,
                      color: AppTheme.catGreen,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$totalCount Enrolled',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppTheme.catGreen,
                      ),
                    ),
                  ],
                ),
              );

              if (isWide) {
                return Row(
                  children: [
                    Expanded(child: searchField),
                    const SizedBox(width: 12),
                    dateNavigator,
                    if (!isToday) ...[
                      const SizedBox(width: 8),
                      AppButton.secondary(
                        label: 'Today',
                        isSmall: true,
                        onPressed: () => _onDateChanged(DateTime.now()),
                      ),
                    ],
                    const SizedBox(width: 12),
                    enrolledBadge,
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchField,
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        dateNavigator,
                        if (!isToday)
                          AppButton.secondary(
                            label: 'Today',
                            isSmall: true,
                            onPressed: () => _onDateChanged(DateTime.now()),
                          ),
                        enrolledBadge,
                      ],
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 16),

          // Batch Action Buttons Row
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppButton.success(
                label: 'Mark All Present',
                icon: LucideIcons.checkCheck,
                isSmall: true,
                onPressed: () => setState(() {
                  for (final s in _rosterStudents) {
                    _tempAttendanceStates[s.studentId] = AttendanceStatus.present;
                    _tempAttendanceRemarks.remove(s.studentId);
                  }
                }),
              ),
              AppButton.outline(
                label: 'Auto-Absent Unmarked ($unmarkedCount)',
                icon: LucideIcons.clockAlert,
                isSmall: true,
                onPressed: unmarkedCount > 0 ? _autoAbsentUnmarked : null,
              ),
              AppButton.danger(
                label: 'Mark All Absent',
                icon: LucideIcons.userX,
                isSmall: true,
                onPressed: () => setState(() {
                  for (final s in _rosterStudents) {
                    _tempAttendanceStates[s.studentId] = AttendanceStatus.absent;
                  }
                }),
              ),
              AppButton.outline(
                label: 'Holiday / Suspension',
                icon: LucideIcons.calendarOff,
                isSmall: true,
                onPressed: () => setState(() {
                  for (final s in _rosterStudents) {
                    _tempAttendanceStates[s.studentId] = AttendanceStatus.excused;
                  }
                }),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Responsive 4 Status Metric Cards (Present, Late, Absent, Excused)
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 720;
              final isTablet = constraints.maxWidth >= 460;

              final presentCard = _buildModernStatusBadge(
                count: presentCount,
                label: 'PRESENT',
                icon: LucideIcons.checkCircle2,
                bg: const Color(0xFFECFDF5),
                border: const Color(0xFFA7F3D0),
                fg: const Color(0xFF065F46),
              );
              final lateCard = _buildModernStatusBadge(
                count: lateCount,
                label: 'LATE',
                icon: LucideIcons.clock,
                bg: const Color(0xFFFFFBEB),
                border: const Color(0xFFFDE68A),
                fg: const Color(0xFF92400E),
              );
              final absentCard = _buildModernStatusBadge(
                count: absentCount,
                label: 'ABSENT',
                icon: LucideIcons.xCircle,
                bg: const Color(0xFFFEF2F2),
                border: const Color(0xFFFECACA),
                fg: const Color(0xFF991B1B),
              );
              final excusedCard = _buildModernStatusBadge(
                count: excusedCount,
                label: 'EXCUSED',
                icon: LucideIcons.shieldCheck,
                bg: const Color(0xFFF8FAFC),
                border: const Color(0xFFE2E8F0),
                fg: const Color(0xFF334155),
              );

              if (isDesktop) {
                return Row(
                  children: [
                    Expanded(child: presentCard),
                    const SizedBox(width: 12),
                    Expanded(child: lateCard),
                    const SizedBox(width: 12),
                    Expanded(child: absentCard),
                    const SizedBox(width: 12),
                    Expanded(child: excusedCard),
                  ],
                );
              } else if (isTablet) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: presentCard),
                        const SizedBox(width: 12),
                        Expanded(child: lateCard),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: absentCard),
                        const SizedBox(width: 12),
                        Expanded(child: excusedCard),
                      ],
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: presentCard),
                        const SizedBox(width: 8),
                        Expanded(child: lateCard),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: absentCard),
                        const SizedBox(width: 8),
                        Expanded(child: excusedCard),
                      ],
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatusBadge({
    required int count,
    required String label,
    required IconData icon,
    required Color bg,
    required Color border,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: fg.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: fg),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    height: 1.1,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: fg.withValues(alpha: 0.8),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.5,
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(LucideIcons.alertCircle, color: theme.colorScheme.error, size: 36),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            AppButton.outline(
              label: 'Retry',
              icon: LucideIcons.refreshCw,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoClassesAvailable(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.calendarX2,
                size: 36,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No classes available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Set up your subjects and sections in Classroom Setup first to record attendance.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            AppButton.outline(
              label: 'Reload Classes',
              icon: LucideIcons.refreshCw,
              onPressed: _loadSubjects,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineBanner(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.catOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.catOrange.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.wifiOff,
            size: 16,
            color: AppTheme.catOrange,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Offline Mode: Data loaded from local storage. Any recorded attendance will be saved locally and synced automatically when online.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _loadSubjects,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                LucideIcons.refreshCw,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
