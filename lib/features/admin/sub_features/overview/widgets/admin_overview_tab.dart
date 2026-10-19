import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/models/admin_portal_models.dart';
import 'package:class_realm/data/repositories/admin_repository.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';

class AdminOverviewTab extends StatefulWidget {
  final List<UserModel> teachers;
  final List<UserModel> students;
  final List<UserModel> parents;
  final VoidCallback? onNavigateToBroadcasts;

  const AdminOverviewTab({
    super.key,
    required this.teachers,
    required this.students,
    required this.parents,
    this.onNavigateToBroadcasts,
  });

  @override
  State<AdminOverviewTab> createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends State<AdminOverviewTab> {
  bool _isLoadingKpis = true;
  Map<String, dynamic> _kpiMetrics = {};

  List<SchoolYearRecord> _allSchoolYears = [];
  SchoolYearRecord? _activeSchoolYear;
  String? _selectedPreviewSchoolYearId;
  bool _isLoadingSchoolYears = true;

  SchoolYearRecord? get _selectedPreviewSchoolYear {
    if (_selectedPreviewSchoolYearId == null) return _activeSchoolYear;
    for (final sy in _allSchoolYears) {
      if (sy.id == _selectedPreviewSchoolYearId) return sy;
    }
    return _activeSchoolYear;
  }

  DateTime? _lastSyTransitionAt;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadKpiMetrics(),
      _loadSchoolYears(),
    ]);
  }

  Future<void> _loadKpiMetrics() async {
    final metrics = await AdminRepository.instance.getDashboardKpiMetrics();
    if (mounted) {
      setState(() {
        _kpiMetrics = metrics;
        _isLoadingKpis = false;
      });
    }
  }

  Future<void> _loadSchoolYears() async {
    final list = await AdminRepository.instance.getAllSchoolYears();
    final current = await AdminRepository.instance.getActiveSchoolYear();
    if (mounted) {
      setState(() {
        _allSchoolYears = list;
        _activeSchoolYear = current;
        _selectedPreviewSchoolYearId = current?.id ?? (list.isNotEmpty ? list.first.id : null);
        _isLoadingSchoolYears = false;
      });
    }
  }

  bool get _isViewingHistoricalSnapshot =>
      _selectedPreviewSchoolYear != null &&
      _activeSchoolYear != null &&
      _selectedPreviewSchoolYear!.id != _activeSchoolYear!.id;

  // =========================================================================
  // SCHOOL YEAR TRANSITION & PRE-TRANSITION AUDIT (EDGE CASES #11 & #12)
  // =========================================================================

  Future<void> _handleNewSchoolYearDialog() async {
    final now = DateTime.now();
    if (_lastSyTransitionAt != null && now.difference(_lastSyTransitionAt!) < const Duration(seconds: 60)) {
      final remaining = 60 - now.difference(_lastSyTransitionAt!).inSeconds;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please wait $remaining seconds before transitioning School Years again.')),
      );
      return;
    }

    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final syInput = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.calendar_month_rounded, color: AppTheme.catPurple, size: 28),
            SizedBox(width: 10),
            Text('New School Year'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the consecutive School Year (e.g. 2026-2027). The end year must be exactly start year + 1.',
                style: TextStyle(fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'School Year (YYYY-YYYY)',
                  hintText: '2026-2027',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Required';
                  final regex = RegExp(r'^[0-9]{4}-[0-9]{4}$');
                  if (!regex.hasMatch(val.trim())) return 'Format must be YYYY-YYYY';
                  final parts = val.trim().split('-');
                  final start = int.tryParse(parts[0]);
                  final end = int.tryParse(parts[1]);
                  if (start == null || end == null) return 'Invalid numbers';
                  if (end != start + 1) return 'End year must be exactly start year + 1';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(controller.text.trim());
              }
            },
            child: const Text('Proceed to Audit'),
          ),
        ],
      ),
    );

    if (syInput == null) return;

    // Run Pre-Transition Audit Check (Edge Case #11)
    final audit = await AdminRepository.instance.checkPreTransitionAudit(_activeSchoolYear?.id ?? '');

    if (!mounted) return;

    // Show Audit Confirmation Warning Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              audit.hasPendingItems ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
              color: audit.hasPendingItems ? AppTheme.catOrange : AppTheme.catGreen,
              size: 28,
            ),
            const SizedBox(width: 10),
            const Text('Pre-Transition Audit'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Switching to School Year $syInput will archive the current School Year and give teachers a fresh slate.',
              style: const TextStyle(fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (audit.hasPendingItems ? AppTheme.catOrange : AppTheme.catGreen).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (audit.hasPendingItems ? AppTheme.catOrange : AppTheme.catGreen).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Audit Results for SY ${_activeSchoolYear?.schoolYear ?? "Current"}:',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text('• Unfinalized Term Grades: ${audit.unfinalizedGradesCount}'),
                  Text('• Pending Classwork Submissions: ${audit.pendingSubmissionsCount}'),
                ],
              ),
            ),
            if (audit.hasPendingItems) ...[
              const SizedBox(height: 12),
              const Text(
                'Warning: Some submissions or grades are not yet finalized. They will remain archived in read-only mode.',
                style: TextStyle(fontSize: 12.5, color: AppTheme.catOrange, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
        actions: [
          OutlinedButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: audit.hasPendingItems ? AppTheme.catOrange : AppTheme.catGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm Transition'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Execute Transition
    try {
      final adminId = AuthRepository.instance.currentUser?.id ?? 'admin';
      await AdminRepository.instance.transitionToNewSchoolYear(syInput, adminId);
      _lastSyTransitionAt = DateTime.now();

      await _loadSchoolYears();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.catGreen,
            content: Text('Successfully transitioned to School Year $syInput! Fresh slate initialized.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.catRed, content: Text('Transition error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final totalTeachers = _kpiMetrics['totalTeachers'] ?? widget.teachers.length;
    final activeTeachers = _kpiMetrics['activeTeachers'] ?? totalTeachers;

    final totalStudents = _kpiMetrics['totalStudents'] ?? widget.students.length;
    final activeStudents = _kpiMetrics['activeStudents'] ?? totalStudents;

    final totalParents = _kpiMetrics['totalParents'] ?? widget.parents.length;
    final activeParents = _kpiMetrics['activeParents'] ?? totalParents;

    final pendingTotal = _kpiMetrics['pendingFirstLoginTotal'] ?? 0;
    final pendingTr = _kpiMetrics['pendingTeachers'] ?? 0;
    final pendingSt = _kpiMetrics['pendingStudents'] ?? 0;
    final pendingPt = _kpiMetrics['pendingParents'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Institutional Overview',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'System statistics, institutional metrics, and academic year governance.',
                    style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
              if (widget.onNavigateToBroadcasts != null)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: widget.onNavigateToBroadcasts,
                  icon: const Icon(Icons.campaign_rounded, size: 18),
                  label: const Text('Quick Broadcast', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Historical Snapshot Banner if viewing archived SY (Edge Cases #13 & #14)
          if (_isViewingHistoricalSnapshot)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.catPurple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.catPurple.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, color: AppTheme.catPurple, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Viewing Historical Snapshot: SY ${_selectedPreviewSchoolYear?.schoolYear ?? ""} (Read-Only Snapshot)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.catPurple),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _selectedPreviewSchoolYearId = _activeSchoolYear?.id);
                    },
                    child: const Text('Return to Active SY', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

          // 4 REFINED SUMMARY KPI CARDS
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1050
                  ? 4
                  : constraints.maxWidth >= 600
                      ? 2
                      : 1;

              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: columns == 1 ? 2.8 : 1.6,
                children: [
                  // Card 1: Teachers
                  _buildKpiCard(
                    title: 'Total Teachers',
                    value: '$activeTeachers / $totalTeachers',
                    subtext: 'Active / Total Teachers',
                    icon: Icons.person_pin,
                    color: theme.colorScheme.primary,
                  ),
                  // Card 2: Students
                  _buildKpiCard(
                    title: 'Total Students',
                    value: '$activeStudents / $totalStudents',
                    subtext: 'Active / Total Students',
                    icon: Icons.groups_rounded,
                    color: AppTheme.catPurple,
                  ),
                  // Card 3: Parents
                  _buildKpiCard(
                    title: 'Total Parents',
                    value: '$activeParents / $totalParents',
                    subtext: 'Active / Total Parents',
                    icon: Icons.family_restroom_rounded,
                    color: AppTheme.catBlue,
                  ),
                  // Card 4: Pending First Login
                  _buildKpiCard(
                    title: 'Pending First Login',
                    value: '$pendingTotal',
                    subtext: 'Tr: $pendingTr | St: $pendingSt | Pt: $pendingPt',
                    icon: Icons.lock_clock_outlined,
                    color: AppTheme.catOrange,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),

          // SCHOOL YEAR CONFIGURATION & ARCHIVING CARD
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isDark ? theme.colorScheme.surface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.school_rounded, color: AppTheme.catPurple, size: 24),
                        const SizedBox(width: 10),
                        Text(
                          'Academic School Year & Term Governance',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.catPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _handleNewSchoolYearDialog,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Transition New SY', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Active SY Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.catGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.catGreen.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppTheme.catGreen, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Active SY: ${_activeSchoolYear?.schoolYear ?? "Loading..."}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.catGreen),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Fixed 3-Term Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Structure: 3-Term Trimester (Fixed)',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Historical Preview Selector Dropdown
                Row(
                  children: [
                    Text(
                      'Historical Snapshot Preview:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                    ),
                    const SizedBox(width: 12),
                    if (_isLoadingSchoolYears)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (_allSchoolYears.isEmpty)
                      Text(
                        'No school years configured',
                        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                      )
                    else
                      DropdownButton<String>(
                        value: _allSchoolYears.any((sy) => sy.id == _selectedPreviewSchoolYearId)
                            ? _selectedPreviewSchoolYearId
                            : _allSchoolYears.first.id,
                        underline: const SizedBox.shrink(),
                        items: _allSchoolYears.map((sy) {
                          return DropdownMenuItem<String>(
                            value: sy.id,
                            child: Text('${sy.schoolYear} ${sy.isCurrent ? "(ACTIVE)" : "(Archived)"}'),
                          );
                        }).toList(),
                        onChanged: (id) {
                          if (id != null) {
                            setState(() => _selectedPreviewSchoolYearId = id);
                          }
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Text(
            subtext,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
