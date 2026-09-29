import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/features/teacher/sub_features/class_management/widgets/add_student_dialog.dart';
import 'package:class_realm/features/teacher/sub_features/class_management/widgets/edit_student_dialog.dart';

class TeacherStudentManagementTab extends StatefulWidget {
  final List<UserModel> activeStudents;
  final List<UserModel> archivedStudents;

  const TeacherStudentManagementTab({
    super.key,
    required this.activeStudents,
    required this.archivedStudents,
  });

  @override
  State<TeacherStudentManagementTab> createState() =>
      _TeacherStudentManagementTabState();
}

class _TeacherStudentManagementTabState
    extends State<TeacherStudentManagementTab> {
  bool _showArchivedStudents = false;
  String _studentSearchQuery = '';
  String _selectedClassFilter = '— Select a class —';
  String _sortColumn = 'lastName';
  bool _sortAscending = true;
  final Set<String> _selectedStudentIds = {};

  final _studentNameCtrl = TextEditingController();
  final _studentIdCtrl = TextEditingController();
  final _studentSectionCtrl = TextEditingController();

  @override
  void dispose() {
    _studentNameCtrl.dispose();
    _studentIdCtrl.dispose();
    _studentSectionCtrl.dispose();
    super.dispose();
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
    var displayList =
        (_showArchivedStudents ? widget.archivedStudents : widget.activeStudents)
            .where((s) {
              final matchesSearch =
                  s.fullName.toLowerCase().contains(
                    _studentSearchQuery.toLowerCase(),
                  ) ||
                  (s.lrn?.toLowerCase().contains(
                        _studentSearchQuery.toLowerCase(),
                      ) ??
                      false);
              final matchesClass =
                  _selectedClassFilter == '— Select a class —' ||
                  (s.departmentOrSection == _selectedClassFilter);
              return matchesSearch && matchesClass;
            })
            .toList();

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
          cmp = (a.id.hashCode % 2).compareTo(b.id.hashCode % 2);
          break;
        case 'birthdate':
          final aDate = a.birthday ?? DateTime(2006);
          final bDate = b.birthday ?? DateTime(2006);
          cmp = aDate.compareTo(bDate);
          break;
        case 'email':
          cmp = a.email.compareTo(b.email);
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

    bool allSelected =
        displayList.isNotEmpty &&
        displayList.every((s) => _selectedStudentIds.contains(s.id));

    const colCheckWidth = 48.0;
    const colNumWidth = 56.0;
    const colLastNameWidth = 150.0;
    const colFirstNameWidth = 140.0;
    const colLrnWidth = 150.0;
    const colGenderWidth = 110.0;
    const colBirthdateWidth = 160.0;
    const colEmailWidth = 240.0;
    const colContactWidth = 160.0;
    const colStatusWidth = 120.0;
    const colActionsWidth = 170.0;

    const totalTableWidth =
        colCheckWidth +
        colNumWidth +
        colLastNameWidth +
        colFirstNameWidth +
        colLrnWidth +
        colGenderWidth +
        colBirthdateWidth +
        colEmailWidth +
        colContactWidth +
        colStatusWidth +
        colActionsWidth;

    return Padding(
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
                    'Manage Students',
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
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  AppButton.success(
                    icon: LucideIcons.upload,
                    label: 'Import Excel',
                    onPressed: () => _showImportStudentsDialog(context),
                  ),
                  AppButton.primary(
                    icon: LucideIcons.userPlus,
                    label: 'Add Students',
                    onPressed: () => AddStudentDialog.show(
                      context,
                      onStudentCreated: () => setState(() {}),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.12)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedClassFilter,
                    dropdownColor: theme.colorScheme.surface,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    items:
                        [
                              '— Select a class —',
                              ...MockDatabase.instance.sections,
                            ]
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
                        setState(() => _selectedClassFilter = val);
                      }
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 300,
                child: TextField(
                  onChanged: (v) => setState(() => _studentSearchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search by name or LRN...',
                    hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    prefixIcon: Icon(
                      LucideIcons.search,
                      size: 20,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _showArchivedStudents
                      ? const Color(0xFF1A56DB)
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  side: BorderSide(
                    color: _showArchivedStudents
                        ? const Color(0xFF1A56DB)
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
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
                      : 'View Archive (${widget.archivedStudents.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                onPressed: () => setState(() {
                  _showArchivedStudents = !_showArchivedStudents;
                  _selectedStudentIds.clear();
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
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
                                color: Color(0xFF1A56DB),
                              ),
                              child: Row(
                                children: [
                                  _buildHeaderCell(
                                    width: colCheckWidth,
                                    child: Center(
                                      child: Checkbox(
                                        value: allSelected,
                                        activeColor: Colors.white,
                                        checkColor: const Color(0xFF1A56DB),
                                        side: const BorderSide(
                                          color: Colors.white,
                                          width: 1.5,
                                        ),
                                        onChanged: (val) {
                                          setState(() {
                                            if (val == true) {
                                              for (var s in displayList) {
                                                _selectedStudentIds.add(s.id);
                                              }
                                            } else {
                                              for (var s in displayList) {
                                                _selectedStudentIds.remove(
                                                  s.id,
                                                );
                                              }
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  _buildHeaderCell(
                                    width: colNumWidth,
                                    child: const Center(
                                      child: Text(
                                        '#',
                                        style: TextStyle(
                                          color: Colors.white,
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
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  _buildHeaderCell(
                                    width: colContactWidth,
                                    child: Text(
                                      'CONTACT NO.',
                                      style: TextStyle(
                                        color: Colors.white,
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
                                    child: const Center(
                                      child: Text(
                                        'ACTIONS',
                                        style: TextStyle(
                                          color: Colors.white,
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
                                            size: 48,
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            _showArchivedStudents
                                                ? 'No archived students found.'
                                                : 'No students found matching filters.',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: displayList.length,
                                      itemBuilder: (ctx, i) {
                                        final s = displayList[i];
                                        final isSelected = _selectedStudentIds
                                            .contains(s.id);
                                        final lastName =
                                            s.lastName ??
                                            (s.fullName.contains(' ')
                                                ? s.fullName.split(' ').last
                                                : s.fullName);
                                        final firstName =
                                            s.firstName ??
                                            (s.fullName.contains(' ')
                                                ? s.fullName.split(' ').first
                                                : '');
                                        final lrn =
                                            s.lrn ?? s.studentId ?? 'N/A';
                                        final gender = (s.id.hashCode % 2 == 0)
                                            ? 'Male'
                                            : 'Female';
                                        final bday = s.birthday != null
                                            ? '${s.birthday!.year}-${s.birthday!.month.toString().padLeft(2, '0')}-${s.birthday!.day.toString().padLeft(2, '0')}'
                                            : '2006-05-12';
                                        final age = s.birthday != null
                                            ? _calculateAge(s.birthday!)
                                            : 18;
                                        final contact =
                                            s.parentGuardianContact ??
                                            s.contactNumber ??
                                            '09123456663';

                                        return Container(
                                          height: 52,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? const Color(0xFFEFF6FF)
                                                : (i % 2 == 1
                                                      ? const Color(0xFFFBFDFF)
                                                      : Colors.white),
                                            border: const Border(
                                              bottom: BorderSide(
                                                color: Color(0xFFE2E8F0),
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
                                                    activeColor: const Color(
                                                      0xFF1A56DB,
                                                    ),
                                                    onChanged: (val) {
                                                      setState(() {
                                                        if (val == true) {
                                                          _selectedStudentIds
                                                              .add(s.id);
                                                        } else {
                                                          _selectedStudentIds
                                                              .remove(s.id);
                                                        }
                                                      });
                                                    },
                                                  ),
                                                ),
                                              ),
                                              _buildDataCell(
                                                width: colNumWidth,
                                                child: Center(
                                                  child: Text(
                                                    '${i + 1}',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color:
                                                          Theme.of(context).colorScheme.onSurface,
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
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF1E293B),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              _buildDataCell(
                                                width: colFirstNameWidth,
                                                child: Text(
                                                  firstName,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF1E293B),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              _buildDataCell(
                                                width: colLrnWidth,
                                                child: Text(
                                                  lrn.replaceAll(' ', ''),
                                                  maxLines: 1,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontFamily: 'monospace',
                                                    color: Color(0xFF475569),
                                                  ),
                                                ),
                                              ),
                                              _buildDataCell(
                                                width: colGenderWidth,
                                                child: Text(
                                                  gender,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF334155),
                                                  ),
                                                ),
                                              ),
                                              _buildDataCell(
                                                width: colBirthdateWidth,
                                                child: Text(
                                                  '$bday ($age)',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF334155),
                                                  ),
                                                ),
                                              ),
                                              _buildDataCell(
                                                width: colEmailWidth,
                                                child: Text(
                                                  s.email,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF334155),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              _buildDataCell(
                                                width: colContactWidth,
                                                child: Text(
                                                  contact,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF334155),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              _buildDataCell(
                                                width: colStatusWidth,
                                                child:
                                                    StatusBadge.fromAccountStatus(
                                                      s.status,
                                                    ),
                                              ),
                                              _buildDataCell(
                                                width: colActionsWidth,
                                                hasRightBorder: false,
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    if (!_showArchivedStudents) ...[
                                                      IconButton(
                                                        tooltip:
                                                            'Edit Student Details',
                                                        icon: Icon(
                                                          Icons.edit_outlined,
                                                          color: Color(
                                                            0xFF64748B,
                                                          ),
                                                          size: 18,
                                                        ),
                                                        splashRadius: 18,
                                                        onPressed: () =>
                                                            EditStudentDialog.show(
                                                              context,
                                                              student: s,
                                                              onStudentUpdated:
                                                                  () =>
                                                                      setState(
                                                                        () {},
                                                                      ),
                                                            ),
                                                      ),
                                                      IconButton(
                                                        tooltip:
                                                            'Transfer to another section',
                                                        icon: Icon(
                                                          Icons.swap_horiz,
                                                          color: Color(
                                                            0xFF1A56DB,
                                                          ),
                                                          size: 18,
                                                        ),
                                                        splashRadius: 18,
                                                        onPressed: () =>
                                                            _showTransferSectionDialog(
                                                              context,
                                                              s,
                                                            ),
                                                      ),
                                                      IconButton(
                                                        tooltip:
                                                            'Archive Student',
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
                                                          final confirm =
                                                              await AppModals.showConfirmDialog(
                                                                context:
                                                                    context,
                                                                title:
                                                                    'Archive Student',
                                                                message:
                                                                    'Are you sure you want to move ${s.fullName} to the archive?',
                                                                confirmLabel:
                                                                    'Archive',
                                                                confirmColor:
                                                                    AppTheme.catOrange,
                                                              );
                                                          if (confirm == true) {
                                                            setState(
                                                              () => MockDatabase
                                                                  .instance
                                                                  .archiveStudent(
                                                                    s.id,
                                                                  ),
                                                            );
                                                            messenger
                                                                .showSnackBar(
                                                                  SnackBar(
                                                                    content: Text(
                                                                      '${s.fullName} moved to archive.',
                                                                    ),
                                                                  ),
                                                                );
                                                          }
                                                        },
                                                      ),
                                                    ] else ...[
                                                      IconButton(
                                                        tooltip:
                                                            'Recover Student',
                                                        icon: Icon(
                                                          Icons.restore,
                                                          color:
                                                              AppTheme.catGreen,
                                                          size: 18,
                                                        ),
                                                        splashRadius: 18,
                                                        onPressed: () {
                                                          setState(
                                                            () => MockDatabase
                                                                .instance
                                                                .restoreStudent(
                                                                  s.id,
                                                                ),
                                                          );
                                                          AppModals.showSuccessDialog(
                                                            context: context,
                                                            title: 'Recovered',
                                                            message:
                                                                '${s.fullName} recovered.',
                                                          );
                                                        },
                                                      ),
                                                      IconButton(
                                                        tooltip:
                                                            'Permanently delete student',
                                                        icon: Icon(
                                                          Icons
                                                              .delete_forever_outlined,
                                                          color:
                                                              AppTheme.catRed,
                                                          size: 18,
                                                        ),
                                                        splashRadius: 18,
                                                        onPressed: () async {
                                                          final confirm =
                                                              await AppModals.showConfirmDialog(
                                                                context:
                                                                    context,
                                                                title:
                                                                    'Permanently Delete Student',
                                                                message:
                                                                    'This will permanently delete ${s.fullName}. This action cannot be undone.',
                                                                confirmLabel:
                                                                    'Permanent Delete',
                                                                confirmColor:
                                                                    AppTheme.catRed,
                                                              );
                                                          if (confirm == true) {
                                                            setState(
                                                              () => MockDatabase
                                                                  .instance
                                                                  .permanentlyDeleteStudent(
                                                                    s.id,
                                                                  ),
                                                            );
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
                              height: 42,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              alignment: Alignment.centerRight,
                              decoration: BoxDecoration(
                                color: Color(0xFFF8FAFC),
                                border: Border(
                                  top: BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                              ),
                              child: Text(
                                '${displayList.length} students enrolled',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
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
                          color: const Color(0xFF1E293B),
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
                                color: Colors.white,
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
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                icon: Icon(Icons.restore, size: 16),
                                label: Text(
                                  'Recover',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                onPressed: () {
                                  final selectedCount =
                                      _selectedStudentIds.length;
                                  setState(() {
                                    for (final id in _selectedStudentIds) {
                                      MockDatabase.instance.restoreStudent(id);
                                    }
                                    _selectedStudentIds.clear();
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '$selectedCount student(s) recovered.',
                                      ),
                                    ),
                                  );
                                },
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
                                    borderRadius: BorderRadius.circular(20),
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
                                        title: 'Permanent delete',
                                        message:
                                            'Permanently delete $selectedCount selected student(s)? This action cannot be undone.',
                                        confirmLabel: 'Permanent delete',
                                        confirmColor: AppTheme.catRed,
                                      );
                                  if (confirm == true) {
                                    setState(() {
                                      for (final id in _selectedStudentIds) {
                                        MockDatabase.instance
                                            .permanentlyDeleteStudent(id);
                                      }
                                      _selectedStudentIds.clear();
                                    });
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                ),
                                onPressed: () =>
                                    setState(() => _selectedStudentIds.clear()),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ] else ...[
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                ),
                                onPressed: () =>
                                    setState(() => _selectedStudentIds.clear()),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                ),
                                icon: Icon(Icons.swap_horiz, size: 16),
                                label: Text(
                                  'Transfer Section',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                onPressed: () =>
                                    _showBulkTransferSectionDialog(context),
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
                                    borderRadius: BorderRadius.circular(20),
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
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  final selectedCount =
                                      _selectedStudentIds.length;
                                  final confirm =
                                      await AppModals.showConfirmDialog(
                                        context: context,
                                        title: 'Archive selected students',
                                        message:
                                            'Are you sure you want to archive $selectedCount selected student(s)?',
                                        confirmLabel: 'Archive selected',
                                        confirmColor: AppTheme.catRed,
                                      );
                                  if (confirm == true) {
                                    setState(() {
                                      for (final id in _selectedStudentIds) {
                                        MockDatabase.instance.archiveStudent(
                                          id,
                                        );
                                      }
                                      _selectedStudentIds.clear();
                                    });
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '$selectedCount student(s) moved to archive.',
                                        ),
                                      ),
                                    );
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
    );
  }

  Widget _buildHeaderCell({
    required double width,
    required Widget child,
    bool hasRightBorder = true,
  }) {
    return Container(
      width: width,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: hasRightBorder
            ? const Border(
                right: BorderSide(color: Color(0xFF2563EB), width: 1),
              )
            : null,
      ),
      child: child,
    );
  }

  Widget _buildClickableHeaderTitle(String title, String columnKey) {
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
                color: Colors.white,
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
    return Container(
      width: width,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: hasRightBorder
            ? const Border(
                right: BorderSide(color: Color(0xFFF1F5F9), width: 1),
              )
            : null,
      ),
      child: child,
    );
  }

  void _showImportStudentsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Import Students'),
        content: SizedBox(
          width: 760,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  AppModals.showSuccessDialog(
                    context: context,
                    title: 'File Selected',
                    message:
                        'Prototype only: the selected CSV or Excel file will be processed here.',
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 28,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.upload_file_outlined,
                        size: 42,
                        color: Color(0xFF94A3B8),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Click to select a CSV or Excel file',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Accepted: .csv, .xlsx, .xls',
                        style: TextStyle(color: Color(0xFF475569)),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Required: LRN, Last Name, First Name, Gender, Birthday, Email, Student Contact, Parent Name, Parent Contact, Relationship',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF475569)),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Optional: Middle Name',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Please follow the format shown above so the system can accept the file. Download the template to ensure the columns and format are correct.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF475569), fontSize: 13),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F8A48),
                  foregroundColor: Colors.white,
                ),
                icon: Icon(Icons.description_outlined),
                label: Text('Download Template'),
                onPressed: () {
                  AppModals.showSuccessDialog(
                    context: context,
                    title: 'Template Ready',
                    message:
                        'Student import template downloaded. Fill in the required columns before importing.',
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTransferSectionDialog(BuildContext context, UserModel student) {
    String selectedTargetSection = MockDatabase.instance.sections.firstWhere(
      (sec) => sec != student.departmentOrSection,
      orElse: () => MockDatabase.instance.sections.first,
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.swap_horiz,
                  color: Color(0xFF1A56DB),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Transfer to Another Section',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transfer student ${student.fullName} from ${student.departmentOrSection ?? "current section"} to a new section.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Select Destination Section:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedTargetSection,
                      items: MockDatabase.instance.sections
                          .map(
                            (sec) => DropdownMenuItem(
                              value: sec,
                              child: Text(
                                sec,
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedTargetSection = val);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A56DB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                setState(() {
                  MockDatabase.instance.updateStudent(
                    student.id,
                    student.fullName,
                    student.lrn ?? student.studentId ?? '',
                    selectedTargetSection,
                  );
                });
                Navigator.pop(ctx);
                AppModals.showSuccessDialog(
                  context: context,
                  title: 'Section Transferred',
                  message:
                      '${student.fullName} has been transferred to $selectedTargetSection successfully.',
                );
              },
              child: Text(
                'Confirm Transfer',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBulkTransferSectionDialog(BuildContext context) {
    String selectedTargetSection = MockDatabase.instance.sections.first;
    final selectedCount = _selectedStudentIds.length;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Transfer Section'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transfer $selectedCount selected student(s) to another section.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 20),
                Text(
                  'Select Destination Section:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedTargetSection,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: MockDatabase.instance.sections
                      .map(
                        (section) => DropdownMenuItem(
                          value: section,
                          child: Text(section),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setModalState(() => selectedTargetSection = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  for (final id in _selectedStudentIds) {
                    final student = MockDatabase.instance.users.firstWhere(
                      (user) => user.id == id,
                    );
                    MockDatabase.instance.updateStudent(
                      id,
                      student.fullName,
                      student.lrn ?? student.studentId ?? '',
                      selectedTargetSection,
                    );
                  }
                  _selectedStudentIds.clear();
                });
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '$selectedCount student(s) transferred to $selectedTargetSection.',
                    ),
                  ),
                );
              },
              child: Text('Transfer Section'),
            ),
          ],
        ),
      ),
    );
  }
}
