import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:class_realm/core/constants/asset_paths.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/models/subject_catalog_model.dart';
import 'package:class_realm/routes/app_routes.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';

class AcademicSetupWizardScreen extends StatefulWidget {
  const AcademicSetupWizardScreen({super.key});

  @override
  State<AcademicSetupWizardScreen> createState() => _AcademicSetupWizardScreenState();
}

class _AcademicSetupWizardScreenState extends State<AcademicSetupWizardScreen> {
  int _currentStep = 0;
  bool _isSaving = false;

  // Step 1: School Year & Term Setup
  String _schoolYear = '2026-2027';
  final String _termStructure = '3 Terms (Trimester) — DepEd DO 15, s. 2026';
  final DateTime _term1Start = DateTime(2026, 8, 24);
  final DateTime _term1End = DateTime(2026, 11, 27);
  final DateTime _term2Start = DateTime(2026, 12, 1);
  final DateTime _term2End = DateTime(2027, 3, 12);
  final DateTime _term3Start = DateTime(2027, 3, 15);
  final DateTime _term3End = DateTime(2027, 6, 18);

  // Step 2: Grade Level, Track & Subject Area
  String _selectedGradeLevel = 'Grade 11';
  String _selectedCategory = DepEdSubjectCatalog.catCore;
  String _selectedCluster = 'CORE';
  String _selectedSubject = 'General Mathematics';

  // Component Weights
  double _wwWeight = 20.0;
  double _ptWeight = 50.0;
  double _exWeight = 30.0;
  bool _customWeightOverride = false;

  // Step 3: Sections Setup
  final _sectionCtrl = TextEditingController();
  final List<String> _sections = ['Grade 11 - Einstein', 'Grade 11 - Newton'];

  @override
  void initState() {
    super.initState();
    _applyPresetWeights();
  }

  @override
  void dispose() {
    _sectionCtrl.dispose();
    super.dispose();
  }

  void _applyPresetWeights() {
    final weights = DepEdSubjectCatalog.getDefaultWeights(_selectedCategory);
    setState(() {
      _wwWeight = weights['ww']!;
      _ptWeight = weights['pt']!;
      _exWeight = weights['ex']!;
    });
  }

  void _onCategoryChanged(String? newCat) {
    if (newCat == null) return;
    setState(() {
      _selectedCategory = newCat;
      final clusters = DepEdSubjectCatalog.getClusters(newCat);
      _selectedCluster = clusters.isNotEmpty ? clusters.first : 'CORE';

      final subjects = DepEdSubjectCatalog.getSubjects(
        category: _selectedCategory,
        cluster: _selectedCluster,
        gradeLevel: _selectedGradeLevel,
      );
      _selectedSubject = subjects.isNotEmpty ? subjects.first.name : 'General Mathematics';

      if (!_customWeightOverride) {
        _applyPresetWeights();
      }
    });
  }

  void _onClusterChanged(String? newCluster) {
    if (newCluster == null) return;
    setState(() {
      _selectedCluster = newCluster;
      final subjects = DepEdSubjectCatalog.getSubjects(
        category: _selectedCategory,
        cluster: _selectedCluster,
        gradeLevel: _selectedGradeLevel,
      );
      _selectedSubject = subjects.isNotEmpty ? subjects.first.name : 'General Mathematics';
    });
  }

  void _addSection() {
    final text = _sectionCtrl.text.trim();
    if (text.isEmpty) return;
    if (_sections.contains(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Section already exists.')),
      );
      return;
    }
    setState(() {
      _sections.add(text);
      _sectionCtrl.clear();
    });
  }

  void _removeSection(String sec) {
    if (_sections.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must have at least one section.')),
      );
      return;
    }
    setState(() {
      _sections.remove(sec);
    });
  }

  void _handleFinalizeSetup() async {
    setState(() => _isSaving = true);
    
    final current = AuthRepository.instance.currentUser;
    if (current != null) {
      await AuthRepository.instance.completeAcademicSetup(
        uid: current.id, 
        gradeLevel: _selectedGradeLevel, 
        subjectName: _selectedSubject,
        sections: _sections,
        schoolYear: _schoolYear,
        wwWeight: _wwWeight,
        ptWeight: _ptWeight,
        exWeight: _exWeight,
      );
    }
    
    if (!mounted) return;
    setState(() => _isSaving = false);

    // Success dialog
    AppModals.showSuccessDialog(
      context: context,
      title: 'Academic Setup Completed! 🎉',
      message:
          'Welcome to ClassRealm! Your teaching curriculum for $_selectedSubject ($selectedWeightFormula) has been configured. You are now being redirected to your dashboard.',
      onConfirm: () {
        Navigator.pushReplacementNamed(context, AppRoutes.teacherDashboard);
      },
    );
  }

  String get selectedWeightFormula =>
      '${_wwWeight.toStringAsFixed(0)}% WW • ${_ptWeight.toStringAsFixed(0)}% PT • ${_exWeight.toStringAsFixed(0)}% EX';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Row(
          children: [
            Image.asset(
              AssetPaths.schoolLogo,
              width: 32,
              height: 32,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Academic Setup Wizard',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  'DepEd Order No. 15, s. 2026 Onboarding',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Chip(
              avatar: const Icon(LucideIcons.sparkles, size: 14, color: AppTheme.catPurple),
              label: Text(
                'Step ${_currentStep + 1} of 4',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              backgroundColor: AppTheme.catPurple.withValues(alpha: 0.1),
              side: BorderSide.none,
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 860),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: EdgeInsets.all(isDesktop ? 36 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Progress Stepper
                _buildStepper(theme),
                const SizedBox(height: 32),

                // Active Step Content
                if (_currentStep == 0) _buildStep1SchoolYear(theme),
                if (_currentStep == 1) _buildStep2SubjectAndWeights(theme, isDesktop),
                if (_currentStep == 2) _buildStep3Sections(theme),
                if (_currentStep == 3) _buildStep4Review(theme, isDesktop),

                const SizedBox(height: 36),
                const Divider(),
                const SizedBox(height: 20),

                // Navigation Buttons (Back & Next/Finish)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentStep > 0)
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _currentStep--),
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text('Back'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    if (_currentStep < 3)
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _currentStep++),
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        label: const Text('Next Step'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _handleFinalizeSetup,
                        icon: _isSaving
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: LoadingAnimationWidget.staggeredDotsWave(color: Colors.white, size: 18),
                              )
                            : const Icon(LucideIcons.checkCheck, size: 18),
                        label: Text(_isSaving ? 'Configuring System...' : 'Finalize & Launch Dashboard'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.catGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- STEPPER PROGRESS BAR ---
  Widget _buildStepper(ThemeData theme) {
    final steps = ['School Year', 'Subject & Weights', 'Sections', 'Confirmation'];
    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          final stepIdx = index ~/ 2;
          final isPassed = _currentStep > stepIdx;
          return Expanded(
            child: Container(
              height: 3,
              color: isPassed ? theme.colorScheme.primary : theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          );
        }

        final stepIdx = index ~/ 2;
        final isActive = _currentStep == stepIdx;
        final isCompleted = _currentStep > stepIdx;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: isCompleted
                  ? AppTheme.catGreen
                  : (isActive ? theme.colorScheme.primary : theme.colorScheme.outline.withValues(alpha: 0.2)),
              child: isCompleted
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : Text(
                      '${stepIdx + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isActive ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            Text(
              steps[stepIdx],
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        );
      }),
    );
  }

  // --- STEP 1: SCHOOL YEAR & CALENDAR ---
  Widget _buildStep1SchoolYear(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '1. School Year & Term Calendar',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
        ),
        const SizedBox(height: 6),
        Text(
          'Configure the active academic school year and three-term calendar for your classes.',
          style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 24),

        // School Year Dropdown
        Text('Academic School Year', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _schoolYear,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: '2026-2027', child: Text('S.Y. 2026 - 2027 (Active DepEd SY)')),
                DropdownMenuItem(value: '2027-2028', child: Text('S.Y. 2027 - 2028')),
              ],
              onChanged: (v) => setState(() => _schoolYear = v ?? '2026-2027'),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Term Structure Notice
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.calendarCheck, color: theme.colorScheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Term Structure: $_termStructure',
                      style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Under DO 15, s. 2026, the academic year consists of 3 continuous grading terms with equal weight in final grade determination.',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 3 Terms Calendar Preview
        Text('Calendar Trimester Ranges', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
        const SizedBox(height: 12),
        _buildTermDateTile('Term 1', _term1Start, _term1End, theme),
        const SizedBox(height: 8),
        _buildTermDateTile('Term 2', _term2Start, _term2End, theme),
        const SizedBox(height: 8),
        _buildTermDateTile('Term 3', _term3Start, _term3End, theme),
      ],
    );
  }

  Widget _buildTermDateTile(String label, DateTime start, DateTime end, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.clock, size: 16, color: Colors.grey),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          Text(
            '${start.month}/${start.day}/${start.year}  —  ${end.month}/${end.day}/${end.year}',
            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  // --- STEP 2: GRADE LEVEL, SUBJECT AREA & DO 15 WEIGHTS ---
  Widget _buildStep2SubjectAndWeights(ThemeData theme, bool isDesktop) {
    final availableClusters = DepEdSubjectCatalog.getClusters(_selectedCategory);
    final availableSubjects = DepEdSubjectCatalog.getSubjects(
      category: _selectedCategory,
      cluster: _selectedCluster,
      gradeLevel: _selectedGradeLevel,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '2. Grade Level & Subject Assignment',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
        ),
        const SizedBox(height: 6),
        Text(
          'Select your grade level, subject category, and auto-load the DepEd Order 15, s. 2026 grading weights.',
          style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 24),

        // Grade Level Chips
        Text('Target Grade Level', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
        const SizedBox(height: 8),
        Row(
          children: ['Grade 11', 'Grade 12'].map((g) {
            final isSelected = _selectedGradeLevel == g;
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
                  if (sel) {
                    setState(() {
                      _selectedGradeLevel = g;
                      final subjects = DepEdSubjectCatalog.getSubjects(
                        category: _selectedCategory,
                        cluster: _selectedCluster,
                        gradeLevel: _selectedGradeLevel,
                      );
                      if (subjects.isNotEmpty) {
                        _selectedSubject = subjects.first.name;
                      }
                    });
                  }
                },
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // Category Dropdown
        Text('Subject Category (Curriculum Area)', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
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
              onChanged: _onCategoryChanged,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Cluster & Subject Row
        if (isDesktop)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cluster / Strand', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 8),
                    _buildClusterDropdown(availableClusters, theme),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Subject Name', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 8),
                    _buildSubjectDropdown(availableSubjects, theme),
                  ],
                ),
              ),
            ],
          )
        else ...[
          Text('Cluster / Strand', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 8),
          _buildClusterDropdown(availableClusters, theme),
          const SizedBox(height: 16),
          Text('Subject Name', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 8),
          _buildSubjectDropdown(availableSubjects, theme),
        ],

        const SizedBox(height: 28),

        // Grading Weights Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.scale, color: AppTheme.catPurple, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Grading Component Weights',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.onSurface),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text('Custom Override', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
                      Switch(
                        value: _customWeightOverride,
                        onChanged: (val) {
                          setState(() {
                            _customWeightOverride = val;
                            if (!val) _applyPresetWeights();
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Visual Weight Split
              Row(
                children: [
                  _buildWeightCard('Written Works (WW)', _wwWeight, AppTheme.catBlue, theme),
                  const SizedBox(width: 12),
                  _buildWeightCard('Performance Tasks (PT)', _ptWeight, AppTheme.catGreen, theme),
                  const SizedBox(width: 12),
                  _buildWeightCard('Quarterly Exam (EX)', _exWeight, AppTheme.catOrange, theme),
                ],
              ),

              if (_customWeightOverride) ...[
                const SizedBox(height: 20),
                Text('Adjust Custom Weights (Must Total 100%):', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Slider(
                  value: _wwWeight,
                  min: 0,
                  max: 60,
                  divisions: 12,
                  label: 'WW: ${_wwWeight.round()}%',
                  onChanged: (v) => setState(() => _wwWeight = v),
                ),
                Slider(
                  value: _ptWeight,
                  min: 0,
                  max: 80,
                  divisions: 16,
                  label: 'PT: ${_ptWeight.round()}%',
                  onChanged: (v) => setState(() => _ptWeight = v),
                ),
                Slider(
                  value: _exWeight,
                  min: 0,
                  max: 50,
                  divisions: 10,
                  label: 'EX: ${_exWeight.round()}%',
                  onChanged: (v) => setState(() => _exWeight = v),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClusterDropdown(List<String> clusters, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: clusters.contains(_selectedCluster) ? _selectedCluster : (clusters.isNotEmpty ? clusters.first : null),
          isExpanded: true,
          items: clusters.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: _onClusterChanged,
        ),
      ),
    );
  }

  Widget _buildSubjectDropdown(List<SubjectCatalogItem> subjects, ThemeData theme) {
    final validSubject = subjects.any((s) => s.name == _selectedSubject)
        ? _selectedSubject
        : (subjects.isNotEmpty ? subjects.first.name : _selectedSubject);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: validSubject,
          isExpanded: true,
          items: subjects.map((s) => DropdownMenuItem(value: s.name, child: Text(s.name, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) {
            if (v != null) setState(() => _selectedSubject = v);
          },
        ),
      ),
    );
  }

  Widget _buildWeightCard(String title, double weight, Color color, ThemeData theme) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              '${weight.toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );
  }

  // --- STEP 3: SECTIONS MANAGEMENT ---
  Widget _buildStep3Sections(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '3. Section Management',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
        ),
        const SizedBox(height: 6),
        Text(
          'Define the classrooms and class sections you handle for $_selectedSubject.',
          style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _sectionCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. $_selectedGradeLevel - Archimedes',
                  labelText: 'New Section Name',
                  prefixIcon: const Icon(LucideIcons.school),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onSubmitted: (_) => _addSection(),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _addSection,
              icon: const Icon(Icons.add),
              label: const Text('Add Section'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        Text(
          'Current Sections Assigned (${_sections.length}):',
          style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
        ),
        const SizedBox(height: 12),

        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _sections.map((sec) {
            return Chip(
              avatar: const Icon(LucideIcons.users, size: 16, color: AppTheme.catBlue),
              label: Text(sec, style: const TextStyle(fontWeight: FontWeight.w600)),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () => _removeSection(sec),
              backgroundColor: AppTheme.catBlue.withValues(alpha: 0.1),
              side: BorderSide(color: AppTheme.catBlue.withValues(alpha: 0.3)),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- STEP 4: REVIEW & CONFIRMATION ---
  Widget _buildStep4Review(ThemeData theme, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.award, color: AppTheme.catGreen, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '4. Review Academic Configuration',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                ),
                Text(
                  'Please confirm your setup before launching the Teacher Portal.',
                  style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              _buildReviewRow('Academic School Year', _schoolYear, LucideIcons.calendar),
              const Divider(height: 24),
              _buildReviewRow('Grading Calendar', _termStructure, LucideIcons.clock),
              const Divider(height: 24),
              _buildReviewRow('Grade Level', _selectedGradeLevel, LucideIcons.graduationCap),
              const Divider(height: 24),
              _buildReviewRow('Subject Category', _selectedCategory, LucideIcons.layers),
              const Divider(height: 24),
              _buildReviewRow('Assigned Subject', _selectedSubject, LucideIcons.bookOpen),
              const Divider(height: 24),
              _buildReviewRow('Grading Weights', selectedWeightFormula, LucideIcons.percent),
              const Divider(height: 24),
              _buildReviewRow('Managed Sections', _sections.join(', '), LucideIcons.users),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewRow(String title, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 12),
        SizedBox(
          width: 180,
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
