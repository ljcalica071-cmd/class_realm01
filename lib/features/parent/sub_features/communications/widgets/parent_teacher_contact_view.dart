import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:class_realm/data/repositories/supabase_parent_repository.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';

class ParentTeacherContactView extends StatefulWidget {
  final UserModel? linkedStudent;
  final UserModel? student;
  final List<UserModel> allChildren;
  final ValueChanged<UserModel>? onSelectChild;
  final UserModel? teacher;
  final List<Map<String, dynamic>>? initialOfferings;

  const ParentTeacherContactView({
    super.key,
    this.linkedStudent,
    this.student,
    this.allChildren = const [],
    this.onSelectChild,
    this.teacher,
    this.initialOfferings,
  });

  @override
  State<ParentTeacherContactView> createState() =>
      _ParentTeacherContactViewState();
}

class _ParentTeacherContactViewState extends State<ParentTeacherContactView> {
  List<Map<String, dynamic>> _offerings = [];
  bool _isLoading = true;
  late UserModel? _activeStudent;

  @override
  void initState() {
    super.initState();
    _activeStudent =
        widget.student ??
        widget.linkedStudent ??
        (widget.allChildren.isNotEmpty ? widget.allChildren.first : null);
    if (widget.initialOfferings != null &&
        widget.initialOfferings!.isNotEmpty) {
      _offerings = widget.initialOfferings!;
      _isLoading = false;
    } else {
      _loadTeachers();
    }
  }

  Future<void> _loadTeachers({bool silent = false}) async {
    final studentId = _activeStudent?.id;
    if (studentId == null || studentId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (!silent) {
      setState(() => _isLoading = true);
    }

    try {
      final rows = await SupabaseParentRepository()
          .getEnrolledOfferingsWithTeachersForStudent(studentId);
      if (!mounted) return;
      setState(() {
        _offerings = rows;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showChildSwitcherSheet() {
    if (widget.allChildren.isEmpty) return;
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const Text(
                  'Switch Linked Student',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...widget.allChildren.map((child) {
                  final isSelected = child.id == _activeStudent?.id;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.primary.withValues(alpha: 0.14),
                      child: Text(
                        child.lastFirstMi.isNotEmpty
                            ? child.lastFirstMi[0].toUpperCase()
                            : 'S',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    title: Text(
                      child.lastFirstMi,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w600,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      setState(() => _activeStudent = child);
                      widget.onSelectChild?.call(child);
                      _loadTeachers();
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return const {};
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final student = _activeStudent;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          student == null
              ? 'Subject Teachers'
              : "${student.firstName ?? student.fullName}'s Teachers",
        ),
        actions: [
          if (student != null && widget.allChildren.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Center(
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: _showChildSwitcherSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? theme.colorScheme.primary.withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isDark
                            ? theme.colorScheme.primary.withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 110),
                          child: Text(
                            student.firstName?.isNotEmpty == true
                                ? student.firstName!
                                : student.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? theme.colorScheme.primary
                                  : Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: isDark
                              ? theme.colorScheme.primary
                              : Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: _isLoading
              ? Center(
                  child: LoadingAnimationWidget.staggeredDotsWave(
                    color: theme.colorScheme.primary,
                    size: 40,
                  ),
                )
              : AppPullToRefresh(
                  onRefresh: () => _loadTeachers(silent: true),
                  child: _offerings.isEmpty && widget.teacher == null
                      ? AppPullToRefresh.scrollableState(
                          child: _buildEmptyState(theme, isDark, student),
                        )
                      : ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                          children: [
                            if (student != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: theme.colorScheme.onSurface
                                        .withValues(
                                          alpha: isDark ? 0.14 : 0.1,
                                        ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.school_outlined,
                                      size: 20,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            student.fullName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            '${_offerings.length} Enrolled ${_offerings.length == 1 ? 'Subject' : 'Subjects'} · Public Teacher Directory',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.65),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (_offerings.isNotEmpty)
                              ..._offerings.map(
                                (off) => _buildOfferingTeacherCard(
                                  context,
                                  theme,
                                  isDark,
                                  off,
                                ),
                              )
                            else if (widget.teacher != null)
                              _buildFallbackTeacherCard(
                                context,
                                theme,
                                isDark,
                                widget.teacher!,
                              ),
                          ],
                        ),
                ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    ThemeData theme,
    bool isDark,
    UserModel? student,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(
            alpha: isDark ? 0.14 : 0.1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(
                alpha: isDark ? 0.18 : 0.1,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.badge_outlined,
              size: 32,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No Subject Teachers Found',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            student == null
                ? 'Please select a linked student to view their subject teachers.'
                : 'Subject teachers and consultation hours for ${student.fullName} will appear here once enrolled.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferingTeacherCard(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    Map<String, dynamic> offering,
  ) {
    final subjectsMap = _asMap(offering['subjects']);
    final subjectName = subjectsMap['subject_name']?.toString() ?? 'Subject';
    final subjectCode = subjectsMap['subject_code']?.toString() ?? '';

    final sectionsMap = _asMap(offering['sections']);
    final sectionName = sectionsMap['section_name']?.toString() ?? '';

    final teacherMap = _asMap(offering['teacher_profiles']);
    final firstName = teacherMap['first_name']?.toString().trim() ?? '';
    final middleName = teacherMap['middle_name']?.toString().trim() ?? '';
    final lastName = teacherMap['last_name']?.toString().trim() ?? '';
    final gender = teacherMap['gender']?.toString().trim().toLowerCase() ?? '';
    final prefix = (gender == 'female' || gender == 'f')
        ? "Ma'am"
        : (gender == 'male' || gender == 'm')
        ? 'Sir'
        : 'Teacher';
    final rawName = [
      firstName,
      if (middleName.isNotEmpty) middleName,
      lastName,
    ].where((s) => s.isNotEmpty).join(' ');
    final displayName = rawName.isNotEmpty
        ? '$prefix $rawName'
        : 'Assigned Subject Teacher';

    final email = teacherMap['email']?.toString().trim() ?? '';
    final consultation =
        teacherMap['consultation_hours']?.toString().trim() ?? '';
    final specialization =
        teacherMap['subject_specialization']?.toString().trim() ?? '';
    final isPhonePublic = teacherMap['is_phone_public'] == true;
    final phone = isPhonePublic
        ? (teacherMap['contact_number']?.toString().trim() ?? '')
        : '';
    final isFacebookPublic = teacherMap['is_facebook_public'] == true;
    final facebook = isFacebookPublic
        ? (teacherMap['facebook_link']?.toString().trim() ?? '')
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(
            alpha: isDark ? 0.16 : 0.1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.14,
                ),
                child: Text(
                  firstName.isNotEmpty ? firstName[0].toUpperCase() : 'T',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (subjectCode.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              subjectCode,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        subjectName,
                        if (sectionName.isNotEmpty) sectionName,
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.78,
                        ),
                      ),
                    ),
                    if (specialization.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Specialization: $specialization',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          _buildContactRow(
            theme: theme,
            icon: Icons.access_time_rounded,
            label: 'Consultation Hours',
            value: consultation.isNotEmpty
                ? consultation
                : 'By appointment (coordinate via email)',
          ),

          if (email.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildContactRow(
              theme: theme,
              icon: Icons.email_outlined,
              label: 'Email',
              value: email,
              actionLabel: 'Email',
              actionIcon: Icons.send_rounded,
              onAction: () async {
                final uri = Uri(
                  scheme: 'mailto',
                  path: email,
                  query: 'subject=ClassRealm Parent Inquiry: $subjectName',
                );
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                } else {
                  await Clipboard.setData(ClipboardData(text: email));
                  if (context.mounted) {
                    AppModals.showSuccessDialog(
                      context: context,
                      title: 'Email Copied',
                      message: 'Teacher email copied to clipboard: $email',
                    );
                  }
                }
              },
            ),
          ],

          if (phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildContactRow(
              theme: theme,
              icon: Icons.phone_outlined,
              label: 'Public Phone',
              value: phone,
              actionLabel: 'Copy',
              actionIcon: Icons.copy_rounded,
              onAction: () async {
                await Clipboard.setData(ClipboardData(text: phone));
                if (context.mounted) {
                  AppModals.showSuccessDialog(
                    context: context,
                    title: 'Phone Copied',
                    message: 'Contact number copied to clipboard: $phone',
                  );
                }
              },
            ),
          ],

          if (facebook.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildContactRow(
              theme: theme,
              icon: Icons.public_rounded,
              label: 'Public Facebook',
              value: facebook,
              actionLabel: 'Open',
              actionIcon: Icons.open_in_new_rounded,
              onAction: () async {
                final raw = facebook.startsWith('http')
                    ? facebook
                    : 'https://$facebook';
                final uri = Uri.tryParse(raw);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                } else {
                  await Clipboard.setData(ClipboardData(text: facebook));
                  if (context.mounted) {
                    AppModals.showSuccessDialog(
                      context: context,
                      title: 'Link Copied',
                      message: 'Facebook link copied to clipboard: $facebook',
                    );
                  }
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFallbackTeacherCard(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    UserModel t,
  ) {
    final phone = t.isPhonePublic ? (t.contactNumber ?? '') : '';
    final fb = t.isFacebookPublic ? (t.facebookLink ?? '') : '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.honorificFullName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildContactRow(
            theme: theme,
            icon: Icons.access_time_rounded,
            label: 'Consultation Hours',
            value: t.consultationHours ?? 'By appointment',
          ),
          if (t.email.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildContactRow(
              theme: theme,
              icon: Icons.email_outlined,
              label: 'Email',
              value: t.email,
            ),
          ],
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildContactRow(
              theme: theme,
              icon: Icons.phone_outlined,
              label: 'Public Phone',
              value: phone,
            ),
          ],
          if (fb.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildContactRow(
              theme: theme,
              icon: Icons.public_rounded,
              label: 'Public Facebook',
              value: fb,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContactRow({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String value,
    String? actionLabel,
    IconData? actionIcon,
    VoidCallback? onAction,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton.icon(
            onPressed: onAction,
            icon: Icon(actionIcon ?? Icons.open_in_new_rounded, size: 13),
            label: Text(actionLabel),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              textStyle: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}
