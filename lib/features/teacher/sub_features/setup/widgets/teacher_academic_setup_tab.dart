import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/models/subject_catalog_model.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';

class TeacherAcademicSetupTab extends StatefulWidget {
  const TeacherAcademicSetupTab({super.key});

  @override
  State<TeacherAcademicSetupTab> createState() =>
      _TeacherAcademicSetupTabState();
}

class _TeacherAcademicSetupTabState extends State<TeacherAcademicSetupTab> {
  late String _academicYear;
  late String _gradeLevel;
  late String _selectedCategory;
  late String _selectedCluster;
  late String _selectedSubject;
  late List<String> _sections;
  final _newSectionCtrl = TextEditingController();

  double _wwWeight = 20.0;
  double _ptWeight = 50.0;
  double _exWeight = 30.0;
  final bool _customWeightOverride = false;

  @override
  void initState() {
    super.initState();
    final current = AuthRepository.instance.currentUser;
    final year = DateTime.now().year >= 2026 ? DateTime.now().year : 2026;
    _academicYear = '$year-${year + 1}';
    _gradeLevel = current?.gradeLevel ?? 'Grade 11';
    _selectedCategory = DepEdSubjectCatalog.catCore;
    _selectedCluster = 'CORE';
    _selectedSubject = current?.departmentOrSection ?? 'General Mathematics';
    _sections = ['$_gradeLevel - Section A'];

    // Auto-detect category & cluster if matching current subject
    final match = DepEdSubjectCatalog.allSubjects.firstWhere(
      (s) => s.name.toLowerCase() == _selectedSubject.toLowerCase(),
      orElse: () => DepEdSubjectCatalog.allSubjects.first,
    );
    _selectedCategory = match.category;
    _selectedCluster = match.cluster;
    _wwWeight = match.wwWeight;
    _ptWeight = match.ptWeight;
    _exWeight = match.exWeight;
  }

  @override
  void dispose() {
    _newSectionCtrl.dispose();
    super.dispose();
  }

  void _applyCategoryChange(String newCat) {
    setState(() {
      _selectedCategory = newCat;
      final clusters = DepEdSubjectCatalog.getClusters(newCat);
      _selectedCluster = clusters.isNotEmpty ? clusters.first : 'CORE';
      final subjects = DepEdSubjectCatalog.getSubjects(
        category: _selectedCategory,
        cluster: _selectedCluster,
        gradeLevel: _gradeLevel,
      );
      _selectedSubject = subjects.isNotEmpty ? subjects.first.name : 'General Mathematics';

      if (!_customWeightOverride) {
        final weights = DepEdSubjectCatalog.getDefaultWeights(newCat);
        _wwWeight = weights['ww']!;
        _ptWeight = weights['pt']!;
        _exWeight = weights['ex']!;
      }
    });
  }

  void _addSection() {
    final text = _newSectionCtrl.text.trim();
    if (text.isEmpty) return;
    if (_sections.contains(text)) return;
    setState(() {
      _sections.add(text);
      _newSectionCtrl.clear();
    });
  }

  void _removeSection(String sec) {
    if (_sections.length <= 1) return;
    setState(() => _sections.remove(sec));
  }

  void _saveConfiguration() {
    final current = AuthRepository.instance.currentUser;
    if (current != null) {
      final updated = current.copyWith(
        departmentOrSection: _selectedSubject,
        gradeLevel: _gradeLevel,
      );
      AuthRepository.instance.setCurrentUser(updated);
    }

    AppModals.showSuccessDialog(
      context: context,
      title: 'Academic Configuration Saved',
      message:
          'Your active subject is now set to "$_selectedSubject" with grading weights ${_wwWeight.round()}% WW, ${_ptWeight.round()}% PT, ${_exWeight.round()}% EX under S.Y. $_academicYear.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availableClusters = DepEdSubjectCatalog.getClusters(_selectedCategory);
    final availableSubjects = DepEdSubjectCatalog.getSubjects(
      category: _selectedCategory,
      cluster: _selectedCluster,
      gradeLevel: _gradeLevel,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(32),
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
                            'Teacher Academic Setup',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'DepEd Order No. 15, s. 2026 Curriculum Configuration',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Chip(
                        avatar: const Icon(LucideIcons.calendar, size: 14),
                        label: Text(_academicYear, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                        side: BorderSide.none,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Grade Level Selector
                  Text('Grade Level', style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 8),
                  Row(
                    children: ['Grade 11', 'Grade 12'].map((g) {
                      final isSelected = _gradeLevel == g;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: ChoiceChip(
                          label: Text(g),
                          selected: isSelected,
                          selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (sel) {
                            if (sel) setState(() => _gradeLevel = g);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Category Dropdown
                  Text('Subject Category', style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        isExpanded: true,
                        items: DepEdSubjectCatalog.categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) {
                          if (v != null) _applyCategoryChange(v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Cluster & Subject Selection
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cluster / Strand', style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: availableClusters.contains(_selectedCluster) ? _selectedCluster : availableClusters.first,
                                  isExpanded: true,
                                  items: availableClusters.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() {
                                        _selectedCluster = v;
                                        final subjs = DepEdSubjectCatalog.getSubjects(
                                          category: _selectedCategory,
                                          cluster: _selectedCluster,
                                          gradeLevel: _gradeLevel,
                                        );
                                        if (subjs.isNotEmpty) _selectedSubject = subjs.first.name;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Primary Subject', style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: availableSubjects.any((s) => s.name == _selectedSubject)
                                      ? _selectedSubject
                                      : (availableSubjects.isNotEmpty ? availableSubjects.first.name : _selectedSubject),
                                  isExpanded: true,
                                  items: availableSubjects.map((s) => DropdownMenuItem(value: s.name, child: Text(s.name, overflow: TextOverflow.ellipsis))).toList(),
                                  onChanged: (v) {
                                    if (v != null) setState(() => _selectedSubject = v);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Grading Weights Preview
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMiniWeight('Written Works', '${_wwWeight.round()}%', AppTheme.catBlue),
                        _buildMiniWeight('Performance Tasks', '${_ptWeight.round()}%', AppTheme.catGreen),
                        _buildMiniWeight('Quarterly Exam', '${_exWeight.round()}%', AppTheme.catOrange),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sections Management
                  Text('Managed Sections', style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newSectionCtrl,
                          decoration: InputDecoration(
                            hintText: 'e.g. $_gradeLevel - Darwin',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onSubmitted: (_) => _addSection(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _addSection,
                        child: const Text('Add Section'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _sections.map((sec) {
                      return Chip(
                        label: Text(sec, style: const TextStyle(fontWeight: FontWeight.w600)),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => _removeSection(sec),
                        backgroundColor: AppTheme.catBlue.withValues(alpha: 0.12),
                        side: BorderSide.none,
                        labelStyle: const TextStyle(color: AppTheme.catBlue),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: AppButton.primary(
                      label: 'Save Academic Configuration',
                      icon: LucideIcons.save,
                      onPressed: _saveConfiguration,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniWeight(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
