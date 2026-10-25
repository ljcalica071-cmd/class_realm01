import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import '../models/student_live_proctor_state.dart';

class StudentProctorCard extends StatelessWidget {
  final StudentLiveProctorState state;
  final VoidCallback onKick;
  final VoidCallback onRetake;

  const StudentProctorCard({
    super.key,
    required this.state,
    required this.onKick,
    required this.onRetake,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Violation color coding
    final Color violationColor = state.violationCount == 0
        ? AppTheme.catGreen
        : state.violationCount < 3
            ? AppTheme.catOrange
            : AppTheme.catRed;

    // Status badge color coding
    Color statusBg;
    Color statusText;
    switch (state.status) {
      case ProctorSessionStatus.inProgress:
        statusBg = AppTheme.catBlue.withValues(alpha: 0.1);
        statusText = AppTheme.catBlue;
        break;
      case ProctorSessionStatus.submitted:
        statusBg = AppTheme.catGreen.withValues(alpha: 0.1);
        statusText = AppTheme.catGreen;
        break;
      case ProctorSessionStatus.kicked:
        statusBg = AppTheme.catRed.withValues(alpha: 0.12);
        statusText = AppTheme.catRed;
        break;
      case ProctorSessionStatus.retakeRequested:
        statusBg = AppTheme.catPurple.withValues(alpha: 0.1);
        statusText = AppTheme.catPurple;
        break;
      case ProctorSessionStatus.notStarted:
        statusBg = theme.colorScheme.onSurface.withValues(alpha: 0.08);
        statusText = theme.colorScheme.onSurface.withValues(alpha: 0.6);
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: state.status == ProctorSessionStatus.kicked
            ? AppTheme.catRed.withValues(alpha: 0.04)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: state.isSevere
              ? AppTheme.catRed.withValues(alpha: 0.4)
              : theme.colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            child: Text(
              state.studentName.isNotEmpty ? state.studentName[0] : 'S',
              style: TextStyle(
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        state.studentName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        state.status.displayName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'LRN: ${state.lrn} • ${state.section}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                if (state.kickedReason != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Disqualification Note: ${state.kickedReason}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.catRed,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Violation Count Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: violationColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: violationColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  state.violationCount == 0
                      ? Icons.verified_user_outlined
                      : Icons.warning_amber_rounded,
                  size: 14,
                  color: violationColor,
                ),
                const SizedBox(width: 4),
                Text(
                  '${state.violationCount} Violations',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: violationColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Actions
          if (state.status == ProctorSessionStatus.kicked ||
              state.status == ProctorSessionStatus.submitted)
            IconButton(
              tooltip: 'Authorize Retake',
              icon: const Icon(Icons.replay_rounded, size: 20),
              color: AppTheme.catBlue,
              onPressed: onRetake,
            ),
          if (state.status == ProctorSessionStatus.inProgress) ...[
            IconButton(
              tooltip: 'Reset / Authorize Retake',
              icon: const Icon(Icons.replay_rounded, size: 20),
              color: AppTheme.catBlue,
              onPressed: onRetake,
            ),
            IconButton(
              tooltip: 'Kick & Disqualify',
              icon: const Icon(Icons.gavel, size: 20),
              color: AppTheme.catRed,
              onPressed: onKick,
            ),
          ],
        ],
      ),
    );
  }
}
