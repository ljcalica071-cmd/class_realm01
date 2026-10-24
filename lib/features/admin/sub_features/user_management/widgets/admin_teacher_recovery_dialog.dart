import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/core/utils/validators.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AdminTeacherRecoveryDialog extends StatefulWidget {
  final UserModel teacher;
  final bool isEmailUpdateOnly;

  const AdminTeacherRecoveryDialog({
    super.key,
    required this.teacher,
    required this.isEmailUpdateOnly,
  });

  static Future<bool?> show(BuildContext context, UserModel teacher, {bool isEmailUpdateOnly = false}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AdminTeacherRecoveryDialog(
        teacher: teacher,
        isEmailUpdateOnly: isEmailUpdateOnly,
      ),
    );
  }

  @override
  State<AdminTeacherRecoveryDialog> createState() => _AdminTeacherRecoveryDialogState();
}

class _AdminTeacherRecoveryDialogState extends State<AdminTeacherRecoveryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.teacher.email;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final newEmail = _emailCtrl.text.trim().toLowerCase();
    
    // Additional warning if resetting password
    if (!widget.isEmailUpdateOnly && newEmail == widget.teacher.email.toLowerCase()) {
      setState(() => _errorMessage = "You are resetting the password for the same email address. This is valid, but ensure the teacher still has access to it.");
    } else {
      setState(() => _errorMessage = null);
    }
    
    // Add an extra layer of confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.isEmailUpdateOnly ? 'Confirm Email Update' : 'Confirm Account Recovery'),
        content: Text(
          widget.isEmailUpdateOnly
          ? 'Are you sure you want to change this teacher\'s email to $newEmail? Their password will remain the same.'
          : 'Are you sure you want to recover this account? This will change the email to $newEmail, generate a new temporary password, and force a First Login setup.'
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: TextButton.styleFrom(foregroundColor: widget.isEmailUpdateOnly ? AppTheme.catBlue : AppTheme.catRed),
            child: const Text('Confirm'),
          ),
        ],
      )
    );
    
    if (confirm != true) return;

    setState(() => _isProcessing = true);
    
    try {
      if (widget.isEmailUpdateOnly) {
        await AuthRepository.instance.updateTeacherEmailOnly(
          teacherId: widget.teacher.id,
          newEmail: newEmail,
        );
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        await AuthRepository.instance.recoverTeacherAccount(
          teacherId: widget.teacher.id,
          newEmail: newEmail,
        );
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = widget.isEmailUpdateOnly ? AppTheme.catBlue : AppTheme.catRed;
    final icon = widget.isEmailUpdateOnly ? LucideIcons.mail : LucideIcons.key;
    final title = widget.isEmailUpdateOnly ? 'Update Email Only' : 'Reset & Recover Account';
    
    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            widget.isEmailUpdateOnly
                                ? 'Fix typos without resetting password.'
                                : 'For lost emails or forgotten passwords.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _isProcessing ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                AppTextField(
                  label: 'New Email Address',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  inputFormatters: AppValidators.emailFormatters,
                  validator: AppValidators.validateEmail,
                  hint: 'e.g. new.email@gmail.com',
                ),
                
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.catOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.catOrange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(LucideIcons.alertTriangle, color: AppTheme.catOrange, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(fontSize: 12, color: AppTheme.catOrange),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isProcessing ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    AppButton.primary(
                      label: widget.isEmailUpdateOnly ? 'Update Email' : 'Reset Account',
                      backgroundColor: color,
                      isLoading: _isProcessing,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
