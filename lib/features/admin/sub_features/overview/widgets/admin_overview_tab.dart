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

  Future<String?> _showSchoolYearSelectionModal() async {
    final availableYears = [
      for (int y = 2026; y <= 2049; y++) '$y-${y + 1}'
    ];

    final activeSy = _activeSchoolYear?.schoolYear;
    final archivedYears = _allSchoolYears
        .where((s) => s.isArchived)
        .map((s) => s.schoolYear)
        .toSet();

    return showDialog<String>(
      context: context,
      builder: (ctx) {
        String? selectedSy;
        String? validationError;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.calendar_month_rounded, color: theme.colorScheme.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Academic School Year Governance',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Select an academic year (2026-2027 to 2049-2050)',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Legend / Status Guidance
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF16A34A),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text('Active', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEAB308),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text('Archived', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text('Future / Upcoming', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Scrollable List of School Years
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: availableYears.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: isDark ? Colors.white10 : Colors.grey.shade200,
                            ),
                            itemBuilder: (ctx, index) {
                              final sy = availableYears[index];
                              final isActive = sy == activeSy;
                              final isArchived = archivedYears.contains(sy);
                              final isSelected = sy == selectedSy;

                              return InkWell(
                                onTap: () {
                                  final now = DateTime.now();
                                  final startYear = int.tryParse(sy.split('-').first) ?? 0;

                                  if (isActive) {
                                    setModalState(() {
                                      selectedSy = null;
                                      validationError = 'School Year $sy is already the currently active academic school year.';
                                    });
                                    return;
                                  }

                                  if (isArchived) {
                                    setModalState(() {
                                      selectedSy = null;
                                      validationError = 'School Year $sy has already concluded and is archived. Archived school years cannot be re-activated.';
                                    });
                                    return;
                                  }

                                  if (startYear > now.year) {
                                    setModalState(() {
                                      selectedSy = null;
                                      validationError = 'Cannot select School Year $sy because the academic start year ($startYear) has not arrived yet. Current calendar year is ${now.year}. Academic school years can only be set or transitioned during or after their starting calendar year.';
                                    });
                                    return;
                                  }

                                  // Valid selectable candidate
                                  setModalState(() {
                                    selectedSy = sy;
                                    validationError = null;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  color: isSelected
                                      ? theme.colorScheme.primary.withValues(alpha: 0.12)
                                      : (isActive
                                          ? const Color(0xFF16A34A).withValues(alpha: 0.08)
                                          : Colors.transparent),
                                  child: Row(
                                    children: [
                                      // Status Circle Indicator
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? const Color(0xFF16A34A)
                                              : (isArchived
                                                  ? const Color(0xFFEAB308)
                                                  : (isDark ? Colors.grey.shade600 : Colors.grey.shade400)),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      // Year text
                                      Text(
                                        sy,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected || isActive ? FontWeight.bold : FontWeight.w500,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                      const Spacer(),
                                      // Badge
                                      if (isActive)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFF16A34A)),
                                          ),
                                          child: const Text(
                                            'ACTIVE',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF16A34A),
                                            ),
                                          ),
                                        )
                                      else if (isArchived)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEAB308).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFEAB308)),
                                          ),
                                          child: const Text(
                                            'ARCHIVED',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFB45309),
                                            ),
                                          ),
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white10 : Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'FUTURE',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                      if (isSelected) ...[
                                        const SizedBox(width: 10),
                                        Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 18),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    // Inline Error Message (Matching inline-input-validation skill!)
                    if (validationError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.5), width: 1.5),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                validationError!,
                                style: const TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: selectedSy != null
                      ? () => Navigator.of(ctx).pop(selectedSy)
                      : null,
                  child: const Text('Proceed to Audit', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleNewSchoolYearDialog() async {
    final now = DateTime.now();
    if (_lastSyTransitionAt != null && now.difference(_lastSyTransitionAt!) < const Duration(seconds: 60)) {
      final remaining = 60 - now.difference(_lastSyTransitionAt!).inSeconds;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please wait $remaining seconds before transitioning School Years again.')),
      );
      return;
    }

    final syInput = await _showSchoolYearSelectionModal();
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
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: widget.onNavigateToBroadcasts,
                  icon: const Icon(Icons.campaign_rounded, size: 18),
                  label: const Text('Quick Broadcast', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.history_rounded, color: theme.colorScheme.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Viewing Historical Snapshot: SY ${_selectedPreviewSchoolYear?.schoolYear ?? ""} (Read-Only Snapshot)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: theme.colorScheme.primary,
                      ),
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
                    color: theme.colorScheme.primary,
                  ),
                  // Card 3: Parents
                  _buildKpiCard(
                    title: 'Total Parents',
                    value: '$activeParents / $totalParents',
                    subtext: 'Active / Total Parents',
                    icon: Icons.family_restroom_rounded,
                    color: theme.colorScheme.primary,
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
              border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.school_rounded, color: theme.colorScheme.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
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
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _handleNewSchoolYearDialog,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Transition New SY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    // Active SY Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Active SY: ${_activeSchoolYear?.schoolYear ?? "Loading..."}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF16A34A)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Fixed 3-Term Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        'Structure: 3-Term Trimester (Fixed)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Historical Preview Selector Dropdown
                Row(
                  children: [
                    Text(
                      'Historical Snapshot Preview:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                      ),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _allSchoolYears.any((sy) => sy.id == _selectedPreviewSchoolYearId)
                                ? _selectedPreviewSchoolYearId
                                : _allSchoolYears.first.id,
                            icon: Icon(
                              Icons.arrow_drop_down_rounded,
                              color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                            ),
                            items: _allSchoolYears.map((sy) {
                              return DropdownMenuItem<String>(
                                value: sy.id,
                                child: Text(
                                  '${sy.schoolYear} ${sy.isCurrent ? "(ACTIVE)" : "(Archived)"}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: sy.isCurrent ? FontWeight.bold : FontWeight.w500,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (id) {
                              if (id != null) {
                                setState(() => _selectedPreviewSchoolYearId = id);
                              }
                            },
                          ),
                        ),
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
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
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
                  color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            subtext,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}
