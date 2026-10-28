import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/features/teacher/sub_features/class_management/widgets/unified_enroll_student_dialog.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/features/teacher/sub_features/setup/widgets/teacher_classroom_setup_templates.dart';
import 'package:class_realm/core/theme/subject_palette.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:class_realm/shared/widgets/shimmer_loading.dart';

/// A section the teacher handles for a subject.
class _ClassSection {
  final String id;
  final String name;
  int studentCount;

  _ClassSection({
    required this.id,
    required this.name,
    this.studentCount = 0,
  });
}

/// Classroom Setup View Mode
enum _ClassroomViewMode { active, archivedSubjects, archivedSections }

/// A subject the teacher teaches, with grading config and sections.
class _SubjectClass {
  final String id;
  final String subjectId;
  final String name;
  final String gradeLevel;
  final int wwWeight;
  final int ptWeight;
  final int exWeight;
  final int termsTaught;
  final String termBlock;
  final double unitsPerTerm;
  final double st1Weight;
  final double st2Weight;
  final double teWeight;
  final List<_ClassSection> sections;

  _SubjectClass({
    required this.id,
    required this.subjectId,
    required this.name,
    required this.gradeLevel,
    required this.wwWeight,
    required this.ptWeight,
    required this.exWeight,
    this.termsTaught = 3,
    this.termBlock = '1ST, 2ND, 3RD',
    this.unitsPerTerm = 2.0,
    this.st1Weight = 30.0,
    this.st2Weight = 30.0,
    this.teWeight = 40.0,
    required this.sections,
  });

  int get studentCount =>
      sections.fold(0, (total, section) => total + section.studentCount);
}

/// Editable section row inside the add form.
class _SectionRowDraft {
  final String id;
  final bool isExisting;
  final TextEditingController nameCtrl = TextEditingController();
  final FocusNode focusNode = FocusNode();

  _SectionRowDraft(this.id, {this.isExisting = false});

  void dispose() {
    nameCtrl.dispose();
    focusNode.dispose();
  }
}

class TeacherClassroomSetupTab extends StatefulWidget {
  final ValueChanged<int>? onNavigateTo;

  const TeacherClassroomSetupTab({super.key, this.onNavigateTo});

  @override
  State<TeacherClassroomSetupTab> createState() =>
      _TeacherClassroomSetupTabState();
}

class _TeacherClassroomSetupTabState extends State<TeacherClassroomSetupTab> {
  static const int _maxSections = 10;
  static const int _maxSubjects = 10;
  static const List<String> _gradeLevels = ['Grade 11', 'Grade 12'];

  // Inherited from dashboard context
  final String _currentSchoolYear = '2026-2027';

  bool _showAddForm = false;
  _ClassroomViewMode _viewMode = _ClassroomViewMode.active;
  bool get _isViewingArchived => _viewMode != _ClassroomViewMode.active;
  _SubjectClass? _editingSubject;

  final List<_SubjectClass> _subjects = [];
  final List<_SubjectClass> _archivedSubjects = [];
  final List<_SubjectClass> _archivedSectionsSubjects = [];
  int _archivedSectionsCount = 0;

  // ── Form state ──
  SubjectTemplate? _selectedTemplate;
  final _subjectCtrl = TextEditingController();
  final _subjectFocus = FocusNode();
  String _gradeLevel = _gradeLevels.first;
  int _termsTaught = 3;
  String _termBlock = '1ST, 2ND, 3RD';
  double _unitsPerTerm = 2;
  double _st1Weight = 30;
  double _st2Weight = 30;
  double _teWeight = 40;

  // Grading Weights
  final _wwCtrl = TextEditingController();
  final _ptCtrl = TextEditingController();
  final _exCtrl = TextEditingController();

  final List<_SectionRowDraft> _sectionRows = [];

  // ── Validation state ──
  bool _submitted = false;
  String? _subjectError;
  String? _termBlockError;
  final Map<String, String> _sectionErrors = {};

  bool _isLoadingSubjects = false;
  bool _isSaving = false;

  int _idCounter = 0;
  String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

  @override
  void initState() {
    super.initState();
    _sectionRows.add(_SectionRowDraft(_newId('row')));

    _loadSubjects();

    // Listen to weight changes to trigger rebuilds for the total sum text
    _wwCtrl.addListener(() => setState(() {}));
    _ptCtrl.addListener(() => setState(() {}));
    _exCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _subjectFocus.dispose();
    _wwCtrl.dispose();
    _ptCtrl.dispose();
    _exCtrl.dispose();
    for (final row in _sectionRows) {
      row.dispose();
    }
    super.dispose();
  }

  int get _currentWeightTotal {
    final ww = int.tryParse(_wwCtrl.text) ?? 0;
    final pt = int.tryParse(_ptCtrl.text) ?? 0;
    final ex = int.tryParse(_exCtrl.text) ?? 0;
    return ww + pt + ex;
  }

  bool get _isWeightValid => _currentWeightTotal == 100;

  List<SubjectTemplate> get _availableTemplates {
    return defaultSubjectTemplates;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Custom Constrained Dialog Helper (Prevents overly wide stretched dialogs)
  // ─────────────────────────────────────────────────────────────────────────
  Future<T?> _showConstrainedDialog<T>({
    required BuildContext context,
    required Widget child,
    double maxWidth = 460,
  }) {
    final theme = Theme.of(context);
    return showDialog<T>(
      context: context,
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Dialog(
            backgroundColor: theme.colorScheme.surface,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            child: Padding(padding: const EdgeInsets.all(24), child: child),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = AuthRepository.instance.currentUser;
    final teacherName = currentUser?.fullName ?? 'Teacher';
    final nameTitle = currentUser?.honorific.isNotEmpty == true
        ? currentUser!.honorific
        : ((currentUser?.gender?.trim().toLowerCase() == 'female' ||
                  currentUser?.gender?.trim().toLowerCase() == 'f')
              ? "Ma'am"
              : "Sir");

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top Header Card ──
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.outline.withValues(
                  alpha: isDark ? 0.2 : 0.4,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 700;
                  final headerLeft = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          LucideIcons.building,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "$nameTitle $teacherName's Classroom",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'SY $_currentSchoolYear · Trimester Curriculum',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );

                  final headerActions = Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      AppButton.outline(
                        icon: LucideIcons.calendar,
                        label: 'Timetable & Schedule',
                        onPressed: () => widget.onNavigateTo?.call(14),
                      ),
                      if (!_isViewingArchived)
                        AppButton.primary(
                          icon: _showAddForm
                              ? LucideIcons.x
                              : LucideIcons.plus,
                          label: _showAddForm
                              ? (_editingSubject != null ? 'Close Edit' : 'Close Form')
                              : 'Add Subject',
                          onPressed: _handleAddSubjectClick,
                        ),
                    ],
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        headerLeft,
                        const SizedBox(height: 16),
                        headerActions,
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [headerLeft, headerActions],
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Section Title Bar ──
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 720;

              final titleWidget = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _viewMode == _ClassroomViewMode.active
                        ? LucideIcons.bookOpen
                        : (_viewMode == _ClassroomViewMode.archivedSubjects
                            ? LucideIcons.archive
                            : LucideIcons.layers),
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _viewMode == _ClassroomViewMode.active
                        ? 'ACTIVE SUBJECTS'
                        : (_viewMode == _ClassroomViewMode.archivedSubjects
                            ? 'ARCHIVED SUBJECTS'
                            : 'ARCHIVED SECTIONS'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              );

              final actionButtons = Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_viewMode == _ClassroomViewMode.active) ...[
                    AppButton.outline(
                      icon: LucideIcons.archive,
                      label: 'Archived Subjects (${_archivedSubjects.length})',
                      onPressed: () {
                        setState(() {
                          _viewMode = _ClassroomViewMode.archivedSubjects;
                          _showAddForm = false;
                          _editingSubject = null;
                        });
                      },
                    ),
                    AppButton.outline(
                      icon: LucideIcons.layers,
                      label: 'Archived Sections ($_archivedSectionsCount)',
                      onPressed: () {
                        setState(() {
                          _viewMode = _ClassroomViewMode.archivedSections;
                          _showAddForm = false;
                          _editingSubject = null;
                        });
                      },
                    ),
                  ] else if (_viewMode == _ClassroomViewMode.archivedSubjects) ...[
                    AppButton.outline(
                      icon: LucideIcons.bookOpen,
                      label: 'Active Subjects (${_subjects.length})',
                      onPressed: () {
                        setState(() {
                          _viewMode = _ClassroomViewMode.active;
                          _showAddForm = false;
                          _editingSubject = null;
                        });
                      },
                    ),
                    AppButton.outline(
                      icon: LucideIcons.layers,
                      label: 'Archived Sections ($_archivedSectionsCount)',
                      onPressed: () {
                        setState(() {
                          _viewMode = _ClassroomViewMode.archivedSections;
                          _showAddForm = false;
                          _editingSubject = null;
                        });
                      },
                    ),
                  ] else ...[
                    AppButton.outline(
                      icon: LucideIcons.bookOpen,
                      label: 'Active Subjects (${_subjects.length})',
                      onPressed: () {
                        setState(() {
                          _viewMode = _ClassroomViewMode.active;
                          _showAddForm = false;
                          _editingSubject = null;
                        });
                      },
                    ),
                    AppButton.outline(
                      icon: LucideIcons.archive,
                      label: 'Archived Subjects (${_archivedSubjects.length})',
                      onPressed: () {
                        setState(() {
                          _viewMode = _ClassroomViewMode.archivedSubjects;
                          _showAddForm = false;
                          _editingSubject = null;
                        });
                      },
                    ),
                  ],
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    titleWidget,
                    const SizedBox(height: 10),
                    actionButtons,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [titleWidget, actionButtons],
              );
            },
          ),

          const SizedBox(height: 14),

          // ── Add Subject Form (collapsible) ──
          if (_showAddForm && !_isViewingArchived) ...[
            _buildAddSubjectForm(),
            const SizedBox(height: 20),
          ],

          // ── Main Content Area ──
          _isLoadingSubjects
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth >= 950 ? 2 : 1;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        mainAxisExtent: 340,
                      ),
                      itemCount: 4,
                      itemBuilder: (_, _) => const ShimmerTeacherSubjectCard(),
                    );
                  },
                )
              : _viewMode == _ClassroomViewMode.archivedSubjects
              ? _buildArchivedView()
              : _viewMode == _ClassroomViewMode.archivedSections
              ? _buildArchivedSectionsView()
              : _buildActiveView(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Handle Add Subject Click (Validates Max 10 without displaying "Max 10")
  // ─────────────────────────────────────────────────────────────────────────
  void _handleAddSubjectClick() {
    if (_subjects.length >= _maxSubjects) {
      _showLimitErrorDialog(
        title: 'Subject Limit Reached',
        message:
            'You have reached the maximum allowed number of subjects for this classroom. '
            'Please archive an existing subject before adding a new one.',
      );
      return;
    }

    if (_showAddForm) {
      _resetForm(close: true);
    } else {
      setState(() => _showAddForm = true);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _subjectFocus.requestFocus(),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Limit Notice Dialog
  // ─────────────────────────────────────────────────────────────────────────
  void _showLimitErrorDialog({required String title, required String message}) {
    _showConstrainedDialog(
      context: context,
      maxWidth: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.alertTriangle,
                  color: Colors.amber,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton.primary(
              label: 'Understood',
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Active Subjects View
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildActiveView() {
    if (_subjects.isEmpty) {
      return _buildEmptyClassroomState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 950 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 340,
          ),
          itemCount: _subjects.length,
          itemBuilder: (context, index) {
            return _buildResponsiveSubjectCard(
              _subjects[index],
              isArchived: false,
              index: index,
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Archived Subjects View & Empty State
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildArchivedView() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_archivedSubjects.isEmpty) {
      return Container(
        height: 260,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark
              ? theme.colorScheme.surface
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(
              alpha: isDark ? 0.2 : 0.3,
            ),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.archive,
                size: 32,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No Archived Subjects',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Subjects you archive will be stored here safely.\nYou can restore them to active status anytime or delete them permanently.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 950 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 340,
          ),
          itemCount: _archivedSubjects.length,
          itemBuilder: (context, index) {
            return _buildResponsiveSubjectCard(
              _archivedSubjects[index],
              isArchived: true,
              index: index,
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Responsive Redesigned Subject Card
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildResponsiveSubjectCard(
    _SubjectClass subject, {
    required bool isArchived,
    int index = 0,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final sectionCount = subject.sections.length;

    // Deterministic unique accessible color per teacher's subjects
    final cardAccentColor = SubjectPalette.getColorForSubject(
      subject.name,
      teacherSubjectNames: (isArchived ? _archivedSubjects : _subjects)
          .map((s) => s.name)
          .toList(),
      index: index,
    );

    return Container(
      decoration: BoxDecoration(
        color: isArchived
            ? (isDark
                  ? theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.2,
                    )
                  : const Color(0xFFF8F9FA))
            : (isDark ? theme.colorScheme.surface : Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isArchived
              ? theme.colorScheme.outline.withValues(alpha: 0.2)
              : cardAccentColor.withValues(alpha: isDark ? 0.35 : 0.22),
          width: 1.2,
        ),
        boxShadow: isArchived
            ? []
            : [
                BoxShadow(
                  color: cardAccentColor.withValues(
                    alpha: isDark ? 0.12 : 0.05,
                  ),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Subject Info, Actions ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Clean Left-Aligned Subject Title and Grade (No avatar box)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildBadge(
                          subject.gradeLevel,
                          isPrimary: true,
                          compact: true,
                        ),
                        if (isArchived) ...[
                          const SizedBox(width: 6),
                          _buildBadge('Archived', subtle: true, compact: true),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subject.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isArchived ? muted : theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              // Archive / Edit Actions on Active Cards (Archived cards have actions in footer)
              if (!isArchived) ...[
                IconButton(
                  tooltip: 'Edit subject and sections',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(LucideIcons.pencil, size: 17, color: muted),
                  onPressed: () => _openEditSubjectForm(subject),
                ),
                IconButton(
                  tooltip: 'Archive subject',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(LucideIcons.archive, size: 17, color: muted),
                  onPressed: () => _confirmArchive(subject),
                ),
              ],
            ],
          ),

          const SizedBox(height: 10),

          // ── Stats Row: Total Sections & Total Students ──
          Row(
            children: [
              Icon(LucideIcons.layers, size: 13, color: muted),
              const SizedBox(width: 4),
              Text(
                '$sectionCount ${sectionCount == 1 ? 'section' : 'sections'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: muted,
                ),
              ),
              const SizedBox(width: 12),
              Icon(LucideIcons.users, size: 13, color: muted),
              const SizedBox(width: 4),
              Text(
                '${subject.studentCount} enrolled students',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: muted,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Grading Weights Pill Row ──
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _buildBadge(
                'WW ${subject.wwWeight}%',
                isPrimary: true,
                compact: true,
              ),
              _buildBadge(
                'PT ${subject.ptWeight}%',
                isPrimary: true,
                compact: true,
              ),
              _buildBadge(
                subject.exWeight == 0 ? 'NO EXAM' : 'EX ${subject.exWeight}%',
                isPrimary: true,
                compact: true,
              ),
            ],
          ),

          const SizedBox(height: 10),
          Divider(
            height: 1,
            color: theme.colorScheme.outline.withValues(alpha: 0.18),
          ),
          const SizedBox(height: 8),

          // ── Sections Area (Scrollable if many sections) ──
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: subject.sections.length,
              separatorBuilder: (_, _) => const SizedBox(height: 5),
              itemBuilder: (context, idx) {
                final sec = subject.sections[idx];
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.22,
                          )
                        : theme.colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.4,
                          ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(
                        alpha: isDark ? 0.15 : 0.2,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: cardAccentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          LucideIcons.users,
                          size: 12,
                          color: cardAccentColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          sec.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${sec.studentCount} students',
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                      if (!isArchived) ...[
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _openEnrollmentDialog(
                            initialSubjectId: sec.id,
                            initialSectionName: sec.name,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Tooltip(
                              message: 'Enroll to ${sec.name}',
                              child: Icon(
                                LucideIcons.userPlus,
                                size: 14,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),
          Divider(
            height: 1,
            color: theme.colorScheme.outline.withValues(alpha: 0.18),
          ),
          const SizedBox(height: 10),

          // ── Footer Action Buttons ──
          if (!isArchived)
            SizedBox(
              width: double.infinity,
              child: AppButton.primary(
                icon: LucideIcons.userPlus,
                label: 'Add Students',
                onPressed: () {
                  final firstSec = subject.sections.isNotEmpty
                      ? subject.sections.first
                      : null;
                  _openEnrollmentDialog(
                    initialSubjectId: firstSec?.id,
                    initialSectionName: firstSec?.name,
                  );
                },
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: theme.colorScheme.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(LucideIcons.rotateCcw, size: 15),
                    label: const Text(
                      'Restore Subject',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () => _restoreSubject(subject),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: theme.colorScheme.error.withValues(
                        alpha: 0.08,
                      ),
                      side: BorderSide(color: theme.colorScheme.error),
                      foregroundColor: theme.colorScheme.error,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(LucideIcons.trash2, size: 15),
                    label: const Text(
                      'Delete Permanently',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () => _confirmPermanentDelete(subject),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _openEditSubjectForm(_SubjectClass subject) {
    for (final row in _sectionRows) {
      row.dispose();
    }
    _sectionRows.clear();
    for (final sec in subject.sections) {
      final draft = _SectionRowDraft(sec.id, isExisting: true);
      draft.nameCtrl.text = sec.name;
      _sectionRows.add(draft);
    }
    if (_sectionRows.isEmpty) {
      _sectionRows.add(_SectionRowDraft(_newId('row')));
    }

    setState(() {
      _selectedTemplate = defaultSubjectTemplates
          .cast<SubjectTemplate?>()
          .firstWhere(
            (t) =>
                t?.name.trim().toLowerCase() ==
                subject.name.trim().toLowerCase(),
            orElse: () => null,
          );
      _subjectCtrl.text = subject.name;
      _gradeLevel = subject.gradeLevel;
      _wwCtrl.text = subject.wwWeight.toString();
      _ptCtrl.text = subject.ptWeight.toString();
      _exCtrl.text = subject.exWeight.toString();
      _termsTaught = subject.termsTaught;
      _termBlock = subject.termBlock;
      _unitsPerTerm = subject.unitsPerTerm;
      _st1Weight = subject.st1Weight;
      _st2Weight = subject.st2Weight;
      _teWeight = subject.teWeight;
      _editingSubject = subject;
      _showAddForm = true;
      _submitted = false;
      _subjectError = null;
      _termBlockError = null;
      _sectionErrors.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subjectFocus.requestFocus();
    });
  }

  /// Universal, DRY confirmation dialog for Archive, Restore, and Delete actions
  Future<bool> _showActionConfirmationDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required IconData icon,
    Color? iconColor,
    Color? confirmButtonColor,
    Widget? detailsWidget,
    bool isDestructive = false,
  }) async {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final effectiveIconColor = iconColor ??
        (isDestructive ? theme.colorScheme.error : primaryColor);
    final effectiveBtnColor = confirmButtonColor ??
        (isDestructive ? theme.colorScheme.error : primaryColor);

    final result = await _showConstrainedDialog<bool>(
      context: context,
      maxWidth: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: effectiveIconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 22, color: effectiveIconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
          if (detailsWidget != null) ...[
            const SizedBox(height: 12),
            detailsWidget,
          ],
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: effectiveBtnColor,
                  foregroundColor: isDestructive
                      ? theme.colorScheme.onError
                      : theme.colorScheme.onPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: Icon(icon, size: 16),
                label: Text(
                  confirmLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Informative blocking dialog when academic records prevent permanent deletion
  void _showAcademicRecordsBlockedDialog({
    required String itemName,
    required bool isSection,
  }) {
    _showConstrainedDialog(
      context: context,
      maxWidth: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.shieldAlert,
                  size: 22,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Cannot Permanently Delete',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'The ${isSection ? "section" : "subject"} "$itemName" contains existing student grades, scores, or classwork submissions.',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline
                    .withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  LucideIcons.info,
                  size: 16,
                  color: Color(0xFF487898),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'To protect historical student records and grading accuracy, items with academic activity cannot be deleted. '
                    'They will remain safely stored in your Archive.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton.primary(
              label: 'Understood',
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  void _openEnrollmentDialog({
    String? initialSubjectId,
    String? initialSectionName,
  }) async {
    final teacherId = AuthRepository.instance.currentUser?.id;
    if (teacherId == null) return;

    final rawSubjects = await SubjectRepository.instance.getTeacherSubjects(
      teacherId,
      schoolYear: _currentSchoolYear,
    );

    if (mounted) {
      UnifiedEnrollStudentDialog.show(
        context,
        teacherSubjects: rawSubjects,
        initialSubjectId: initialSubjectId,
        initialSectionName: initialSectionName,
        onStudentCreated: () {
          _loadSubjects();
        },
      );
    }
  }

  Widget _buildBadge(
    String label, {
    bool isPrimary = false,
    bool subtle = false,
    bool compact = false,
  }) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 9,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: isPrimary
            ? primary.withValues(alpha: 0.12)
            : (subtle
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.06)
                  : primary.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w600,
          color: isPrimary
              ? primary
              : theme.colorScheme.onSurface.withValues(alpha: 0.85),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Add Subject Form
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAddSubjectForm() {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final isTotalValid = _isWeightValid;

    final isEditing = _editingSubject != null;
    final templateField = _buildLabeledField(
      label: 'Template',
      field: InkWell(
        onTap: isEditing ? null : _showTemplateModal,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isEditing ? theme.colorScheme.onSurface.withValues(alpha: 0.04) : null,
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.4),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _selectedTemplate?.name ?? 'Custom / Manual Entry',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: isEditing ? theme.colorScheme.onSurface.withValues(alpha: 0.6) : null,
                  ),
                ),
              ),
              Icon(
                isEditing ? LucideIcons.lock : LucideIcons.chevronDown,
                size: isEditing ? 15 : 18,
                color: isEditing ? theme.colorScheme.primary : null,
              ),
            ],
          ),
        ),
      ),
    );

    final isTemplateLocked = _selectedTemplate != null;

    final subjectField = _buildLabeledField(
      label: 'Subject Name',
      isRequired: true,
      error: _subjectError,
      labelTrailing: isTemplateLocked
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.lock,
                  size: 11,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Template Locked',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            )
          : Text(
              '${_subjectCtrl.text.length}/60',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
      field: TextField(
        controller: _subjectCtrl,
        focusNode: _subjectFocus,
        readOnly: isTemplateLocked,
        maxLength: 60,
        inputFormatters: [_SingleSpaceInputFormatter()],
        buildCounter: (
          _, {
          required currentLength,
          required isFocused,
          required maxLength,
        }) => null,
        textInputAction: TextInputAction.next,
        onChanged: isTemplateLocked
            ? null
            : (_) {
                setState(() {
                  if (_selectedTemplate != null &&
                      _selectedTemplate!.name != _subjectCtrl.text) {
                    _selectedTemplate = null;
                  }
                });
                _revalidateIfSubmitted();
              },
        onEditingComplete: () {
          final trimmedText = _subjectCtrl.text.trimRight();
          if (trimmedText != _subjectCtrl.text) {
            setState(() => _subjectCtrl.text = trimmedText);
          }
          _subjectFocus.nextFocus();
        },
        decoration: _boxDecoration(
          hint: 'e.g. General Mathematics',
          hasError: _subjectError != null,
        ).copyWith(
          filled: isTemplateLocked,
          fillColor: isTemplateLocked
              ? theme.colorScheme.onSurface.withValues(alpha: 0.05)
              : null,
        ),
      ),
    );

    final gradeField = _buildLabeledField(
      label: 'Grade Level',
      field: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.4),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _gradeLevel,
            isExpanded: true,
            items: _gradeLevels
                .map(
                  (g) => DropdownMenuItem(
                    value: g,
                    child: Text(g, style: const TextStyle(fontSize: 13)),
                  ),
                )
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _gradeLevel = val);
            },
          ),
        ),
      ),
    );

    final isTermsTaughtLocked = isTemplateLocked;

    final termsTaughtField = _buildLabeledField(
      label: 'No. of Terms Taught',
      labelTrailing: isTermsTaughtLocked
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.lock,
                  size: 11,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Standardized',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            )
          : null,
      field: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isTermsTaughtLocked
              ? theme.colorScheme.onSurface.withValues(alpha: 0.05)
              : null,
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.4),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: _termsTaught,
            isExpanded: true,
            iconEnabledColor: isTermsTaughtLocked ? Colors.transparent : null,
            items: const [
              DropdownMenuItem(
                value: 3,
                child: Text('3 Terms (Full Year / Trimester)'),
              ),
              DropdownMenuItem(value: 1, child: Text('1 Term Only')),
              DropdownMenuItem(value: 2, child: Text('2 Terms')),
            ],
            onChanged: isTermsTaughtLocked
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() {
                      _termsTaught = value;
                      _termBlock = value == 3
                          ? '1ST, 2ND, 3RD'
                          : value == 1
                          ? 'FIRST TERM'
                          : '1ST & 2ND';
                      _termBlockError = null;
                    });
                  },
          ),
        ),
      ),
    );

    final termBlockOptions = switch (_termsTaught) {
      1 => const [
        ('FIRST TERM', 'FIRST TERM'),
        ('SECOND TERM', 'SECOND TERM'),
        ('THIRD TERM', 'THIRD TERM'),
      ],
      2 => const [
        ('1ST & 2ND', '1ST & 2ND (Starts Term 1)'),
        ('2ND & 3RD', '2ND & 3RD (Starts Term 2)'),
      ],
      _ => const [('1ST, 2ND, 3RD', '1ST, 2ND, 3RD')],
    };

    final termBlockNote = switch (_termsTaught) {
      1 => 'Note: Accomplish only ONE (1) term sheet. Select the applicable TERM BLOCK.',
      2 => 'Notes: Accomplish TWO (2) term sheets. 2-term electives cannot begin in Term 3.',
      _ => 'Note: Accomplish all Term sheets.',
    };

    final isTermBlockLocked = _termsTaught == 3;

    final termBlockField = _buildLabeledField(
      label: 'Term Block (Active Term)',
      isRequired: true,
      error: _termBlockError,
      field: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isTermBlockLocked
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.05)
                  : null,
              border: Border.all(
                color: _termBlockError != null
                    ? theme.colorScheme.error
                    : theme.colorScheme.outline.withValues(alpha: 0.4),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _termBlock.isNotEmpty ? _termBlock : null,
                isExpanded: true,
                iconEnabledColor: isTermBlockLocked ? Colors.transparent : null,
                items: termBlockOptions
                    .map(
                      (option) => DropdownMenuItem(
                        value: option.$1,
                        child: Text(
                          option.$2,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: isTermBlockLocked
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() {
                            _termBlock = value;
                            _termBlockError = null;
                          });
                        }
                      },
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(termBlockNote, style: TextStyle(fontSize: 11, color: muted)),
        ],
      ),
    );

    final isTotalExact = _currentWeightTotal == 100;

    final wwField = _buildLabeledField(
      label: 'WRITTEN / ORAL WORKS',
      field: TextField(
        controller: _wwCtrl,
        readOnly: isTemplateLocked,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(3),
        ],
        decoration: _boxDecoration(hint: '0', hasError: false).copyWith(
          filled: isTemplateLocked,
          fillColor: isTemplateLocked
              ? theme.colorScheme.onSurface.withValues(alpha: 0.05)
              : null,
        ),
      ),
    );

    final ptField = _buildLabeledField(
      label: 'PRODUCT / PERFORMANCE TASKS',
      field: TextField(
        controller: _ptCtrl,
        readOnly: isTemplateLocked,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(3),
        ],
        decoration: _boxDecoration(hint: '0', hasError: false).copyWith(
          filled: isTemplateLocked,
          fillColor: isTemplateLocked
              ? theme.colorScheme.onSurface.withValues(alpha: 0.05)
              : null,
        ),
      ),
    );

    final exField = _buildLabeledField(
      label: 'EXAMINATIONS',
      field: TextField(
        controller: _exCtrl,
        readOnly: isTemplateLocked,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(3),
        ],
        decoration: _boxDecoration(hint: '0', hasError: false).copyWith(
          filled: isTemplateLocked,
          fillColor: isTemplateLocked
              ? theme.colorScheme.onSurface.withValues(alpha: 0.05)
              : null,
        ),
      ),
    );

    final Color totalBorderColor;
    final Color totalBgColor;
    final Color totalTextColor;
    final IconData totalIcon;

    if (isTotalExact) {
      totalBorderColor = theme.colorScheme.primary.withValues(alpha: 0.5);
      totalBgColor = theme.colorScheme.primary.withValues(alpha: 0.08);
      totalTextColor = theme.colorScheme.primary;
      totalIcon = LucideIcons.checkCircle;
    } else {
      totalBorderColor = theme.colorScheme.error;
      totalBgColor = theme.colorScheme.error.withValues(alpha: 0.08);
      totalTextColor = theme.colorScheme.error;
      totalIcon = LucideIcons.alertCircle;
    }

    final totalField = _buildLabeledField(
      label: 'Total Weight',
      field: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: totalBgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: totalBorderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$_currentWeightTotal%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: totalTextColor,
              ),
            ),
            Icon(totalIcon, size: 16, color: totalTextColor),
          ],
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEditing
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : theme.colorScheme.outline.withValues(alpha: 0.3),
          width: isEditing ? 1.5 : 1.0,
        ),
        boxShadow: isEditing
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isEditing ? theme.colorScheme.primary : theme.colorScheme.secondary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isEditing ? LucideIcons.pencil : LucideIcons.plusCircle,
                  size: 20,
                  color: isEditing ? theme.colorScheme.primary : theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing
                          ? 'Edit Subject: ${_editingSubject!.name}'
                          : 'Add New Subject & Sections',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEditing
                          ? (isTemplateLocked
                              ? 'Template-backed: Grade level & sections are editable. Term block editable if 1-term.'
                              : 'Custom subject: All fields and sections can be edited freely.')
                          : 'Configure subject details, grading weights, and create sections.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(LucideIcons.x, size: 18),
                onPressed: () => _resetForm(close: true),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 650) {
                return Column(
                  children: [
                    templateField,
                    const SizedBox(height: 12),
                    subjectField,
                    const SizedBox(height: 12),
                    gradeField,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: templateField),
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: subjectField),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: gradeField),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _buildSectionHeading('SUBJECT TERM CONFIGURATION'),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 650) {
                return Column(
                  children: [
                    termsTaughtField,
                    const SizedBox(height: 12),
                    termBlockField,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: termsTaughtField),
                  const SizedBox(width: 12),
                  Expanded(child: termBlockField),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          _buildSectionHeading('GRADING WEIGHTS'),
          const SizedBox(height: 4),
          Text(
            'Written / Oral Works, Product / Performance Tasks, and Examinations must sum to 100%.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 650) {
                return Column(
                  children: [
                    wwField,
                    const SizedBox(height: 12),
                    ptField,
                    const SizedBox(height: 12),
                    exField,
                    const SizedBox(height: 12),
                    totalField,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: wwField),
                  const SizedBox(width: 12),
                  Expanded(child: ptField),
                  const SizedBox(width: 12),
                  Expanded(child: exField),
                  const SizedBox(width: 12),
                  Expanded(child: totalField),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Divider(
            height: 1,
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          _buildSectionHeading('SECTIONS'),
          const SizedBox(height: 4),
          Text(
            'Add the sections for this subject.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < _sectionRows.length; i++) ...[
            _buildSectionRow(i, _sectionRows[i]),
            const SizedBox(height: 12),
          ],
          TextButton.icon(
            onPressed: _addSectionRow,
            icon: const Icon(LucideIcons.plus, size: 16),
            label: const Text('Add another section'),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 10,
              children: [
                AppButton.outline(
                  label: 'Cancel',
                  onPressed: () => _resetForm(close: true),
                ),
                _isSaving
                    ? LoadingAnimationWidget.staggeredDotsWave(
                        color: Theme.of(context).colorScheme.primary,
                        size: 28,
                      )
                    : AppButton.primary(
                        label: _editingSubject != null
                            ? 'Save Changes'
                            : 'Save Subject',
                        onPressed: isTotalValid ? _saveSubject : null,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeading(String text) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
      ),
    );
  }

  Widget _buildSectionRow(int index, _SectionRowDraft row) {
    final theme = Theme.of(context);
    final error = _sectionErrors[row.id];
    final canRemove = _sectionRows.length > 1;

    final nameField = _buildLabeledField(
      label: 'Section Name',
      isRequired: true,
      error: error,
      labelTrailing: Text(
        '${row.nameCtrl.text.length}/30',
        style: TextStyle(
          fontSize: 11,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      field: TextField(
        controller: row.nameCtrl,
        focusNode: row.focusNode,
        maxLength: 30,
        textInputAction: TextInputAction.next,
        onEditingComplete: () {
          final trimmedText = row.nameCtrl.text.trimRight();
          if (trimmedText != row.nameCtrl.text) {
            setState(() => row.nameCtrl.text = trimmedText);
          }
          final rowIndex = _sectionRows.indexOf(row);
          if (rowIndex >= 0 && rowIndex + 1 < _sectionRows.length) {
            _sectionRows[rowIndex + 1].focusNode.requestFocus();
          } else {
            row.focusNode.unfocus();
          }
        },
        buildCounter: (
          _, {
          required currentLength,
          required isFocused,
          required maxLength,
        }) => null,
        onChanged: (_) {
          setState(() {});
          _revalidateIfSubmitted();
        },
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9- ]')),
          _SingleSpaceInputFormatter(),
        ],
        decoration: _boxDecoration(
          hint: 'e.g. STEM 11-A',
          hasError: error != null,
        ),
      ),
    );

    const labelOffset = 25.0;

    final indexBadge = Padding(
      padding: const EdgeInsets.only(top: labelOffset + 12),
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Text(
          '${index + 1}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );

    final removeButton = Padding(
      padding: const EdgeInsets.only(top: labelOffset + 4),
      child: IconButton(
        tooltip: canRemove
            ? 'Remove section'
            : 'At least one section is required',
        onPressed: canRemove ? () => _removeSectionRow(row) : null,
        icon: const Icon(LucideIcons.trash2, size: 18),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        indexBadge,
        const SizedBox(width: 12),
        Expanded(child: nameField),
        const SizedBox(width: 4),
        removeButton,
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section Row Management (Limit of 10 enforced via error message)
  // ─────────────────────────────────────────────────────────────────────────
  void _addSectionRow() {
    if (_sectionRows.length >= _maxSections) {
      _showLimitErrorDialog(
        title: 'Section Limit Reached',
        message: 'You have reached the maximum allowed limit of sections for this subject.',
      );
      return;
    }
    final row = _SectionRowDraft(_newId('row'));
    setState(() => _sectionRows.add(row));
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => row.focusNode.requestFocus(),
    );
  }

  void _removeSectionRow(_SectionRowDraft row) async {
    if (_sectionRows.length <= 1) return;

    if (row.isExisting && _editingSubject != null) {
      final confirmed = await _showActionConfirmationDialog(
        title: 'Archive Section?',
        message:
            'Are you sure you want to archive section "${row.nameCtrl.text}"? '
            'It will be safely moved to Archived Sections and can be restored anytime.',
        confirmLabel: 'Archive Section',
        icon: LucideIcons.archive,
      );
      if (!confirmed) return;

      try {
        await SubjectRepository.instance.archiveSingleOffering(row.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Section "${row.nameCtrl.text}" archived.')),
          );
        }
        await _loadSubjects();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to archive section: $e')),
          );
        }
        return;
      }
    }

    setState(() {
      _sectionRows.remove(row);
      _sectionErrors.remove(row.id);
    });
    row.dispose();
    _revalidateIfSubmitted();
  }

  void _revalidateIfSubmitted() {
    if (_submitted) _validate();
  }

  bool _validate() {
    final rawName = _subjectCtrl.text;
    final name = rawName.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (rawName != name) {
      _subjectCtrl.text = name;
    }

    String? subjectError;
    if (name.isEmpty) {
      subjectError = 'Subject name is required.';
    } else if (name.length < 2) {
      subjectError = 'Subject name is too short.';
    } else if (_subjects
        .where(
          (s) =>
              s.id != _editingSubject?.id &&
              s.subjectId != _editingSubject?.subjectId,
        )
        .any(
          (s) =>
              s.name.toLowerCase() == name.toLowerCase() &&
              s.gradeLevel == _gradeLevel,
        )) {
      subjectError = 'You already have this subject for $_gradeLevel.';
    }

    String? termBlockError;
    if (_termsTaught < 3 && _termBlock.trim().isEmpty) {
      termBlockError = 'Term block is required.';
    }

    final sectionErrors = <String, String>{};
    final seen = <String>{};
    for (final row in _sectionRows) {
      final rawSecName = row.nameCtrl.text;
      final sectionName = rawSecName.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (rawSecName != sectionName) {
        row.nameCtrl.text = sectionName;
      }

      if (sectionName.isEmpty) {
        sectionErrors[row.id] = 'Section name is required.';
      } else if (sectionName.length < 2) {
        sectionErrors[row.id] = 'Section name is too short.';
      } else if (!seen.add(sectionName.toLowerCase())) {
        sectionErrors[row.id] = 'This section is already listed.';
      }
    }

    setState(() {
      _subjectError = subjectError;
      _termBlockError = termBlockError;
      _sectionErrors
        ..clear()
        ..addAll(sectionErrors);
    });
    return subjectError == null &&
        termBlockError == null &&
        sectionErrors.isEmpty &&
        _isWeightValid;
  }

  Future<void> _loadSubjects() async {
    final teacherId = AuthRepository.instance.currentUser?.id;
    if (teacherId == null) return;

    setState(() => _isLoadingSubjects = true);

    try {
      final activeRows = await SubjectRepository.instance.getTeacherSubjects(
        teacherId,
        schoolYear: _currentSchoolYear,
      );
      final archivedRows = await SubjectRepository.instance
          .getTeacherArchivedSubjects(
            teacherId,
            schoolYear: _currentSchoolYear,
          );
      final archivedSectionRows = await SubjectRepository.instance
          .getTeacherArchivedSections(
            teacherId,
            schoolYear: _currentSchoolYear,
          );

      final activeIds = activeRows.map((r) => r['id'].toString()).toList();
      final activeStudentCounts = await SubjectRepository.instance
          .getOfferingStudentCounts(activeIds);

      Map<String, _SubjectClass> parseGrouped(
        List<Map<String, dynamic>> rows, {
        Map<String, int>? studentCounts,
      }) {
        final Map<String, _SubjectClass> grouped = {};
        for (var row in rows) {
          final id = row['id'].toString();
          final subjectId = row['subject_id']?.toString() ?? id;
          final name = row['subject_name'] ?? 'Subject';
          final glInt = row['grade_level'];
          final gl = 'Grade $glInt';
          final secName = row['section_name'] ?? 'Section';
          final studentCount = studentCounts?[id] ??
              (row['student_count'] as num?)?.toInt() ??
              0;
          final ww = (row['ww_weight'] as num?)?.toInt() ?? 20;
          final pt = (row['pt_weight'] as num?)?.toInt() ?? 50;
          final ex = (row['ex_weight'] as num?)?.toInt() ?? 30;
          final termsTaught = (row['terms_taught'] as num?)?.toInt() ?? 3;
          final termBlock = row['term_block']?.toString() ?? '1ST, 2ND, 3RD';
          final unitsPerTerm =
              (row['units_per_term'] as num?)?.toDouble() ?? 2.0;
          final st1Weight = (row['st1_weight'] as num?)?.toDouble() ?? 30.0;
          final st2Weight = (row['st2_weight'] as num?)?.toDouble() ?? 30.0;
          final teWeight = (row['te_weight'] as num?)?.toDouble() ?? 40.0;

          final key = '${name}_$gl';
          if (!grouped.containsKey(key)) {
            grouped[key] = _SubjectClass(
              id: id,
              subjectId: subjectId,
              name: name,
              gradeLevel: gl,
              wwWeight: ww,
              ptWeight: pt,
              exWeight: ex,
              termsTaught: termsTaught,
              termBlock: termBlock,
              unitsPerTerm: unitsPerTerm,
              st1Weight: st1Weight,
              st2Weight: st2Weight,
              teWeight: teWeight,
              sections: [],
            );
          }
          grouped[key]!.sections.add(
            _ClassSection(
              id: id,
              name: secName,
              studentCount: studentCount,
            ),
          );
        }
        return grouped;
      }

      final activeGrouped = parseGrouped(
        activeRows,
        studentCounts: activeStudentCounts,
      );
      final archivedGrouped = parseGrouped(archivedRows);
      final archivedSectionsGrouped = parseGrouped(archivedSectionRows);

      if (mounted) {
        setState(() {
          _subjects.clear();
          _subjects.addAll(activeGrouped.values);
          _archivedSubjects.clear();
          _archivedSubjects.addAll(archivedGrouped.values);
          _archivedSectionsSubjects.clear();
          _archivedSectionsSubjects.addAll(archivedSectionsGrouped.values);
          _archivedSectionsCount = archivedSectionRows.length;
        });
      }
    } catch (e) {
      debugPrint('Error loading subjects: $e');
    } finally {
      if (mounted) setState(() => _isLoadingSubjects = false);
    }
  }

  Future<void> _saveSubject() async {
    _submitted = true;
    if (!_validate()) {
      if (_subjectError != null) {
        _subjectFocus.requestFocus();
      } else if (_termBlockError != null) {
        // Validation error for term block
      } else if (_sectionErrors.isNotEmpty) {
        final firstInvalid = _sectionRows.firstWhere(
          (row) => _sectionErrors.containsKey(row.id),
        );
        firstInvalid.focusNode.requestFocus();
      }
      return;
    }

    final teacherId = AuthRepository.instance.currentUser?.id;
    if (teacherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No active user session.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (_editingSubject != null) {
        await SubjectRepository.instance.updateSubjectAndSections(
          subjectId: _editingSubject!.subjectId,
          teacherId: teacherId,
          subjectName: _subjectCtrl.text.trim(),
          gradeLevel: _gradeLevel,
          wwWeight: double.parse(_wwCtrl.text),
          ptWeight: double.parse(_ptCtrl.text),
          exWeight: double.parse(_exCtrl.text),
          schoolYear: _currentSchoolYear,
          termsTaught: _termsTaught,
          termBlock: _termBlock,
          unitsPerTerm: _unitsPerTerm,
          st1Weight: _st1Weight,
          st2Weight: _st2Weight,
          teWeight: _teWeight,
          sections: _sectionRows
              .map(
                (r) => {
                  'id': r.id,
                  'name': r.nameCtrl.text.trim(),
                  'isExisting': r.isExisting,
                },
              )
              .toList(),
        );
      } else {
        await SubjectRepository.instance.saveSubjects(
          teacherId: teacherId,
          subjectName: _subjectCtrl.text.trim(),
          gradeLevel: _gradeLevel,
          wwWeight: double.parse(_wwCtrl.text),
          ptWeight: double.parse(_ptCtrl.text),
          exWeight: double.parse(_exCtrl.text),
          sectionNames: _sectionRows
              .map((r) => r.nameCtrl.text.trim())
              .toList(),
          schoolYear: _currentSchoolYear,
          termsTaught: _termsTaught,
          termBlock: _termBlock,
          unitsPerTerm: _unitsPerTerm,
          st1Weight: _st1Weight,
          st2Weight: _st2Weight,
          teWeight: _teWeight,
        );
      }

      final isEdit = _editingSubject != null;
      await _loadSubjects();

      if (mounted) {
        _resetForm(close: true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEdit
                  ? 'Subject and sections updated successfully!'
                  : 'Subject and sections saved successfully!',
            ),
            backgroundColor: AppTheme.catGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving subject: $e');
      if (mounted) {
        final friendlyMsg = e is PostgrestException
            ? 'Unable to save subject changes: ${e.message}'
            : 'Failed to save subject: ${e.toString()}';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(
          content: Text(friendlyMsg),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _resetForm({required bool close}) {
    for (final row in _sectionRows) {
      row.dispose();
    }
    setState(() {
      _editingSubject = null;
      _selectedTemplate = null;
      _subjectCtrl.clear();
      _wwCtrl.clear();
      _ptCtrl.clear();
      _exCtrl.clear();
      _gradeLevel = _gradeLevels.first;
      _termsTaught = 3;
      _termBlock = '1ST, 2ND, 3RD';
      _unitsPerTerm = 2;
      _st1Weight = 30;
      _st2Weight = 30;
      _teWeight = 40;
      _sectionRows
        ..clear()
        ..add(_SectionRowDraft(_newId('row')));
      _submitted = false;
      _subjectError = null;
      _termBlockError = null;
      _sectionErrors.clear();
      if (close) _showAddForm = false;
    });
  }

  Widget _buildEmptyClassroomState() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      height: 240,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : const Color(0xFFFBFCFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? theme.colorScheme.outline.withValues(alpha: 0.25)
              : const Color(0xFFBFD3F5),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.bookOpen,
            size: 38,
            color: isDark
                ? theme.colorScheme.primary.withValues(alpha: 0.8)
                : const Color(0xFF94A8C4),
          ),
          const SizedBox(height: 14),
          Text(
            'No subjects in this school year yet.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Click Add Subject above to configure your subjects and sections.',
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

  // ─────────────────────────────────────────────────────────────────────────
  // Archive Modal (Constrained Max Width 440px)
  // ─────────────────────────────────────────────────────────────────────────
  // ─────────────────────────────────────────────────────────────────────────
  // Archive Modal (Uses DRY _showActionConfirmationDialog)
  // ─────────────────────────────────────────────────────────────────────────
  void _confirmArchive(_SubjectClass subject) async {
    final confirmed = await _showActionConfirmationDialog(
      title: 'Archive Subject?',
      message:
          'Are you sure you want to archive "${subject.name}" (${subject.gradeLevel})? '
          'It will be hidden from your active classroom views.',
      confirmLabel: 'Archive Subject',
      icon: LucideIcons.archive,
      detailsWidget: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.info, size: 16, color: Color(0xFF487898)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sections, learning materials, and grading records are kept safely. You can restore this subject anytime from the Archived Subjects view.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );

    if (!confirmed) return;

    final teacherId = AuthRepository.instance.currentUser?.id;
    if (teacherId != null) {
      await SubjectRepository.instance.archiveSubjectOffering(
        teacherId: teacherId,
        subjectId: subject.subjectId,
      );
    }
    await _loadSubjects();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${subject.name} moved to archived subjects.')),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Restore Subject (Checks Active Limit of 10 and Asks Confirmation)
  // ─────────────────────────────────────────────────────────────────────────
  void _restoreSubject(_SubjectClass subject) async {
    if (_subjects.length >= _maxSubjects) {
      _showLimitErrorDialog(
        title: 'Subject Limit Reached',
        message:
            'Cannot restore this subject because you already have the maximum allowed number of active subjects. '
            'Please archive an active subject first before restoring.',
      );
      return;
    }

    final confirmed = await _showActionConfirmationDialog(
      title: 'Restore Subject?',
      message:
          'Are you sure you want to restore "${subject.name}" (${subject.gradeLevel}) back to your active classroom?',
      confirmLabel: 'Restore Subject',
      icon: LucideIcons.rotateCcw,
    );
    if (!confirmed) return;

    final teacherId = AuthRepository.instance.currentUser?.id;
    if (teacherId != null) {
      await SubjectRepository.instance.restoreSubjectOffering(
        teacherId: teacherId,
        subjectId: subject.subjectId,
      );
    }

    await _loadSubjects();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${subject.name} restored to active classroom.')),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Permanent Delete Modal (Guarded by Academic Records Check)
  // ─────────────────────────────────────────────────────────────────────────
  void _confirmPermanentDelete(_SubjectClass subject) async {
    final teacherId = AuthRepository.instance.currentUser?.id;
    if (teacherId == null) return;

    // 1. Guard against academic records
    final hasRecords = await SubjectRepository.instance.hasSubjectAcademicRecords(
      teacherId,
      subject.subjectId,
    );

    if (hasRecords) {
      if (mounted) {
        _showAcademicRecordsBlockedDialog(
          itemName: subject.name,
          isSection: false,
        );
      }
      return;
    }

    // 2. Ask confirmation if no academic records exist
    final confirmed = await _showActionConfirmationDialog(
      title: 'Permanently Delete Subject?',
      message:
          'Are you sure you want to permanently delete "${subject.name}" (${subject.gradeLevel})? '
          'This action cannot be undone.',
      confirmLabel: 'Delete Permanently',
      icon: LucideIcons.trash2,
      isDestructive: true,
      detailsWidget: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.shieldCheck, size: 16, color: Colors.green),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Student Accounts Are Safe: Deleting this subject will NOT delete student user accounts. '
                'Enrolled students will remain fully active in the system.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );

    if (!confirmed) return;

    await SubjectRepository.instance.deleteSubjectOffering(
      teacherId: teacherId,
      subjectId: subject.subjectId,
    );

    await _loadSubjects();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${subject.name} permanently deleted.')),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Restore Single Section
  // ─────────────────────────────────────────────────────────────────────────
  void _restoreSection(_ClassSection sec, _SubjectClass parentSubject) async {
    final confirmed = await _showActionConfirmationDialog(
      title: 'Restore Section?',
      message:
          'Are you sure you want to restore section "${sec.name}" back to "${parentSubject.name}"?',
      confirmLabel: 'Restore Section',
      icon: LucideIcons.rotateCcw,
    );
    if (!confirmed) return;

    await SubjectRepository.instance.restoreSingleOffering(sec.id);
    await _loadSubjects();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Section "${sec.name}" restored to active classroom.'),
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Permanent Delete Single Archived Section (Guarded by Academic Records)
  // ─────────────────────────────────────────────────────────────────────────
  void _confirmDeleteArchivedSection(
    _ClassSection sec,
    _SubjectClass parentSubject,
  ) async {
    // 1. Guard against academic records
    final hasRecords =
        await SubjectRepository.instance.hasAcademicRecords(sec.id);
    if (hasRecords) {
      if (mounted) {
        _showAcademicRecordsBlockedDialog(itemName: sec.name, isSection: true);
      }
      return;
    }

    // 2. Ask confirmation if no academic records exist
    final confirmed = await _showActionConfirmationDialog(
      title: 'Permanently Delete Section?',
      message:
          'Are you sure you want to permanently delete section "${sec.name}" from "${parentSubject.name}"? '
          'This action cannot be undone.',
      confirmLabel: 'Delete Permanently',
      icon: LucideIcons.trash2,
      isDestructive: true,
      detailsWidget: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.shieldCheck, size: 16, color: Colors.green),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Student Accounts Are Safe: Deleting this section will NOT delete student user accounts.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );

    if (!confirmed) return;

    await SubjectRepository.instance.deleteSingleOffering(sec.id);
    await _loadSubjects();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Section "${sec.name}" permanently deleted.')),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Archived Sections View & Empty State
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildArchivedSectionsView() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_archivedSectionsSubjects.isEmpty) {
      return Container(
        height: 260,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark
              ? theme.colorScheme.surface
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(
              alpha: isDark ? 0.2 : 0.3,
            ),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.layers,
                size: 32,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No Archived Sections',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sections you archive will be stored here under their respective subjects.\nYou can restore individual sections back to their active subjects anytime.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 950 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 340,
          ),
          itemCount: _archivedSectionsSubjects.length,
          itemBuilder: (context, index) {
            return _buildArchivedSectionSubjectCard(
              _archivedSectionsSubjects[index],
              index: index,
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Archived Section Subject Card
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildArchivedSectionSubjectCard(
    _SubjectClass subject, {
    int index = 0,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final sectionCount = subject.sections.length;

    final cardAccentColor = SubjectPalette.getColorForSubject(
      subject.name,
      teacherSubjectNames:
          _archivedSectionsSubjects.map((s) => s.name).toList(),
      index: index,
    );

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2)
            : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Grade badge, Archived Section Tag, Subject Name ──
          Row(
            children: [
              _buildBadge(subject.gradeLevel, isPrimary: true, compact: true),
              const SizedBox(width: 6),
              _buildBadge('Archived Sections', subtle: true, compact: true),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subject.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),

          // ── Stats Row ──
          Row(
            children: [
              Icon(LucideIcons.layers, size: 13, color: muted),
              const SizedBox(width: 4),
              Text(
                '$sectionCount ${sectionCount == 1 ? 'archived section' : 'archived sections'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: muted,
                ),
              ),
              const SizedBox(width: 12),
              Icon(LucideIcons.users, size: 13, color: muted),
              const SizedBox(width: 4),
              Text(
                '${subject.studentCount} enrolled students',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: muted,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Weights Badges ──
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _buildBadge(
                'WW ${subject.wwWeight}%',
                isPrimary: true,
                compact: true,
              ),
              _buildBadge(
                'PT ${subject.ptWeight}%',
                isPrimary: true,
                compact: true,
              ),
              _buildBadge(
                subject.exWeight == 0 ? 'NO EXAM' : 'EX ${subject.exWeight}%',
                isPrimary: true,
                compact: true,
              ),
            ],
          ),

          const SizedBox(height: 10),
          Divider(
            height: 1,
            color: theme.colorScheme.outline.withValues(alpha: 0.18),
          ),
          const SizedBox(height: 8),

          // ── Archived Sections List ──
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: subject.sections.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, idx) {
                final sec = subject.sections[idx];
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.25,
                          )
                        : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(
                        alpha: isDark ? 0.15 : 0.2,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: cardAccentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          LucideIcons.users,
                          size: 12,
                          color: cardAccentColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          sec.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Enrolled Student Count Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.08,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${sec.studentCount} ${sec.studentCount == 1 ? "student" : "students"}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Restore Section Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          side: BorderSide(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        icon: const Icon(LucideIcons.rotateCcw, size: 12),
                        label: const Text(
                          'Restore',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () => _restoreSection(sec, subject),
                      ),
                      const SizedBox(width: 4),
                      // Section Permanent Delete Button
                      IconButton(
                        tooltip: 'Delete section permanently',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 26,
                          minHeight: 26,
                        ),
                        icon: Icon(
                          LucideIcons.trash2,
                          size: 14,
                          color: theme.colorScheme.error.withValues(alpha: 0.7),
                        ),
                        onPressed: () =>
                            _confirmDeleteArchivedSection(sec, subject),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),
          Divider(
            height: 1,
            color: theme.colorScheme.outline.withValues(alpha: 0.18),
          ),
          const SizedBox(height: 8),

          // ── Card Footer Note ──
          Row(
            children: [
              const Icon(LucideIcons.info, size: 13, color: Color(0xFF487898)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Restore sections back to this subject anytime.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: muted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Template Picker Dialog (Searchable & Filterable by Category & Cluster)
  // ─────────────────────────────────────────────────────────────────────────
  void _showTemplateModal() {
    final allTemplates = _availableTemplates;
    String searchQuery = '';
    String selectedCategory = 'ALL CATEGORIES';
    final searchCtrl = TextEditingController();

    const categories = [
      'ALL CATEGORIES',
      'SSHS - CORE',
      'SSHS - ACADEMIC',
      'SSHS - TECH-PRO',
    ];

    _showConstrainedDialog(
      context: context,
      maxWidth: 680,
      child: StatefulBuilder(
        builder: (dialogCtx, setModalState) {
          final theme = Theme.of(dialogCtx);
          final isDark = theme.brightness == Brightness.dark;

          // Filter templates
          final filtered = allTemplates.where((t) {
            if (selectedCategory != 'ALL CATEGORIES' &&
                t.category != selectedCategory) {
              return false;
            }
            if (searchQuery.isNotEmpty) {
              final q = searchQuery.toLowerCase().trim();
              final matchesName = t.name.toLowerCase().contains(q);
              final matchesCluster = t.cluster.toLowerCase().contains(q);
              final matchesCategory = t.category.toLowerCase().contains(q);
              if (!matchesName && !matchesCluster && !matchesCategory) {
                return false;
              }
            }
            return true;
          }).toList();

          // Group by Cluster
          final Map<String, List<SubjectTemplate>> groupedByCluster = {};
          for (final t in filtered) {
            groupedByCluster.putIfAbsent(t.cluster, () => []).add(t);
          }

          int getCategoryCount(String cat) {
            if (cat == 'ALL CATEGORIES') return allTemplates.length;
            return allTemplates.where((t) => t.category == cat).length;
          }

          return SizedBox(
            height: 600,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.auto_stories_rounded,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Subject Template',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Standardized DepEd DO 15, s. 2026 grading weight & term presets',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      splashRadius: 18,
                      onPressed: () => Navigator.pop(dialogCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Search Bar Input
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: TextField(
                    controller: searchCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search by subject name or cluster (e.g. Mathematics, ICT, Accounting)...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white38 : Colors.grey.shade400,
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                searchCtrl.clear();
                                setModalState(() => searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (val) {
                      setModalState(() => searchQuery = val);
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Category Filter Pills
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: categories.map((cat) {
                      final isSelected = selectedCategory == cat;
                      final count = getCategoryCount(cat);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () {
                            setModalState(() => selectedCategory = cat);
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : (isDark
                                        ? Colors.white12
                                        : const Color(0xFFE2E8F0)),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  cat,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : theme.colorScheme.onSurface
                                            .withValues(alpha: 0.75),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.25)
                                        : (isDark
                                            ? Colors.white10
                                            : Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Colors.white
                                          : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),

                // Main Content List
                Expanded(
                  child: ListView(
                    children: [
                      // Prominent Hero Card: Custom / Manual Entry
                      InkWell(
                        onTap: () {
                          setState(() => _selectedTemplate = null);
                          Navigator.pop(dialogCtx);
                          _subjectFocus.requestFocus();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? theme.colorScheme.primary.withValues(alpha: 0.08)
                                : theme.colorScheme.primary.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(alpha: 0.35),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.edit_note_rounded,
                                  color: theme.colorScheme.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Custom / Manual Entry',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.catPurple.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'User Defined',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.catPurple,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Enter custom subject name, custom grading weights, and term configuration',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: theme.colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Empty Search State
                      if (filtered.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 44,
                                color: isDark ? Colors.white24 : Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No subjects found matching "$searchQuery"',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'You can create it as a custom subject with your own weights.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                              if (searchQuery.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: Text(
                                    'Use "$searchQuery" as Subject Name',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _selectedTemplate = null;
                                      _subjectCtrl.text = searchQuery.trim();
                                    });
                                    Navigator.pop(dialogCtx);
                                    _revalidateIfSubmitted();
                                  },
                                ),
                              ],
                            ],
                          ),
                        )
                      else
                        // Filtered Subjects Grouped by Cluster
                        ...groupedByCluster.entries.map((clusterEntry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Cluster Section Header
                                Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      clusterEntry.key,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '(${clusterEntry.value.length})',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Subject Items
                                ...clusterEntry.value.map((template) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? theme.colorScheme.surface
                                          : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white10
                                            : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: ListTile(
                                      dense: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 4,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      hoverColor: theme.colorScheme.primary.withValues(alpha: 0.05),
                                      title: Text(
                                        template.name,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            // Weight badge (Unified Blue)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 7,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                                                borderRadius: BorderRadius.circular(5),
                                              ),
                                              child: Text(
                                                template.weightSummary,
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: theme.colorScheme.primary,
                                                ),
                                              ),
                                            ),
                                            // Term badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 7,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? Colors.white10
                                                    : Colors.grey.shade200,
                                                borderRadius: BorderRadius.circular(5),
                                              ),
                                              child: Text(
                                                template.termsSummary,
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      trailing: const Icon(
                                        Icons.chevron_right_rounded,
                                        size: 20,
                                        color: Colors.grey,
                                      ),
                                      onTap: () {
                                        _applyTemplate(template);
                                        Navigator.pop(dialogCtx);
                                      },
                                    ),
                                  );
                                }),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Bottom Close Button Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${filtered.length} of ${allTemplates.length} subjects available',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _applyTemplate(SubjectTemplate template) {
    setState(() {
      _selectedTemplate = template;
      _subjectCtrl.text = template.name;
      _wwCtrl.text = template.ww.toString();
      _ptCtrl.text = template.pt.toString();
      _exCtrl.text = template.ex.toString();
      _termsTaught = template.termsTaught;
      _termBlock = template.termBlock;
      _unitsPerTerm = template.category == 'SSHS - ACADEMIC'
          ? 3.0
          : (template.category == 'SSHS - TECH-PRO' ? 4.0 : 2.0);
      _st1Weight = template.st1Weight;
      _st2Weight = template.st2Weight;
      _teWeight = template.teWeight;
    });
    _revalidateIfSubmitted();
  }

  Widget _buildLabeledField({
    required String label,
    required Widget field,
    bool isRequired = false,
    String? error,
    Widget? labelTrailing,
  }) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                  ),
                  if (isRequired) ...[
                    const SizedBox(width: 4),
                    Text(
                      '*',
                      style: TextStyle(color: errorColor, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            if (labelTrailing != null) ...[
              const SizedBox(width: 8),
              labelTrailing,
            ],
          ],
        ),
        const SizedBox(height: 6),
        field,
        if (error != null) ...[
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  LucideIcons.alertCircle,
                  size: 14,
                  color: errorColor,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  error,
                  style: TextStyle(fontSize: 12, color: errorColor),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  InputDecoration _boxDecoration({String? hint, required bool hasError}) {
    return InputDecoration(
      hintText: hint,
      error: hasError ? const SizedBox.shrink() : null,
      errorStyle: const TextStyle(fontSize: 0, height: 0),
    );
  }
}

class _SingleSpaceInputFormatter extends TextInputFormatter {
  static final RegExp _leadingWhitespace = RegExp(r'^\s+');
  static final RegExp _repeatedWhitespace = RegExp(r'\s{2,}');

  String _normalize(String value) {
    return value
        .replaceAll(_leadingWhitespace, '')
        .replaceAll(_repeatedWhitespace, ' ');
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = _normalize(newValue.text);
    if (normalized == newValue.text) return newValue;

    int mapOffset(int offset) {
      if (offset < 0) return normalized.length;
      final safeOffset = offset.clamp(0, newValue.text.length);
      return _normalize(newValue.text.substring(0, safeOffset)).length;
    }

    return TextEditingValue(
      text: normalized,
      selection: TextSelection(
        baseOffset: mapOffset(newValue.selection.baseOffset),
        extentOffset: mapOffset(newValue.selection.extentOffset),
        affinity: newValue.selection.affinity,
        isDirectional: newValue.selection.isDirectional,
      ),
      composing: TextRange.empty,
    );
  }
}
