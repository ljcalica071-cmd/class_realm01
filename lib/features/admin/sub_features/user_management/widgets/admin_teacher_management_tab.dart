import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/widgets/common/app_buttons.dart';
import 'package:class_realm/widgets/common/app_modals.dart';
import 'package:class_realm/features/admin/sub_features/user_management/widgets/admin_add_teacher_dialog.dart';
import 'package:class_realm/features/admin/sub_features/user_management/widgets/admin_edit_teacher_dialog.dart';

class AdminTeacherManagementTab extends StatefulWidget {
  final List<UserModel> teachers;
  final VoidCallback onDataChanged;

  const AdminTeacherManagementTab({
    super.key,
    required this.teachers,
    required this.onDataChanged,
  });

  @override
  State<AdminTeacherManagementTab> createState() =>
      _AdminTeacherManagementTabState();
}

class _AdminTeacherManagementTabState extends State<AdminTeacherManagementTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showArchivedTeachers = false;

  String _sortColumn = 'lastName';
  bool _sortAscending = true;

  int _currentPage = 1;
  static const int _itemsPerPage = 10;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _calculateAge(DateTime birthday) {
    final now = DateTime.now();
    int age = now.year - birthday.year;
    if (now.month < birthday.month ||
        (now.month == birthday.month && now.day < birthday.day)) {
      age--;
    }
    return age;
  }

  void _onSort(String columnKey) {
    setState(() {
      if (_sortColumn == columnKey) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = columnKey;
        _sortAscending = true;
      }
    });
  }

  Future<void> _addTeacher() async {
    final created = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const AdminAddTeacherDialog();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            )),
            child: child,
          ),
        );
      },
    );

    if (created == true && mounted) {
      widget.onDataChanged();
    }
  }

  Future<void> _handleEdit(UserModel t) async {
    final updated = await AdminEditTeacherDialog.show(
      context,
      teacher: t,
      onTeacherUpdated: widget.onDataChanged,
    );
    if (updated == true && mounted) {
      widget.onDataChanged();
      AppModals.showSuccessDialog(
        context: context,
        title: 'Teacher Updated',
        message: 'Teacher profile details have been successfully updated.',
      );
    }
  }

  void _handleArchive(UserModel t) async {
    final confirm = await AppModals.showConfirmDialog(
      context: context,
      title: 'Archive Teacher',
      message: 'Are you sure you want to archive ${t.fullName}?',
      confirmLabel: 'Archive',
      confirmColor: AppTheme.catOrange,
    );
    if (confirm == true) {
      final success =
          await AuthRepository.instance.updateTeacherStatus(t.id, 'archived');
      if (success) {
        if (mounted) {
          AppModals.showSuccessDialog(
            context: context,
            title: 'Teacher Archived',
            message: '${t.fullName} has been moved to archives.',
            onConfirm: widget.onDataChanged,
          );
        }
        widget.onDataChanged();
      } else {
        if (mounted) {
          AppModals.showErrorDialog(
            context: context,
            title: 'Archive Failed',
            message: 'Failed to archive teacher. Please try again.',
          );
        }
      }
    }
  }

  void _handleRecover(UserModel t) async {
    final confirm = await AppModals.showConfirmDialog(
      context: context,
      title: 'Recover Teacher',
      message:
          'Are you sure you want to recover ${t.fullName} and set their status back to active?',
      confirmLabel: 'Recover',
      confirmColor: Colors.green,
    );
    if (confirm == true) {
      final success =
          await AuthRepository.instance.updateTeacherStatus(t.id, 'active');
      if (success) {
        if (mounted) {
          AppModals.showSuccessDialog(
            context: context,
            title: 'Teacher Recovered',
            message:
                '${t.fullName} has been successfully recovered and is now active.',
            onConfirm: widget.onDataChanged,
          );
        }
        widget.onDataChanged();
      } else {
        if (mounted) {
          AppModals.showErrorDialog(
            context: context,
            title: 'Recover Failed',
            message: 'Failed to recover teacher. Please try again.',
          );
        }
      }
    }
  }

  void _handlePermanentDelete(UserModel t) async {
    final confirm = await AppModals.showConfirmDialog(
      context: context,
      title: 'Permanent Delete',
      message:
          'Are you sure you want to permanently delete ${t.fullName}? This action cannot be undone and will remove them completely from the database.',
      confirmLabel: 'Delete',
      confirmColor: AppTheme.catRed,
    );
    if (confirm == true) {
      final success = await AuthRepository.instance.deleteTeacherRecord(t.id);
      if (success) {
        if (mounted) {
          AppModals.showSuccessDialog(
            context: context,
            title: 'Teacher Deleted',
            message: '${t.fullName} has been permanently deleted.',
            onConfirm: widget.onDataChanged,
          );
        }
        widget.onDataChanged();
      } else {
        if (mounted) {
          AppModals.showErrorDialog(
            context: context,
            title: 'Delete Failed',
            message: 'Failed to delete teacher. Please try again.',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final tableHeaderColor =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final tableHeaderTextColor =
        isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155);
    final alternateRowColor =
        isDark ? const Color(0xFF141E33) : const Color(0xFFFAFAFA);
    final tableBorderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    // Split archived and active teachers
    final archivedTeachers = widget.teachers.where((t) {
      return t.isArchived || t.status == AccountStatus.archived;
    }).toList();

    final activeTeachers = widget.teachers.where((t) {
      return !t.isArchived && t.status != AccountStatus.archived;
    }).toList();

    final sourceList =
        _showArchivedTeachers ? archivedTeachers : activeTeachers;

    // Filter by search
    final filtered = sourceList.where((t) {
      final q = _searchQuery.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          t.fullName.toLowerCase().contains(q) ||
          t.email.toLowerCase().contains(q);

      return matchesSearch;
    }).toList();

    // Sort list
    filtered.sort((a, b) {
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
          cmp = aLast.toLowerCase().compareTo(bLast.toLowerCase());
          break;
        case 'firstName':
          final aFirst = a.firstName ??
              (a.fullName.contains(' ') ? a.fullName.split(' ').first : '');
          final bFirst = b.firstName ??
              (b.fullName.contains(' ') ? b.fullName.split(' ').first : '');
          cmp = aFirst.toLowerCase().compareTo(bFirst.toLowerCase());
          break;
        case 'gender':
          cmp = (a.gender ?? '').compareTo(b.gender ?? '');
          break;
        case 'birthdate':
          final aDate = a.birthday ?? DateTime(1900);
          final bDate = b.birthday ?? DateTime(1900);
          cmp = aDate.compareTo(bDate);
          break;
        case 'status':
          cmp = a.status.name.compareTo(b.status.name);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });

    final totalItems = filtered.length;
    final totalPages = (totalItems / _itemsPerPage).ceil();

    if (_currentPage > totalPages && totalPages > 0) {
      _currentPage = totalPages;
    }

    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, totalItems);

    final paginatedItems = filtered.isEmpty
        ? <UserModel>[]
        : filtered.sublist(startIndex, endIndex);

    // Column widths for the table
    const colNumWidth = 56.0;
    const colLastNameWidth = 160.0;
    const colFirstNameWidth = 150.0;
    const colGenderWidth = 110.0;
    const colBirthdateWidth = 170.0;
    const colEmailWidth = 240.0;
    const colStatusWidth = 180.0;
    const colActionsWidth = 150.0;

    const totalTableWidth = colNumWidth +
        colLastNameWidth +
        colFirstNameWidth +
        colGenderWidth +
        colBirthdateWidth +
        colEmailWidth +
        colStatusWidth +
        colActionsWidth;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header title and subtitle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Teacher Accounts Directory',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'View and manage your teacher directory, update profiles, and handle account archives.',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Search, Filters & Action Buttons Bar (matching Student Directory)
          LayoutBuilder(
            builder: (context, constraints) {
              final searchAndFilter = Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Search field
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) {
                        setState(() {
                          _searchQuery = v;
                          _currentPage = 1;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search by name or email...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              );

              final actionButtons = Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.end,
                children: [
                  AppButton.primary(
                    icon: LucideIcons.userPlus,
                    label: 'Add Teacher',
                    onPressed: _addTeacher,
                  ),
                  SizedBox(
                    height: 42,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _showArchivedTeachers
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        side: BorderSide(
                          color: _showArchivedTeachers
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.2),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: Icon(
                        _showArchivedTeachers
                            ? Icons.people_outline
                            : Icons.archive_outlined,
                        size: 18,
                      ),
                      label: Text(
                        _showArchivedTeachers
                            ? 'View Active'
                            : 'View Archive (${archivedTeachers.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      onPressed: () => setState(() {
                        _showArchivedTeachers = !_showArchivedTeachers;
                        _currentPage = 1;
                      }),
                    ),
                  ),
                ],
              );

              if (constraints.maxWidth < 780) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchAndFilter,
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
                  Expanded(child: searchAndFilter),
                  const SizedBox(width: 12),
                  actionButtons,
                ],
              );
            },
          ),
          const SizedBox(height: 18),

          // Table Section (matching Student Directory)
          Expanded(
            child: Container(
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
                        // Table Header Row
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

                        // Table Body / Rows
                        Expanded(
                          child: filtered.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _showArchivedTeachers
                                            ? Icons.archive_outlined
                                            : Icons.school_outlined,
                                        size: 56,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.4),
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        _showArchivedTeachers
                                            ? 'No archived teacher accounts found.'
                                            : 'No teacher accounts found.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: paginatedItems.length,
                                  itemBuilder: (ctx, i) {
                                    final t = paginatedItems[i];
                                    final lastName = t.lastName ??
                                        (t.fullName.contains(' ')
                                            ? t.fullName.split(' ').last
                                            : t.fullName);
                                    final firstName = t.firstName ??
                                        (t.fullName.contains(' ')
                                            ? t.fullName.split(' ').first
                                            : '');
                                    final gender = t.gender ?? '—';
                                    final birthdayLabel = t.birthday == null
                                        ? '—'
                                        : '${t.birthday!.year}-${t.birthday!.month.toString().padLeft(2, '0')}-${t.birthday!.day.toString().padLeft(2, '0')} (${_calculateAge(t.birthday!)})';

                                    final isPendingFirstLogin =
                                        t.status == AccountStatus.pendingFirstLogin;

                                    return Container(
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: (i % 2 == 1
                                            ? alternateRowColor
                                            : theme.colorScheme.surface),
                                        border: Border(
                                          bottom: BorderSide(
                                            color: tableBorderColor,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          // 1. # (number)
                                          _buildDataCell(
                                            width: colNumWidth,
                                            child: Center(
                                              child: Text(
                                                '${startIndex + i + 1}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: theme
                                                      .colorScheme.onSurface,
                                                ),
                                              ),
                                            ),
                                          ),

                                          // 2. Last Name
                                          _buildDataCell(
                                            width: colLastNameWidth,
                                            child: Text(
                                              lastName,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: theme
                                                    .colorScheme.onSurface,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),

                                          // 3. First Name
                                          _buildDataCell(
                                            width: colFirstNameWidth,
                                            child: Text(
                                              firstName,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: theme
                                                    .colorScheme.onSurface,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),

                                          // 4. Gender
                                          _buildDataCell(
                                            width: colGenderWidth,
                                            child: Text(
                                              gender,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: theme
                                                    .colorScheme.onSurface,
                                              ),
                                            ),
                                          ),

                                          // 5. Birthday (Age)
                                          _buildDataCell(
                                            width: colBirthdateWidth,
                                            child: Text(
                                              birthdayLabel,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: theme
                                                    .colorScheme.onSurface,
                                              ),
                                            ),
                                          ),

                                          // 6. Email
                                          _buildDataCell(
                                            width: colEmailWidth,
                                            child: Text(
                                              t.email,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: theme
                                                    .colorScheme.onSurface,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),

                                          // 7. Status
                                          _buildDataCell(
                                            width: colStatusWidth,
                                            child: StatusBadge.fromAccountStatus(
                                              t.status,
                                            ),
                                          ),

                                          // 8. Actions (Edit & Archive / Recover & Permanent Delete)
                                          _buildDataCell(
                                            width: colActionsWidth,
                                            hasRightBorder: false,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (!_showArchivedTeachers) ...[
                                                  IconButton(
                                                    tooltip: isPendingFirstLogin
                                                        ? 'Cannot edit: Pending First Login'
                                                        : 'Edit Teacher Details',
                                                    icon: Icon(
                                                      Icons.edit_outlined,
                                                      color: isPendingFirstLogin
                                                          ? theme.colorScheme.onSurface.withValues(alpha: 0.25)
                                                          : const Color(0xFF64748B),
                                                      size: 18,
                                                    ),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                    visualDensity: VisualDensity.compact,
                                                    splashRadius: 18,
                                                    onPressed: isPendingFirstLogin
                                                        ? () {
                                                            AppModals.showErrorDialog(
                                                              context: context,
                                                              title: 'Cannot Edit Teacher',
                                                              message:
                                                                  'This teacher account has not completed their first login yet. Profiles can only be edited once the teacher has logged in and set up their account.',
                                                            );
                                                          }
                                                        : () => _handleEdit(t),
                                                  ),
                                                  IconButton(
                                                    tooltip: 'Archive Teacher',
                                                    icon: const Icon(
                                                      Icons.archive_outlined,
                                                      color:
                                                          AppTheme.catOrange,
                                                      size: 18,
                                                    ),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                    visualDensity: VisualDensity.compact,
                                                    splashRadius: 18,
                                                    onPressed: () =>
                                                        _handleArchive(t),
                                                  ),
                                                  IconButton(
                                                    tooltip:
                                                        'Delete Teacher',
                                                    icon: const Icon(
                                                      Icons.delete_outline,
                                                      color: AppTheme.catRed,
                                                      size: 18,
                                                    ),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                    visualDensity: VisualDensity.compact,
                                                    splashRadius: 18,
                                                    onPressed: () =>
                                                        _handlePermanentDelete(t),
                                                  ),
                                                ] else ...[
                                                  IconButton(
                                                    tooltip: 'Recover Teacher',
                                                    icon: const Icon(
                                                      Icons.restore,
                                                      color: Colors.green,
                                                      size: 18,
                                                    ),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                    visualDensity: VisualDensity.compact,
                                                    splashRadius: 18,
                                                    onPressed: () =>
                                                        _handleRecover(t),
                                                  ),
                                                  IconButton(
                                                    tooltip:
                                                        'Delete Teacher',
                                                    icon: const Icon(
                                                      Icons
                                                          .delete_forever_outlined,
                                                      color: AppTheme.catRed,
                                                      size: 18,
                                                    ),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                    visualDensity: VisualDensity.compact,
                                                    splashRadius: 18,
                                                    onPressed: () =>
                                                        _handlePermanentDelete(
                                                            t),
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

                        // Bottom Container: Entry count and pagination
                        Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF8FAFC),
                            border: Border(
                              top: BorderSide(color: tableBorderColor),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Showing ${filtered.isEmpty ? 0 : startIndex + 1} to $endIndex of ${filtered.length} entries',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                              if (totalPages > 1)
                                Row(
                                  children: [
                                    _buildPageButton(
                                      'First',
                                      () => setState(() => _currentPage = 1),
                                      _currentPage > 1,
                                    ),
                                    _buildPageButton(
                                      '<',
                                      () => setState(() => _currentPage--),
                                      _currentPage > 1,
                                    ),
                                    for (int p = 1; p <= totalPages; p++)
                                      if (p >= _currentPage - 2 &&
                                          p <= _currentPage + 2)
                                        _buildPageButton(
                                          p.toString(),
                                          () => setState(
                                              () => _currentPage = p),
                                          true,
                                          isActive: p == _currentPage,
                                        ),
                                    _buildPageButton(
                                      '>',
                                      () => setState(() => _currentPage++),
                                      _currentPage < totalPages,
                                    ),
                                    _buildPageButton(
                                      'Last',
                                      () => setState(
                                          () => _currentPage = totalPages),
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
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isActive ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive
                ? theme.colorScheme.onPrimary
                : enabled
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}
