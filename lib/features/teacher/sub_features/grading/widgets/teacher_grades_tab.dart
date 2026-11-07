import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/models/subject_catalog_model.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/data/repositories/supabase_student_repository.dart';
import 'package:class_realm/features/teacher/sub_features/grading/utils/gradebook_analytics_calculator.dart';
import 'package:class_realm/features/teacher/sub_features/grading/widgets/teacher_gradebook_tab.dart';

class TeacherGradesTab extends StatefulWidget {
  final List<UserModel> students;
  final VoidCallback? onNavigateToGradebook;

  const TeacherGradesTab({
    super.key,
    required this.students,
    this.onNavigateToGradebook,
  });

  @override
  State<TeacherGradesTab> createState() => _TeacherGradesTabState();
}

class _TeacherGradesTabState extends State<TeacherGradesTab>
    with SingleTickerProviderStateMixin {
  // Theme Palette (60-30-10 System)
  static const Color crCanvas = Color(0xFFF8FAFC);
  static const Color crBorder = Color(0xFFE2E8F0);
  static const Color crSteelBlue = Color(0xFF3A6B88);
  static const Color crEmerald = Color(0xFF10B981);
  static const Color crAmber = Color(0xFFF59E0B);
  static const Color crRed = Color(0xFFEF4444);
  static const Color crSlateDark = Color(0xFF0F172A);
  static const Color crSlateMuted = Color(0xFF64748B);

  // State
  List<Map<String, dynamic>> _teacherSubjects = [];
  bool _isLoadingSubjects = true;
  bool _isLoadingSheets = false;
  String? _selectedSubjectName;
  String? _selectedOfferingId;
  String _selectedSectionFilter = 'All Sections';
  int _selectedTermView = 0; // 0 = All Terms / Final Comparison, or 1, 2, 3
  String _donutMode = 'components'; // 'components' or 'distribution'
  String _searchQuery = '';
  String _sortOrder = 'desc'; // 'desc', 'asc', 'alpha'
  int _pageSize = 10;
  int _currentPage = 1;

  DateTime _refreshedAt = DateTime.now();
  late AnimationController _animController;
  late Animation<double> _chartAnim;

  List<UserModel> _activeRoster = [];
  final Map<int, Map<String, dynamic>?> _termSheets = {
    1: null,
    2: null,
    3: null,
  };

  @override
  void initState() {
    super.initState();
    _activeRoster = List.from(widget.students);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _chartAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    TeacherGradebookTab.gradebookRefreshNotifier.addListener(_handleGradebookChanged);
    TeacherGradebookTab.classworkSyncNotifier.addListener(_handleGradebookChanged);
    SubjectRepository.classworkSyncedNotifier.addListener(_handleGradebookChanged);

    _fetchTeacherSubjects();
  }

  @override
  void didUpdateWidget(covariant TeacherGradesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.students != oldWidget.students && _activeRoster.isEmpty) {
      setState(() {
        _activeRoster = List.from(widget.students);
      });
    }
  }

  @override
  void dispose() {
    TeacherGradebookTab.gradebookRefreshNotifier.removeListener(_handleGradebookChanged);
    TeacherGradebookTab.classworkSyncNotifier.removeListener(_handleGradebookChanged);
    SubjectRepository.classworkSyncedNotifier.removeListener(_handleGradebookChanged);
    _animController.dispose();
    super.dispose();
  }

  void _handleGradebookChanged() {
    if (!mounted) return;
    _reloadGradebookData(animate: true);
  }

  Future<void> _fetchTeacherSubjects() async {
    final user = AuthRepository.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingSubjects = false);
      return;
    }

    try {
      final subjects = await SubjectRepository.instance.getTeacherSubjects(
        user.id,
        onlyWithEnrolledStudents: true,
      );

      if (!mounted) return;

      setState(() {
        _teacherSubjects = subjects;
        _isLoadingSubjects = false;
        if (subjects.isNotEmpty) {
          final uniqueSubjects = subjects
              .map((s) => s['subject_name']?.toString() ?? '')
              .where((name) => name.isNotEmpty)
              .toSet()
              .toList();

          if (_selectedSubjectName == null || !uniqueSubjects.contains(_selectedSubjectName)) {
            _selectedSubjectName = uniqueSubjects.isNotEmpty ? uniqueSubjects.first : null;
          }

          final offeringsForSubject = subjects
              .where((s) => s['subject_name'] == _selectedSubjectName)
              .toList();

          final availableSections = offeringsForSubject
              .map((s) => s['section_name']?.toString() ?? '')
              .where((sec) => sec.isNotEmpty)
              .toSet()
              .toList()..sort();

          if (_selectedSectionFilter != 'All Sections' && !availableSections.contains(_selectedSectionFilter)) {
            _selectedSectionFilter = 'All Sections';
          }

          final initialOffering = _selectedSectionFilter != 'All Sections'
              ? offeringsForSubject.firstWhere(
                  (s) => s['section_name'] == _selectedSectionFilter,
                  orElse: () => offeringsForSubject.first,
                )
              : (offeringsForSubject.isNotEmpty ? offeringsForSubject.first : null);

          _selectedOfferingId = initialOffering?['id']?.toString();
          final termsTaught = (initialOffering?['terms_taught'] as num?)?.toInt() ?? 3;
          _selectedTermView = termsTaught > 1 ? 0 : 1;
        }
      });

      if (_selectedSubjectName != null) {
        await _loadSubjectData();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSubjects = false);
    }
  }

  Map<String, dynamic>? get _currentOffering {
    if (_teacherSubjects.isEmpty) return null;
    if (_selectedSubjectName != null) {
      final offeringsForSubject = _teacherSubjects
          .where((s) => s['subject_name'] == _selectedSubjectName)
          .toList();
      if (offeringsForSubject.isNotEmpty) {
        if (_selectedSectionFilter != 'All Sections') {
          return offeringsForSubject.firstWhere(
            (s) => s['section_name'] == _selectedSectionFilter,
            orElse: () => offeringsForSubject.first,
          );
        }
        return offeringsForSubject.first;
      }
    }
    if (_selectedOfferingId != null) {
      return _teacherSubjects.firstWhere(
        (s) => s['id']?.toString() == _selectedOfferingId,
        orElse: () => _teacherSubjects.first,
      );
    }
    return _teacherSubjects.first;
  }

  List<int> get _activeTerms {
    final offering = _currentOffering;
    if (offering == null) return const [1, 2, 3];
    final termsTaught = (offering['terms_taught'] as num?)?.toInt() ?? 3;
    final termBlock = offering['term_block']?.toString() ?? 'FIRST TERM';
    try {
      return DepEdSubjectCatalog.getActiveTermsForBlock(termsTaught, termBlock);
    } catch (_) {
      return const [1, 2, 3];
    }
  }

  Future<void> _loadSubjectData() async {
    final user = AuthRepository.instance.currentUser;
    if (_selectedSubjectName == null) return;
    setState(() => _isLoadingSheets = true);

    try {
      final offeringsForSubject = _teacherSubjects
          .where((s) => s['subject_name'] == _selectedSubjectName)
          .toList();

      List<Map<String, dynamic>> targetOfferings;
      if (_selectedSectionFilter == 'All Sections') {
        targetOfferings = offeringsForSubject;
      } else {
        targetOfferings = offeringsForSubject
            .where((s) => s['section_name'] == _selectedSectionFilter)
            .toList();
        if (targetOfferings.isEmpty && offeringsForSubject.isNotEmpty) {
          targetOfferings = [offeringsForSubject.first];
        }
      }

      if (targetOfferings.isNotEmpty) {
        _selectedOfferingId = targetOfferings.first['id']?.toString();
      }

      // 1. Fetch Students across target offerings
      if (user != null) {
        final allStudents = <UserModel>[];
        final seenStudentIds = <String>{};

        for (final off in targetOfferings) {
          final offId = off['id']?.toString();
          if (offId == null) continue;
          final students = await SupabaseStudentRepository().getStudentsForTeacher(
            user.id,
            subjectId: offId,
          );
          for (final s in students) {
            if (seenStudentIds.add(s.id)) {
              allStudents.add(s);
            }
          }
        }

        if (allStudents.isNotEmpty) {
          _activeRoster = allStudents;
        }
      }

      // 2. Hydrate & combine sheets for active terms from cache
      for (final term in const [1, 2, 3]) {
        Map<String, dynamic>? baseSheet;
        final List<Map<String, dynamic>> aggregatedStudents = [];

        for (final off in targetOfferings) {
          final offId = off['id']?.toString();
          if (offId == null) continue;
          final cached = LocalStorageService.getGradebookSheet(offId, term);
          if (cached != null) {
            baseSheet ??= cached;
            final sheetStudents = cached['students'];
            if (sheetStudents is List) {
              for (final st in sheetStudents) {
                if (st is Map<String, dynamic>) {
                  aggregatedStudents.add(st);
                }
              }
            }
          }
        }

        if (baseSheet != null) {
          final combined = Map<String, dynamic>.from(baseSheet);
          combined['students'] = aggregatedStudents;
          _termSheets[term] = combined;
        } else {
          _termSheets[term] = null;
        }
      }

      _animController.forward(from: 0.0);

      // Background fresh fetch from repository
      await Future.wait([
        for (final term in const [1, 2, 3])
          Future.wait([
            for (final off in targetOfferings)
              if (off['id'] != null)
                SubjectRepository.instance.getGradebookTermSheet(off['id'].toString(), term),
          ]).then((freshSheets) {
            if (!mounted) return;
            Map<String, dynamic>? baseFresh;
            final List<Map<String, dynamic>> allFreshStudents = [];

            for (final fresh in freshSheets) {
              if (fresh != null) {
                baseFresh ??= fresh;
                final sheetStudents = fresh['students'];
                if (sheetStudents is List) {
                  for (final st in sheetStudents) {
                    if (st is Map<String, dynamic>) {
                      allFreshStudents.add(st);
                    }
                  }
                }
              }
            }

            if (baseFresh != null) {
              final combined = Map<String, dynamic>.from(baseFresh);
              combined['students'] = allFreshStudents;
              _termSheets[term] = combined;
            }
          }),
      ]);
    } catch (_) {
      // Retain cached sheets
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSheets = false;
          _refreshedAt = DateTime.now();
        });
      }
    }
  }

  void _reloadGradebookData({bool animate = true}) {
    if (_selectedSubjectName != null) {
      _loadSubjectData();
    }
    if (animate) {
      _animController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoadingSubjects) {
      return const Center(
        child: CircularProgressIndicator(color: crSteelBlue),
      );
    }

    final hasNoOfferings = _teacherSubjects.isEmpty && widget.students.isEmpty;

    final offering = _currentOffering ?? {
      'id': 'default',
      'subject_name': 'No Subject Selected',
      'ww_weight': 20.0,
      'pt_weight': 60.0,
      'ex_weight': 20.0,
      'terms_taught': 3,
      'term_block': 'FIRST TERM',
    };

    final activeTerms = _activeTerms;
    if (activeTerms.length <= 1 &&
        activeTerms.isNotEmpty &&
        _selectedTermView != activeTerms.first) {
      _selectedTermView = activeTerms.first;
    }

    // Filter students by section if specified
    var studentsForComputation = _activeRoster.isNotEmpty ? _activeRoster : widget.students;
    if (_selectedSectionFilter != 'All Sections') {
      studentsForComputation = studentsForComputation
          .where((s) => s.departmentOrSection == _selectedSectionFilter)
          .toList();
    }

    // Compute live deterministic analytics summary
    final summary = GradebookAnalyticsCalculator.compute(
      subjectOffering: offering,
      students: studentsForComputation,
      termSheets: _termSheets,
      selectedTermView: _selectedTermView,
      activeTerms: activeTerms,
    );

    return Scaffold(
      backgroundColor: isDark ? theme.scaffoldBackgroundColor : crCanvas,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TOP HEADER & REFRESH STRIP
            _buildTopHeader(isDark, theme),
            if (hasNoOfferings)
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.info, size: 16, color: crSteelBlue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No subject offerings found yet. Set up your subjects and class sections in Classroom Setup first.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : const Color(0xFF1E40AF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_isLoadingSheets)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: crSteelBlue,
                  backgroundColor: Color(0xFFE2E8F0),
                ),
              )
            else
              const SizedBox(height: 16),

            // 2. UNIFIED FILTER & OVERVIEW ROW (5-col Filter + 7-col Class Summary Strip)
            _buildFilterAndOverviewRow(offering, activeTerms, summary, isDark, theme),
            const SizedBox(height: 16),

            // 3. FOUR KPI METRIC CARDS
            _buildKpiSummaryRow(summary, isDark, theme),
            const SizedBox(height: 20),

            // 4. CHARTS SECTION (Standing Vertical Bar Chart + Donut/Pie Chart)
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 950) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: _buildVerticalBarChartCard(summary, activeTerms, isDark, theme),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 5,
                        child: _buildDonutPieChartCard(summary, isDark, theme),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildVerticalBarChartCard(summary, activeTerms, isDark, theme),
                      const SizedBox(height: 16),
                      _buildDonutPieChartCard(summary, isDark, theme),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 24),

            // 5. INTEGRATED GRADES COMPUTATION & STUDENT RANKING TABLE
            _buildGradesTableCard(summary, activeTerms, isDark, theme),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // --- 1. TOP HEADER ---
  Widget _buildTopHeader(bool isDark, ThemeData theme) {
    final timeStr =
        '${_refreshedAt.hour.toString().padLeft(2, '0')}:${_refreshedAt.minute.toString().padLeft(2, '0')}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final titleSection = ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: crSteelBlue,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: crSteelBlue.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(LucideIcons.barChart3, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Performance Analytics',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : crSlateDark,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? Colors.white12 : crBorder,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.link2, size: 12, color: crSteelBlue),
                              const SizedBox(width: 4),
                              Text(
                                'Synced with Gradebook',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : crSlateMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Real-time academic trajectory and transmuted rankings.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : crSlateMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        final refreshBtn = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? theme.colorScheme.surface : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? Colors.white12 : crBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.clock, size: 13, color: crSlateMuted),
              const SizedBox(width: 6),
              Text(
                'Refreshed at $timeStr',
                style: const TextStyle(fontSize: 11, color: crSlateMuted),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  _reloadGradebookData(animate: true);
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: RotationTransition(
                    turns: _chartAnim,
                    child: const Icon(LucideIcons.refreshCw, size: 13, color: crSteelBlue),
                  ),
                ),
              ),
            ],
          ),
        );

        return Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            titleSection,
            refreshBtn,
          ],
        );
      },
    );
  }

  // --- 2. UNIFIED FILTER & OVERVIEW ROW (5-col Filter + 7-col Summary Strip) ---
  Widget _buildFilterAndOverviewRow(
    Map<String, dynamic> offering,
    List<int> activeTerms,
    GradebookAnalyticsSummary summary,
    bool isDark,
    ThemeData theme,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final filterCard = _buildFilterAndContextCard(
          offering,
          activeTerms,
          isDark,
          theme,
        );
        final summaryStripCard = _buildClassPerformanceSummaryCard(
          offering,
          summary,
          isDark,
          theme,
        );

        if (constraints.maxWidth > 980) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: filterCard),
              const SizedBox(width: 16),
              Expanded(flex: 7, child: summaryStripCard),
            ],
          );
        } else {
          return Column(
            children: [
              filterCard,
              const SizedBox(height: 14),
              summaryStripCard,
            ],
          );
        }
      },
    );
  }

  Widget _buildFilterAndContextCard(
    Map<String, dynamic> offering,
    List<int> activeTerms,
    bool isDark,
    ThemeData theme,
  ) {
    // Unique subjects from _teacherSubjects
    final uniqueSubjects = _teacherSubjects
        .map((s) => s['subject_name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();

    final safeSubject = uniqueSubjects.contains(_selectedSubjectName)
        ? _selectedSubjectName
        : (uniqueSubjects.isNotEmpty ? uniqueSubjects.first : null);

    // Sections for currently selected subject
    final availableSections = safeSubject != null
        ? (_teacherSubjects
            .where((s) => s['subject_name'] == safeSubject)
            .map((s) => s['section_name']?.toString() ?? '')
            .where((sec) => sec.isNotEmpty)
            .toSet()
            .toList()..sort())
        : <String>[];

    final sectionItems = [
      'All Sections',
      ...availableSections,
    ];

    final safeSection = sectionItems.contains(_selectedSectionFilter)
        ? _selectedSectionFilter
        : 'All Sections';

    if (_selectedSectionFilter != safeSection) {
      _selectedSectionFilter = safeSection;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : crBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // Subject Dropdown (Unique items only - no duplicates)
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SUBJECT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: crSlateMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      key: ValueKey('subject_${safeSubject ?? "none"}'),
                      isExpanded: true,
                      initialValue: safeSubject,
                      dropdownColor: isDark ? theme.colorScheme.surface : Colors.white,
                      decoration: _inputDecoration(isDark),
                      hint: const Text(
                        'No subjects available',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: crSlateMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                      items: uniqueSubjects.isEmpty
                          ? null
                          : uniqueSubjects.map((s) {
                              return DropdownMenuItem<String>(
                                value: s,
                                child: Text(
                                  s,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                      onChanged: uniqueSubjects.isEmpty
                          ? null
                          : (val) {
                              if (val != null && val != _selectedSubjectName) {
                                setState(() {
                                  _selectedSubjectName = val;
                                  _selectedSectionFilter = 'All Sections';
                                  final offerings = _teacherSubjects.where((s) => s['subject_name'] == val).toList();
                                  if (offerings.isNotEmpty) {
                                    final termsTaught = (offerings.first['terms_taught'] as num?)?.toInt() ?? 3;
                                    _selectedTermView = termsTaught > 1 ? 0 : 1;
                                  }
                                  _currentPage = 1;
                                });
                                _loadSubjectData();
                              }
                            },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Section Dropdown (Safe & synchronized with current subject)
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SECTION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: crSlateMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      key: ValueKey('section_${safeSubject}_$safeSection'),
                      isExpanded: true,
                      initialValue: safeSection,
                      dropdownColor: isDark ? theme.colorScheme.surface : Colors.white,
                      decoration: _inputDecoration(isDark),
                      items: sectionItems.map((sec) {
                        return DropdownMenuItem<String>(
                          value: sec,
                          child: Text(
                            sec,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null && val != _selectedSectionFilter) {
                          setState(() {
                            _selectedSectionFilter = val;
                            _currentPage = 1;
                          });
                          _loadSubjectData();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: crBorder),
          const SizedBox(height: 10),

          // Dynamic Term Tabs Bar / Single-Term Adaptation + Open Gradebook
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.calendarRange, size: 13, color: crSlateMuted),
                      SizedBox(width: 5),
                      Text(
                        'GRADING PERIOD:',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: crSlateMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  if (activeTerms.length <= 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFBAE6FD)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.calendarCheck, size: 13, color: crSteelBlue),
                          const SizedBox(width: 6),
                          Text(
                            'Single-Term • Term ${activeTerms.firstOrNull ?? 1}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: crSteelBlue,
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    for (final t in activeTerms)
                      _buildTermPill(
                        label: 'Term $t',
                        isSelected: _selectedTermView == t,
                        onTap: () {
                          setState(() {
                            _selectedTermView = t;
                            _currentPage = 1;
                          });
                          _animController.forward(from: 0.0);
                        },
                      ),
                    _buildTermPill(
                      label: 'All Terms',
                      isSelected: _selectedTermView == 0,
                      onTap: () {
                        setState(() {
                          _selectedTermView = 0;
                          _currentPage = 1;
                        });
                        _animController.forward(from: 0.0);
                      },
                    ),
                  ],
                ],
              ),

              if (widget.onNavigateToGradebook != null)
                ElevatedButton.icon(
                  onPressed: widget.onNavigateToGradebook,
                  icon: const Icon(LucideIcons.externalLink, size: 13),
                  label: const Text('Open Gradebook', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: crSteelBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClassPerformanceSummaryCard(
    Map<String, dynamic> offering,
    GradebookAnalyticsSummary summary,
    bool isDark,
    ThemeData theme,
  ) {
    final wwWeight = (offering['ww_weight'] as num?)?.toInt() ?? 20;
    final ptWeight = (offering['pt_weight'] as num?)?.toInt() ?? 50;
    final exWeight = (offering['ex_weight'] as num?)?.toInt() ?? 30;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : crBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Header Row: Title + Weights Badge
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.activity, size: 15, color: crSteelBlue),
                  const SizedBox(width: 6),
                  Text(
                    'Class Performance Summary',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : crSlateDark,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? Colors.white12 : crBorder),
                ),
                child: Text(
                  'Weights: WW $wwWeight% • PT $ptWeight% • EX $exWeight%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: crSlateMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 5-Column Full-Width Inner Metric Strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 460) {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildStripItem(
                          'Students',
                          '${summary.totalCount}',
                          'Active Roster',
                          crSlateDark,
                          isDark,
                        ),
                      ),
                      _buildStripDivider(),
                      Expanded(
                        child: _buildStripItem(
                          'Class Average',
                          summary.classAverage != null ? '${summary.classAverage}' : '—',
                          'DO 15 Transmuted',
                          crSteelBlue,
                          isDark,
                        ),
                      ),
                      _buildStripDivider(),
                      Expanded(
                        child: _buildStripItem(
                          'Written Works',
                          summary.wwPsAvg != null ? '${summary.wwPsAvg}%' : '—',
                          'PS Average',
                          crSlateDark,
                          isDark,
                        ),
                      ),
                      _buildStripDivider(),
                      Expanded(
                        child: _buildStripItem(
                          'Perf. Tasks',
                          summary.ptPsAvg != null ? '${summary.ptPsAvg}%' : '—',
                          'PS Average',
                          crSlateDark,
                          isDark,
                        ),
                      ),
                      _buildStripDivider(),
                      Expanded(
                        child: _buildStripItem(
                          'Examinations',
                          summary.exPsAvg != null ? '${summary.exPsAvg}%' : '—',
                          'PS Average',
                          crSlateDark,
                          isDark,
                        ),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildStripItem(
                              'Students',
                              '${summary.totalCount}',
                              'Active Roster',
                              crSlateDark,
                              isDark,
                            ),
                          ),
                          _buildStripDivider(),
                          Expanded(
                            child: _buildStripItem(
                              'Class Average',
                              summary.classAverage != null ? '${summary.classAverage}' : '—',
                              'DO 15 Transmuted',
                              crSteelBlue,
                              isDark,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16, color: crBorder),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStripItem(
                              'Written Works',
                              summary.wwPsAvg != null ? '${summary.wwPsAvg}%' : '—',
                              'PS Average',
                              crSlateDark,
                              isDark,
                            ),
                          ),
                          _buildStripDivider(),
                          Expanded(
                            child: _buildStripItem(
                              'Perf. Tasks',
                              summary.ptPsAvg != null ? '${summary.ptPsAvg}%' : '—',
                              'PS Average',
                              crSlateDark,
                              isDark,
                            ),
                          ),
                          _buildStripDivider(),
                          Expanded(
                            child: _buildStripItem(
                              'Examinations',
                              summary.exPsAvg != null ? '${summary.exPsAvg}%' : '—',
                              'PS Average',
                              crSlateDark,
                              isDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? crSteelBlue : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? crSteelBlue : crBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : crSlateDark,
          ),
        ),
      ),
    );
  }

  // --- 3. KPI SUMMARY ROW (4 Metric Cards) ---
  Widget _buildKpiSummaryRow(
    GradebookAnalyticsSummary summary,
    bool isDark,
    ThemeData theme,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final card1 = _buildKpiCard(
          title: 'Passing Rate (≥ 75)',
          value: summary.passingRate != null ? '${summary.passingRate}%' : '—',
          badgeText: '${summary.passingCount} / ${summary.encodedCount} Passed',
          subText: 'Based on DO 15, s. 2026',
          icon: LucideIcons.checkCircle2,
          iconColor: crEmerald,
          badgeBg: const Color(0xFFECFDF5),
          badgeBorder: const Color(0xFFA7F3D0),
          badgeTextColor: const Color(0xFF047857),
          isDark: isDark,
          theme: theme,
        );
        final card2 = _buildKpiCard(
          title: 'Advancing (90–100)',
          value: '${summary.advancingCount}',
          badgeText: summary.encodedCount > 0
              ? '${((summary.advancingCount / summary.encodedCount) * 100).toStringAsFixed(1)}%'
              : '0%',
          subText: 'Highest achievement tier',
          icon: LucideIcons.award,
          iconColor: crSteelBlue,
          badgeBg: const Color(0xFFF0F9FF),
          badgeBorder: const Color(0xFFBAE6FD),
          badgeTextColor: crSteelBlue,
          isDark: isDark,
          theme: theme,
        );
        final card3 = _buildKpiCard(
          title: 'Positive Trajectory',
          value: '${summary.improvingCount}',
          badgeText: 'Rising',
          subText: 'Improving score trend',
          icon: LucideIcons.trendingUp,
          iconColor: crEmerald,
          badgeBg: const Color(0xFFECFDF5),
          badgeBorder: const Color(0xFFA7F3D0),
          badgeTextColor: const Color(0xFF047857),
          isDark: isDark,
          theme: theme,
        );
        final card4 = _buildKpiCard(
          title: 'Needs Attention',
          value: '${summary.needsAttentionCount}',
          badgeText: 'Action Required',
          subText: '<75 or declining scores',
          icon: LucideIcons.alertTriangle,
          iconColor: crRed,
          badgeBg: const Color(0xFFFEF2F2),
          badgeBorder: const Color(0xFFFECACA),
          badgeTextColor: crRed,
          isDark: isDark,
          theme: theme,
        );

        if (constraints.maxWidth > 950) {
          return Row(
            children: [
              Expanded(child: card1),
              const SizedBox(width: 14),
              Expanded(child: card2),
              const SizedBox(width: 14),
              Expanded(child: card3),
              const SizedBox(width: 14),
              Expanded(child: card4),
            ],
          );
        } else {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: card1),
                  const SizedBox(width: 14),
                  Expanded(child: card2),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: card3),
                  const SizedBox(width: 14),
                  Expanded(child: card4),
                ],
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildStripItem(
    String label,
    String value,
    String subtitle,
    Color valColor,
    bool isDark,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: crSlateMuted, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : valColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : crSlateMuted),
        ),
      ],
    );
  }

  Widget _buildStripDivider() {
    return Container(
      width: 1,
      height: 38,
      color: crBorder,
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String badgeText,
    required String subText,
    required IconData icon,
    required Color iconColor,
    required Color badgeBg,
    required Color badgeBorder,
    required Color badgeTextColor,
    required bool isDark,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : crBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: crSlateMuted, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : crSlateDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: badgeBorder),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: badgeTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subText,
                  style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : crSlateMuted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: iconColor.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
        ],
      ),
    );
  }

  // --- 4A. STANDING VERTICAL COLUMN BAR CHART ---
  Widget _buildVerticalBarChartCard(
    GradebookAnalyticsSummary summary,
    List<int> activeTerms,
    bool isDark,
    ThemeData theme,
  ) {
    final isCrossTerm = _selectedTermView == 0 && activeTerms.length > 1;

    final title = isCrossTerm
        ? 'Term-over-Term Progression (Term 1 → Term 2 → Term 3)'
        : 'Assessment Trajectory (WW → PT → Exams)';
    final subtitle = isCrossTerm
        ? 'Standing vertical comparison of section Transmuted Grade Averages.'
        : 'Vertical column breakdown of class mean percentage scores.';

    // Pick points to render
    final barData = isCrossTerm
        ? summary.termProgressionPoints.map((p) {
            return _BarItem(
              label: p.label,
              sub: p.subLabel,
              value: p.classAverageGrade ?? 0.0,
              color: p.color,
            );
          }).toList()
        : summary.assessmentPoints.map((p) {
            return _BarItem(
              label: p.label,
              sub: p.subLabel,
              value: p.classAveragePercent,
              color: p.color,
            );
          }).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : crBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.barChart2, size: 16, color: crSteelBlue),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : crSlateDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: crBorder),
                ),
                child: Text(
                  isCrossTerm ? 'Cross-Term View' : 'Within-Term View',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: crSlateDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: crSlateMuted),
          ),
          const SizedBox(height: 20),

          // Chart Canvas with Standing Vertical Bars
          SizedBox(
            height: 220,
            child: barData.isEmpty
                ? const Center(
                    child: Text(
                      'No scored assessments encoded yet for this view.',
                      style: TextStyle(fontSize: 12, color: crSlateMuted),
                    ),
                  )
                : AnimatedBuilder(
                    animation: _chartAnim,
                    builder: (context, _) {
                      return Stack(
                        children: [
                          // Y-Axis Horizontal Gridlines
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildGridline('100'),
                              _buildGridline('80'),
                              _buildGridline('60'),
                              _buildGridline('40'),
                              _buildGridline('20'),
                              _buildGridline('0'),
                            ],
                          ),

                          // Dashed Pass Threshold Line at 75%
                          Positioned(
                            left: 32,
                            right: 0,
                            bottom: 220 * 0.75,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: crAmber.withValues(alpha: 0.6),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Pass 75',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Standing Bars
                          Padding(
                            padding: const EdgeInsets.only(left: 36, right: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: barData.map((item) {
                                final animVal = item.value * _chartAnim.value;
                                final barHeight = (animVal / 100).clamp(0.08, 1.0) * 180;

                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    // Value Label Badge
                                    Opacity(
                                      opacity: _chartAnim.value,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: crBorder),
                                        ),
                                        child: Text(
                                          item.value.toStringAsFixed(1),
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: crSlateDark),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),

                                    // Standing Bar
                                    Container(
                                      width: 44,
                                      height: barHeight,
                                      decoration: BoxDecoration(
                                        color: item.color,
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: item.color.withValues(alpha: 0.3),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 6),

                                    // X-Axis Label
                                    Text(
                                      item.label,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: crSlateDark),
                                    ),
                                    Text(
                                      item.sub,
                                      style: const TextStyle(fontSize: 9, color: crSlateMuted),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          const SizedBox(height: 14),

          // Insight Footer
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: crBorder),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.trendingUp, size: 14, color: crEmerald),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isCrossTerm
                        ? 'Class transmuted average is tracking across all completed grading terms.'
                        : 'Within-term assessment scores reflect continuous learner mastery in Gradebook items.',
                    style: const TextStyle(fontSize: 11, color: crSlateDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridline(String label) {
    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            label,
            style: const TextStyle(fontSize: 9, color: crSlateMuted),
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            height: 1,
            color: crBorder.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  // --- 4B. ANIMATED DONUT / PIE CHART WITH FLOATING BADGES (Matches 2nd Reference Pic) ---
  Widget _buildDonutPieChartCard(
    GradebookAnalyticsSummary summary,
    bool isDark,
    ThemeData theme,
  ) {
    final slices = _donutMode == 'components'
        ? summary.componentDonutSlices
        : summary.distributionDonutSlices;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : crBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.pieChart, size: 16, color: crSteelBlue),
                  const SizedBox(width: 8),
                  Text(
                    _donutMode == 'components' ? 'Component Mastery' : 'Performance Distribution',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : crSlateDark,
                    ),
                  ),
                ],
              ),
              // Dropdown mode selector (Matches "Group 1 v" in 2nd Pic)
              Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: crBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _donutMode,
                    icon: const Icon(LucideIcons.chevronDown, size: 13, color: crSlateDark),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: crSlateDark),
                    items: const [
                      DropdownMenuItem(
                        value: 'components',
                        child: Text('WW vs PT vs EX'),
                      ),
                      DropdownMenuItem(
                        value: 'distribution',
                        child: Text('Performance Distribution'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null && val != _donutMode) {
                        setState(() => _donutMode = val);
                        _animController.forward(from: 0.0);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            _donutMode == 'components'
                ? 'Section Percentage Score (PS%) & category weights.'
                : 'Learner distribution across DO 15 achievement tiers.',
            style: const TextStyle(fontSize: 11, color: crSlateMuted),
          ),
          const SizedBox(height: 16),

          // Donut Chart Canvas with Floating Circular White Badges (Exact 2nd Pic Look)
          Center(
            child: SizedBox(
              width: 210,
              height: 210,
              child: AnimatedBuilder(
                animation: _chartAnim,
                builder: (context, _) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Arc Painter
                      CustomPaint(
                        size: const Size(200, 200),
                        painter: _DonutChartPainter(
                          slices: slices,
                          progress: _chartAnim.value,
                          strokeWidth: 26,
                        ),
                      ),

                      // Center Hole Text
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _donutMode == 'components' ? 'Initial Avg' : 'Total Class',
                            style: const TextStyle(fontSize: 9, color: crSlateMuted, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            _donutMode == 'components'
                                ? (summary.classAverage != null ? '${summary.classAverage}%' : '—')
                                : '${summary.totalCount}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: crSlateDark),
                          ),
                          Text(
                            _donutMode == 'components' ? 'Weighted PS%' : 'Students',
                            style: const TextStyle(fontSize: 9, color: crSlateMuted),
                          ),
                        ],
                      ),

                      // Floating Circular Badges over slices (Reference Pic 2 style)
                      ..._buildFloatingBadges(slices, _chartAnim.value),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Dot Legend (Matches "● Excellent   ● Good   ● Weak" in 2nd Pic)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: slices.map((s) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: s.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      s.dotLabel,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: crSlateDark),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: crBorder),
          const SizedBox(height: 12),

          // DO 15 Descriptor Breakdown Cards
          const Text(
            'DO 15, S. 2026 DESCRIPTOR BREAKDOWN',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: crSlateMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDescriptorCard('Advancing', '90–100', summary.advancingCount, crEmerald),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDescriptorCard('Benchmarking', '80–89', summary.benchmarkingCount, crSteelBlue),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDescriptorCard('Connecting', '75–79', summary.connectingCount, crAmber),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDescriptorCard('Developing', '< 75', summary.developingCount, crRed),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFloatingBadges(List<DonutSliceData> slices, double progress) {
    final widgets = <Widget>[];
    const center = Offset(105, 105);
    const radius = 72.0;

    var startAngle = -math.pi / 2;

    for (final s in slices) {
      if (s.pct <= 0) continue;
      final sweep = (s.pct / 100) * 2 * math.pi;
      final midAngle = startAngle + sweep / 2;
      startAngle += sweep;

      final x = center.dx + radius * math.cos(midAngle);
      final y = center.dy + radius * math.sin(midAngle);

      final bounceScale = Curves.easeOutBack.transform(progress.clamp(0.0, 1.0));

      widgets.add(
        Positioned(
          left: x - 22,
          top: y - 22,
          child: Transform.scale(
            scale: bounceScale,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${s.badgeVal.toStringAsFixed(s.badgeVal % 1 != 0 ? 1 : 0)}%',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: crSlateDark,
                    ),
                  ),
                  Text(
                    s.sub,
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: crSlateMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _buildDescriptorCard(String title, String range, int count, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: crBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 24,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: crSlateDark)),
                  Text(range, style: const TextStyle(fontSize: 9, color: crSlateMuted)),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Text(
              '$count',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: accent),
            ),
          ),
        ],
      ),
    );
  }

  // --- 5. INTEGRATED GRADES COMPUTATION & STUDENT RANKING TABLE ---
  Widget _buildGradesTableCard(
    GradebookAnalyticsSummary summary,
    List<int> activeTerms,
    bool isDark,
    ThemeData theme,
  ) {
    final isCrossTerm = _selectedTermView == 0 && activeTerms.length > 1;

    // Filter by search query
    var list = summary.studentRows.where((r) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return r.displayName.toLowerCase().contains(q) || r.lrn.toLowerCase().contains(q);
    }).toList();

    // Sort order
    if (_sortOrder == 'desc') {
      list.sort((a, b) {
        final ga = a.activeGrade;
        final gb = b.activeGrade;
        if (ga == null && gb == null) return a.displayName.compareTo(b.displayName);
        if (ga == null) return 1;
        if (gb == null) return -1;
        return gb.compareTo(ga);
      });
    } else if (_sortOrder == 'asc') {
      list.sort((a, b) {
        final ga = a.activeGrade;
        final gb = b.activeGrade;
        if (ga == null && gb == null) return a.displayName.compareTo(b.displayName);
        if (ga == null) return 1;
        if (gb == null) return -1;
        return ga.compareTo(gb);
      });
    } else if (_sortOrder == 'alpha') {
      list.sort((a, b) => a.displayName.compareTo(b.displayName));
    }

    // Pagination calculations
    final totalEntries = list.length;
    var totalPages = (totalEntries / _pageSize).ceil();
    if (totalPages == 0) totalPages = 1;
    if (_currentPage > totalPages) _currentPage = totalPages;

    final startIdx = (_currentPage - 1) * _pageSize;
    final endIdx = math.min(startIdx + _pageSize, totalEntries);
    final paginatedRows = totalEntries > 0 ? list.sublist(startIdx, endIdx) : <StudentGradeAnalyticsRow>[];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : crBorder),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Control Header (Search + Sort + Page Size)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Quarterly / Term Grades Computation & Student Ranking',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : crSlateDark,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F9FF),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFBAE6FD)),
                          ),
                          child: const Text(
                            'Computed via DepEdGradingEngine',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: crSteelBlue),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Automatic initial-to-transmuted grade computation and descriptor classification.',
                      style: TextStyle(fontSize: 11, color: crSlateMuted),
                    ),
                  ],
                ),

                Wrap(
                  spacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Search Input
                    SizedBox(
                      width: 210,
                      height: 36,
                      child: TextField(
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.trim();
                            _currentPage = 1;
                          });
                        },
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(LucideIcons.search, size: 14, color: crSlateMuted),
                          hintText: 'Search by name or LRN...',
                          hintStyle: const TextStyle(fontSize: 12, color: crSlateMuted),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                          filled: true,
                          fillColor: isDark ? Colors.white10 : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: crBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: crBorder),
                          ),
                        ),
                      ),
                    ),

                    // Sort Order Dropdown
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: crBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _sortOrder,
                          icon: const Icon(LucideIcons.arrowUpDown, size: 13, color: crSlateMuted),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: crSlateDark),
                          items: const [
                            DropdownMenuItem(value: 'desc', child: Text('Sort: Highest to Lowest')),
                            DropdownMenuItem(value: 'asc', child: Text('Sort: Lowest to Highest')),
                            DropdownMenuItem(value: 'alpha', child: Text('Sort: Alphabetical (A–Z)')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _sortOrder = val;
                                _currentPage = 1;
                              });
                            }
                          },
                        ),
                      ),
                    ),

                    // Page Size Selector
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: crBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _pageSize,
                          icon: const Icon(LucideIcons.chevronDown, size: 13, color: crSlateMuted),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: crSlateDark),
                          items: const [
                            DropdownMenuItem(value: 10, child: Text('10 / page')),
                            DropdownMenuItem(value: 20, child: Text('20 / page')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _pageSize = val;
                                _currentPage = 1;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Table Content - Stretched Full Width ("Naka Sagad sa Tabi")
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: crBorder),
                bottom: BorderSide(color: crBorder),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final minTableWidth = isCrossTerm ? 960.0 : 1020.0;
                final tableWidth = math.max(constraints.maxWidth, minTableWidth);

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header Row
                        _buildCustomTableHeader(isCrossTerm, activeTerms, isDark),

                        // Empty State if no students
                        if (paginatedRows.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            alignment: Alignment.center,
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.users, size: 32, color: crSlateMuted),
                                SizedBox(height: 8),
                                Text(
                                  'No students found',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: crSlateMuted,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          // Student Data Rows
                          for (int i = 0; i < paginatedRows.length; i++)
                            _buildCustomTableRow(
                              paginatedRows[i],
                              isCrossTerm,
                              activeTerms,
                              isDark,
                              i,
                            ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Manage Students Pagination Footer (Exact Match)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  totalEntries == 0
                      ? 'Showing 0 to 0 of 0 entries'
                      : 'Showing ${startIdx + 1} to $endIdx of $totalEntries entries',
                  style: const TextStyle(fontSize: 12, color: crSlateMuted, fontWeight: FontWeight.w500),
                ),
                if (totalPages > 1)
                  Row(
                    children: [
                      _buildPageButton(
                        'First',
                        () => setState(() => _currentPage = 1),
                        _currentPage > 1,
                      ),
                      const SizedBox(width: 4),
                      _buildPageButton(
                        '<',
                        () => setState(() => _currentPage--),
                        _currentPage > 1,
                      ),
                      const SizedBox(width: 4),
                      for (int p = 1; p <= totalPages; p++)
                        if (p >= _currentPage - 2 && p <= _currentPage + 2) ...[
                          _buildPageButton(
                            p.toString(),
                            () => setState(() => _currentPage = p),
                            true,
                            isActive: p == _currentPage,
                          ),
                          const SizedBox(width: 4),
                        ],
                      _buildPageButton(
                        '>',
                        () => setState(() => _currentPage++),
                        _currentPage < totalPages,
                      ),
                      const SizedBox(width: 4),
                      _buildPageButton(
                        'Last',
                        () => setState(() => _currentPage = totalPages),
                        _currentPage < totalPages,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const TextStyle _colHeaderStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: crSlateMuted,
    letterSpacing: 0.5,
  );

  Widget _buildCustomTableHeader(bool isCrossTerm, List<int> activeTerms, bool isDark) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
        border: const Border(bottom: BorderSide(color: crBorder)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 44,
            child: Text('#', style: _colHeaderStyle),
          ),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('STUDENT NAME', style: _colHeaderStyle),
            ),
          ),
          const SizedBox(
            width: 130,
            child: Text('LRN', style: _colHeaderStyle),
          ),
          if (isCrossTerm) ...[
            for (final t in activeTerms)
              SizedBox(
                width: 85,
                child: Text('TERM $t', style: _colHeaderStyle),
              ),
            const SizedBox(
              width: 105,
              child: Text('FINAL GRADE', style: _colHeaderStyle),
            ),
          ] else ...[
            const SizedBox(
              width: 95,
              child: Text('WW (PS%)', style: _colHeaderStyle),
            ),
            const SizedBox(
              width: 95,
              child: Text('PT (PS%)', style: _colHeaderStyle),
            ),
            const SizedBox(
              width: 95,
              child: Text('EXAM (PS%)', style: _colHeaderStyle),
            ),
            SizedBox(
              width: 110,
              child: Text(
                'TERM ${_selectedTermView == 0 ? activeTerms.first : _selectedTermView} GRADE',
                style: _colHeaderStyle,
              ),
            ),
          ],
          const SizedBox(
            width: 110,
            child: Text('TREND', style: _colHeaderStyle),
          ),
          const SizedBox(
            width: 130,
            child: Text('DESCRIPTOR', style: _colHeaderStyle),
          ),
          const SizedBox(
            width: 110,
            child: Text('REMARKS', style: _colHeaderStyle),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomTableRow(
    StudentGradeAnalyticsRow row,
    bool isCrossTerm,
    List<int> activeTerms,
    bool isDark,
    int index,
  ) {
    final displayName = row.displayName;
    String lastName = displayName;
    String restOfName = '';
    if (displayName.contains(',')) {
      final idx = displayName.indexOf(',');
      lastName = displayName.substring(0, idx).trim();
      restOfName = displayName.substring(idx + 1).trim();
    }

    final nameWidget = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: lastName,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : crSlateDark,
            ),
          ),
          if (restOfName.isNotEmpty)
            TextSpan(
              text: ', $restOfName',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : crSlateDark,
              ),
            ),
        ],
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );

    // Trend Widget
    Widget trendWidget;
    if (row.trend == GradeTrend.improving) {
      trendWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.trendingUp, size: 12, color: Color(0xFF047857)),
            const SizedBox(width: 4),
            Text(
              '+${row.delta?.toStringAsFixed(1) ?? '1'} pts',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
            ),
          ],
        ),
      );
    } else if (row.trend == GradeTrend.declining) {
      trendWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.trendingDown, size: 12, color: crRed),
            const SizedBox(width: 4),
            Text(
              '${row.delta?.toStringAsFixed(1) ?? '-1'} pts',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: crRed),
            ),
          ],
        ),
      );
    } else {
      trendWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: crBorder),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.minus, size: 12, color: crSlateMuted),
            SizedBox(width: 4),
            Text('Stable', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: crSlateMuted)),
          ],
        ),
      );
    }

    // Remarks Widget
    final isPassed = row.activeGrade != null && row.activeGrade! >= 75;
    final remarksWidget = row.activeGrade == null
        ? const Text('—', style: TextStyle(fontSize: 13, color: crSlateMuted))
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isPassed ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isPassed ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPassed ? LucideIcons.check : LucideIcons.x,
                  size: 12,
                  color: isPassed ? const Color(0xFF047857) : crRed,
                ),
                const SizedBox(width: 4),
                Text(
                  row.remarks,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isPassed ? const Color(0xFF047857) : crRed,
                  ),
                ),
              ],
            ),
          );

    // Descriptor Widget
    final descColor = _descriptorColor(row.descriptor);
    final descriptorWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: descColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: descColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        row.descriptor,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: descColor),
      ),
    );

    // Grade Badge
    final gradeBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? Colors.white12 : crBorder),
      ),
      child: Text(
        row.activeGrade != null ? '${row.activeGrade}' : '—',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : crSlateDark,
        ),
      ),
    );

    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: index % 2 == 1
            ? (isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFFAFAFB))
            : (isDark ? Colors.transparent : Colors.white),
        border: const Border(bottom: BorderSide(color: crBorder)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              '${row.rank}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: crSlateMuted),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: nameWidget,
            ),
          ),
          SizedBox(
            width: 130,
            child: Text(
              row.lrn,
              style: const TextStyle(fontSize: 12.5, color: crSlateMuted, fontFamily: 'monospace'),
            ),
          ),
          if (isCrossTerm) ...[
            for (final t in activeTerms)
              SizedBox(
                width: 85,
                child: Text(
                  row.termGrades[t] != null ? '${row.termGrades[t]}' : '—',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : crSlateDark,
                  ),
                ),
              ),
            SizedBox(
              width: 105,
              child: Align(
                alignment: Alignment.centerLeft,
                child: gradeBadge,
              ),
            ),
          ] else ...[
            SizedBox(
              width: 95,
              child: Text(
                row.wwPs != null ? '${row.wwPs}%' : '—',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : crSlateDark),
              ),
            ),
            SizedBox(
              width: 95,
              child: Text(
                row.ptPs != null ? '${row.ptPs}%' : '—',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : crSlateDark),
              ),
            ),
            SizedBox(
              width: 95,
              child: Text(
                row.exPs != null ? '${row.exPs}%' : '—',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : crSlateDark),
              ),
            ),
            SizedBox(
              width: 110,
              child: Align(
                alignment: Alignment.centerLeft,
                child: gradeBadge,
              ),
            ),
          ],
          SizedBox(
            width: 110,
            child: Align(
              alignment: Alignment.centerLeft,
              child: trendWidget,
            ),
          ),
          SizedBox(
            width: 130,
            child: Align(
              alignment: Alignment.centerLeft,
              child: descriptorWidget,
            ),
          ),
          SizedBox(
            width: 110,
            child: Align(
              alignment: Alignment.centerLeft,
              child: remarksWidget,
            ),
          ),
        ],
      ),
    );
  }

  Color _descriptorColor(String descriptor) {
    switch (descriptor) {
      case 'Advancing':
        return crEmerald;
      case 'Benchmarking':
        return crSteelBlue;
      case 'Connecting':
        return crAmber;
      case 'Developing':
      case 'Emerging':
        return crRed;
      default:
        return crSlateMuted;
    }
  }

  Widget _buildPageButton(
    String label,
    VoidCallback onTap,
    bool enabled, {
    bool isActive = false,
  }) {
    return InkWell(
      onTap: enabled && !isActive ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? crSteelBlue : (enabled ? Colors.white : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isActive ? crSteelBlue : crBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : (enabled ? crSlateDark : Colors.black26),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(bool isDark) {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      filled: true,
      fillColor: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: crBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: crBorder),
      ),
    );
  }
}

class _BarItem {
  final String label;
  final String sub;
  final double value;
  final Color color;

  const _BarItem({
    required this.label,
    required this.sub,
    required this.value,
    required this.color,
  });
}

class _DonutChartPainter extends CustomPainter {
  final List<DonutSliceData> slices;
  final double progress;
  final double strokeWidth;

  _DonutChartPainter({
    required this.slices,
    required this.progress,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track Ring
    final trackPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    if (slices.isEmpty) return;

    var startAngle = -math.pi / 2;

    for (final slice in slices) {
      final sweepAngle = (slice.pct / 100) * 2 * math.pi * progress;

      final slicePaint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        slicePaint,
      );

      startAngle += (slice.pct / 100) * 2 * math.pi;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.slices != slices;
  }
}
