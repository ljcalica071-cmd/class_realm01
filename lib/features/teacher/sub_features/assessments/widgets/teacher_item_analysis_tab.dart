import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/academic_models.dart';

class TeacherItemAnalysisTab extends StatefulWidget {
  final List<QuizOrExamModel> quizzes;

  const TeacherItemAnalysisTab({
    super.key,
    required this.quizzes,
  });

  @override
  State<TeacherItemAnalysisTab> createState() => _TeacherItemAnalysisTabState();
}

class _TeacherItemAnalysisTabState extends State<TeacherItemAnalysisTab> {
  String _selectedItemAnalysisAssessment = 'Summative Test 1 (ST1)';

  final Map<String, List<Map<String, dynamic>>> _mockItemData = {
    'Summative Test 1 (ST1)': [
      {
        'q': '1',
        'concept': 'Domain of rational function',
        'correct': 8,
        'wrong': 2,
        'percent': '80%',
        'difficulty': 'Easy',
      },
      {
        'q': '2',
        'concept': 'Vertical asymptote properties',
        'correct': 6,
        'wrong': 4,
        'percent': '60%',
        'difficulty': 'Moderate',
      },
      {
        'q': '3',
        'concept': 'Piecewise function evaluation',
        'correct': 7,
        'wrong': 3,
        'percent': '70%',
        'difficulty': 'Moderate',
      },
    ],
    'Summative Test 2 (ST2)': [
      {
        'q': '1',
        'concept': 'Exponential growth modeling',
        'correct': 9,
        'wrong': 1,
        'percent': '90%',
        'difficulty': 'Easy',
      },
      {
        'q': '2',
        'concept': 'Logarithmic properties',
        'correct': 5,
        'wrong': 5,
        'percent': '50%',
        'difficulty': 'Hard',
      },
    ],
    'Term Examination (TE)': [
      {
        'q': '1',
        'concept': 'Comprehensive Functions',
        'correct': 7,
        'wrong': 3,
        'percent': '70%',
        'difficulty': 'Moderate',
      },
      {
        'q': '2',
        'concept': 'Inverse Functions',
        'correct': 8,
        'wrong': 2,
        'percent': '80%',
        'difficulty': 'Easy',
      },
      {
        'q': '3',
        'concept': 'Compound Interest Applications',
        'correct': 4,
        'wrong': 6,
        'percent': '40%',
        'difficulty': 'Hard',
      },
      {
        'q': '4',
        'concept': 'Exponential Equations',
        'correct': 6,
        'wrong': 4,
        'percent': '60%',
        'difficulty': 'Moderate',
      },
    ],
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentData =
        _mockItemData[_selectedItemAnalysisAssessment] ??
        _mockItemData.values.first;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Item Analysis Dashboard',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Evaluate question difficulty index and student correctness percentages.',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.12)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedItemAnalysisAssessment,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    items: _mockItemData.keys
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedItemAnalysisAssessment = v);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_selectedItemAnalysisAssessment - Item Breakdown',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Table(
                  border: TableBorder.all(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                    width: 1,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  columnWidths: const {
                    0: IntrinsicColumnWidth(),
                    1: FlexColumnWidth(4),
                    2: FlexColumnWidth(1),
                    3: FlexColumnWidth(1),
                    4: FlexColumnWidth(1.5),
                    5: FlexColumnWidth(1.5),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: theme.colorScheme.surface),
                      children: [
                        _buildTableHeader('Q #', theme),
                        _buildTableHeader('Question Concept', theme),
                        _buildTableHeader('Correct', theme),
                        _buildTableHeader('Wrong', theme),
                        _buildTableHeader('% Correct', theme),
                        _buildTableHeader('Difficulty', theme),
                      ],
                    ),
                    ...currentData.map((item) {
                      final diffColor = item['difficulty'] == 'Easy'
                          ? AppTheme.catGreen
                          : (item['difficulty'] == 'Moderate'
                                ? AppTheme.catOrange
                                : AppTheme.catRed);
                      return TableRow(
                        children: [
                          _buildTableCell(item['q'].toString(), theme),
                          _buildTableCell(item['concept'].toString(), theme),
                          _buildTableCell(
                            item['correct'].toString(),
                            theme,
                            alignment: Alignment.center,
                          ),
                          _buildTableCell(
                            item['wrong'].toString(),
                            theme,
                            alignment: Alignment.center,
                          ),
                          _buildTableCell(
                            item['percent'].toString(),
                            theme,
                            alignment: Alignment.center,
                            textStyle: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          _buildTableCell(
                            item['difficulty'].toString(),
                            theme,
                            alignment: Alignment.center,
                            textStyle: TextStyle(
                              color: diffColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String label, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.onSurface),
      ),
    );
  }

  Widget _buildTableCell(
    String text,
    ThemeData theme, {
    Alignment alignment = Alignment.centerLeft,
    TextStyle? textStyle,
  }) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.all(12),
      child: Text(text, style: textStyle ?? TextStyle(fontSize: 13, color: theme.colorScheme.onSurface)),
    );
  }
}
