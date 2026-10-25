import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/attendance_workspace_models.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/shared/widgets/shimmer_loading.dart';

class AttendanceRosterList extends StatefulWidget {
  final List<AttendanceRosterStudent> students;
  final Map<String, AttendanceStatus?> statuses;
  final Map<String, String>? remarks;
  final ValueChanged<MapEntry<String, AttendanceStatus?>> onStatusChanged;
  final String searchQuery;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final int pageSize;

  const AttendanceRosterList({
    super.key,
    required this.students,
    required this.statuses,
    this.remarks,
    required this.onStatusChanged,
    this.searchQuery = '',
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.pageSize = 20,
  });

  @override
  State<AttendanceRosterList> createState() => _AttendanceRosterListState();
}

class _AttendanceRosterListState extends State<AttendanceRosterList> {
  late int _visibleCount;

  @override
  void initState() {
    super.initState();
    _visibleCount = widget.pageSize;
  }

  @override
  void didUpdateWidget(covariant AttendanceRosterList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.students != widget.students) {
      _visibleCount = widget.pageSize;
    }
  }

  int _compareStudents(AttendanceRosterStudent a, AttendanceRosterStudent b) {
    int cmp = a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase());
    if (cmp != 0) return cmp;
    cmp = a.firstName.toLowerCase().compareTo(b.firstName.toLowerCase());
    if (cmp != 0) return cmp;
    final aMid = (a.middleName ?? '').toLowerCase();
    final bMid = (b.middleName ?? '').toLowerCase();
    return aMid.compareTo(bMid);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.isLoading) {
      return ShimmerLoading(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            children: List.generate(
              5,
              (i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: const [
                    ShimmerBox(width: 24, height: 14, borderRadius: 4),
                    SizedBox(width: 14),
                    ShimmerBox(width: 38, height: 38, borderRadius: 19),
                    SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: 160, height: 14, borderRadius: 4),
                        SizedBox(height: 6),
                        ShimmerBox(width: 90, height: 12, borderRadius: 4),
                      ],
                    ),
                    Spacer(),
                    ShimmerBox(width: 160, height: 36, borderRadius: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (widget.errorMessage != null || widget.students.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.users,
                  color: theme.colorScheme.primary,
                  size: 38,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No Students Enrolled',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Text(
                  'No students are currently enrolled in this subject and section. Once students are enrolled, you can record daily attendance here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              if (widget.onRetry != null) ...[
                const SizedBox(height: 20),
                AppButton.outline(
                  label: 'Refresh Roster',
                  icon: LucideIcons.refreshCw,
                  isSmall: true,
                  onPressed: widget.onRetry!,
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Partition by gender
    final males = <AttendanceRosterStudent>[];
    final females = <AttendanceRosterStudent>[];
    final unspecified = <AttendanceRosterStudent>[];

    for (final s in widget.students) {
      final g = s.gender.toLowerCase().trim();
      if (g == 'male') {
        males.add(s);
      } else if (g == 'female') {
        females.add(s);
      } else {
        unspecified.add(s);
      }
    }

    males.sort(_compareStudents);
    females.sort(_compareStudents);
    unspecified.sort(_compareStudents);

    // Combined ordering: Male, then Female, then Unspecified
    final combined = [...males, ...females, ...unspecified];

    // Filter by search query if any
    final query = widget.searchQuery.trim().toLowerCase();
    final filtered = query.isEmpty
        ? combined
        : combined.where((s) {
            return s.displayName.toLowerCase().contains(query) ||
                s.studentId.toLowerCase().contains(query);
          }).toList();

    if (filtered.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.searchX,
                size: 32,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 10),
              Text(
                'No students match "$query"',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Slice combined list according to pagination
    final effectiveVisibleCount = query.isEmpty
        ? min(_visibleCount, filtered.length)
        : filtered.length;
    final visibleSlice = filtered.take(effectiveVisibleCount).toList();

    // Map visible students into gender groups
    final visibleMales = visibleSlice
        .where((s) => s.gender.toLowerCase().trim() == 'male')
        .toList();
    final visibleFemales = visibleSlice
        .where((s) => s.gender.toLowerCase().trim() == 'female')
        .toList();
    final visibleUnspecified = visibleSlice
        .where((s) =>
            s.gender.toLowerCase().trim() != 'male' &&
            s.gender.toLowerCase().trim() != 'female')
        .toList();

    final hasMore = query.isEmpty && effectiveVisibleCount < filtered.length;

    int runningIndex = 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (visibleMales.isNotEmpty || (query.isEmpty && males.isNotEmpty))
          _buildGenderGroupSection(
            context: context,
            title: 'Male (${males.length})',
            icon: LucideIcons.user,
            students: visibleMales,
            startIndex: runningIndex,
            onIndexAdvanced: (count) => runningIndex += count,
          ),
        if (visibleFemales.isNotEmpty || (query.isEmpty && females.isNotEmpty))
          _buildGenderGroupSection(
            context: context,
            title: 'Female (${females.length})',
            icon: LucideIcons.userCheck,
            students: visibleFemales,
            startIndex: runningIndex,
            onIndexAdvanced: (count) => runningIndex += count,
          ),
        if (visibleUnspecified.isNotEmpty ||
            (query.isEmpty && unspecified.isNotEmpty))
          _buildGenderGroupSection(
            context: context,
            title: 'Unspecified (${unspecified.length})',
            icon: LucideIcons.users,
            students: visibleUnspecified,
            startIndex: runningIndex,
            onIndexAdvanced: (count) => runningIndex += count,
          ),
        if (hasMore) ...[
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Text(
                  'Showing $effectiveVisibleCount of ${filtered.length} students',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 8),
                AppButton.outline(
                  label:
                      'Load More (Scroll to show ${filtered.length - effectiveVisibleCount} remaining)',
                  icon: LucideIcons.chevronDown,
                  isSmall: true,
                  onPressed: () {
                    setState(() {
                      _visibleCount += widget.pageSize;
                    });
                  },
                ),
              ],
            ),
          ),
        ] else if (filtered.isNotEmpty) ...[
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.checkCheck, size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'All ${filtered.length} students loaded',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGenderGroupSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<AttendanceRosterStudent> students,
    required int startIndex,
    required void Function(int) onIndexAdvanced,
  }) {
    if (students.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final count = students.length;
    final start = startIndex;
    onIndexAdvanced(count);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: students.length,
          itemBuilder: (ctx, idx) {
            final student = students[idx];
            final status = widget.statuses[student.studentId];
            return _buildStudentRow(
              context: context,
              index: start + idx,
              student: student,
              currentStatus: status,
            );
          },
        ),
      ],
    );
  }

  Widget _buildStudentRow({
    required BuildContext context,
    required int index,
    required AttendanceRosterStudent student,
    required AttendanceStatus? currentStatus,
  }) {
    final theme = Theme.of(context);
    final initials = (student.lastName.isNotEmpty ? student.lastName[0].toUpperCase() : '') +
        (student.firstName.isNotEmpty ? student.firstName[0].toUpperCase() : '');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$index',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.primary,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              student.displayName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Row(
            children: [
              _buildStatusButton(
                context: context,
                icon: LucideIcons.check,
                color: AppTheme.catGreen,
                tooltip: 'Mark Present',
                isActive: currentStatus == AttendanceStatus.present,
                onPressed: () {
                  final newStatus = currentStatus == AttendanceStatus.present
                      ? null
                      : AttendanceStatus.present;
                  widget.onStatusChanged(
                    MapEntry(student.studentId, newStatus),
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildStatusButton(
                context: context,
                icon: LucideIcons.x,
                color: AppTheme.catRed,
                tooltip: 'Mark Absent',
                isActive: currentStatus == AttendanceStatus.absent,
                onPressed: () {
                  final newStatus = currentStatus == AttendanceStatus.absent
                      ? null
                      : AttendanceStatus.absent;
                  widget.onStatusChanged(
                    MapEntry(student.studentId, newStatus),
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildStatusButton(
                context: context,
                icon: LucideIcons.clock,
                color: AppTheme.catOrange,
                tooltip: 'Mark Late',
                isActive: currentStatus == AttendanceStatus.late,
                onPressed: () {
                  final newStatus = currentStatus == AttendanceStatus.late
                      ? null
                      : AttendanceStatus.late;
                  widget.onStatusChanged(
                    MapEntry(student.studentId, newStatus),
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildStatusButton(
                context: context,
                icon: LucideIcons.clipboardCheck,
                color: AppTheme.catSlate,
                tooltip: 'Mark Excused',
                isActive: currentStatus == AttendanceStatus.excused,
                onPressed: () {
                  final newStatus = currentStatus == AttendanceStatus.excused
                      ? null
                      : AttendanceStatus.excused;
                  widget.onStatusChanged(
                    MapEntry(student.studentId, newStatus),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusButton({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String tooltip,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: tooltip,
        button: true,
        selected: isActive,
        child: SizedBox(
          width: 32,
          height: 32,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: isActive ? color : theme.colorScheme.surface,
              foregroundColor: isActive
                  ? Colors.white
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: isActive
                    ? BorderSide.none
                    : BorderSide(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.12),
                      ),
              ),
            ),
            onPressed: onPressed,
            child: Icon(icon, size: 16),
          ),
        ),
      ),
    );
  }
}
