import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/core/services/supabase_service.dart';
import 'package:class_realm/core/utils/browser_url_helper.dart';
import 'package:class_realm/routes/app_routes.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/data/repositories/teacher_classwork_repository.dart';
import 'package:class_realm/features/teacher/sub_features/grading/widgets/teacher_gradebook_tab.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/widgets/common/app_date_picker_field.dart';
import 'package:class_realm/widgets/common/app_time_picker_field.dart';
import 'package:class_realm/widgets/common/expandable_instructions_text.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/screens/create_assessment_flow.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/screens/create_requirement_flow.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/screens/edit_assessment_flow.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/anti_cheating/anti_cheating.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class TeacherUnifiedAssessmentsTab extends StatefulWidget {
  final List<ActivityModel> activities;
  final List<QuizOrExamModel> assessments;
  final String selectedClassSection;
  final ValueChanged<ActivityModel>? onViewSubmissions;
  final TeacherClassworkRepository? repository;
  final FutureOr<void> Function()? onRefresh;
  final bool isLoading;

  const TeacherUnifiedAssessmentsTab({
    super.key,
    required this.activities,
    required this.assessments,
    this.selectedClassSection = 'All Sections',
    this.onViewSubmissions,
    this.repository,
    this.onRefresh,
    this.isLoading = false,
  });

  @override
  State<TeacherUnifiedAssessmentsTab> createState() =>
      _TeacherUnifiedAssessmentsTabState();
}

class _TeacherUnifiedAssessmentsTabState
    extends State<TeacherUnifiedAssessmentsTab>
    with SingleTickerProviderStateMixin {
  int? _selectedGrade;
  String? _selectedSubject;
  String? _selectedClassSection;
  List<Map<String, dynamic>> _teacherSubjects = [];
  bool _isLoadingSubjects = true;
  bool _isSyncing = false;
  QuizOrExamModel? _monitoringAssessment;
  late final TabController _categoryTabController;
  Timer? _creationCooldownTimer;

  @override
  void initState() {
    super.initState();
    final navState = LocalStorageService.getTeacherClassworkNavState();
    final rawCurrentPath = AppRoutes.normalizeRoutePath(getBrowserUrlPath());
    final savedRoute = AppRoutes.normalizeRoutePath(
      LocalStorageService.getLastActiveRoute() ?? '',
    );
    final currentPath =
        (rawCurrentPath == '/' || rawCurrentPath == AppRoutes.teacherClasswork) &&
                AppRoutes.isTeacherClassworkSubViewRoute(savedRoute)
            ? savedRoute
            : rawCurrentPath;
    final pathTabIdx = AppRoutes.teacherClassworkTabIndexForRoute(currentPath);
    final initialTabIdx =
        (pathTabIdx ?? (navState['categoryTabIndex'] as num?)?.toInt() ?? 0)
            .clamp(0, 2);
    _categoryTabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: initialTabIdx,
    );
    _categoryTabController.addListener(() {
      if (_categoryTabController.indexIsChanging) return;
      final idx = _categoryTabController.index;
      LocalStorageService.saveTeacherClassworkNavState(categoryTabIndex: idx);
      if (_monitoringAssessment == null) {
        final cleanRoute = AppRoutes.teacherClassworkRouteForTabIndex(idx);
        updateBrowserUrl(cleanRoute);
        LocalStorageService.saveLastActiveRoute(cleanRoute);
      }
    });
    if (!AppRoutes.isTeacherClassworkProctoringRoute(currentPath) &&
        !AppRoutes.isTeacherClassworkItemAnalysisRoute(currentPath)) {
      LocalStorageService.clearTeacherClassworkSubView();
      final cleanRoute = AppRoutes.teacherClassworkRouteForTabIndex(
        initialTabIdx,
      );
      updateBrowserUrl(cleanRoute);
      LocalStorageService.saveLastActiveRoute(cleanRoute);
    }
    _hydrateInitialFilterFromStorage();
    _loadTeacherSections();
    _tryRestoreMonitoringAssessment(fromInit: true);
    if (CreateAssessmentFlowDialog.creationCooldown.isActive) {
      _startCreationCooldownTimer();
    }
  }

  @override
  void didUpdateWidget(covariant TeacherUnifiedAssessmentsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final rawCurrentPath = AppRoutes.normalizeRoutePath(getBrowserUrlPath());
    final savedRoute = AppRoutes.normalizeRoutePath(
      LocalStorageService.getLastActiveRoute() ?? '',
    );
    final currentPath =
        (rawCurrentPath == '/' || rawCurrentPath == AppRoutes.teacherClasswork) &&
                AppRoutes.isTeacherClassworkSubViewRoute(savedRoute)
            ? savedRoute
            : rawCurrentPath;
    if (_monitoringAssessment != null &&
        !AppRoutes.isTeacherClassworkProctoringRoute(currentPath) &&
        !AppRoutes.isTeacherClassworkItemAnalysisRoute(currentPath)) {
      _monitoringAssessment = null;
      final targetTab =
          AppRoutes.teacherClassworkTabIndexForRoute(currentPath) ?? 0;
      if (_categoryTabController.index != targetTab) {
        _categoryTabController.index = targetTab;
      }
    } else if (_monitoringAssessment == null && widget.assessments.isNotEmpty) {
      _tryRestoreMonitoringAssessment(fromInit: true);
    } else if (_monitoringAssessment != null && widget.assessments.isNotEmpty) {
      for (final a in widget.assessments) {
        if (a.id == _monitoringAssessment!.id &&
            a.completionMode != 'in_person') {
          _monitoringAssessment = a;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _creationCooldownTimer?.cancel();
    _categoryTabController.dispose();
    super.dispose();
  }

  void _startCreationCooldownTimer() {
    _creationCooldownTimer?.cancel();
    if (!CreateAssessmentFlowDialog.creationCooldown.isActive) return;
    _creationCooldownTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      if (!mounted || !CreateAssessmentFlowDialog.creationCooldown.isActive) {
        timer.cancel();
        _creationCooldownTimer = null;
      }
      if (mounted) setState(() {});
    });
  }

  Future<void> _openCreateAssessmentFlow({required bool isExam}) async {
    final sectionParam = _selectedClassSection ?? '';
    final offeringMatch = _teacherSubjects.firstWhere(
      (s) =>
          (_selectedSubject == null || s['subject_name'] == _selectedSubject) &&
          (_selectedClassSection == null ||
              s['section_name'] == _selectedClassSection),
      orElse: () => _teacherSubjects.isNotEmpty
          ? _teacherSubjects.first
          : <String, dynamic>{},
    );
    await CreateAssessmentFlowDialog.show(
      context,
      initialSection: sectionParam,
      initialSubject: _selectedSubject,
      initialOfferingId: offeringMatch['id']?.toString(),
      initialOfferings: _teacherSubjects,
      initialIsExam: isExam,
      skipTypeSelection: true,
      repository: widget.repository,
      onAssessmentCreated: () async {
        _startCreationCooldownTimer();
        await widget.onRefresh?.call();
        if (mounted) setState(() {});
      },
    );
    if (mounted && CreateAssessmentFlowDialog.creationCooldown.isActive) {
      _startCreationCooldownTimer();
      setState(() {});
    }
  }

  Widget _buildAssessmentCreateButton({
    required String baseLabel,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final remaining =
        CreateAssessmentFlowDialog.creationCooldown.remainingSeconds;
    final inCooldown = remaining > 0;

    return Tooltip(
      message: inCooldown
          ? 'Cooldown active: Please wait ${remaining}s before creating another quiz or exam.'
          : baseLabel,
      child: AppButton.primary(
        label: inCooldown ? '$baseLabel (${remaining}s)' : baseLabel,
        icon: inCooldown ? Icons.hourglass_bottom_rounded : icon,
        onPressed: inCooldown ? null : onPressed,
        isSmall: true,
      ),
    );
  }

  void _tryRestoreMonitoringAssessment({bool fromInit = false}) {
    final rawCurrentPath = AppRoutes.normalizeRoutePath(getBrowserUrlPath());
    final savedRoute = AppRoutes.normalizeRoutePath(
      LocalStorageService.getLastActiveRoute() ?? '',
    );
    final currentPath =
        (rawCurrentPath == '/' || rawCurrentPath == AppRoutes.teacherClasswork) &&
                AppRoutes.isTeacherClassworkSubViewRoute(savedRoute)
            ? savedRoute
            : rawCurrentPath;
    if (!AppRoutes.isTeacherClassworkProctoringRoute(currentPath) &&
        !AppRoutes.isTeacherClassworkItemAnalysisRoute(currentPath)) {
      LocalStorageService.clearTeacherClassworkSubView();
      return;
    }
    final navState = LocalStorageService.getTeacherClassworkNavState();
    final savedAssessId = navState['activeAssessmentId']?.toString();
    if (savedAssessId == null || savedAssessId.isEmpty) return;
    for (final a in widget.assessments) {
      if (a.id == savedAssessId && a.completionMode != 'in_person') {
        if (fromInit) {
          _monitoringAssessment = a;
        } else if (mounted) {
          setState(() => _monitoringAssessment = a);
        }
        return;
      }
    }
    if (_monitoringAssessment == null) {
      final rawJson = navState['activeAssessmentJson'];
      if (rawJson is Map) {
        try {
          final restored = QuizOrExamModel.fromJson(
            Map<String, dynamic>.from(rawJson),
          );
          if (restored.id == savedAssessId &&
              restored.completionMode != 'in_person') {
            if (fromInit) {
              _monitoringAssessment = restored;
            } else if (mounted) {
              setState(() => _monitoringAssessment = restored);
            }
          }
        } catch (_) {}
      }
    }
  }

  int _parseGrade(dynamic g) {
    if (g is int) return g;
    return int.tryParse(g?.toString() ?? '') ?? 11;
  }

  String _formatSectionName(dynamic raw) {
    if (raw == null) return 'Section';
    final clean = raw.toString().trim();
    if (clean.isEmpty) return 'Section';
    if (clean.toLowerCase().startsWith('section')) {
      return clean[0].toUpperCase() + clean.substring(1);
    }
    return 'Section $clean';
  }

  List<int> get _availableGrades {
    if (_teacherSubjects.isEmpty) return [];
    final set = <int>{};
    for (final s in _teacherSubjects) {
      set.add(_parseGrade(s['grade_level']));
    }
    final list = set.toList()..sort();
    return list;
  }

  List<String> get _availableSubjects {
    if (_teacherSubjects.isEmpty) return [];
    final set = <String>{};
    for (final s in _teacherSubjects) {
      if (_selectedGrade == null ||
          _parseGrade(s['grade_level']) == _selectedGrade) {
        final name = s['subject_name']?.toString().trim();
        if (name != null && name.isNotEmpty) {
          set.add(name);
        }
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  List<String> get _availableSections {
    if (_teacherSubjects.isEmpty) return [];
    final set = <String>{};
    for (final s in _teacherSubjects) {
      final matchesGrade =
          _selectedGrade == null ||
          _parseGrade(s['grade_level']) == _selectedGrade;
      final matchesSubject =
          _selectedSubject == null ||
          (s['subject_name']?.toString().trim() == _selectedSubject);
      if (matchesGrade && matchesSubject) {
        final sec = s['section_name']?.toString().trim();
        if (sec != null && sec.isNotEmpty) {
          set.add(sec);
        }
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  void _hydrateInitialFilterFromStorage() {
    final navState = LocalStorageService.getTeacherClassworkNavState();
    final savedGrade = (navState['gradeLevel'] as num?)?.toInt();
    final savedSubject = navState['subjectName']?.toString();
    final savedSection = navState['sectionName']?.toString();

    if (savedGrade != null) _selectedGrade = savedGrade;
    if (savedSubject != null && savedSubject.isNotEmpty) {
      _selectedSubject = savedSubject;
    }
    if (savedSection != null && savedSection.isNotEmpty) {
      _selectedClassSection = savedSection;
    }
  }

  Future<void> _loadTeacherSections() async {
    try {
      final teacherId = AuthRepository.instance.currentUser?.id;
      if (teacherId == null) {
        if (mounted) setState(() => _isLoadingSubjects = false);
        return;
      }
      final subjects = await SubjectRepository.instance.getTeacherSubjects(
        teacherId,
      );
      if (!mounted) return;
      final navState = LocalStorageService.getTeacherClassworkNavState();
      final savedGrade = (navState['gradeLevel'] as num?)?.toInt();
      final savedSubject = navState['subjectName']?.toString();
      final savedSection = navState['sectionName']?.toString();

      setState(() {
        _teacherSubjects = subjects;
        _isLoadingSubjects = false;

        final grades = _availableGrades;
        if (grades.isNotEmpty) {
          if (savedGrade != null && grades.contains(savedGrade)) {
            _selectedGrade = savedGrade;
          } else {
            _selectedGrade ??= grades.first;
          }
        }

        final subs = _availableSubjects;
        if (subs.isNotEmpty) {
          if (savedSubject != null && subs.contains(savedSubject)) {
            _selectedSubject = savedSubject;
          } else {
            _selectedSubject ??= subs.first;
          }
        }

        final secs = _availableSections;
        if (secs.isNotEmpty) {
          if (savedSection != null && secs.contains(savedSection)) {
            _selectedClassSection = savedSection;
          } else if (widget.selectedClassSection.isNotEmpty &&
              widget.selectedClassSection != 'All Sections' &&
              secs.contains(widget.selectedClassSection)) {
            _selectedClassSection = widget.selectedClassSection;
          } else {
            _selectedClassSection = secs.first;
          }
        }
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingSubjects = false);
    }
  }

  bool get _isCurrentSubjectZeroExam {
    if (_teacherSubjects.isEmpty) return false;
    final match = _teacherSubjects.firstWhere(
      (s) =>
          (_selectedSubject == null || s['subject_name'] == _selectedSubject) &&
          (_selectedClassSection == null ||
              s['section_name'] == _selectedClassSection),
      orElse: () => _teacherSubjects.first,
    );
    final exWeight = (match['ex_weight'] as num?)?.toDouble() ?? 30.0;
    return exWeight == 0.0;
  }

  String _monthName(int month) {
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
    return months[month - 1];
  }

  String _formatTime(DateTime date) {
    final hour = date.hour == 0
        ? 12
        : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  bool _matchesItem(
    String? itemSubject,
    String? itemSection,
    List<String> assignedSections,
  ) {
    // If subjects are still loading and we have no confirmed subject filter, prevent leaking other subjects
    if (_isLoadingSubjects &&
        (_selectedSubject == null || _selectedSubject!.isEmpty)) {
      return false;
    }

    // If user has chosen a section
    if (_selectedClassSection != null && _selectedClassSection!.isNotEmpty) {
      final targetSec = _selectedClassSection!.trim().toLowerCase();
      final sec = itemSection?.trim().toLowerCase();
      final matchesSection =
          (sec != null &&
              (sec == targetSec ||
                  sec.contains(targetSec) ||
                  targetSec.contains(sec))) ||
          assignedSections.any((s) {
            final clean = s.trim().toLowerCase();
            return clean == targetSec ||
                clean.contains(targetSec) ||
                targetSec.contains(clean);
          });
      if (!matchesSection) return false;
    }
    // If user has chosen a subject
    if (_selectedSubject != null && _selectedSubject!.isNotEmpty) {
      final targetSub = _selectedSubject!.trim().toLowerCase();
      final sub = itemSubject?.trim().toLowerCase();
      if (sub == null ||
          (!sub.contains(targetSub) && !targetSub.contains(sub))) {
        return false;
      }
    } else if (_teacherSubjects.isNotEmpty) {
      // If teacher has subjects defined but none is selected yet, do not leak all subjects
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_monitoringAssessment != null) {
      return AssessmentProctoringScreen(
        assessment: _monitoringAssessment!,
        onBack: () {
          LocalStorageService.saveTeacherClassworkNavState(
            clearActiveAssessment: true,
          );
          final cleanRoute = AppRoutes.teacherClassworkRouteForTabIndex(
            _categoryTabController.index,
          );
          updateBrowserUrl(cleanRoute);
          LocalStorageService.saveLastActiveRoute(cleanRoute);
          setState(() => _monitoringAssessment = null);
        },
        onCancelAssessment: () =>
            _confirmCancelAssessment(_monitoringAssessment!),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final writtenWork = <Widget>[
      ...widget.activities
          .where(
            (item) =>
                !item.isRequirement &&
                _matchesItem(item.subject, item.section, item.assignedSections),
          )
          .map((item) => _buildUnifiedActivityCard(item, 'WW')),
      ...widget.assessments
          .where(
            (item) =>
                !item.isExam &&
                _matchesItem(item.subject, item.section, item.assignedSections),
          )
          .map((item) => _buildUnifiedAssessmentCard(item, 'WW')),
    ];
    final performanceTasks = widget.activities
        .where(
          (item) =>
              item.isRequirement &&
              _matchesItem(item.subject, item.section, item.assignedSections),
        )
        .map((item) => _buildUnifiedActivityCard(item, 'PT'))
        .toList();
    final examinations = widget.assessments
        .where(
          (item) =>
              item.isExam &&
              _matchesItem(item.subject, item.section, item.assignedSections),
        )
        .map((item) => _buildUnifiedAssessmentCard(item, 'EX'))
        .toList();

    final availableGrades = _availableGrades;
    final availableSubjects = _availableSubjects;
    final availableSections = _availableSections;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 16,
              runSpacing: 14,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Classwork',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create activities, performance tasks, quizzes, and exams by subject and section.',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Right-aligned Attendance-Style Target Filter Card
                _buildFilterCard(
                  theme: theme,
                  isDark: isDark,
                  availableGrades: availableGrades,
                  availableSubjects: availableSubjects,
                  availableSections: availableSections,
                ),
              ],
            ),
          ),
          if (_isSyncing) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(
                minHeight: 4,
                backgroundColor: Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F8A48)),
              ),
            ),
            const SizedBox(height: 6),
            const Row(
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF0F8A48),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Updating schedule and syncing with gradebook...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F8A48),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
              ),
            ),
            child: TabBar(
              controller: _categoryTabController,
              dividerColor: Colors.transparent,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurface.withValues(
                alpha: 0.6,
              ),
              indicatorColor: theme.colorScheme.primary,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'Written Works (WW)'),
                Tab(text: 'Performance Tasks (PT)'),
                Tab(text: 'Examinations (EX)'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _categoryTabController,
              physics: const BouncingScrollPhysics(),
              children: [
                _KeepAliveTabWrapper(
                  child: _buildUnifiedCategoryView(
                    label: 'Written Works',
                    items: writtenWork,
                    emptyTitle: 'No written works yet',
                    emptyMessage: 'Create assignments, activities, and quizzes for your students.',
                    icon: LucideIcons.fileText,
                    actionButtons: [
                      AppButton.primary(
                        label: 'Create Activity',
                        icon: Icons.assignment_outlined,
                        onPressed: () {
                          final sectionParam = _selectedClassSection ?? '';
                          final offeringMatch = _teacherSubjects.firstWhere(
                            (s) =>
                                (_selectedSubject == null ||
                                    s['subject_name'] == _selectedSubject) &&
                                (_selectedClassSection == null ||
                                    s['section_name'] == _selectedClassSection),
                            orElse: () => _teacherSubjects.isNotEmpty
                                ? _teacherSubjects.first
                                : <String, dynamic>{},
                          );
                          CreateRequirementFlowDialog.show(
                            context,
                            initialSection: sectionParam,
                            initialSubject: _selectedSubject,
                            initialOfferingId: offeringMatch['id']?.toString(),
                            initialOfferings: _teacherSubjects,
                            isPerformanceTask: false,
                            repository: widget.repository,
                            onRequirementCreated: () {
                              widget.onRefresh?.call();
                              setState(() {});
                            },
                          );
                        },
                        isSmall: true,
                      ),
                      _buildAssessmentCreateButton(
                        baseLabel: 'Create Quiz',
                        icon: Icons.quiz_outlined,
                        onPressed: () =>
                            _openCreateAssessmentFlow(isExam: false),
                      ),
                    ],
                  ),
                ),
                _KeepAliveTabWrapper(
                  child: _buildUnifiedCategoryView(
                    label: 'Performance Tasks',
                    items: performanceTasks,
                    emptyTitle: 'No performance tasks yet',
                    emptyMessage: 'Create hands-on tasks, portfolios, and graded projects.',
                    icon: LucideIcons.presentation,
                    actionButtons: [
                      AppButton.primary(
                        label: 'Create Performance Task',
                        icon: Icons.add_task,
                        onPressed: () {
                          final sectionParam = _selectedClassSection ?? '';
                          final offeringMatch = _teacherSubjects.firstWhere(
                            (s) =>
                                (_selectedSubject == null ||
                                    s['subject_name'] == _selectedSubject) &&
                                (_selectedClassSection == null ||
                                    s['section_name'] == _selectedClassSection),
                            orElse: () => _teacherSubjects.isNotEmpty
                                ? _teacherSubjects.first
                                : <String, dynamic>{},
                          );
                          CreateRequirementFlowDialog.show(
                            context,
                            initialSection: sectionParam,
                            initialSubject: _selectedSubject,
                            initialOfferingId: offeringMatch['id']?.toString(),
                            initialOfferings: _teacherSubjects,
                            isPerformanceTask: true,
                            repository: widget.repository,
                            onRequirementCreated: () {
                              widget.onRefresh?.call();
                              setState(() {});
                            },
                          );
                        },
                        isSmall: true,
                      ),
                    ],
                  ),
                ),
                _KeepAliveTabWrapper(
                  child: _buildUnifiedCategoryView(
                    label: 'Examinations',
                    items: examinations,
                    emptyTitle: 'No examinations yet',
                    emptyMessage: _isCurrentSubjectZeroExam
                        ? 'This subject has no Examination component under DepEd Order No. 015, s. 2026. Initial Grades are computed 100% from Written Works and Performance Tasks.'
                        : 'Create Summative Tests (ST1, ST2) and Term Examinations (TE).',
                    icon: LucideIcons.award,
                    isZeroExam: _isCurrentSubjectZeroExam,
                    actionButtons: [
                      _buildAssessmentCreateButton(
                        baseLabel: 'Create Examination',
                        icon: Icons.description_outlined,
                        onPressed: () {
                          if (_isCurrentSubjectZeroExam) {
                            AppTopToast.info(
                              context,
                              'This subject has no Examination component under DepEd Order No. 015, s. 2026.',
                            );
                            return;
                          }
                          _openCreateAssessmentFlow(isExam: true);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard({
    required ThemeData theme,
    required bool isDark,
    required List<int> availableGrades,
    required List<String> availableSubjects,
    required List<String> availableSections,
  }) {
    final borderColor = theme.colorScheme.onSurface.withValues(
      alpha: isDark ? 0.14 : 0.12,
    );

    if (_isLoadingSubjects && _teacherSubjects.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: const ShimmerLoading(
          child: Wrap(
            spacing: 14,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShimmerBox(width: 64, height: 11, borderRadius: 4),
                  SizedBox(height: 4),
                  ShimmerBox(width: 108, height: 38, borderRadius: 8),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShimmerBox(width: 52, height: 11, borderRadius: 4),
                  SizedBox(height: 4),
                  ShimmerBox(width: 180, height: 38, borderRadius: 8),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShimmerBox(width: 52, height: 11, borderRadius: 4),
                  SizedBox(height: 4),
                  ShimmerBox(width: 120, height: 38, borderRadius: 8),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          _buildFilterDropdown(
            label: 'Grade Level',
            icon: LucideIcons.graduationCap,
            value: _selectedGrade?.toString(),
            items: availableGrades.map((g) => g.toString()).toList(),
            itemLabel: (g) => 'Grade $g',
            onChanged: (val) {
              final g = int.tryParse(val ?? '');
              if (g != null) {
                setState(() {
                  _selectedGrade = g;
                  final subs = _availableSubjects;
                  _selectedSubject = subs.isNotEmpty ? subs.first : null;
                  final secs = _availableSections;
                  _selectedClassSection = secs.isNotEmpty ? secs.first : null;
                });
                LocalStorageService.saveTeacherClassworkNavState(
                  gradeLevel: _selectedGrade,
                  subjectName: _selectedSubject,
                  sectionName: _selectedClassSection,
                );
              }
            },
            theme: theme,
            isDark: isDark,
          ),
          _buildFilterDropdown(
            label: 'Subject',
            icon: LucideIcons.bookOpen,
            value: _selectedSubject,
            items: availableSubjects,
            itemLabel: (sub) => sub,
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedSubject = val;
                  final secs = _availableSections;
                  _selectedClassSection = secs.isNotEmpty ? secs.first : null;
                });
                LocalStorageService.saveTeacherClassworkNavState(
                  subjectName: _selectedSubject,
                  sectionName: _selectedClassSection,
                );
              }
            },
            theme: theme,
            isDark: isDark,
          ),
          _buildFilterDropdown(
            label: 'Section',
            icon: LucideIcons.users,
            value: _selectedClassSection,
            items: availableSections,
            itemLabel: _formatSectionName,
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedClassSection = val);
                LocalStorageService.saveTeacherClassworkNavState(
                  sectionName: val,
                );
              }
            },
            theme: theme,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required String Function(String) itemLabel,
    required ThemeData theme,
    required bool isDark,
  }) {
    if (items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.surface.withValues(alpha: 0.5)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(
                  alpha: isDark ? 0.12 : 0.1,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 13.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w500,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  LucideIcons.chevronDown,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final validValue = (value != null && items.contains(value))
        ? value
        : (items.isNotEmpty ? items.first : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 4),
        AppFixedDropdown<String>(
          value: validValue,
          items: items.map((item) {
            return AppDropdownItem<String>(
              value: item,
              label: itemLabel(item),
              icon: Icon(
                icon,
                size: 13.5,
                color: theme.colorScheme.primary,
              ),
            );
          }).toList(),
          onChanged: onChanged,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(
                alpha: isDark ? 0.18 : 0.16,
              ),
            ),
          ),
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
          icon: Icon(
            LucideIcons.chevronDown,
            size: 14,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildUnifiedCategoryView({
    required String label,
    required List<Widget> items,
    required String emptyTitle,
    required String emptyMessage,
    required IconData icon,
    required List<Widget> actionButtons,
    bool isZeroExam = false,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isZeroExam)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.catPurple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.catPurple.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppTheme.catPurple,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DepEd Order No. 015, s. 2026 — Zero-Exam Subject',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.catPurple,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'This subject has no Examination component. Initial Grades are computed 100% from Written Works and Performance Tasks.',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.75,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: actionButtons,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: (widget.isLoading || _isLoadingSubjects) && items.isEmpty
              ? ListView.builder(
                  itemCount: 4,
                  itemBuilder: (_, _) => const ShimmerClassworkCard(),
                )
              : _PaginatedUnifiedItemList(
                  items: items,
                  emptyTitle: emptyTitle,
                  emptyMessage: emptyMessage,
                  icon: icon,
                  pageSize: 5,
                ),
        ),
      ],
    );
  }

  Widget _buildUnifiedActivityCard(ActivityModel item, String category) {
    final dueDate = item.deadlineForSection(_selectedClassSection ?? '');
    final isOnline = item.completionMode == 'online';
    final effectiveInstructions = item.instructions.trim().isNotEmpty
        ? item.instructions.trim()
        : item.description.trim();

    return _buildUnifiedCard(
      title: item.title,
      description: effectiveInstructions,
      category: category,
      details: isOnline
          ? '${item.section} • Term ${item.termNumber} • ${item.maxScore.toInt()} pts • Due ${_monthName(dueDate.month)} ${dueDate.day}, ${_formatTime(dueDate)}'
          : '${item.section} • Term ${item.termNumber} • ${item.maxScore.toInt()} pts • In-Person (${_monthName(dueDate.month)} ${dueDate.day}, ${dueDate.year})',
      icon: Icons.assignment_outlined,
      onPressed: () {
        if (widget.onViewSubmissions != null) {
          widget.onViewSubmissions!(item);
        }
      },
      actionLabel: isOnline ? 'View Submissions' : 'Record Scores',
      onEdit: () => _showEditActivityModal(item),
      onDelete: () => _confirmDeleteActivity(item),
    );
  }

  Widget _buildUnifiedAssessmentCard(QuizOrExamModel item, String category) {
    final isInPerson = item.completionMode == 'in_person';
    final examEndTime = item.scheduleDate.add(
      Duration(minutes: item.durationMinutes),
    );
    final isTestingFinished = DateTime.now().isAfter(examEndTime);

    return _buildUnifiedCard(
      title: item.title,
      description: item.description,
      category: category,
      details: isInPerson
          ? '${item.section} • Term ${item.termNumber} • ${item.totalPoints.toInt()} pts • In-Person (${_monthName(item.scheduleDate.month)} ${item.scheduleDate.day}, ${item.scheduleDate.year})'
          : '${item.section} • Term ${item.termNumber} • ${item.totalPoints.toInt()} pts • Start ${_monthName(item.scheduleDate.month)} ${item.scheduleDate.day}, ${_formatTime(item.scheduleDate)}',
      icon: item.isExam ? Icons.description_outlined : Icons.quiz_outlined,
      resultsReleased: isInPerson ? null : item.resultsReleased,
      onToggleReleaseKey: isInPerson
          ? null
          : () => _toggleResultsReleased(item),
      onPressed: isInPerson
          ? () {
              if (widget.onViewSubmissions != null) {
                widget.onViewSubmissions!(
                  ActivityModel(
                    id: item.id,
                    title: item.title,
                    description: item.description,
                    instructions: item.description,
                    subject: item.subject,
                    section: item.section,
                    deadline: item.scheduleDate,
                    maxScore: item.totalPoints,
                    isPublished: item.isPublished,
                    isRequirement: false,
                    subjectOfferingId: item.subjectOfferingId,
                    termNumber: item.termNumber,
                    gradebookColumnIndex: item.gradebookColumnIndex,
                    completionMode: 'in_person',
                    gradingCategory: item.isExam ? 'ex' : 'ww',
                  ),
                );
              }
            }
          : () {
              LocalStorageService.saveTeacherClassworkNavState(
                categoryTabIndex: item.isExam ? 2 : 0,
                activeAssessmentId: item.id,
                activeAssessmentJson: item.toJson(),
              );
              final proctorRoute = item.isExam
                  ? AppRoutes.teacherClassworkExProctoring
                  : AppRoutes.teacherClassworkWwProctoring;
              updateBrowserUrl(proctorRoute);
              LocalStorageService.saveLastActiveRoute(proctorRoute);
              setState(() => _monitoringAssessment = item);
            },
      actionLabel: isInPerson ? 'Record Scores' : null,
      onEdit: () => EditAssessmentFlowDialog.show(
        context,
        assessment: item,
        onAssessmentUpdated: () async {
          await widget.onRefresh?.call();
          if (mounted) setState(() {});
        },
      ),
      onDelete: () => _confirmDeleteAssessment(item),
      onReschedule: () => _showRescheduleAssessmentDialog(item),
      onCancel: () => _confirmCancelAssessment(item),
      onProctor: null,
      isItemAnalysisLocked: !isTestingFinished,
      onItemAnalysis: isInPerson
          ? null
          : () {
              LocalStorageService.saveTeacherClassworkNavState(
                categoryTabIndex: item.isExam ? 2 : 0,
                activeAssessmentId: item.id,
                activeAssessmentJson: item.toJson(),
              );
              final analysisRoute = item.isExam
                  ? AppRoutes.teacherClassworkExItemAnalysis
                  : AppRoutes.teacherClassworkWwItemAnalysis;
              updateBrowserUrl(analysisRoute);
              LocalStorageService.saveLastActiveRoute(analysisRoute);
              setState(() => _monitoringAssessment = item);
            },
    );
  }

  Future<void> _toggleResultsReleased(QuizOrExamModel item) async {
    final newStatus = !item.resultsReleased;
    try {
      final client = SupabaseService().client;
      await client
          .from('digital_assessments')
          .update({'results_released': newStatus})
          .eq('id', item.id);

      setState(() {
        final index = widget.assessments.indexWhere((a) => a.id == item.id);
        if (index != -1) {
          widget.assessments[index] = item.copyWith(resultsReleased: newStatus);
        }
      });

      if (!mounted) return;
      if (newStatus) {
        AppTopToast.success(
          context,
          'Answer key for "${item.title}" released.',
        );
      } else {
        AppTopToast.info(context, 'Answer key for "${item.title}" hidden.');
      }
    } catch (e) {
      if (mounted) {
        AppModals.showErrorDialog(
          context: context,
          title: 'Update Failed',
          message: 'Failed to update answer key release state: $e',
        );
      }
    }
  }

  Widget _buildUnifiedCard({
    required String title,
    required String description,
    required String category,
    required String details,
    required IconData icon,
    required VoidCallback onPressed,
    String? actionLabel,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    VoidCallback? onReschedule,
    VoidCallback? onCancel,
    VoidCallback? onProctor,
    VoidCallback? onItemAnalysis,
    bool? resultsReleased,
    VoidCallback? onToggleReleaseKey,
    bool isItemAnalysisLocked = false,
  }) {
    final theme = Theme.of(context);
    final isPerformanceTask = category == 'PT';
    final isExam = category == 'EX';
    final typeLabel = isExam
        ? 'Exam'
        : (category == 'WW' ? 'Quiz' : 'Assessment');
    final badgeBackground = isPerformanceTask
        ? AppTheme.catGreen.withValues(alpha: 0.1)
        : isExam
        ? AppTheme.catPurple.withValues(alpha: 0.1)
        : AppTheme.catBlue.withValues(alpha: 0.1);
    final badgeText = isPerformanceTask
        ? AppTheme.catGreen
        : isExam
        ? AppTheme.catPurple
        : AppTheme.catBlue;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 34),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildAssessmentCategoryBadge(
                          category,
                          badgeBackground,
                          badgeText,
                        ),
                        if (resultsReleased != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: resultsReleased
                                  ? AppTheme.catGreen.withValues(alpha: 0.12)
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: 0.08,
                                    ),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: resultsReleased
                                    ? AppTheme.catGreen.withValues(alpha: 0.3)
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.2,
                                      ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  resultsReleased
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  size: 12,
                                  color: resultsReleased
                                      ? AppTheme.catGreen
                                      : theme.colorScheme.onSurface.withValues(
                                          alpha: 0.6,
                                        ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  resultsReleased
                                      ? 'Key Released'
                                      : 'Key Hidden',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: resultsReleased
                                        ? AppTheme.catGreen
                                        : theme.colorScheme.onSurface
                                              .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (description.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      ExpandableInstructionsText(
                        text: description,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      details,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 4,
                children: [
                  if (actionLabel != null && actionLabel.isNotEmpty)
                    AppButton.outline(
                      label: actionLabel,
                      icon: Icons.open_in_new,
                      isSmall: true,
                      onPressed: onPressed,
                    ),
                  if (onToggleReleaseKey != null && resultsReleased != null)
                    IconButton(
                      tooltip: resultsReleased
                          ? 'Answer Key: Released (Visible to students) — Tap to Hide'
                          : 'Answer Key: Hidden from students — Tap to Release',
                      icon: Icon(
                        resultsReleased
                            ? Icons.visibility
                            : Icons.visibility_off_outlined,
                        color: resultsReleased
                            ? AppTheme.catGreen
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                      ),
                      onPressed: onToggleReleaseKey,
                    ),
                  if (onProctor != null)
                    IconButton(
                      tooltip: 'Live Proctoring Monitor',
                      icon: const Icon(
                        Icons.shield_outlined,
                        color: AppTheme.catPurple,
                      ),
                      onPressed: onProctor,
                    ),
                  if (onItemAnalysis != null)
                    IconButton(
                      tooltip: isItemAnalysisLocked
                          ? 'Item Analysis Locked ($typeLabel window active)'
                          : '$typeLabel Item Analysis & DepEd Tiers',
                      icon: Icon(
                        isItemAnalysisLocked
                            ? Icons.lock_clock_outlined
                            : Icons.analytics_outlined,
                        color: isItemAnalysisLocked
                            ? theme.colorScheme.onSurface.withValues(
                                alpha: 0.38,
                              )
                            : AppTheme.catTeal,
                      ),
                      onPressed: isItemAnalysisLocked ? null : onItemAnalysis,
                    ),
                  if (onReschedule != null)
                    IconButton(
                      tooltip: 'Update Schedule',
                      icon: Icon(
                        Icons.schedule,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed: onReschedule,
                    ),
                  if (onEdit != null)
                    IconButton(
                      tooltip: 'Edit',
                      icon: Icon(
                        Icons.edit_outlined,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      onPressed: onEdit,
                    ),
                  if (onCancel != null)
                    IconButton(
                      tooltip: 'Cancel $typeLabel',
                      icon: const Icon(
                        LucideIcons.xCircle,
                        size: 20,
                        color: Color(0xFFD97706),
                      ),
                      onPressed: onCancel,
                    ),
                  if (onDelete != null)
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppTheme.catRed,
                      ),
                      onPressed: onDelete,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssessmentCategoryBadge(
    String label,
    Color backgroundColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _confirmDeleteActivity(ActivityModel item) async {
    bool hasRecords = false;
    try {
      final client = SupabaseService().client;
      // 1. Check student submissions for existing scores or submitted work
      final submissions = await client
          .from('student_classwork_submissions')
          .select('id, score, status')
          .eq('classwork_id', item.id);
      final subList = List<Map<String, dynamic>>.from(
        submissions as List? ?? [],
      );
      for (final s in subList) {
        if (s['score'] != null ||
            s['status'] == 'graded' ||
            s['status'] == 'submitted') {
          hasRecords = true;
          break;
        }
      }

      // 2. Also check Gradebook sheet if subjectOfferingId and gradebookColumnIndex exist
      if (!hasRecords &&
          item.subjectOfferingId != null &&
          item.gradebookColumnIndex != null) {
        final term = item.termNumber > 0 ? item.termNumber : 1;
        final termSheet = await SubjectRepository.instance
            .getGradebookTermSheet(item.subjectOfferingId!, term);
        if (termSheet != null && termSheet['scores'] is Map) {
          final scoresMap = termSheet['scores'] as Map;
          final catKey = item.effectiveGradingCategory;
          final colKey = item.gradebookColumnIndex.toString();
          for (final studentVal in scoresMap.values) {
            if (studentVal is Map && studentVal[catKey] is Map) {
              final catScores = studentVal[catKey] as Map;
              final usesZeroBased =
                  catScores.containsKey('0') || catScores.containsKey(0);
              final targetKey = usesZeroBased
                  ? (item.gradebookColumnIndex! - 1).toString()
                  : colKey;
              if (catScores[targetKey] != null) {
                hasRecords = true;
                break;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Notice checking activity score records: $e');
    }

    if (!mounted) return;

    if (hasRecords) {
      AppModals.showWarningDialog(
        context: context,
        title: 'Cannot Delete Item',
        message: 'This classwork activity already has recorded student scores or submissions. Items with existing student records cannot be deleted.',
      );
      return;
    }

    _showDeleteConfirmation(
      title: item.title,
      onDelete: () async {
        setState(() {
          _isSyncing = true;
          widget.activities.removeWhere((a) => a.id == item.id);
        });
        if (widget.repository != null) {
          try {
            await widget.repository!.deleteActivity(item.id);
          } catch (_) {}
        }
        TeacherGradebookTab.gradebookRefreshNotifier.value++;
        if (mounted) {
          await widget.onRefresh?.call();
          setState(() => _isSyncing = false);
        }
      },
    );
  }

  Future<void> _confirmDeleteAssessment(QuizOrExamModel item) async {
    bool hasRecords = false;
    Map<String, dynamic>? classworkRow;
    try {
      final client = SupabaseService().client;
      // 1. Check assessment_attempts for submitted or scored attempts
      final attempts = await client
          .from('assessment_attempts')
          .select('id, score_earned, status')
          .eq('assessment_id', item.id);
      final attemptList = List<Map<String, dynamic>>.from(
        attempts as List? ?? [],
      );
      for (final a in attemptList) {
        if (a['score_earned'] != null ||
            a['status'] == 'submitted' ||
            a['status'] == 'auto_submitted') {
          hasRecords = true;
          break;
        }
      }

      // 2. Check classwork submissions if item exists in classwork_items
      classworkRow = await client
          .from('classwork_items')
          .select(
            'id, subject_offering_id, term_number, gradebook_column_index, grading_category',
          )
          .eq('id', item.id)
          .maybeSingle();

      if (!hasRecords && classworkRow != null) {
        final subs = await client
            .from('student_classwork_submissions')
            .select('id, score, status')
            .eq('classwork_id', item.id);
        final subList = List<Map<String, dynamic>>.from(subs as List? ?? []);
        for (final s in subList) {
          if (s['score'] != null ||
              s['status'] == 'graded' ||
              s['status'] == 'submitted') {
            hasRecords = true;
            break;
          }
        }
      }

      // 3. Check Gradebook sheet scores as Single Source of Truth
      final offeringId =
          classworkRow?['subject_offering_id']?.toString() ??
          item.subjectOfferingId;
      final termNumber =
          (classworkRow?['term_number'] as num?)?.toInt() ?? item.termNumber;
      final colIdx =
          (classworkRow?['gradebook_column_index'] as num?)?.toInt() ??
          item.gradebookColumnIndex;
      final category =
          classworkRow?['grading_category']?.toString().toLowerCase() ??
          (item.isExam ? 'ex' : 'ww');

      if (!hasRecords && offeringId != null && colIdx != null) {
        final termSheet = await SubjectRepository.instance
            .getGradebookTermSheet(offeringId, termNumber);
        if (termSheet != null && termSheet['scores'] is Map) {
          final scoresMap = termSheet['scores'] as Map;
          final colKey = category == 'ex'
              ? (colIdx == 1 ? 'st1' : (colIdx == 2 ? 'st2' : 'te'))
              : colIdx.toString();
          for (final studentVal in scoresMap.values) {
            if (studentVal is Map && studentVal[category] is Map) {
              final catScores = studentVal[category] as Map;
              final usesZeroBased =
                  catScores.containsKey('0') || catScores.containsKey(0);
              final altKey = usesZeroBased
                  ? (colIdx - 1).toString()
                  : colIdx.toString();
              if (catScores[colKey] != null || catScores[altKey] != null) {
                hasRecords = true;
                break;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Notice checking assessment records: $e');
    }

    if (!mounted) return;

    if (hasRecords) {
      AppModals.showWarningDialog(
        context: context,
        title: 'Cannot Delete ${item.isExam ? 'Examination' : 'Quiz'}',
        message:
            'This ${item.isExam ? 'examination' : 'quiz'} already has recorded student attempts or scores. Items with existing student records cannot be deleted.',
      );
      return;
    }

    _showDeleteConfirmation(
      title: item.title,
      onDelete: () async {
        setState(() => _isSyncing = true);
        try {
          final client = SupabaseService().client;
          // Remove any unsubmitted/abandoned attempt rows first (FK RESTRICT)
          final openAttempts = await client
              .from('assessment_attempts')
              .select('id')
              .eq('assessment_id', item.id);
          final openIds = List<Map<String, dynamic>>.from(
            openAttempts as List? ?? [],
          ).map((e) => e['id'].toString()).toList();
          if (openIds.isNotEmpty) {
            await client
                .from('assessment_responses')
                .delete()
                .inFilter('attempt_id', openIds);
            await client
                .from('assessment_attempts')
                .delete()
                .inFilter('id', openIds);
          }

          await client
              .from('student_classwork_submissions')
              .delete()
              .eq('classwork_id', item.id);

          // Delete questions (cascade cleans up question_options)
          await client
              .from('assessment_questions')
              .delete()
              .eq('assessment_id', item.id);
          // Hard delete from classwork_items
          await client.from('classwork_items').delete().eq('id', item.id);
          // Hard delete from digital_assessments
          await client.from('digital_assessments').delete().eq('id', item.id);

          // Clean up HPS from gradebook_term_sheets
          final offeringId =
              classworkRow?['subject_offering_id']?.toString() ??
              item.subjectOfferingId;
          final colIdx =
              (classworkRow?['gradebook_column_index'] as num?)?.toInt() ??
              item.gradebookColumnIndex;
          final termNum =
              (classworkRow?['term_number'] as num?)?.toInt() ??
              item.termNumber;
          final categoryKey =
              classworkRow?['grading_category']?.toString().toLowerCase() ??
              (item.isExam ? 'ex' : 'ww');

          if (offeringId != null && colIdx != null) {
            final termSheet = await SubjectRepository.instance
                .getGradebookTermSheet(offeringId, termNum);
            if (termSheet != null && termSheet['hps'] is Map) {
              final hps = Map<String, dynamic>.from(termSheet['hps'] as Map);
              if (hps[categoryKey] is Map) {
                final catHps = Map<String, dynamic>.from(
                  hps[categoryKey] as Map,
                );
                final colKey = categoryKey == 'ex'
                    ? (colIdx == 1 ? 'st1' : (colIdx == 2 ? 'st2' : 'te'))
                    : colIdx.toString();
                catHps.remove(colKey);
                if (categoryKey == 'ex') {
                  catHps.remove(colIdx.toString());
                }
                hps[categoryKey] = catHps;
                termSheet['hps'] = hps;
                await SubjectRepository.instance.saveGradebookTermSheet(
                  offeringId,
                  termNum,
                  termSheet,
                );
              }
            }
            try {
              await LocalStorageService.clearGradebookSheet(
                offeringId,
                termNum,
              );
            } catch (_) {}
          }

          // Clear caches & notify gradebook + student portal
          AppDataCache.instance.invalidatePrefix('gradebook_');
          AppDataCache.instance.invalidatePrefix('teacher_assessments_');
          AppDataCache.instance.invalidatePrefix('teacher_activities_');
          AppDataCache.instance.invalidatePrefix('student_dashboard_');
          TeacherGradebookTab.gradebookRefreshNotifier.value++;
        } catch (e) {
          debugPrint('Error deleting assessment: $e');
        }

        if (mounted) {
          setState(() {
            widget.assessments.removeWhere((q) => q.id == item.id);
          });
          await widget.onRefresh?.call();
          setState(() => _isSyncing = false);
        }
      },
    );
  }

  Future<void> _confirmCancelAssessment(QuizOrExamModel item) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.14),
          ),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.catRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                LucideIcons.xCircle,
                color: AppTheme.catRed,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Cancel ${item.isExam ? "Examination" : "Quiz"}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
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
              Text(
                'Are you sure you want to cancel "${item.title}"?',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.catRed.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.catRed.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCancelBullet(
                      theme,
                      'Active student sessions will end immediately.',
                    ),
                    const SizedBox(height: 6),
                    _buildCancelBullet(
                      theme,
                      'Recorded attempts and scores will be voided (no student penalized).',
                    ),
                    const SizedBox(height: 6),
                    _buildCancelBullet(
                      theme,
                      'This ${item.isExam ? "exam" : "quiz"} and its HPS will be removed so you can recreate it anytime.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Assessment'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.catRed,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Yes, Cancel ${item.isExam ? "Exam" : "Quiz"}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _cancelAssessment(item);
    }
  }

  Widget _buildCancelBullet(ThemeData theme, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 5),
          child: Icon(Icons.circle, size: 5, color: AppTheme.catRed),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.82),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _cancelAssessment(QuizOrExamModel item) async {
    setState(() => _isSyncing = true);
    try {
      final client = SupabaseService().client;

      // 1. Fetch classwork_items row to get metadata for Gradebook cleanup
      Map<String, dynamic>? classworkRow;
      try {
        classworkRow = await client
            .from('classwork_items')
            .select(
              'id, subject_offering_id, term_number, gradebook_column_index, grading_category',
            )
            .eq('id', item.id)
            .maybeSingle();
      } catch (e) {
        debugPrint('classwork_items query notice during cancel: $e');
      }

      // 2. Query existing attempts so we can notify active students & delete responses safely
      List<String> attemptIds = [];
      Set<String> distinctStudentIds = {};
      try {
        final attempts = await client
            .from('assessment_attempts')
            .select('id, student_id')
            .eq('assessment_id', item.id);
        for (final raw in (attempts as List? ?? [])) {
          final row = raw as Map<String, dynamic>;
          final aid = row['id']?.toString() ?? '';
          final sid = row['student_id']?.toString() ?? '';
          if (aid.isNotEmpty) attemptIds.add(aid);
          if (sid.isNotEmpty) distinctStudentIds.add(sid);
        }
      } catch (e) {
        debugPrint('assessment_attempts query notice during cancel: $e');
      }

      // 3. Broadcast real-time cancellation to connected students before deleting
      try {
        await client
            .from('digital_assessments')
            .update({'is_published': false, 'is_archived': true})
            .eq('id', item.id);
      } catch (e) {
        debugPrint('digital_assessments cancel broadcast notice: $e');
      }

      if (distinctStudentIds.isNotEmpty) {
        try {
          final nowIso = DateTime.now().toUtc().toIso8601String();
          await client.from('anti_cheating_logs').insert([
            for (final sid in distinctStudentIds)
              {
                'event_type': 'cancelled',
                'details': 'Assessment was cancelled by instructor.',
                'assessment_id': item.id,
                'student_id': sid,
                'event_at': nowIso,
              },
          ]);
        } catch (e) {
          debugPrint('anti_cheating_logs cancel insert notice: $e');
        }
      }

      // 4. Hard-delete assessment records so Gradebook slot & portals are cleaned
      try {
        if (attemptIds.isNotEmpty) {
          await client
              .from('assessment_responses')
              .delete()
              .inFilter('attempt_id', attemptIds);
        }
        await client
            .from('assessment_attempts')
            .delete()
            .eq('assessment_id', item.id);
        await client
            .from('student_classwork_submissions')
            .delete()
            .eq('classwork_id', item.id);
        await client
            .from('assessment_questions')
            .delete()
            .eq('assessment_id', item.id);
        await client.from('classwork_items').delete().eq('id', item.id);
        await client.from('digital_assessments').delete().eq('id', item.id);
      } catch (e) {
        debugPrint('Assessment delete cleanup notice during cancel: $e');
      }

      // 7. Clean up Gradebook: remove column score & HPS so grades recalculate cleanly
      final offeringId =
          classworkRow?['subject_offering_id']?.toString() ??
          item.subjectOfferingId;
      final termNumber =
          (classworkRow?['term_number'] as num?)?.toInt() ?? item.termNumber;
      final colIdx =
          (classworkRow?['gradebook_column_index'] as num?)?.toInt() ??
          item.gradebookColumnIndex;
      final categoryKey =
          classworkRow?['grading_category']?.toString().toLowerCase() ??
          (item.isExam ? 'ex' : 'ww');

      if (offeringId != null && colIdx != null) {
        final termSheet = await SubjectRepository.instance
            .getGradebookTermSheet(offeringId, termNumber);
        if (termSheet != null) {
          bool sheetModified = false;

          // Remove HPS entry
          if (termSheet['hps'] is Map) {
            final hps = Map<String, dynamic>.from(termSheet['hps'] as Map);
            if (hps[categoryKey] is Map) {
              final catHps = Map<String, dynamic>.from(hps[categoryKey] as Map);
              final colKey = categoryKey == 'ex'
                  ? (colIdx == 1 ? 'st1' : (colIdx == 2 ? 'st2' : 'te'))
                  : colIdx.toString();
              catHps.remove(colKey);
              catHps.remove(colIdx.toString());
              hps[categoryKey] = catHps;
              termSheet['hps'] = hps;
              sheetModified = true;
            }
          }

          // Remove student scores for this column
          if (termSheet['scores'] is Map) {
            final scoresMap = Map<String, dynamic>.from(
              termSheet['scores'] as Map,
            );
            final colKey = categoryKey == 'ex'
                ? (colIdx == 1 ? 'st1' : (colIdx == 2 ? 'st2' : 'te'))
                : colIdx.toString();
            final altKey = (colIdx - 1).toString();

            for (final entry in scoresMap.entries) {
              if (entry.value is Map) {
                final studentVal = Map<String, dynamic>.from(
                  entry.value as Map,
                );
                if (studentVal[categoryKey] is Map) {
                  final catScores = Map<String, dynamic>.from(
                    studentVal[categoryKey] as Map,
                  );
                  catScores.remove(colKey);
                  catScores.remove(colIdx.toString());
                  catScores.remove(altKey);
                  studentVal[categoryKey] = catScores;
                  scoresMap[entry.key] = studentVal;
                  sheetModified = true;
                }
              }
            }
            termSheet['scores'] = scoresMap;
          }

          if (sheetModified) {
            await SubjectRepository.instance.saveGradebookTermSheet(
              offeringId,
              termNumber,
              termSheet,
            );
          }
        }
        try {
          await LocalStorageService.clearGradebookSheet(offeringId, termNumber);
        } catch (_) {}
      }

      // 8. Invalidate caches and notify Gradebook and Student portals
      AppDataCache.instance.invalidatePrefix('gradebook_');
      AppDataCache.instance.invalidatePrefix('teacher_assessments_');
      AppDataCache.instance.invalidatePrefix('teacher_activities_');
      AppDataCache.instance.invalidatePrefix('student_dashboard_');
      TeacherGradebookTab.gradebookRefreshNotifier.value++;

      if (_monitoringAssessment?.id == item.id) {
        setState(() => _monitoringAssessment = null);
        LocalStorageService.clearTeacherClassworkSubView();
        final cleanRoute = AppRoutes.teacherClassworkRouteForTabIndex(
          _categoryTabController.index,
        );
        updateBrowserUrl(cleanRoute);
        LocalStorageService.saveLastActiveRoute(cleanRoute);
      }

      if (mounted) {
        setState(() {
          widget.assessments.removeWhere((q) => q.id == item.id);
        });
        await widget.onRefresh?.call();
        if (!mounted) return;
        setState(() => _isSyncing = false);
        AppTopToast.success(
          context,
          '${item.isExam ? "Examination" : "Quiz"} "${item.title}" cancelled.',
        );
      }
    } catch (e) {
      debugPrint('Error cancelling assessment: $e');
      if (mounted) {
        setState(() => _isSyncing = false);
        AppModals.showErrorDialog(
          context: context,
          title: 'Cancellation Failed',
          message: 'An error occurred while cancelling the assessment: $e',
        );
      }
    }
  }

  Future<void> _showRescheduleAssessmentDialog(QuizOrExamModel item) async {
    final isInPerson = item.completionMode == 'in_person';
    final localOrig = item.scheduleDate.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime selectedDate = DateTime(
      localOrig.year,
      localOrig.month,
      localOrig.day,
    );
    if (!isInPerson && selectedDate.isBefore(today)) {
      selectedDate = today;
    }
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(localOrig);
    bool isSavingSchedule = false;

    String? computeTimeError(DateTime date, TimeOfDay time) {
      if (isInPerson) return null;
      final candidate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (!candidate.isAfter(DateTime.now())) {
        return 'Updated schedule must be in the future.';
      }
      return null;
    }

    String? scheduleTimeError;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final theme = Theme.of(modalCtx);
          final candidateCombined = isInPerson
              ? DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  23,
                  59,
                )
              : DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );
          final isUnchanged = isSameClassworkSchedule(
            item.scheduleDate,
            candidateCombined,
            isInPerson: isInPerson,
          );
          final isSelectedToday =
              selectedDate.year == today.year &&
              selectedDate.month == today.month &&
              selectedDate.day == today.day;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.event_repeat,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isInPerson ? 'Update Date' : 'Update Schedule',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isInPerson
                        ? 'Update the scheduled date for "${item.title}".'
                        : 'Set a new testing window for "${item.title}".',
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F8A48).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF0F8A48).withValues(alpha: 0.3),
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
                            isInPerson
                                ? 'Current Date: ${localOrig.month.toString().padLeft(2, '0')}/${localOrig.day.toString().padLeft(2, '0')}/${localOrig.year}'
                                : 'Current Schedule: ${localOrig.month.toString().padLeft(2, '0')}/${localOrig.day.toString().padLeft(2, '0')}/${localOrig.year} ${_formatTime(localOrig)}',
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
                  Text(
                    isInPerson ? 'Update Date *' : 'Update Schedule Date *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: isSavingSchedule
                        ? null
                        : () async {
                            final tNow = DateTime.now();
                            final tToday = DateTime(
                              tNow.year,
                              tNow.month,
                              tNow.day,
                            );
                            final pickedDate = await showAppDatePickerDialog(
                              ctx,
                              initialDate: selectedDate,
                              firstDate: isInPerson
                                  ? DateTime(tToday.year - 1, 1, 1)
                                  : tToday,
                              lastDate: DateTime(tToday.year + 5, 12, 31),
                              title: isInPerson
                                  ? 'Update Date'
                                  : 'Update Schedule',
                              icon: Icons.event_available_outlined,
                              highlightDate: localOrig,
                              highlightLabel: isInPerson
                                  ? 'Current Date'
                                  : 'Current Schedule',
                            );
                            if (pickedDate != null && ctx.mounted) {
                              setModalState(() {
                                selectedDate = pickedDate;
                                scheduleTimeError = computeTimeError(
                                  selectedDate,
                                  selectedTime,
                                );
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
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                                color: Color(0xFF0F8A48),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.year}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                  if (!isInPerson) ...[
                    const SizedBox(height: 14),
                    AppTimePickerField(
                      key: ValueKey(
                        '${selectedDate.year}-${selectedDate.month}-${selectedDate.day}-${selectedTime.hour}-${selectedTime.minute}',
                      ),
                      label: 'Start Time *',
                      initialTime: selectedTime,
                      minTime: isSelectedToday
                          ? TimeOfDay.fromDateTime(
                              DateTime.now().add(const Duration(minutes: 1)),
                            )
                          : null,
                      onTimeSelected: (pickedTime) {
                        setModalState(() {
                          selectedTime = pickedTime;
                          scheduleTimeError = computeTimeError(
                            selectedDate,
                            selectedTime,
                          );
                        });
                      },
                    ),
                  ],
                  if (scheduleTimeError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      scheduleTimeError!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else if (isUnchanged) ...[
                    const SizedBox(height: 8),
                    Text(
                      isInPerson ? 'Select a different date to update.' : 'Select a different date or time to update the schedule.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSavingSchedule ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed:
                    (isSavingSchedule ||
                        isUnchanged ||
                        scheduleTimeError != null)
                    ? null
                    : () async {
                        final recheckErr = computeTimeError(
                          selectedDate,
                          selectedTime,
                        );
                        if (recheckErr != null) {
                          setModalState(() => scheduleTimeError = recheckErr);
                          return;
                        }
                        setModalState(() => isSavingSchedule = true);
                        try {
                          final client = SupabaseService().client;
                          final existing = await client
                              .from(
                                isInPerson
                                    ? 'classwork_items'
                                    : 'digital_assessments',
                              )
                              .select('id')
                              .eq('id', item.id)
                              .eq('is_archived', false)
                              .maybeSingle();

                          if (existing == null) {
                            AppDataCache.instance.invalidatePrefix(
                              'teacher_assessments_',
                            );
                            AppDataCache.instance.invalidatePrefix(
                              'teacher_activities_',
                            );
                            AppDataCache.instance.invalidatePrefix(
                              'student_dashboard_',
                            );
                            AppDataCache.instance.invalidatePrefix(
                              'gradebook_',
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              await widget.onRefresh?.call();
                              if (mounted) {
                                await AppModals.showWarningDialog(
                                  context: context,
                                  title: 'Assessment Removed',
                                  message: 'This assessment has already been deleted from the database and can no longer be updated.',
                                );
                              }
                            }
                            return;
                          }

                          if (isInPerson) {
                            await client
                                .from('classwork_items')
                                .update({
                                  'deadline': candidateCombined
                                      .toUtc()
                                      .toIso8601String(),
                                })
                                .eq('id', item.id);
                          } else {
                            final endUtc = candidateCombined
                                .add(Duration(minutes: item.durationMinutes))
                                .toUtc()
                                .toIso8601String();
                            await client
                                .from('digital_assessments')
                                .update({
                                  'available_from': candidateCombined
                                      .toUtc()
                                      .toIso8601String(),
                                  'deadline': endUtc,
                                })
                                .eq('id', item.id);

                            await client
                                .from('classwork_items')
                                .update({'deadline': endUtc})
                                .eq('id', item.id);
                          }

                          AppDataCache.instance.invalidatePrefix(
                            'teacher_assessments_',
                          );
                          AppDataCache.instance.invalidatePrefix(
                            'teacher_activities_',
                          );
                          AppDataCache.instance.invalidatePrefix(
                            'student_dashboard_',
                          );
                          AppDataCache.instance.invalidatePrefix('gradebook_');
                          TeacherGradebookTab.gradebookRefreshNotifier.value++;

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            setState(() => _isSyncing = true);
                            await widget.onRefresh?.call();
                            if (mounted) {
                              setState(() => _isSyncing = false);
                              AppTopToast.success(
                                context,
                                isInPerson
                                    ? 'Date updated for "${item.title}".'
                                    : 'Schedule updated for "${item.title}".',
                              );
                            }
                          }
                        } catch (e) {
                          setModalState(() => isSavingSchedule = false);
                          if (mounted) {
                            await AppModals.showErrorDialog(
                              context: context,
                              title: 'Update Failed',
                              message: 'Could not update schedule: $e',
                            );
                          }
                        }
                      },
                child: isSavingSchedule
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(isInPerson ? 'Save New Date' : 'Save New Schedule'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation({
    required String title,
    required VoidCallback onDelete,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete this item?\n\n$title'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.catRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              onDelete();
              Navigator.pop(dialogContext);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditActivityModal(ActivityModel item) {
    CreateRequirementFlowDialog.show(
      context,
      existingTask: item,
      initialSection: item.assignedSections.isNotEmpty
          ? item.assignedSections.first
          : '',
      initialSubject: item.subject,
      initialOfferingId: item.subjectOfferingId,
      initialOfferings: _teacherSubjects,
      isPerformanceTask: item.isRequirement,
      repository: widget.repository,
      onRequirementCreated: () async {
        setState(() => _isSyncing = true);
        try {
          final res = widget.onRefresh?.call();
          if (res is Future) {
            await res;
          }
        } finally {
          if (mounted) {
            setState(() => _isSyncing = false);
            AppTopToast.success(
              context,
              'Classwork updated and synced with gradebook successfully.',
            );
          }
        }
      },
    );
  }
}

class _PaginatedUnifiedItemList extends StatefulWidget {
  final List<Widget> items;
  final String emptyTitle;
  final String emptyMessage;
  final IconData icon;
  final int pageSize;

  const _PaginatedUnifiedItemList({
    required this.items,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.icon,
    this.pageSize = 5,
  });

  @override
  State<_PaginatedUnifiedItemList> createState() =>
      _PaginatedUnifiedItemListState();
}

class _PaginatedUnifiedItemListState extends State<_PaginatedUnifiedItemList> {
  int _visibleCount = 5;

  @override
  void initState() {
    super.initState();
    _visibleCount = widget.pageSize;
  }

  @override
  void didUpdateWidget(covariant _PaginatedUnifiedItemList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _visibleCount = widget.pageSize;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.icon,
                size: 36,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.emptyTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.emptyMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    final effectiveVisible = min(_visibleCount, widget.items.length);
    final visibleItems = widget.items.take(effectiveVisible).toList();
    final hasMore = effectiveVisible < widget.items.length;

    return ListView(
      children: [
        for (int i = 0; i < visibleItems.length; i++) ...[
          visibleItems[i],
          if (i < visibleItems.length - 1) const SizedBox(height: 12),
        ],
        if (hasMore) ...[
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Text(
                  'Showing $effectiveVisible of ${widget.items.length} items',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 8),
                AppButton.outline(
                  label:
                      'Load More (Scroll to show ${widget.items.length - effectiveVisible} remaining)',
                  icon: LucideIcons.chevronDown,
                  isSmall: true,
                  onPressed: () {
                    setState(() {
                      _visibleCount += widget.pageSize;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ] else ...[
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.checkCheck,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'All ${widget.items.length} items loaded',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.65,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _KeepAliveTabWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveTabWrapper({required this.child});

  @override
  State<_KeepAliveTabWrapper> createState() => _KeepAliveTabWrapperState();
}

class _KeepAliveTabWrapperState extends State<_KeepAliveTabWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
