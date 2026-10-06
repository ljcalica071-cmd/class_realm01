import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';

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
    this.studentCount = 0,
  });
}

/// A subject the teacher teaches, with grading config and sections.
class _SubjectClass {
  final String id;
  final String name;
  final String gradeLevel;
  final int wwWeight;
  final int ptWeight;
  final int exWeight;
  final List<_ClassSection> sections;
  // Implicitly active for all 3 terms under the dashboard's active School Year.

  _SubjectClass({
    required this.id,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      LucideIcons.building,
                      color: theme.colorScheme.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$nameTitle $teacherName's Classroom",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'SY $_currentSchoolYear · Trimester',
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
                  AppButton.outline(
                    icon: LucideIcons.calendar,
                    label: 'Timetable & Schedule',
                    onPressed: () {
                      widget.onNavigateTo?.call(14);
                    },
                  ),
                  const SizedBox(width: 8),
                  AppButton.primary(
                    icon: LucideIcons.plus,
                    label: 'Add Subject',
                    onPressed: () {
                      if (_subjects.length >= _maxSubjects) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Maximum of $_maxSubjects subjects allowed.')),
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
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          if (_showAddForm) ...[
            const SizedBox(height: 12),
            _buildAddSubjectForm(),
          ],
          const SizedBox(height: 20),
          _isLoadingSubjects
              ? const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator()))
              : _subjects.isEmpty
                  ? _buildEmptyClassroomState()
                  : Wrap(
                  spacing: 18,
                  runSpacing: 18,
                  children: _subjects.map(_buildSubjectCard).toList(),
                ),
          if (_archivedSubjects.isNotEmpty) ...[
            const SizedBox(height: 32),
            _buildSectionHeading('ARCHIVED SUBJECTS'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 18,
              runSpacing: 18,
              children: _archivedSubjects.map((s) => _buildSubjectCard(s, isArchived: true)).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Subject card
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildSubjectCard(_SubjectClass subject, {bool isArchived = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final sectionCount = subject.sections.length;

    return Container(
      width: 320,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isArchived
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isArchived
              ? theme.colorScheme.outline.withValues(alpha: 0.2)
              : theme.colorScheme.outline.withValues(
                  alpha: isDark ? 0.35 : 0.55,
                ),
        ),
        boxShadow: isArchived
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildBadge(subject.gradeLevel),
              const Spacer(),
              if (isArchived) ...[
                IconButton(
                  tooltip: 'Restore subject',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(LucideIcons.rotateCcw, size: 18, color: theme.colorScheme.primary),
                  onPressed: () => _restoreSubject(subject),
                ),
                IconButton(
                  tooltip: 'Permanently delete',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(LucideIcons.trash2, size: 18, color: theme.colorScheme.error),
                  onPressed: () => _confirmPermanentDelete(subject),
                ),
              ] else ...[
                IconButton(
                  tooltip: 'Archive subject',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(LucideIcons.archive, size: 18, color: muted),
                  onPressed: () => _confirmArchive(subject),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subject.name,
            style: TextStyle(
              color: isArchived ? muted : theme.colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '$sectionCount ${sectionCount == 1 ? 'section' : 'sections'} · ${subject.studentCount} students',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Grading badges
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildBadge('WW ${subject.wwWeight}%', subtle: true, compact: true),
              _buildBadge('PT ${subject.ptWeight}%', subtle: true, compact: true),
              _buildBadge('EX ${subject.exWeight}%', subtle: true, compact: true),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.4)),
          const SizedBox(height: 8),
          ...subject.sections.map(
            (section) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(LucideIcons.users, size: 15, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      section.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    '${section.studentCount}',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          if (!isArchived)
            Row(
              children: [
                Expanded(
                  child: AppButton.outline(
                    icon: LucideIcons.userPlus,
                    label: 'Add Students',
                    onPressed: () => widget.onNavigateTo?.call(12),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => widget.onNavigateTo?.call(14),
                  icon: const Icon(LucideIcons.calendar, size: 15),
                  label: const Text('Schedule'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, {bool subtle = false, bool compact = false}) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: subtle
            ? theme.colorScheme.onSurface.withValues(alpha: 0.06)
            : primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: subtle
              ? theme.colorScheme.onSurface.withValues(alpha: 0.75)
              : primary,
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Add subject form
  // ═══════════════════════════════════════════════════════════════════

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
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            children: [
              if (isRequired)
                TextSpan(text: ' *', style: TextStyle(color: errorColor)),
            ],
          ),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        field,
        if (error != null) ...[
          const SizedBox(height: 6),
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

  void _showTemplateModal() {
    showDialog(
      context: context,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setState) {
            final filtered = _defaultTemplates.where(
              (t) => t.name.toLowerCase().contains(query.toLowerCase()),
            ).toList();
            return AlertDialog(
              title: const Text('Select Template'),
              content: SizedBox(
                width: 400,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search subjects...',
                        prefixIcon: Icon(LucideIcons.search, size: 18),
                      ),
                      onChanged: (val) => setState(() => query = val),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return ListTile(
                              title: const Text('Custom / Manual Entry'),
                              onTap: () {
                                this.setState(() => _selectedTemplate = null);
                                Navigator.pop(ctx);
                              },
                            );
                          }
                          final template = filtered[index - 1];
                          return ListTile(
                            title: Text(template.name),
                            subtitle: Text('WW ${template.ww}% · PT ${template.pt}% · EX ${template.ex}%'),
                            onTap: () {
                              _applyTemplate(template);
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAddSubjectForm() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final sectionCount = _sectionRows.length;
    final canAddSection = sectionCount < _maxSections;

    final templateField = _buildLabeledField(
      label: 'Template',
      field: InkWell(
        onTap: _showTemplateModal,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _selectedTemplate?.name ?? 'Custom / Manual Entry',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(LucideIcons.chevronDown, size: 18),
            ],
          ),
        ),
      ),
    );

    final subjectField = _buildLabeledField(
      label: 'Subject Name (Min 2, Max 60)',
      isRequired: true,
      error: _subjectError,
      field: TextField(
        controller: _subjectCtrl,
        focusNode: _subjectFocus,
        maxLength: 60,
        buildCounter: (_, {required currentLength, required isFocused, required maxLength}) => null,
        textInputAction: TextInputAction.next,
        onChanged: (_) {
          if (_selectedTemplate != null) setState(() => _selectedTemplate = null);
          _revalidateIfSubmitted();
        },
        // Auto-trim consecutive spaces
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9-., ]')),
        ],
        decoration: _boxDecoration(
          hint: 'e.g. General Mathematics',
          hasError: _subjectError != null,
        ),
      ),
    );

    final gradeField = _buildLabeledField(
      label: 'Grade Level',
      isRequired: true,
      field: DropdownButtonFormField<String>(
        initialValue: _gradeLevel,
        decoration: _boxDecoration(hasError: false),
        items: _gradeLevels
            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
            .toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() => _gradeLevel = value);
          _revalidateIfSubmitted();
        },
      ),
    );

    // Number formatters for weights
    final weightFormatters = [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(2),
    ];

    final wwField = _buildLabeledField(
      label: 'WRITTEN / ORAL WORKS (WWs) %',
      field: TextField(
        controller: _wwCtrl,
        keyboardType: TextInputType.number,
        inputFormatters: weightFormatters,
        decoration: _boxDecoration(hasError: false, hint: '0'),
        onChanged: (_) { if (_selectedTemplate != null) setState(() => _selectedTemplate = null); },
      ),
    );

    final ptField = _buildLabeledField(
      label: 'PRODUCT / PERFORMANCE TASKS (PTs) %',
      field: TextField(
        controller: _ptCtrl,
        keyboardType: TextInputType.number,
        inputFormatters: weightFormatters,
        decoration: _boxDecoration(hasError: false, hint: '0'),
        onChanged: (_) { if (_selectedTemplate != null) setState(() => _selectedTemplate = null); },
      ),
    );

    final exField = _buildLabeledField(
      label: 'EXAMINATIONS (EXs) %',
      field: TextField(
        controller: _exCtrl,
        keyboardType: TextInputType.number,
        inputFormatters: weightFormatters,
        decoration: _boxDecoration(hasError: false, hint: '0'),
        onChanged: (_) { if (_selectedTemplate != null) setState(() => _selectedTemplate = null); },
      ),
    );

    final bool isTotalValid = _isWeightValid;
    final totalColor = isTotalValid ? theme.colorScheme.primary : theme.colorScheme.error;
    
    final totalField = _buildLabeledField(
      label: 'TOTAL %',
      error: isTotalValid ? null : 'Must equal 100%',
      field: TextFormField(
        readOnly: true,
        controller: TextEditingController(text: '$_currentWeightTotal%'),
        style: TextStyle(
          color: totalColor,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: isTotalValid ? theme.colorScheme.outline.withValues(alpha: 0.4) : theme.colorScheme.error,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: isTotalValid ? theme.colorScheme.outline.withValues(alpha: 0.4) : theme.colorScheme.error,
            ),
          ),
        ),
      ),
    );
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(
            alpha: isDark ? 0.35 : 0.55,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add Subject',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'SY $_currentSchoolYear — Add a subject, configure its grading weights, and add sections.',
            style: TextStyle(fontSize: 13, color: muted),
          ),
          const SizedBox(height: 24),
          _buildSectionHeading('SUBJECT DETAILS'),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 600) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    templateField,
                    const SizedBox(height: 16),
                    subjectField,
                    const SizedBox(height: 16),
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
          const SizedBox(height: 24),
          _buildSectionHeading('GRADING WEIGHTS'),
          const SizedBox(height: 4),
          Text(
            'Configure grading distribution. Written Work (WW), Performance Task (PT), and Exam (EX) must sum to 100%.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 600) {
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
          const SizedBox(height: 24),
          Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.4)),
          const SizedBox(height: 24),
          _buildSectionHeading('SECTIONS ($sectionCount/$_maxSections)'),
          const SizedBox(height: 4),
          Text(
            'Add one or more sections for this subject.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < _sectionRows.length; i++) ...[
            _buildSectionRow(i, _sectionRows[i]),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              TextButton.icon(
                onPressed: canAddSection ? _addSectionRow : null,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Add another section'),
              ),
              if (!canAddSection) ...[
                const SizedBox(width: 8),
                Text(
                  'Maximum of $_maxSections sections.',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
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
                  ? const Center(child: CircularProgressIndicator())
                  : AppButton.primary(
                      label: sectionCount > 1
                          ? 'Save Subject · $sectionCount sections'
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
      label: 'Section Name (Min 2, Max 30)',
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

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'Section ${index + 1}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: canRemove
                          ? 'Remove section'
                          : 'At least one section is required',
                      onPressed: canRemove ? () => _removeSectionRow(row) : null,
                      icon: const Icon(LucideIcons.trash2, size: 18),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      nameField,
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            indexBadge,
            const SizedBox(width: 12),
            Expanded(flex: 2, child: nameField),
            const SizedBox(width: 4),
            removeButton,
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Form actions & validation
  // ═══════════════════════════════════════════════════════════════════

  void _addSectionRow() {
    if (_sectionRows.length >= _maxSections) return;
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
    // Basic trim to clean up multiple spaces
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
      subjectError =
          'You already have this subject for $_gradeLevel.';
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
      final rows = await SubjectRepository.instance.getTeacherSubjects(teacherId, schoolYear: _currentSchoolYear);
      
      final Map<String, _SubjectClass> grouped = {};
      
      for (var row in rows) {
        final id = row['id'].toString();
        final name = row['subject_name'];
        final glInt = row['grade_level'];
        final gl = 'Grade $glInt';
        final secName = row['section_name'];
        final ww = (row['ww_weight'] as num).toInt();
        final pt = (row['pt_weight'] as num).toInt();
        final ex = (row['ex_weight'] as num).toInt();
        
        final key = '${name}_$gl';
        if (!grouped.containsKey(key)) {
          grouped[key] = _SubjectClass(
            id: id,
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

      if (mounted) {
        setState(() {
          _subjects.clear();
          _subjects.addAll(grouped.values);
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: No active user.')));
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
      height: 235,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : const Color(0xFFFBFCFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? theme.colorScheme.outline.withValues(alpha: 0.5)
              : const Color(0xFFBFD3F5),
          style: BorderStyle.solid,
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
          const SizedBox(height: 16),
          Text(
            'No subjects in this school year yet.',
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Click Add Subject to add a subject and its sections.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
                  : const Color(0xFF8DA4C8),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // CRUD Actions
  // ═══════════════════════════════════════════════════════════════════

  void _confirmArchive(_SubjectClass subject) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Subject?'),
        content: Text(
          'Archiving "${subject.name}" will hide it from your active classroom.\n\n'
          'Sections, learning materials, and student records will become inactive but are kept safely. '
          'You can restore this subject later from the Archived Subjects section.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          AppButton.primary(
            label: 'Archive',
            onPressed: () {
              setState(() {
                _subjects.remove(subject);
                _archivedSubjects.add(subject);
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${subject.name} archived.')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _restoreSubject(_SubjectClass subject) {
    if (_subjects.length >= _maxSubjects) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot restore. Maximum of $_maxSubjects active subjects allowed.')),
      );
      return;
    }
    setState(() {
      _archivedSubjects.remove(subject);
      _subjects.add(subject);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${subject.name} restored.')),
    );
  }

  void _confirmPermanentDelete(_SubjectClass subject) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permanently Delete?'),
        content: Text(
          'Are you sure you want to permanently delete "${subject.name}"?\n\n'
          '⚠️ WARNING: This will permanently erase all sections, uploaded learning materials, and student records associated with this subject. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () {
              setState(() {
                _archivedSubjects.remove(subject);
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${subject.name} permanently deleted.')),
              );
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }
}
