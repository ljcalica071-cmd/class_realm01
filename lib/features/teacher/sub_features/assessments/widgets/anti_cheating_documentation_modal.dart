import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/widgets/common/app_buttons.dart';

class AntiCheatingDocumentationModal extends StatelessWidget {
  const AntiCheatingDocumentationModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const AntiCheatingDocumentationModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 680,
          maxHeight: 720,
        ),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                color: isDark
                    ? theme.colorScheme.primary.withValues(alpha: 0.15)
                    : theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.15),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.shield_rounded,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Anti-Cheating & Exam Integrity System',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Single-page policy reference for assessment delivery and telemetry',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // Scrollable Categorized Content
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Category 1: Question Categories & Deterministic Order
                      _buildCategoryCard(
                        theme: theme,
                        isDark: isDark,
                        categoryNumber: '1',
                        title: 'Fixed Question Categories & Deterministic Shuffling',
                        icon: Icons.shuffle_rounded,
                        color: AppTheme.catBlue,
                        points: [
                          'Standard Category Sequence: Part 1 is always Multiple Choice, Part 2 is True or False, and Part 3 is Identification.',
                          'Isolated Shuffling: Questions and choices are shuffled exclusively within their own part so the structure remains clean.',
                          'Deterministic Seed: Shuffling is tied to the student\'s unique ID. Reopening the app preserves their exact sequence, but no two students share the same order.',
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Category 2: Schedule, Duration & Answering Integrity
                      _buildCategoryCard(
                        theme: theme,
                        isDark: isDark,
                        categoryNumber: '2',
                        title: 'Schedule Synchronization & Offline Resilience',
                        icon: Icons.timer_outlined,
                        color: AppTheme.catPurple,
                        points: [
                          'Strict Window Enforcement: The exam opens exactly at the Scheduled Date and Start Time, with a maximum 180-minute duration limit.',
                          'Mandatory Answering: Students must provide a response to every item before submission can be unlocked.',
                          'Zero Data Loss Local Vault: Answers are continuously backed up to offline local storage. In case of network drops, students can finish and submit.',
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Category 3: Anti-Cheating Telemetry Matrix
                      _buildCategoryCard(
                        theme: theme,
                        isDark: isDark,
                        categoryNumber: '3',
                        title: 'Silent Anti-Cheating Telemetry Matrix',
                        icon: Icons.security_rounded,
                        color: AppTheme.catOrange,
                        points: [
                          'Screen & App State: Tab switching, window blur, app minimizing, and split-screen triggers are detected and timestamped.',
                          'Dual-Device Blocking: A student can only test from one device at a time. Simultaneous secondary logins are locked out.',
                          'Silent Monitoring: The system never interrupts the student with disruptive warning alerts, ensuring natural behavior and zero anxiety.',
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Category 4: Sole Teacher Authority & Judgment
                      _buildCategoryCard(
                        theme: theme,
                        isDark: isDark,
                        categoryNumber: '4',
                        title: 'Teacher Exclusive Judgment & Disciplinary Action',
                        icon: Icons.gavel_rounded,
                        color: AppTheme.catGreen,
                        points: [
                          'No Automated Penalties: The system never auto-invalidates or auto-disqualifies students for harmless app notifications.',
                          'Live Proctoring Panel: Teachers monitor active students, violations, and remaining duration in real time.',
                          'Teacher Discretion: The teacher alone holds the authority to Kick & Disqualify, invalidate a test, or authorize a retake.',
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Modal Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.15),
                  ),
                ),
                color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppPrimaryButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icons.check_circle_outline,
                    label: 'I Understand',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard({
    required ThemeData theme,
    required bool isDark,
    required String categoryNumber,
    required String title,
    required IconData icon,
    required Color color,
    required List<String> points,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.08)
            : color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.25 : 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.25 : 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'PART $categoryNumber',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...points.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5, right: 8),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      point,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
