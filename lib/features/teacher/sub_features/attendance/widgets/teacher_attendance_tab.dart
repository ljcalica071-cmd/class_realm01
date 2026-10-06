import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/data/repositories/supabase_student_repository.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';

class TeacherAttendanceTab extends StatefulWidget {
  const TeacherAttendanceTab({super.key});

  @override
  State<TeacherAttendanceTab> createState() => _TeacherAttendanceTabState();
}

class _TeacherAttendanceTabState extends State<TeacherAttendanceTab> {
  List<Map<String, dynamic>> _teacherSubjects = [];
  List<UserModel> _students = [];
  String? _selectedSubjectId;
  String? _loadError;
  bool _isLoading = true;
  String _selectedAttendanceView = 'Take Attendance';
  DateTime _attendanceSelectedDate = DateTime.now();
  String _attendanceSearchQuery = '';
  final Map<String, AttendanceStatus> _tempAttendanceStates = {};
  int _studentLoadRequest = 0;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final teacherId = AuthRepository.instance.currentUser?.id;
    if (teacherId == null) {
      setState(() {
        _isLoading = false;
        _loadError = 'Sign in as a teacher to load your classes.';
      });
      return;
    }

    try {
      final subjects = await SubjectRepository.instance.getTeacherSubjects(
        teacherId,
      );
      if (!mounted) return;
      final selectedId = subjects.isEmpty
          ? null
          : subjects.first['id']?.toString();
      setState(() {
        _teacherSubjects = subjects;
        _selectedSubjectId = selectedId;
        _isLoading = false;
      });
      if (selectedId != null) {
        await _loadStudents(teacherId, selectedId);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Failed to load your classes: $error';
      });
    }
  }

  Future<void> _loadStudents(String teacherId, String subjectId) async {
    final request = ++_studentLoadRequest;
    setState(() {
      _isLoading = true;
      _loadError = null;
      _students = [];
      _tempAttendanceStates.clear();
    });
    try {
      final students = await SupabaseStudentRepository().getStudentsForTeacher(
        teacherId,
        subjectId: subjectId,
      );
      if (!mounted || request != _studentLoadRequest) return;
      setState(() {
        _students = students;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || request != _studentLoadRequest) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Failed to load enrolled students: $error';
      });
    }
  }

  String _subjectLabel(Map<String, dynamic> subject) {
    final grade = subject['grade_level']?.toString() ?? '';
    final section = subject['section_name']?.toString() ?? '';
    final name = subject['subject_name']?.toString() ?? '';
    return [
      if (grade.isNotEmpty) 'Grade $grade',
      if (section.isNotEmpty) 'Section $section',
      if (name.isNotEmpty) name,
    ].join(' • ');
  }

  String get _selectedSubjectLabel {
    for (final subject in _teacherSubjects) {
      if (subject['id']?.toString() == _selectedSubjectId) {
        return _subjectLabel(subject);
      }
    }
    return 'No subject or section selected';
  }

  String _formatStudentDisplayName(UserModel student) {
    final lastName = student.lastName?.trim().isNotEmpty == true
        ? student.lastName!.trim()
        : student.fullName.split(' ').last;
    final firstName = student.firstName?.trim().isNotEmpty == true
        ? student.firstName!.trim()
        : (student.fullName.split(' ').isNotEmpty
              ? student.fullName.split(' ').first
              : student.fullName);
    final middleName = student.middleName?.trim() ?? '';
    final middleInitial = middleName.isEmpty ? '' : ' ${middleName[0]}.';
    return '$lastName, $firstName$middleInitial';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allActiveStudents = List<UserModel>.from(_students);
    allActiveStudents.sort((a, b) {
      final aLast = (a.lastName ?? a.fullName.split(' ').last).toLowerCase();
      final bLast = (b.lastName ?? b.fullName.split(' ').last).toLowerCase();
      return aLast.compareTo(bLast);
    });
    final activeStudents = allActiveStudents.where((student) {
      final query = _attendanceSearchQuery.trim().toLowerCase();
      return query.isEmpty ||
          _formatStudentDisplayName(student).toLowerCase().contains(query) ||
          (student.lrn?.toLowerCase().contains(query) ?? false);
    }).toList();

    final visibleStudentIds = activeStudents
        .map((student) => student.id)
        .toSet();
    int countStatus(AttendanceStatus status) => visibleStudentIds
        .where((id) => _tempAttendanceStates[id] == status)
        .length;
    final presentCount = countStatus(AttendanceStatus.present);
    final absentCount = countStatus(AttendanceStatus.absent);
    final lateCount = countStatus(AttendanceStatus.late);
    final excusedCount = countStatus(AttendanceStatus.excused);
    int totalCount = activeStudents.length;
    final markedCount = presentCount + absentCount + lateCount + excusedCount;
    double percentPresent = markedCount > 0
        ? (presentCount / markedCount) * 100
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner title
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
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
                      LucideIcons.calendar,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Take Attendance',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedSubjectLabel,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tab View Headers
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _selectedAttendanceView == 'Take Attendance'
                  ? AppButton.primary(
                      label: 'Take Attendance',
                      onPressed: () => setState(
                        () => _selectedAttendanceView = 'Take Attendance',
                      ),
                    )
                  : AppButton.outline(
                      label: 'Take Attendance',
                      onPressed: () => setState(
                        () => _selectedAttendanceView = 'Take Attendance',
                      ),
                    ),
              _selectedAttendanceView == 'View History'
                  ? AppButton.primary(
                      label: 'View History',
                      onPressed: () => setState(
                        () => _selectedAttendanceView = 'View History',
                      ),
                    )
                  : AppButton.outline(
                      label: 'View History',
                      onPressed: () => setState(
                        () => _selectedAttendanceView = 'View History',
                      ),
                    ),
            ],
          ),
          const SizedBox(height: 20),

          // Search bar (Left side of date picker)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Search Student Input
                    SizedBox(
                      width: 280,
                      child: TextField(
                        onChanged: (value) =>
                            setState(() => _attendanceSearchQuery = value),
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search student name or LRN',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          prefixIcon: Icon(
                            LucideIcons.search,
                            size: 18,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.12,
                              ),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Date Picker Input Box
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _attendanceSelectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _attendanceSelectedDate = picked;
                            _tempAttendanceStates.clear();
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${_attendanceSelectedDate.day.toString().padLeft(2, '0')}/${_attendanceSelectedDate.month.toString().padLeft(2, '0')}/${_attendanceSelectedDate.year}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.calendar_month,
                              size: 16,
                              color: Color(0xFF64748B),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Students Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.people_outline,
                            size: 16,
                            color: Color(0xFF107B41),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$totalCount Students',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Percent Present Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: Color(0xFF107B41),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${percentPresent.toStringAsFixed(1)}% Present',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF107B41),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Config Buttons Row (Aligned with Class Dropdown)
                Row(
                  children: [
                    // Class / Section Dropdown Aligned Here
                    const Text(
                      'Class / Section:  ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedSubjectId,
                          hint: const Text('No classes configured'),
                          style: const TextStyle(
                            color: Color(0xFF1A56DB),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          isDense: true,
                          items: _teacherSubjects.map((subject) {
                            final id = subject['id']?.toString();
                            return DropdownMenuItem<String>(
                              value: id,
                              child: Text(_subjectLabel(subject)),
                            );
                          }).toList(),
                          onChanged: (subjectId) {
                            if (subjectId == null) return;
                            setState(() {
                              _selectedSubjectId = subjectId;
                              _tempAttendanceStates.clear();
                            });
                            final teacherId =
                                AuthRepository.instance.currentUser?.id;
                            if (teacherId != null) {
                              _loadStudents(teacherId, subjectId);
                            }
                          },
                        ),
                      ),
                    ),
                    const Spacer(),
                    _buildHeaderConfigButton(
                      label: 'Group by Gender',
                      icon: Icons.grid_view_outlined,
                      onPressed: () {},
                    ),
                    const SizedBox(width: 8),
                    _buildHeaderConfigButton(
                      label: 'Sort: A-Z',
                      icon: Icons.sort_by_alpha,
                      onPressed: () {},
                    ),
                    const SizedBox(width: 8),
                    _buildHeaderConfigButton(
                      label: 'Holiday / Suspension',
                      icon: Icons.celebration_outlined,
                      onPressed: () => setState(() {
                        for (final student in activeStudents) {
                          _tempAttendanceStates[student.id] =
                              AttendanceStatus.excused;
                        }
                      }),
                    ),
                    const SizedBox(width: 16),
                    // MARK ALL PRESENT BUTTON
                    AppButton.success(
                      label: 'Mark All Present',
                      isSmall: true,
                      onPressed: () {
                        setState(() {
                          for (var s in activeStudents) {
                            _tempAttendanceStates[s.id] =
                                AttendanceStatus.present;
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    // MARK ALL ABSENT BUTTON
                    AppButton.danger(
                      label: 'Mark All Absent',
                      isSmall: true,
                      onPressed: () {
                        setState(() {
                          for (var s in activeStudents) {
                            _tempAttendanceStates[s.id] =
                                AttendanceStatus.absent;
                          }
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_loadError != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  _loadError!,
                  style: TextStyle(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (activeStudents.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No students are enrolled in this subject and section.',
                ),
              ),
            )
          else ...[
            // Attendance status summary boxes
            Row(
              children: [
                _buildAttendanceCountBadge(
                  label: '$presentCount PRESENT',
                  color: AppTheme.catGreen,
                ),
                const SizedBox(width: 8),
                _buildAttendanceCountBadge(
                  label: '$absentCount ABSENT',
                  color: AppTheme.catRed,
                ),
                const SizedBox(width: 8),
                _buildAttendanceCountBadge(
                  label: '$lateCount LATE',
                  color: AppTheme.catOrange,
                ),
                const SizedBox(width: 8),
                _buildAttendanceCountBadge(
                  label: '$excusedCount EXCUSED',
                  color: AppTheme.catSlate,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Student Attendance Status Row Checklist List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeStudents.length,
              itemBuilder: (ctx, i) {
                final student = activeStudents[i];
                final currentStatus = _tempAttendanceStates[student.id];
                final initials =
                    student.fullName.substring(0, 1).toUpperCase() +
                    (student.fullName.contains(' ')
                        ? student.fullName
                              .split(' ')[1]
                              .substring(0, 1)
                              .toUpperCase()
                        : '');

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.12,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Index
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      // Initials Avatar
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: theme.colorScheme.primary,
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Student name
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatStudentDisplayName(student),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              currentStatus == null
                                  ? 'Attendance not marked'
                                  : 'Marked ${currentStatus.name}',
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Rounded check buttons row
                      Row(
                        children: [
                          // PRESENT check
                          _buildAttendanceActionButton(
                            icon: LucideIcons.check,
                            color: AppTheme.catGreen,
                            isActive: currentStatus == AttendanceStatus.present,
                            theme: theme,
                            onPressed: () {
                              setState(
                                () => _tempAttendanceStates[student.id] =
                                    AttendanceStatus.present,
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          // ABSENT check
                          _buildAttendanceActionButton(
                            icon: LucideIcons.x,
                            color: AppTheme.catRed,
                            isActive: currentStatus == AttendanceStatus.absent,
                            theme: theme,
                            onPressed: () {
                              setState(
                                () => _tempAttendanceStates[student.id] =
                                    AttendanceStatus.absent,
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          // LATE check
                          _buildAttendanceActionButton(
                            icon: LucideIcons.clock,
                            color: AppTheme.catOrange,
                            isActive: currentStatus == AttendanceStatus.late,
                            theme: theme,
                            onPressed: () {
                              setState(
                                () => _tempAttendanceStates[student.id] =
                                    AttendanceStatus.late,
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          // EXCUSED check
                          _buildAttendanceActionButton(
                            icon: LucideIcons.clipboardCheck,
                            color: AppTheme.catSlate,
                            isActive: currentStatus == AttendanceStatus.excused,
                            theme: theme,
                            onPressed: () {
                              setState(
                                () => _tempAttendanceStates[student.id] =
                                    AttendanceStatus.excused,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Bottom Action Save Attendance Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppButton.primary(
                  icon: LucideIcons.check,
                  label:
                      'Save Attendance for ${_attendanceSelectedDate.day.toString().padLeft(2, '0')}/${_attendanceSelectedDate.month.toString().padLeft(2, '0')}/${_attendanceSelectedDate.year}',
                  onPressed: () {
                    AppModals.showErrorDialog(
                      context: context,
                      title: 'Attendance Not Saved',
                      message: 'Attendance storage is not connected yet. Your selections have not been saved.',
                    );
                  },
                ),
                const SizedBox(width: 12),
                AppButton.danger(
                  icon: LucideIcons.trash2,
                  label: 'Clear',
                  onPressed: () {
                    setState(() {
                      _tempAttendanceStates.clear();
                    });
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderConfigButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return AppButton.outline(
      label: label,
      icon: icon,
      isSmall: true,
      onPressed: onPressed,
    );
  }

  Widget _buildAttendanceCountBadge({
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceActionButton({
    required IconData icon,
    required Color color,
    required bool isActive,
    required ThemeData theme,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 30,
      height: 30,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: isActive ? color : theme.colorScheme.surface,
          foregroundColor: isActive
              ? Colors.white
              : theme.colorScheme.onSurface.withValues(alpha: 0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: isActive
                ? BorderSide.none
                : BorderSide(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                  ),
          ),
        ),
        onPressed: onPressed,
        child: Icon(icon, size: 15),
      ),
    );
  }
}
