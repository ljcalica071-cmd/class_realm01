import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';

class TeacherClassroomSetupTab extends StatefulWidget {
  final ValueChanged<int>? onNavigateTo;

  const TeacherClassroomSetupTab({
    super.key,
    this.onNavigateTo,
  });

  @override
  State<TeacherClassroomSetupTab> createState() =>
      _TeacherClassroomSetupTabState();
}

class _TeacherClassroomSetupTabState extends State<TeacherClassroomSetupTab> {
  bool _showNewSchoolYearForm = false;
  bool _showAddClassForm = false;
  final List<String> _classroomSections = ['Section A', 'Section B'];
  final Map<String, String> _classroomGrades = {
    'Section A': 'Grade 11',
    'Section B': 'Grade 11',
  };
  final Map<String, String> _classroomSubjects = {
    'Section A': 'General Mathematics',
    'Section B': 'General Mathematics',
  };
  final Map<String, int> _classroomStudentCounts = {
    'Section A': 5,
    'Section B': 5,
  };
  String _selectedSchoolYear = '2026-2027';
  String _newSchoolYearStructure = 'Quarterly (4 quarters)';
  String _newClassSchoolYear = 'SY 2026-2027';
  String _newClassGradeLevel = 'Grade 11';

  final _schoolYearCtrl = TextEditingController();
  final _schoolYearStartCtrl = TextEditingController(text: '01/06/2026');
  final _schoolYearEndCtrl = TextEditingController(text: '30/04/2027');
  final _classSectionCtrl = TextEditingController();
  final _classSubjectCtrl = TextEditingController();

  @override
  void dispose() {
    _schoolYearCtrl.dispose();
    _schoolYearStartCtrl.dispose();
    _schoolYearEndCtrl.dispose();
    _classSectionCtrl.dispose();
    _classSubjectCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = _classroomSections;
    final teacherName =
        MockDatabase.instance.currentUser?.fullName ?? 'Karen P. Gonzaga';

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
                          "$teacherName's Classroom",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Solo Teacher — Self-managed',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppButton.primary(
                    icon: LucideIcons.calendarDays,
                    label: 'New School Year',
                    onPressed: () {
                      _schoolYearCtrl.text = 'SY 2026-2027';
                      setState(
                        () => _showNewSchoolYearForm = !_showNewSchoolYearForm,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          if (_showNewSchoolYearForm) ...[
            const SizedBox(height: 12),
            _buildNewSchoolYearForm(),
          ],
          const SizedBox(height: 22),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(child: _buildSchoolYearSelector(theme)),
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: 'Edit school year',
                    onPressed: () =>
                        setState(() => _showNewSchoolYearForm = true),
                    icon: Icon(
                      LucideIcons.pencil,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete school year',
                    onPressed: () {},
                    icon: Icon(
                      LucideIcons.trash2,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  AppButton.primary(
                    icon: LucideIcons.plus,
                    label: 'Add Class${sections.isEmpty ? '' : ' (${sections.length}/10)'}',
                    onPressed: () =>
                        setState(() => _showAddClassForm = !_showAddClassForm),
                  ),
                ],
              ),
            ),
          ),
          if (_showAddClassForm) ...[
            const SizedBox(height: 12),
            _buildAddClassForm(),
          ],
          const SizedBox(height: 20),
          sections.isEmpty
              ? _buildEmptyClassroomState()
              : Wrap(
                  spacing: 18,
                  runSpacing: 18,
                  children: sections
                      .map(
                        (section) => _buildClassroomPrototypeCard(
                          section: section,
                          teacherName: teacherName,
                          gradeLevel: _classroomGrades[section] ?? 'Grade 11',
                          subject:
                              _classroomSubjects[section] ??
                              'General Mathematics',
                          studentCount: _classroomStudentCounts[section] ?? 0,
                        ),
                      )
                      .toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildClassroomPrototypeCard({
    required String section,
    required String teacherName,
    required String gradeLevel,
    required String subject,
    required int studentCount,
  }) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
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
              _buildClassroomBadge(gradeLevel),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  section,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: Color(0xFF64748B),
                ),
                onPressed: () {},
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Color(0xFF94A3B8),
                ),
                onPressed: () {
                  setState(() {
                    _classroomSections.remove(section);
                    _classroomGrades.remove(section);
                    _classroomSubjects.remove(section);
                    _classroomStudentCounts.remove(section);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildClassroomInfoTile(
            icon: Icons.people_outline,
            text: '$studentCount students',
            color: const Color(0xFFF3F6FC),
            iconColor: const Color(0xFF1A56DB),
          ),
          const SizedBox(height: 16),
          const Text(
            'SUBJECT',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          _buildClassroomInfoTile(
            text: subject,
            color: const Color(0xFFEFF6FF),
            borderColor: const Color(0xFFDBEAFE),
            textColor: const Color(0xFF1E293B),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton.icon(
              onPressed: () => widget.onNavigateTo?.call(12),
              icon: const Icon(Icons.person_add_alt, size: 17),
              label: const Text(
                'Add Students',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE8F8F0),
                foregroundColor: const Color(0xFF166534),
                elevation: 0,
                side: const BorderSide(color: Color(0xFFB9F6CA)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassroomBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE0EDFF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF1A56DB),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildClassroomInfoTile({
    required String text,
    required Color color,
    IconData? icon,
    Color? iconColor,
    Color? borderColor,
    Color? textColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: borderColor == null ? null : Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor ?? const Color(0xFF334155),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolYearSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.calendar,
            size: 18,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSchoolYear,
                isExpanded: true,
                icon: Icon(
                  LucideIcons.chevronDown,
                  color: theme.colorScheme.primary,
                ),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: theme.colorScheme.primary,
                ),
                items: const [
                  DropdownMenuItem(
                    value: '2026-2027',
                    child: Text('SY 2026-2027 (Current)'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedSchoolYear = value);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewSchoolYearForm() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE6F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'New School Year',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _buildSetupField('YEAR NAME', _schoolYearCtrl)),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _newSchoolYearStructure,
                  decoration: const InputDecoration(
                    labelText: 'STRUCTURE',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Quarterly (4 quarters)',
                      child: Text('Quarterly (4 quarters)'),
                    ),
                    DropdownMenuItem(
                      value: 'Semester (2 semesters)',
                      child: Text('Semester (2 semesters)'),
                    ),
                    DropdownMenuItem(
                      value: 'Trimester (3 terms)',
                      child: Text('Trimester (3 terms)'),
                    ),
                  ],
                  menuMaxHeight: 280,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _newSchoolYearStructure = value);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDateField('START DATE', _schoolYearStartCtrl),
              ),
              const SizedBox(width: 16),
              Expanded(child: _buildDateField('END DATE', _schoolYearEndCtrl)),
            ],
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 10,
              children: [
                AppButton.outline(
                  label: 'Cancel',
                  onPressed: () =>
                      setState(() => _showNewSchoolYearForm = false),
                ),
                AppButton.primary(
                  label: 'Create School Year',
                  onPressed: () {
                    setState(() {
                      _selectedSchoolYear = _schoolYearCtrl.text
                          .trim()
                          .replaceFirst('SY ', '');
                      MockDatabase.instance.academicYear = _selectedSchoolYear;
                      _showNewSchoolYearForm = false;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildDateField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
      ),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(2040),
          initialDate: DateTime.now(),
        );
        if (picked != null) {
          controller.text =
              '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
        }
      },
    );
  }

  Widget _buildAddClassForm() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE6F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add New Class',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _newClassSchoolYear,
                  decoration: const InputDecoration(
                    labelText: 'SCHOOL YEAR',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'SY 2026-2027',
                      child: Text('SY 2026-2027'),
                    ),
                  ],
                  menuMaxHeight: 280,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _newClassSchoolYear = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _newClassGradeLevel,
                  decoration: const InputDecoration(
                    labelText: 'GRADE LEVEL',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Kinder', child: Text('Kinder')),
                    DropdownMenuItem(value: 'Grade 1', child: Text('Grade 1')),
                    DropdownMenuItem(value: 'Grade 2', child: Text('Grade 2')),
                    DropdownMenuItem(value: 'Grade 3', child: Text('Grade 3')),
                    DropdownMenuItem(value: 'Grade 4', child: Text('Grade 4')),
                    DropdownMenuItem(value: 'Grade 5', child: Text('Grade 5')),
                    DropdownMenuItem(value: 'Grade 6', child: Text('Grade 6')),
                    DropdownMenuItem(value: 'Grade 7', child: Text('Grade 7')),
                    DropdownMenuItem(value: 'Grade 8', child: Text('Grade 8')),
                    DropdownMenuItem(value: 'Grade 9', child: Text('Grade 9')),
                    DropdownMenuItem(
                      value: 'Grade 10',
                      child: Text('Grade 10'),
                    ),
                    DropdownMenuItem(
                      value: 'Grade 11',
                      child: Text('Grade 11'),
                    ),
                    DropdownMenuItem(
                      value: 'Grade 12',
                      child: Text('Grade 12'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _newClassGradeLevel = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSetupField('SECTION NAME', _classSectionCtrl),
              ),
              const SizedBox(width: 16),
              Expanded(child: _buildSetupField('SUBJECT', _classSubjectCtrl)),
            ],
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 10,
              children: [
                AppButton.outline(
                  label: 'Cancel',
                  onPressed: () => setState(() => _showAddClassForm = false),
                ),
                AppButton.primary(
                  label: 'Add Class',
                  onPressed: _addClassFromForm,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addClassFromForm() {
    final section = _classSectionCtrl.text.trim();
    final subject = _classSubjectCtrl.text.trim();

    String? errorMessage;
    if (section.isEmpty) {
      errorMessage = 'Please enter a section name.';
    } else if (subject.isEmpty) {
      errorMessage = 'Please enter the subject handled for this class.';
    } else if (_classroomSections.contains(section)) {
      errorMessage = 'That section has already been added.';
    } else if (_classroomSections.length >= 10) {
      errorMessage = 'You can add up to 10 classes.';
    }

    if (errorMessage != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(errorMessage)));
      return;
    }

    setState(() {
      _classroomSections.add(section);
      _classroomGrades[section] = _newClassGradeLevel;
      _classroomSubjects[section] = subject;
      _classroomStudentCounts[section] = 0;
      _classSectionCtrl.clear();
      _classSubjectCtrl.clear();
      _showAddClassForm = false;
    });
  }

  Widget _buildEmptyClassroomState() {
    return Container(
      height: 235,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFBFD3F5),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book_outlined, size: 38, color: Color(0xFF94A8C4)),
          const SizedBox(height: 16),
          Text(
            'No classes in this school year yet.',
            style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          SizedBox(height: 8),
          Text(
            'Click Add Class to create your first section.',
            style: TextStyle(fontSize: 14, color: Color(0xFF8DA4C8)),
          ),
        ],
      ),
    );
  }
}
