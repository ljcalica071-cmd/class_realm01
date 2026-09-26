import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';

class TeacherGradebookTab extends StatefulWidget {
  const TeacherGradebookTab({super.key});

  @override
  State<TeacherGradebookTab> createState() => _TeacherGradebookTabState();
}

class _TeacherGradebookTabState extends State<TeacherGradebookTab> {
  bool _isEditingWeights = false;
  final _weightWWCtrl = TextEditingController(text: '20');
  final _weightPTCtrl = TextEditingController(text: '50');
  final _weightEXCtrl = TextEditingController(text: '30');

  @override
  void dispose() {
    _weightWWCtrl.dispose();
    _weightPTCtrl.dispose();
    _weightEXCtrl.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradeItems = <String, List<Map<String, String>>>{
      'Written Works (WW)': [],
      'Performance Task (PT)': [],
      'Examinations (EX)': [],
    };
    final database = MockDatabase.instance;

    String formatDate(DateTime date) =>
        '${_monthName(date.month)} ${date.day}, ${date.year}';

    for (final activity in database.activities) {
      gradeItems[activity.isRequirement
              ? 'Performance Task (PT)'
              : 'Written Works (WW)']!
          .add({
            'name': activity.title,
            'points': '${activity.maxScore.toStringAsFixed(0)} pts',
            'date': formatDate(activity.dateAssigned),
          });
    }

    for (final assessment in database.quizzesAndExams) {
      if (!assessment.isExam) {
        gradeItems['Written Works (WW)']!.add({
          'name': assessment.title,
          'points': '${assessment.totalPoints.toStringAsFixed(0)} pts',
          'date': formatDate(assessment.scheduleDate),
        });
        continue;
      }

      gradeItems['Examinations (EX)']!.add({
        'header': assessment.id == 'EX3'
            ? 'Term Examination'
            : assessment.title,
        'name': assessment.title,
        'weight': assessment.id == 'EX3' ? '40%' : '30%',
        'points': '${assessment.totalPoints.toStringAsFixed(0)}pts',
        'date': formatDate(assessment.scheduleDate),
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      const Text(
                        'Grading Period:',
                        style: TextStyle(
                          color: Color(0xFF334155),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      _buildGradebookDropdown(
                        label: '',
                        value: 'Quarter 1',
                        options: const [
                          'Quarter 1',
                          'Quarter 2',
                          'Quarter 3',
                          'Quarter 4',
                        ],
                        width: 120,
                      ),
                      const Text(
                        'Class:',
                        style: TextStyle(
                          color: Color(0xFF334155),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      _buildGradebookDropdown(
                        label: '',
                        value: 'Grade 11 - Section A - General Mathematics',
                        options: const [
                          'Grade 11 - Section A - General Mathematics',
                          'Grade 11 - Section B - General Mathematics',
                        ],
                        width: 270,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(bottom: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.12))),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.bookOpenCheck,
                        color: theme.colorScheme.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gradebook - Quarter 1',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Grade 11 - Section A - General Mathematics',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Grades are automatically computed from grade items:',
                            style: TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Build the grade from written work, performance tasks and exams. ClassRealm computes it based on the weighted components defined below.',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_isEditingWeights)
                        _buildGradeWeightEditor()
                      else
                        Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildGradebookInfoChip(
                                    'DepEd Order No. 015, s. 2026',
                                    const Color(0xFFE8F8F0),
                                    const Color(0xFF166534),
                                  ),
                                  _buildGradeWeightChip(
                                    'WW',
                                    '${_weightWWCtrl.text}%',
                                  ),
                                  _buildGradeWeightChip(
                                    'PT',
                                    '${_weightPTCtrl.text}%',
                                  ),
                                  _buildGradeWeightChip(
                                    'EX',
                                    '${_weightEXCtrl.text}%',
                                  ),
                                  _buildGradebookInfoChip(
                                    'EX = ST-1:30% + ST-2:30% + EX:40%',
                                    const Color(0xFFF3F0FF),
                                    const Color(0xFF6D28D9),
                                  ),
                                ],
                              ),
                            ),
                            AppSecondaryButton(
                              label: 'Edit Weights',
                              icon: Icons.tune,
                              height: 36,
                              onPressed: () =>
                                  setState(() => _isEditingWeights = true),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...gradeItems.entries.expand(
            (entry) => entry.key == 'Examinations (EX)'
                ? entry.value.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildGradebookSection(
                        item['header'] ?? item['name']!,
                        [item],
                        showItemName: true,
                        sectionWeight: item['weight'],
                      ),
                    ),
                  )
                : [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildGradebookSection(entry.key, entry.value),
                    ),
                  ],
          ),
        ],
      ),
    );
  }

  Widget _buildGradeWeightEditor() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Text(
            'WW',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(width: 8),
          _buildWeightInputField(_weightWWCtrl),
          const SizedBox(width: 6),
          const Text(
            '%',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 20),
          const Text(
            'PT',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(width: 8),
          _buildWeightInputField(_weightPTCtrl),
          const SizedBox(width: 6),
          const Text(
            '%',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 20),
          const Text(
            'EX',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(width: 8),
          _buildWeightInputField(_weightEXCtrl),
          const SizedBox(width: 6),
          const Text(
            '%  =',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '100%',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(0xFF059669),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() => _isEditingWeights = false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {
              final ww = int.tryParse(_weightWWCtrl.text) ?? 0;
              final pt = int.tryParse(_weightPTCtrl.text) ?? 0;
              final ex = int.tryParse(_weightEXCtrl.text) ?? 0;
              final total = ww + pt + ex;

              if (total != 100) {
                AppModals.showErrorDialog(
                  context: context,
                  title: 'Invalid Configuration',
                  message:
                      'The total percentage must equal exactly 100%. Current total: $total%',
                );
                return;
              }

              setState(() => _isEditingWeights = false);
              AppModals.showSuccessDialog(
                context: context,
                title: 'Weights Updated',
                message:
                    'Gradebook weighting criteria has been updated successfully.',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightInputField(TextEditingController controller) {
    return Container(
      width: 50,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
        ),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E293B),
        ),
      ),
    );
  }

  Widget _buildGradebookDropdown({
    required String label,
    required String value,
    required List<String> options,
    double width = 350,
  }) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: value,
        decoration: InputDecoration(
          labelText: label.isEmpty ? null : label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          isDense: true,
        ),
        items: options
            .map(
              (option) => DropdownMenuItem(
                value: option,
                child: Text(
                  option,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            )
            .toList(),
        onChanged: (_) {},
      ),
    );
  }

  Widget _buildGradebookInfoChip(
    String label,
    Color backgroundColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
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

  Widget _buildGradeWeightChip(String label, String weight) {
    return Chip(
      label: Text('$label  $weight'),
      backgroundColor: const Color(0xFFE0F2FE),
      labelStyle: const TextStyle(
        color: Color(0xFF0369A1),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide.none,
    );
  }

  Widget _buildGradebookSection(
    String title,
    List<Map<String, String>> items, {
    bool showItemName = true,
    String? sectionWeight,
  }) {
    final isWrittenWork = title == 'Written Works (WW)';
    final isPerformance = title == 'Performance Task (PT)';
    final headerColor = isWrittenWork
        ? const Color(0xFF1D4ED8)
        : isPerformance
        ? const Color(0xFF059669)
        : const Color(0xFF6D28D9);
    final headerIcon = isWrittenWork
        ? Icons.description_outlined
        : isPerformance
        ? Icons.task_alt
        : Icons.edit_note_outlined;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1E3A8A),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  headerColor,
                  Color.lerp(headerColor, Colors.black, 0.18) ?? headerColor,
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(headerIcon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${items.length} ITEM${items.length == 1 ? '' : 'S'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    sectionWeight ?? _gradebookSectionWeight(title),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...items.map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      showItemName ? item['name']! : item['points']!,
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  AppButton.outline(
                    onPressed: () {},
                    icon: LucideIcons.eye,
                    label: 'View Scores',
                    isSmall: true,
                  ),
                  const SizedBox(width: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      item['points']!,
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 90,
                    child: Text(
                      item['date']!,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _gradebookSectionWeight(String title) {
    if (title == 'Written Works (WW)') return '20%';
    if (title == 'Performance Task (PT)') return '50%';
    return '30%';
  }
}
