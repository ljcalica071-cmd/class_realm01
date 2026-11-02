import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:class_realm/core/utils/validators.dart';
import 'package:class_realm/data/repositories/supabase_student_repository.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/widgets/common/app_buttons.dart';
import 'package:class_realm/widgets/common/app_modals.dart';
import 'package:class_realm/widgets/common/app_text_field.dart';
import 'package:class_realm/widgets/common/app_date_picker_field.dart';

class EditStudentDialog extends StatefulWidget {
  final UserModel student;
  final VoidCallback onStudentUpdated;

  const EditStudentDialog({
    super.key,
    required this.student,
    required this.onStudentUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required UserModel student,
    required VoidCallback onStudentUpdated,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditStudentDialog(
        student: student,
        onStudentUpdated: onStudentUpdated,
      ),
    );
  }

  @override
  State<EditStudentDialog> createState() => _EditStudentDialogState();
}

class _EditStudentDialogState extends State<EditStudentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _middleNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _studentIdCtrl;
  String? _gender;
  DateTime? _birthday;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _firstNameCtrl = TextEditingController(text: s.firstName ?? '');
    _middleNameCtrl = TextEditingController(text: s.middleName ?? '');
    _lastNameCtrl = TextEditingController(text: s.lastName ?? '');
    _emailCtrl = TextEditingController(text: s.email);
    _studentIdCtrl = TextEditingController(text: s.lrn ?? s.studentId ?? '');
    _gender = s.gender;
    _birthday = s.birthday;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _studentIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthday == null) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Birthday Required',
        message: 'Please select the student\'s birthday.',
      );
      return;
    }
    final subjectId = widget.student.enrolledSubjectId;
    if (subjectId == null || subjectId.isEmpty) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Enrollment Not Found',
        message:
            'This student has no subject and section enrollment to update.',
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await SupabaseStudentRepository().updateStudentFull(
        id: widget.student.id,
        subjectId: subjectId,
        firstName: _firstNameCtrl.text.trim(),
        middleName: _middleNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        studentId: _studentIdCtrl.text.trim(),
        gender: _gender!,
        birthday: _birthday!,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppModals.showErrorDialog(
        context: context,
        title: 'Student Update Failed',
        message: error.toString(),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onStudentUpdated();
    AppModals.showSuccessDialog(
      context: context,
      title: 'Student Updated',
      message: 'Student information has been updated successfully.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
      contentPadding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
      actionsPadding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
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
              Icons.edit_outlined,
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
                  'Edit Student',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.student.fullName,
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
                        validator: (value) =>
                            AppValidators.validateName(value, 'First name'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: AppTextField(
                        label: 'Middle Initial (Optional)',
                        controller: _middleNameCtrl,
                        textCapitalization: TextCapitalization.characters,
                        validator: AppValidators.validateMiddleInitial,
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
                        validator: (value) =>
                            AppValidators.validateName(value, 'Last name'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _SectionLabel('Student Details'),
                Row(
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
                    Expanded(child: _buildGenderField()),
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
                        firstDate: BirthdayValidator.getMinDate(),
                        lastDate: BirthdayValidator.getMaxDate('student'),
                        onDateSelected: (date) =>
                            setState(() => _birthday = date),
                        validator: (date) {
                          if (date == null) return 'Birthday is required';
                          final now = DateTime.now();
                          var age = now.year - date.year;
                          if (now.month < date.month ||
                              (now.month == date.month && now.day < date.day)) {
                            age--;
                          }
                          return age < 10
                              ? 'Student must be at least 10 years old.'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        label: 'Email / Gmail *',
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        validator: AppValidators.validateEmail,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSubjectField(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
        ),
        AppPrimaryButton(
          label: 'Save Changes',
          icon: Icons.save_outlined,
          onPressed: _isSaving ? null : _submit,
          isLoading: _isSaving,
          width: 180,
          height: 44,
        ),
      ],
    );
  }

  Widget _buildGenderField() {
    return DropdownButtonFormField<String>(
      initialValue: _gender,
      decoration: const InputDecoration(labelText: 'Gender *'),
      items: const [
        DropdownMenuItem(value: 'Male', child: Text('Male')),
        DropdownMenuItem(value: 'Female', child: Text('Female')),
      ],
      validator: (value) => value == null ? 'Gender is required' : null,
      onChanged: (value) => setState(() => _gender = value),
    );
  }

  Widget _buildSubjectField() {
    final subject = widget.student.enrolledSubjectName;
    final section = widget.student.departmentOrSection;
    final value = [
      if (subject != null && subject.isNotEmpty) subject,
      if (section != null && section.isNotEmpty) section,
    ].join(' - ');
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Subject & Section *',
        prefixIcon: Icon(Icons.lock_outline, size: 18),
      ),
      child: Text(
        value.isEmpty ? 'No subject or section assigned' : value,
        style: TextStyle(color: Theme.of(context).disabledColor),
      ),
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
