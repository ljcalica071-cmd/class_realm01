import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/supabase_parent_repository.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';

class StudentSettingsScreen extends StatefulWidget {
  final UserModel? studentOverride;
  final List<Map<String, dynamic>>? linkedParentsOverride;

  const StudentSettingsScreen({
    super.key,
    this.studentOverride,
    this.linkedParentsOverride,
  });

  @override
  State<StudentSettingsScreen> createState() => _StudentSettingsScreenState();
}

class _StudentSettingsScreenState extends State<StudentSettingsScreen> {
  bool _hideTermGrades = false;
  bool _hideFinalGrades = false;
  bool _isLoadingPrivacy = true;
  bool _isSavingPrivacy = false;
  List<Map<String, dynamic>> _linkedParents = [];
  UserModel? _student;

  @override
  void initState() {
    super.initState();
    _student = widget.studentOverride ?? AuthRepository.instance.currentUser;
    if (_student != null) {
      _hideTermGrades = _student!.hideTermGradesFromParent;
      _hideFinalGrades = _student!.hideFinalGradesFromParent;
    }
    if (widget.linkedParentsOverride != null) {
      _linkedParents = widget.linkedParentsOverride!;
      _isLoadingPrivacy = false;
    } else {
      _loadPrivacyAndLinkedParents();
    }
  }

  Future<void> _loadPrivacyAndLinkedParents() async {
    final student = _student;
    if (student == null || student.id.isEmpty) {
      if (mounted) setState(() => _isLoadingPrivacy = false);
      return;
    }

    try {
      final repo = SupabaseParentRepository();
      final results = await Future.wait<dynamic>([
        repo.getLinkedParentsForStudent(student.id),
        repo.getStudentGradePrivacySettings(student.id),
      ]);
      if (!mounted) return;
      final parents = results[0] as List<Map<String, dynamic>>;
      final privacy = results[1] as Map<String, bool>;

      setState(() {
        _linkedParents = parents;
        _hideTermGrades = privacy['hideTermGrades'] ?? _hideTermGrades;
        _hideFinalGrades = privacy['hideFinalGrades'] ?? _hideFinalGrades;
        _isLoadingPrivacy = false;
      });

      final updatedStudent = student.copyWith(
        hideTermGradesFromParent: _hideTermGrades,
        hideFinalGradesFromParent: _hideFinalGrades,
      );
      _student = updatedStudent;
      if (widget.studentOverride == null) {
        AuthRepository.instance.setCurrentUser(updatedStudent);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPrivacy = false);
    }
  }

  Future<void> _confirmAndApplyPrivacyToggle({
    required bool nextHideTermGrades,
    required bool nextHideFinalGrades,
    required String toggleLabel,
    required bool isTurningOn,
  }) async {
    final student = _student;
    if (student == null || !student.isLegalAdult) return;

    final parentNames = _linkedParents
        .map((p) => '${p['fullName']} (${p['relationship']})')
        .join(', ');
    final targetLabel = parentNames.isNotEmpty
        ? parentNames
        : 'your linked parent/guardian account(s)';

    AppModals.showConfirmationDialog(
      context: context,
      title: isTurningOn ? 'Hide $toggleLabel?' : 'Show $toggleLabel?',
      message: isTurningOn
          ? 'You are about to hide your $toggleLabel from $targetLabel. Your enrolled subjects, attendance records, class schedule, and subject teacher details will remain visible to them.'
          : 'Your $toggleLabel will now be visible again to $targetLabel on the Parent Portal.',
      confirmLabel: isTurningOn ? 'Hide Grades' : 'Allow Visibility',
      confirmColor: isTurningOn
          ? AppTheme.catOrange
          : Theme.of(context).colorScheme.primary,
      onConfirm: () async {
        setState(() {
          _hideTermGrades = nextHideTermGrades;
          _hideFinalGrades = nextHideFinalGrades;
          _isSavingPrivacy = true;
        });

        try {
          if (widget.studentOverride == null) {
            await SupabaseParentRepository().updateStudentGradePrivacySettings(
              studentId: student.id,
              hideTermGrades: nextHideTermGrades,
              hideFinalGrades: nextHideFinalGrades,
            );
          }
          final updated = student.copyWith(
            hideTermGradesFromParent: nextHideTermGrades,
            hideFinalGradesFromParent: nextHideFinalGrades,
          );
          _student = updated;
          if (widget.studentOverride == null) {
            AuthRepository.instance.setCurrentUser(updated);
          }
        } finally {
          if (mounted) {
            setState(() => _isSavingPrivacy = false);
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final student = _student;
    final age = student?.ageInYears;
    final isAdult = student?.isLegalAdult ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Privacy'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
            children: [
              // ── 1. PARENT / GUARDIAN GRADE PRIVACY CONTROLS (18+ FEATURE) ──
              _buildSectionHeader(theme, 'PARENT / GUARDIAN PRIVACY CONTROLS'),
              _buildParentPrivacyControlCard(
                theme: theme,
                isDark: isDark,
                age: age,
                isAdult: isAdult,
              ),

              const SizedBox(height: 24),

              // ── 2. UNIFIED SETTINGS & LEGAL POLICIES ──
              const PortalSettingsContent(portalLabel: 'Student'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParentPrivacyControlCard({
    required ThemeData theme,
    required bool isDark,
    required int? age,
    required bool isAdult,
  }) {
    final badgeColor = isAdult ? AppTheme.catGreen : AppTheme.catOrange;
    final ageText = age != null ? '$age yrs old' : 'Age not set';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(
            alpha: isDark ? 0.16 : 0.12,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Age Eligibility Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isAdult
                      ? Icons.verified_user_outlined
                      : Icons.lock_clock_outlined,
                  color: badgeColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Grade Visibility Consent',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: badgeColor.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            isAdult
                                ? '18+ Eligible ($ageText)'
                                : '18+ Only ($ageText)',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAdult
                          ? 'As a student aged 18 or above, you have the right to control whether your linked parent or guardian can view your Term Grades and Final Grades.'
                          : 'Students under 18 years old cannot hide Term or Final Grades from their linked parent/guardian. This control unlocks automatically on your 18th birthday.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.72,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Linked Parent / Guardian List
          Text(
            'LINKED PARENT / GUARDIAN ACCOUNT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          if (_isLoadingPrivacy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 3),
            )
          else if (_linkedParents.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.45,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No parent or guardian is currently linked to your student account.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._linkedParents.map((p) {
              final pName = p['fullName']?.toString() ?? 'Parent / Guardian';
              final pRel = p['relationship']?.toString() ?? 'Guardian';
              final pEmail = p['email']?.toString() ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.family_restroom_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          if (pEmail.isNotEmpty)
                            Text(
                              pEmail,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.14,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        pRel,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 12),

          // Pre-Toggle Specification Box (What is Always Visible vs Always Private)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: isDark ? 0.35 : 0.5,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WHAT YOUR LINKED PARENT / GUARDIAN CAN SEE:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
                  ),
                ),
                const SizedBox(height: 8),
                _buildDisclosureRow(
                  theme: theme,
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: AppTheme.catGreen,
                  title: 'Always Visible to Parent/Guardian:',
                  detail:
                      'Enrolled Subjects & Section, Daily & Subject Attendance Logs, Weekly Class Schedule, and Subject Teacher Contact Details.',
                ),
                const SizedBox(height: 8),
                _buildDisclosureRow(
                  theme: theme,
                  icon: Icons.visibility_off_outlined,
                  iconColor: AppTheme.catBlue,
                  title: 'Always Private to Your Student Account:',
                  detail:
                      'Learning Materials, Classwork/Activities (WW), Performance Tasks (PT), Examinations (EX), and your raw activity/exam scores.',
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 18+ Granular Toggles
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  title: Text(
                    'Hide Term Grades (Term 1, 2, 3)',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: isAdult
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                  subtitle: Text(
                    isAdult
                        ? (_hideTermGrades
                              ? 'Hidden from linked parent/guardian (shows Protected 18+)'
                              : 'Currently visible to linked parent/guardian')
                        : 'Locked until age 18 (Term grades remain visible to parent/guardian)',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  value: isAdult && _hideTermGrades,
                  activeThumbColor: theme.colorScheme.primary,
                  onChanged: (!isAdult || _isSavingPrivacy)
                      ? null
                      : (val) => _confirmAndApplyPrivacyToggle(
                          nextHideTermGrades: val,
                          nextHideFinalGrades: _hideFinalGrades,
                          toggleLabel: 'Term Grades (Term 1, 2, 3)',
                          isTurningOn: val,
                        ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  title: Text(
                    'Hide Final Subject Grades & GWA',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: isAdult
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                  subtitle: Text(
                    isAdult
                        ? (_hideFinalGrades
                              ? 'Hidden from linked parent/guardian (shows Protected 18+)'
                              : 'Currently visible to linked parent/guardian')
                        : 'Locked until age 18 (Final grades & GWA remain visible to parent/guardian)',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  value: isAdult && _hideFinalGrades,
                  activeThumbColor: theme.colorScheme.primary,
                  onChanged: (!isAdult || _isSavingPrivacy)
                      ? null
                      : (val) => _confirmAndApplyPrivacyToggle(
                          nextHideTermGrades: _hideTermGrades,
                          nextHideFinalGrades: val,
                          toggleLabel: 'Final Subject Grades & GWA',
                          isTurningOn: val,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclosureRow({
    required ThemeData theme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String detail,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
              children: [
                TextSpan(
                  text: '$title ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: detail),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}
