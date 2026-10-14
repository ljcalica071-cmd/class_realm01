import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/features/teacher/sub_features/class_management/widgets/unified_enroll_student_dialog.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

/// Pre-defined grading templates
class SubjectTemplate {
  final String name;
  final int ww;
  final int pt;
  final int ex;
  const SubjectTemplate(this.name, this.ww, this.pt, this.ex);
}

const List<SubjectTemplate> _defaultTemplates = [
  SubjectTemplate('Effective Communication', 20, 50, 30),
  SubjectTemplate('Mabisang Komunikasyon', 20, 50, 30),
  SubjectTemplate('Life and Career Skills', 20, 50, 30),
  SubjectTemplate('General Mathematics', 20, 50, 30),
  SubjectTemplate('General Science', 20, 50, 30),
  SubjectTemplate('Pag-aaral ng Kasaysayan at Lipunang Pilipino', 20, 50, 30),
];

/// A section the teacher handles for a subject.
class _ClassSection {
  final String id;
  final String name;
  int studentCount;

  _ClassSection({
    required this.id,
    required this.name,
  }) : studentCount = 0;
}

/// A subject the teacher teaches, with grading config and sections.
class _SubjectClass {
  final String id;
  final String subjectId;
  final String name;
  final String gradeLevel;
  final int wwWeight;
  final int ptWeight;
  final int exWeight;
  final List<_ClassSection> sections;

  _SubjectClass({
    required this.id,
    required this.subjectId,
    required this.name,
    required this.gradeLevel,
    required this.wwWeight,
    required this.ptWeight,
    required this.exWeight,
    required this.sections,
  });

  int get studentCount =>
      sections.fold(0, (total, section) => total + section.studentCount);
}

/// Editable section row inside the add form.
class _SectionRowDraft {
  final String id;
  final TextEditingController nameCtrl = TextEditingController();
  final FocusNode focusNode = FocusNode();

  _SectionRowDraft(this.id);

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
  bool _isViewingArchived = false;

  final List<_SubjectClass> _subjects = [];
  final List<_SubjectClass> _archivedSubjects = [];

  // ── Form state ──
  SubjectTemplate? _selectedTemplate;
  final _subjectCtrl = TextEditingController();
  final _subjectFocus = FocusNode();
  String _gradeLevel = _gradeLevels.first;
  
  // Grading Weights
  final _wwCtrl = TextEditingController();
  final _ptCtrl = TextEditingController();
  final _exCtrl = TextEditingController();

  final List<_SectionRowDraft> _sectionRows = [];

  // ── Validation state ──
  bool _submitted = false;
  String? _subjectError;
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: child,
            ),
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
    final nameTitle = currentUser?.gender?.toLowerCase() == 'female'
        ? "Ma'am"
        : "Sir";

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
                color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.2 : 0.4),
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
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
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
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
                      // View Archived / Active Toggle Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          side: BorderSide(
                            color: _isViewingArchived
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline.withValues(alpha: 0.35),
                          ),
                          backgroundColor: _isViewingArchived
                              ? theme.colorScheme.primary.withValues(alpha: 0.08)
                              : Colors.transparent,
                        ),
                        onPressed: () {
                          setState(() {
                            _isViewingArchived = !_isViewingArchived;
                            _showAddForm = false;
                          });
                        },
                        icon: Icon(
                          _isViewingArchived ? LucideIcons.layers : LucideIcons.archive,
                          size: 16,
                          color: _isViewingArchived
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                        label: Text(
                          _isViewingArchived
                              ? 'Active Subjects (${_subjects.length})'
                              : 'Archived Subjects (${_archivedSubjects.length})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _isViewingArchived
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                      AppButton.outline(
                        icon: LucideIcons.calendar,
                        label: 'Timetable & Schedule',
                        onPressed: () => widget.onNavigateTo?.call(14),
                      ),
                      if (!_isViewingArchived)
                        AppButton.primary(
                          icon: _showAddForm ? LucideIcons.x : LucideIcons.plus,
                          label: _showAddForm ? 'Close Form' : 'Add Subject',
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
                    children: [
                      headerLeft,
                      headerActions,
                    ],
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Section Title Bar ──
          Row(
            children: [
              Icon(
                _isViewingArchived ? LucideIcons.archive : LucideIcons.bookOpen,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                _isViewingArchived ? 'ARCHIVED SUBJECTS' : 'ACTIVE SUBJECTS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const Spacer(),
              if (_isViewingArchived)
                TextButton.icon(
                  onPressed: () => setState(() => _isViewingArchived = false),
                  icon: const Icon(LucideIcons.arrowLeft, size: 14),
                  label: const Text('Back to Active Subjects'),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Add Subject Form (collapsible) ──
          if (_showAddForm && !_isViewingArchived) ...[
            _buildAddSubjectForm(),
            const SizedBox(height: 20),
          ],

          // ── Main Content Area ──
          _isLoadingSubjects
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48.0),
                    child: LoadingAnimationWidget.staggeredDotsWave(
                      color: Theme.of(context).colorScheme.primary,
                      size: 40,
                    ),
                  ),
                )
              : _isViewingArchived
                  ? _buildArchivedView()
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
                child: const Icon(LucideIcons.alertTriangle, color: Colors.amber, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
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
            return _buildResponsiveSubjectCard(_subjects[index], isArchived: false);
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
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.2 : 0.3),
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
            return _buildResponsiveSubjectCard(_archivedSubjects[index], isArchived: true);
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Responsive Redesigned Subject Card
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildResponsiveSubjectCard(_SubjectClass subject, {required bool isArchived}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final sectionCount = subject.sections.length;

    // Distinct theme colors based on subject name
    final cardAccentColor = _getSubjectAccentColor(subject.name);

    return Container(
      decoration: BoxDecoration(
        color: isArchived
            ? (isDark
                ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2)
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
                  color: cardAccentColor.withValues(alpha: isDark ? 0.12 : 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Subject Icon Avatar, Subject Info, Actions ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Visual Subject Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isArchived
                        ? [Colors.grey.shade400, Colors.grey.shade600]
                        : [
                            cardAccentColor,
                            cardAccentColor.withValues(alpha: 0.75),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isArchived
                      ? []
                      : [
                          BoxShadow(
                            color: cardAccentColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                ),
                child: Icon(
                  _getSubjectIcon(subject.name),
                  size: 22,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              // Subject Title and Grade
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildBadge(subject.gradeLevel, isPrimary: true, compact: true),
                        if (isArchived) ...[
                          const SizedBox(width: 6),
                          _buildBadge('Archived', subtle: true, compact: true),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subject.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isArchived ? muted : theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              // Archive / Delete Actions
              if (isArchived) ...[
                IconButton(
                  tooltip: 'Restore to Active',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(LucideIcons.rotateCcw, size: 17, color: theme.colorScheme.primary),
                  onPressed: () => _restoreSubject(subject),
                ),
                IconButton(
                  tooltip: 'Permanently Delete',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(LucideIcons.trash2, size: 17, color: theme.colorScheme.error),
                  onPressed: () => _confirmPermanentDelete(subject),
                ),
              ] else ...[
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
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: muted),
              ),
              const SizedBox(width: 12),
              Icon(LucideIcons.users, size: 13, color: muted),
              const SizedBox(width: 4),
              Text(
                '${subject.studentCount} enrolled students',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: muted),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Grading Weights Pill Row ──
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _buildBadge('WW ${subject.wwWeight}%', subtle: true, compact: true),
              _buildBadge('PT ${subject.ptWeight}%', subtle: true, compact: true),
              _buildBadge('EX ${subject.exWeight}%', subtle: true, compact: true),
            ],
          ),

          const SizedBox(height: 10),
          Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.18)),
          const SizedBox(height: 8),

          // ── Sections Area (Scrollable if many sections) ──
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: subject.sections.length,
              separatorBuilder: (_, __) => const SizedBox(height: 5),
              itemBuilder: (context, idx) {
                final sec = subject.sections[idx];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.22)
                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.15 : 0.2),
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
                        child: Icon(LucideIcons.users, size: 12, color: cardAccentColor),
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
          Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.18)),
          const SizedBox(height: 10),

          // ── Footer Action Buttons ──
          if (!isArchived)
            Row(
              children: [
                Expanded(
                  child: AppButton.primary(
                    icon: LucideIcons.userPlus,
                    label: 'Add Students',
                    onPressed: () {
                      final firstSec = subject.sections.isNotEmpty ? subject.sections.first : null;
                      _openEnrollmentDialog(
                        initialSubjectId: firstSec?.id,
                        initialSectionName: firstSec?.name,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => widget.onNavigateTo?.call(14),
                  icon: const Icon(LucideIcons.calendar, size: 14),
                  label: const Text('Schedule', style: TextStyle(fontSize: 12)),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: BorderSide(color: theme.colorScheme.primary),
                    ),
                    icon: const Icon(LucideIcons.rotateCcw, size: 14),
                    label: const Text('Restore Subject', style: TextStyle(fontSize: 12)),
                    onPressed: () => _restoreSubject(subject),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Permanently Delete',
                  icon: Icon(LucideIcons.trash2, size: 16, color: theme.colorScheme.error),
                  onPressed: () => _confirmPermanentDelete(subject),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Color _getSubjectAccentColor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('math')) return const Color(0xFF2563EB); // Royal Blue
    if (lower.contains('science')) return const Color(0xFF059669); // Emerald Green
    if (lower.contains('comm') || lower.contains('komunikasyon')) {
      return const Color(0xFF7C3AED); // Purple
    }
    if (lower.contains('career') || lower.contains('life')) {
      return const Color(0xFFD97706); // Amber
    }
    if (lower.contains('kasaysayan') || lower.contains('history') || lower.contains('lipunan')) {
      return const Color(0xFFDC2626); // Crimson
    }
    return const Color(0xFF0D9488); // Teal Default
  }

  IconData _getSubjectIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('math')) return LucideIcons.binary;
    if (lower.contains('science')) return LucideIcons.atom;
    if (lower.contains('comm') || lower.contains('komunikasyon')) {
      return LucideIcons.messageSquare;
    }
    if (lower.contains('career') || lower.contains('life')) {
      return LucideIcons.briefcase;
    }
    if (lower.contains('kasaysayan') || lower.contains('history') || lower.contains('lipunan')) {
      return LucideIcons.landmark;
    }
    return LucideIcons.bookOpen;
  }

  void _openEnrollmentDialog({String? initialSubjectId, String? initialSectionName}) async {
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

  Widget _buildBadge(String label, {bool isPrimary = false, bool subtle = false, bool compact = false}) {
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
          color: isPrimary ? primary : theme.colorScheme.onSurface.withValues(alpha: 0.85),
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

    final templateField = _buildLabeledField(
      label: 'Template',
      field: InkWell(
        onTap: _showTemplateModal,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _selectedTemplate?.name ?? 'Custom / Manual Entry',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const Icon(LucideIcons.chevronDown, size: 18),
            ],
          ),
        ),
      ),
    );

    final subjectField = _buildLabeledField(
      label: 'Subject Name',
      isRequired: true,
      error: _subjectError,
      field: TextField(
        controller: _subjectCtrl,
        focusNode: _subjectFocus,
        maxLength: 60,
        buildCounter: (_, {required currentLength, required isFocused, required maxLength}) => null,
        textInputAction: TextInputAction.next,
        onChanged: (_) {
          if (_selectedTemplate != null && _selectedTemplate!.name != _subjectCtrl.text) {
            setState(() => _selectedTemplate = null);
          }
          _revalidateIfSubmitted();
        },
        decoration: _boxDecoration(
          hint: 'e.g. General Mathematics',
          hasError: _subjectError != null,
        ),
      ),
    );

    final gradeField = _buildLabeledField(
      label: 'Grade Level',
      field: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _gradeLevel,
            isExpanded: true,
            items: _gradeLevels
                .map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _gradeLevel = val);
            },
          ),
        ),
      ),
    );

    final isTotalExact = _currentWeightTotal == 100;
    final isTotalOver = _currentWeightTotal > 100;
    final showWeightError = _submitted ? !isTotalExact : isTotalOver;

    final wwField = _buildLabeledField(
      label: 'WRITTEN / ORAL WORKS',
      field: TextField(
        controller: _wwCtrl,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        decoration: _boxDecoration(hint: '0', hasError: showWeightError),
      ),
    );

    final ptField = _buildLabeledField(
      label: 'PRODUCT / PERFORMANCE TASKS',
      field: TextField(
        controller: _ptCtrl,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        decoration: _boxDecoration(hint: '0', hasError: showWeightError),
      ),
    );

    final exField = _buildLabeledField(
      label: 'EXAMINATIONS',
      field: TextField(
        controller: _exCtrl,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        decoration: _boxDecoration(hint: '0', hasError: showWeightError),
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
    } else if (showWeightError) {
      totalBorderColor = theme.colorScheme.error;
      totalBgColor = theme.colorScheme.error.withValues(alpha: 0.08);
      totalTextColor = theme.colorScheme.error;
      totalIcon = LucideIcons.alertCircle;
    } else {
      totalBorderColor = theme.colorScheme.outline.withValues(alpha: 0.35);
      totalBgColor = theme.colorScheme.surface;
      totalTextColor = theme.colorScheme.onSurface.withValues(alpha: 0.7);
      totalIcon = LucideIcons.scale;
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
            Icon(
              totalIcon,
              size: 16,
              color: totalTextColor,
            ),
          ],
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Add Subject & Sections',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
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
          Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.2)),
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
                      label: 'Save Subject',
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
      field: TextField(
        controller: row.nameCtrl,
        focusNode: row.focusNode,
        maxLength: 30,
        buildCounter: (_, {required currentLength, required isFocused, required maxLength}) => null,
        onChanged: (_) => _revalidateIfSubmitted(),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9- ]')),
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
        tooltip: canRemove ? 'Remove section' : 'At least one section is required',
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
        message:
            'You have reached the maximum allowed limit of sections for this subject.',
      );
      return;
    }
    final row = _SectionRowDraft(_newId('row'));
    setState(() => _sectionRows.add(row));
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => row.focusNode.requestFocus(),
    );
  }

  void _removeSectionRow(_SectionRowDraft row) {
    if (_sectionRows.length <= 1) return;
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
    } else if (_subjects.any(
      (s) =>
          s.name.toLowerCase() == name.toLowerCase() &&
          s.gradeLevel == _gradeLevel,
    )) {
      subjectError = 'You already have this subject for $_gradeLevel.';
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
      _sectionErrors
        ..clear()
        ..addAll(sectionErrors);
    });
    return subjectError == null && sectionErrors.isEmpty && _isWeightValid;
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
      final archivedRows = await SubjectRepository.instance.getTeacherArchivedSubjects(
        teacherId,
        schoolYear: _currentSchoolYear,
      );

      Map<String, _SubjectClass> parseGrouped(List<Map<String, dynamic>> rows) {
        final Map<String, _SubjectClass> grouped = {};
        for (var row in rows) {
          final id = row['id'].toString();
          final subjectId = row['subject_id']?.toString() ?? id;
          final name = row['subject_name'] ?? 'Subject';
          final glInt = row['grade_level'];
          final gl = 'Grade $glInt';
          final secName = row['section_name'] ?? 'Section';
          final ww = (row['ww_weight'] as num?)?.toInt() ?? 20;
          final pt = (row['pt_weight'] as num?)?.toInt() ?? 50;
          final ex = (row['ex_weight'] as num?)?.toInt() ?? 30;

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
              sections: [],
            );
          }
          grouped[key]!.sections.add(_ClassSection(id: id, name: secName));
        }
        return grouped;
      }

      final activeGrouped = parseGrouped(activeRows);
      final archivedGrouped = parseGrouped(archivedRows);

      if (mounted) {
        setState(() {
          _subjects.clear();
          _subjects.addAll(activeGrouped.values);
          _archivedSubjects.clear();
          _archivedSubjects.addAll(archivedGrouped.values);
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
      await SubjectRepository.instance.saveSubjects(
        teacherId: teacherId,
        subjectName: _subjectCtrl.text.trim(),
        gradeLevel: _gradeLevel,
        wwWeight: double.parse(_wwCtrl.text),
        ptWeight: double.parse(_ptCtrl.text),
        exWeight: double.parse(_exCtrl.text),
        sectionNames: _sectionRows.map((r) => r.nameCtrl.text.trim()).toList(),
        schoolYear: _currentSchoolYear,
      );

      await _loadSubjects();

      if (mounted) {
        _resetForm(close: true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subject and sections saved successfully!')),
        );
      }
    } catch (e) {
      debugPrint('Error saving subject: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save subject: $e')),
        );
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
      _selectedTemplate = null;
      _subjectCtrl.clear();
      _wwCtrl.clear();
      _ptCtrl.clear();
      _exCtrl.clear();
      _gradeLevel = _gradeLevels.first;
      _sectionRows
        ..clear()
        ..add(_SectionRowDraft(_newId('row')));
      _submitted = false;
      _subjectError = null;
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
  void _confirmArchive(_SubjectClass subject) {
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.archive, size: 20, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Archive Subject?',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Archiving "${subject.name}" will hide it from your active classroom views.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.info, size: 16, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sections, learning materials, and grading records are kept safely. You can restore this subject anytime from the Archived Subjects view.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              AppButton.primary(
                label: 'Archive',
                onPressed: () async {
                  Navigator.pop(context);
                  final teacherId = AuthRepository.instance.currentUser?.id;
                  if (teacherId != null) {
                    await SubjectRepository.instance.archiveSubjectOffering(
                      teacherId: teacherId,
                      subjectId: subject.subjectId,
                    );
                  }
                  setState(() {
                    _subjects.remove(subject);
                    _archivedSubjects.add(subject);
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${subject.name} moved to archived subjects.')),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Restore Subject (Checks Active Limit of 10)
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

    final teacherId = AuthRepository.instance.currentUser?.id;
    if (teacherId != null) {
      await SubjectRepository.instance.restoreSubjectOffering(
        teacherId: teacherId,
        subjectId: subject.subjectId,
      );
    }

    setState(() {
      _archivedSubjects.remove(subject);
      _subjects.add(subject);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${subject.name} restored to active classroom.')),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Permanent Delete Modal (Constrained Max Width 480px with Student Reassurance)
  // ─────────────────────────────────────────────────────────────────────────
  void _confirmPermanentDelete(_SubjectClass subject) {
    _showConstrainedDialog(
      context: context,
      maxWidth: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.alertTriangle,
                  size: 20,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Permanently Delete Subject?',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Are you sure you want to permanently delete "${subject.name}" (${subject.gradeLevel})?',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          // Warning breakdown
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.alertCircle, size: 15, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 6),
                    Text(
                      'What will be deleted:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '• Subject offering and all assigned sections\n'
                  '• Classwork, digital assessments, and quiz records for this subject\n'
                  '• Gradebook scores and teacher learning materials for this subject\n'
                  '• This action is permanent and cannot be undone.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Student Account Safety Reassurance Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.shieldCheck, size: 16, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Student Accounts Are Safe: Deleting this subject will NOT delete student user accounts. '
                    'Enrolled students will remain fully active in the system and in their other teachers\' subjects.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                icon: const Icon(LucideIcons.trash2, size: 16),
                label: const Text('Delete Permanently'),
                onPressed: () async {
                  Navigator.pop(context);
                  final teacherId = AuthRepository.instance.currentUser?.id;
                  if (teacherId != null) {
                    await SubjectRepository.instance.deleteSubjectOffering(
                      teacherId: teacherId,
                      subjectId: subject.subjectId,
                    );
                  }
                  setState(() {
                    _archivedSubjects.remove(subject);
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${subject.name} permanently deleted.')),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Template Picker Dialog (Constrained Width)
  // ─────────────────────────────────────────────────────────────────────────
  void _showTemplateModal() {
    _showConstrainedDialog(
      context: context,
      maxWidth: 440,
      child: StatefulBuilder(
        builder: (context, setStateModal) {
          return SizedBox(
            height: 380,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Subject Template',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: _defaultTemplates.length + 1,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Custom / Manual Entry', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: const Text('Enter custom subject name and grading weights', style: TextStyle(fontSize: 11)),
                          onTap: () {
                            setState(() => _selectedTemplate = null);
                            Navigator.pop(context);
                          },
                        );
                      }
                      final template = _defaultTemplates[index - 1];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(template.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text('WW ${template.ww}% · PT ${template.pt}% · EX ${template.ex}%', style: const TextStyle(fontSize: 11)),
                        onTap: () {
                          _applyTemplate(template);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
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
    });
    _revalidateIfSubmitted();
  }

  Widget _buildLabeledField({
    required String label,
    required Widget field,
    bool isRequired = false,
    String? error,
  }) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              Text('*', style: TextStyle(color: errorColor, fontSize: 12)),
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
                child: Icon(LucideIcons.alertCircle, size: 14, color: errorColor),
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
