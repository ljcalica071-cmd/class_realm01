import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:class_realm/core/services/gemini_service.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/features/teacher/sub_features/schedule_and_lessons/models/ilaw_lesson_plan.dart';
import 'package:class_realm/features/teacher/sub_features/schedule_and_lessons/services/ilaw_file_downloader.dart';
import 'package:class_realm/features/teacher/sub_features/schedule_and_lessons/services/teacher_lesson_plan_store.dart';
import 'package:class_realm/features/teacher/sub_features/schedule_and_lessons/widgets/ilaw_lesson_plan_wizard_dialog.dart';

class TeacherLessonPlanningTab extends StatefulWidget {
  final List<LessonPlanModel> lessonPlans;
  final VoidCallback onPlanGenerated;
  final TeacherLessonPlanStore? store;
  final GeminiService? geminiService;
  final UserModel? Function()? currentUserProvider;
  final IlawFileSaveHandler? fileSaveHandler;

  const TeacherLessonPlanningTab({
    super.key,
    required this.lessonPlans,
    required this.onPlanGenerated,
    this.store,
    this.geminiService,
    this.currentUserProvider,
    this.fileSaveHandler,
  });

  @override
  State<TeacherLessonPlanningTab> createState() =>
      _TeacherLessonPlanningTabState();
}

class _TeacherLessonPlanningTabState extends State<TeacherLessonPlanningTab> {
  static const Color _errorRed = Color(0xFFDC2626);

  final TextEditingController _searchCtrl = TextEditingController();
  String _gradeFilter = 'All Grades';
  String _statusFilter = 'All Statuses';
  String _dateFilter = 'All Dates';
  DateTimeRange? _customDateRange;

  int _currentPage = 1;
  int _pageSize = 5;

  List<IlawLessonPlan> _plans = const [];
  bool _isLoading = true;
  String? _accessDeniedMessage;

  String? _inlineBannerMessage;
  bool _inlineBannerIsError = false;
  String? _activeExportTag;

  TeacherLessonPlanStore get _store =>
      widget.store ?? TeacherLessonPlanStore.instance;

  GeminiService get _gemini => widget.geminiService ?? GeminiService.instance;

  UserModel? get _activeTeacher =>
      (widget.currentUserProvider ??
      (() => AuthRepository.instance.currentUser))();

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  @override
  void didUpdateWidget(covariant TeacherLessonPlanningTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store ||
        oldWidget.currentUserProvider != widget.currentUserProvider) {
      _loadPlans();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _isLoading = true;
      _accessDeniedMessage = null;
    });

    try {
      final loaded = await _store.loadPlansForCurrentTeacher();
      if (!mounted) return;
      setState(() {
        _plans = loaded;
        _isLoading = false;
        if (_currentPage > _totalPages) {
          _currentPage = math.max(1, _totalPages);
        }
      });
    } on LessonPlanAccessDeniedException catch (e) {
      if (!mounted) return;
      setState(() {
        _plans = const [];
        _isLoading = false;
        _accessDeniedMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _plans = const [];
        _isLoading = false;
        _inlineBannerIsError = true;
        _inlineBannerMessage =
            'Unable to load your saved lesson plans right now.';
      });
    }
  }

  Future<void> _openWizard({
    IlawLessonPlan? existingPlan,
    IlawWizardStep initialStep = IlawWizardStep.details,
  }) async {
    if (_accessDeniedMessage != null) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => IlawLessonPlanWizardDialog(
        existingPlan: existingPlan,
        initialStep: initialStep,
        store: _store,
        geminiService: _gemini,
        currentTeacher: _activeTeacher,
        fileSaveHandler: widget.fileSaveHandler,
        onSaved: () {
          _loadPlans();
          widget.onPlanGenerated();
        },
      ),
    );
    if (mounted) {
      await _loadPlans();
    }
  }

  Future<void> _handleQuickExport(
    IlawLessonPlan plan,
    IlawExportFormat format,
  ) async {
    final tag = '${plan.id}_${format.name}';
    setState(() {
      _activeExportTag = tag;
      _inlineBannerMessage = null;
    });

    try {
      final msg = await IlawFileDownloader.exportAndDownload(
        plan: plan,
        format: format,
        customSaveHandler: widget.fileSaveHandler,
      );
      if (!mounted) return;
      setState(() {
        _activeExportTag = null;
        _inlineBannerIsError = false;
        _inlineBannerMessage = msg;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _activeExportTag = null;
        _inlineBannerIsError = true;
        _inlineBannerMessage = 'Export failed: $e';
      });
    }
  }

  Future<void> _confirmAndDeletePlan(IlawLessonPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text(
            'Delete Lesson Plan?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          content: Text(
            'Remove "${plan.topic}" (${plan.subject} • ${plan.gradeLevel}) from your private lesson plans? This action cannot be undone.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
            ),
          ),
          actions: [
            AppButton.outline(
              label: 'Cancel',
              isSmall: true,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            AppButton.danger(
              label: 'Delete Plan',
              isSmall: true,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await _store.deletePlan(plan.id);
      await _loadPlans();
      if (!mounted) return;
      setState(() {
        _inlineBannerIsError = false;
        _inlineBannerMessage = 'Deleted "${plan.topic}" from your saved plans.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _inlineBannerIsError = true;
        _inlineBannerMessage = e.toString();
      });
    }
  }

  bool _matchesDateFilter(DateTime dt) {
    final localDt = dt.toLocal();
    final now = DateTime.now();

    switch (_dateFilter) {
      case 'Today':
        return localDt.year == now.year &&
            localDt.month == now.month &&
            localDt.day == now.day;
      case 'This Week':
        final startOfWeek = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(
          const Duration(days: 7, microseconds: -1),
        );
        return !localDt.isBefore(startOfWeek) && !localDt.isAfter(endOfWeek);
      case 'This Month':
        return localDt.year == now.year && localDt.month == now.month;
      case 'Custom Range':
        if (_customDateRange == null) return true;
        final start = DateTime(
          _customDateRange!.start.year,
          _customDateRange!.start.month,
          _customDateRange!.start.day,
        );
        final end = DateTime(
          _customDateRange!.end.year,
          _customDateRange!.end.month,
          _customDateRange!.end.day,
          23,
          59,
          59,
          999,
        );
        return !localDt.isBefore(start) && !localDt.isAfter(end);
      case 'All Dates':
      default:
        return true;
    }
  }

  Future<void> _handleDateFilterChange(String? value) async {
    if (value == null) return;
    if (value == 'Custom Range') {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final min2026 = DateTime(2026, 1, 1);
      final lastAllowed = today.isBefore(min2026) ? min2026 : today;

      DateTimeRange? initialRange;
      if (_customDateRange != null) {
        var start = _customDateRange!.start;
        var end = _customDateRange!.end;
        if (start.isBefore(min2026)) start = min2026;
        if (start.isAfter(lastAllowed)) start = lastAllowed;
        if (end.isBefore(start)) end = start;
        if (end.isAfter(lastAllowed)) end = lastAllowed;
        initialRange = DateTimeRange(start: start, end: end);
      } else {
        var defaultStart = today.subtract(const Duration(days: 7));
        if (defaultStart.isBefore(min2026)) defaultStart = min2026;
        initialRange = DateTimeRange(start: defaultStart, end: lastAllowed);
      }

      final picked = await showDateRangePicker(
        context: context,
        firstDate: min2026,
        lastDate: lastAllowed,
        currentDate: today,
        initialDateRange: initialRange,
        helpText: 'Select Date Range',
        saveText: 'Save',
      );
      if (picked != null) {
        setState(() {
          _dateFilter = 'Custom Range';
          _customDateRange = picked;
          _currentPage = 1;
        });
      }
    } else {
      setState(() {
        _dateFilter = value;
        _customDateRange = null;
        _currentPage = 1;
      });
    }
  }

  String _formatShortDate(DateTime dt) =>
      '${dt.month}/${dt.day}/${dt.year}';

  List<IlawLessonPlan> get _filteredPlans {
    final query = _searchCtrl.text.trim().toLowerCase();
    return _plans.where((plan) {
      if (_gradeFilter != 'All Grades' && plan.gradeLevel != _gradeFilter) {
        return false;
      }
      if (_statusFilter == 'Approved' && !plan.isApproved) {
        return false;
      }
      if (_statusFilter == 'Draft' && plan.isApproved) {
        return false;
      }
      if (!_matchesDateFilter(plan.updatedAt)) {
        return false;
      }
      if (query.isNotEmpty) {
        final haystack =
            '${plan.topic} ${plan.subject} ${plan.gradeLevel} ${plan.term}'
                .toLowerCase();
        if (!haystack.contains(query)) return false;
      }
      return true;
    }).toList();
  }

  int get _totalPages {
    final count = _filteredPlans.length;
    if (count == 0) return 1;
    return ((count - 1) ~/ _pageSize) + 1;
  }

  List<IlawLessonPlan> get _paginatedPlans {
    final filtered = _filteredPlans;
    if (filtered.isEmpty) return const [];
    final total = _totalPages;
    final page = _currentPage.clamp(1, total);
    final start = (page - 1) * _pageSize;
    final end = math.min(start + _pageSize, filtered.length);
    if (start >= filtered.length) return const [];
    return filtered.sublist(start, end);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyCount = _gemini.configuredKeyCount;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme, keyCount),
          if (_inlineBannerMessage != null) ...[
            const SizedBox(height: 16),
            _buildInlineBanner(theme),
          ],
          if (!_isLoading &&
              _accessDeniedMessage == null &&
              _plans.isNotEmpty) ...[
            const SizedBox(height: 18),
            _buildFilterBar(theme),
          ],
          const SizedBox(height: 18),
          Expanded(child: _buildMainContent(theme)),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, int keyCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 760;
        final cloudSyncSuccess = _store.lastSyncCloudSuccess == true;

        final infoSection = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'ILAW Format',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                _buildSubtlePill(
                  theme,
                  icon: Icons.lock_outline,
                  label: 'Private to Teacher',
                  accent: theme.colorScheme.primary,
                ),
                _buildSubtlePill(
                  theme,
                  icon: keyCount > 0
                      ? Icons.bolt_outlined
                      : Icons.science_outlined,
                  label: keyCount > 0
                      ? 'Gemini AI Ready'
                      : 'Sample Draft Ready',
                  accent: keyCount > 0
                      ? AppTheme.catGreen
                      : AppTheme.catSlate,
                ),
                _buildSubtlePill(
                  theme,
                  icon: cloudSyncSuccess
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_outlined,
                  label: cloudSyncSuccess
                      ? 'Cloud Synced'
                      : 'Local Storage Active',
                  accent: cloudSyncSuccess
                      ? AppTheme.catGreen
                      : AppTheme.catOrange,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Senior High School Strengthened Curriculum  •  Generate with AI, review & edit, format in minimalist iLAW, and export Word (.docx) or PDF (.pdf).',
              style: TextStyle(
                fontSize: 12.8,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
              ),
            ),
          ],
        );

        final actionBtn = AppButton.primary(
          label: 'Generate New Lesson Plan',
          icon: Icons.auto_awesome_outlined,
          onPressed: _accessDeniedMessage != null ? null : () => _openWizard(),
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              infoSection,
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: actionBtn,
              ),
            ],
          );
        }

        return SizedBox(
          width: double.infinity,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: infoSection),
              const SizedBox(width: 16),
              actionBtn,
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubtlePill(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: accent),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineBanner(ThemeData theme) {
    final accent = _inlineBannerIsError ? _errorRed : AppTheme.catGreen;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            _inlineBannerIsError
                ? Icons.error_outline
                : Icons.check_circle_outline,
            size: 18,
            color: accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _inlineBannerMessage!,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: _inlineBannerIsError
                    ? _errorRed
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _inlineBannerMessage = null),
            icon: Icon(
              Icons.close,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
          child: TextField(
            key: const Key('ilaw_search_field'),
            controller: _searchCtrl,
            onChanged: (_) => setState(() {
              _currentPage = 1;
            }),
            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Search topic or subject...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.42),
              ),
              prefixIcon: Icon(
                Icons.search,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {
                          _currentPage = 1;
                        });
                      },
                      icon: const Icon(Icons.close, size: 16),
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.14),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 1.4,
                ),
              ),
            ),
          ),
        ),
        _buildFilterDropdown(
          theme: theme,
          value: _gradeFilter,
          items: const ['All Grades', 'Grade 11', 'Grade 12'],
          onChanged: (v) {
            if (v != null) {
              setState(() {
                _gradeFilter = v;
                _currentPage = 1;
              });
            }
          },
        ),
        _buildFilterDropdown(
          theme: theme,
          value: _statusFilter,
          items: const ['All Statuses', 'Approved', 'Draft'],
          onChanged: (v) {
            if (v != null) {
              setState(() {
                _statusFilter = v;
                _currentPage = 1;
              });
            }
          },
        ),
        _buildFilterDropdown(
          theme: theme,
          value: _dateFilter,
          items: const [
            'All Dates',
            'Today',
            'This Week',
            'This Month',
            'Custom Range',
          ],
          onChanged: _handleDateFilterChange,
        ),
        if (_dateFilter == 'Custom Range' && _customDateRange != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.date_range,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '${_formatShortDate(_customDateRange!.start)} - ${_formatShortDate(_customDateRange!.end)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    setState(() {
                      _dateFilter = 'All Dates';
                      _customDateRange = null;
                      _currentPage = 1;
                    });
                  },
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFilterDropdown({
    required ThemeData theme,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(theme.colorScheme.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(6),
        shadowColor: WidgetStatePropertyAll(
          Colors.black.withValues(alpha: 0.16),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 4),
        ),
        minimumSize: const WidgetStatePropertyAll(Size(140, 0)),
        side: WidgetStatePropertyAll(
          BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
          ),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      menuChildren: items.map((item) {
        final isSelected = item == value;
        return MenuItemButton(
          onPressed: () => onChanged(item),
          style: ButtonStyle(
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (isSelected) {
                return theme.colorScheme.primary.withValues(alpha: 0.10);
              }
              if (states.contains(WidgetState.hovered)) {
                return theme.colorScheme.onSurface.withValues(alpha: 0.05);
              }
              return Colors.transparent;
            }),
          ),
          trailingIcon: isSelected
              ? Icon(Icons.check, size: 15, color: theme.colorScheme.primary)
              : null,
          child: Text(
            item,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
            ),
          ),
        );
      }).toList(),
      builder: (context, controller, child) {
        final isOpen = controller.isOpen;
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isOpen
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.14),
                width: isOpen ? 1.4 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  isOpen
                        ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainContent(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.2),
        ),
      );
    }

    if (_accessDeniedMessage != null) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _errorRed.withValues(alpha: 0.28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 36, color: _errorRed),
              const SizedBox(height: 12),
              Text(
                'Private Teacher Workspace',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _accessDeniedMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_plans.isEmpty) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.description_outlined,
                  size: 26,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No SHS iLAW lesson plans yet',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Click "Generate New Lesson Plan" above to create a Senior High School iLAW lesson plan with Gemini AI, review and customize all sections, and download a formatted Word (.docx) or PDF (.pdf) file.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.64),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final visible = _filteredPlans;
    if (visible.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list_off,
              size: 32,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 10),
            Text(
              'No lesson plans match your current search or filter.',
              style: TextStyle(
                fontSize: 13.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
              ),
            ),
            const SizedBox(height: 12),
            AppButton.outline(
              label: 'Reset Filters',
              isSmall: true,
              onPressed: () {
                setState(() {
                  _searchCtrl.clear();
                  _gradeFilter = 'All Grades';
                  _statusFilter = 'All Statuses';
                  _dateFilter = 'All Dates';
                  _customDateRange = null;
                  _currentPage = 1;
                });
              },
            ),
          ],
        ),
      );
    }

    final paginated = _paginatedPlans;

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: paginated.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (ctx, idx) => _buildLessonPlanCard(theme, paginated[idx]),
          ),
        ),
        const SizedBox(height: 14),
        _buildPaginationToolbar(theme, totalItems: visible.length),
      ],
    );
  }

  Widget _buildPaginationToolbar(ThemeData theme, {required int totalItems}) {
    final total = _totalPages;
    final safePage = _currentPage.clamp(1, total);
    final start = totalItems == 0 ? 0 : ((safePage - 1) * _pageSize) + 1;
    final end = math.min(safePage * _pageSize, totalItems);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 620;

        final infoText = Text(
          'Showing $start–$end of $totalItems lesson plans',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        );

        final pageSizeDropdown = _buildFilterDropdown(
          theme: theme,
          value: '$_pageSize per page',
          items: const ['5 per page', '10 per page', '20 per page'],
          onChanged: (val) {
            if (val == null) return;
            final numVal = int.tryParse(val.split(' ').first);
            if (numVal != null && numVal != _pageSize) {
              setState(() {
                _pageSize = numVal;
                _currentPage = 1;
              });
            }
          },
        );

        final pageNav = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Previous page',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_left, size: 20),
              onPressed: safePage > 1
                  ? () => setState(() => _currentPage = safePage - 1)
                  : null,
            ),
            const SizedBox(width: 4),
            ..._buildPageNumbers(theme, total: total, current: safePage),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Next page',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_right, size: 20),
              onPressed: safePage < total
                  ? () => setState(() => _currentPage = safePage + 1)
                  : null,
            ),
          ],
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  infoText,
                  pageSizeDropdown,
                ],
              ),
              const SizedBox(height: 10),
              Center(child: pageNav),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                infoText,
                const SizedBox(width: 14),
                pageSizeDropdown,
              ],
            ),
            pageNav,
          ],
        );
      },
    );
  }

  List<Widget> _buildPageNumbers(
    ThemeData theme, {
    required int total,
    required int current,
  }) {
    final widgets = <Widget>[];
    final pages = <int>{};
    pages.add(1);
    pages.add(total);
    for (int p = math.max(1, current - 1); p <= math.min(total, current + 1); p++) {
      pages.add(p);
    }
    final sortedPages = pages.toList()..sort();

    int last = 0;
    for (final p in sortedPages) {
      if (last > 0 && p - last > 1) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '...',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        );
      }
      final isSelected = p == current;
      widgets.add(
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _currentPage = p),
          child: Container(
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            alignment: Alignment.center,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.12),
              ),
            ),
            child: Text(
              '$p',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      );
      last = p;
    }
    return widgets;
  }

  Widget _buildLessonPlanCard(ThemeData theme, IlawLessonPlan plan) {
    final dateStr = plan.updatedAt.toLocal().toString().split(' ').first;
    final isApproved = plan.isApproved;
    final exportingDocx = _activeExportTag == '${plan.id}_docx';
    final exportingPdf = _activeExportTag == '${plan.id}_pdf';

    return Container(
      key: ValueKey('ilaw_plan_card_${plan.id}'),
      padding: const EdgeInsets.all(20),
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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                '${plan.subject}  •  ${plan.gradeLevel}  •  ${plan.term}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: theme.colorScheme.primary,
                ),
              ),
              StatusBadge(
                text: isApproved ? 'Approved iLAW' : 'Draft • Pending Approval',
                backgroundColor: isApproved
                    ? AppTheme.catGreen.withValues(alpha: 0.12)
                    : AppTheme.catOrange.withValues(alpha: 0.12),
                textColor: isApproved ? AppTheme.catGreen : AppTheme.catOrange,
                icon: isApproved
                    ? Icons.check_circle_outline
                    : Icons.edit_note_outlined,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            plan.topic,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${plan.durationMinutes} mins  •  Updated $dateStr${plan.teachingStrategy.isNotEmpty ? '  •  ${plan.teachingStrategy}' : ''}',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.56),
            ),
          ),
          if (plan.intendedOutcomes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              plan.intendedOutcomes,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.48,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Divider(
            height: 1,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AppButton.outline(
                    label: 'Review & Edit',
                    icon: Icons.edit_outlined,
                    isSmall: true,
                    onPressed: () => _openWizard(
                      existingPlan: plan,
                      initialStep: IlawWizardStep.reviewEdit,
                    ),
                  ),
                  if (isApproved)
                    AppButton.outline(
                      label: 'View iLAW Format',
                      icon: Icons.visibility_outlined,
                      isSmall: true,
                      onPressed: () => _openWizard(
                        existingPlan: plan,
                        initialStep: IlawWizardStep.previewExport,
                      ),
                    )
                  else
                    AppButton.success(
                      label: 'Approve & Format',
                      icon: Icons.check_circle_outline,
                      isSmall: true,
                      onPressed: () => _openWizard(
                        existingPlan: plan,
                        initialStep: IlawWizardStep.reviewEdit,
                      ),
                    ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (isApproved) ...[
                    AppButton.outline(
                      label: 'DOCX',
                      icon: Icons.description_outlined,
                      isSmall: true,
                      isLoading: exportingDocx,
                      onPressed: (_activeExportTag != null)
                          ? null
                          : () =>
                                _handleQuickExport(plan, IlawExportFormat.docx),
                    ),
                    AppButton.outline(
                      label: 'PDF',
                      icon: Icons.picture_as_pdf_outlined,
                      isSmall: true,
                      isLoading: exportingPdf,
                      onPressed: (_activeExportTag != null)
                          ? null
                          : () =>
                                _handleQuickExport(plan, IlawExportFormat.pdf),
                    ),
                  ],
                  IconButton(
                    tooltip: 'Delete lesson plan',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _confirmAndDeletePlan(plan),
                    icon: Icon(
                      Icons.delete_outline,
                      size: 19,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
