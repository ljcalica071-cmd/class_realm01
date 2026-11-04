import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/widgets/common/app_buttons.dart';

class AntiCheatingDocumentationModal extends StatefulWidget {
  const AntiCheatingDocumentationModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const AntiCheatingDocumentationModal(),
    );
  }

  @override
  State<AntiCheatingDocumentationModal> createState() =>
      _AntiCheatingDocumentationModalState();
}

class _AntiCheatingDocumentationModalState
    extends State<AntiCheatingDocumentationModal> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: 700,
        height: 600,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.shield,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Anti-Cheating & Exam Integrity System',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          'Comprehensive guide on how ClassRealm secures digital assessments.',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Progress Indicator
            LinearProgressIndicator(
              value: (_currentPage + 1) / 3,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.catGreen),
            ),

            // Content Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics:
                    const NeverScrollableScrollPhysics(), // Force using buttons
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildPage1(theme),
                  _buildPage2(theme),
                  _buildPage3(theme),
                ],
              ),
            ),

            // Footer / Navigation
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _currentPage > 0
                      ? OutlinedButton.icon(
                          onPressed: _prevPage,
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: const Text('Previous'),
                        )
                      : const SizedBox(width: 100),
                  Text(
                    'Page ${_currentPage + 1} of 3',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  _currentPage < 2
                      ? AppPrimaryButton(
                          onPressed: _nextPage,
                          icon: Icons.arrow_forward,
                          label: 'Next',
                        )
                      : AppPrimaryButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icons.check,
                          label: 'Finish',
                          backgroundColor: AppTheme.catGreen,
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage1(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shuffle, color: AppTheme.catBlue, size: 32),
              const SizedBox(width: 12),
              const Text(
                '1. Deterministic Randomization',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'To prevent students from copying answers from their seatmates, ClassRealm employs a "Deterministic Randomization" algorithm.',
            style: TextStyle(fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 16),
          _buildInfoBox(
            theme,
            title: 'How It Works:',
            content:
                '• Every student receives a completely unique arrangement of questions and choices.\n'
                '• Questions are strictly isolated per category (Multiple Choice stays in Part 1, True/False in Part 2).\n'
                '• The randomization seed is tied to the student\'s unique ID. This means even if they close and reopen the app, their specific randomized order stays exactly the same, but it will never match their classmate\'s order.',
            icon: Icons.extension,
            color: AppTheme.catBlue,
          ),
        ],
      ),
    );
  }

  Widget _buildPage2(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.visibility_off,
                color: AppTheme.catPurple,
                size: 32,
              ),
              const SizedBox(width: 12),
              const Text(
                '2. Silent Tracking Mechanisms',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'We record every suspicious activity on the student\'s device while the exam is active. Crucially, this tracking is 100% silent.',
            style: TextStyle(fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 16),
          _buildInfoBox(
            theme,
            title: 'What is recorded in the Anti-Cheating Logs?',
            content:
                '• Switching to another app (e.g. Browser, Messenger).\n'
                '• Activating Split-Screen mode.\n'
                '• Triggering Google Assistant or "Circle to Search".\n'
                '• Pulling down the notification shade for an extended period.',
            icon: Icons.find_in_page_outlined,
            color: AppTheme.catPurple,
          ),
          const SizedBox(height: 16),
          const Text(
            'Why Silent? We do not show pop-ups or warnings on the student\'s screen when a violation occurs. This prevents students from testing the limits of the system or panicking. They will act organically, giving you a true assessment of their integrity.',
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage3(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gavel, color: AppTheme.catRed, size: 32),
              const SizedBox(width: 12),
              const Text(
                '3. Consequences & Teacher Authority',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'The AI and System will NEVER automatically submit a student\'s exam or kick them out due to violations. We believe that technology should assist, not judge.',
            style: TextStyle(fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 16),
          _buildInfoBox(
            theme,
            title: 'Teacher\'s Sole Authority',
            content:
                '• All infractions are securely sent to the Supabase database with precise timestamps.\n'
                '• After the exam, the Teacher reviews the "Anti-Cheating Logs" on their dashboard.\n'
                '• Only the Teacher has the authority to decide the consequence:\n'
                '   1. Accept the grade if the violation was a minor accident.\n'
                '   2. Invalidate the exam and record a Zero.\n'
                '   3. Authorize a retake or reset.',
            icon: Icons.admin_panel_settings,
            color: AppTheme.catRed,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(
    ThemeData theme, {
    required String title,
    required String content,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              height: 1.8,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
