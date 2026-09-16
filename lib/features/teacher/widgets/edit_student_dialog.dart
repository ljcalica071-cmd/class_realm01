import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/mock_database.dart';
import '../../../models/user_model.dart';
import '../../../widgets/common/app_buttons.dart';
import '../../../widgets/common/app_modals.dart';

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
  late final TextEditingController _gradeLevelCtrl;
  late final TextEditingController _sectionCtrl;
  late final TextEditingController _guardianNameCtrl;
  late final TextEditingController _guardianContactCtrl;
  DateTime? _birthday;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _firstNameCtrl = TextEditingController(text: s.firstName ?? '');
    _middleNameCtrl = TextEditingController(text: s.middleName ?? '');
    _lastNameCtrl = TextEditingController(text: s.lastName ?? '');
    _emailCtrl = TextEditingController(text: s.email);
    _studentIdCtrl = TextEditingController(text: s.studentId ?? '');
    _gradeLevelCtrl = TextEditingController(text: s.gradeLevel ?? '11');
    _sectionCtrl = TextEditingController(text: s.departmentOrSection ?? '');
    _guardianNameCtrl = TextEditingController(text: s.parentGuardianName ?? '');
    _guardianContactCtrl = TextEditingController(
      text: s.parentGuardianContact ?? '',
    );
    _birthday = s.birthday;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _studentIdCtrl.dispose();
    _gradeLevelCtrl.dispose();
    _sectionCtrl.dispose();
    _guardianNameCtrl.dispose();
    _guardianContactCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(2006, 1, 1),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    MockDatabase.instance.updateStudentFull(
      id: widget.student.id,
      firstName: _firstNameCtrl.text.trim(),
      middleName: _middleNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      studentId: _studentIdCtrl.text.trim(),
      gradeLevel: _gradeLevelCtrl.text.trim(),
      section: _sectionCtrl.text.trim(),
      parentGuardianName: _guardianNameCtrl.text.trim(),
      parentGuardianContact: _guardianContactCtrl.text.trim(),
      birthday: _birthday ?? widget.student.birthday ?? DateTime(2006, 1, 1),
    );

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
    final birthdayText = _birthday == null
        ? 'Select Birthday'
        : '${_birthday!.month.toString().padLeft(2, '0')}/${_birthday!.day.toString().padLeft(2, '0')}/${_birthday!.year}';

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
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.edit_outlined,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit Student',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.student.fullName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
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
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildField(_firstNameCtrl, 'First Name *'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _buildField(
                        _middleNameCtrl,
                        'Middle Name / Initial',
                        required: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: _buildField(_lastNameCtrl, 'Last Name *'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _SectionLabel('Account & Contact'),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        _emailCtrl,
                        'Email / Gmail *',
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.isEmpty)
                            return 'Email is required';
                          if (!v.toLowerCase().endsWith('@gmail.com')) {
                            return 'Use a Gmail address ending in @gmail.com';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildField(
                        _studentIdCtrl,
                        'LRN (12-digit number) *',
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'LRN is required';
                          if (v.length != 12 || int.tryParse(v) == null)
                            return 'LRN must be exactly 12 digits';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _SectionLabel('Academic Information'),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(_gradeLevelCtrl, 'Grade Level *'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _buildField(_sectionCtrl, 'Section *')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _pickBirthday,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Birthday',
                            prefixIcon: const Icon(
                              Icons.cake_outlined,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFEFF6FF),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          child: Text(
                            birthdayText,
                            style: TextStyle(
                              fontSize: 14,
                              color: _birthday == null
                                  ? AppColors.textMuted
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _SectionLabel('Parent / Guardian'),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        _guardianNameCtrl,
                        'Guardian Name',
                        required: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildField(
                        _guardianContactCtrl,
                        'Guardian Contact',
                        required: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withOpacity(0.4),
                    ),
                  ),
                  child: const Text(
                    'Note: Editing the student\'s name does not automatically change the username or temporary password for an existing account.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF92400E),
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        AppPrimaryButton(
          label: 'Save Changes',
          icon: Icons.save_outlined,
          onPressed: _submit,
          width: 160,
          height: 44,
        ),
      ],
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label, {
    bool required = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      validator:
          validator ??
          (required
              ? (v) => (v == null || v.isEmpty) ? '$label is required' : null
              : null),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFEFF6FF),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
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
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
