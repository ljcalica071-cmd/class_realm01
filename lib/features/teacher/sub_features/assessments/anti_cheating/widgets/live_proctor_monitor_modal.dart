import 'package:class_realm/core/services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import '../models/student_live_proctor_state.dart';
import '../services/teacher_proctor_channel_service.dart';
import 'kick_student_alert_dialog.dart';
import 'retake_confirmation_dialog.dart';
import 'student_proctor_card.dart';

class LiveProctorMonitorModal extends StatefulWidget {
  final String assessmentId;
  final String assessmentTitle;
  final String section;

  const LiveProctorMonitorModal({
    super.key,
    required this.assessmentId,
    required this.assessmentTitle,
    required this.section,
  });

  static Future<void> show({
    required BuildContext context,
    required String assessmentId,
    required String assessmentTitle,
    required String section,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => LiveProctorMonitorModal(
        assessmentId: assessmentId,
        assessmentTitle: assessmentTitle,
        section: section,
      ),
    );
  }

  @override
  State<LiveProctorMonitorModal> createState() =>
      _LiveProctorMonitorModalState();
}

class _LiveProctorMonitorModalState extends State<LiveProctorMonitorModal> {
  late final TeacherProctorChannelService _channelService;
  List<StudentLiveProctorState> _students = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _channelService = TeacherProctorChannelService(assessmentId: widget.assessmentId);
    _initializeRoster();
  }

  Future<void> _initializeRoster() async {
    try {
      final client = SupabaseService().client;
      final assessmentRow = await client
          .from('digital_assessments')
          .select('subject_offering_id')
          .eq('id', widget.assessmentId)
          .maybeSingle();

      final offeringId = assessmentRow?['subject_offering_id']?.toString();

      var enrollQuery = client
          .from('student_enrollments')
          .select("""
            student_id,
            student_profiles!inner (
              student_id,
              lrn,
              first_name,
              last_name,
              department_or_section
            )
          """)
          .ilike('status', 'enrolled');

      if (offeringId != null && offeringId.isNotEmpty) {
        enrollQuery = enrollQuery.eq('subject_offering_id', offeringId);
      }

      final enrollData = await enrollQuery;
      final learners = <Map<String, String>>[];

      for (final row in enrollData as List? ?? []) {
        final profile = row['student_profiles'] as Map<String, dynamic>? ?? {};
        final sId = row['student_id']?.toString() ?? profile['student_id']?.toString() ?? '';
        final firstName = profile['first_name']?.toString() ?? '';
        final lastName = profile['last_name']?.toString() ?? '';
        final name = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
        final lrn = profile['lrn']?.toString() ?? 'N/A';
        final sec = profile['department_or_section']?.toString() ?? widget.section;

        if (sId.isNotEmpty) {
          learners.add({
            'id': sId,
            'name': name.isNotEmpty ? name : 'Student ($lrn)',
            'lrn': lrn,
            'section': sec,
          });
        }
      }

      _channelService.initializeRoster(learners);
      if (mounted) {
        setState(() {
          _students = _channelService.currentStates;
        });
      }
    } catch (e) {
      debugPrint('Real proctor roster fetch notice: $e');
    }

    _channelService.studentStatesStream.listen((updated) {
      if (mounted) {
        setState(() {
          _students = updated;
        });
      }
    });
  }

  @override
  void dispose() {
    _channelService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final filtered = _students.where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return s.studentName.toLowerCase().contains(q) || s.lrn.contains(q);
    }).toList();

    final activeCount = _students.where((s) => s.status == ProctorSessionStatus.inProgress).length;
    final submittedCount = _students.where((s) => s.status == ProctorSessionStatus.submitted).length;
    final flaggedCount = _students.where((s) => s.hasViolations).length;
    final kickedCount = _students.where((s) => s.status == ProctorSessionStatus.kicked).length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 820,
        height: 640,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.catPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield_outlined, color: AppTheme.catPurple, size: 28),
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
                              'Live Proctoring — ${widget.assessmentTitle}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.catGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.catGreen,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: AppTheme.catGreen,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Section: ${widget.section.isEmpty ? "All Sections" : widget.section} • Real-time tab-switch & focus monitoring',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
            const SizedBox(height: 16),

            // Summary Metric Badges
            Row(
              children: [
                _buildSummaryBadge('Active Learners', '$activeCount', AppTheme.catBlue),
                const SizedBox(width: 10),
                _buildSummaryBadge('Completed', '$submittedCount', AppTheme.catGreen),
                const SizedBox(width: 10),
                _buildSummaryBadge('Flagged / Violations', '$flaggedCount', AppTheme.catOrange),
                const SizedBox(width: 10),
                _buildSummaryBadge('Kicked / Disqualified', '$kickedCount', AppTheme.catRed),
              ],
            ),
            const SizedBox(height: 16),

            // Search Bar
            TextField(
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search learner by name or LRN...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                  ),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
            const SizedBox(height: 14),

            // Student Roster
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No learners found matching filter',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final student = filtered[index];
                        return StudentProctorCard(
                          state: student,
                          onKick: () {
                            KickStudentAlertDialog.show(
                              context: context,
                              studentName: student.studentName,
                              onConfirm: (reason) {
                                _channelService.kickStudent(student.studentId, reason);
                              },
                            );
                          },
                          onRetake: () {
                            RetakeConfirmationDialog.show(
                              context: context,
                              studentName: student.studentName,
                              onConfirm: () {
                                _channelService.authorizeRetake(student.studentId);
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBadge(String title, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
