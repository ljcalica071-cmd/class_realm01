import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/repositories/supabase_student_repository.dart';
import 'package:class_realm/widgets/common/app_buttons.dart';
import 'package:class_realm/widgets/common/app_modals.dart';
import 'package:class_realm/widgets/common/app_text_field.dart';
import 'package:class_realm/widgets/common/app_date_picker_field.dart';
import 'package:class_realm/core/utils/validators.dart';
import 'package:class_realm/core/services/email_service.dart';

class AddStudentDialog extends StatefulWidget {
  final VoidCallback onStudentCreated;
  final List<Map<String, dynamic>> teacherSubjects;

  const AddStudentDialog({
    super.key,
    required this.onStudentCreated,
    required this.teacherSubjects,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onStudentCreated,
    required List<Map<String, dynamic>> teacherSubjects,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddStudentDialog(
        onStudentCreated: onStudentCreated,
        teacherSubjects: teacherSubjects,
      ),
    );
  }

  @override
  State<AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends State<AddStudentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _studentIdCtrl = TextEditingController();
  String? _gender;
  DateTime? _birthday;
  String? _selectedSubjectId;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _studentIdCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthday == null) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Birthday Required',
        message: 'Please select the student\'s birthday.',
      );
      return;
    }
    if (_selectedSubjectId == null) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Subject Required',
        message: 'Please select a subject/section to enroll the student into.',
      );
      return;
    }

    late final StudentEnrollmentResult result;
    try {
      final repo = SupabaseStudentRepository();
      result = await repo.enrollStudent(
        lrn: _studentIdCtrl.text.trim(),
        firstName: _firstNameCtrl.text.trim(),
        middleName: _middleNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        birthday: _birthday!,
        email: _emailCtrl.text.trim(),
        gender: _gender!,
        subjectId: _selectedSubjectId!,
      );
    } catch (e) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Enrollment Error',
        message: e.toString(),
      );
      return;
    }

    final fullName = [
      _firstNameCtrl.text.trim(),
      if (_middleNameCtrl.text.trim().isNotEmpty) _middleNameCtrl.text.trim(),
      _lastNameCtrl.text.trim(),
    ].join(' ');
    final email = _emailCtrl.text.trim();

    if (result.createdAccount && result.tempPassword != null) {
      EmailService.sendStudentCredentials(
        recipientEmail: email,
        studentName: fullName,
        studentId: result.studentId,
        tempPassword: result.tempPassword!,
      );
    }

    Navigator.of(context).pop();
    widget.onStudentCreated();

    _showConfirmationDialog(
      context: context,
      fullName: fullName,
      email: email,
      createdAccount: result.createdAccount,
    );
  }

  static void _showConfirmationDialog({
    required BuildContext context,
    required String fullName,
    required String email,
    required bool createdAccount,
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
                createdAccount ? 'STUDENT ACCOUNT CREATED' : 'STUDENT ENROLLED',
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
                createdAccount
                    ? 'A temporary password was sent to the student email. On first sign-in, the student must set a new password and verify it by email.'
                    : 'The existing student account was enrolled in this subject and section. Their account credentials were not changed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              _CredentialRow(label: 'Student', value: fullName),
              _CredentialRow(label: 'Email / Username', value: email),
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
              Icons.person_add_alt_1,
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
                  'Add New Student',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Teacher creates the student account',
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
                const _SectionLabel('Student Name'),
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
                const _SectionLabel('Student Details'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'LRN (12-digit number) *',
                        controller: _studentIdCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(12),
                        ],
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'LRN is required';
                          if (v.length != 12 || int.tryParse(v) == null) {
                            return 'LRN must be exactly 12 digits';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _buildGenderField(Theme.of(context))),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppDatePickerField(
                        label: 'Birthday *',
                        initialDate: _birthday,
                        firstDate: DateTime(1970, 1, 1),
                        lastDate: DateTime(
                          DateTime.now().year - 10,
                          DateTime.now().month,
                          DateTime.now().day,
                        ),
                        onDateSelected: (d) => setState(() => _birthday = d),
                        validator: (d) {
                          if (d == null) return 'Birthday is required';
                          final now = DateTime.now();
                          int age = now.year - d.year;
                          if (now.month < d.month ||
                              (now.month == d.month && now.day < d.day))
                            age--;
                          if (age < 10)
                            return 'Student must be at least 10 years old.';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        label: 'Email / Gmail *',
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: AppValidators.validateEmail,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSubjectDropdown(Theme.of(context)),
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

  Widget _buildGenderField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender *',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _gender,
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
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.error,
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.error,
                width: 1.5,
              ),
            ),
            errorStyle: TextStyle(fontSize: 12, color: theme.colorScheme.error),
          ),
          hint: Text(
            'Select Gender',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Gender is required.' : null,
          items: const [
            DropdownMenuItem(
              value: 'Male',
              child: Row(
                children: [
                  Icon(Icons.male, size: 20, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Male'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'Female',
              child: Row(
                children: [
                  Icon(Icons.female, size: 20, color: Colors.pink),
                  SizedBox(width: 8),
                  Text('Female'),
                ],
              ),
            ),
          ],
          onChanged: (v) => setState(() => _gender = v),
        ),
      ],
    );
  }

  Widget _buildSubjectDropdown(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Subject & Section *',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _selectedSubjectId,
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
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.catRed, width: 1.5),
            ),
          ),
          hint: const Text('Select a subject/section to enroll'),
          items: widget.teacherSubjects.map((subject) {
            return DropdownMenuItem<String>(
              value: subject['id'].toString(),
              child: Text(
                '${subject['subject_name']} - ${subject['section_name'] ?? 'No Section'}',
              ),
            );
          }).toList(),
          onChanged: (val) => setState(() => _selectedSubjectId = val),
          validator: (val) => val == null ? 'Subject is required' : null,
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          letterSpacing: 1,
        ),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: 0.12),
                ),
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
