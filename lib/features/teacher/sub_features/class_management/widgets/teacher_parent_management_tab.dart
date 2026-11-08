import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/features/teacher/sub_features/class_management/widgets/add_parent_dialog.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/data/repositories/supabase_student_repository.dart';
import 'package:class_realm/data/repositories/supabase_parent_repository.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/core/utils/parent_credential_helper.dart';
import 'package:class_realm/core/utils/search_utils.dart';
import 'package:class_realm/core/utils/validators.dart';
import 'package:class_realm/shared/widgets/shimmer_loading.dart';
import 'package:class_realm/widgets/common/app_date_picker_field.dart';

class TeacherParentManagementTab extends StatefulWidget {
  final List<UserModel>? parents;

  const TeacherParentManagementTab({super.key, this.parents});

  @override
  State<TeacherParentManagementTab> createState() =>
      _TeacherParentManagementTabState();
}

class _TeacherParentManagementTabState
    extends State<TeacherParentManagementTab> {
  bool _showArchivedParents = false;
  bool _isLoading = true;
  String _parentSearchQuery = '';
  String? _selectedSubjectFilter;
  String _selectedSectionFilter = '— All Sections —';
  String _sortColumn = 'lastName';
  bool _sortAscending = true;
  final Set<String> _selectedParentIds = {};
  RealtimeChannel? _realtimeChannel;

  List<UserModel> _activeParents = [];
  List<UserModel> _archivedParents = [];
  List<UserModel> _enrolledStudents = [];
  List<String> _teacherSubjects = [];
  List<String> _teacherSections = [];
  List<Map<String, dynamic>> _teacherSubjectsData = [];

  int _currentPage = 1;
  final int _itemsPerPage = 20;

  @override
  void initState() {
    super.initState();
    _loadFilters();
    _hydrateFromCache();
    _loadData();
    _subscribeRealtime();
  }

  void _hydrateFromCache() {
    final teacherId = AuthRepository.instance.currentUser?.id;
    if (teacherId == null) return;

    final cachedActive = AppDataCache.instance.getCached<List<UserModel>>(
      'teacher_parents_${teacherId}_all_false',
      (json) => (json as List)
          .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
    final cachedArchived = AppDataCache.instance.getCached<List<UserModel>>(
      'teacher_parents_${teacherId}_all_true',
      (json) => (json as List)
          .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
    final cachedStudents = AppDataCache.instance.getCached<List<UserModel>>(
      'teacher_students_${teacherId}_all_false',
      (json) => (json as List)
          .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
    final cachedSubjects = SubjectRepository.instance.getCachedTeacherSubjects(
      teacherId,
    );

    if (cachedActive != null ||
        cachedStudents != null ||
        cachedSubjects.isNotEmpty) {
      final subjectsSet = <String>{};
      final sectionsSet = <String>{};
      for (final row in cachedSubjects) {
        if (row['subject_name'] != null) subjectsSet.add(row['subject_name']);
        if (row['section_name'] != null) sectionsSet.add(row['section_name']);
      }

      _activeParents = cachedActive ?? _activeParents;
      _archivedParents = cachedArchived ?? _archivedParents;
      _enrolledStudents = cachedStudents ?? _enrolledStudents;
      _teacherSubjectsData = cachedSubjects;
      _teacherSubjects = subjectsSet.toList()..sort();
      _teacherSections = sectionsSet.toList()..sort();
      if (_selectedSubjectFilter == null && _teacherSubjects.isNotEmpty) {
        _selectedSubjectFilter = _teacherSubjects.first;
      }
      if (cachedActive != null && cachedActive.isNotEmpty) {
        _isLoading = false;
      }
    }
  }

  void _subscribeRealtime() {
    try {
      _realtimeChannel = Supabase.instance.client
          .channel('teacher_parents_realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'parent_student_links',
            callback: (payload) => _loadData(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'parent_profiles',
            callback: (payload) => _loadData(),
          )
          .subscribe();
    } catch (_) {}
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_realtimeChannel!);
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _loadFilters() async {
    final sub = LocalStorageService.getString('parent_management_subject');
    final sec = LocalStorageService.getString('parent_management_section');
    if (sub != null) _selectedSubjectFilter = sub;
    if (sec != null) _selectedSectionFilter = sec;
  }

  Future<void> _saveFilters() async {
    await Future.wait([
      if (_selectedSubjectFilter != null)
        LocalStorageService.saveString(
          'parent_management_subject',
          _selectedSubjectFilter!,
        ),
      LocalStorageService.saveString(
        'parent_management_section',
        _selectedSectionFilter,
      ),
    ]);
  }

  int _calculateAge(DateTime birthday) {
    final today = DateTime.now();
    var age = today.year - birthday.year;
    final birthdayThisYear = DateTime(today.year, birthday.month, birthday.day);
    if (today.isBefore(birthdayThisYear)) age--;
    return age;
  }

  Future<void> _loadData() async {
    if (_activeParents.isEmpty && _archivedParents.isEmpty) {
      setState(() => _isLoading = true);
    }

    final teacherId = AuthRepository.instance.currentUser?.id;
    if (teacherId == null) {
      final fallbackParents = widget.parents ?? const <UserModel>[];
      setState(() {
        _activeParents = fallbackParents.where((p) => !p.isArchived).toList();
        _archivedParents = fallbackParents.where((p) => p.isArchived).toList();
        _isLoading = false;
      });
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
      final students = await studentRepo.getStudentsForTeacher(
        teacherId,
        includeArchived: false,
        onFreshData: (fresh) {
          if (mounted) setState(() => _enrolledStudents = fresh);
        },
      );

      final parentRepo = SupabaseParentRepository();
      final active = await parentRepo.getParentsForTeacher(
        teacherId,
        includeArchived: false,
        onFreshData: (fresh) {
          if (mounted) setState(() => _activeParents = fresh);
        },
      );
      final archived = await parentRepo.getParentsForTeacher(
        teacherId,
        includeArchived: true,
        onFreshData: (fresh) {
          if (mounted) setState(() => _archivedParents = fresh);
        },
      );

      if (mounted) {
        setState(() {
          _teacherSubjectsData = subjectsData;
          _teacherSubjects = subjectsSet.toList()..sort();
          _teacherSections = sectionsSet.toList()..sort();
          _enrolledStudents = students;
          _activeParents = active;
          _archivedParents = archived;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Parent load notice: $e');
      if (mounted) {
        final fallbackParents = widget.parents ?? const <UserModel>[];
        setState(() {
          _activeParents = fallbackParents.where((p) => !p.isArchived).toList();
          _archivedParents = fallbackParents
              .where((p) => p.isArchived)
              .toList();
          _isLoading = false;
        });
      }
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tableHeaderTextColor = theme.colorScheme.onSurface;
    final tableBorderColor = theme.colorScheme.onSurface.withValues(
      alpha: 0.08,
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
    }

    var displayList = (_showArchivedParents ? _archivedParents : _activeParents)
        .where((p) {
          final linkedStudent = _enrolledStudents
              .where((user) => user.id == p.linkedStudentId)
              .firstOrNull;

          final studentName =
              (p.parentGuardianName != null &&
                  p.parentGuardianName!.trim().isNotEmpty)
              ? p.parentGuardianName!
              : (linkedStudent?.fullName ?? '');
          final studentSection =
              linkedStudent?.departmentOrSection ?? p.departmentOrSection ?? '';
          final studentSubject =
              linkedStudent?.enrolledSubjectName ?? p.enrolledSubjectName ?? '';

          final matchesSearch =
              p.fullName.toLowerCase().contains(
                _parentSearchQuery.toLowerCase(),
              ) ||
              p.username.toLowerCase().contains(
                _parentSearchQuery.toLowerCase(),
              ) ||
              studentName.toLowerCase().contains(
                _parentSearchQuery.toLowerCase(),
              );

          final matchesSubject =
              _selectedSubjectFilter == '— All Subjects —' ||
              (studentSubject == _selectedSubjectFilter);

          final matchesSection =
              _selectedSectionFilter == '— All Sections —' ||
              (studentSection == _selectedSectionFilter);

          return matchesSearch && matchesSubject && matchesSection;
        })
        .toList();

    // Sort logic
    if (_parentSearchQuery.trim().isNotEmpty) {
      SearchUtils.sortByRelevance<UserModel>(
        _parentSearchQuery,
        displayList,
        (p) => p.fullName,
      );
    } else {
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
          case 'relationship':
            cmp = (a.parentGuardianRelationship ?? '').compareTo(
              b.parentGuardianRelationship ?? '',
            );
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
          case 'username':
            cmp = a.username.compareTo(b.username);
            break;
          case 'status':
            cmp = a.status.name.compareTo(b.status.name);
            break;
          default:
            cmp = 0;
        }
        return _sortAscending ? cmp : -cmp;
      });
    }

    int totalPages = (displayList.length / _itemsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;
    if (_currentPage > totalPages) _currentPage = totalPages;

    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, displayList.length);
    final paginatedList = displayList.sublist(startIndex, endIndex);

    // Selection check
    paginatedList.isNotEmpty &&
        paginatedList.every((p) => _selectedParentIds.contains(p.id));

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header Row
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
                        'Parent Directory',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'View and manage parent or guardian accounts linked to enrolled students.',
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

              // Controls Row (Filters on left, Actions aligned together on right)
              LayoutBuilder(
                builder: (context, constraints) {
                  final filters = Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Subject Filter
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
                            value:
                                _teacherSubjects.contains(
                                  _selectedSubjectFilter,
                                )
                                ? _selectedSubjectFilter
                                : (_teacherSubjects.isNotEmpty
                                      ? _teacherSubjects.first
                                      : null),
                            dropdownColor: theme.colorScheme.surface,
                            iconEnabledColor: theme.colorScheme.onSurface,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            items: _teacherSubjects
                                .map(
                                  (sub) => DropdownMenuItem(
                                    value: sub,
                                    child: Text(
                                      sub,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                      ),
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

                      // Section Filter
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
                            value:
                                ([
                                  '— All Sections —',
                                  ...availableSections,
                                ].contains(_selectedSectionFilter))
                                ? _selectedSectionFilter
                                : '— All Sections —',
                            dropdownColor: theme.colorScheme.surface,
                            iconEnabledColor: theme.colorScheme.onSurface,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            items: ['— All Sections —', ...availableSections]
                                .map(
                                  (sec) => DropdownMenuItem(
                                    value: sec,
                                    child: Text(
                                      sec,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                      ),
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

                      // Search Input
                      SizedBox(
                        width: 300,
                        child: TextField(
                          onChanged: (v) =>
                              setState(() => _parentSearchQuery = v),
                          decoration: InputDecoration(
                            hintText: 'Search by parent name or student...',
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
                    height: 44, // Match Add Students uniform height
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _showArchivedParents
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                        side: BorderSide(
                          color: _showArchivedParents
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
                        _showArchivedParents
                            ? Icons.people_outline
                            : Icons.archive_outlined,
                        size: 18,
                      ),
                      label: Text(
                        _showArchivedParents
                            ? 'View Active'
                            : 'View Archive (${_archivedParents.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      onPressed: () => setState(() {
                        _showArchivedParents = !_showArchivedParents;
                        _selectedParentIds.clear();
                      }),
                    ),
                  );

                  final actionButtons = Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.end,
                    children: [
                      SizedBox(
                        height: 44,
                        child: AppButton.success(
                          icon: LucideIcons.upload,
                          label: 'Import Excel',
                          onPressed: () {
                            AppModals.showUpcomingFeatureDialog(
                              context,
                              featureName: 'Parent Excel Batch Import',
                            );
                          },
                        ),
                      ),
                      SizedBox(
                        height: 44,
                        child: AppButton.primary(
                          icon: LucideIcons.userPlus,
                          label: 'Add Parent',
                          onPressed: _showAddParentDialog,
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

              // Table Container
              Expanded(
                child:
                    (_isLoading &&
                        _activeParents.isEmpty &&
                        _archivedParents.isEmpty)
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
                              child: Column(
                                children: [
                                  Expanded(
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        const colNumWidth = 56.0;
                                        const colRelWidth = 140.0;
                                        const colBirthdateWidth = 160.0;
                                        const colStatusWidth = 185.0;
                                        const colActionsWidth = 140.0;

                                        const baseFixed =
                                            colNumWidth +
                                            colRelWidth +
                                            colBirthdateWidth +
                                            colStatusWidth +
                                            colActionsWidth;
                                        const baseNameWidth = 260.0;
                                        const baseStudentWidth = 220.0;
                                        const baseTotal =
                                            baseFixed +
                                            baseNameWidth +
                                            baseStudentWidth;

                                        final extraWidth = math.max(
                                          0.0,
                                          constraints.maxWidth - baseTotal,
                                        );
                                        final colNameWidth =
                                            baseNameWidth + (extraWidth * 0.5);
                                        final colStudentWidth =
                                            baseStudentWidth +
                                            (extraWidth * 0.5);
                                        final totalTableWidth = math.max(
                                          constraints.maxWidth,
                                          baseTotal,
                                        );

                                        return SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: SizedBox(
                                            width: totalTableWidth,
                                            child: Column(
                                              children: [
                                                // ── UNIFIED TABLE HEADER ──
                                                Container(
                                                  height: 48,
                                                  decoration: BoxDecoration(
                                                    color: theme
                                                        .colorScheme
                                                        .primary
                                                        .withValues(alpha: 0.1),
                                                    border: Border(
                                                      bottom: BorderSide(
                                                        color: theme
                                                            .colorScheme
                                                            .primary
                                                            .withValues(
                                                              alpha: 0.3,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      _buildHeaderCell(
                                                        width: colNumWidth,
                                                        child: Center(
                                                          child: Text(
                                                            '#',
                                                            style: TextStyle(
                                                              color:
                                                                  tableHeaderTextColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 13,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      _buildHeaderCell(
                                                        width: colNameWidth,
                                                        child:
                                                            _buildClickableHeaderTitle(
                                                              'PARENT / GUARDIAN NAME',
                                                              'lastName',
                                                            ),
                                                      ),
                                                      _buildHeaderCell(
                                                        width: colRelWidth,
                                                        child:
                                                            _buildClickableHeaderTitle(
                                                              'RELATIONSHIP',
                                                              'relationship',
                                                            ),
                                                      ),
                                                      _buildHeaderCell(
                                                        width: colStudentWidth,
                                                        child: Text(
                                                          'LINKED STUDENT',
                                                          style: TextStyle(
                                                            color:
                                                                tableHeaderTextColor,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ),
                                                      _buildHeaderCell(
                                                        width:
                                                            colBirthdateWidth,
                                                        child:
                                                            _buildClickableHeaderTitle(
                                                              'BIRTHDATE',
                                                              'birthdate',
                                                            ),
                                                      ),
                                                      _buildHeaderCell(
                                                        width: colStatusWidth,
                                                        child:
                                                            _buildClickableHeaderTitle(
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
                                                              color:
                                                                  tableHeaderTextColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 13,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                // ── TABLE CONTENT OR EMPTY STATE ──
                                                Expanded(
                                                  child: displayList.isEmpty
                                                      ? Center(
                                                          child: Column(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              Icon(
                                                                _showArchivedParents
                                                                    ? Icons
                                                                          .archive_outlined
                                                                    : Icons
                                                                          .family_restroom,
                                                                size: 56,
                                                                color: theme
                                                                    .colorScheme
                                                                    .onSurface
                                                                    .withValues(
                                                                      alpha:
                                                                          0.5,
                                                                    ),
                                                              ),
                                                              const SizedBox(
                                                                height: 16,
                                                              ),
                                                              Text(
                                                                _showArchivedParents
                                                                    ? 'No archived parents found.'
                                                                    : 'No parent accounts found for the current filters.',
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                                style: TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                  color: theme
                                                                      .colorScheme
                                                                      .onSurface
                                                                      .withValues(
                                                                        alpha:
                                                                            0.8,
                                                                      ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        )
                                                      : ListView.builder(
                                                          itemCount:
                                                              paginatedList
                                                                  .length,
                                                          itemBuilder: (ctx, i) {
                                                            final p =
                                                                paginatedList[i];
                                                            final isSelected =
                                                                _selectedParentIds
                                                                    .contains(
                                                                      p.id,
                                                                    );

                                                            final lastName =
                                                                p.lastName ??
                                                                (p.fullName
                                                                        .contains(
                                                                          ' ',
                                                                        )
                                                                    ? p.fullName
                                                                          .split(
                                                                            ' ',
                                                                          )
                                                                          .last
                                                                    : p.fullName);
                                                            final firstName =
                                                                p.firstName ??
                                                                (p.fullName
                                                                        .contains(
                                                                          ' ',
                                                                        )
                                                                    ? p.fullName
                                                                          .split(
                                                                            ' ',
                                                                          )
                                                                          .first
                                                                    : '');
                                                            final middleInitial =
                                                                (p.middleName !=
                                                                        null &&
                                                                    p.middleName!
                                                                        .trim()
                                                                        .isNotEmpty)
                                                                ? '${p.middleName!.trim()[0].toUpperCase()}.'
                                                                : '';
                                                            final restOfName =
                                                                [
                                                                      firstName,
                                                                      middleInitial,
                                                                    ]
                                                                    .where(
                                                                      (e) => e
                                                                          .isNotEmpty,
                                                                    )
                                                                    .join(' ');

                                                            final linkedStudent =
                                                                _enrolledStudents
                                                                    .where(
                                                                      (user) =>
                                                                          user.id ==
                                                                          p.linkedStudentId,
                                                                    )
                                                                    .firstOrNull;
                                                            final studentName =
                                                                (p.parentGuardianName !=
                                                                        null &&
                                                                    p.parentGuardianName!
                                                                        .trim()
                                                                        .isNotEmpty)
                                                                ? p.parentGuardianName!
                                                                : (linkedStudent
                                                                          ?.fullName ??
                                                                      'Unlinked Student');

                                                            final birthdateText =
                                                                p.birthday !=
                                                                    null
                                                                ? '${p.birthday!.year}-${p.birthday!.month.toString().padLeft(2, '0')}-${p.birthday!.day.toString().padLeft(2, '0')} (${_calculateAge(p.birthday!)})'
                                                                : '\u2014';

                                                            return Container(
                                                              height: 52,
                                                              decoration: BoxDecoration(
                                                                color:
                                                                    isSelected
                                                                    ? theme
                                                                          .colorScheme
                                                                          .primary
                                                                          .withValues(
                                                                            alpha:
                                                                                0.12,
                                                                          )
                                                                    : (i % 2 ==
                                                                              1
                                                                          ? theme.colorScheme.primary.withValues(
                                                                              alpha: 0.03,
                                                                            )
                                                                          : theme.colorScheme.surface),
                                                                border: Border(
                                                                  bottom: BorderSide(
                                                                    color:
                                                                        tableBorderColor,
                                                                  ),
                                                                ),
                                                              ),
                                                              child: Row(
                                                                children: [
                                                                  _buildDataCell(
                                                                    width:
                                                                        colNumWidth,
                                                                    child: Center(
                                                                      child: Text(
                                                                        '${startIndex + i + 1}',
                                                                        style: const TextStyle(
                                                                          fontSize:
                                                                              13,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  _buildDataCell(
                                                                    width:
                                                                        colNameWidth,
                                                                    child: Text.rich(
                                                                      TextSpan(
                                                                        children: [
                                                                          TextSpan(
                                                                            text:
                                                                                lastName,
                                                                            style: TextStyle(
                                                                              fontSize: 14,
                                                                              fontWeight: FontWeight.bold,
                                                                              color: theme.colorScheme.onSurface,
                                                                            ),
                                                                          ),
                                                                          if (restOfName
                                                                              .isNotEmpty)
                                                                            TextSpan(
                                                                              text: ', $restOfName',
                                                                              style: TextStyle(
                                                                                fontSize: 13,
                                                                                fontWeight: FontWeight.w500,
                                                                                color: theme.colorScheme.onSurface,
                                                                              ),
                                                                            ),
                                                                        ],
                                                                      ),
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                      maxLines:
                                                                          1,
                                                                    ),
                                                                  ),
                                                                  _buildDataCell(
                                                                    width:
                                                                        colRelWidth,
                                                                    child: Text(
                                                                      p.parentGuardianRelationship ?? 'Parent/Guardian',
                                                                      style: const TextStyle(
                                                                        fontSize:
                                                                            13,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  _buildDataCell(
                                                                    width:
                                                                        colStudentWidth,
                                                                    child: Text(
                                                                      studentName,
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            13,
                                                                        color: theme
                                                                            .colorScheme
                                                                            .primary,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                      ),
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                    ),
                                                                  ),
                                                                  _buildDataCell(
                                                                    width:
                                                                        colBirthdateWidth,
                                                                    child: Text(
                                                                      birthdateText,
                                                                      style: const TextStyle(
                                                                        fontSize:
                                                                            13,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  _buildDataCell(
                                                                    width:
                                                                        colStatusWidth,
                                                                    child: StatusBadge.fromAccountStatus(
                                                                      p.status,
                                                                    ),
                                                                  ),
                                                                  _buildDataCell(
                                                                    width:
                                                                        colActionsWidth,
                                                                    hasRightBorder:
                                                                        false,
                                                                    child: Row(
                                                                      mainAxisAlignment:
                                                                          MainAxisAlignment
                                                                              .spaceEvenly,
                                                                      children: [
                                                                        IconButton(
                                                                          tooltip: 'Access Credentials Slip',
                                                                          icon: const Icon(
                                                                            Icons.badge_outlined,
                                                                            size:
                                                                                18,
                                                                            color: Color(
                                                                              0xFF64748B,
                                                                            ),
                                                                          ),
                                                                          splashRadius:
                                                                              18,
                                                                          onPressed: () => _showCredentialSlip(
                                                                            p,
                                                                            studentName,
                                                                          ),
                                                                        ),
                                                                        IconButton(
                                                                          tooltip: 'Edit Parent Details',
                                                                          icon: const Icon(
                                                                            Icons.edit_outlined,
                                                                            size:
                                                                                18,
                                                                            color: Color(
                                                                              0xFF64748B,
                                                                            ),
                                                                          ),
                                                                          splashRadius:
                                                                              18,
                                                                          onPressed: () =>
                                                                              _showEditParentDialog(
                                                                                p,
                                                                              ),
                                                                        ),
                                                                        IconButton(
                                                                          tooltip:
                                                                              _showArchivedParents
                                                                              ? 'Restore Parent'
                                                                              : 'Archive Parent',
                                                                          icon: Icon(
                                                                            _showArchivedParents
                                                                                ? Icons.restore
                                                                                : Icons.archive_outlined,
                                                                            size:
                                                                                18,
                                                                            color:
                                                                                _showArchivedParents
                                                                                ? const Color(0xFF10B981)
                                                                                : const Color(0xFF94A3B8),
                                                                          ),
                                                                          splashRadius:
                                                                              18,
                                                                          onPressed: () =>
                                                                              _toggleArchiveParent(
                                                                                p,
                                                                              ),
                                                                        ),
                                                                        if (_showArchivedParents)
                                                                          IconButton(
                                                                            tooltip: 'Permanently Delete',
                                                                            icon: const Icon(
                                                                              Icons.delete_outline,
                                                                              size: 18,
                                                                              color: Colors.redAccent,
                                                                            ),
                                                                            splashRadius:
                                                                                18,
                                                                            onPressed: () => _permanentlyDeleteParent(
                                                                              p,
                                                                            ),
                                                                          ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  // ── FULL WIDTH PAGINATION FOOTER ──
                                  Container(
                                    height: 52,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.brightness == Brightness.dark
                                          ? theme.colorScheme.surface
                                          : const Color(0xFFF8FAFC),
                                      border: Border(
                                        top: BorderSide(
                                          color:
                                              theme.brightness ==
                                                  Brightness.dark
                                              ? theme.colorScheme.onSurface
                                                    .withValues(alpha: 0.12)
                                              : const Color(0xFFE2E8F0),
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
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.7),
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
      child: Text(
        '$title$icon',
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontWeight: isCurrent ? FontWeight.w800 : FontWeight.bold,
          fontSize: 12.5,
        ),
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
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
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
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive
                ? Colors.white
                : (enabled
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddParentDialog() async {
    final effectiveSubject = _teacherSubjects.contains(_selectedSubjectFilter)
        ? _selectedSubjectFilter
        : (_teacherSubjects.isNotEmpty ? _teacherSubjects.first : null);

    final isAllSubjects =
        effectiveSubject == null || effectiveSubject == '— All Subjects —';
    final isAllSections = _selectedSectionFilter == '— All Sections —';

    final filteredStudents = _enrolledStudents.where((s) {
      final matchesSubject =
          isAllSubjects ||
          (s.enrolledSubjectName != null &&
              s.enrolledSubjectName!.trim().toLowerCase() ==
                  effectiveSubject.trim().toLowerCase());

      final matchesSection =
          isAllSections ||
          (s.departmentOrSection != null &&
              s.departmentOrSection!.trim().toLowerCase() ==
                  _selectedSectionFilter.trim().toLowerCase());

      return matchesSubject && matchesSection;
    }).toList();

    await AddParentDialog.show(
      context,
      students: filteredStudents,
      filterSection: !isAllSections ? _selectedSectionFilter : null,
      filterSubject: !isAllSubjects ? effectiveSubject : null,
      onParentCreated: _loadData,
    );
  }

  void _showCredentialSlip(UserModel parent, String studentName) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _ParentAccessSlipDialog(
        initialParent: parent,
        initialStudentNamesFallback: studentName,
        onParentResetOrUpdated: _loadData,
      ),
    );
  }

  Future<void> _showEditParentDialog(UserModel parent) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _EditParentAccountDialog(
        parent: parent,
        enrolledStudents: _enrolledStudents,
        onSaved: _loadData,
      ),
    );
  }

  Future<void> _toggleArchiveParent(UserModel parent) async {
    final isArchiving = !_showArchivedParents;
    final confirm = isArchiving
        ? await AppModals.showArchiveCooldownDialog(
            context: context,
            title: 'Archive Parent Account',
            message:
                'Are you sure you want to archive the account for ${parent.fullName}? Their login will be disabled and they will be moved to Archives. Their profile and student links remain preserved.',
            confirmLabel: 'Archive',
            confirmColor: AppTheme.catOrange,
            cooldownSeconds: 5,
          )
        : await AppModals.showConfirmDialog(
            context: context,
            title: 'Restore Parent Account',
            message:
                'Are you sure you want to restore ${parent.fullName}? This will restore their active status and re-enable their account login.',
            confirmLabel: 'Restore',
            confirmColor: AppTheme.catGreen,
          );

    if (confirm == true) {
      try {
        final repo = SupabaseParentRepository();
        final currentHint = (parent.status == AccountStatus.pendingFirstLogin)
            ? 'pending_first_login'
            : 'active';
        await repo.setArchived(
          parent.id,
          isArchiving,
          currentStatusHint: currentHint,
        );
      } catch (_) {}

      _loadData();
      if (mounted) {
        AppModals.showSuccessDialog(
          context: context,
          title: isArchiving ? 'Parent Archived' : 'Parent Restored',
          message: isArchiving
              ? '${parent.fullName} has been moved to archives.'
              : '${parent.fullName} has been restored to active status.',
        );
      }
    }
  }

  Future<void> _permanentlyDeleteParent(UserModel parent) async {
    final confirm = await AppModals.showTypeToConfirmDeleteDialog(
      context: context,
      title: 'Permanently Delete Parent',
      message:
          'Are you sure you want to permanently delete ${parent.fullName}? This will erase their parent profile and account records from the school system. This action is irreversible and cannot be undone.',
    );

    if (confirm == true) {
      try {
        final repo = SupabaseParentRepository();
        await repo.permanentlyDelete(parent.id);
      } catch (_) {}

      _loadData();
      if (mounted) {
        AppModals.showSuccessDialog(
          context: context,
          title: 'Parent Deleted',
          message: '${parent.fullName} has been permanently deleted.',
        );
      }
    }
  }
}

class _ParentAccessSlipDialog extends StatefulWidget {
  final UserModel initialParent;
  final String initialStudentNamesFallback;
  final VoidCallback onParentResetOrUpdated;

  const _ParentAccessSlipDialog({
    required this.initialParent,
    required this.initialStudentNamesFallback,
    required this.onParentResetOrUpdated,
  });

  @override
  State<_ParentAccessSlipDialog> createState() =>
      _ParentAccessSlipDialogState();
}

class _ParentAccessSlipDialogState extends State<_ParentAccessSlipDialog> {
  late UserModel _parent;
  List<UserModel> _linkedStudents = [];
  bool _isLoadingStudents = true;
  bool _isResettingPassword = false;
  String? _statusFeedbackMessage;

  @override
  void initState() {
    super.initState();
    _parent = widget.initialParent;
    _loadLinkedStudents();
  }

  Future<void> _loadLinkedStudents() async {
    try {
      final repo = SupabaseParentRepository();
      final students = await repo.getLinkedStudentsForParent(_parent.id);
      if (mounted) {
        setState(() {
          _linkedStudents = students;
          _isLoadingStudents = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingStudents = false);
      }
    }
  }

  String get _rawFirstName =>
      _parent.firstName ??
      (_parent.fullName.contains(' ')
          ? _parent.fullName.split(' ').first
          : _parent.fullName);

  String get _rawLastName =>
      _parent.lastName ??
      (_parent.fullName.contains(' ')
          ? _parent.fullName.split(' ').last
          : _parent.fullName);

  String get _effectiveEmail {
    if (_parent.email.isNotEmpty && _parent.email.contains('@')) {
      return _parent.email;
    }
    return ParentCredentialHelper.generateEmail(
      _rawLastName,
      rawFirstName: _rawFirstName,
    );
  }

  String get _effectiveTempPassword {
    final formattedLastName = ParentCredentialHelper.sanitizeLastName(
      _rawLastName,
    );
    return _parent.birthday != null
        ? ParentCredentialHelper.generateTempPassword(
            _rawLastName,
            _parent.birthday!,
          )
        : '${formattedLastName}YYYYMMDD';
  }

  String get _formattedLinkedStudentsSummary {
    if (_linkedStudents.isNotEmpty) {
      return _linkedStudents
          .map((s) {
            final rel = s.parentGuardianRelationship ?? 'Guardian';
            final sec = s.departmentOrSection;
            if (sec != null && sec.isNotEmpty) {
              return '${s.fullName} ($rel • $sec)';
            }
            return '${s.fullName} ($rel)';
          })
          .join(', ');
    }
    return widget.initialStudentNamesFallback;
  }

  Future<void> _handleResetPassword() async {
    if (_isResettingPassword) return;
    setState(() {
      _isResettingPassword = true;
      _statusFeedbackMessage = null;
    });

    try {
      final repo = SupabaseParentRepository();
      final updatedParent = await repo.resetParentToDefaultPassword(_parent);
      if (!mounted) return;
      setState(() {
        _parent = updatedParent;
        _isResettingPassword = false;
        _statusFeedbackMessage =
            'Password reset to temporary password ($_effectiveTempPassword) & status set to First Login Pending.';
      });
      widget.onParentResetOrUpdated();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isResettingPassword = false;
      });
      AppModals.showErrorDialog(
        context: context,
        title: 'Password Reset Failed',
        message: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = _effectiveEmail;
    final tempPassword = _effectiveTempPassword;
    final linkedSummary = _formattedLinkedStudentsSummary;

    final credentialsText =
        '''
[CLASSREALM PARENT ACCESS SLIP]
Parent Name: ${_parent.fullName}
Linked Student(s): $linkedSummary
Email (Login): $email
Temporary Password: $tempPassword

Instructions:
1. Open ClassRealm.
2. Log in using your Parent Email and Temporary Password.
3. Verify your identity and set your new private password on first login.
''';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(28, 18, 28, 28),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Upper-right X close button
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close_rounded, size: 22),
                splashRadius: 20,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.badge_outlined,
                color: theme.colorScheme.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'PARENT ACCESS SLIP',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface,
                letterSpacing: 1,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Provide these credentials to the parent/guardian so they can log in to ClassRealm using their Parent Email and Temporary Password. They will be prompted to create their own new password upon first login.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            _buildSlipRow(
              theme,
              'Parent',
              Text(
                _parent.fullName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _buildSlipRow(
              theme,
              _linkedStudents.length > 1
                  ? 'Linked Students (${_linkedStudents.length})'
                  : 'Linked Student',
              _isLoadingStudents && _linkedStudents.isEmpty
                  ? Text(
                      widget.initialStudentNamesFallback,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : (_linkedStudents.isEmpty
                        ? Text(
                            widget.initialStudentNamesFallback,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (
                                int i = 0;
                                i < _linkedStudents.length;
                                i++
                              ) ...[
                                if (i > 0)
                                  Divider(
                                    height: 12,
                                    color: theme.colorScheme.outline.withValues(
                                      alpha: 0.15,
                                    ),
                                  ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person_outline_rounded,
                                      size: 15,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _linkedStudents[i].fullName,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        _linkedStudents[i]
                                                .parentGuardianRelationship ??
                                            'Guardian',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          )),
            ),
            _buildSlipRow(
              theme,
              'Email (Login)',
              Text(
                email,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _buildSlipRow(
              theme,
              'Temp Password',
              Text(
                tempPassword,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            if (_statusFeedbackMessage != null) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.catGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.catGreen.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: AppTheme.catGreen,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusFeedbackMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.catGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy_all_rounded, size: 18),
                    label: const Text('Copy Slip'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: credentialsText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Parent Access Slip copied to clipboard!',
                          ),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppPrimaryButton(
                    label: _isResettingPassword
                        ? 'Resetting...'
                        : 'Reset Password',
                    icon: Icons.lock_reset_rounded,
                    isLoading: _isResettingPassword,
                    onPressed: _isResettingPassword
                        ? null
                        : _handleResetPassword,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlipRow(ThemeData theme, String label, Widget content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 135,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.22),
                ),
              ),
              child: content,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkedStudentLinkItem {
  final UserModel student;
  String relationship;

  _LinkedStudentLinkItem({required this.student, required this.relationship});
}

class _EditParentAccountDialog extends StatefulWidget {
  final UserModel parent;
  final List<UserModel> enrolledStudents;
  final VoidCallback onSaved;

  const _EditParentAccountDialog({
    required this.parent,
    required this.enrolledStudents,
    required this.onSaved,
  });

  @override
  State<_EditParentAccountDialog> createState() =>
      _EditParentAccountDialogState();
}

class _EditParentAccountDialogState extends State<_EditParentAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _middleNameCtrl;
  late final TextEditingController _lastNameCtrl;
  DateTime? _birthday;

  final List<_LinkedStudentLinkItem> _linkedItems = [];
  bool _isLoadingLinks = true;
  bool _isSaving = false;
  String? _unlinkGuardError;

  // Inline "+ Link Another Student" panel state
  bool _showAddStudentPanel = false;
  String _newLinkRelationship = 'Guardian';
  final TextEditingController _customRelCtrl = TextEditingController();
  final TextEditingController _studentSearchCtrl = TextEditingController();
  String _studentSearchQuery = '';
  String? _newLinkError;

  @override
  void initState() {
    super.initState();
    final fallbackFirst = widget.parent.firstName?.trim().isNotEmpty == true
        ? widget.parent.firstName!.trim()
        : (widget.parent.fullName.contains(' ')
              ? widget.parent.fullName.split(' ').first
              : widget.parent.fullName);
    final fallbackLast = widget.parent.lastName?.trim().isNotEmpty == true
        ? widget.parent.lastName!.trim()
        : (widget.parent.fullName.contains(' ')
              ? widget.parent.fullName.split(' ').last
              : '');

    _firstNameCtrl = TextEditingController(text: fallbackFirst);
    _middleNameCtrl = TextEditingController(
      text: widget.parent.middleName ?? '',
    );
    _lastNameCtrl = TextEditingController(text: fallbackLast);
    _birthday = widget.parent.birthday ?? DateTime(1980, 1, 1);

    _firstNameCtrl.addListener(_onFieldEdited);
    _lastNameCtrl.addListener(_onFieldEdited);
    _loadCurrentLinkedStudents();
  }

  void _onFieldEdited() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _customRelCtrl.dispose();
    _studentSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLinkedStudents() async {
    try {
      final repo = SupabaseParentRepository();
      final linked = await repo.getLinkedStudentsForParent(widget.parent.id);
      if (!mounted) return;
      setState(() {
        _linkedItems.clear();
        for (final s in linked) {
          _linkedItems.add(
            _LinkedStudentLinkItem(
              student: s,
              relationship:
                  (s.parentGuardianRelationship != null &&
                      s.parentGuardianRelationship!.trim().isNotEmpty)
                  ? s.parentGuardianRelationship!.trim()
                  : 'Guardian',
            ),
          );
        }
        // Fallback if empty
        if (_linkedItems.isEmpty && widget.parent.linkedStudentId != null) {
          final fallbackStudent = widget.enrolledStudents
              .where((u) => u.id == widget.parent.linkedStudentId)
              .firstOrNull;
          if (fallbackStudent != null) {
            _linkedItems.add(
              _LinkedStudentLinkItem(
                student: fallbackStudent,
                relationship:
                    widget.parent.parentGuardianRelationship ?? 'Guardian',
              ),
            );
          }
        }
        _isLoadingLinks = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingLinks = false);
      }
    }
  }

  int? get _calculatedAge {
    if (_birthday == null) return null;
    final today = DateTime.now();
    int age = today.year - _birthday!.year;
    if (today.month < _birthday!.month ||
        (today.month == _birthday!.month && today.day < _birthday!.day)) {
      age--;
    }
    return age;
  }

  void _handleRemoveLinkedStudent(String studentId) {
    if (_linkedItems.length <= 1) {
      setState(() {
        _unlinkGuardError =
            'At least 1 student must remain linked to this parent account.';
      });
      return;
    }
    setState(() {
      _linkedItems.removeWhere((item) => item.student.id == studentId);
      _unlinkGuardError = null;
    });
  }

  void _handleLinkStudent(UserModel student) {
    final effectiveRel = _newLinkRelationship == 'Other'
        ? _customRelCtrl.text.trim()
        : _newLinkRelationship;

    if (effectiveRel.isEmpty) {
      setState(() {
        _newLinkError = 'Please specify the relationship to the student.';
      });
      return;
    }

    if (_linkedItems.any((item) => item.student.id == student.id)) {
      return;
    }

    setState(() {
      _linkedItems.add(
        _LinkedStudentLinkItem(student: student, relationship: effectiveRel),
      );
      _newLinkError = null;
      _unlinkGuardError = null;
    });
  }

  Future<void> _submitChanges() async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthday == null) return;

    if (_linkedItems.isEmpty) {
      setState(() {
        _unlinkGuardError =
            'At least 1 student must remain linked to this parent account.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _unlinkGuardError = null;
    });

    try {
      final repo = SupabaseParentRepository();
      await repo.updateParentAccountAndLinks(
        currentParent: widget.parent,
        firstName: _firstNameCtrl.text.trim(),
        middleName: AppValidators.normalizeMiddleInitial(
          _middleNameCtrl.text.trim(),
        ),
        lastName: _lastNameCtrl.text.trim(),
        birthday: _birthday!,
        studentLinks: _linkedItems
            .map(
              (item) => {
                'studentId': item.student.id,
                'relationship': item.relationship,
              },
            )
            .toList(),
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Parent account & linked students updated!'),
          backgroundColor: AppTheme.catGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppModals.showErrorDialog(
        context: context,
        title: 'Update Failed',
        message: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rawFirst = _firstNameCtrl.text.trim();
    final rawLast = _lastNameCtrl.text.trim();
    final previewEmail = ParentCredentialHelper.generateEmail(
      rawLast.isNotEmpty ? rawLast : 'lastname',
      rawFirstName: rawFirst.isNotEmpty ? rawFirst : 'firstname',
    );
    final previewTempPassword = _birthday != null
        ? ParentCredentialHelper.generateTempPassword(
            rawLast.isNotEmpty ? rawLast : 'lastname',
            _birthday!,
          )
        : '${ParentCredentialHelper.sanitizeLastName(rawLast.isNotEmpty ? rawLast : 'lastname')}[YYYYMMDD]';

    // Group linked students by Relationship Category
    final groupedByCategory = <String, List<_LinkedStudentLinkItem>>{};
    for (final item in _linkedItems) {
      final cat = item.relationship.trim().isNotEmpty
          ? item.relationship.trim()
          : 'Guardian';
      groupedByCategory.putIfAbsent(cat, () => []).add(item);
    }

    // Available students for "+ Link Another Student"
    final linkedIds = _linkedItems.map((e) => e.student.id).toSet();
    final unlinkedStudents = widget.enrolledStudents
        .where((s) => !linkedIds.contains(s.id))
        .where((s) {
          if (_studentSearchQuery.trim().isEmpty) return true;
          final q = _studentSearchQuery.toLowerCase().trim();
          return s.fullName.toLowerCase().contains(q) ||
              (s.lrn ?? '').toLowerCase().contains(q) ||
              (s.departmentOrSection ?? '').toLowerCase().contains(q);
        })
        .toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(28, 24, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
      actionsPadding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.manage_accounts_outlined,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit Parent / Guardian Account',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Update parent personal details and manage linked student relationships.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(),
                const SizedBox(height: 12),

                // ── SECTION 1: PARENT PERSONAL INFORMATION ──
                Text(
                  'PARENT PERSONAL INFORMATION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: AppTextField(
                        label: 'First Name *',
                        hint: 'e.g. Granny',
                        controller: _firstNameCtrl,
                        prefixIcon: Icons.person_outline,
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r"[a-zA-ZÀ-ÿ\s\-']"),
                          ),
                        ],
                        validator: (val) =>
                            AppValidators.validateName(val, 'First Name'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: AppTextField(
                        label: 'Middle Initial',
                        hint: 'Optional (e.g. M.)',
                        controller: _middleNameCtrl,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(2),
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z\.]'),
                          ),
                        ],
                        validator: AppValidators.validateMiddleInitial,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: AppTextField(
                        label: 'Last Name *',
                        hint: 'e.g. Cruz',
                        controller: _lastNameCtrl,
                        prefixIcon: Icons.badge_outlined,
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r"[a-zA-ZÀ-ÿ\s\-']"),
                          ),
                        ],
                        validator: (val) =>
                            AppValidators.validateName(val, 'Last Name'),
                      ),
                    ),
                  ],
                ),

                // Live Credential Preview Card
                Container(
                  margin: const EdgeInsets.only(top: 4, bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Login Email (firstname.lastname.cr@classrealm.com)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              previewEmail,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Default / Reset Temp Password',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              previewTempPassword,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Birthday & Age Row (No top-level Relationship dropdown)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: AppDatePickerField(
                        label: 'Birthday *',
                        initialDate: _birthday,
                        showAgeHeader: false,
                        firstDate: BirthdayValidator.getMinDate(),
                        lastDate: BirthdayValidator.getMaxDate('parent'),
                        onDateSelected: (picked) {
                          setState(() => _birthday = picked);
                        },
                        validator: (d) {
                          if (d == null) return 'Birthday is required.';
                          final now = DateTime.now();
                          int age = now.year - d.year;
                          if (now.month < d.month ||
                              (now.month == d.month && now.day < d.day)) {
                            age--;
                          }
                          if (age < 18) {
                            return 'Parent/Guardian must be at least 18 years old.';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Age',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 48,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: theme.colorScheme.outline.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Text(
                                _calculatedAge != null
                                    ? '${_calculatedAge!} yrs'
                                    : '—',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _calculatedAge != null
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface.withValues(
                                          alpha: 0.4,
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 12),

                // ── SECTION 2: LINKED STUDENT(S) GROUPED BY RELATIONSHIP CATEGORY ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'LINKED STUDENT(S) BY RELATIONSHIP',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_linkedItems.length} linked',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Min. 1 student required',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (_unlinkGuardError != null) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.catRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.catRed.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 16,
                          color: AppTheme.catRed,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _unlinkGuardError!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.catRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_isLoadingLinks)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  for (final entry in groupedByCategory.entries) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.22,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category Header
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.07,
                              ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(11),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.family_restroom_rounded,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  entry.key.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.7,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${entry.value.length}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Student Rows inside this Relationship Category
                          for (int i = 0; i < entry.value.length; i++) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                color: theme.colorScheme.outline.withValues(
                                  alpha: 0.15,
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 17,
                                    backgroundColor: theme.colorScheme.primary
                                        .withValues(alpha: 0.12),
                                    child: Text(
                                      entry.value[i].student.fullName.isNotEmpty
                                          ? entry.value[i].student.fullName[0]
                                                .toUpperCase()
                                          : 'S',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          entry.value[i].student.fullName,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          [
                                            if (entry.value[i].student.lrn !=
                                                    null &&
                                                entry
                                                    .value[i]
                                                    .student
                                                    .lrn!
                                                    .isNotEmpty)
                                              'LRN: ${entry.value[i].student.lrn}',
                                            if (entry
                                                        .value[i]
                                                        .student
                                                        .departmentOrSection !=
                                                    null &&
                                                entry
                                                    .value[i]
                                                    .student
                                                    .departmentOrSection!
                                                    .isNotEmpty)
                                              entry
                                                  .value[i]
                                                  .student
                                                  .departmentOrSection!,
                                          ].join(' • '),
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Tooltip(
                                    message: _linkedItems.length <= 1
                                        ? 'At least 1 student must remain linked'
                                        : 'Unlink student from this parent',
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.link_off_rounded,
                                        size: 18,
                                        color: _linkedItems.length <= 1
                                            ? theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.25)
                                            : AppTheme.catRed,
                                      ),
                                      splashRadius: 18,
                                      onPressed: () =>
                                          _handleRemoveLinkedStudent(
                                            entry.value[i].student.id,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],

                // ── "+ LINK ANOTHER STUDENT" BUTTON & INLINE PANEL ──
                if (!_showAddStudentPanel)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 18,
                      ),
                      label: const Text(
                        '+ Link Another Student',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.45,
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _showAddStudentPanel = true;
                          _newLinkError = null;
                        });
                      },
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.28,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.person_add_alt_1_rounded,
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'LINK ANOTHER STUDENT',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _showAddStudentPanel = false;
                                  _newLinkError = null;
                                });
                              },
                              icon: const Icon(Icons.close_rounded, size: 16),
                              label: const Text('Done Linking'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Step 1: Specify Relationship to Student
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '1. Specify Relationship to Student *',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    initialValue: _newLinkRelationship,
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(
                                        Icons.family_restroom,
                                        size: 18,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    items:
                                        const [
                                              'Mother',
                                              'Father',
                                              'Guardian',
                                              'Other',
                                            ]
                                            .map(
                                              (r) => DropdownMenuItem(
                                                value: r,
                                                child: Text(
                                                  r,
                                                  style: const TextStyle(
                                                    fontSize: 13.5,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _newLinkRelationship = val;
                                          _newLinkError = null;
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            if (_newLinkRelationship == 'Other') ...[
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: AppTextField(
                                  label: 'Specify Relationship *',
                                  hint: 'e.g. Grandmother, Aunt',
                                  controller: _customRelCtrl,
                                  textCapitalization: TextCapitalization.words,
                                ),
                              ),
                            ],
                          ],
                        ),

                        if (_newLinkError != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _newLinkError!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.catRed,
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),
                        Text(
                          '2. Select Student to Link *',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _studentSearchCtrl,
                          onChanged: (v) =>
                              setState(() => _studentSearchQuery = v),
                          decoration: InputDecoration(
                            hintText:
                                'Search student by name, LRN, or section...',
                            prefixIcon: const Icon(Icons.search, size: 18),
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 190),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          ),
                          child: unlinkedStudents.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Center(
                                    child: Text(
                                      'No unlinked enrolled students match your search.',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.55),
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: unlinkedStudents.length,
                                  separatorBuilder: (_, _) => Divider(
                                    height: 1,
                                    color: theme.colorScheme.outline.withValues(
                                      alpha: 0.12,
                                    ),
                                  ),
                                  itemBuilder: (ctx, idx) {
                                    final st = unlinkedStudents[idx];
                                    return ListTile(
                                      dense: true,
                                      leading: CircleAvatar(
                                        radius: 15,
                                        backgroundColor: theme
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.1),
                                        child: Text(
                                          st.fullName.isNotEmpty
                                              ? st.fullName[0].toUpperCase()
                                              : 'S',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        st.fullName,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      subtitle: Text(
                                        [
                                          if (st.lrn != null &&
                                              st.lrn!.isNotEmpty)
                                            'LRN: ${st.lrn}',
                                          if (st.departmentOrSection != null &&
                                              st
                                                  .departmentOrSection!
                                                  .isNotEmpty)
                                            st.departmentOrSection!,
                                        ].join(' • '),
                                        style: const TextStyle(fontSize: 11.5),
                                      ),
                                      trailing: OutlinedButton.icon(
                                        icon: const Icon(Icons.add, size: 15),
                                        label: const Text(
                                          'Link',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          minimumSize: Size.zero,
                                        ),
                                        onPressed: () => _handleLinkStudent(st),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
      actions: [
        AppSecondaryButton(
          label: 'Cancel',
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 8),
        AppPrimaryButton(
          label: 'Save Changes',
          icon: Icons.check_circle_outline,
          isLoading: _isSaving,
          onPressed: _isSaving ? null : _submitChanges,
        ),
      ],
    );
  }
}
