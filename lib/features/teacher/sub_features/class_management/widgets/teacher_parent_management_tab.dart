import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/features/teacher/sub_features/class_management/widgets/add_parent_dialog.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/data/repositories/supabase_student_repository.dart';
import 'package:class_realm/data/repositories/supabase_parent_repository.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/core/utils/parent_credential_helper.dart';

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
  String _selectedSubjectFilter = '— All Subjects —';
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
    _loadData();
    _subscribeRealtime();
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
      LocalStorageService.saveString(
        'parent_management_subject',
        _selectedSubjectFilter,
      ),
      LocalStorageService.saveString(
        'parent_management_section',
        _selectedSectionFilter,
      ),
    ]);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final teacherId = AuthRepository.instance.currentUser?.id;
    if (teacherId == null) {
      _fallbackToMockData();
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
      final students = await studentRepo.getStudentsForTeacher(
        teacherId,
        includeArchived: false,
      );

      final parentRepo = SupabaseParentRepository();
      final active = await parentRepo.getParentsForTeacher(
        teacherId,
        includeArchived: false,
      );
      final archived = await parentRepo.getParentsForTeacher(
        teacherId,
        includeArchived: true,
      );

      if (mounted) {
        setState(() {
          _teacherSubjectsData = subjectsData;
          _teacherSubjects = subjectsSet.toList()..sort();
          _teacherSections = sectionsSet.toList()..sort();
          _enrolledStudents = students;

          if (active.isEmpty && archived.isEmpty && (widget.parents != null && widget.parents!.isNotEmpty)) {
            _fallbackToMockData();
          } else {
            _activeParents = active;
            _archivedParents = archived;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Parent load notice: $e');
      if (mounted) {
        _fallbackToMockData();
        setState(() => _isLoading = false);
      }
    }
  }

  void _fallbackToMockData() {
    final allMockParents = widget.parents ??
        MockDatabase.instance.users
            .where((u) => u.role == UserRole.parent)
            .toList();

    _activeParents = allMockParents.where((p) => !p.isArchived).toList();
    _archivedParents = allMockParents.where((p) => p.isArchived).toList();

    _enrolledStudents = MockDatabase.instance.users
        .where((u) => u.role == UserRole.student)
        .toList();

    final sections = MockDatabase.instance.sections;
    if (_teacherSections.isEmpty) {
      _teacherSections = sections;
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
    }

    var displayList =
        (_showArchivedParents ? _archivedParents : _activeParents).where((p) {
      final linkedStudent = _enrolledStudents
          .where((user) => user.id == p.linkedStudentId)
          .firstOrNull ??
          MockDatabase.instance.users
              .where((user) => user.id == p.linkedStudentId)
              .firstOrNull;

      final studentName = linkedStudent?.fullName ?? '';
      final studentSection = linkedStudent?.departmentOrSection ?? p.departmentOrSection ?? '';
      final studentSubject = linkedStudent?.enrolledSubjectName ?? p.enrolledSubjectName ?? '';

      final matchesSearch =
          p.fullName.toLowerCase().contains(_parentSearchQuery.toLowerCase()) ||
          p.username.toLowerCase().contains(_parentSearchQuery.toLowerCase()) ||
          (p.contactNumber ?? '').contains(_parentSearchQuery) ||
          studentName.toLowerCase().contains(_parentSearchQuery.toLowerCase());

      final matchesSubject =
          _selectedSubjectFilter == '— All Subjects —' ||
          (studentSubject == _selectedSubjectFilter);

      final matchesSection =
          _selectedSectionFilter == '— All Sections —' ||
          (studentSection == _selectedSectionFilter);

      return matchesSearch && matchesSubject && matchesSection;
    }).toList();

    // Sort logic
    displayList.sort((a, b) {
      int cmp = 0;
      switch (_sortColumn) {
        case 'lastName':
          final aLast = a.lastName ??
              (a.fullName.contains(' ')
                  ? a.fullName.split(' ').last
                  : a.fullName);
          final bLast = b.lastName ??
              (b.fullName.contains(' ')
                  ? b.fullName.split(' ').last
                  : b.fullName);
          cmp = aLast.compareTo(bLast);
          break;
        case 'firstName':
          final aFirst = a.firstName ??
              (a.fullName.contains(' ') ? a.fullName.split(' ').first : '');
          final bFirst = b.firstName ??
              (b.fullName.contains(' ') ? b.fullName.split(' ').first : '');
          cmp = aFirst.compareTo(bFirst);
          break;
        case 'relationship':
          cmp = (a.parentGuardianRelationship ?? '')
              .compareTo(b.parentGuardianRelationship ?? '');
          break;
        case 'username':
          cmp = a.username.compareTo(b.username);
          break;
        case 'contact':
          cmp = (a.contactNumber ?? '').compareTo(b.contactNumber ?? '');
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

    bool allSelected = paginatedList.isNotEmpty &&
        paginatedList.every((p) => _selectedParentIds.contains(p.id));

    const colCheckWidth = 48.0;
    const colNumWidth = 56.0;
    const colLastNameWidth = 140.0;
    const colFirstNameWidth = 140.0;
    const colRelWidth = 130.0;
    const colStudentWidth = 240.0;
    const colSectionWidth = 140.0;
    const colContactWidth = 160.0;
    const colStatusWidth = 140.0;
    const colActionsWidth = 180.0;

    const totalTableWidth = colCheckWidth +
        colNumWidth +
        colLastNameWidth +
        colFirstNameWidth +
        colRelWidth +
        colStudentWidth +
        colSectionWidth +
        colContactWidth +
        colStatusWidth +
        colActionsWidth;

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
                              value: _selectedSubjectFilter,
                              dropdownColor: theme.colorScheme.surface,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                              items: ['— All Subjects —', ..._teacherSubjects]
                                  .map(
                                    (sub) => DropdownMenuItem(
                                      value: sub,
                                      child: Text(
                                        sub,
                                        style: const TextStyle(fontSize: 13),
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
                                        style: const TextStyle(fontSize: 13),
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
                              hintText:
                                  'Search by parent name, student, or contact...',
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
                        AppButton.success(
                          icon: LucideIcons.upload,
                          label: 'Import Excel',
                          onPressed: () {
                            AppModals.showSuccessDialog(
                              context: context,
                              title: 'Import Parents via Excel',
                              message:
                                  'Excel batch import template for parent accounts will be available shortly.',
                            );
                          },
                        ),
                        AppButton.primary(
                          icon: LucideIcons.userPlus,
                          label: 'Add Parent',
                          onPressed: _showAddParentDialog,
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
                  child: Stack(
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
                                  // Table Header
                                  Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: tableHeaderColor,
                                    ),
                                    child: Row(
                                      children: [
                                        _buildHeaderCell(
                                          width: colCheckWidth,
                                          child: Center(
                                            child: Checkbox(
                                              value: allSelected,
                                              activeColor:
                                                  theme.colorScheme.primary,
                                              checkColor:
                                                  theme.colorScheme.onPrimary,
                                              side: BorderSide(
                                                color: tableHeaderTextColor,
                                                width: 1.5,
                                              ),
                                              onChanged: (val) {
                                                setState(() {
                                                  if (val == true) {
                                                    for (var p in paginatedList) {
                                                      _selectedParentIds.add(p.id);
                                                    }
                                                  } else {
                                                    for (var p in paginatedList) {
                                                      _selectedParentIds.remove(p.id);
                                                    }
                                                  }
                                                });
                                              },
                                            ),
                                          ),
                                        ),
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
                                          width: colRelWidth,
                                          child: _buildClickableHeaderTitle(
                                            'RELATIONSHIP',
                                            'relationship',
                                          ),
                                        ),
                                        _buildHeaderCell(
                                          width: colStudentWidth,
                                          child: Text(
                                            'LINKED STUDENT',
                                            style: TextStyle(
                                              color: tableHeaderTextColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        _buildHeaderCell(
                                          width: colSectionWidth,
                                          child: Text(
                                            'SECTION',
                                            style: TextStyle(
                                              color: tableHeaderTextColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        _buildHeaderCell(
                                          width: colContactWidth,
                                          child: _buildClickableHeaderTitle(
                                            'CONTACT NO.',
                                            'contact',
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

                                  // Table Body
                                  Expanded(
                                    child: displayList.isEmpty
                                        ? Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  _showArchivedParents
                                                      ? Icons.archive_outlined
                                                      : Icons.family_restroom,
                                                  size: 56,
                                                  color: theme
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.5),
                                                ),
                                                const SizedBox(height: 16),
                                                Text(
                                                  _showArchivedParents
                                                      ? 'No archived parents found.'
                                                      : 'No parent accounts found for the current filters.',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                    color: theme
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
                                              final p = paginatedList[i];
                                              final isSelected =
                                                  _selectedParentIds
                                                      .contains(p.id);

                                              final linkedStudent =
                                                  _enrolledStudents
                                                      .where((user) =>
                                                          user.id ==
                                                          p.linkedStudentId)
                                                      .firstOrNull ??
                                                  MockDatabase.instance.users
                                                      .where((user) =>
                                                          user.id ==
                                                          p.linkedStudentId)
                                                      .firstOrNull;

                                              final lastName = p.lastName ??
                                                  (p.fullName.contains(' ')
                                                      ? p.fullName
                                                          .split(' ')
                                                          .last
                                                      : p.fullName);
                                              final firstName = p.firstName ??
                                                  (p.fullName.contains(' ')
                                                      ? p.fullName
                                                          .split(' ')
                                                          .first
                                                      : '');

                                              final studentName =
                                                  linkedStudent?.fullName ??
                                                      'Unlinked Student';
                                              final section = linkedStudent
                                                      ?.departmentOrSection ??
                                                  p.departmentOrSection ??
                                                  '—';

                                              return Container(
                                                height: 52,
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? theme.colorScheme.primary
                                                          .withValues(
                                                              alpha: 0.12)
                                                      : (i % 2 == 1
                                                          ? alternateRowColor
                                                          : theme.colorScheme
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
                                                      width: colCheckWidth,
                                                      child: Center(
                                                        child: Checkbox(
                                                          value: isSelected,
                                                          onChanged: (val) =>
                                                              setState(() {
                                                            if (val == true) {
                                                              _selectedParentIds
                                                                  .add(p.id);
                                                            } else {
                                                              _selectedParentIds
                                                                  .remove(p.id);
                                                            }
                                                          }),
                                                        ),
                                                      ),
                                                    ),
                                                    _buildDataCell(
                                                      width: colNumWidth,
                                                      child: Center(
                                                        child: Text(
                                                          '${startIndex + i + 1}',
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    _buildDataCell(
                                                      width: colLastNameWidth,
                                                      child: Text(
                                                        lastName,
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    _buildDataCell(
                                                      width: colFirstNameWidth,
                                                      child: Text(
                                                        firstName,
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ),
                                                    _buildDataCell(
                                                      width: colRelWidth,
                                                      child: Text(
                                                        p.parentGuardianRelationship ??
                                                            'Parent/Guardian',
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ),
                                                    _buildDataCell(
                                                      width: colStudentWidth,
                                                      child: Text(
                                                        studentName,
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: theme
                                                              .colorScheme
                                                              .primary,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    _buildDataCell(
                                                      width: colSectionWidth,
                                                      child: Text(
                                                        section,
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ),
                                                    _buildDataCell(
                                                      width: colContactWidth,
                                                      child: Text(
                                                        p.contactNumber ?? 'N/A',
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ),
                                                    _buildDataCell(
                                                      width: colStatusWidth,
                                                      child: StatusBadge
                                                          .fromAccountStatus(
                                                        p.status,
                                                      ),
                                                    ),
                                                    _buildDataCell(
                                                      width: colActionsWidth,
                                                      hasRightBorder: false,
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          // View / Copy Credentials Slip
                                                          IconButton(
                                                            tooltip:
                                                                'Access Credentials Slip',
                                                            icon: const Icon(
                                                              Icons.badge_outlined,
                                                              size: 18,
                                                              color: Color(
                                                                  0xFF64748B),
                                                            ),
                                                            splashRadius: 18,
                                                            onPressed: () =>
                                                                _showCredentialSlip(
                                                              p,
                                                              studentName,
                                                            ),
                                                          ),

                                                          // Reset Parent Password (active only)
                                                          if (!_showArchivedParents)
                                                            IconButton(
                                                              tooltip:
                                                                  'Reset Parent Password',
                                                              icon: const Icon(
                                                                Icons
                                                                    .lock_reset_outlined,
                                                                size: 19,
                                                                color: Color(
                                                                    0xFF64748B),
                                                              ),
                                                              splashRadius: 18,
                                                              onPressed: () =>
                                                                  _handleResetParentPassword(
                                                                p,
                                                                studentName,
                                                              ),
                                                            ),

                                                          // Edit Parent
                                                          if (!_showArchivedParents)
                                                            IconButton(
                                                              tooltip:
                                                                  'Edit Parent Details',
                                                              icon: const Icon(
                                                                Icons
                                                                    .edit_outlined,
                                                                size: 18,
                                                                color: Color(
                                                                    0xFF64748B),
                                                              ),
                                                              splashRadius: 18,
                                                              onPressed: () =>
                                                                  _showEditParentDialog(
                                                                      p),
                                                            ),

                                                          // Archive / Restore
                                                          IconButton(
                                                            tooltip: _showArchivedParents
                                                                ? 'Restore Parent'
                                                                : 'Archive Parent',
                                                            icon: Icon(
                                                              _showArchivedParents
                                                                  ? Icons
                                                                      .unarchive_outlined
                                                                  : Icons
                                                                      .archive_outlined,
                                                              size: 18,
                                                              color: const Color(
                                                                  0xFF94A3B8),
                                                            ),
                                                            splashRadius: 18,
                                                            onPressed: () =>
                                                                _toggleArchiveParent(
                                                                    p),
                                                          ),

                                                          // Delete (in archive mode)
                                                          if (_showArchivedParents)
                                                            IconButton(
                                                              tooltip:
                                                                  'Permanently Delete',
                                                              icon: const Icon(
                                                                Icons
                                                                    .delete_outline,
                                                                size: 18,
                                                                color: Colors
                                                                    .redAccent,
                                                              ),
                                                              splashRadius: 18,
                                                              onPressed: () =>
                                                                  _permanentlyDeleteParent(
                                                                      p),
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

                                  // Pagination Footer
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
                                          color: theme.brightness ==
                                                  Brightness.dark
                                              ? theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.1)
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
                                                .withValues(alpha: 0.6),
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
                                              for (int p = 1;
                                                  p <= totalPages;
                                                  p++)
                                                if (p >= _currentPage - 2 &&
                                                    p <= _currentPage + 2)
                                                  _buildPageButton(
                                                    p.toString(),
                                                    () => setState(
                                                      () => _currentPage = p,
                                                    ),
                                                    true,
                                                    isActive:
                                                        p == _currentPage,
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
                                                  () => _currentPage =
                                                      totalPages,
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
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary
              : Colors.transparent,
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
    await AddParentDialog.show(
      context,
      students: _enrolledStudents,
      onParentCreated: _loadData,
    );
  }

  void _showCredentialSlip(UserModel parent, String studentName) {
    final rawLastName = parent.lastName ??
        (parent.fullName.contains(' ')
            ? parent.fullName.split(' ').last
            : parent.fullName);
    final formattedLastName =
        ParentCredentialHelper.sanitizeLastName(rawLastName);
    final email = parent.email.isNotEmpty && parent.email.contains('@')
        ? parent.email
        : ParentCredentialHelper.generateEmail(formattedLastName);
    final tempPassword = parent.birthday != null
        ? ParentCredentialHelper.generateTempPassword(
            rawLastName,
            parent.birthday!,
          )
        : '${formattedLastName}YYYYMMDD';
    final phone = parent.contactNumber ?? 'N/A';

    final credentialsText = '''
[CLASSREALM PARENT ACCESS SLIP]
Parent Name: ${parent.fullName}
Linked Student: $studentName
Email (Login): $email
Temporary Password: $tempPassword
Phone Number: $phone

Instructions:
1. Open ClassRealm.
2. Sign in using your Parent Email and Temporary Password.
3. Set your new private password on first login.
''';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(28),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.badge_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'PARENT ACCESS SLIP',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Provide these credentials to the parent/guardian so they can sign in to ClassRealm using their Parent Email and Temporary Password. They will be prompted to create their own new password upon first login.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              _buildCredentialCardRow('Parent', parent.fullName),
              _buildCredentialCardRow('Linked Student', studentName),
              _buildCredentialCardRow('Email (Login)', email),
              _buildCredentialCardRow('Temp Password', tempPassword, isSecret: true),
              _buildCredentialCardRow('Phone Number', phone),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy_all, size: 18),
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
                            content: Text('Parent Access Slip copied to clipboard!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppPrimaryButton(
                      label: 'Done',
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleResetParentPassword(UserModel parent, String studentName) async {
    final rawLastName = parent.lastName ??
        (parent.fullName.contains(' ')
            ? parent.fullName.split(' ').last
            : parent.fullName);
    final tempPasswordSample = parent.birthday != null
        ? ParentCredentialHelper.generateTempPassword(rawLastName, parent.birthday!)
        : '[lastname][YYYYMMDD]';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.lock_reset_outlined, color: Theme.of(context).colorScheme.primary, size: 24),
            const SizedBox(width: 8),
            const Text('Reset Parent Password'),
          ],
        ),
        content: Text(
          'This will reset the account of ${parent.fullName} back to Pending First Login with their default temporary password ($tempPasswordSample).\n\nUse this if the parent forgot their password or requires their account credentials to be reissued.',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          AppPrimaryButton(
            label: 'Reset Password',
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final repo = SupabaseParentRepository();
      final updatedParent = await repo.resetParentToDefaultPassword(parent);
      await _loadData();
      if (mounted) {
        setState(() => _isLoading = false);
        _showCredentialSlip(updatedParent, studentName);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppModals.showErrorDialog(
          context: context,
          title: 'Reset Failed',
          message: 'Unable to reset parent password: $e',
        );
      }
    }
  }

  Widget _buildCredentialCardRow(String label, String value, {bool isSecret = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: isSecret ? 'monospace' : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditParentDialog(UserModel parent) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: parent.fullName);
    final contactController = TextEditingController(text: parent.contactNumber);
    String? relationship = parent.parentGuardianRelationship ?? 'Mother';
    String? linkedStudentId = parent.linkedStudentId;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Parent / Guardian Details'),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Parent / Guardian Full Name *',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: contactController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number (11 digits) *',
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Required';
                      if (value.trim().length != 11) return 'Must be 11 digits';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: relationship,
                    decoration: const InputDecoration(
                      labelText: 'Relationship to Student *',
                    ),
                    items: const ['Mother', 'Father', 'Guardian', 'Other']
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => relationship = value),
                    validator: (value) => value == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: linkedStudentId,
                    decoration: const InputDecoration(
                      labelText: 'Linked Student *',
                    ),
                    items: _enrolledStudents
                        .map(
                          (u) => DropdownMenuItem(
                            value: u.id,
                            child: Text(
                              '${u.fullName} (${u.departmentOrSection ?? 'Enrolled'})',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => linkedStudentId = value),
                    validator: (value) => value == null ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final nameParts = nameController.text.trim().split(' ');
                  final firstName = nameParts.first;
                  final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

                  try {
                    final repo = SupabaseParentRepository();
                    await repo.updateParent(
                      parentId: parent.id,
                      firstName: firstName,
                      lastName: lastName,
                      contactNumber: contactController.text.trim(),
                      relationship: relationship!,
                      studentId: linkedStudentId,
                    );
                  } catch (_) {}

                  MockDatabase.instance.updateParentAccount(
                    id: parent.id,
                    fullName: nameController.text.trim(),
                    email: parent.email,
                    contactNumber: contactController.text.trim(),
                    relationship: relationship!,
                    linkedStudentId: linkedStudentId!,
                  );

                  Navigator.pop(context);
                  _loadData();
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleArchiveParent(UserModel parent) async {
    final isArchiving = !_showArchivedParents;
    final confirm = await AppModals.showConfirmDialog(
      context: context,
      title: isArchiving ? 'Archive Parent Account' : 'Restore Parent Account',
      message: isArchiving
          ? 'Are you sure you want to archive the account for ${parent.fullName}? They will not appear in the active parent directory.'
          : 'Are you sure you want to restore ${parent.fullName} to the active directory?',
      confirmLabel: isArchiving ? 'Archive' : 'Restore',
      confirmColor: isArchiving ? AppTheme.catOrange : AppTheme.catGreen,
    );

    if (confirm == true) {
      try {
        final repo = SupabaseParentRepository();
        await repo.setArchived(parent.id, isArchiving);
      } catch (_) {}

      final idx = MockDatabase.instance.users.indexWhere((u) => u.id == parent.id);
      if (idx != -1) {
        MockDatabase.instance.users[idx] =
            MockDatabase.instance.users[idx].copyWith(isArchived: isArchiving);
      }

      _loadData();
    }
  }

  Future<void> _permanentlyDeleteParent(UserModel parent) async {
    final confirm = await AppModals.showConfirmDialog(
      context: context,
      title: 'Permanently Delete Parent',
      message:
          'This will permanently delete the parent account for ${parent.fullName}. This action cannot be undone.',
      confirmLabel: 'Permanent Delete',
      confirmColor: AppTheme.catRed,
    );

    if (confirm == true) {
      try {
        final repo = SupabaseParentRepository();
        await repo.permanentlyDelete(parent.id);
      } catch (_) {}

      MockDatabase.instance.users.removeWhere((u) => u.id == parent.id);
      _loadData();
    }
  }
}
