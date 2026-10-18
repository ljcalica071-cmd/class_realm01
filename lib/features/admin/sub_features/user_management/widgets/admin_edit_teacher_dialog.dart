import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:class_realm/core/utils/validators.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/widgets/common/app_buttons.dart';
import 'package:class_realm/widgets/common/app_modals.dart';
import 'package:class_realm/widgets/common/app_text_field.dart';
import 'package:class_realm/widgets/common/app_date_picker_field.dart';

class AdminEditTeacherDialog extends StatefulWidget {
  final UserModel teacher;
  final VoidCallback onTeacherUpdated;

  const AdminEditTeacherDialog({
    super.key,
    required this.teacher,
    required this.onTeacherUpdated,
  });

  static Future<bool?> show(
    BuildContext context, {
    required UserModel teacher,
    required VoidCallback onTeacherUpdated,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AdminEditTeacherDialog(
        teacher: teacher,
        onTeacherUpdated: onTeacherUpdated,
      ),
    );
  }

  @override
  State<AdminEditTeacherDialog> createState() => _AdminEditTeacherDialogState();
}

class _AdminEditTeacherDialogState extends State<AdminEditTeacherDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _middleNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _emailCtrl;
  String? _gender;
  DateTime? _birthday;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.teacher;
    _firstNameCtrl = TextEditingController(text: t.firstName ?? '');
    _middleNameCtrl = TextEditingController(text: t.middleName ?? '');
    _lastNameCtrl = TextEditingController(text: t.lastName ?? '');
    _emailCtrl = TextEditingController(text: t.email);
    _gender = (t.gender == 'Male' || t.gender == 'Female') ? t.gender : 'Male';
    _birthday = t.birthday;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthday == null) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Birthdate Required',
        message: 'Please select the teacher\'s birthdate.',
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final success = await AuthRepository.instance.updateTeacherProfile(
        teacherId: widget.teacher.id,
        firstName: _firstNameCtrl.text.trim(),
        middleName: _middleNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        gender: _gender ?? 'Male',
        birthday: _birthday!,
      );

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop(true);
      } else {
        AppModals.showErrorDialog(
          context: context,
          title: 'Update Failed',
          message: 'Could not update teacher details. Please try again.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppModals.showErrorDialog(
        context: context,
        title: 'Error',
        message: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LucideIcons.userCheck,
                          color: theme.colorScheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Teacher Details',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              'Update personal information for this teacher.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _isSaving ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 20),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Email (Read-Only)
                  AppTextField(
                    label: 'Email Address (Account ID)',
                    controller: _emailCtrl,
                    readOnly: true,
                    enabled: false,
                    hint: 'Email address',
                  ),
                  const SizedBox(height: 14),

                  // Names Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: AppTextField(
                          label: 'First Name*',
                          controller: _firstNameCtrl,
                          validator: (v) =>
                              AppValidators.validateName(v, 'First name'),
                          inputFormatters: AppValidators.nameFormatters,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: AppTextField(
                          label: 'Middle Name',
                          controller: _middleNameCtrl,
                          inputFormatters: AppValidators.nameFormatters,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 5,
                        child: AppTextField(
                          label: 'Last Name*',
                          controller: _lastNameCtrl,
                          validator: (v) =>
                              AppValidators.validateName(v, 'Last name'),
                          inputFormatters: AppValidators.nameFormatters,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Gender & Birthdate Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gender*',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: _gender,
                              isExpanded: true,
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Male', child: Text('Male')),
                                DropdownMenuItem(value: 'Female', child: Text('Female')),
                              ],
                              onChanged: (v) => setState(() => _gender = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: AppDatePickerField(
                          label: 'Birthdate*',
                          initialDate: _birthday,
                          firstDate: BirthdayValidator.getMinDate(),
                          lastDate: BirthdayValidator.getMaxDate('teacher'),
                          onDateSelected: (date) {
                            setState(() => _birthday = date);
                          },
                          validator: (v) => BirthdayValidator.validateBirthday(
                            v,
                            'teacher',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AppButton.secondary(
                        label: 'Cancel',
                        onPressed: _isSaving ? null : () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      AppButton.primary(
                        label: 'Save Changes',
                        isLoading: _isSaving,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
