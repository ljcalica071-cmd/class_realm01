import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/widgets/common/app_buttons.dart';
import 'package:class_realm/widgets/common/app_modals.dart';

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
  late final TextEditingController _contactCtrl;
  String? _gender;
  DateTime? _birthday;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _firstNameCtrl = TextEditingController(text: s.firstName ?? '');
    _middleNameCtrl = TextEditingController(text: s.middleName ?? '');
    _lastNameCtrl = TextEditingController(text: s.lastName ?? '');
    _emailCtrl = TextEditingController(text: s.email);
    _studentIdCtrl = TextEditingController(text: s.lrn ?? s.studentId ?? '');
    _contactCtrl = TextEditingController(text: s.contactNumber ?? '');
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
    _contactCtrl.dispose();
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
      gender: _gender!,
      contactNumber: _contactCtrl.text.trim(),
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
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                const _SectionLabel('Student Details'),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        _studentIdCtrl,
                        'LRN (12-digit number) *',
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
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _gender,
                        decoration: const InputDecoration(
                          labelText: 'Gender *',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(
                            value: 'Female',
                            child: Text('Female'),
                          ),
                        ],
                        validator: (value) =>
                            value == null ? 'Gender is required' : null,
                        onChanged: (value) => setState(() => _gender = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickBirthday,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Birthday *',
                            prefixIcon: Icon(Icons.cake_outlined, size: 18),
                          ),
                          child: Text(birthdayText),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildField(
                        _emailCtrl,
                        'Email / Gmail *',
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Email is required';
                          }
                          if (!v.toLowerCase().endsWith('@gmail.com')) {
                            return 'Use a Gmail address ending in @gmail.com';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildField(
                  _contactCtrl,
                  'Contact Number *',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
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
          child: Text(
            'Cancel',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
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
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
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
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.catRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.catRed, width: 1.5),
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
