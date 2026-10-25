import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/features/teacher/sub_features/class_management/widgets/unified_enroll_student_dialog.dart';
import 'package:class_realm/features/teacher/sub_features/class_management/widgets/edit_student_dialog.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/data/repositories/supabase_student_repository.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/shared/widgets/shimmer_loading.dart';

class TeacherStudentManagementTab extends StatefulWidget {
  const TeacherStudentManagementTab({super.key});

  @override
  State<TeacherStudentManagementTab> createState() =>
      _TeacherStudentManagementTabState();
}

class _TeacherStudentManagementTabState
    extends State<TeacherStudentManagementTab> {
  bool _showArchivedStudents = false;
  bool _isLoading = true;
  String _studentSearchQuery = '';
  String _selectedSubjectFilter = '— All Subjects —';
  String _selectedSectionFilter = '— All Sections —';
  String _sortColumn = 'lastName';
  bool _sortAscending = true;
  final Set<String> _selectedStudentIds = {};
  RealtimeChannel? _realtimeChannel;

  List<UserModel> _activeStudents = [];
  List<UserModel> _archivedStudents = [];
  List<String> _teacherSubjects = [];
  List<String> _teacherSections = [];
  List<Map<String, dynamic>> _teacherSubjectsData = [];

  int _currentPage = 1;
  final int _itemsPerPage = 20;

  @override
  void initState() {
    super.initState();
    _loadFilters();
    _loadData();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('teacher_students_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'student_enrollments',
          callback: (payload) => _loadData(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'student_info',
          callback: (payload) => _loadData(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
    _studentNameCtrl.dispose();
    _studentIdCtrl.dispose();
    _studentSectionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFilters() async {
    final sub = LocalStorageService.getString('student_management_subject');
    final sec = LocalStorageService.getString('student_management_section');
    if (sub != null && sub != '— All Subjects —' && sub.isNotEmpty) {
      _selectedSubjectFilter = sub;
    }
    if (sec != null) _selectedSectionFilter = sec;
  }

  Future<void> _saveFilters() async {
    await Future.wait([
      LocalStorageService.saveString(
        'student_management_subject',
        _selectedSubjectFilter,
      ),
      LocalStorageService.saveString(
        'student_management_section',
        _selectedSectionFilter,
      ),
    ]);
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final teacherId = AuthRepository.instance.currentUser?.id;
    if (teacherId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final subjectRepo = SubjectRepository.instance;
      final subjectsData = await subjectRepo.getTeacherSubjects(teacherId);
      final subjectsSet = <String>{};
      final sectionsSet = <String>{};
      for (final row in subjectsData) {
        if (row['subject_name'] != null) {
          subjectsSet.add(row['subject_name']);
        }
        if (row['section_name'] != null) {
          sectionsSet.add(row['section_name']);
        }
      }

      final studentRepo = SupabaseStudentRepository();
      final active = await studentRepo.getStudentsForTeacher(
        teacherId,
        includeArchived: false,
      );
      final archived = await studentRepo.getStudentsForTeacher(
        teacherId,
        includeArchived: true,
      );

      if (mounted) {
        setState(() {
          _teacherSubjectsData = subjectsData;
          _teacherSubjects = subjectsSet.toList()..sort();
          _teacherSections = sectionsSet.toList()..sort();
          _activeStudents = active;
          // Filter archived so it doesn't duplicate ones in active
          _archivedStudents = archived.where((s) => s.isArchived).toList();

          if ((_selectedSubjectFilter == '— All Subjects —' || !_teacherSubjects.contains(_selectedSubjectFilter)) &&
              _teacherSubjects.isNotEmpty) {
            _selectedSubjectFilter = _teacherSubjects.first;
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Student load notice: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  final _studentNameCtrl = TextEditingController();
  final _studentIdCtrl = TextEditingController();
  final _studentSectionCtrl = TextEditingController();

  void _onSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
  }

  int _calculateAge(DateTime birthday) {
    final today = DateTime.now();
    var age = today.year - birthday.year;
    final birthdayThisYear = DateTime(today.year, birthday.month, birthday.day);
    if (today.isBefore(birthdayThisYear)) age--;
    return age;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tableHeaderColor = theme.colorScheme.secondary;
    final tableHeaderTextColor = theme.colorScheme.onSurface;
    final tableBorderColor = theme.colorScheme.onSurface.withValues(
      alpha: 0.08,
    );
    final alternateRowColor = theme.colorScheme.secondary.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.3 : 0.35,
    );
    // Calculate available sections based on selected subject
    List<String> availableSections = [];
    if (_selectedSubjectFilter == '— All Subjects —') {
      availableSections = _teacherSections;
    } else {
      final filteredSectionsSet = <String>{};
      for (final row in _teacherSubjectsData) {
        if (row['subject_name'] == _selectedSubjectFilter &&
            row['section_name'] != null) {
          filteredSectionsSet.add(row['section_name']);
        }
      }
      availableSections = filteredSectionsSet.toList()..sort();

      // If the currently selected section is not in the available sections, reset it
      if (_selectedSectionFilter != '— All Sections —' &&
          !availableSections.contains(_selectedSectionFilter)) {
        // We can't setState during build easily, but since this is just filtering,
        // we can just treat it as '— All Sections —' for now, or just let it reset in the UI.
        // It's better to reset it in the onChanged of the subject dropdown.
      }
    }

    var displayList =
        (_showArchivedStudents ? _archivedStudents : _activeStudents).where((
          s,
        ) {
          final matchesSearch =
              s.fullName.toLowerCase().contains(
                _studentSearchQuery.toLowerCase(),
              ) ||
              (s.lrn?.toLowerCase().contains(
                    _studentSearchQuery.toLowerCase(),
                  ) ??
                  false);
          final effectiveSubject = _teacherSubjects.contains(_selectedSubjectFilter)
              ? _selectedSubjectFilter
              : (_teacherSubjects.isNotEmpty ? _teacherSubjects.first : null);
          final matchesSubject = effectiveSubject == null ||
              (s.enrolledSubjectName?.trim().toLowerCase() == effectiveSubject.trim().toLowerCase());
          final matchesSection =
              _selectedSectionFilter == '— All Sections —' ||
              (s.departmentOrSection?.trim().toLowerCase() == _selectedSectionFilter.trim().toLowerCase());
          return matchesSearch && matchesSubject && matchesSection;
        }).toList();

    // Sort logic
    displayList.sort((a, b) {
      int cmp = 0;
      switch (_sortColumn) {
        case 'lastName':
          final aLast =
              a.lastName ??
              (a.fullName.contains(' ')
                  ? a.fullName.split(' ').last
                  : a.fullName);
          final bLast =
              b.lastName ??
              (b.fullName.contains(' ')
                  ? b.fullName.split(' ').last
                  : b.fullName);
          cmp = aLast.compareTo(bLast);
          break;
        case 'firstName':
          final aFirst =
              a.firstName ??
              (a.fullName.contains(' ') ? a.fullName.split(' ').first : '');
          final bFirst =
              b.firstName ??
              (b.fullName.contains(' ') ? b.fullName.split(' ').first : '');
          cmp = aFirst.compareTo(bFirst);
          break;
        case 'lrn':
          cmp = (a.lrn ?? a.studentId ?? '').compareTo(
            b.lrn ?? b.studentId ?? '',
          );
          break;
        case 'gender':
          cmp = (a.gender ?? '').compareTo(b.gender ?? '');
          break;
        case 'birthdate':
          if (a.birthday == null) {
            cmp = b.birthday == null ? 0 : 1;
          } else if (b.birthday == null) {
            cmp = -1;
          } else {
            cmp = a.birthday!.compareTo(b.birthday!);
          }
          break;
        case 'email':
          cmp = a.email.compareTo(b.email);
          break;
        case 'status':
          cmp = a.status.name.compareTo(b.status.name);
          break;
        default:
          cmp = 0;
      }
      return _sortAscending ? cmp : -cmp;
    });

    int totalPages = (displayList.length / _itemsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;
    if (_currentPage > totalPages) _currentPage = totalPages;

    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, displayList.length);
    final paginatedList = displayList.sublist(startIndex, endIndex);


    const colNumWidth = 56.0;
    const colLastNameWidth = 150.0;
    const colFirstNameWidth = 140.0;
    const colLrnWidth = 150.0;
    const colGenderWidth = 110.0;
    const colBirthdateWidth = 160.0;
    const colEmailWidth = 240.0;
    const colStatusWidth = 180.0;
    const colActionsWidth = 170.0;

    const totalTableWidth =
        colNumWidth +
        colLastNameWidth +
        colFirstNameWidth +
        colLrnWidth +
        colGenderWidth +
        colBirthdateWidth +
        colEmailWidth +
        colStatusWidth +
        colActionsWidth;

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 16,
                  spacing: 16,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Student Directory',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'View and manage your student directory, update profiles, and handle account archives.',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final filters = Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.12,
                              ),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _teacherSubjects.contains(_selectedSubjectFilter)
                                  ? _selectedSubjectFilter
                                  : (_teacherSubjects.isNotEmpty ? _teacherSubjects.first : null),
                              dropdownColor: theme.colorScheme.surface,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                              hint: Text(
                                _teacherSubjects.isEmpty ? 'No Subjects' : 'Select Subject',
                                style: const TextStyle(fontSize: 13),
                              ),
                              items: _teacherSubjects
                                  .map(
                                    (sub) => DropdownMenuItem(
                                      value: sub,
                                      child: Text(
                                        sub,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedSubjectFilter = val;
                                    _selectedSectionFilter = '— All Sections —';
                                    _currentPage = 1;
                                  });
                                  unawaited(_saveFilters());
                                }
                              },
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.12,
                              ),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedSectionFilter,
                              dropdownColor: theme.colorScheme.surface,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                              items: ['— All Sections —', ...availableSections]
                                  .map(
                                    (sec) => DropdownMenuItem(
                                      value: sec,
                                      child: Text(
                                        sec,
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedSectionFilter = val;
                                    _currentPage = 1;
                                  });
                                  unawaited(_saveFilters());
                                }
                              },
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 300,
                          child: TextField(
                            onChanged: (v) =>
                                setState(() => _studentSearchQuery = v),
                            decoration: InputDecoration(
                              hintText: 'Search by name or LRN...',
                              hintStyle: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                              prefixIcon: Icon(
                                LucideIcons.search,
                                size: 20,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                              filled: true,
                              fillColor: theme.colorScheme.surface,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 16,
                              ),
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
                      ],
                    );
                    final archiveButton = SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _showArchivedStudents
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                          side: BorderSide(
                            color: _showArchivedStudents
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.2,
                                  ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: Icon(
                          _showArchivedStudents
                              ? Icons.people_outline
                              : Icons.archive_outlined,
                          size: 18,
                        ),
                        label: Text(
                          _showArchivedStudents
                              ? 'View Active'
                              : 'View Archive (${_archivedStudents.length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        onPressed: () => setState(() {
                          _showArchivedStudents = !_showArchivedStudents;
                          _selectedStudentIds.clear();
                        }),
                      ),
                    );

                    final actionButtons = Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.end,
                      children: [
                        AppButton.success(
                          icon: LucideIcons.upload,
                          label: 'Import Excel',
                          onPressed: () => UnifiedEnrollStudentDialog.show(
                            context,
                            teacherSubjects: _teacherSubjectsData,
                            initialTabIndex: 1, // File import tab
                            onStudentCreated: _loadData,
                          ),
                        ),
                        AppButton.primary(
                          icon: LucideIcons.userPlus,
                          label: 'Add Students',
                          onPressed: () => UnifiedEnrollStudentDialog.show(
                            context,
                            teacherSubjects: _teacherSubjectsData,
                            initialTabIndex: 0, // Manual add tab
                            onStudentCreated: _loadData,
                          ),
                        ),
                        archiveButton,
                      ],
                    );

                    if (constraints.maxWidth < 760) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          filters,
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: actionButtons,
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: filters),
                        const SizedBox(width: 12),
                        actionButtons,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: (_isLoading && _activeStudents.isEmpty && _archivedStudents.isEmpty)
                      ? const ShimmerManagementTable(rowCount: 8)
                      : Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: tableBorderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: totalTableWidth,
                              child: Column(
                                children: [
                                  Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: tableHeaderColor,
                                    ),
                                    child: Row(
                                      children: [
                                        _buildHeaderCell(
                                          width: colNumWidth,
                                          child: Center(
                                            child: Text(
                                              '#',
                                              style: TextStyle(
                                                color: tableHeaderTextColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                        _buildHeaderCell(
                                          width: colLastNameWidth,
                                          child: _buildClickableHeaderTitle(
                                            'LAST NAME',
                                            'lastName',
                                          ),
                                        ),
                                        _buildHeaderCell(
                                          width: colFirstNameWidth,
                                          child: _buildClickableHeaderTitle(
                                            'FIRST NAME',
                                            'firstName',
                                          ),
                                        ),
                                        _buildHeaderCell(
                                          width: colLrnWidth,
                                          child: _buildClickableHeaderTitle(
                                            'LRN',
                                            'lrn',
                                          ),
                                        ),
                                        _buildHeaderCell(
                                          width: colGenderWidth,
                                          child: _buildClickableHeaderTitle(
                                            'GENDER',
                                            'gender',
                                          ),
                                        ),
                                        _buildHeaderCell(
                                          width: colBirthdateWidth,
                                          child: _buildClickableHeaderTitle(
                                            'BIRTHDATE',
                                            'birthdate',
                                          ),
                                        ),
                                        _buildHeaderCell(
                                          width: colEmailWidth,
                                          child: Text(
                                            'EMAIL',
                                            style: TextStyle(
                                              color: tableHeaderTextColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),

                                        _buildHeaderCell(
                                          width: colStatusWidth,
                                          child: _buildClickableHeaderTitle(
                                            'STATUS',
                                            'status',
                                          ),
                                        ),
                                        _buildHeaderCell(
                                          width: colActionsWidth,
                                          hasRightBorder: false,
                                          child: Center(
                                            child: Text(
                                              'ACTIONS',
                                              style: TextStyle(
                                                color: tableHeaderTextColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: displayList.isEmpty
                                        ? Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  _showArchivedStudents
                                                      ? Icons.archive_outlined
                                                      : Icons.school_outlined,
                                                  size: 56,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.5),
                                                ),
                                                const SizedBox(height: 16),
                                                Text(
                                                  _showArchivedStudents
                                                      ? 'No archived students found.'
                                                      : 'No students found for ${_teacherSubjects.contains(_selectedSubjectFilter) ? _selectedSubjectFilter : (_teacherSubjects.isNotEmpty ? _teacherSubjects.first : "this subject")} in $_selectedSectionFilter.',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(alpha: 0.8),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : ListView.builder(
                                            itemCount: paginatedList.length,
                                            itemBuilder: (ctx, i) {
                                              final s = paginatedList[i];
                                              final isSelected =
                                                  _selectedStudentIds.contains(
                                                    s.id,
                                                  );
                                              final lastName =
                                                  s.lastName ??
                                                  (s.fullName.contains(' ')
                                                      ? s.fullName
                                                            .split(' ')
                                                            .last
                                                      : s.fullName);
                                              final firstName =
                                                  s.firstName ??
                                                  (s.fullName.contains(' ')
                                                      ? s.fullName
                                                            .split(' ')
                                                            .first
                                                      : '');
                                              final lrn =
                                                  s.lrn ?? s.studentId ?? 'N/A';
                                              final gender = s.gender ?? '—';
                                              final birthdayLabel =
                                                  s.birthday == null
                                                  ? '—'
                                                  : '${s.birthday!.year}-${s.birthday!.month.toString().padLeft(2, '0')}-${s.birthday!.day.toString().padLeft(2, '0')} (${_calculateAge(s.birthday!)})';

                                              return Container(
                                                height: 52,
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? theme
                                                            .colorScheme
                                                            .primary
                                                            .withValues(
                                                              alpha: 0.12,
                                                            )
                                                      : (i % 2 == 1
                                                            ? alternateRowColor
                                                            : theme
                                                                  .colorScheme
                                                                  .surface),
                                                  border: Border(
                                                    bottom: BorderSide(
                                                      color: tableBorderColor,
                                                    ),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    _buildDataCell(
                                                      width: colNumWidth,
                                                      child: Center(
                                                        child: Text(
                                                          '${startIndex + i + 1}',
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .onSurface,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    _buildDataCell(
                                                      width: colLastNameWidth,
                                                      child: Text(
                                                        lastName,
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: theme
                                                              .colorScheme
                                                              .onSurface,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    _buildDataCell(
                                                      width: colFirstNameWidth,
                                                      child: Text(
                                                        firstName,
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: theme
                                                              .colorScheme
                                                              .onSurface,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    _buildDataCell(
                                                      width: colLrnWidth,
                                                      child: Text(
                                                        lrn.replaceAll(' ', ''),
                                                        maxLines: 1,
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontFamily:
                                                              'monospace',
                                                          color: theme
                                                              .colorScheme
                                                              .onSurface
                                                              .withValues(
                                                                alpha: 0.8,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                    _buildDataCell(
                                                      width: colGenderWidth,
                                                      child: Text(
                                                        gender,
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: theme
                                                              .colorScheme
                                                              .onSurface,
                                                        ),
                                                      ),
                                                    ),
                                                    _buildDataCell(
                                                      width: colBirthdateWidth,
                                                      child: Text(
                                                        birthdayLabel,
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: theme
                                                              .colorScheme
                                                              .onSurface,
                                                        ),
                                                      ),
                                                    ),
                                                    _buildDataCell(
                                                      width: colEmailWidth,
                                                      child: Text(
                                                        s.email,
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: theme
                                                              .colorScheme
                                                              .onSurface,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),

                                                    _buildDataCell(
                                                      width: colStatusWidth,
                                                      child:
                                                          StatusBadge.fromAccountStatus(
                                                            s.isArchived ? AccountStatus.archived : s.status,
                                                          ),
                                                    ),
                                                    _buildDataCell(
                                                      width: colActionsWidth,
                                                      hasRightBorder: false,
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                        children: [
                                                          if (!_showArchivedStudents) ...[
                                                            IconButton(
                                                              tooltip: s.status == AccountStatus.pendingFirstLogin
                                                                  ? 'Cannot edit: Pending First Login'
                                                                  : 'Edit Student Details',
                                                              icon: Icon(
                                                                Icons
                                                                    .edit_outlined,
                                                                color: s.status == AccountStatus.pendingFirstLogin
                                                                    ? theme.colorScheme.onSurface.withValues(alpha: 0.25)
                                                                    : const Color(0xFF64748B),
                                                                size: 18,
                                                              ),
                                                              splashRadius: 18,
                                                              onPressed: s.status == AccountStatus.pendingFirstLogin
                                                                  ? () {
                                                                      AppModals.showErrorDialog(
                                                                        context: context,
                                                                        title: 'Cannot Edit Student',
                                                                        message:
                                                                            'This student account has not completed their first login yet. Profiles can only be edited once the student has logged in and set up their account.',
                                                                      );
                                                                    }
                                                                  : () =>
                                                                      EditStudentDialog.show(
                                                                        context,
                                                                        student: s,
                                                                        onStudentUpdated:
                                                                            _loadData,
                                                                      ),
                                                            ),
                                                            IconButton(
                                                              tooltip: 'Archive Student',
                                                              icon: Icon(
                                                                Icons
                                                                    .archive_outlined,
                                                                color: Color(
                                                                  0xFF94A3B8,
                                                                ),
                                                                size: 18,
                                                              ),
                                                              splashRadius: 18,
                                                              onPressed: () async {
                                                                final messenger =
                                                                    ScaffoldMessenger.of(
                                                                      context,
                                                                    );
                                                                final confirm = await AppModals.showArchiveCooldownDialog(
                                                                  context:
                                                                      context,
                                                                  title: 'Archive Student',
                                                                  message:
                                                                      'Are you sure you want to archive ${s.fullName}? Their enrollment in this class will be archived. All grades and classwork submissions are preserved and can be restored anytime.',
                                                                  confirmLabel:
                                                                      'Archive',
                                                                  confirmColor:
                                                                      AppTheme
                                                                          .catOrange,
                                                                );
                                                                if (confirm ==
                                                                    true) {
                                                                  await SupabaseStudentRepository()
                                                                      .archiveStudent(
                                                                        s.id,
                                                                        s.enrolledSubjectId,
                                                                        (s.status == AccountStatus.pendingFirstLogin)
                                                                            ? 'pending_first_login'
                                                                            : 'active',
                                                                      );
                                                                  _loadData();
                                                                  if (context.mounted) {
                                                                    AppModals.showSuccessDialog(
                                                                      context: context,
                                                                      title: 'Student Archived',
                                                                      message: '${s.fullName} has been moved to archives.',
                                                                    );
                                                                  }
                                                                }
                                                              },
                                                            ),
                                                          ] else ...[
                                                            IconButton(
                                                              tooltip: 'Restore Student',
                                                              icon: Icon(
                                                                Icons.restore,
                                                                color: AppTheme
                                                                    .catGreen,
                                                                size: 18,
                                                              ),
                                                              splashRadius: 18,
                                                              onPressed: () async {
                                                                final confirm = await AppModals.showConfirmDialog(
                                                                  context: context,
                                                                  title: 'Restore Student',
                                                                  message: 'Are you sure you want to restore ${s.fullName} to active enrollment in this class?',
                                                                  confirmLabel: 'Restore',
                                                                  confirmColor: Colors.green,
                                                                );
                                                                if (confirm == true) {
                                                                  await SupabaseStudentRepository()
                                                                      .restoreStudent(
                                                                        s.id,
                                                                        s.enrolledSubjectId,
                                                                      );
                                                                  _loadData();
                                                                  if (context.mounted) {
                                                                    AppModals.showSuccessDialog(
                                                                      context:
                                                                          context,
                                                                      title: 'Restored',
                                                                      message:
                                                                          '${s.fullName} has been restored to active enrollment.',
                                                                    );
                                                                  }
                                                                }
                                                              },
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                  Container(
                                    height: 52,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFF8FAFC),
                                      border: Border(
                                        top: BorderSide(
                                          color: Color(0xFFE2E8F0),
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Showing ${displayList.isEmpty ? 0 : startIndex + 1} to $endIndex of ${displayList.length} entries',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        if (totalPages > 1)
                                          Row(
                                            children: [
                                              _buildPageButton(
                                                'First',
                                                () => setState(
                                                  () => _currentPage = 1,
                                                ),
                                                _currentPage > 1,
                                              ),
                                              _buildPageButton(
                                                '<',
                                                () => setState(
                                                  () => _currentPage--,
                                                ),
                                                _currentPage > 1,
                                              ),
                                              for (
                                                int p = 1;
                                                p <= totalPages;
                                                p++
                                              )
                                                if (p >= _currentPage - 2 &&
                                                    p <= _currentPage + 2)
                                                  _buildPageButton(
                                                    p.toString(),
                                                    () => setState(
                                                      () => _currentPage = p,
                                                    ),
                                                    true,
                                                    isActive: p == _currentPage,
                                                  ),
                                              _buildPageButton(
                                                '>',
                                                () => setState(
                                                  () => _currentPage++,
                                                ),
                                                _currentPage < totalPages,
                                              ),
                                              _buildPageButton(
                                                'Last',
                                                () => setState(
                                                  () =>
                                                      _currentPage = totalPages,
                                                ),
                                                _currentPage < totalPages,
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_selectedStudentIds.isNotEmpty)
                        Positioned(
                          bottom: 24,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.inverseSurface,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${_selectedStudentIds.length} selected',
                                    style: TextStyle(
                                      color: theme.colorScheme.onInverseSurface,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  if (_showArchivedStudents) ...[
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.catGreen,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                      ),
                                      icon: Icon(Icons.restore, size: 16),
                                      label: Text(
                                        'Restore',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      onPressed: () async {
                                        final selectedCount =
                                            _selectedStudentIds.length;
                                        final confirm =
                                            await AppModals.showConfirmDialog(
                                              context: context,
                                              title: 'Restore Selected Students',
                                              message:
                                                  'Are you sure you want to restore $selectedCount selected student(s) to active enrollment?',
                                              confirmLabel: 'Restore Selected',
                                              confirmColor: Colors.green,
                                            );
                                        if (confirm == true) {
                                          for (final id in _selectedStudentIds) {
                                            await SupabaseStudentRepository()
                                                .restoreStudent(id);
                                          }
                                          setState(() {
                                            _selectedStudentIds.clear();
                                            _loadData();
                                          });
                                          if (context.mounted) {
                                            AppModals.showSuccessDialog(
                                              context: context,
                                              title: 'Students Restored',
                                              message:
                                                  '$selectedCount student(s) restored to active enrollment.',
                                            );
                                          }
                                        }
                                      },
                                    ),
                                    if (false) const SizedBox(width: 8),
                                    if (false) ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.catRed,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                      ),
                                      icon: Icon(
                                        Icons.delete_forever_outlined,
                                        size: 16,
                                      ),
                                      label: Text(
                                        'Permanent delete',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      onPressed: () async {
                                        final selectedCount =
                                            _selectedStudentIds.length;
                                        final confirm =
                                            await AppModals.showConfirmDialog(
                                              context: context,
                                              title:
                                                  'Permanently Delete Selected',
                                              message:
                                                  'Permanently delete $selectedCount selected student(s)? If any student has no other enrolled classes, their account and Firebase Auth login will be permanently erased. This action cannot be undone.',
                                              confirmLabel: 'Permanent Delete',
                                              confirmColor: AppTheme.catRed,
                                            );
                                        if (confirm == true) {
                                          for (final id
                                              in _selectedStudentIds) {
                                            final student = displayList
                                                .firstWhere(
                                                  (st) => st.id == id,
                                                );
                                            await SupabaseStudentRepository()
                                                .permanentlyDeleteStudent(
                                                  id,
                                                  student.enrolledSubjectId,
                                                );
                                          }
                                          _selectedStudentIds.clear();
                                          _loadData();
                                          if (context.mounted) {
                                            AppModals.showSuccessDialog(
                                              context: context,
                                              title: 'Students Deleted',
                                              message:
                                                  '$selectedCount student(s) permanently deleted.',
                                            );
                                          }
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: theme
                                            .colorScheme
                                            .onInverseSurface
                                            .withValues(alpha: 0.7),
                                      ),
                                      onPressed: () => setState(
                                        () => _selectedStudentIds.clear(),
                                      ),
                                      child: Text(
                                        'Cancel',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: theme
                                            .colorScheme
                                            .onInverseSurface
                                            .withValues(alpha: 0.7),
                                      ),
                                      onPressed: () => setState(
                                        () => _selectedStudentIds.clear(),
                                      ),
                                      child: Text(
                                        'Cancel',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.catRed,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                      ),
                                      icon: Icon(
                                        Icons.archive_outlined,
                                        size: 16,
                                      ),
                                      label: Text(
                                        'Archive selected',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      onPressed: () async {
                                        final selectedCount =
                                            _selectedStudentIds.length;
                                        final confirm =
                                            await AppModals.showConfirmDialog(
                                              context: context,
                                              title:
                                                  'Archive Selected Students',
                                              message:
                                                  'Are you sure you want to archive $selectedCount selected student(s)? Their enrollment will be moved to archives, and all class records remain preserved.',
                                              confirmLabel: 'Archive Selected',
                                              confirmColor: AppTheme.catOrange,
                                            );
                                        if (confirm == true) {
                                          for (final id
                                              in _selectedStudentIds) {
                                            final student = displayList
                                                .firstWhere(
                                                  (st) => st.id == id,
                                                );
                                            await SupabaseStudentRepository()
                                                .archiveStudent(
                                                  id,
                                                  student.enrolledSubjectId,
                                                  (student.status == AccountStatus.pendingFirstLogin)
                                                      ? 'pending_first_login'
                                                      : 'active',
                                                );
                                          }
                                          _selectedStudentIds.clear();
                                          _loadData();
                                          if (context.mounted) {
                                            AppModals.showSuccessDialog(
                                              context: context,
                                              title: 'Students Archived',
                                              message:
                                                  '$selectedCount student(s) moved to archives.',
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                minHeight: 3,
                color: theme.colorScheme.primary,
                backgroundColor: Colors.transparent,
              ),
            ),
        ],
      );
  }

  Widget _buildHeaderCell({
    required double width,
    required Widget child,
    bool hasRightBorder = true,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: hasRightBorder
            ? Border(
                right: BorderSide(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                ),
              )
            : null,
      ),
      child: child,
    );
  }

  Widget _buildClickableHeaderTitle(String title, String columnKey) {
    final theme = Theme.of(context);
    final isCurrent = _sortColumn == columnKey;
    final icon = !isCurrent ? ' ↕' : (_sortAscending ? ' ▴' : ' ▾');
    return InkWell(
      onTap: () => _onSort(columnKey),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              '$title$icon',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: isCurrent ? FontWeight.w800 : FontWeight.bold,
                fontSize: 12.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataCell({
    required double width,
    required Widget child,
    bool hasRightBorder = true,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: hasRightBorder
            ? Border(
                right: BorderSide(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                ),
              )
            : null,
      ),
      child: child,
    );
  }

  Widget _buildPageButton(
    String label,
    VoidCallback onTap,
    bool enabled, {
    bool isActive = false,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: enabled && !isActive ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? theme.colorScheme.primary : Colors.white,
          border: Border.all(color: Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive
                ? Colors.white
                : (enabled ? theme.colorScheme.primary : Colors.grey),
          ),
        ),
      ),
    );
  }
}
