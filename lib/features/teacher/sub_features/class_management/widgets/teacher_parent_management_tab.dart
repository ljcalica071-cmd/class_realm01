import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/features/teacher/sub_features/class_management/widgets/add_parent_dialog.dart';

class TeacherParentManagementTab extends StatefulWidget {
  final List<UserModel> parents;

  const TeacherParentManagementTab({super.key, required this.parents});

  @override
  State<TeacherParentManagementTab> createState() =>
      _TeacherParentManagementTabState();
}

class _TeacherParentManagementTabState
    extends State<TeacherParentManagementTab> {
  String _parentSearchQuery = '';
  final Set<String> _selectedParentIds = {};
  String _parentSortColumn = 'lastName';
  bool _parentSortAscending = true;
  String _selectedClassFilter = '— Select a class —';

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
    var displayList = widget.parents.where((p) {
      final linkedStudent = MockDatabase.instance.users
          .where((user) => user.id == p.linkedStudentId)
          .firstOrNull;
      final matchesSearch =
          p.fullName.toLowerCase().contains(_parentSearchQuery.toLowerCase()) ||
          p.email.toLowerCase().contains(_parentSearchQuery.toLowerCase()) ||
          (p.contactNumber ?? '').contains(_parentSearchQuery) ||
          (linkedStudent?.fullName.toLowerCase().contains(
                _parentSearchQuery.toLowerCase(),
              ) ??
              false);
      final matchesClass =
          _selectedClassFilter == '— Select a class —' ||
          (linkedStudent?.departmentOrSection == _selectedClassFilter);
      return matchesSearch && matchesClass;
    }).toList();

    // Sort logic
    displayList.sort((a, b) {
      int cmp = 0;
      switch (_parentSortColumn) {
        case 'lastName':
          cmp = a.fullName
              .split(' ')
              .last
              .compareTo(b.fullName.split(' ').last);
          break;
        case 'firstName':
          cmp = a.fullName
              .split(' ')
              .first
              .compareTo(b.fullName.split(' ').first);
          break;
        case 'email':
          cmp = a.email.compareTo(b.email);
          break;
        case 'contact':
          cmp = (a.contactNumber ?? '').compareTo(b.contactNumber ?? '');
          break;
        default:
          cmp = 0;
      }
      return _parentSortAscending ? cmp : -cmp;
    });

    bool allSelected =
        displayList.isNotEmpty &&
        displayList.every((p) => _selectedParentIds.contains(p.id));

    const colCheckWidth = 48.0;
    const colNumWidth = 56.0;
    const colLastNameWidth = 150.0;
    const colFirstNameWidth = 140.0;
    const colRelWidth = 130.0;
    const colStudentWidth = 190.0;
    const colSectionWidth = 130.0;
    const colEmailWidth = 250.0;
    const colContactWidth = 160.0;
    const colStatusWidth = 140.0;
    const colActionsWidth = 120.0;

    const totalTableWidth =
        colCheckWidth +
        colNumWidth +
        colLastNameWidth +
        colFirstNameWidth +
        colRelWidth +
        colStudentWidth +
        colSectionWidth +
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
                    'Manage Parents / Guardians',
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
                    onPressed: () {},
                  ),
                  AppButton.primary(
                    icon: LucideIcons.userPlus,
                    label: 'Add Parent',
                    onPressed: _showAddParentDialog,
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
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                  ),
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
                  onChanged: (v) => setState(() => _parentSearchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search by parent name, student, or email...',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
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
              AppButton.outline(
                icon: LucideIcons.archive,
                label: 'View Archive',
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tableBorderColor),
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
                                    width: colCheckWidth,
                                    child: Center(
                                      child: Checkbox(
                                        value: allSelected,
                                        activeColor: theme.colorScheme.primary,
                                        checkColor: theme.colorScheme.onPrimary,
                                        side: BorderSide(
                                          color: tableHeaderTextColor,
                                          width: 1.5,
                                        ),
                                        onChanged: (val) {
                                          setState(() {
                                            if (val == true) {
                                              for (var p in displayList) {
                                                _selectedParentIds.add(p.id);
                                              }
                                            } else {
                                              for (var p in displayList) {
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
                                    child: _buildClickableParentHeaderTitle(
                                      'LAST NAME',
                                      'lastName',
                                    ),
                                  ),
                                  _buildHeaderCell(
                                    width: colFirstNameWidth,
                                    child: _buildClickableParentHeaderTitle(
                                      'FIRST NAME',
                                      'firstName',
                                    ),
                                  ),
                                  _buildHeaderCell(
                                    width: colRelWidth,
                                    child: Text(
                                      'RELATIONSHIP',
                                      style: TextStyle(
                                        color: tableHeaderTextColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
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
                                    width: colEmailWidth,
                                    child: _buildClickableParentHeaderTitle(
                                      'EMAIL',
                                      'email',
                                    ),
                                  ),
                                  _buildHeaderCell(
                                    width: colContactWidth,
                                    child: _buildClickableParentHeaderTitle(
                                      'CONTACT NO.',
                                      'contact',
                                    ),
                                  ),
                                  _buildHeaderCell(
                                    width: colStatusWidth,
                                    child: Text(
                                      'STATUS',
                                      style: TextStyle(
                                        color: tableHeaderTextColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
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
                                  ? const Center(
                                      child: Text('No parents found.'),
                                    )
                                  : ListView.builder(
                                      itemCount: displayList.length,
                                      itemBuilder: (ctx, i) {
                                        final p = displayList[i];
                                        final isSelected = _selectedParentIds
                                            .contains(p.id);
                                        final linkedStudent = MockDatabase
                                            .instance
                                            .users
                                            .where(
                                              (user) =>
                                                  user.id == p.linkedStudentId,
                                            )
                                            .firstOrNull;
                                        final nameParts = p.fullName
                                            .trim()
                                            .split(' ');
                                        final lastName = nameParts.isEmpty
                                            ? p.fullName
                                            : nameParts.last;
                                        final firstName = nameParts.length > 1
                                            ? nameParts
                                                  .sublist(
                                                    0,
                                                    nameParts.length - 1,
                                                  )
                                                  .join(' ')
                                            : '';

                                        return Container(
                                          height: 52,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? theme.colorScheme.primary
                                                      .withValues(alpha: 0.12)
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
                                                width: colCheckWidth,
                                                child: Center(
                                                  child: Checkbox(
                                                    value: isSelected,
                                                    onChanged: (val) => setState(
                                                      () => val == true
                                                          ? _selectedParentIds
                                                                .add(p.id)
                                                          : _selectedParentIds
                                                                .remove(p.id),
                                                    ),
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
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              _buildDataCell(
                                                width: colFirstNameWidth,
                                                child: Text(
                                                  firstName,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                              _buildDataCell(
                                                width: colRelWidth,
                                                child: Text(
                                                  p.parentGuardianRelationship ??
                                                      'Parent/Guardian',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                              _buildDataCell(
                                                width: colStudentWidth,
                                                child: Text(
                                                  linkedStudent?.fullName ??
                                                      'Unlinked student',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              _buildDataCell(
                                                width: colSectionWidth,
                                                child: Text(
                                                  linkedStudent
                                                          ?.departmentOrSection ??
                                                      'Unlinked',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                              _buildDataCell(
                                                width: colEmailWidth,
                                                child: Text(
                                                  p.email,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                              _buildDataCell(
                                                width: colContactWidth,
                                                child: Text(
                                                  p.contactNumber ?? 'N/A',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                              _buildDataCell(
                                                width: colStatusWidth,
                                                child:
                                                    StatusBadge.fromAccountStatus(
                                                      p.status,
                                                    ),
                                              ),
                                              _buildDataCell(
                                                width: colActionsWidth,
                                                hasRightBorder: false,
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    IconButton(
                                                      icon: Icon(
                                                        Icons.edit_outlined,
                                                        size: 18,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .primary,
                                                      ),
                                                      onPressed: () =>
                                                          _showEditParentDialog(
                                                            p,
                                                          ),
                                                    ),
                                                    IconButton(
                                                      icon: Icon(
                                                        Icons.delete_outline,
                                                        size: 18,
                                                        color: Colors.redAccent,
                                                      ),
                                                      onPressed: () async {
                                                        final confirm =
                                                            await AppModals.showConfirmDialog(
                                                              context: context,
                                                              title: 'Remove Parent Account',
                                                              message:
                                                                  'Are you sure you want to remove the account for ${p.fullName}?',
                                                              confirmLabel:
                                                                  'Remove',
                                                              confirmColor:
                                                                  AppTheme
                                                                      .catOrange,
                                                            );
                                                        if (confirm == true) {
                                                          setState(() {
                                                            MockDatabase
                                                                .instance
                                                                .users
                                                                .removeWhere(
                                                                  (u) =>
                                                                      u.id ==
                                                                      p.id,
                                                                );
                                                          });
                                                        }
                                                      },
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

  Widget _buildClickableParentHeaderTitle(String title, String columnKey) {
    final theme = Theme.of(context);
    final isCurrent = _parentSortColumn == columnKey;
    final icon = !isCurrent ? ' ↕' : (_parentSortAscending ? ' ▴' : ' ▾');
    return InkWell(
      onTap: () => setState(() {
        if (_parentSortColumn == columnKey) {
          _parentSortAscending = !_parentSortAscending;
        } else {
          _parentSortColumn = columnKey;
          _parentSortAscending = true;
        }
      }),
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

  Future<void> _showAddParentDialog() async {
    await AddParentDialog.show(
      context,
      onParentCreated: () {
        setState(() {});
      },
    );
  }

  Future<void> _showEditParentDialog(UserModel parent) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: parent.fullName);
    final emailController = TextEditingController(text: parent.email);
    final contactController = TextEditingController(text: parent.contactNumber);
    String? relationship = parent.parentGuardianRelationship;
    String? linkedStudentId = parent.linkedStudentId;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit Parent / Guardian'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Parent / Guardian Name',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  TextFormField(
                    controller: contactController,
                    decoration: const InputDecoration(
                      labelText: 'Contact Number',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: relationship,
                    decoration: const InputDecoration(
                      labelText: 'Relationship to Student',
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
                  DropdownButtonFormField<String>(
                    initialValue: linkedStudentId,
                    decoration: const InputDecoration(
                      labelText: 'Linked Student',
                    ),
                    items: MockDatabase.instance.users
                        .where((u) => u.role == UserRole.student)
                        .map(
                          (u) => DropdownMenuItem(
                            value: u.id,
                            child: Text(u.fullName),
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
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  setState(() {
                    MockDatabase.instance.updateParentAccount(
                      id: parent.id,
                      fullName: nameController.text,
                      email: emailController.text,
                      contactNumber: contactController.text,
                      relationship: relationship!,
                      linkedStudentId: linkedStudentId!,
                    );
                  });
                  Navigator.pop(context);
                }
              },
              child: Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
