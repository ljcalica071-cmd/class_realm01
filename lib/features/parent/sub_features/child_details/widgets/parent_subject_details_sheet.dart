import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/utils/deped_grading_engine.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/subject_catalog_model.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';

class ParentSubjectDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> offering;
  final List<ScheduleModel> schedules;
  final Map<int, Map<String, dynamic>> termGrades;
  final UserModel? student;

  const ParentSubjectDetailsSheet({
    super.key,
    required this.offering,
    this.schedules = const [],
    this.termGrades = const {},
    this.student,
  });

  static void show(
    BuildContext context, {
    required Map<String, dynamic> offering,
    List<ScheduleModel> schedules = const [],
    Map<int, Map<String, dynamic>> termGrades = const {},
    UserModel? student,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ParentSubjectDetailsSheet(
        offering: offering,
        schedules: schedules,
        termGrades: termGrades,
        student: student,
      ),
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

  static List<int> _activeTerms(int termsTaught, String termBlock) {
    try {
      return DepEdSubjectCatalog.getActiveTermsForBlock(termsTaught, termBlock);
    } on ArgumentError {
      return switch (termsTaught) {
        1 => const [1],
        2 => const [1, 2],
        _ => const [1, 2, 3],
      };
    }
  }

  static int? _encodedTermGrade(Map<String, dynamic>? row) {
    if (row == null) return null;
    if (row['is_published'] != true) return null;
    final grade = row['transmuted_grade'];
    final parsed = grade is num ? grade.toDouble() : double.tryParse('$grade');
    final remarks = row['remarks']?.toString().toLowerCase();
    final isFinalized = row['is_finalized'] == true;
    if (parsed == null ||
        (!isFinalized &&
            parsed == 0 &&
            (remarks == null || remarks == 'incomplete'))) {
      return null;
    }
    return parsed.round();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final subjectsMap = _asMap(offering['subjects']);
    final subjectName = subjectsMap['subject_name']?.toString() ?? 'Subject';
    final subjectCode = subjectsMap['subject_code']?.toString() ?? '';
    final gradeLevel = subjectsMap['grade_level']?.toString() ?? 'Grade 11/12';

    final sectionsMap = _asMap(offering['sections']);
    final sectionName = sectionsMap['section_name']?.toString() ?? '';

    final teacherMap = _asMap(offering['teacher_profiles']);
    final teacherFirstName = teacherMap['first_name']?.toString().trim() ?? '';
    final teacherMiddleName =
        teacherMap['middle_name']?.toString().trim() ?? '';
    final teacherLastName = teacherMap['last_name']?.toString().trim() ?? '';
    final teacherGender = teacherMap['gender']?.toString().trim() ?? '';
    final teacherName = [
      teacherFirstName,
      if (teacherMiddleName.isNotEmpty) teacherMiddleName,
      teacherLastName,
    ].where((s) => s.isNotEmpty).join(' ');
    final gLower = teacherGender.toLowerCase();
    final teacherTitle = (gLower == 'female' || gLower == 'f')
        ? "Ma'am"
        : (gLower == 'male' || gLower == 'm')
        ? 'Sir'
        : 'Teacher';
    final teacherDisplayName = teacherName.isNotEmpty
        ? '$teacherTitle $teacherName'
        : 'Assigned Subject Teacher';

    final nestedSettings = _asMap(teacherMap['teacher_settings']);
    final teacherEmail = teacherMap['email']?.toString().trim() ?? '';
    final consultationHours =
        (teacherMap['consultation_hours'] ??
                nestedSettings['consultation_hours'])
            ?.toString()
            .trim() ??
        '';
    final specialization =
        teacherMap['subject_specialization']?.toString().trim() ?? '';
    final isPhonePublic =
        teacherMap['is_phone_public'] == true ||
        nestedSettings['is_phone_public'] == true;
    final contactNumber = isPhonePublic
        ? (teacherMap['contact_number']?.toString().trim() ?? '')
        : '';
    final isFacebookPublic =
        teacherMap['is_facebook_public'] == true ||
        nestedSettings['is_facebook_public'] == true;
    final facebookLink = isFacebookPublic
        ? ((teacherMap['facebook_link'] ?? nestedSettings['facebook_link'])
                  ?.toString()
                  .trim() ??
              '')
        : '';

    final termsTaught = ((offering['terms_taught'] as num?)?.toInt() ?? 3)
        .clamp(1, 3);
    final termBlock = offering['term_block']?.toString() ?? '1ST, 2ND, 3RD';
    final activeTerms = _activeTerms(termsTaught, termBlock);

    final wwWeight = (offering['ww_weight'] as num?)?.toInt() ?? 25;
    final ptWeight = (offering['pt_weight'] as num?)?.toInt() ?? 50;
    final exWeight = (offering['ex_weight'] as num?)?.toInt() ?? 25;

    final hideTermGrades = student?.effectiveHideTermGradesFromParent ?? false;
    final hideFinalGrades =
        student?.effectiveHideFinalGradesFromParent ?? false;

    final encodedGradesMap = <int, int?>{
      for (final term in activeTerms) term: _encodedTermGrade(termGrades[term]),
    };
    final isFinalPublished = offering['is_final_grade_published'] == true;
    final computedFinalGrade = isFinalPublished
        ? DepEdGradingEngine.computeFinalGrade(
            termsTaught: activeTerms.length,
            activeTerms: activeTerms,
            termGrades: encodedGradesMap,
          )
        : null;

    final relevantSchedules = schedules.where((s) {
      final sSubject = s.subject.toLowerCase();
      if (subjectCode.isNotEmpty &&
          sSubject.contains(subjectCode.toLowerCase())) {
        return true;
      }
      return sSubject.contains(subjectName.toLowerCase()) ||
          subjectName.toLowerCase().contains(sSubject);
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.84,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (subjectCode.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2.5,
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
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  termsTaught == 1
                                      ? '1 Term ($termBlock)'
                                      : '$termsTaught Terms ($termBlock)',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subjectName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (sectionName.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Enrolled in $sectionName (Grade $gradeLevel)',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.65,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // ── 1. SUBJECT TEACHER PROFILE & PUBLIC CONTACT ──
                    _buildSectionTitle(theme, 'SUBJECT TEACHER INFORMATION'),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: isDark ? 0.16 : 0.1,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: theme.colorScheme.primary
                                    .withValues(alpha: 0.15),
                                child: Text(
                                  teacherFirstName.isNotEmpty
                                      ? teacherFirstName[0].toUpperCase()
                                      : 'T',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      teacherDisplayName,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      specialization.isNotEmpty
                                          ? 'Specialization: $specialization'
                                          : 'Subject Faculty · $subjectName',
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
                          const SizedBox(height: 14),
                          const Divider(height: 1),
                          const SizedBox(height: 12),

                          // Consultation Hours
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  consultationHours.isNotEmpty
                                      ? 'Consultation Hours: $consultationHours'
                                      : 'Consultation Hours: By appointment',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.82),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          if (teacherEmail.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(
                                  Icons.email_outlined,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    teacherEmail,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.82),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () async {
                                    final Uri emailLaunchUri = Uri(
                                      scheme: 'mailto',
                                      path: teacherEmail,
                                      query:
                                          'subject=ClassRealm Inquiry: $subjectName',
                                    );
                                    if (await canLaunchUrl(emailLaunchUri)) {
                                      await launchUrl(emailLaunchUri);
                                    } else {
                                      await Clipboard.setData(
                                        ClipboardData(text: teacherEmail),
                                      );
                                      if (context.mounted) {
                                        AppTopToast.success(
                                          context,
                                          'Teacher email copied: $teacherEmail',
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.send_rounded,
                                    size: 14,
                                  ),
                                  label: const Text('Email'),
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    textStyle: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          if (contactNumber.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.phone_outlined,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Contact Number: $contactNumber',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.82),
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: contactNumber),
                                    );
                                    if (context.mounted) {
                                      AppTopToast.success(
                                        context,
                                        'Contact number copied: $contactNumber',
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.copy_rounded,
                                    size: 14,
                                  ),
                                  label: const Text('Copy'),
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    textStyle: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          if (facebookLink.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.public_rounded,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    facebookLink,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.82),
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () async {
                                    final raw = facebookLink.startsWith('http')
                                        ? facebookLink
                                        : 'https://$facebookLink';
                                    final uri = Uri.tryParse(raw);
                                    if (uri != null &&
                                        await canLaunchUrl(uri)) {
                                      await launchUrl(uri);
                                    } else {
                                      await Clipboard.setData(
                                        ClipboardData(text: facebookLink),
                                      );
                                      if (context.mounted) {
                                        AppTopToast.success(
                                          context,
                                          'Facebook link copied: $facebookLink',
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.open_in_new_rounded,
                                    size: 14,
                                  ),
                                  label: const Text('Open'),
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    textStyle: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── 2. CLASS SCHEDULE ──
                    _buildSectionTitle(theme, 'CLASS SCHEDULE & VENUE'),
                    if (relevantSchedules.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: isDark ? 0.14 : 0.08,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.event_note_outlined,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No specific schedule slot plotted yet for this subject.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...relevantSchedules.map((s) {
                        final cleanRoom = s.room.trim();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: isDark ? 0.16 : 0.1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.catBlue.withValues(
                                    alpha: isDark ? 0.2 : 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 16,
                                  color: AppTheme.catBlue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.dayOfWeek,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${s.startTime} - ${s.endTime}${cleanRoom.isNotEmpty ? " · Room $cleanRoom" : ""}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                    const SizedBox(height: 20),

                    // ── 3. SSHS 3-TERM GRADES & WEIGHTS ──
                    _buildSectionTitle(theme, 'SSHS TERM GRADES & WEIGHTS'),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: isDark ? 0.16 : 0.1,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _buildWeightBadge(
                                theme,
                                'WW (Written Work)',
                                '$wwWeight%',
                                AppTheme.catBlue,
                              ),
                              const SizedBox(width: 8),
                              _buildWeightBadge(
                                theme,
                                'PT (Perf Task)',
                                '$ptWeight%',
                                AppTheme.catTeal,
                              ),
                              const SizedBox(width: 8),
                              _buildWeightBadge(
                                theme,
                                'EX (Term Exam)',
                                '$exWeight%',
                                AppTheme.catOrange,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              for (int term = 1; term <= 3; term++) ...[
                                if (term > 1) const SizedBox(width: 8),
                                _buildTermScoreTile(
                                  theme: theme,
                                  isDark: isDark,
                                  termLabel: 'Term $term',
                                  isActive: activeTerms.contains(term),
                                  encodedGrade: encodedGradesMap[term],
                                  isHiddenBy18Plus: hideTermGrades,
                                  isUnpublished:
                                      termGrades[term] != null &&
                                      termGrades[term]!['is_published'] != true,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'FINAL SUBJECT GRADE',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: hideFinalGrades
                                    ? Align(
                                        alignment: Alignment.centerRight,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.catOrange
                                                .withValues(alpha: 0.14),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.lock_outline_rounded,
                                                size: 13,
                                                color: AppTheme.catOrange,
                                              ),
                                              SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  'Protected (18+ Privacy)',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.catOrange,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    : Text(
                                        computedFinalGrade != null
                                            ? '$computedFinalGrade (${DepEdGradingEngine.getRemarks(computedFinalGrade)})'
                                            : (offering['is_final_grade_published'] ==
                                                      true
                                                  ? 'Ongoing / Awaiting Finalization'
                                                  : 'Pending / Not published'),
                                        textAlign: TextAlign.right,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: computedFinalGrade != null
                                              ? (computedFinalGrade >= 75
                                                    ? AppTheme.catGreen
                                                    : AppTheme.catRed)
                                              : theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildWeightBadge(
    ThemeData theme,
    String label,
    String weight,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              weight,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermScoreTile({
    required ThemeData theme,
    required bool isDark,
    required String termLabel,
    required bool isActive,
    required int? encodedGrade,
    required bool isHiddenBy18Plus,
    bool isUnpublished = false,
  }) {
    if (isHiddenBy18Plus) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: AppTheme.catOrange.withValues(alpha: isDark ? 0.14 : 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.catOrange.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: AppTheme.catOrange,
              ),
              const SizedBox(height: 4),
              Text(
                termLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Hidden (18+)',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.catOrange,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final hasGrade = isActive && encodedGrade != null;
    final isPassing = hasGrade && encodedGrade >= 75;

    final Color badgeColor = !hasGrade
        ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
        : (isPassing
              ? (isDark ? const Color(0xFF2DD4BF) : AppTheme.catTeal)
              : AppTheme.catRed);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: hasGrade
              ? badgeColor.withValues(alpha: isDark ? 0.14 : 0.08)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasGrade
                ? badgeColor.withValues(alpha: isDark ? 0.35 : 0.22)
                : theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          children: [
            Text(
              !isActive ? 'N/A' : (hasGrade ? '$encodedGrade' : '—'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: badgeColor,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              termLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              !isActive
                  ? 'Inactive'
                  : (isUnpublished
                        ? 'Not published'
                        : (!hasGrade
                              ? 'Ongoing'
                              : (isPassing ? 'Passed' : 'Needs Help'))),
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: badgeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
