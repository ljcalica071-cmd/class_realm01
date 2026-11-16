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
      margin: const EdgeInsets.only(bottom: 16),
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
          // ── Teacher Profile Header (Teacher Name + Subject Code + Subject Name WITHOUT Section) ──
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
                    // Subject name ONLY (strictly NO section in the list per user instructions)
                    Text(
                      subjectName,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.78,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // ── Contact & Professional Info Section (Matching Reference Design) ──
          Text(
            'Contact & Professional Info',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),

          // 1. Email
          _buildInfoRow(
            theme: theme,
            icon: Icons.email_outlined,
            label: 'Email',
            value: email.isNotEmpty ? email : 'Not provided',
            action: email.isNotEmpty
                ? TextButton.icon(
                    onPressed: () async {
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
                          AppTopToast.success(
                            context,
                            'Teacher email copied to clipboard: $email',
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.send_rounded, size: 13),
                    label: const Text('Email'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
          ),

          // 2. Subject Specialization
          _buildInfoRow(
            theme: theme,
            icon: Icons.science_outlined,
            label: 'Subject Specialization',
            value: specialization.isNotEmpty ? specialization : 'Not specified',
          ),

          // 3. Consultation Hours
          _buildInfoRow(
            theme: theme,
            icon: Icons.schedule_rounded,
            label: 'Consultation Hours',
            value: consultation.isNotEmpty ? consultation : 'Not specified',
          ),

          // 4. Facebook Profile Link
          _buildInfoRow(
            theme: theme,
            icon: Icons.public_rounded,
            label: 'Facebook',
            value: (isFacebookPublic && facebook.isNotEmpty)
                ? facebook
                : 'Not linked',
            privacyBadge: _buildPrivacyBadge(theme, isFacebookPublic),
            action: (isFacebookPublic && facebook.isNotEmpty)
                ? TextButton.icon(
                    onPressed: () async {
                      final raw = facebook.startsWith('http')
                          ? facebook
                          : 'https://$facebook';
                      final uri = Uri.tryParse(raw);
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      } else {
                        await Clipboard.setData(ClipboardData(text: facebook));
                        if (context.mounted) {
                          AppTopToast.success(
                            context,
                            'Facebook link copied to clipboard: $facebook',
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 13),
                    label: const Text('Open'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
          ),

          // 5. Phone Number
          _buildInfoRow(
            theme: theme,
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: (isPhonePublic && phone.isNotEmpty)
                ? phone
                : 'Not provided',
            privacyBadge: _buildPrivacyBadge(theme, isPhonePublic),
            action: (isPhonePublic && phone.isNotEmpty)
                ? TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: phone));
                      if (context.mounted) {
                        AppTopToast.success(
                          context,
                          'Contact number copied to clipboard: $phone',
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 13),
                    label: const Text('Copy'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
          ),
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
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            'Contact & Professional Info',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            theme: theme,
            icon: Icons.email_outlined,
            label: 'Email',
            value: t.email.isNotEmpty ? t.email : 'Not provided',
          ),
          _buildInfoRow(
            theme: theme,
            icon: Icons.science_outlined,
            label: 'Subject Specialization',
            value: t.subjectSpecialization?.isNotEmpty == true
                ? t.subjectSpecialization!
                : 'Not specified',
          ),
          _buildInfoRow(
            theme: theme,
            icon: Icons.schedule_rounded,
            label: 'Consultation Hours',
            value: t.consultationHours?.isNotEmpty == true
                ? t.consultationHours!
                : 'Not specified',
          ),
          _buildInfoRow(
            theme: theme,
            icon: Icons.public_rounded,
            label: 'Facebook',
            value: (t.isFacebookPublic && fb.isNotEmpty) ? fb : 'Not linked',
            privacyBadge: _buildPrivacyBadge(theme, t.isFacebookPublic),
          ),
          _buildInfoRow(
            theme: theme,
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: (t.isPhonePublic && phone.isNotEmpty) ? phone : 'Not provided',
            privacyBadge: _buildPrivacyBadge(theme, t.isPhonePublic),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String value,
    Widget? privacyBadge,
    Widget? action,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              icon,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (privacyBadge != null) ...[
                      const SizedBox(width: 8),
                      privacyBadge,
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 8),
            action,
          ],
        ],
      ),
    );
  }

  Widget _buildPrivacyBadge(ThemeData theme, bool isPublic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: isPublic
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : theme.colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPublic ? Icons.public : Icons.lock,
            size: 10.5,
            color: isPublic
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 3.5),
          Text(
            isPublic ? 'Public' : 'Private',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: isPublic
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
