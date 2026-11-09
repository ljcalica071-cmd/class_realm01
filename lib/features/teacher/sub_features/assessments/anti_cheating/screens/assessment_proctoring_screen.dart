import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:class_realm/core/services/supabase_service.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/anti_cheating/models/student_live_proctor_state.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/anti_cheating/services/teacher_proctor_channel_service.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/anti_cheating/widgets/proctoring_roster_table.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/item_analysis/item_difficulty_stat.dart';

enum ProctorViewTab { liveMonitor, itemAnalysis }

class AssessmentProctoringScreen extends StatefulWidget {
  final QuizOrExamModel assessment;
  final VoidCallback onBack;

  const AssessmentProctoringScreen({
    super.key,
    required this.assessment,
    required this.onBack,
  });

  @override
  State<AssessmentProctoringScreen> createState() =>
      _AssessmentProctoringScreenState();
}

class _AssessmentProctoringScreenState
    extends State<AssessmentProctoringScreen> {
  late final TeacherProctorChannelService _proctorService;
  StreamSubscription<List<StudentLiveProctorState>>? _proctorSub;
  ProctorViewTab _activeTab = ProctorViewTab.liveMonitor;
  String _searchQuery = '';
  bool _isLoading = true;
  bool _soundEnabled = true;
  bool _resultsReleased = false;

  List<StudentLiveProctorState> _rosterStudents = [];
  List<ItemDifficultyStat> _itemStats = [];

  Timer? _lateCheckTimer;

  DateTime get _scheduleDate => widget.assessment.scheduleDate;
  DateTime get _lateCutoff =>
      _scheduleDate.add(const Duration(minutes: 15));
  DateTime get _examEndTime =>
      _scheduleDate.add(Duration(minutes: widget.assessment.durationMinutes));

  bool get _isPastLateCutoff => DateTime.now().isAfter(_lateCutoff);
  bool get _isTestingFinished => DateTime.now().isAfter(_examEndTime);

  @override
  void initState() {
    super.initState();
    _resultsReleased = widget.assessment.resultsReleased;

    _proctorService = TeacherProctorChannelService(
      assessmentId: widget.assessment.id,
    );

    _proctorService.startListening();
    _proctorService.loadHistoricalViolations();

    _proctorSub = _proctorService.studentStatesStream.listen((liveList) {
      if (!mounted) return;
      final map = {for (final s in liveList) s.studentId: s};
      setState(() {
        _rosterStudents = _rosterStudents.map((st) {
          final live = map[st.studentId];
          if (live != null) {
            return st.copyWith(
              status: live.status,
              violationCount: live.violationCount,
              violations: live.violations,
              lastActiveAt: live.lastActiveAt,
              kickedReason: live.kickedReason,
              score: live.score ?? st.score,
              totalPoints: live.totalPoints ?? st.totalPoints,
              isEntryAllowed: live.isEntryAllowed,
              currentQuestionNumber:
                  live.currentQuestionNumber ?? st.currentQuestionNumber,
            );
          }
          return st;
        }).toList();
      });
    });

    _loadLearners();
    if (widget.assessment.isExam) {
      _loadItemAnalysis();
    }

    _lateCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _evaluateLateWindowStatus();
    });
  }

  @override
  void dispose() {
    _lateCheckTimer?.cancel();
    _proctorSub?.cancel();
    _proctorService.dispose();
    super.dispose();
  }

  Future<void> _loadLearners() async {
    setState(() => _isLoading = true);
    try {
      final client = SupabaseService().client;

      // 1. Fetch digital assessment metadata
      final assessmentRow = await client
          .from('digital_assessments')
          .select('subject_offering_id, total_points, results_released')
          .eq('id', widget.assessment.id)
          .maybeSingle();

      final offeringId = assessmentRow?['subject_offering_id']?.toString() ??
          widget.assessment.subjectOfferingId;
      final totalPoints =
          (assessmentRow?['total_points'] as num?)?.toDouble() ??
              widget.assessment.totalPoints;
      _resultsReleased = assessmentRow?['results_released'] == true;

      // 2. Fetch enrollment with 3-tier fallback
      List<dynamic> enrollData = [];
      if (offeringId != null && offeringId.isNotEmpty) {
        try {
          final res = await client
              .from('student_enrollments')
              .select("""
                student_id,
                student_profiles!inner (
                  student_id,
                  lrn,
                  first_name,
                  middle_name,
                  last_name,
                  gender,
                  department_or_section
                )
              """)
              .eq('subject_offering_id', offeringId)
              .ilike('status', 'enrolled');
          enrollData = res as List<dynamic>? ?? [];
        } catch (_) {}
      }

      // Fallback 1: Query by section name in student_profiles
      if (enrollData.isEmpty && widget.assessment.section.isNotEmpty) {
        try {
          final cleanSec =
              widget.assessment.section.replaceAll('Section', '').trim();
          final profileRes = await client
              .from('student_profiles')
              .select(
                'student_id, lrn, first_name, middle_name, last_name, gender, department_or_section',
              )
              .or(
                'department_or_section.ilike.%${widget.assessment.section}%,department_or_section.ilike.%$cleanSec%',
              );
          for (final p in (profileRes as List? ?? [])) {
            enrollData.add({
              'student_id': p['student_id'],
              'student_profiles': p,
            });
          }
        } catch (_) {}
      }

      // Fallback 2: Query all student_profiles
      if (enrollData.isEmpty) {
        try {
          final allProfiles = await client
              .from('student_profiles')
              .select(
                'student_id, lrn, first_name, middle_name, last_name, gender, department_or_section',
              )
              .limit(50);
          for (final p in (allProfiles as List? ?? [])) {
            enrollData.add({
              'student_id': p['student_id'],
              'student_profiles': p,
            });
          }
        } catch (_) {}
      }

      // 3. Fetch existing attempts
      final attemptsData = await client
          .from('assessment_attempts')
          .select('student_id, status, score_earned, current_question_index')
          .eq('assessment_id', widget.assessment.id);
      final attemptsMap = <String, Map<String, dynamic>>{};
      for (final a in (attemptsData as List? ?? [])) {
        final sId = a['student_id']?.toString() ?? '';
        if (sId.isNotEmpty) attemptsMap[sId] = Map<String, dynamic>.from(a);
      }

      // 4. Fetch allow/disallow overrides from anti_cheating_logs
      final logsData = await client
          .from('anti_cheating_logs')
          .select('student_id, event_type, event_at')
          .eq('assessment_id', widget.assessment.id)
          .inFilter('event_type', ['entry_allowed', 'entry_disallowed'])
          .order('event_at', ascending: true);
      final overridesMap = <String, bool>{};
      for (final l in (logsData as List? ?? [])) {
        final sId = l['student_id']?.toString() ?? '';
        final ev = l['event_type']?.toString() ?? '';
        if (sId.isNotEmpty) {
          overridesMap[sId] = ev == 'entry_allowed';
        }
      }

      final pastLateCutoff = _isPastLateCutoff;
      final parsedList = <StudentLiveProctorState>[];

      for (final row in enrollData) {
        final profile =
            row['student_profiles'] as Map<String, dynamic>? ?? {};
        final sId =
            row['student_id']?.toString() ??
            profile['student_id']?.toString() ??
            '';
        final firstName = profile['first_name']?.toString() ?? '';
        final middleName = profile['middle_name']?.toString() ?? '';
        final lastName = profile['last_name']?.toString() ?? '';
        final lrn = profile['lrn']?.toString() ?? '';
        final gender = profile['gender']?.toString() ?? '';
        final fullName =
            [firstName, middleName, lastName].where((s) => s.isNotEmpty).join(' ');

        final attempt = attemptsMap[sId];
        final rawStatus = attempt?['status']?.toString() ?? 'pending';
        final score = (attempt?['score_earned'] as num?)?.toDouble();
        final currentQ =
            (attempt?['current_question_index'] as num?)?.toInt();

        final hasStarted = attempt != null &&
            (rawStatus == 'in_progress' || rawStatus == 'submitted');
        final isMissing = pastLateCutoff && !hasStarted;

        // Entry allowed check: default false if past 15m and never started, unless overridden
        bool isAllowed;
        if (overridesMap.containsKey(sId)) {
          isAllowed = overridesMap[sId]!;
        } else {
          isAllowed = !pastLateCutoff || hasStarted;
        }

        ProctorSessionStatus status;
        if (rawStatus == 'in_progress') {
          status = ProctorSessionStatus.inProgress;
        } else if (rawStatus == 'submitted') {
          status = ProctorSessionStatus.submitted;
        } else {
          status = ProctorSessionStatus.notStarted;
        }

        parsedList.add(
          StudentLiveProctorState(
            studentId: sId,
            studentName: fullName.isNotEmpty ? fullName : 'Learner',
            lrn: lrn,
            section: widget.assessment.section,
            status: status,
            violationCount: 0,
            gender: gender,
            score: score,
            totalPoints: totalPoints,
            isEntryAllowed: isAllowed,
            currentQuestionNumber: currentQ != null ? currentQ + 1 : null,
            isMissing: isMissing,
            lastName: lastName,
            firstName: firstName,
            middleName: middleName,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _rosterStudents = parsedList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading proctoring learners: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _evaluateLateWindowStatus() {
    final pastLate = _isPastLateCutoff;
    if (!pastLate) return;

    setState(() {
      _rosterStudents = _rosterStudents.map((s) {
        if (s.status == ProctorSessionStatus.notStarted) {
          return s.copyWith(isMissing: true);
        }
        return s;
      }).toList();
    });
  }

  Future<void> _loadItemAnalysis() async {
    try {
      final client = SupabaseService().client;
      final questionsRes = await client
          .from('assessment_questions')
          .select('id, question_text, order_index')
          .eq('assessment_id', widget.assessment.id)
          .order('order_index');

      final questions = questionsRes as List<dynamic>? ?? [];
      final responsesRes = await client
          .from('assessment_responses')
          .select('question_id, is_correct')
          .eq('assessment_id', widget.assessment.id);
      final responses = responsesRes as List<dynamic>? ?? [];

      final statsList = <ItemDifficultyStat>[];
      for (int i = 0; i < questions.length; i++) {
        final q = questions[i];
        final qId = q['id'];
        final itemResponses =
            responses.where((r) => r['question_id'] == qId).toList();
        final total = itemResponses.length;
        final correct =
            itemResponses.where((r) => r['is_correct'] == true).length;

        statsList.add(
          ItemDifficultyStat(
            itemNumber: i + 1,
            questionText: q['question_text'] ?? 'Question ${i + 1}',
            totalAttempts: total,
            correctCount: correct,
          ),
        );
      }

      if (mounted) {
        setState(() => _itemStats = statsList);
      }
    } catch (e) {
      debugPrint('Item analysis load error: $e');
    }
  }

  Future<void> _handleResetStudent(StudentLiveProctorState student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(LucideIcons.rotateCcw, color: AppTheme.catBlue, size: 20),
            SizedBox(width: 8),
            Text('Reset Student Progress'),
          ],
        ),
        content: Text(
          'Are you sure you want to reset the assessment for ${student.studentName}? '
          'This will wipe all existing answers and reset their attempt to Question 1.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.catBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset Attempt'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _proctorService.authorizeRetake(student.studentId);
      setState(() {
        final idx =
            _rosterStudents.indexWhere((s) => s.studentId == student.studentId);
        if (idx != -1) {
          _rosterStudents[idx] = _rosterStudents[idx].copyWith(
            status: ProctorSessionStatus.retakeRequested,
            violationCount: 0,
            score: null,
            currentQuestionNumber: 1,
            isEntryAllowed: true,
            isMissing: false,
          );
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Progress reset for ${student.studentName}'),
            backgroundColor: AppTheme.catBlue,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleForceSubmit(StudentLiveProctorState student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(LucideIcons.send, color: AppTheme.catRed, size: 20),
            SizedBox(width: 8),
            Text('Force Submit Assessment'),
          ],
        ),
        content: Text(
          'Force submit the examination for ${student.studentName}? '
          'Their test will be locked and current answers evaluated immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.catRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Force Submit'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _proctorService.forceSubmitStudent(student.studentId);
      setState(() {
        final idx =
            _rosterStudents.indexWhere((s) => s.studentId == student.studentId);
        if (idx != -1) {
          _rosterStudents[idx] = _rosterStudents[idx].copyWith(
            status: ProctorSessionStatus.submitted,
          );
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submitted assessment for ${student.studentName}'),
            backgroundColor: AppTheme.catPurple,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleToggleAllow(StudentLiveProctorState student) async {
    final newAllowed = !student.isEntryAllowed;
    _proctorService.toggleAllowStudent(student.studentId, newAllowed);

    setState(() {
      final idx =
          _rosterStudents.indexWhere((s) => s.studentId == student.studentId);
      if (idx != -1) {
        _rosterStudents[idx] = _rosterStudents[idx].copyWith(
          isEntryAllowed: newAllowed,
          isMissing: !newAllowed && _isPastLateCutoff,
        );
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newAllowed
                ? 'Access unlocked for ${student.studentName}'
                : 'Access locked for ${student.studentName}',
          ),
          backgroundColor: newAllowed ? AppTheme.catGreen : AppTheme.catRed,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleResultsReleased() async {
    final newStatus = !_resultsReleased;
    try {
      final client = SupabaseService().client;
      await client
          .from('digital_assessments')
          .update({'results_released': newStatus})
          .eq('id', widget.assessment.id);

      setState(() => _resultsReleased = newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus
                  ? 'Answer key released to learners'
                  : 'Answer key hidden from learners',
            ),
            backgroundColor: AppTheme.catGreen,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }

  String _formatTime(DateTime date) {
    final hour =
        date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final activeCount = _rosterStudents
        .where((s) => s.status == ProctorSessionStatus.inProgress)
        .length;
    final completedCount = _rosterStudents
        .where((s) => s.status == ProctorSessionStatus.submitted)
        .length;
    final violationsCount =
        _rosterStudents.where((s) => s.violationCount > 0).length;
    final lockedLateCount = _rosterStudents
        .where((s) => !s.isEntryAllowed || s.isMissing)
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── TOP HEADER WITH BACK BUTTON ──
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: widget.onBack,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceContainerHighest
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.1)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.arrowLeft, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Back to Classwork',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.assessment.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.catGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppTheme.catGreen.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.circleDot,
                                size: 10,
                                color: AppTheme.catGreen,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'LIVE',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.catGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Section: ${widget.assessment.section} • Real-time student roster & proctoring monitor',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              // Controls
              IconButton(
                tooltip: _soundEnabled
                    ? 'Mute Alert Sounds'
                    : 'Enable Alert Sounds',
                icon: Icon(
                  _soundEnabled ? LucideIcons.volume2 : LucideIcons.volumeX,
                  size: 19,
                ),
                onPressed: () =>
                    setState(() => _soundEnabled = !_soundEnabled),
              ),
              IconButton(
                tooltip: 'Refresh Roster',
                icon: const Icon(LucideIcons.refreshCw, size: 18),
                onPressed: () {
                  _loadLearners();
                  if (widget.assessment.isExam) _loadItemAnalysis();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── SEGMENTED VIEW SWITCHER (Exam only) ──
          if (widget.assessment.isExam) ...[
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFE2E8F0).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildViewSegment(
                      label: 'Live Proctoring Monitor',
                      icon: LucideIcons.shieldCheck,
                      selected: _activeTab == ProctorViewTab.liveMonitor,
                      onTap: () => setState(
                        () => _activeTab = ProctorViewTab.liveMonitor,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Tooltip(
                      message: _isTestingFinished
                          ? 'View DepEd item difficulty indices'
                          : 'Item Analysis unlocks after the examination time window ends',
                      child: _buildViewSegment(
                        label: 'Item Analysis (DepEd Tiers)',
                        icon: _isTestingFinished
                            ? LucideIcons.barChart2
                            : LucideIcons.lock,
                        selected: _activeTab == ProctorViewTab.itemAnalysis,
                        disabled: !_isTestingFinished,
                        onTap: _isTestingFinished
                            ? () => setState(
                                () => _activeTab = ProctorViewTab.itemAnalysis,
                              )
                            : () {},
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── 15-MINUTE ENTRANCE WINDOW NOTICE ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.clockAlert,
                  size: 17,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '15-Minute Entrance Window: ${_formatTime(_scheduleDate)} – ${_formatTime(_lateCutoff)}. '
                    'Students arriving past this window are automatically locked out unless manually allowed by instructor.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E40AF),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 4 STAT METRIC BADGES ──
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _metricBadge(
                label: 'Active Learners',
                value: '$activeCount',
                color: AppTheme.catBlue,
              ),
              _metricBadge(
                label: 'Completed',
                value: '$completedCount',
                color: AppTheme.catGreen,
              ),
              _metricBadge(
                label: 'Flagged / Violations',
                value: '$violationsCount',
                color: Colors.orange.shade700,
              ),
              _metricBadge(
                label: 'Late / Locked',
                value: '$lockedLateCount',
                color: AppTheme.catRed,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── ACTIVE TAB CONTENT ──
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_activeTab == ProctorViewTab.liveMonitor)
            ProctoringRosterTable(
              students: _rosterStudents,
              searchQuery: _searchQuery,
              onSearchChanged: (q) => setState(() => _searchQuery = q),
              onReset: _handleResetStudent,
              onForceSubmit: _handleForceSubmit,
              onToggleAllow: _handleToggleAllow,
            )
          else
            _buildItemAnalysisView(theme, isDark),
        ],
      ),
    );
  }

  Widget _buildViewSegment({
    required String label,
    required IconData icon,
    required bool selected,
    bool disabled = false,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? theme.colorScheme.primary : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected && !isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: disabled
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                  : selected
                      ? (isDark ? Colors.white : theme.colorScheme.onSurface)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: disabled
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                    : selected
                        ? (isDark ? Colors.white : theme.colorScheme.onSurface)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricBadge({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      width: 175,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemAnalysisView(ThemeData theme, bool isDark) {
    final totalItems = _itemStats.length;
    final avgP = totalItems > 0
        ? (_itemStats.fold<double>(0.0, (sum, s) => sum + s.pIndex) /
                totalItems) *
            100
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Total Items: $totalItems',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Mean Accuracy: ${avgP.toStringAsFixed(1)}%',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Release Answer Key to Students',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _resultsReleased,
                    onChanged: (_) => _toggleResultsReleased(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_itemStats.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text(
                  'No item analysis responses recorded yet.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _itemStats.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final stat = _itemStats[idx];
                final classification = stat.classification;
                Color badgeColor;
                switch (classification) {
                  case 'Very Easy':
                    badgeColor = Colors.blue;
                  case 'Easy':
                    badgeColor = const Color(0xFF0F8A48);
                  case 'Moderate / Ideal':
                    badgeColor = Colors.teal;
                  case 'Difficult':
                    badgeColor = Colors.orange;
                  default:
                    badgeColor = Colors.red;
                }

                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor:
                        theme.colorScheme.primary.withValues(alpha: 0.12),
                    child: Text(
                      'Q${stat.itemNumber}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  title: Text(
                    stat.questionText,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${stat.correctCount} of ${stat.totalAttempts} correct (${(stat.pIndex * 100).toStringAsFixed(1)}% accuracy • P = ${stat.pIndex.toStringAsFixed(2)})',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: badgeColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      classification,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: badgeColor,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
