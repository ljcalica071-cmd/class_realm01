import 'package:flutter/material.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/user_model.dart';

class TeacherGradesTab extends StatefulWidget {
  final List<UserModel> students;

  const TeacherGradesTab({
    super.key,
    required this.students,
  });

  @override
  State<TeacherGradesTab> createState() => _TeacherGradesTabState();
}

class _TeacherGradesTabState extends State<TeacherGradesTab> {
  String _gradesSectionFilter = 'All Sections';
  String _gradesRankingOrder = 'None';

  double _quarterlyGradeFor(String studentId) {
    return 85.0;
  }

  @override
  Widget build(BuildContext context) {
    final sections = <String>{
      for (final s in widget.students)
        if (s.departmentOrSection != null && s.departmentOrSection!.isNotEmpty)
          s.departmentOrSection!,
    }.toList()..sort();

    var filteredList = widget.students.where((s) {
      if (_gradesSectionFilter == 'All Sections') return true;
      return s.departmentOrSection == _gradesSectionFilter;
    }).toList();

    if (_gradesRankingOrder == 'Highest to Lowest') {
      filteredList.sort(
        (a, b) => _quarterlyGradeFor(b.id).compareTo(_quarterlyGradeFor(a.id)),
      );
    } else if (_gradesRankingOrder == 'Lowest to Highest') {
      filteredList.sort(
        (a, b) => _quarterlyGradeFor(a.id).compareTo(_quarterlyGradeFor(b.id)),
      );
    }

    String getDescriptor(double grade) {
      if (grade >= 90) return 'Outstanding';
      if (grade >= 85) return 'Very Satisfactory';
      if (grade >= 80) return 'Satisfactory';
      if (grade >= 75) return 'Fairly Satisfactory';
      return 'Did Not Meet Expectations';
    }

    String getRemarks(double grade) {
      return grade >= 75 ? 'Passed' : 'Failed';
    }

    Color getGradeColor(double grade) {
      if (grade >= 90) return AppTheme.catGreen;
      if (grade >= 75) return const Color(0xFF1D4ED8);
      return AppTheme.catRed;
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quarterly Grades Computation',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  _buildGradesFilterDropdown(
                    label: 'Section:',
                    value: _gradesSectionFilter,
                    items: ['All Sections', ...sections],
                    onChanged: (val) =>
                        setState(() => _gradesSectionFilter = val!),
                  ),
                  const SizedBox(width: 16),
                  _buildGradesFilterDropdown(
                    label: 'Ranking:',
                    value: _gradesRankingOrder,
                    items: ['None', 'Highest to Lowest', 'Lowest to Highest'],
                    onChanged: (val) =>
                        setState(() => _gradesRankingOrder = val!),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
              ),
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      border: Border(
                        bottom: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'STUDENT NAME',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'LRN',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Center(
                            child: Text(
                              'GRADE',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Text(
                              'DESCRIPTOR',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Center(
                            child: Text(
                              'REMARKS',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filteredList.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final s = filteredList[i];
                        final grade = _quarterlyGradeFor(s.id);
                        final descriptor = getDescriptor(grade);
                        final remarks = getRemarks(grade);
                        final color = getGradeColor(grade);

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: AppTheme.catPurple,
                                      child: Text(
                                        s.fullName.substring(0, 1),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      s.fullName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  s.lrn ?? s.studentId ?? 'N/A',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Center(
                                  child: Text(
                                    grade.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      descriptor,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Center(
                                  child: Text(
                                    remarks,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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

  Widget _buildGradesFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isDense: true,
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.primary),
              items: items
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
