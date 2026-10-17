import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/features/admin/sub_features/user_management/widgets/admin_add_teacher_dialog.dart';
import 'package:class_realm/routes/app_routes.dart';

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
  String _searchQuery = '';
  String _statusFilter = 'All';
  int _currentPage = 1;
  static const int _itemsPerPage = 10;
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

  void _handleArchive(UserModel t) async {
    final confirm = await AppModals.showConfirmDialog(
      context: context,
      title: 'Archive Teacher',
      message: 'Are you sure you want to archive ${t.fullName}?',
      confirmLabel: 'Archive',
      confirmColor: AppTheme.catOrange,
    );
    if (confirm == true) {
      final success = await AuthRepository.instance.updateTeacherStatus(t.id, 'archived');
      if (success) widget.onDataChanged();
    }
  }

  void _handleRecover(UserModel t) async {
    final confirm = await AppModals.showConfirmDialog(
      context: context,
      title: 'Recover Teacher',
      message: 'Are you sure you want to recover ${t.fullName} and set their status back to active?',
      confirmLabel: 'Recover',
      confirmColor: Colors.green,
    );
    if (confirm == true) {
      final success = await AuthRepository.instance.updateTeacherStatus(t.id, 'active');
      if (success) {
        widget.onDataChanged();
        if (mounted) {
          AppModals.showSuccessDialog(
            context: context,
            title: 'Teacher Recovered',
            message: '${t.fullName} has been successfully recovered and is now active.',
          );
        }
      }
    }
  }

  void _handlePermanentDelete(UserModel t) async {
    final confirm = await AppModals.showConfirmDialog(
      context: context,
      title: 'Permanent Delete',
      message: 'Are you sure you want to permanently delete ${t.fullName}? This action cannot be undone and will remove them from the database.',
      confirmLabel: 'Delete Forever',
      confirmColor: AppTheme.catRed,
    );
    if (confirm == true) {
      final success = await AuthRepository.instance.deleteTeacherRecord(t.id);
      if (success) widget.onDataChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = widget.teachers.where((t) {
      final matchesSearch = t.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.email.toLowerCase().contains(_searchQuery.toLowerCase());

      if (_statusFilter == 'All') return matchesSearch;
      if (_statusFilter == 'Active') return matchesSearch && t.status == AccountStatus.active;
      if (_statusFilter == 'Pending First Login') return matchesSearch && t.status == AccountStatus.pendingFirstLogin;
      if (_statusFilter == 'Archived') return matchesSearch && t.status == AccountStatus.archived;

      return matchesSearch;
    }).toList();

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

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Teacher Accounts Directory',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filters & Search
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) {
                    setState(() {
                      _searchQuery = v;
                      _currentPage = 1; // Reset to page 1 on search
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search teachers by name or email...',
                    prefixIcon: Icon(Icons.search, size: 20),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 44,
                child: FilledButton.icon(
                  onPressed: _addTeacher,
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text('Add Teacher'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _statusFilter,
                items: ['All', 'Active', 'Pending First Login', 'Archived']
                    .map((s) => DropdownMenuItem(value: s, child: Text('Status: $s')))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _statusFilter = v ?? 'All';
                    _currentPage = 1; // Reset to page 1 on filter
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.12)),
              ),
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.school_outlined,
                              size: 48,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No registered teachers found.',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Teacher accounts created by an administrator will appear here.',
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            itemCount: paginatedItems.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final t = paginatedItems[i];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: theme.colorScheme.primary,
                                  child: Text(
                                    t.fullName.substring(0, 1),
                                    style: TextStyle(color: theme.colorScheme.onPrimary),
                                  ),
                                ),
                                title: Text(t.fullName, style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                                subtitle: Text('${t.email} • Dept: ${t.departmentOrSection ?? "General"}', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    StatusBadge.fromAccountStatus(t.status),
                                    const SizedBox(width: 16),

                                    if (t.status == AccountStatus.archived) ...[
                                      Tooltip(
                                        message: 'Recover Account',
                                        child: IconButton(
                                          icon: const Icon(Icons.restore, color: Colors.green),
                                          onPressed: () => _handleRecover(t),
                                        ),
                                      ),
                                      Tooltip(
                                        message: 'Permanent Delete',
                                        child: IconButton(
                                          icon: const Icon(Icons.delete_forever, color: AppTheme.catRed),
                                          onPressed: () => _handlePermanentDelete(t),
                                        ),
                                      ),
                                    ] else ...[
                                      Tooltip(
                                        message: 'Archive Account',
                                        child: IconButton(
                                          icon: const Icon(Icons.archive_outlined, color: AppTheme.catOrange),
                                          onPressed: () => _handleArchive(t),
                                        ),
                                      ),
                                    ]
                                  ],
                                ),
                              );
                            },
                          ),
                        ),

                        // Pagination Controls
                        if (totalPages > 1)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chevron_left),
                                  onPressed: _currentPage > 1
                                      ? () => setState(() => _currentPage--)
                                      : null,
                                ),
                                Text('Page $_currentPage of $totalPages', 
                                  style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right),
                                  onPressed: _currentPage < totalPages
                                      ? () => setState(() => _currentPage++)
                                      : null,
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
    );
  }
}
