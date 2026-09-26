import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';

class TeacherAcademicSetupTab extends StatefulWidget {
  const TeacherAcademicSetupTab({super.key});

  @override
  State<TeacherAcademicSetupTab> createState() =>
      _TeacherAcademicSetupTabState();
}

class _TeacherAcademicSetupTabState extends State<TeacherAcademicSetupTab> {
  late final TextEditingController _ayCtrl;
  late final TextEditingController _gradeCtrl;
  late final TextEditingController _subjectCtrl;

  @override
  void initState() {
    super.initState();
    _ayCtrl = TextEditingController(text: MockDatabase.instance.academicYear);
    _gradeCtrl = TextEditingController(text: MockDatabase.instance.gradeLevel);
    _subjectCtrl =
        TextEditingController(text: MockDatabase.instance.currentSubject);
  }

  @override
  void dispose() {
    _ayCtrl.dispose();
    _gradeCtrl.dispose();
    _subjectCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        margin: EdgeInsets.zero,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 650),
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Teacher Academic Setup',
                style: TextStyle(
                  fontSize: 22, 
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Define your active academic year, grade level, sections, and subjects.',
                style: TextStyle(
                  fontSize: 14, 
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _ayCtrl,
                decoration: const InputDecoration(labelText: 'Academic Year'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _gradeCtrl,
                decoration: const InputDecoration(labelText: 'Grade Level'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _subjectCtrl,
                decoration: const InputDecoration(labelText: 'Primary Subject'),
              ),
              const SizedBox(height: 16),
              Text(
                'Managed Sections:',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: MockDatabase.instance.sections
                    .map((sec) => Chip(
                      label: Text(sec, style: TextStyle(fontWeight: FontWeight.w600)),
                      backgroundColor: AppTheme.catBlue.withValues(alpha: 0.12),
                      side: BorderSide.none,
                      labelStyle: TextStyle(color: AppTheme.catBlue),
                    ))
                    .toList(),
              ),
              const SizedBox(height: 24),
              AppButton.primary(
                label: 'Save Academic Configuration',
                icon: LucideIcons.save,
                onPressed: () {
                  AppModals.showSuccessDialog(
                    context: context,
                    title: 'Configuration Saved',
                    message: 'Your academic setup has been updated successfully.',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
