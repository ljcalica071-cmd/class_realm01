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
import 'package:class_realm/core/utils/parent_credential_helper.dart';

import 'package:class_realm/data/repositories/supabase_parent_repository.dart';

class AddParentDialog extends StatefulWidget {
  final VoidCallback onParentCreated;
  final List<UserModel>? students;

  const AddParentDialog({
    super.key,
    required this.onParentCreated,
    this.students,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onParentCreated,
    List<UserModel>? students,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddParentDialog(
        onParentCreated: onParentCreated,
        students: students,
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
  final _studentSearchCtrl = TextEditingController();

  String? _relationship;
  DateTime? _birthday;
  final List<UserModel> _selectedStudents = [];
  String _studentSearchQuery = '';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _lastNameCtrl.addListener(_onLastNameChanged);
  }

  void _onLastNameChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _lastNameCtrl.removeListener(_onLastNameChanged);
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _contactCtrl.dispose();
    _customRelationshipCtrl.dispose();
    _studentSearchCtrl.dispose();
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
    if (_selectedStudents.length > 15) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Limit Exceeded',
        message: 'Too much students to link in one parent account.',
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

    setState(() => _isSubmitting = true);

    final firstName = _firstNameCtrl.text.trim();
    final middleName = _middleNameCtrl.text.trim().isNotEmpty ? _middleNameCtrl.text.trim() : null;
    final lastName = _lastNameCtrl.text.trim();
    final fullName = [firstName, if (middleName != null) middleName, lastName].join(' ');

    final contactNumber = _contactCtrl.text.trim();
    final relationship = _relationship == 'Other' 
        ? _customRelationshipCtrl.text.trim() 
        : _relationship!;

    final tempPassword = ParentCredentialHelper.generateTempPassword(lastName, _birthday!);
    final parentEmail = ParentCredentialHelper.generateEmail(lastName);
    final primaryStudent = _selectedStudents.first;

    UserModel? createdUser;
    try {
      final repo = SupabaseParentRepository();
      createdUser = await repo.createParentAccount(
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        contactNumber: contactNumber,
        birthday: _birthday!,
        relationship: relationship,
        studentIds: _selectedStudents.map((s) => s.id).toList(),
        email: parentEmail,
        tempPassword: tempPassword,
      );
    } catch (e) {
      debugPrint('Notice saving to supabase parent: $e');
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppModals.showErrorDialog(
          context: context,
          title: 'Account Creation Failed',
          message: e.toString().replaceAll('Exception: ', ''),
        );
        return;
      }
    }

    final finalEmail = createdUser?.email ?? parentEmail;

    // Also sync to MockDatabase
    final newParent = createdUser ??
        UserModel(
          id: 'parent_${DateTime.now().millisecondsSinceEpoch}',
          username: finalEmail,
          email: finalEmail,
          fullName: fullName,
          firstName: firstName,
          middleName: middleName,
          lastName: lastName,
          role: UserRole.parent,
          status: AccountStatus.pendingFirstLogin,
          linkedStudentId: primaryStudent.id,
          contactNumber: contactNumber,
          birthday: _birthday,
          departmentOrSection: primaryStudent.departmentOrSection ?? relationship,
          parentGuardianRelationship: relationship,
        );

    MockDatabase.instance.users.add(newParent);

    if (mounted) {
      setState(() => _isSubmitting = false);
      Navigator.of(context).pop();
      widget.onParentCreated();

      _showConfirmationDialog(
        context: context,
        fullName: fullName,
        email: finalEmail,
        contactNumber: contactNumber,
        tempPassword: tempPassword,
        linkedStudentName: _selectedStudents.map((s) => s.fullName).join(', '),
      );
    }
  }

  static void _showConfirmationDialog({
    required BuildContext context,
    required String fullName,
    required String email,
    required String contactNumber,
    required String tempPassword,
    required String linkedStudentName,
  }) {
    final credentialsText = '''
[CLASSREALM PARENT ACCESS SLIP]
Parent Name: $fullName
Linked Student: $linkedStudentName
Email (Login): $email
Temporary Password: $tempPassword
Phone Number: $contactNumber

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
                'Provide this Parent Access Slip to the parent/guardian so they can sign in to ClassRealm using their Parent Email and Temporary Password. They will be prompted to create their own new password upon first login.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              _CredentialRow(label: 'Parent', value: fullName),
              _CredentialRow(label: 'Linked Student', value: linkedStudentName),
              _CredentialRow(label: 'Email (Login)', value: email),
              _CredentialRow(label: 'Temp Password', value: tempPassword),
              _CredentialRow(label: 'Phone Number', value: contactNumber),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_reset,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'On first login, the parent will set their private password before accessing their portal.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy_all, size: 18),
                      label: const Text('Copy Access Slip'),
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
                            content: Text('Access slip copied to clipboard!'),
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
                      flex: 4,
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
                      flex: 4,
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
                      flex: 3,
                      child: AppDatePickerField(
                        label: 'Birthday *',
                        initialDate: _birthday,
                        showAgeHeader: false,
                        firstDate: BirthdayValidator.getMinDate(),
                        lastDate: BirthdayValidator.getMaxDate('parent'),
                        onDateSelected: (d) => setState(() => _birthday = d),
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
                      flex: 2,
                      child: _buildAgeField(Theme.of(context)),
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
                          if (v == null || v.trim().isEmpty) return 'Phone number is required.';
                          if (v.trim().length != 11 || !v.trim().startsWith('09')) {
                            return 'Phone number must be 11 digits starting with 09.';
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
                      if (v == null || v.trim().isEmpty) {
                        return 'Specify relationship is required.';
                      }
                      if (v.trim().length < 2) {
                        return 'Specify relationship must be at least 2 characters.';
                      }
                      if (v.trim().length > 30) {
                        return 'Specify relationship cannot exceed 30 characters.';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 12),
                _buildCredentialPreviewCard(Theme.of(context)),
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

  Widget _buildCredentialPreviewCard(ThemeData theme) {
    final rawLastName = _lastNameCtrl.text.trim();
    final sanitizedLastName = rawLastName.isNotEmpty
        ? ParentCredentialHelper.sanitizeLastName(rawLastName)
        : 'lastname';
    final previewEmail = ParentCredentialHelper.generateEmail(
      rawLastName.isNotEmpty ? rawLastName : 'lastname',
    );
    final previewPassword = _birthday != null
        ? ParentCredentialHelper.generateTempPassword(
            rawLastName.isNotEmpty ? rawLastName : 'lastname',
            _birthday!,
          )
        : '$sanitizedLastName[YYYYMMDD]';

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.badge_outlined,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'LIVE CREDENTIAL PREVIEW',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Login Email',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        previewEmail,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
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
                      'Temporary Password',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        previewPassword,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _birthday != null
                              ? AppTheme.catGreen
                              : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
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
          initialValue: _relationship,
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
          validator: (v) => v == null ? 'Relationship is required.' : null,
        ),
      ],
    );
  }

  int? get _calculatedAge {
    if (_birthday == null) return null;
    final now = DateTime.now();
    int age = now.year - _birthday!.year;
    if (now.month < _birthday!.month ||
        (now.month == _birthday!.month && now.day < _birthday!.day)) {
      age--;
    }
    return age;
  }

  Widget _buildAgeField(ThemeData theme) {
    final ageText = _calculatedAge != null ? '$_calculatedAge yrs old' : '—';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Age',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.cake_outlined,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ageText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: _calculatedAge != null ? FontWeight.w600 : FontWeight.normal,
                    color: _calculatedAge != null
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLinkStudentSection(ThemeData theme) {
    final candidateStudents = (widget.students != null && widget.students!.isNotEmpty)
        ? widget.students!
        : MockDatabase.instance.users.where((u) => u.role == UserRole.student).toList();

    final query = _studentSearchQuery.trim().toLowerCase();
    final matchingStudents = query.isEmpty
        ? <UserModel>[]
        : candidateStudents.where((u) {
            final nameMatch = u.fullName.toLowerCase().contains(query);
            final lrnMatch = (u.lrn ?? '').toLowerCase().contains(query);
            final isAlreadySelected = _selectedStudents.any((s) => s.id == u.id);
            return !isAlreadySelected && (nameMatch || lrnMatch);
          }).take(6).toList();

    return FormField<List<UserModel>>(
      initialValue: _selectedStudents,
      validator: (_) {
        if (_selectedStudents.isEmpty) {
          return 'Link student is required.';
        }
        return null;
      },
      builder: (field) {
        final hasError = field.hasError;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Link Students *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: hasError ? theme.colorScheme.error : theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  '${_selectedStudents.length} linked',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _studentSearchCtrl,
              onChanged: (val) => setState(() => _studentSearchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search student by name or LRN...',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                suffixIcon: _studentSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _studentSearchCtrl.clear();
                          setState(() => _studentSearchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.4),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: hasError
                        ? theme.colorScheme.error
                        : theme.colorScheme.outline.withValues(alpha: 0.4),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: hasError ? theme.colorScheme.error : theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
            ),
            if (_studentSearchQuery.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: matchingStudents.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'No matching students found for "$_studentSearchQuery"',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: matchingStudents.map((s) {
                          return InkWell(
                            onTap: () {
                              if (_selectedStudents.length >= 15) {
                                AppModals.showErrorDialog(
                                  context: context,
                                  title: 'Limit Exceeded',
                                  message: 'Too much students to link in one parent account.',
                                );
                                return;
                              }
                              setState(() {
                                _selectedStudents.add(s);
                                field.didChange(_selectedStudents);
                                _studentSearchCtrl.clear();
                                _studentSearchQuery = '';
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                                    child: Text(
                                      s.fullName.isNotEmpty ? s.fullName[0].toUpperCase() : 'S',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s.fullName,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'LRN: ${s.lrn ?? s.studentId ?? 'N/A'} • ${s.departmentOrSection ?? 'Enrolled'}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.add,
                                          size: 14,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Link',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
            const SizedBox(height: 12),
            if (_selectedStudents.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasError
                        ? theme.colorScheme.error
                        : theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasError ? Icons.error_outline : Icons.info_outline,
                      size: 18,
                      color: hasError
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No students linked yet. Search and select up to 15 students to connect.',
                        style: TextStyle(
                          fontSize: 12,
                          color: hasError
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    field.errorText ?? 'Link student is required.',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ] else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedStudents.map((student) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              student.fullName,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              'LRN: ${student.lrn ?? 'N/A'} • ${student.departmentOrSection ?? 'Enrolled'}',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        InkWell(
                          onTap: () => setState(() {
                            _selectedStudents.remove(student);
                            field.didChange(_selectedStudents);
                          }),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        );
      },
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
