import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/repositories/attendance_repository.dart';
import 'package:class_realm/models/attendance_workspace_models.dart';
import 'package:class_realm/shared/widgets/buttons/app_buttons.dart';
import 'package:class_realm/shared/widgets/modals/app_modals.dart';

class AttendanceCutoffDialog extends StatefulWidget {
  final AttendanceCutoffConfig initialConfig;
  final String? subjectLabel;
  final String? scheduleTimeLabel;
  final AttendanceRepository? repository;

  const AttendanceCutoffDialog({
    super.key,
    required this.initialConfig,
    this.subjectLabel,
    this.scheduleTimeLabel,
    this.repository,
  });

  static Future<AttendanceCutoffConfig?> show(
    BuildContext context, {
    required AttendanceCutoffConfig initialConfig,
    String? subjectLabel,
    String? scheduleTimeLabel,
    AttendanceRepository? repository,
  }) {
    final theme = Theme.of(context);
    return showDialog<AttendanceCutoffConfig>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Theme(
        data: theme,
        child: AttendanceCutoffDialog(
          initialConfig: initialConfig,
          subjectLabel: subjectLabel,
          scheduleTimeLabel: scheduleTimeLabel,
          repository: repository,
        ),
      ),
    );
  }

  @override
  State<AttendanceCutoffDialog> createState() => _AttendanceCutoffDialogState();
}

class _AttendanceCutoffDialogState extends State<AttendanceCutoffDialog> {
  static const Color _errorRed = Color(0xFFDC2626);

  late final TextEditingController _openBeforeCtrl;
  late final TextEditingController _presentGraceCtrl;
  late final TextEditingController _lateCutoffCtrl;
  late final TextEditingController _absentCutoffCtrl;

  String? _openBeforeError;
  String? _presentGraceError;
  String? _lateCutoffError;
  String? _absentCutoffError;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _openBeforeCtrl = TextEditingController(
      text: widget.initialConfig.presentStartMinsBefore.toString(),
    );
    _presentGraceCtrl = TextEditingController(
      text: widget.initialConfig.presentGraceMins.toString(),
    );
    _lateCutoffCtrl = TextEditingController(
      text: widget.initialConfig.lateCutoffMins.toString(),
    );
    _absentCutoffCtrl = TextEditingController(
      text: widget.initialConfig.absentCutoffMins.toString(),
    );
  }

  @override
  void dispose() {
    _openBeforeCtrl.dispose();
    _presentGraceCtrl.dispose();
    _lateCutoffCtrl.dispose();
    _absentCutoffCtrl.dispose();
    super.dispose();
  }

  void _resetDefaults() {
    setState(() {
      _openBeforeCtrl.text = '15';
      _presentGraceCtrl.text = '15';
      _lateCutoffCtrl.text = '45';
      _absentCutoffCtrl.text = '60';
      _openBeforeError = null;
      _presentGraceError = null;
      _lateCutoffError = null;
      _absentCutoffError = null;
    });
  }

  bool _validateFields() {
    String? openErr;
    String? graceErr;
    String? lateErr;
    String? absentErr;

    final openVal = int.tryParse(_openBeforeCtrl.text.trim());
    final graceVal = int.tryParse(_presentGraceCtrl.text.trim());
    final lateVal = int.tryParse(_lateCutoffCtrl.text.trim());
    final absentVal = int.tryParse(_absentCutoffCtrl.text.trim());

    if (openVal == null || openVal < 0 || openVal > 60) {
      openErr = 'Enter a whole number between 0 and 60 minutes.';
    }
    if (graceVal == null || graceVal < 0 || graceVal > 120) {
      graceErr = 'Enter a whole number between 0 and 120 minutes.';
    }
    if (lateVal == null || lateVal < 1 || lateVal > 180) {
      lateErr = 'Enter a whole number between 1 and 180 minutes.';
    }
    if (absentVal == null || absentVal < 1 || absentVal > 240) {
      absentErr = 'Enter a whole number between 1 and 240 minutes.';
    }

    // Relational checks once individual numbers are within valid range
    if (graceErr == null && lateErr == null && graceVal != null && lateVal != null) {
      if (graceVal >= lateVal) {
        lateErr =
            'Late cutoff must be strictly greater than Present grace period ($graceVal mins).';
      }
    }

    if (lateErr == null &&
        absentErr == null &&
        lateVal != null &&
        absentVal != null) {
      if (lateVal > absentVal) {
        absentErr =
            'Auto-Absent cutoff must be greater than or equal to Late cutoff ($lateVal mins).';
      }
    }

    setState(() {
      _openBeforeError = openErr;
      _presentGraceError = graceErr;
      _lateCutoffError = lateErr;
      _absentCutoffError = absentErr;
    });

    return openErr == null &&
        graceErr == null &&
        lateErr == null &&
        absentErr == null;
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    if (!_validateFields()) return;

    final updated = AttendanceCutoffConfig(
      subjectOfferingId: widget.initialConfig.subjectOfferingId,
      presentStartMinsBefore: int.parse(_openBeforeCtrl.text.trim()),
      presentGraceMins: int.parse(_presentGraceCtrl.text.trim()),
      lateCutoffMins: int.parse(_lateCutoffCtrl.text.trim()),
      absentCutoffMins: int.parse(_absentCutoffCtrl.text.trim()),
    );

    if (widget.repository == null) {
      Navigator.of(context).pop(updated);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.repository!.saveCutoffConfig(updated);
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      await AppModals.showErrorDialog(
        context: context,
        title: 'Unable to Save Cutoff Rules',
        message: e.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final openPreview = int.tryParse(_openBeforeCtrl.text.trim()) ?? 15;
    final gracePreview = int.tryParse(_presentGraceCtrl.text.trim()) ?? 15;
    final latePreview = int.tryParse(_lateCutoffCtrl.text.trim()) ?? 45;
    final absentPreview = int.tryParse(_absentCutoffCtrl.text.trim()) ?? 60;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 18,
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 490),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(
                        alpha: isDark ? 0.2 : 0.1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      LucideIcons.clock4,
                      color: theme.colorScheme.primary,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attendance Cutoff Rules',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (widget.subjectLabel != null &&
                            widget.subjectLabel!.trim().isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            widget.subjectLabel!,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ],
                        if (widget.scheduleTimeLabel != null &&
                            widget.scheduleTimeLabel!.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Scheduled Time: ${widget.scheduleTimeLabel!}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _isSaving ? null : _resetDefaults,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text(
                      'Reset Defaults',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Visual Timeline Summary Strip
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.05)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                  ),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildWindowPill(
                      label: '-${openPreview}m Scan Opens',
                      color: AppTheme.catTeal,
                      isDark: isDark,
                    ),
                    Icon(
                      LucideIcons.arrowRight,
                      size: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    _buildWindowPill(
                      label: '+${gracePreview}m Present',
                      color: AppTheme.catGreen,
                      isDark: isDark,
                    ),
                    Icon(
                      LucideIcons.arrowRight,
                      size: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    _buildWindowPill(
                      label: '+${latePreview}m Late',
                      color: AppTheme.catOrange,
                      isDark: isDark,
                    ),
                    Icon(
                      LucideIcons.arrowRight,
                      size: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    _buildWindowPill(
                      label: '+${absentPreview}m Auto-Absent',
                      color: AppTheme.catRed,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 1. Scan Window Opens Before Start
              _buildMinutesField(
                theme: theme,
                isDark: isDark,
                label: 'Scan Window Opens Before Start (mins)',
                helper: 'Allowed range: 0–60 mins before class start (default 15)',
                controller: _openBeforeCtrl,
                errorText: _openBeforeError,
                accentColor: AppTheme.catTeal,
                icon: LucideIcons.radio,
                onChanged: (_) {
                  setState(() => _openBeforeError = null);
                },
              ),
              const SizedBox(height: 14),

              // 2. Present Grace Period After Start
              _buildMinutesField(
                theme: theme,
                isDark: isDark,
                label: 'Present Grace Period After Start (mins)',
                helper: 'Allowed range: 0–120 mins after class start (default 15)',
                controller: _presentGraceCtrl,
                errorText: _presentGraceError,
                accentColor: AppTheme.catGreen,
                icon: LucideIcons.checkCircle2,
                onChanged: (_) {
                  setState(() {
                    _presentGraceError = null;
                    if (_lateCutoffError != null &&
                        _lateCutoffError!.contains('Present grace period')) {
                      _lateCutoffError = null;
                    }
                  });
                },
              ),
              const SizedBox(height: 14),

              // 3. Late Cutoff After Start
              _buildMinutesField(
                theme: theme,
                isDark: isDark,
                label: 'Late Cutoff After Start (mins)',
                helper:
                    'Allowed range: 1–180 mins; must be greater than Present grace period',
                controller: _lateCutoffCtrl,
                errorText: _lateCutoffError,
                accentColor: AppTheme.catOrange,
                icon: LucideIcons.clock,
                onChanged: (_) {
                  setState(() {
                    _lateCutoffError = null;
                    if (_absentCutoffError != null &&
                        _absentCutoffError!.contains('Late cutoff')) {
                      _absentCutoffError = null;
                    }
                  });
                },
              ),
              const SizedBox(height: 14),

              // 4. Auto-Absent Cutoff After Start
              _buildMinutesField(
                theme: theme,
                isDark: isDark,
                label: 'Auto-Absent Cutoff After Start (mins)',
                helper:
                    'Allowed range: 1–240 mins; must be at least Late cutoff',
                controller: _absentCutoffCtrl,
                errorText: _absentCutoffError,
                accentColor: AppTheme.catRed,
                icon: LucideIcons.userX,
                onChanged: (_) {
                  setState(() => _absentCutoffError = null);
                },
              ),

              const SizedBox(height: 24),

              // Footer Actions
              Row(
                children: [
                  Expanded(
                    child: AppSecondaryButton(
                      label: 'Cancel',
                      height: 42,
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(null),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppPrimaryButton(
                      label: 'Save Cutoff Rules',
                      icon: LucideIcons.check,
                      height: 42,
                      isLoading: _isSaving,
                      onPressed: _isSaving ? null : _handleSave,
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

  Widget _buildWindowPill({
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white.withValues(alpha: 0.9) : color,
        ),
      ),
    );
  }

  Widget _buildMinutesField({
    required ThemeData theme,
    required bool isDark,
    required String label,
    required String helper,
    required TextEditingController controller,
    required String? errorText,
    required Color accentColor,
    required IconData icon,
    required ValueChanged<String> onChanged,
  }) {
    final hasError = errorText != null;
    final normalBorder = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.16)
        : const Color(0xFFCBD5E1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          enabled: !_isSaving,
          keyboardType: TextInputType.number,
          inputFormatters: [
            LengthLimitingTextInputFormatter(4),
          ],
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              size: 16,
              color: hasError ? _errorRed : accentColor,
            ),
            suffixText: 'mins',
            suffixStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
            isDense: true,
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: hasError ? _errorRed : normalBorder,
                width: hasError ? 1.5 : 1.0,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: hasError ? _errorRed : normalBorder,
                width: hasError ? 1.5 : 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: hasError ? _errorRed : theme.colorScheme.primary,
                width: hasError ? 1.5 : 1.6,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        if (hasError)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 14,
                  color: _errorRed,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  errorText,
                  style: const TextStyle(
                    color: _errorRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          )
        else
          Text(
            helper,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
      ],
    );
  }
}
