import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/widgets/common/app_buttons.dart';
import 'package:class_realm/widgets/common/app_modals.dart';
import 'package:class_realm/widgets/common/app_text_field.dart';
import 'package:class_realm/widgets/common/app_date_picker_field.dart';
import 'package:class_realm/core/utils/validators.dart';
import 'package:class_realm/core/services/email_service.dart';

class AddParentDialog extends StatefulWidget {
  final VoidCallback onParentCreated;

  const AddParentDialog({
    super.key,
    required this.onParentCreated,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onParentCreated,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddParentDialog(
        onParentCreated: onParentCreated,
      ),
    );
  }

  @override
  State<AddParentDialog> createState() => _AddParentDialogState();
}

class _AddParentDialogState extends State<AddParentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _customRelationshipCtrl = TextEditingController();

  String? _relationship;
  DateTime? _birthday;
  final List<UserModel> _selectedStudents = [];
  UserModel? _currentStudentSelection;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _contactCtrl.dispose();
    _customRelationshipCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStudents.isEmpty) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Student Required',
        message: 'Please link at least one student to this parent.',
      );
      return;
    }
    if (_birthday == null) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Birthday Required',
        message: 'Please select the parent\'s birthday.',
      );
      return;
    }

    // Process submission...
    final fullName = [
      _firstNameCtrl.text.trim(),
      if (_middleNameCtrl.text.trim().isNotEmpty) _middleNameCtrl.text.trim(),
      _lastNameCtrl.text.trim(),
    ].join(' ');

    final contactNumber = _contactCtrl.text.trim();
    final relationship = _relationship == 'Other' 
        ? _customRelationshipCtrl.text.trim() 
        : _relationship!;

    final formattedLastName = _lastNameCtrl.text.trim().toLowerCase().replaceAll(' ', '');
    final bdayStr = '${_birthday!.year}${_birthday!.month.toString().padLeft(2, '0')}${_birthday!.day.toString().padLeft(2, '0')}';
    
    final tempPassword = '$formattedLastName$bdayStr';
    final pseudoEmail = '$contactNumber@$formattedLastName.com';

    // Simulated Save to Mock Database
    final newParent = UserModel(
      id: 'parent_${DateTime.now().millisecondsSinceEpoch}',
      username: pseudoEmail,
      email: pseudoEmail,
      fullName: fullName,
      role: UserRole.parent,
      status: AccountStatus.pendingFirstLogin,
      linkedStudentId: _selectedStudents.first.id,
      contactNumber: contactNumber,
      departmentOrSection: relationship,
    );
    
    MockDatabase.instance.users.add(newParent);

    Navigator.of(context).pop();
    widget.onParentCreated();

    _showConfirmationDialog(
      context: context,
      fullName: fullName,
      contactNumber: contactNumber,
      tempPassword: tempPassword,
    );
  }

  static void _showConfirmationDialog({
    required BuildContext context,
    required String fullName,
    required String contactNumber,
    required String tempPassword,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(28),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.catGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.how_to_reg_outlined,
                  color: AppTheme.catGreen,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'PARENT ACCOUNT CREATED',
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
                'Please securely share these credentials with the parent. They will use their phone number to log in.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              _CredentialRow(label: 'Parent', value: fullName),
              _CredentialRow(label: 'Phone Number', value: contactNumber),
              _CredentialRow(label: 'Temp Password', value: tempPassword),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: AppPrimaryButton(
                      label: 'Close',
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
      contentPadding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
      actionsPadding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.group_add_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Parent / Guardian',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Create an account and link it to students',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface
                        .withValues(alpha: 0.6),
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                const _SectionLabel('Parent Name'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: AppTextField(
                        label: 'First Name *',
                        controller: _firstNameCtrl,
                        inputFormatters: [
                          ...AppValidators.nameFormatters,
                          LengthLimitingTextInputFormatter(30),
                        ],
                        validator: (v) =>
                            AppValidators.validateName(v, 'First name'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: AppTextField(
                        label: 'Middle Name',
                        controller: _middleNameCtrl,
                        inputFormatters: [
                          ...AppValidators.nameFormatters,
                          LengthLimitingTextInputFormatter(30),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: AppTextField(
                        label: 'Last Name *',
                        controller: _lastNameCtrl,
                        inputFormatters: [
                          ...AppValidators.nameFormatters,
                          LengthLimitingTextInputFormatter(30),
                        ],
                        validator: (v) =>
                            AppValidators.validateName(v, 'Last name'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _SectionLabel('Contact & Relationship'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppDatePickerField(
                        label: 'Birthday *',
                        initialDate: _birthday,
                        firstDate: DateTime(1970, 1, 1),
                        lastDate: DateTime(
                          DateTime.now().year - 18,
                          DateTime.now().month,
                          DateTime.now().day,
                        ),
                        onDateSelected: (d) => setState(() => _birthday = d),
                        validator: (d) {
                          if (d == null) return 'Birthday is required';
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
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'Phone Number (11-digits) *',
                        controller: _contactCtrl,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(11),
                        ],
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (v.length != 11 || !v.startsWith('09')) {
                            return 'Must be 11 digits starting with 09';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _buildRelationshipField(Theme.of(context))),
                  ],
                ),
                if (_relationship == 'Other') ...[
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Specify Relationship *',
                    controller: _customRelationshipCtrl,
                    inputFormatters: [
                      ...AppValidators.nameFormatters,
                      LengthLimitingTextInputFormatter(30),
                    ],
                    validator: (v) {
                      if (_relationship != 'Other') return null;
                      if (v == null || v.trim().length < 2) {
                        return 'Must be at least 2 characters';
                      }
                      if (v.trim().length > 30) {
                        return 'Cannot exceed 30 characters';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),
                const _SectionLabel('Link Students'),
                _buildLinkStudentSection(Theme.of(context)),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.7),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outline
                      .withValues(alpha: 0.3),
                ),
                minimumSize: const Size(160, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            AppPrimaryButton(
              label: 'Create Account',
              icon: Icons.person_add_alt_1,
              onPressed: _submit,
              width: 200,
              height: 44,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRelationshipField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Relationship *',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _relationship,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.4),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.4),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.error,
              ),
            ),
          ),
          items: const ['Mother', 'Father', 'Guardian', 'Other']
              .map((r) => DropdownMenuItem(value: r, child: Text(r)))
              .toList(),
          onChanged: (val) {
            setState(() {
              _relationship = val;
              if (val != 'Other') {
                _customRelationshipCtrl.clear();
              }
            });
          },
          validator: (v) => v == null ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _buildLinkStudentSection(ThemeData theme) {
    final availableStudents = MockDatabase.instance.users
        .where((u) => u.role == UserRole.student && !_selectedStudents.contains(u))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Student',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<UserModel>(
                    value: _currentStudentSelection,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outline.withValues(alpha: 0.4),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outline.withValues(alpha: 0.4),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    items: availableStudents
                        .map((u) => DropdownMenuItem(
                              value: u,
                              child: Text('${u.fullName} (${u.departmentOrSection})'),
                            ))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _currentStudentSelection = val;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                  foregroundColor: theme.colorScheme.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _currentStudentSelection == null
                    ? null
                    : () {
                        setState(() {
                          _selectedStudents.add(_currentStudentSelection!);
                          _currentStudentSelection = null;
                        });
                      },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ),
          ],
        ),
        if (_selectedStudents.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedStudents.map((student) {
              return Chip(
                label: Text(
                  student.fullName,
                  style: const TextStyle(fontSize: 12),
                ),
                onDeleted: () {
                  setState(() {
                    _selectedStudents.remove(student);
                  });
                },
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.05),
                deleteIconColor: theme.colorScheme.error,
                side: BorderSide(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }
}

class _CredentialRow extends StatelessWidget {
  final String label;
  final String value;
  const _CredentialRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline
                      .withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: label.contains('Password') ? 'monospace' : null,
                      ),
                    ),
                  ),
                  if (label.contains('Password'))
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: value));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password copied')),
                        );
                      },
                      child: Icon(
                        Icons.copy,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
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
