import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:class_realm/core/services/supabase_service.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/item_analysis/item_difficulty_stat.dart';

import '../models/student_live_proctor_state.dart';
import '../services/teacher_proctor_channel_service.dart';

class LiveProctorMonitorModal extends StatefulWidget {
  final String assessmentId;
  final String assessmentTitle;
  final String section;
  final bool isExam;
  final DateTime? scheduleDate;
  final int durationMinutes;

  const LiveProctorMonitorModal({
    super.key,
    required this.assessmentId,
    required this.assessmentTitle,
    required this.section,
    this.isExam = false,
    this.scheduleDate,
    this.durationMinutes = 60,
  });

  static Future<void> show({
    required BuildContext context,
    required String assessmentId,
    required String assessmentTitle,
    required String section,
    bool isExam = false,
    DateTime? scheduleDate,
    int durationMinutes = 60,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => LiveProctorMonitorModal(
        assessmentId: assessmentId,
        assessmentTitle: assessmentTitle,
        section: section,
        isExam: isExam,
        scheduleDate: scheduleDate,
        durationMinutes: durationMinutes,
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
  String _genderFilter = 'all'; // 'all', 'male', 'female'
  bool _soundEnabled = true;
  int _selectedTab = 0; // 0: Live Proctoring, 1: Item Analysis
  StreamSubscription<List<StudentLiveProctorState>>? _channelSub;

  // Item Analysis state
  bool _isLoadingItemAnalysis = false;
  List<ItemDifficultyStat> _itemStats = [];
  bool _resultsReleased = false;

  @override
  void initState() {
    super.initState();
    _channelService = TeacherProctorChannelService(
      assessmentId: widget.assessmentId,
    );
    _initializeRoster();
  }

  bool get _isTestingFinished {
    if (widget.scheduleDate == null) return false;
    final endTime = widget.scheduleDate!.add(
      Duration(minutes: widget.durationMinutes),
    );
    return DateTime.now().isAfter(endTime);
  }

  bool get _isEntranceClosed {
    if (widget.scheduleDate == null) return false;
    final entranceClose = widget.scheduleDate!.add(const Duration(minutes: 15));
    return DateTime.now().isAfter(entranceClose);
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour > 12
        ? local.hour - 12
        : (local.hour == 0 ? 12 : local.hour);
    final min = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$min $period';
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[local.month - 1]} ${local.day}, ${_formatTime(local)}';
  }

  Future<void> _initializeRoster() async {
    try {
      final client = SupabaseService().client;
      Map<String, dynamic>? assessmentRow;
      try {
        assessmentRow = await client
            .from('digital_assessments')
            .select('subject_offering_id, results_released')
            .eq('id', widget.assessmentId)
            .maybeSingle();
      } catch (e) {
        debugPrint('live_proctor_monitor_modal digital_assessments notice: $e');
      }

      final offeringId = assessmentRow?['subject_offering_id']?.toString();
      final totalPoints = 0.0;
      _resultsReleased = assessmentRow?['results_released'] == true;

      var enrollQuery = client
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
          .ilike('status', 'enrolled');

      if (offeringId != null && offeringId.isNotEmpty) {
        enrollQuery = enrollQuery.eq('subject_offering_id', offeringId);
      }

      final enrollData = await enrollQuery;

      // Fetch attempts
      final attemptsData = await client
          .from('assessment_attempts')
          .select('student_id, status, score_earned, current_question_index')
          .eq('assessment_id', widget.assessmentId);
      final attemptsMap = <String, Map<String, dynamic>>{};
      for (final a in (attemptsData as List? ?? [])) {
        final sId = a['student_id']?.toString() ?? '';
        if (sId.isNotEmpty) attemptsMap[sId] = Map<String, dynamic>.from(a);
      }

      // Fetch allow/disallow overrides from anti_cheating_logs
      final logsData = await client
          .from('anti_cheating_logs')
          .select('student_id, event_type, event_at')
          .eq('assessment_id', widget.assessmentId)
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

      final learners = <Map<String, dynamic>>[];

      for (final row in (enrollData as List? ?? [])) {
        final profile = row['student_profiles'] as Map<String, dynamic>? ?? {};
        final sId =
            row['student_id']?.toString() ??
            profile['student_id']?.toString() ??
            '';
        final firstName = profile['first_name']?.toString() ?? '';
        final middleName = profile['middle_name']?.toString() ?? '';
        final lastName = profile['last_name']?.toString() ?? '';
        final mi = middleName.trim().isNotEmpty
            ? '${middleName.trim()[0]}.'
            : '';
        final formattedName = lastName.isNotEmpty
            ? '$lastName, $firstName $mi'.trim()
            : (firstName.isNotEmpty ? firstName : 'Student');
        final lrn = profile['lrn']?.toString() ?? 'N/A';
        final sec =
            profile['department_or_section']?.toString() ?? widget.section;
        final gender = (profile['gender']?.toString() ?? '').toLowerCase();

        final att = attemptsMap[sId];
        final attStatus = att?['status']?.toString();
        final isEntryAllowed = overridesMap[sId] ?? true;

        ProctorSessionStatus status = ProctorSessionStatus.notStarted;
        bool isMissing = false;
        double? score;
        int? qIndex;

        if (attStatus == 'submitted' || attStatus == 'auto_submitted') {
          status = ProctorSessionStatus.submitted;
          score = (att?['score_earned'] as num?)?.toDouble();
        } else if (attStatus == 'in_progress') {
          status = ProctorSessionStatus.inProgress;
          qIndex = (att?['current_question_index'] as num?)?.toInt();
        } else if (attStatus == 'disqualified') {
          status = ProctorSessionStatus.kicked;
        } else {
          if (_isTestingFinished) {
            isMissing = true;
          }
        }

        if (sId.isNotEmpty) {
          learners.add({
            'id': sId,
            'name': formattedName,
            'lrn': lrn,
            'section': sec,
            'gender': gender,
            'last_name': lastName,
            'first_name': firstName,
            'middle_name': middleName,
            'status': status,
            'score': score,
            'total_points': totalPoints,
            'is_entry_allowed': isEntryAllowed,
            'is_missing': isMissing,
            'current_question_number': qIndex != null ? qIndex + 1 : null,
          });
        }
      }

      // Sort learners alphabetically by Last Name, then First Name
      learners.sort((a, b) {
        final lnA = (a['last_name'] as String? ?? '').toLowerCase();
        final lnB = (b['last_name'] as String? ?? '').toLowerCase();
        final cmp = lnA.compareTo(lnB);
        if (cmp != 0) return cmp;
        final fnA = (a['first_name'] as String? ?? '').toLowerCase();
        final fnB = (b['first_name'] as String? ?? '').toLowerCase();
        return fnA.compareTo(fnB);
      });

      _channelService.initializeRoster(learners);
      await _channelService.loadHistoricalViolations();
      _channelService.startListening();
      if (mounted) {
        setState(() {
          _students = _channelService.currentStates;
        });
      }
    } catch (e) {
      debugPrint('Real proctor roster fetch notice: $e');
    }

    _channelSub?.cancel();
    _channelSub = _channelService.studentStatesStream.listen((updated) {
      if (mounted) {
        final prevSevereCount = _students.where((s) => s.isSevere).length;
        final newSevereCount = updated.where((s) => s.isSevere).length;
        if (_soundEnabled && newSevereCount > prevSevereCount) {
          SystemSound.play(SystemSoundType.alert);
        }
        setState(() {
          _students = updated;
        });
      }
    });
  }

  Future<void> _loadItemAnalysisData() async {
    if (_itemStats.isNotEmpty) return;
    setState(() => _isLoadingItemAnalysis = true);
    try {
      final client = SupabaseService().client;
      final questionsResponse = await client
          .from('assessment_questions')
          .select('id, question_text, position')
          .eq('assessment_id', widget.assessmentId)
          .order('position', ascending: true);

      final questionRows = List<Map<String, dynamic>>.from(
        questionsResponse as List? ?? [],
      );

      final attemptsResponse = await client
          .from('assessment_attempts')
          .select('id, status')
          .eq('assessment_id', widget.assessmentId)
          .inFilter('status', ['submitted', 'auto_submitted']);
      final attemptList = List<Map<String, dynamic>>.from(
        attemptsResponse as List? ?? [],
      );
      final totalAttempts = attemptList.length;

      final stats = <ItemDifficultyStat>[];

      if (questionRows.isNotEmpty) {
        final qIds = questionRows.map((q) => q['id'].toString()).toList();
        final responsesData = totalAttempts > 0
            ? await client
                .from('assessment_responses')
                .select('question_id, is_correct')
                .inFilter('question_id', qIds)
            : [];
        final responseList = List<Map<String, dynamic>>.from(
          responsesData as List? ?? [],
        );

        for (int i = 0; i < questionRows.length; i++) {
          final q = questionRows[i];
          final qId = q['id'].toString();
          final qResponses = responseList.where(
            (r) => r['question_id']?.toString() == qId,
          );
          final correctCount = qResponses
              .where((r) => r['is_correct'] == true)
              .length;

          stats.add(
            ItemDifficultyStat(
              itemNumber: (q['position'] as num?)?.toInt() ?? (i + 1),
              questionText:
                  q['question_text']?.toString() ?? 'Question ${i + 1}',
              totalAttempts: totalAttempts,
              correctCount: correctCount,
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _itemStats = stats;
          _isLoadingItemAnalysis = false;
        });
      }
    } catch (e) {
      debugPrint('Item analysis error: $e');
      if (mounted) setState(() => _isLoadingItemAnalysis = false);
    }
  }

  @override
  void dispose() {
    _channelSub?.cancel();
    _channelService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Apply gender filter and search query
    final filtered = _students.where((s) {
      if (_genderFilter != 'all') {
        final g = (s.gender ?? '').toLowerCase();
        if (_genderFilter == 'male' && g != 'male') return false;
        if (_genderFilter == 'female' && g != 'female') return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return s.studentName.toLowerCase().contains(q) ||
            s.lrn.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    // Sort alphabetically by student name [Lastname, Firstname M.I.]
    filtered.sort((a, b) => a.studentName.compareTo(b.studentName));

    final activeCount = _students
        .where((s) => s.status == ProctorSessionStatus.inProgress)
        .length;
    final submittedCount = _students
        .where((s) => s.status == ProctorSessionStatus.submitted)
        .length;
    final flaggedCount = _students.where((s) => s.hasViolations).length;
    final lockedCount = _students.where((s) {
      if (!s.isEntryAllowed) return true;
      if (_isEntranceClosed &&
          s.status == ProctorSessionStatus.notStarted &&
          !s.isEntryAllowed) {
        return true;
      }
      return false;
    }).length;

    final boysCount = _students
        .where((s) => (s.gender ?? '').toLowerCase() == 'male')
        .length;
    final girlsCount = _students
        .where((s) => (s.gender ?? '').toLowerCase() == 'female')
        .length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 980,
        height: 680,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.catPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: AppTheme.catPurple,
                    size: 26,
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
                              'Live Proctoring & Management — ${widget.assessmentTitle}',
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.catGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 6,
                                  color: AppTheme.catGreen,
                                ),
                                SizedBox(width: 5),
                                Text(
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
                        'Section: ${widget.section.isEmpty ? "All Sections" : widget.section} • Real-time student roster, violations & test control',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Sound Alert Toggle
                IconButton(
                  tooltip: _soundEnabled
                      ? 'Proctor Alert Chime: Active'
                      : 'Proctor Alert Chime: Muted',
                  icon: Icon(
                    _soundEnabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    color: _soundEnabled
                        ? AppTheme.catPurple
                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() => _soundEnabled = !_soundEnabled);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            // Segmented Tab Switcher (Live Proctoring vs Item Analysis for Exams)
            if (widget.isExam) ...[
              const SizedBox(height: 12),
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedTab = 0),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _selectedTab == 0
                                ? theme.colorScheme.surface
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: _selectedTab == 0
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 4,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                size: 16,
                                color: _selectedTab == 0
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.6,
                                      ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Live Proctoring Monitor',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedTab == 0
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface.withValues(
                                          alpha: 0.7,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() => _selectedTab = 1);
                          if (_isTestingFinished) {
                            _loadItemAnalysisData();
                          }
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _selectedTab == 1
                                ? theme.colorScheme.surface
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: _selectedTab == 1
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 4,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.analytics_outlined,
                                size: 16,
                                color: _selectedTab == 1
                                    ? AppTheme.catTeal
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.6,
                                      ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Item Analysis (DepEd Tiers)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedTab == 1
                                      ? AppTheme.catTeal
                                      : theme.colorScheme.onSurface.withValues(
                                          alpha: 0.7,
                                        ),
                                ),
                              ),
                              if (!_isTestingFinished) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.lock_outline,
                                  size: 13,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Tab Content
            Expanded(
              child: _selectedTab == 0
                  ? _buildProctoringTab(
                      context,
                      filtered,
                      activeCount,
                      submittedCount,
                      flaggedCount,
                      lockedCount,
                      boysCount,
                      girlsCount,
                    )
                  : _buildItemAnalysisTab(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProctoringTab(
    BuildContext context,
    List<StudentLiveProctorState> filtered,
    int activeCount,
    int submittedCount,
    int flaggedCount,
    int lockedCount,
    int boysCount,
    int girlsCount,
  ) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // 15-Minute Entrance Window Alert Banner
        if (widget.scheduleDate != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.catBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.catBlue.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: AppTheme.catBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '15-Minute Entrance Window: ${_formatTime(widget.scheduleDate!)} – ${_formatTime(widget.scheduleDate!.add(const Duration(minutes: 15)))}. Students arriving past this window are automatically locked out unless manually allowed by instructor.',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.catBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Metric Badges
        Row(
          children: [
            _buildSummaryBadge(
              'Active Learners',
              '$activeCount',
              AppTheme.catBlue,
            ),
            const SizedBox(width: 8),
            _buildSummaryBadge(
              'Completed',
              '$submittedCount',
              AppTheme.catGreen,
            ),
            const SizedBox(width: 8),
            _buildSummaryBadge(
              'Flagged / Violations',
              '$flaggedCount',
              AppTheme.catOrange,
            ),
            const SizedBox(width: 8),
            _buildSummaryBadge(
              'Late / Locked',
              '$lockedCount',
              AppTheme.catRed,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Search & Gender Filters Toolbar
        Row(
          children: [
            Expanded(
              flex: 4,
              child: TextField(
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
            ),
            const SizedBox(width: 10),
            // Gender Filters
            Wrap(
              spacing: 6,
              children: [
                _buildGenderFilterChip('All (${_students.length})', 'all'),
                _buildGenderFilterChip('Boys ($boysCount)', 'male'),
                _buildGenderFilterChip('Girls ($girlsCount)', 'female'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  'STUDENT NAME [LASTNAME, FIRSTNAME, M.I.]',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'STATUS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'VIOLATIONS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'SCORE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'ACTIONS',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Table Body
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                ),
                right: BorderSide(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                ),
                bottom: BorderSide(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(8),
              ),
            ),
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No learners found matching filter',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    ),
                    itemBuilder: (context, index) {
                      final student = filtered[index];
                      return _buildStudentTableRow(context, student);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentTableRow(
    BuildContext context,
    StudentLiveProctorState student,
  ) {
    final theme = Theme.of(context);
    final isLateLock = _isEntranceClosed &&
        student.status == ProctorSessionStatus.notStarted &&
        !student.isEntryAllowed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Column 1: Student Name [Lastname, Firstname, M.I.] + LRN
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.studentName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'LRN: ${student.lrn} • ${(student.gender ?? "N/A").toUpperCase()}',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),

          // Column 2: Status
          Expanded(
            flex: 2,
            child: _buildStatusBadge(student, isLateLock),
          ),

          // Column 3: Violations
          Expanded(
            flex: 2,
            child: student.violationCount > 0
                ? Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: student.isSevere
                            ? AppTheme.catRed
                            : AppTheme.catOrange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${student.violationCount} Infraction${student.violationCount > 1 ? "s" : ""}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: student.isSevere
                              ? AppTheme.catRed
                              : AppTheme.catOrange,
                        ),
                      ),
                    ],
                  )
                : Text(
                    '0',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
          ),

          // Column 4: Score
          Expanded(
            flex: 2,
            child: student.status == ProctorSessionStatus.submitted &&
                    student.score != null
                ? Text(
                    '${student.score!.toInt()} / ${student.totalPoints?.toInt() ?? 0} pts',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.catGreen,
                    ),
                  )
                : Text(
                    '—',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
          ),

          // Column 5: Actions (Reset, Force Submit, Enable/Disable)
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Reset Button
                IconButton(
                  tooltip: 'Reset Attempt (Restart from Q1)',
                  icon: const Icon(
                    Icons.restart_alt_rounded,
                    size: 18,
                    color: AppTheme.catOrange,
                  ),
                  onPressed: () => _confirmResetStudent(student),
                ),

                // Force Auto-Submit Button
                IconButton(
                  tooltip: 'Force Auto-Submit',
                  icon: const Icon(
                    Icons.upload_file_outlined,
                    size: 18,
                    color: AppTheme.catGreen,
                  ),
                  onPressed: () => _confirmForceSubmit(student),
                ),

                // Allow / Disallow Button
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    side: BorderSide(
                      color: (student.isEntryAllowed && !isLateLock)
                          ? theme.colorScheme.outline.withValues(alpha: 0.3)
                          : AppTheme.catGreen,
                    ),
                    foregroundColor: (student.isEntryAllowed && !isLateLock)
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
                        : AppTheme.catGreen,
                  ),
                  onPressed: () {
                    _channelService.toggleAllowStudent(
                      student.studentId,
                      !student.isEntryAllowed,
                    );
                    setState(() {});
                  },
                  child: Text(
                    (student.isEntryAllowed && !isLateLock)
                        ? 'Disallow'
                        : 'Allow Entry',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(
    StudentLiveProctorState student,
    bool isLateLock,
  ) {
    if (student.isMissing) {
      return _statusChip('Missing', AppTheme.catRed, Icons.close);
    }
    if (!student.isEntryAllowed || isLateLock) {
      return _statusChip('Not Allowed (Late)', AppTheme.catRed, Icons.lock_outline);
    }
    if (student.status == ProctorSessionStatus.inProgress) {
      final qNum = student.currentQuestionNumber;
      final label = qNum != null ? 'In Progress • Q$qNum' : 'In Progress';
      return _statusChip(label, AppTheme.catBlue, Icons.play_arrow_rounded);
    }
    if (student.status == ProctorSessionStatus.submitted) {
      return _statusChip('Completed', AppTheme.catGreen, Icons.check_circle_outline);
    }
    if (student.status == ProctorSessionStatus.kicked) {
      return _statusChip('Disqualified', AppTheme.catRed, Icons.gavel_rounded);
    }
    return _statusChip('Pending', Colors.grey, Icons.hourglass_empty_rounded);
  }

  Widget _statusChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmResetStudent(StudentLiveProctorState student) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.restart_alt_rounded, color: AppTheme.catOrange),
            SizedBox(width: 8),
            Text(
              'Reset Test Attempt',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to reset the attempt for ${student.studentName}?\n\nThis will wipe their recorded responses and restart them from Question 1. If they are currently active, their screen will reset immediately. Other learners will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.catOrange,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _channelService.authorizeRetake(
                student.studentId,
                reason: 'Instructor reset attempt',
              );
            },
            child: const Text('Reset Attempt'),
          ),
        ],
      ),
    );
  }

  void _confirmForceSubmit(StudentLiveProctorState student) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.upload_file_outlined, color: AppTheme.catGreen),
            SizedBox(width: 8),
            Text(
              'Force Auto-Submit',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to force auto-submit for ${student.studentName}?\n\nThis will immediately finalize and grade their answers. Other learners will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.catGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _channelService.forceSubmitStudent(
                student.studentId,
                reason: 'Instructor forced submission',
              );
            },
            child: const Text('Force Submit'),
          ),
        ],
      ),
    );
  }

  Widget _buildItemAnalysisTab(BuildContext context) {
    final theme = Theme.of(context);

    if (!_isTestingFinished) {
      final endTime = widget.scheduleDate != null
          ? widget.scheduleDate!.add(Duration(minutes: widget.durationMinutes))
          : DateTime.now();

      return Center(
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.catPurple.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_clock_outlined,
                  size: 40,
                  color: AppTheme.catPurple,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Item Analysis Locked',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Under DepEd assessment standards, Item Analysis and difficulty index computation are finalized after the testing window concludes to ensure sample integrity.\n\nTesting Window Closes: ${_formatDateTime(endTime)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => setState(() => _selectedTab = 0),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Return to Live Proctoring'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoadingItemAnalysis) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_itemStats.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.analytics_outlined, size: 40, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'No response data available for item analysis',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _loadItemAnalysisData,
              child: const Text('Reload Stats'),
            ),
          ],
        ),
      );
    }

    final meanAccuracy = _itemStats.isEmpty
        ? 0.0
        : _itemStats
                .map((e) => e.pIndex)
                .reduce((a, b) => a + b) /
            _itemStats.length;

    return Column(
      children: [
        // Summary & Release Answer Key Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildMetricPill('Total Items', '${_itemStats.length}'),
                  const SizedBox(width: 8),
                  _buildMetricPill(
                    'Mean Accuracy',
                    '${(meanAccuracy * 100).toStringAsFixed(1)}%',
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    'Release Answer Key to Students',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _resultsReleased,
                    activeThumbColor: AppTheme.catGreen,
                    onChanged: (val) async {
                      try {
                        await SupabaseService().client
                            .from('digital_assessments')
                            .update({'results_released': val})
                            .eq('id', widget.assessmentId);
                        setState(() => _resultsReleased = val);
                      } catch (_) {}
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // DepEd Tiers List
        Expanded(
          child: ListView.separated(
            itemCount: _itemStats.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = _itemStats[index];
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: theme.colorScheme.primary.withValues(
                        alpha: 0.1,
                      ),
                      child: Text(
                        'Q${item.itemNumber}',
                        style: TextStyle(
                          fontSize: 10,
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
                          Text(
                            item.questionText,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.correctCount} of ${item.totalAttempts} correct (${(item.pIndex * 100).toStringAsFixed(1)}% accuracy • P = ${item.pIndex.toStringAsFixed(2)})',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _badgeColor(item.classification).withValues(
                          alpha: 0.1,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _badgeColor(item.classification).withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      child: Text(
                        item.classification,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _badgeColor(item.classification),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _badgeColor(String classification) {
    switch (classification) {
      case 'Very Easy':
        return Colors.blue;
      case 'Easy':
        return AppTheme.catGreen;
      case 'Moderate / Ideal':
        return AppTheme.catTeal;
      case 'Difficult':
        return AppTheme.catOrange;
      default:
        return AppTheme.catRed;
    }
  }

  Widget _buildMetricPill(String label, String value) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderFilterChip(String label, String value) {
    final isSelected = _genderFilter == value;
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected
            ? Colors.white
            : theme.colorScheme.onSurface.withValues(alpha: 0.7),
      ),
      selected: isSelected,
      selectedColor: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      onSelected: (_) => setState(() => _genderFilter = value),
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
