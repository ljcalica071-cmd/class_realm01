import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/models/student_dashboard_models.dart';
import 'package:class_realm/features/student/shared/widgets/student_submit_work_dialog.dart';

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

  Future<void> _openAttachment(BuildContext context, String? signedUrl) async {
    if (signedUrl == null || signedUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attachment link is expired or unavailable.'),
        ),
      );
      return;
    }

    try {
      String resolvedUrl = signedUrl;
      if (!resolvedUrl.startsWith('http://') &&
          !resolvedUrl.startsWith('https://')) {
        try {
          resolvedUrl = Supabase.instance.client.storage
              .from('classwork-materials')
              .getPublicUrl(resolvedUrl);
        } catch (_) {}
      }

      bool launched = false;
      if (urlLauncher != null) {
        launched = await urlLauncher!(resolvedUrl);
      } else {
        final uri = Uri.parse(resolvedUrl);
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open document.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open document.')),
        );
      }
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
    final isSubmitted =
        classwork.status == 'submitted' || classwork.status == 'graded';
    final isOverdue =
        !isSubmitted &&
        classwork.deadline != null &&
        classwork.deadline!.isBefore(DateTime.now());
    final isMissing = !isSubmitted &&
        (isOverdue || classwork.status == 'missing');
    final status = classwork.status == 'graded'
        ? 'Graded'
        : classwork.status == 'submitted'
        ? 'Submitted'
        : classwork.status == 'returned'
        ? 'Returned'
        : isMissing
        ? 'Missing'
        : 'Assigned';
    final statusColor = classwork.status == 'graded'
        ? const Color(0xFF0F8A48)
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
                          classwork.sectionName,
                          if (classwork.gradeLevel.isNotEmpty)
                            'Grade ${classwork.gradeLevel}',
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

            if (classwork.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                classwork.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ],

            if (classwork.instructions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.5),
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
                    Text(
                      classwork.instructions,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],

            // 1. TEACHER'S ATTACHED REFERENCE MATERIAL (PDF or DOC)
            if (classwork.attachment != null) ...[
              const SizedBox(height: 12),
              _buildDocumentCard(
                context: context,
                theme: theme,
                title: 'Teacher Attached Material',
                fileName: classwork.attachment!.fileName,
                fileSizeBytes: classwork.attachment!.fileSizeBytes,
                signedUrl: classwork.attachment!.signedUrl,
                buttonLabel: 'Open Material',
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
                if (classwork.maxScore > 0)
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
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
                        'In-Person ${classwork.type == 'performance_task' ? 'Performance Task' : 'Activity'}: Submit your physical work directly to your teacher in class. Your score and status will appear here once recorded.',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6D28D9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              if (isOverdue) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              if (!isOverdue) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSubmitted && classwork.status != 'graded')
                        OutlinedButton.icon(
                          onPressed: () {
                            StudentSubmitWorkDialog.show(
                              context,
                              classwork: classwork,
                              onSubmitted: () => onRefresh?.call(),
                            );
                          },
                          icon: const Icon(Icons.sync, size: 16),
                          label: const Text('Resubmit / Update File'),
                        )
                      else if (!isSubmitted)
                        FilledButton.icon(
                          onPressed: () {
                            StudentSubmitWorkDialog.show(
                              context,
                              classwork: classwork,
                              onSubmitted: () => onRefresh?.call(),
                            );
                          },
                          icon: const Icon(Icons.upload_file, size: 16),
                          label: const Text('Turn In Work (PDF/DOC)'),
                        ),
                    ],
                  ),
                ),
              ],
            ],

            if (classwork.score != null) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F8A48).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF0F8A48).withValues(alpha: 0.25),
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
                    Text(
                      'Recorded Score: ${_formatScore(classwork.score!)} / ${_formatScore(classwork.maxScore)} pts',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF0F8A48),
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
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSubmittedWork
                ? const Color(0xFF0F8A48).withValues(alpha: 0.3)
                : theme.colorScheme.onSurface.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(iconData, size: 24, color: accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
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
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
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
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle ??
                        (fileSizeBytes != null
                            ? '${_formatFileSize(fileSizeBytes)} • Click to open'
                            : 'Click to open document'),
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                  Text(
                    buttonLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.open_in_new,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ],
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

  static String _formatScore(double score) => score == score.roundToDouble()
      ? score.toInt().toString()
      : score.toStringAsFixed(1);
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
  const _Detail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 5),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
