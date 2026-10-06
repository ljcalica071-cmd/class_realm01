import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';

class AdminPendingApprovalsTab extends StatefulWidget {
  final List<UserModel> pendingTeachers;
  final ValueChanged<UserModel> onApprove;
  final ValueChanged<UserModel> onReject;

  const AdminPendingApprovalsTab({
    super.key,
    required this.pendingTeachers,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<AdminPendingApprovalsTab> createState() => _AdminPendingApprovalsTabState();
}

class _AdminPendingApprovalsTabState extends State<AdminPendingApprovalsTab> {
  int _currentPage = 1;
  static const int _itemsPerPage = 10;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalItems = widget.pendingTeachers.length;
    final totalPages = (totalItems / _itemsPerPage).ceil();
    
    // Ensure current page is valid when items are removed
    if (_currentPage > totalPages && totalPages > 0) {
      _currentPage = totalPages;
    }

    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, totalItems);
    
    final paginatedItems = widget.pendingTeachers.isEmpty 
        ? <UserModel>[] 
        : widget.pendingTeachers.sublist(startIndex, endIndex);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pending Teacher Approvals',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Review and approve new teacher sign-up requests.',
            style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: widget.pendingTeachers.isEmpty
                ? Center(
                    child: Text(
                      'No pending teacher requests.',
                      style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: ListView.separated(
                          itemCount: paginatedItems.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final t = paginatedItems[i];
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.12)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppTheme.catOrange.withValues(alpha: 0.1),
                                    child: const Icon(Icons.person, color: AppTheme.catOrange),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t.fullName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                        Text(
                                          '${t.email} • ${t.departmentOrSection ?? "Pending Academic Setup"}',
                                          style: TextStyle(
                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AppButton.success(
                                    label: 'Approve',
                                    onPressed: () => widget.onApprove(t),
                                  ),
                                  const SizedBox(width: 8),
                                  AppButton.danger(
                                    label: 'Reject',
                                    onPressed: () => widget.onReject(t),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      
                      // Pagination Controls
                      if (totalPages > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
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
        ],
      ),
    );
  }
}
