import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/widgets/common/app_modals.dart';

class ParentSubjectDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> offering;
  final List<ScheduleModel> schedules;
  final Map<int, Map<String, dynamic>> termGrades;

  const ParentSubjectDetailsSheet({
    super.key,
    required this.offering,
    this.schedules = const [],
    this.termGrades = const {},
  });

  static void show(
    BuildContext context, {
    required Map<String, dynamic> offering,
    List<ScheduleModel> schedules = const [],
    Map<int, Map<String, dynamic>> termGrades = const {},
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ParentSubjectDetailsSheet(
        offering: offering,
        schedules: schedules,
        termGrades: termGrades,
      ),
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
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
    final teacherFirstName = teacherMap['first_name']?.toString() ?? '';
    final teacherLastName = teacherMap['last_name']?.toString() ?? '';
    final teacherGender = teacherMap['gender']?.toString() ?? '';
    final teacherName = [teacherFirstName, teacherLastName]
        .where((s) => s.isNotEmpty)
        .join(' ');
    final teacherTitle = teacherGender.toLowerCase() == 'female' ? 'Ms.' : 'Mr.';
    final teacherDisplayName = teacherName.isNotEmpty
        ? '$teacherTitle $teacherName'
        : 'Assigned Subject Teacher';

    final teacherEmail = teacherMap['email']?.toString() ??
        (teacherLastName.isNotEmpty
            ? '${teacherLastName.toLowerCase()}@classrealm.edu'
            : '');

    final termsTaught = (offering['terms_taught'] as num?)?.toInt() ?? 3;
    final termBlock = offering['term_block']?.toString();

    final wwWeight = (offering['ww_weight'] as num?)?.toInt() ?? 25;
    final ptWeight = (offering['pt_weight'] as num?)?.toInt() ?? 50;
    final exWeight = (offering['ex_weight'] as num?)?.toInt() ?? 25;

    // Filter schedules for this subject
    final relevantSchedules = schedules.where((s) {
      final sSubject = s.subject.toLowerCase();
      if (subjectCode.isNotEmpty && sSubject.contains(subjectCode.toLowerCase())) {
        return true;
      }
      return sSubject.contains(subjectName.toLowerCase()) ||
          subjectName.toLowerCase().contains(sSubject);
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
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
              // Drag handle
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

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (subjectCode.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2.5,
                                  ),
                                  margin: const EdgeInsets.only(right: 8),
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
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  termsTaught == 1
                                      ? '1 Term${termBlock != null ? " ($termBlock)" : ""}'
                                      : '3 Terms Full Year',
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
                              'Enrolled in $sectionName ($gradeLevel)',
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

              // Content List
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // ── 1. SUBJECT TEACHER PROFILE & CONTACT ──
                    _buildSectionTitle(theme, 'SUBJECT TEACHER & CONTACT'),
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
                                      'Senior High School Faculty',
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
                                  'Consultation Hours: Mon - Fri · 3:00 PM - 4:30 PM',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.8),
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
                                          .withValues(alpha: 0.8),
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
                                        AppModals.showSuccessDialog(
                                          context: context,
                                          title: 'Email Copied',
                                          message:
                                              'Teacher email copied to clipboard: $teacherEmail',
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.send_rounded, size: 14),
                                  label: const Text('Contact'),
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
                                'Schedule plotted in class timetable.',
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
                                      '${s.startTime} - ${s.endTime}${s.room.isNotEmpty ? " · ${s.room}" : ""}',
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
                    _buildSectionTitle(theme, 'SSHS 3-TERM GRADES & WEIGHTS'),
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
                          // DepEd Component Weights
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
                                'ST-TE (Term Exam)',
                                '$exWeight%',
                                AppTheme.catOrange,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 14),

                          // Term 1, 2, 3 Scores
                          Row(
                            children: [
                              _buildTermScoreTile(
                                theme,
                                isDark,
                                'Term 1',
                                termGrades[1],
                              ),
                              const SizedBox(width: 8),
                              _buildTermScoreTile(
                                theme,
                                isDark,
                                'Term 2',
                                termGrades[2],
                              ),
                              const SizedBox(width: 8),
                              _buildTermScoreTile(
                                theme,
                                isDark,
                                'Term 3',
                                termGrades[3],
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

  Widget _buildTermScoreTile(
    ThemeData theme,
    bool isDark,
    String termLabel,
    Map<String, dynamic>? gradeData,
  ) {
    final transmuted = gradeData?['transmuted_grade']?.toString();
    final hasGrade = transmuted != null && transmuted.isNotEmpty;
    final numGrade = num.tryParse(transmuted ?? '');
    final isPassing = numGrade != null && numGrade >= 75;

    final Color badgeColor = !hasGrade
        ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
        : (isPassing
            ? (isDark ? const Color(0xFF2DD4BF) : AppTheme.catTeal)
            : AppTheme.catRed);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: hasGrade
              ? badgeColor.withValues(alpha: isDark ? 0.14 : 0.08)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
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
              hasGrade ? transmuted : '—',
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
              !hasGrade
                  ? 'Ongoing'
                  : (isPassing ? 'Passed' : 'Needs Help'),
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
