import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/core/services/supabase_service.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/student_dashboard_models.dart';
import 'package:class_realm/features/student/shared/widgets/student_submit_work_dialog.dart';
import 'package:class_realm/features/student/sub_features/academics/screens/student_assessment_screen.dart';
import 'package:class_realm/features/student/sub_features/academics/widgets/student_exam_review_modal.dart';
import 'package:class_realm/widgets/common/app_modals.dart';
import 'package:class_realm/widgets/common/expandable_instructions_text.dart';

class StudentClassworkCard extends StatelessWidget {
  const StudentClassworkCard({
    super.key,
    required this.classwork,
    this.urlLauncher,
    this.onRefresh,
  });

  final StudentClassworkModel classwork;
  final Future<bool> Function(String url)? urlLauncher;
  final VoidCallback? onRefresh;

  static bool _isOpeningAttachment = false;

  Future<void> _openAttachment(BuildContext context, String? signedUrl) async {
    if (_isOpeningAttachment) return;
    if (signedUrl == null || signedUrl.trim().isEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attachment link is expired or unavailable.'),
        ),
      );
      return;
    }

    _isOpeningAttachment = true;
    try {
      final rawUrl = signedUrl.trim();
      String resolvedUrl = rawUrl;

      final isFullHttpUrl =
          rawUrl.startsWith('http://') || rawUrl.startsWith('https://');
      final alreadySigned =
          rawUrl.contains('token=') || rawUrl.contains('Signature=');

      String cleanPath = rawUrl;
      if (!isFullHttpUrl || !alreadySigned) {
        if (cleanPath.contains('/classwork-materials/')) {
          cleanPath = cleanPath.split('/classwork-materials/').last;
        } else if (cleanPath.contains('/classwork%20materials/')) {
          cleanPath = cleanPath.split('/classwork%20materials/').last;
        } else if (cleanPath.contains('/learning_materials/')) {
          cleanPath = cleanPath.split('/learning_materials/').last;
        }
        if (cleanPath.contains('?')) {
          cleanPath = cleanPath.split('?').first;
        }
        cleanPath = Uri.decodeComponent(cleanPath);

        try {
          resolvedUrl = await SupabaseService().adminClient.storage
              .from('classwork-materials')
              .createSignedUrl(cleanPath, 60 * 60);
        } catch (storageErr) {
          debugPrint('Storage createSignedUrl notice: $storageErr');
          if (isFullHttpUrl) {
            resolvedUrl = rawUrl;
          } else {
            // Bucket classwork-materials is public, fallback to public URL
            resolvedUrl = SupabaseService().client.storage
                .from('classwork-materials')
                .getPublicUrl(cleanPath);
          }
        }
      }

      final lower = resolvedUrl.toLowerCase();
      final isOfficeDoc = lower.endsWith('.doc') ||
          lower.endsWith('.docx') ||
          cleanPath.toLowerCase().endsWith('.doc') ||
          cleanPath.toLowerCase().endsWith('.docx');
      Uri targetUri = Uri.parse(resolvedUrl);
      if (kIsWeb && isOfficeDoc) {
        // In Web browsers, doc/docx cannot be natively viewed without downloading.
        // Google Docs Viewer renders it inline in a new tab without downloading.
        targetUri = Uri.parse(
          'https://docs.google.com/viewer?url=${Uri.encodeComponent(resolvedUrl)}&embedded=true',
        );
      }

      bool launched = false;
      if (urlLauncher != null) {
        launched = await urlLauncher!(targetUri.toString());
      } else {
        if (kIsWeb) {
          launched = await launchUrl(targetUri, webOnlyWindowName: '_blank');
        } else {
          // Native App (Android / iOS):
          // 1. Try launching in external application (e.g. Word, Drive, Acrobat Reader)
          try {
            launched = await launchUrl(targetUri, mode: LaunchMode.externalApplication);
          } catch (_) {}

          // 2. Fallback: If no app is installed or handler fails, open via in-app browser overlay
          if (!launched) {
            try {
              final inAppUri = isOfficeDoc
                  ? Uri.parse(
                      'https://docs.google.com/viewer?url=${Uri.encodeComponent(resolvedUrl)}&embedded=true',
                    )
                  : targetUri;
              launched = await launchUrl(inAppUri, mode: LaunchMode.inAppBrowserView);
            } catch (_) {}
          }

          // 3. Last-resort fallback to platform default
          if (!launched) {
            launched = await launchUrl(targetUri, mode: LaunchMode.platformDefault);
          }
        }
      }

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open attachment.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        final errStr = e.toString().toLowerCase();
        final isNotFound =
            errStr.contains('404') ||
            errStr.contains('not_found') ||
            errStr.contains('object not found');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isNotFound
                  ? 'The attached file is no longer available on cloud storage. Please ask your teacher to re-upload it.'
                  : 'Unable to open attachment.',
            ),
          ),
        );
      }
    } finally {
      _isOpeningAttachment = false;
    }
  }

  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MiB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isGraded = classwork.status == 'graded' || classwork.score != null;
    final isSubmitted =
        isGraded || classwork.status == 'submitted';
    final isOverdue =
        !isSubmitted &&
        classwork.deadline != null &&
        classwork.deadline!.isBefore(DateTime.now());
    final isMissing =
        !isSubmitted && (isOverdue || classwork.status == 'missing');
    final status = isGraded
        ? 'Graded'
        : classwork.status == 'submitted'
        ? 'Submitted'
        : classwork.status == 'returned'
        ? 'Returned'
        : isMissing
        ? 'Missing'
        : 'Assigned';
    final statusColor = isGraded
        ? AppTheme.catBlue
        : classwork.status == 'submitted'
        ? AppTheme.catGreen
        : isMissing
        ? const Color(0xFFDC2626)
        : theme.colorScheme.primary;

    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Icon, Title, Section, Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    classwork.type == 'performance_task'
                        ? Icons.workspace_premium_outlined
                        : (classwork.type == 'quiz' || classwork.type == 'exam'
                              ? Icons.quiz_outlined
                              : Icons.assignment_outlined),
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classwork.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          classwork.subjectName,
                          classwork.type == 'performance_task'
                              ? 'Performance Task${classwork.gradebookColumnIndex != null ? ' (PT ${classwork.gradebookColumnIndex})' : ''}'
                              : 'Activity${classwork.gradebookColumnIndex != null ? ' (WW ${classwork.gradebookColumnIndex})' : ''}',
                        ].where((value) => value.isNotEmpty).join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusPill(label: status, color: statusColor),
              ],
            ),

            if ((classwork.instructions.trim().isNotEmpty
                    ? classwork.instructions
                    : classwork.description)
                .trim()
                .isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instructions & Rubrics:',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ExpandableInstructionsText(
                      text: classwork.instructions.trim().isNotEmpty
                          ? classwork.instructions
                          : classwork.description,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],

            // 1. TEACHER'S ATTACHED REFERENCE MATERIAL (PDF or DOC)
            if (classwork.attachment != null &&
                classwork.attachment!.fileName.trim().isNotEmpty &&
                (classwork.attachment!.signedUrl?.trim().isNotEmpty ?? false)) ...[
              const SizedBox(height: 12),
              _buildDocumentCard(
                context: context,
                theme: theme,
                title: 'Teacher Attached Material',
                fileName: classwork.attachment!.fileName,
                fileSizeBytes: classwork.attachment!.fileSizeBytes,
                signedUrl: classwork.attachment!.signedUrl,
                buttonLabel: 'View Attached File',
              ),
            ],

            // 2. STUDENT'S SUBMITTED WORK (PDF or DOC)
            if (classwork.studentSubmission != null) ...[
              const SizedBox(height: 12),
              _buildDocumentCard(
                context: context,
                theme: theme,
                title: 'Your Submitted Work',
                subtitle: classwork.submittedAt != null
                    ? 'Turned in on ${_formatDate(classwork.submittedAt!)}'
                    : 'Turned in online',
                fileName: classwork.studentSubmission!.fileName,
                fileSizeBytes: classwork.studentSubmission!.fileSizeBytes,
                signedUrl: classwork.studentSubmission!.signedUrl,
                buttonLabel: 'View Your Work',
                isSubmittedWork: true,
              ),
            ],

            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _Detail(
                  icon: Icons.event_outlined,
                  text: classwork.deadline == null
                      ? 'No deadline'
                      : 'Due ${_formatDate(classwork.deadline!)}',
                ),
                if (classwork.score != null)
                  _Detail(
                    icon: Icons.grade_rounded,
                    text: 'Score: ${_formatScore(classwork.score!)} / ${_formatScore(classwork.maxScore)} pts',
                    color: AppTheme.catBlue,
                    fontWeight: FontWeight.bold,
                  )
                else if (classwork.maxScore > 0)
                  _Detail(
                    icon: Icons.stars_outlined,
                    text: '${_formatScore(classwork.maxScore)} points',
                  ),
              ],
            ),

            // In-Person Mode vs Online Submission Mode
            if (classwork.completionMode == 'in_person') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.35 : 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.handshake_outlined,
                      size: 16,
                      color: Color(0xFF8B5CF6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        classwork.type == 'exam'
                            ? 'In-Person Periodical Examination: Administered in classroom by teacher. Your score will appear here once recorded in the Gradebook.'
                            : classwork.type == 'quiz'
                            ? 'In-Person Quiz: Administered in classroom by teacher. Your score will appear here once recorded in the Gradebook.'
                            : 'In-Person ${classwork.type == 'performance_task' ? 'Performance Task' : 'Activity'}: Submit your physical work directly to your teacher in class. Your score and status will appear here once recorded.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (classwork.type == 'exam' ||
                classwork.type == 'quiz') ...[
              const SizedBox(height: 12),
              if (isSubmitted) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F8A48).withValues(alpha: isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF0F8A48).withValues(alpha: isDark ? 0.35 : 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 18,
                        color: Color(0xFF0F8A48),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          classwork.score != null
                              ? '${classwork.type == 'quiz' ? 'Quiz' : 'Examination'} Completed • Score: ${_formatScore(classwork.score!)} / ${_formatScore(classwork.maxScore)} pts'
                              : '${classwork.type == 'quiz' ? 'Quiz' : 'Examination'} Submitted • Recorded in system',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF0F8A48),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: classwork.resultsReleased
                      ? OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? const Color(0xFF4ADE80) : const Color(0xFF0F8A48),
                            side: BorderSide(
                              color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF0F8A48),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                          ),
                          onPressed: () => _openExamReview(context),
                          icon: const Icon(Icons.fact_check_outlined, size: 16),
                          label: const Text(
                            'Review Answers & Exam Key',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        )
                      : Tooltip(
                          message:
                              'Answer key not yet released by your teacher.',
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.38),
                              side: BorderSide(
                                color: theme.colorScheme.outline
                                    .withValues(alpha: 0.25),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                            ),
                            onPressed: null,
                            icon: const Icon(Icons.lock_outline, size: 16),
                            label: const Text(
                              'Answer Key Locked',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                ),
              ] else if (isOverdue) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.error.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_clock_outlined,
                        size: 16,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          classwork.type == 'quiz'
                              ? 'Quiz Window Closed: The testing schedule has ended.'
                              : 'Examination Window Closed: The testing schedule has ended.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Builder(
                  builder: (context) {
                    final sched = classwork.assignedAt;
                    final isEntranceClosed = sched != null &&
                        DateTime.now().isAfter(
                          sched.add(const Duration(minutes: 15)),
                        );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (isEntranceClosed) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626).withValues(
                                alpha: 0.08,
                              ),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFDC2626).withValues(
                                  alpha: 0.25,
                                ),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock_clock_outlined,
                                  size: 14,
                                  color: Color(0xFFDC2626),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Entrance Window Expired (15 mins past start) • Instructor authorization required',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            onPressed: () => _startAssessmentFlow(context),
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 18,
                            ),
                            label: Text(
                              classwork.type == 'quiz'
                                  ? 'Take Quiz (App)'
                                  : 'Take Examination (App)',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ] else ...[
              if (isOverdue) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.error.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_clock_outlined,
                        size: 16,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Submission Closed: The deadline has passed and submission is now locked.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Action Buttons: Turn In Work / Resubmit Work
              if (!isOverdue && !isGraded) ...[
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 360;
                    final button = isSubmitted && !isGraded
                        ? OutlinedButton.icon(
                            onPressed: () {
                              StudentSubmitWorkDialog.show(
                                context,
                                classwork: classwork,
                                onSubmitted: () => onRefresh?.call(),
                              );
                            },
                            icon: const Icon(Icons.sync, size: 16),
                            label: Text(
                              isCompact
                                  ? 'Resubmit File'
                                  : 'Resubmit / Update File',
                            ),
                          )
                        : !isSubmitted
                            ? FilledButton.icon(
                                onPressed: () {
                                  StudentSubmitWorkDialog.show(
                                    context,
                                    classwork: classwork,
                                    onSubmitted: () => onRefresh?.call(),
                                  );
                                },
                                icon: const Icon(Icons.upload_file, size: 16),
                                label: Text(
                                  isCompact
                                      ? 'Turn In Work'
                                      : 'Turn In Work (PDF/DOC)',
                                ),
                              )
                            : const SizedBox.shrink();

                    if (isCompact) {
                      return SizedBox(
                        width: double.infinity,
                        child: button,
                      );
                    }

                    return Align(
                      alignment: Alignment.centerRight,
                      child: button,
                    );
                  },
                ),
              ],
            ],

            if (classwork.score != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.catBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.catBlue.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.catBlue.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.grade_rounded,
                        size: 20,
                        color: AppTheme.catBlue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Score Recorded by Teacher',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.catBlue,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '${_formatScore(classwork.score!)} / ${_formatScore(classwork.maxScore)} pts',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: AppTheme.catBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (classwork.feedback?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                'Teacher remarks: ${classwork.feedback!}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard({
    required BuildContext context,
    required ThemeData theme,
    required String title,
    String? subtitle,
    required String fileName,
    int? fileSizeBytes,
    String? signedUrl,
    required String buttonLabel,
    bool isSubmittedWork = false,
  }) {
    final isPdf = fileName.toLowerCase().endsWith('.pdf');
    final accentColor = isPdf
        ? const Color(0xFFDC2626) // PDF Red
        : const Color(0xFF2563EB); // Word Blue
    final iconData = isPdf ? Icons.picture_as_pdf : Icons.description;

    return InkWell(
      onTap: () => _openAttachment(context, signedUrl),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSubmittedWork
              ? const Color(0xFF0F8A48).withValues(alpha: 0.06)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.25,
                ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSubmittedWork
                ? const Color(0xFF0F8A48).withValues(alpha: 0.3)
                : theme.colorScheme.onSurface.withValues(alpha: 0.12),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isVeryNarrow = constraints.maxWidth < 340;
            final isNarrow = constraints.maxWidth < 420;

            final String? actionLabel = isVeryNarrow
                ? null
                : isNarrow
                    ? (buttonLabel.contains('Work') ? 'View Work' : 'View File')
                    : buttonLabel;

            return Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(iconData, size: 20, color: accentColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isPdf ? 'PDF' : 'DOC',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle ??
                            (fileSizeBytes != null
                                ? '${_formatFileSize(fileSizeBytes)} • Click to open'
                                : 'Click to open document'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: actionLabel != null ? 8 : 6,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (actionLabel != null) ...[
                        Text(
                          actionLabel,
                          style: TextStyle(
                            fontSize: isNarrow ? 11 : 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Icon(
                        Icons.open_in_new,
                        size: 13,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'AM' : 'PM';
    return '${months[local.month - 1]} ${local.day}, $hour:$minute $period';
  }

  static String _formatScore(double score) => score.round().toString();

  Future<void> _openExamReview(BuildContext context) async {
    final client = SupabaseService().client;
    try {
      var assessRow = await client
          .from('digital_assessments')
          .select('id, results_released')
          .eq('id', classwork.id)
          .maybeSingle();

      final offeringId = classwork.subjectOfferingId;
      if (assessRow == null && offeringId != null && offeringId.isNotEmpty) {
        assessRow = await client
            .from('digital_assessments')
            .select('id, results_released')
            .eq('subject_offering_id', offeringId)
            .ilike('title', classwork.title)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
      }

      final isReleased =
          (assessRow?['results_released'] == true) || classwork.resultsReleased;
      final assessmentId = assessRow?['id']?.toString() ?? classwork.id;

      if (!isReleased) {
        if (context.mounted) {
          final label = classwork.type == 'quiz' ? 'quiz' : 'examination';
          AppModals.showWarningDialog(
            context: context,
            title: 'Answer Key Not Yet Released',
            message:
                'Your teacher has not yet released the official answer key and $label review for this test. Please check back once all students have completed their submissions.',
          );
        }
        return;
      }

      if (context.mounted) {
        StudentExamReviewModal.show(
          context,
          assessmentId: assessmentId,
          title: classwork.title,
          subjectName: classwork.subjectName,
          maxScore: classwork.maxScore,
        );
      }
    } catch (e) {
      debugPrint('Notice opening exam review: $e');
    }
  }

  Future<void> _startAssessmentFlow(BuildContext context) async {
    if (classwork.assignedAt != null &&
        classwork.assignedAt!.isAfter(DateTime.now())) {
      final diff = classwork.assignedAt!.difference(DateTime.now());
      final timeStr = diff.inHours > 0
          ? '${diff.inHours}h ${diff.inMinutes % 60}m'
          : '${diff.inMinutes} minutes';
      final label = classwork.type == 'quiz' ? 'quiz' : 'examination';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This $label is scheduled for ${_formatDate(classwork.assignedAt!)}. Testing window opens in $timeStr.',
          ),
        ),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final client = SupabaseService().client;
      var rawAssess = await client
          .from('digital_assessments')
          .select("""
            id,
            subject_offering_id,
            assessment_type,
            title,
            instructions,
            time_limit_minutes,
            available_from,
            deadline,
            results_released,
            is_archived,
            assessment_questions (
              id,
              position,
              question_type,
              question_text,
              points,
              assessment_question_options (
                id,
                position,
                option_text,
                is_correct
              )
            )
          """)
          .eq('id', classwork.id)
          .maybeSingle();

      final offeringId = classwork.subjectOfferingId;
      if (rawAssess == null && offeringId != null && offeringId.isNotEmpty) {
        rawAssess = await client
            .from('digital_assessments')
            .select("""
              id,
              subject_offering_id,
              assessment_type,
              title,
              instructions,
              time_limit_minutes,
              available_from,
              deadline,
              results_released,
              is_archived,
              assessment_questions (
                id,
                position,
                question_type,
                question_text,
                points,
                assessment_question_options (
                  id,
                  position,
                  option_text,
                  is_correct
                )
              )
            """)
            .eq('subject_offering_id', offeringId)
            .eq('is_archived', false)
            .ilike('title', classwork.title)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
      }

      if (context.mounted) Navigator.pop(context);

      if (rawAssess == null || rawAssess['is_archived'] == true) {
        AppDataCache.instance.invalidatePrefix('student_dashboard_');
        onRefresh?.call();
        if (context.mounted) {
          await AppModals.showWarningDialog(
            context: context,
            title: 'Assessment Unavailable',
            message:
                'This quiz or examination is no longer available because it was removed by your teacher.',
          );
        }
        return;
      }

      final availRaw = rawAssess['available_from']?.toString();
      final availLocal = availRaw != null
          ? DateTime.tryParse(availRaw)?.toLocal()
          : null;
      if (availLocal != null && DateTime.now().isBefore(availLocal)) {
        final h = availLocal.hour == 0
            ? 12
            : (availLocal.hour > 12 ? availLocal.hour - 12 : availLocal.hour);
        final minStr = availLocal.minute.toString().padLeft(2, '0');
        final ampm = availLocal.hour >= 12 ? 'PM' : 'AM';
        if (context.mounted) {
          await AppModals.showWarningDialog(
            context: context,
            title: 'Assessment Not Yet Open',
            message:
                'This assessment is scheduled to open on ${availLocal.month}/${availLocal.day}/${availLocal.year} at $h:$minStr $ampm.',
          );
        }
        return;
      }

      final schedStart = availLocal ?? classwork.assignedAt;
      final studentId = AuthRepository.instance.currentUser?.id;
      final assessmentDbId = rawAssess['id']?.toString() ?? classwork.id;

      // Check if student has an existing active or submitted attempt
      var hasActiveAttempt = false;
      if (studentId != null) {
        final existingAttempt = await client
            .from('assessment_attempts')
            .select('status')
            .eq('assessment_id', assessmentDbId)
            .eq('student_id', studentId)
            .maybeSingle();
        if (existingAttempt != null &&
            (existingAttempt['status'] == 'in_progress' ||
                existingAttempt['status'] == 'submitted' ||
                existingAttempt['status'] == 'auto_submitted')) {
          hasActiveAttempt = true;
        }
      }

      // 15-Minute Entrance Window Policy:
      // If start time has passed by > 15 minutes, student cannot begin unless:
      // 1. They already started prior to 15 mins (hasActiveAttempt)
      // 2. Instructor explicitly allowed entry (entry_allowed event in anti_cheating_logs)
      if (schedStart != null && !hasActiveAttempt) {
        final entranceWindowClose = schedStart.add(const Duration(minutes: 15));
        final isEntrancePast = DateTime.now().isAfter(entranceWindowClose);

        if (isEntrancePast) {
          bool isTeacherAllowed = false;
          if (studentId != null) {
            final overrideLog = await client
                .from('anti_cheating_logs')
                .select('event_type')
                .eq('assessment_id', assessmentDbId)
                .eq('student_id', studentId)
                .inFilter('event_type', ['entry_allowed', 'entry_disallowed'])
                .order('event_at', ascending: false)
                .limit(1)
                .maybeSingle();
            if (overrideLog != null &&
                overrideLog['event_type'] == 'entry_allowed') {
              isTeacherAllowed = true;
            }
          }

          if (!isTeacherAllowed) {
            if (context.mounted) {
              final h = schedStart.hour == 0
                  ? 12
                  : (schedStart.hour > 12
                        ? schedStart.hour - 12
                        : schedStart.hour);
              final minStr = schedStart.minute.toString().padLeft(2, '0');
              final ampm = schedStart.hour >= 12 ? 'PM' : 'AM';
              await AppModals.showWarningDialog(
                context: context,
                title: 'Entrance Window Closed',
                message:
                    'Under examination protocol, students must enter within 15 minutes of the scheduled start time ($h:$minStr $ampm).\n\nThe 15-minute entrance window has closed. You cannot start this assessment unless your teacher allows entry.',
              );
            }
            return;
          }
        }
      }

      final qRows = (rawAssess['assessment_questions'] as List? ?? [])
          .map((q) => Map<String, dynamic>.from(q as Map))
          .toList();
      qRows.sort(
        (a, b) => ((a['position'] as num?) ?? 0).compareTo(
          (b['position'] as num?) ?? 0,
        ),
      );

      final questions = qRows
          .map((q) => QuestionModel.fromSupabaseMap(q))
          .toList();

      final schedDate = availLocal ?? classwork.assignedAt ?? DateTime.now();
      final assessType = rawAssess['assessment_type']?.toString().toLowerCase();

      final model = QuizOrExamModel(
        id: rawAssess['id'].toString(),
        title: rawAssess['title']?.toString() ?? classwork.title,
        description:
            rawAssess['instructions']?.toString() ?? classwork.instructions,
        subject: classwork.subjectName,
        section: classwork.sectionName,
        isExam: assessType != 'quiz',
        examType: assessType,
        durationMinutes:
            (rawAssess['time_limit_minutes'] as num?)?.toInt() ?? 60,
        scheduleDate: schedDate,
        isPublished: true,
        resultsReleased: rawAssess['results_released'] == true,
        questions: questions,
        subjectOfferingId:
            rawAssess['subject_offering_id']?.toString() ??
            classwork.subjectOfferingId,
      );

      if (context.mounted) {
        await StudentAssessmentScreen.start(context, model);
        onRefresh?.call();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to launch exam: $e')));
      }
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.icon,
    required this.text,
    this.color,
    this.fontWeight,
  });

  final IconData icon;
  final String text;
  final Color? color;
  final FontWeight? fontWeight;

  @override
  Widget build(BuildContext context) {
    final defaultColor = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color ?? defaultColor),
        const SizedBox(width: 5),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: fontWeight,
              ),
        ),
      ],
    );
  }
}
