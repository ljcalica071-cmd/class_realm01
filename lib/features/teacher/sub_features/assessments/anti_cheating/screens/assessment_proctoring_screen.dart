import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:class_realm/core/services/supabase_service.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/supabase_student_repository.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/anti_cheating/models/student_live_proctor_state.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/anti_cheating/services/teacher_proctor_channel_service.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/anti_cheating/widgets/proctoring_roster_table.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/item_analysis/item_difficulty_stat.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/features/teacher/sub_features/grading/widgets/teacher_gradebook_tab.dart';
import 'package:class_realm/widgets/common/app_date_picker_field.dart';
import 'package:class_realm/widgets/common/app_time_picker_field.dart';
import 'package:class_realm/shared/widgets/app_top_toast.dart';
import 'package:class_realm/shared/widgets/shimmer_loading.dart';

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
    extends State<AssessmentProctoringScreen>
    with SingleTickerProviderStateMixin {
  late final TeacherProctorChannelService _proctorService;
  StreamSubscription<List<StudentLiveProctorState>>? _proctorSub;
  late final TabController _tabController;
  ProctorViewTab _activeTab = ProctorViewTab.liveMonitor;
  String _searchQuery = '';
  bool _isLoading = true;
  bool _resultsReleased = false;

  List<StudentLiveProctorState> _rosterStudents = [];
  List<ItemDifficultyStat> _itemStats = [];

  Timer? _lateCheckTimer;
  Timer? _liveProctorAutoSyncTimer;
  bool _isSyncingLearners = false;
  DateTime? _overrideScheduleDate;

  DateTime get _scheduleDate => _overrideScheduleDate ?? widget.assessment.scheduleDate;
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

    _tabController = TabController(
      length: widget.assessment.isExam ? 2 : 1,
      vsync: this,
    );
    _tabController.addListener(() {
      if (!mounted) return;
      final hasSubmitted = _rosterStudents.any(
        (s) => s.status == ProctorSessionStatus.submitted,
      );
      if (_tabController.index == 1 && !_isTestingFinished && !hasSubmitted) {
        _tabController.index = 0;
        AppTopToast.warning(
          context,
          'Item Analysis unlocks once learners submit or after the examination window ends.',
        );
      } else {
        setState(() {
          _activeTab = _tabController.index == 0
              ? ProctorViewTab.liveMonitor
              : ProctorViewTab.itemAnalysis;
        });
        if (_activeTab == ProctorViewTab.itemAnalysis) {
          _loadItemAnalysis();
        }
      }
    });

    _proctorService = TeacherProctorChannelService(
      assessmentId: widget.assessment.id,
    );

    _proctorService.startListening();

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
              score: live.score,
              clearScore: live.score == null && live.status == ProctorSessionStatus.retakeRequested,
              totalPoints: live.totalPoints ?? st.totalPoints,
              isEntryAllowed: live.isEntryAllowed,
              isMissing: live.isMissing,
              currentQuestionNumber:
                  live.currentQuestionNumber ?? st.currentQuestionNumber,
            );
          }
          return st;
        }).toList();
      });
    });

    TeacherGradebookTab.classworkSyncNotifier.addListener(_onGradebookSynced);
    TeacherGradebookTab.gradebookRefreshNotifier.addListener(_onGradebookSynced);

    _loadLearners();
    if (widget.assessment.isExam) {
      _loadItemAnalysis();
    }

    _lateCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _evaluateLateWindowStatus();
    });

    // Auto-sync live learners, active violations & attempts every 4 seconds in the background
    _liveProctorAutoSyncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        _loadLearners(silent: true);
      }
    });
  }

  void _onGradebookSynced() {
    if (!mounted) return;
    _loadLearners(silent: true);
    if (widget.assessment.isExam) {
      _loadItemAnalysis();
    }
  }

  @override
  void dispose() {
    TeacherGradebookTab.classworkSyncNotifier.removeListener(_onGradebookSynced);
    TeacherGradebookTab.gradebookRefreshNotifier.removeListener(_onGradebookSynced);
    _tabController.dispose();
    _lateCheckTimer?.cancel();
    _liveProctorAutoSyncTimer?.cancel();
    _proctorSub?.cancel();
    _proctorService.dispose();
    super.dispose();
  }

  Future<void> _loadLearners({bool silent = false}) async {
    if (_isSyncingLearners) return;
    _isSyncingLearners = true;
    if (!silent && _rosterStudents.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final client = SupabaseService().client;

      // 1. Fetch digital assessment metadata safely (omitting total_points which does not exist on digital_assessments)
      Map<String, dynamic>? assessmentRow;
      try {
        assessmentRow = await client
            .from('digital_assessments')
            .select(
              'subject_offering_id, results_released, available_from, assessment_type, grading_category',
            )
            .eq('id', widget.assessment.id)
            .maybeSingle();
      } catch (e) {
        debugPrint('digital_assessments metadata notice: $e');
      }

      final availStr = assessmentRow?['available_from']?.toString();
      if (availStr != null) {
        final parsed = DateTime.tryParse(availStr);
        if (parsed != null && _overrideScheduleDate == null) {
          _overrideScheduleDate = parsed.toLocal();
        }
      }

      String? offeringId = assessmentRow?['subject_offering_id']?.toString() ??
          widget.assessment.subjectOfferingId;
      final totalPoints = widget.assessment.totalPoints;
      _resultsReleased = assessmentRow?['results_released'] == true;

      // 1b. Fetch classwork_items metadata for gradebook column & term sync
      Map<String, dynamic>? cwRow;
      try {
        cwRow = await client
            .from('classwork_items')
            .select(
              'subject_offering_id, term_number, gradebook_column_index, grading_category',
            )
            .eq('id', widget.assessment.id)
            .maybeSingle();
        offeringId ??= cwRow?['subject_offering_id']?.toString();
      } catch (e) {
        debugPrint('classwork_items metadata notice: $e');
      }

      // 1c. If offeringId is still null/empty, find offering by section name & subject
      if (offeringId == null || offeringId.isEmpty) {
        try {
          final cleanSec =
              widget.assessment.section.replaceAll('Section', '').trim();
          final offRes = await client
              .from('subject_offerings')
              .select('''
                id,
                sections!inner ( section_name ),
                subjects!inner ( subject_name )
              ''');
          for (final off in (offRes as List? ?? [])) {
            final secMap = off['sections'] as Map<String, dynamic>? ?? {};
            final subMap = off['subjects'] as Map<String, dynamic>? ?? {};
            final sName = subMap['subject_name']?.toString() ?? '';
            final secName = secMap['section_name']?.toString() ?? '';
            final matchesSec = secName.toLowerCase().contains(cleanSec.toLowerCase()) ||
                secName.toLowerCase().contains(widget.assessment.section.toLowerCase());
            final matchesSub = widget.assessment.subject.isEmpty ||
                sName.toLowerCase() == widget.assessment.subject.toLowerCase();
            if (matchesSec && matchesSub) {
              offeringId = off['id']?.toString();
              break;
            }
          }
          if (offeringId == null && (offRes as List? ?? []).isNotEmpty) {
            for (final off in (offRes as List)) {
              final secMap = off['sections'] as Map<String, dynamic>? ?? {};
              final secName = secMap['section_name']?.toString() ?? '';
              if (secName.toLowerCase().contains(cleanSec.toLowerCase())) {
                offeringId = off['id']?.toString();
                break;
              }
            }
          }
        } catch (e) {
          debugPrint('Notice finding offering by section: $e');
        }
      }

      // 2. Fetch enrollment with multi-tier fallback so all students in this section appear
      List<dynamic> enrollData = [];

      // Tier 1: Query student_enrollments by offeringId
      if (offeringId != null && offeringId.isNotEmpty) {
        try {
          final res = await client
              .from('student_enrollments')
              .select('''
                id,
                student_id,
                status,
                student_profiles (
                  student_id,
                  lrn,
                  first_name,
                  middle_name,
                  last_name,
                  gender
                )
              ''')
              .eq('subject_offering_id', offeringId);
          enrollData = res as List<dynamic>? ?? [];
        } catch (e) {
          debugPrint('Tier 1 enrollment query notice: $e');
        }
      }

      // Tier 2: Query student_enrollments for all offerings matching this section name
      if (enrollData.isEmpty && widget.assessment.section.isNotEmpty) {
        try {
          final cleanSec =
              widget.assessment.section.replaceAll('Section', '').trim();
          final secRows = await client
              .from('sections')
              .select('id, section_name')
              .or('section_name.ilike.%${widget.assessment.section}%,section_name.ilike.%$cleanSec%');
          final secIds = (secRows as List? ?? [])
              .map((s) => s['id']?.toString())
              .whereType<String>()
              .toList();

          if (secIds.isNotEmpty) {
            final offRes = await client
                .from('subject_offerings')
                .select('id')
                .inFilter('section_id', secIds);
            final offIds = (offRes as List? ?? [])
                .map((o) => o['id']?.toString())
                .whereType<String>()
                .toList();

            if (offIds.isNotEmpty) {
              final secEnroll = await client
                  .from('student_enrollments')
                  .select('''
                    id,
                    student_id,
                    status,
                    student_profiles (
                      student_id,
                      lrn,
                      first_name,
                      middle_name,
                      last_name,
                      gender
                    )
                  ''')
                  .inFilter('subject_offering_id', offIds);
              enrollData = secEnroll as List<dynamic>? ?? [];
            }
          }
        } catch (e) {
          debugPrint('Tier 2 section enrollment query notice: $e');
        }
      }

      // Tier 3: Query teacher's enrolled students matching this section
      if (enrollData.isEmpty) {
        try {
          final teacherId = AuthRepository.instance.currentUser?.id;
          if (teacherId != null) {
            final teacherStudents = await SupabaseStudentRepository()
                .getStudentsForTeacher(teacherId);
            final cleanSec = widget.assessment.section
                .replaceAll('Section', '')
                .trim()
                .toLowerCase();
            final matched = teacherStudents.where((st) {
              final sSec =
                  (st.departmentOrSection ?? '').trim().toLowerCase();
              return sSec.isEmpty ||
                  sSec.contains(widget.assessment.section.toLowerCase()) ||
                  sSec.contains(cleanSec);
            }).toList();

            final targetList = matched.isNotEmpty ? matched : teacherStudents;
            for (final st in targetList) {
              enrollData.add({
                'student_id': st.id,
                'student_profiles': {
                  'student_id': st.id,
                  'first_name': st.firstName,
                  'middle_name': st.middleName,
                  'last_name': st.lastName,
                  'lrn': st.lrn,
                  'gender': st.gender,
                },
              });
            }
          }
        } catch (e) {
          debugPrint('Tier 3 teacher students fallback notice: $e');
        }
      }

      // Tier 4: Universal fallback - query student_profiles directly
      if (enrollData.isEmpty) {
        try {
          final allProfiles = await client
              .from('student_profiles')
              .select('student_id, lrn, first_name, middle_name, last_name, gender')
              .order('last_name', ascending: true);
          for (final p in (allProfiles as List? ?? [])) {
            enrollData.add({
              'student_id': p['student_id'],
              'student_profiles': p,
            });
          }
        } catch (e) {
          debugPrint('Tier 4 profiles fallback notice: $e');
        }
      }

      // Deduplicate enrollData by student_id
      final seenStudentIds = <String>{};
      final uniqueEnrollData = <Map<String, dynamic>>[];
      for (final row in enrollData) {
        final profileRaw = row['student_profiles'];
        final Map<String, dynamic> profile;
        if (profileRaw is Map<String, dynamic>) {
          profile = profileRaw;
        } else if (profileRaw is Map) {
          profile = Map<String, dynamic>.from(profileRaw);
        } else if (profileRaw is List && profileRaw.isNotEmpty && profileRaw.first is Map) {
          profile = Map<String, dynamic>.from(profileRaw.first as Map);
        } else {
          profile = {};
        }

        final sId = row['student_id']?.toString() ??
            profile['student_id']?.toString() ??
            '';
        if (sId.isNotEmpty && seenStudentIds.add(sId)) {
          uniqueEnrollData.add({
            'student_id': sId,
            'student_profiles': profile,
          });
        }
      }

      // 3. Fetch existing attempts safely (using real columns of assessment_attempts)
      final attemptsMap = <String, Map<String, dynamic>>{};
      try {
        final attemptsData = await client
            .from('assessment_attempts')
            .select(
              'id, student_id, status, score_earned, started_at, submitted_at',
            )
            .eq('assessment_id', widget.assessment.id);
        for (final a in (attemptsData as List? ?? [])) {
          final sId = a['student_id']?.toString() ?? '';
          if (sId.isNotEmpty) attemptsMap[sId] = Map<String, dynamic>.from(a);
        }
      } catch (attErr) {
        debugPrint('attempts query notice: $attErr');
      }

      // 3b. Fetch scores from student_classwork_submissions (Gradebook / Classwork sync)
      final submissionsMap = <String, Map<String, dynamic>>{};
      try {
        final subsData = await client
            .from('student_classwork_submissions')
            .select('student_id, status, score, submitted_at')
            .eq('classwork_id', widget.assessment.id);
        for (final s in (subsData as List? ?? [])) {
          final sId = s['student_id']?.toString() ?? '';
          if (sId.isNotEmpty) {
            submissionsMap[sId] = Map<String, dynamic>.from(s);
          }
        }
      } catch (subErr) {
        debugPrint('submissions query notice: $subErr');
      }

      // 3c. Fetch scores from gradebook_term_sheets (Single Source of Truth when teacher edits Gradebook)
      final gradebookScoresMap = <String, double>{};
      try {
        final termNum =
            (cwRow?['term_number'] as num?)?.toInt() ??
            widget.assessment.termNumber;
        final assessType =
            assessmentRow?['assessment_type']?.toString().toLowerCase() ??
            widget.assessment.examType;
        final colIdx =
            (cwRow?['gradebook_column_index'] as num?)?.toInt() ??
            widget.assessment.gradebookColumnIndex ??
            (assessType == 'st1'
                ? 1
                : (assessType == 'st2'
                      ? 2
                      : (assessType == 'term_exam' ? 3 : null)));
        final catKey =
            cwRow?['grading_category']?.toString().toLowerCase() ??
            assessmentRow?['grading_category']?.toString().toLowerCase() ??
            (widget.assessment.isExam ? 'ex' : 'ww');

        if (offeringId != null && offeringId.isNotEmpty && colIdx != null) {
          final sheet = await SubjectRepository.instance.getGradebookTermSheet(
            offeringId,
            termNum,
          );
          if (sheet != null && sheet['scores'] is Map) {
            final scoresMap = sheet['scores'] as Map;
            final colKey = catKey == 'ex'
                ? (colIdx == 1 ? 'st1' : (colIdx == 2 ? 'st2' : 'te'))
                : colIdx.toString();
            for (final entry in scoresMap.entries) {
              final sId = entry.key.toString();
              final sVal = entry.value;
              if (sVal is Map && sVal[catKey] is Map) {
                final catScores = sVal[catKey] as Map;
                final rawScore = catScores[colKey] ?? catScores[colIdx.toString()];
                if (rawScore is num) {
                  gradebookScoresMap[sId] = rawScore.toDouble();
                }
              }
            }
          }
        }
      } catch (gbErr) {
        debugPrint('gradebook sheet score query notice: $gbErr');
      }

      // 4. Fetch allow/disallow overrides from anti_cheating_logs safely
      final overridesMap = <String, bool>{};
      try {
        final logsData = await client
            .from('anti_cheating_logs')
            .select('student_id, event_type, event_at')
            .eq('assessment_id', widget.assessment.id)
            .inFilter('event_type', ['entry_allowed', 'entry_disallowed'])
            .order('event_at', ascending: true);
        for (final l in (logsData as List? ?? [])) {
          final sId = l['student_id']?.toString() ?? '';
          final ev = l['event_type']?.toString() ?? '';
          if (sId.isNotEmpty) {
            overridesMap[sId] = ev == 'entry_allowed';
          }
        }
      } catch (logErr) {
        debugPrint('logs query notice: $logErr');
      }

      final pastLateCutoff = _isPastLateCutoff;
      final parsedList = <StudentLiveProctorState>[];

      for (final row in uniqueEnrollData) {
        final profile =
            row['student_profiles'] as Map<String, dynamic>? ?? {};
        final sId = row['student_id']?.toString() ?? '';
        final firstName = profile['first_name']?.toString() ?? '';
        final middleName = profile['middle_name']?.toString() ?? '';
        final lastName = profile['last_name']?.toString() ?? '';
        final lrn = profile['lrn']?.toString() ?? '';
        final gender = profile['gender']?.toString() ?? '';
        final fullName =
            [firstName, middleName, lastName].where((s) => s.isNotEmpty).join(' ');

        final attempt = attemptsMap[sId];
        final sub = submissionsMap[sId];
        final gbScore = gradebookScoresMap[sId];

        final rawStatus = (attempt?['status']?.toString() ?? '').toLowerCase();
        final subStatus = (sub?['status']?.toString() ?? '').toLowerCase();

        double? score = (attempt?['score_earned'] as num?)?.toDouble() ??
            (sub?['score'] as num?)?.toDouble() ??
            gbScore;
        if (gbScore != null) {
          // Gradebook is the Single Source of Truth if teacher edited the score
          score = gbScore;
        }

        final isCompletedInDb = rawStatus == 'submitted' ||
            rawStatus == 'auto_submitted' ||
            subStatus == 'submitted' ||
            subStatus == 'graded' ||
            gbScore != null;
        final isInProgressInDb = rawStatus == 'in_progress' && !isCompletedInDb;
        final isDisqualifiedInDb = rawStatus == 'disqualified';

        final hasStarted = isInProgressInDb || isCompletedInDb || isDisqualifiedInDb;
        final isMissing = pastLateCutoff && !hasStarted;

        // Entry allowed check: default false if past 15m and never started, unless overridden
        bool isAllowed;
        if (overridesMap.containsKey(sId)) {
          isAllowed = overridesMap[sId]!;
        } else {
          isAllowed = !pastLateCutoff || hasStarted;
        }

        ProctorSessionStatus status;
        if (isDisqualifiedInDb) {
          status = ProctorSessionStatus.kicked;
        } else if (isCompletedInDb) {
          status = ProctorSessionStatus.submitted;
        } else if (isInProgressInDb) {
          status = ProctorSessionStatus.inProgress;
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
            isMissing: isMissing && !isAllowed,
            lastName: lastName,
            firstName: firstName,
            middleName: middleName,
          ),
        );
      }

      // Sort alphabetically by last name, then first name
      parsedList.sort((a, b) {
        final aLast = (a.lastName ?? a.studentName).trim().toLowerCase();
        final bLast = (b.lastName ?? b.studentName).trim().toLowerCase();
        final lnCmp = aLast.compareTo(bLast);
        if (lnCmp != 0) return lnCmp;
        final aFirst = (a.firstName ?? '').trim().toLowerCase();
        final bFirst = (b.firstName ?? '').trim().toLowerCase();
        return aFirst.compareTo(bFirst);
      });

      // Synchronize live proctor service roster first
      _proctorService.initializeRoster(parsedList.map((s) => {
        'id': s.studentId,
        'name': s.studentName,
        'lrn': s.lrn,
        'section': s.section,
        'status': s.status,
        'violation_count': s.violationCount,
        'gender': s.gender,
        'last_name': s.lastName,
        'first_name': s.firstName,
        'middle_name': s.middleName,
        'score': s.score,
        'total_points': s.totalPoints,
        'is_entry_allowed': s.isEntryAllowed,
        'is_missing': s.isMissing,
        'current_question_number': s.currentQuestionNumber,
      }).toList());

      // Load historical violations & session events AFTER roster is initialized so all logs match studentIds!
      await _proctorService.loadHistoricalViolations();

      // Merge updated states from proctor service
      if (_proctorService.currentStates.isNotEmpty) {
        final liveMap = {
          for (final s in _proctorService.currentStates) s.studentId: s,
        };
        for (int i = 0; i < parsedList.length; i++) {
          final live = liveMap[parsedList[i].studentId];
          if (live != null) {
            parsedList[i] = parsedList[i].copyWith(
              status: live.status,
              violationCount: live.violationCount,
              violations: live.violations,
              score: parsedList[i].score ?? live.score,
              totalPoints: live.totalPoints ?? parsedList[i].totalPoints,
              isEntryAllowed: live.isEntryAllowed,
              currentQuestionNumber:
                  live.currentQuestionNumber ?? parsedList[i].currentQuestionNumber,
              isMissing: live.status == ProctorSessionStatus.notStarted &&
                  pastLateCutoff &&
                  !live.isEntryAllowed,
            );
          }
        }
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
    } finally {
      _isSyncingLearners = false;
    }
  }

  void _evaluateLateWindowStatus() {
    final pastLate = _isPastLateCutoff;
    if (!pastLate) {
      setState(() {
        _rosterStudents = _rosterStudents.map((s) {
          if (s.status == ProctorSessionStatus.notStarted && s.isMissing) {
            return s.copyWith(isMissing: false);
          }
          return s;
        }).toList();
      });
      return;
    }

    setState(() {
      _rosterStudents = _rosterStudents.map((s) {
        if (s.status == ProctorSessionStatus.notStarted) {
          return s.copyWith(isMissing: !s.isEntryAllowed);
        }
        return s.copyWith(isMissing: false);
      }).toList();
    });
  }

  Future<void> _loadItemAnalysis() async {
    try {
      final client = SupabaseService().client;
      // 1. Query assessment_questions using real 'position' column (fallback to widget.assessment.questions)
      List<Map<String, dynamic>> questions = [];
      try {
        final questionsRes = await client
            .from('assessment_questions')
            .select('id, question_text, position, points')
            .eq('assessment_id', widget.assessment.id)
            .order('position', ascending: true);
        questions = List<Map<String, dynamic>>.from(questionsRes as List? ?? []);
      } catch (qErr) {
        debugPrint('assessment_questions query notice: $qErr');
      }

      if (questions.isEmpty && widget.assessment.questions.isNotEmpty) {
        for (int i = 0; i < widget.assessment.questions.length; i++) {
          final q = widget.assessment.questions[i];
          questions.add({
            'id': q.id,
            'question_text': q.questionText,
            'position': i + 1,
            'points': q.points,
          });
        }
      }

      // 2. Query assessment_attempts for this assessment to get attempt IDs, then query assessment_responses
      List<Map<String, dynamic>> responses = [];
      try {
        final attemptsRes = await client
            .from('assessment_attempts')
            .select('id, status')
            .eq('assessment_id', widget.assessment.id);
        final attemptIds = (attemptsRes as List? ?? [])
            .where((a) {
              final st = a['status']?.toString().toLowerCase() ?? '';
              return st == 'submitted' || st == 'auto_submitted';
            })
            .map((a) => a['id']?.toString())
            .whereType<String>()
            .toList();

        if (attemptIds.isNotEmpty) {
          final responsesRes = await client
              .from('assessment_responses')
              .select('question_id, is_correct, attempt_id')
              .inFilter('attempt_id', attemptIds);
          responses = List<Map<String, dynamic>>.from(responsesRes as List? ?? []);
        } else if (questions.isNotEmpty) {
          final qIds = questions
              .map((q) => q['id']?.toString())
              .whereType<String>()
              .toList();
          if (qIds.isNotEmpty) {
            final responsesRes = await client
                .from('assessment_responses')
                .select('question_id, is_correct, attempt_id')
                .inFilter('question_id', qIds);
            responses = List<Map<String, dynamic>>.from(responsesRes as List? ?? []);
          }
        }
      } catch (rErr) {
        debugPrint('assessment_responses query notice: $rErr');
      }

      final statsList = <ItemDifficultyStat>[];
      for (int i = 0; i < questions.length; i++) {
        final q = questions[i];
        final qId = q['id']?.toString();
        final itemResponses =
            responses.where((r) => r['question_id']?.toString() == qId).toList();
        final total = itemResponses.length;
        final correct =
            itemResponses.where((r) => r['is_correct'] == true).length;

        statsList.add(
          ItemDifficultyStat(
            itemNumber: i + 1,
            questionText: q['question_text']?.toString() ?? 'Question ${i + 1}',
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
        AppTopToast.info(
          context,
          'Progress reset for ${student.studentName}',
          icon: LucideIcons.rotateCcw,
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
        AppTopToast.info(
          context,
          'Submitted assessment for ${student.studentName}',
          icon: LucideIcons.send,
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
      if (newAllowed) {
        AppTopToast.success(
          context,
          'Access unlocked for ${student.studentName}',
          icon: LucideIcons.unlock,
        );
      } else {
        AppTopToast.error(
          context,
          'Access locked for ${student.studentName}',
          icon: LucideIcons.lock,
        );
      }
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
        if (newStatus) {
          AppTopToast.success(
            context,
            'Answer key released to learners',
            icon: LucideIcons.checkCheck,
          );
        } else {
          AppTopToast.info(
            context,
            'Answer key hidden from learners',
            icon: LucideIcons.eyeOff,
          );
        }
      }
    } catch (_) {}
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour =
        date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _formatDateOnly(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${_formatTime(date)}';
  }

  Future<void> _showUpdateScheduleDialog() async {
    DateTime selectedDate = _scheduleDate;
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(_scheduleDate);
    final initialSchedule = _scheduleDate;
    String? validationError;
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final candidate = DateTime(
              selectedDate.year,
              selectedDate.month,
              selectedDate.day,
              selectedTime.hour,
              selectedTime.minute,
            );
            final isPast = candidate.isBefore(now.subtract(const Duration(minutes: 1)));
            final isUnchanged = selectedDate.year == initialSchedule.year &&
                selectedDate.month == initialSchedule.month &&
                selectedDate.day == initialSchedule.day &&
                selectedTime.hour == initialSchedule.hour &&
                selectedTime.minute == initialSchedule.minute;
            final isSelectedToday = selectedDate.year == today.year &&
                selectedDate.month == today.month &&
                selectedDate.day == today.day;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Icon(
                      LucideIcons.calendarClock,
                      size: 20,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Update Exam Schedule',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Adjust the scheduled start time for this examination. Entrance window and late cut-offs will automatically synchronize.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 14),

                    // Current Schedule Banner
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
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
                            Icons.schedule,
                            size: 16,
                            color: Color(0xFF0F8A48),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Current Schedule: ${_formatDate(_scheduleDate)} ${_formatTime(_scheduleDate)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F8A48),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Date Picker Tile
                    const Text(
                      'Update Schedule Date *',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: isSaving
                          ? null
                          : () async {
                              final picked = await showAppDatePickerDialog(
                                dialogCtx,
                                initialDate: selectedDate,
                                firstDate: today,
                                lastDate: DateTime(today.year + 5, 12, 31),
                                title: 'Update Schedule',
                                icon: Icons.calendar_month_outlined,
                                highlightDate: _scheduleDate,
                                highlightLabel: 'Current Schedule',
                              );
                              if (picked != null && dialogCtx.mounted) {
                                setModalState(() {
                                  selectedDate = picked;
                                  validationError = null;
                                });
                              }
                            },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              LucideIcons.calendar,
                              size: 16,
                              color: Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _formatDate(selectedDate),
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.arrow_drop_down,
                              color: Color(0xFF64748B),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Time Picker (AppTimePickerField with presets and minTime)
                    AppTimePickerField(
                      key: ValueKey(
                        '${selectedDate.year}-${selectedDate.month}-${selectedDate.day}-${selectedTime.hour}-${selectedTime.minute}',
                      ),
                      label: 'Start Time *',
                      initialTime: selectedTime,
                      minTime: isSelectedToday
                          ? TimeOfDay.fromDateTime(
                              now.add(const Duration(minutes: 1)),
                            )
                          : null,
                      onTimeSelected: (picked) {
                        setModalState(() {
                          selectedTime = picked;
                          validationError = null;
                        });
                      },
                    ),

                    if (isPast) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              LucideIcons.circleAlert,
                              size: 15,
                              color: Color(0xFFDC2626),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Scheduled time cannot be in the past.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF991B1B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isUnchanged) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Select a different date or time to update the schedule.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],

                    if (validationError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        validationError!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: (isSaving || isPast || isUnchanged)
                      ? null
                      : () async {
                          setModalState(() {
                            isSaving = true;
                            validationError = null;
                          });

                          try {
                            final client = SupabaseService().client;
                            final candidateUtc = candidate.toUtc().toIso8601String();
                            final durationMinutes = widget.assessment.durationMinutes > 0
                                ? widget.assessment.durationMinutes
                                : 60;
                            final deadlineUtc = candidate
                                .add(Duration(minutes: durationMinutes))
                                .toUtc()
                                .toIso8601String();

                            // 1. Update digital_assessments
                            await client
                                .from('digital_assessments')
                                .update({
                                  'available_from': candidateUtc,
                                  'deadline': deadlineUtc,
                                })
                                .eq('id', widget.assessment.id);

                            // 2. Also update classwork_items if linked
                            try {
                              await client
                                  .from('classwork_items')
                                  .update({
                                    'assigned_at': candidateUtc,
                                    'deadline': deadlineUtc,
                                  })
                                  .eq('id', widget.assessment.id);
                            } catch (cwErr) {
                              debugPrint('classwork_items update non-fatal: $cwErr');
                            }

                            // 3. Invalidate caches across the app
                            AppDataCache.instance.invalidatePrefix('teacher_assessments_');
                            AppDataCache.instance.invalidatePrefix('teacher_activities_');
                            AppDataCache.instance.invalidatePrefix('student_dashboard_');
                            AppDataCache.instance.invalidatePrefix('gradebook_');
                            TeacherGradebookTab.gradebookRefreshNotifier.value++;

                            if (mounted) {
                              setState(() {
                                _overrideScheduleDate = candidate;
                              });
                              _evaluateLateWindowStatus();
                            }

                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }

                            if (mounted) {
                              AppTopToast.success(
                                this.context,
                                'Schedule updated to ${_formatDateTime(candidate)}.',
                              );
                            }
                          } catch (e) {
                            setModalState(() {
                              isSaving = false;
                              validationError = 'Failed to update schedule: $e';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Update Schedule',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
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
            ],
          ),
          const SizedBox(height: 16),

          // ── SLIDING TAB BAR (Written Works / PT / Exam style) ──
          if (widget.assessment.isExam) ...[
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurface.withValues(
                  alpha: 0.6,
                ),
                indicatorColor: theme.colorScheme.primary,
                indicatorWeight: 3,
                tabs: [
                  const Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.shieldCheck, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Live Proctoring Monitor',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          (_isTestingFinished || completedCount > 0)
                              ? LucideIcons.barChart2
                              : LucideIcons.lock,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Item Analysis (DepEd Tiers)',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
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

          // ── 4 STAT METRIC CARDS (Standardized Clean 60-30-10 Style) ──
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 700;

              final cardActive = _buildMetricCard(
                context: context,
                label: 'Active Learners',
                value: '$activeCount',
                icon: LucideIcons.users,
                accentColor: const Color(0xFF2563EB),
                subtitle: 'Real-time test takers',
                onTap: () => setState(() => _searchQuery = ''),
              );

              final cardCompleted = _buildMetricCard(
                context: context,
                label: 'Completed',
                value: '$completedCount',
                icon: LucideIcons.checkCircle,
                accentColor: const Color(0xFF059669),
                subtitle: 'Submitted & graded',
              );

              final cardViolations = _buildMetricCard(
                context: context,
                label: 'Flagged / Violations',
                value: '$violationsCount',
                icon: LucideIcons.alertTriangle,
                accentColor: const Color(0xFFD97706),
                subtitle: 'Integrity & switch alerts',
              );

              final cardLocked = _buildMetricCard(
                context: context,
                label: 'Late / Locked',
                value: '$lockedLateCount',
                icon: LucideIcons.lock,
                accentColor: const Color(0xFFDC2626),
                subtitle: 'Beyond 15-min window',
              );

              if (isNarrow) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: cardActive),
                        const SizedBox(width: 10),
                        Expanded(child: cardCompleted),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: cardViolations),
                        const SizedBox(width: 10),
                        Expanded(child: cardLocked),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: cardActive),
                  const SizedBox(width: 12),
                  Expanded(child: cardCompleted),
                  const SizedBox(width: 12),
                  Expanded(child: cardViolations),
                  const SizedBox(width: 12),
                  Expanded(child: cardLocked),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // ── ACTIVE TAB CONTENT ──
          if (_isLoading)
            _buildProctoringSkeleton(theme, isDark)
          else if (_activeTab == ProctorViewTab.liveMonitor)
            ProctoringRosterTable(
              students: _rosterStudents,
              searchQuery: _searchQuery,
              onSearchChanged: (q) => setState(() => _searchQuery = q),
              onReset: _handleResetStudent,
              onForceSubmit: _handleForceSubmit,
              onToggleAllow: _handleToggleAllow,
              isScheduleExpired: _isTestingFinished,
              onUpdateSchedule: _showUpdateScheduleDialog,
              scheduleDateFormatted: _formatDateOnly(_scheduleDate),
              onRefresh: () async {
                await _loadLearners(silent: true);
                if (widget.assessment.isExam) {
                  await _loadItemAnalysis();
                }
              },
            )
          else
            _buildItemAnalysisView(theme, isDark),
        ],
      ),
    );
  }

  Widget _buildProctoringSkeleton(ThemeData theme, bool isDark) {
    final borderColor = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.12)
        : const Color(0xFFE2E8F0);
    return ShimmerLoading(
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            // Toolbar skeleton
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerBox(width: 280, height: 32, borderRadius: 8),
                  Row(
                    children: [
                      ShimmerBox(width: 220, height: 34, borderRadius: 8),
                      SizedBox(width: 10),
                      ShimmerBox(width: 210, height: 34, borderRadius: 8),
                      SizedBox(width: 8),
                      ShimmerBox(width: 88, height: 34, borderRadius: 8),
                    ],
                  ),
                ],
              ),
            ),
            // Table header skeleton
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: const Row(
                children: [
                  ShimmerBox(width: 24, height: 14, borderRadius: 4),
                  SizedBox(width: 20),
                  Expanded(
                    flex: 3,
                    child: ShimmerBox(height: 14, borderRadius: 4),
                  ),
                  SizedBox(width: 20),
                  Expanded(
                    flex: 2,
                    child: ShimmerBox(height: 14, borderRadius: 4),
                  ),
                  SizedBox(width: 20),
                  Expanded(
                    flex: 2,
                    child: ShimmerBox(height: 14, borderRadius: 4),
                  ),
                  SizedBox(width: 20),
                  Expanded(
                    flex: 2,
                    child: ShimmerBox(height: 14, borderRadius: 4),
                  ),
                  SizedBox(width: 20),
                  Expanded(
                    flex: 3,
                    child: ShimmerBox(height: 14, borderRadius: 4),
                  ),
                ],
              ),
            ),
            // 7 Row skeletons
            for (int i = 0; i < 7; i++)
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: const Row(
                  children: [
                    ShimmerBox(width: 24, height: 14, borderRadius: 4),
                    SizedBox(width: 20),
                    Expanded(
                      flex: 3,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 160, height: 13, borderRadius: 4),
                          SizedBox(height: 5),
                          ShimmerBox(width: 110, height: 10, borderRadius: 4),
                        ],
                      ),
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: ShimmerBox(width: 76, height: 22, borderRadius: 6),
                      ),
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: ShimmerBox(width: 32, height: 18, borderRadius: 4),
                      ),
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: ShimmerBox(width: 64, height: 16, borderRadius: 4),
                      ),
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      flex: 3,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ShimmerBox(width: 28, height: 28, borderRadius: 6),
                          SizedBox(width: 6),
                          ShimmerBox(width: 28, height: 28, borderRadius: 6),
                          SizedBox(width: 8),
                          ShimmerBox(width: 92, height: 28, borderRadius: 6),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color accentColor,
    required String subtitle,
    VoidCallback? onTap,
    bool isSelected = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
        : Colors.white;
    final cardBorder = isSelected
        ? theme.colorScheme.primary
        : (isDark
            ? theme.colorScheme.outline.withValues(alpha: 0.2)
            : const Color(0xFFE2E8F0));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cardBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: !isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Title + Icon Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.8)
                          : const Color(0xFF475569),
                    ),
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      size: 16,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Middle Row: Value
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            // Bottom Row: Helper Subtitle
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
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

    final headerBg = isDark
        ? theme.colorScheme.primary.withValues(alpha: 0.14)
        : theme.colorScheme.primary.withValues(alpha: 0.08);
    final headerBorder = theme.colorScheme.primary.withValues(alpha: 0.25);
    final rowBorder = theme.colorScheme.onSurface.withValues(
      alpha: isDark ? 0.1 : 0.07,
    );

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Control Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
            ),
            // Item Analysis Table with Permanent Column Headers (Edge-to-Edge)
            LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth;
                final tableWidth = availableWidth > 860 ? availableWidth : 860.0;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Permanent Header Row
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: headerBg,
                        border: Border(
                          top: BorderSide(color: headerBorder),
                          bottom: BorderSide(color: headerBorder),
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildAnalysisHeaderCell(
                            theme: theme,
                            width: 44,
                            label: '#',
                            alignment: Alignment.center,
                          ),
                          Expanded(
                            child: _buildAnalysisHeaderCell(
                              theme: theme,
                              label: 'QUESTION STATEMENT',
                            ),
                          ),
                          _buildAnalysisHeaderCell(
                            theme: theme,
                            width: 160,
                            label: 'CORRECT / ATTEMPTS',
                            alignment: Alignment.center,
                          ),
                          _buildAnalysisHeaderCell(
                            theme: theme,
                            width: 160,
                            label: 'ACCURACY (P-INDEX)',
                            alignment: Alignment.center,
                          ),
                          _buildAnalysisHeaderCell(
                            theme: theme,
                            width: 170,
                            label: 'DEPED DIFFICULTY TIER',
                            alignment: Alignment.center,
                            hasRightBorder: false,
                          ),
                        ],
                      ),
                    ),
                    // Rows or Polished Full-Width Empty Row
                    if (_itemStats.isEmpty)
                      Container(
                        width: tableWidth,
                        padding: const EdgeInsets.symmetric(
                          vertical: 48,
                          horizontal: 24,
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: isDark ? 0.14 : 0.08,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  LucideIcons.barChart3,
                                  size: 26,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'No Item Analysis Responses Recorded Yet',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 440),
                              child: Text(
                                'Individual question difficulty (P-Index) and DepEd tiers will populate automatically as learners submit their responses.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _itemStats.length,
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
                            case 'Pending Submissions':
                              badgeColor = AppTheme.catSlate;
                            default:
                              badgeColor = Colors.red;
                          }

                          final rowBg = idx.isOdd
                              ? (isDark
                                  ? theme.colorScheme.onSurface.withValues(alpha: 0.03)
                                  : theme.colorScheme.primary.withValues(alpha: 0.025))
                              : theme.colorScheme.surface;

                          return Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: rowBg,
                              border: Border(bottom: BorderSide(color: rowBorder)),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 44,
                                  child: Center(
                                    child: Text(
                                      '${stat.itemNumber}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(
                                      stat.questionText,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 160,
                                  child: Center(
                                    child: Text(
                                      stat.totalAttempts > 0
                                          ? '${stat.correctCount} / ${stat.totalAttempts} correct'
                                          : '0 / 0 attempts',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface.withValues(
                                          alpha: stat.totalAttempts > 0 ? 0.8 : 0.45,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 160,
                                  child: Center(
                                    child: Text(
                                      stat.totalAttempts > 0
                                          ? '${(stat.pIndex * 100).toStringAsFixed(1)}% (P = ${stat.pIndex.toStringAsFixed(2)})'
                                          : '—',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: stat.totalAttempts > 0
                                            ? theme.colorScheme.onSurface
                                            : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 170,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
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
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    ),
  ),
);
  }

  Widget _buildAnalysisHeaderCell({
    required ThemeData theme,
    double? width,
    required String label,
    Alignment alignment = Alignment.centerLeft,
    bool hasRightBorder = true,
  }) {
    final cell = Container(
      height: double.infinity,
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: alignment,
      decoration: BoxDecoration(
        border: hasRightBorder
            ? Border(
                right: BorderSide(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                ),
              )
            : null,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );

    return width != null ? cell : Expanded(child: cell);
  }
}
