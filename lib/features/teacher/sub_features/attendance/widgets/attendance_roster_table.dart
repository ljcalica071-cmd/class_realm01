import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/attendance_workspace_models.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';

enum RosterGenderFilter { all, male, female }

class AttendanceRosterTable extends StatefulWidget {
  final List<AttendanceRosterStudent> students;
  final Map<String, AttendanceStatus?> statuses;
  final Map<String, AttendanceSource> sources;
  final Map<String, String?> timesIn;
  final Map<String, String> remarks;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final bool isLocked;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final void Function(String studentId, AttendanceStatus? status) onStatusChanged;
  final void Function(String studentId, String? remark) onRemarkChanged;
  final ValueChanged<AttendanceRosterStudent> onLinkRfidTap;
  final VoidCallback? onMarkAllPresent;
  final VoidCallback? onAutoAbsentUnmarked;
  final String? linkingStudentId;
  final ValueChanged<AttendanceRosterStudent>? onStartLinkingRfid;
  final VoidCallback? onCancelLinkingRfid;
  final VoidCallback? onSaveAttendance;
  final int? dirtyCount;
  final bool? isSavingBatch;

  const AttendanceRosterTable({
    super.key,
    required this.students,
    required this.statuses,
    required this.sources,
    required this.timesIn,
    required this.remarks,
    required this.searchQuery,
    required this.onSearchChanged,
    this.isLocked = false,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    required this.onStatusChanged,
    required this.onRemarkChanged,
    required this.onLinkRfidTap,
    this.onMarkAllPresent,
    this.onAutoAbsentUnmarked,
    this.linkingStudentId,
    this.onStartLinkingRfid,
    this.onCancelLinkingRfid,
    this.onSaveAttendance,
    this.dirtyCount,
    this.isSavingBatch,
  });

  @override
  State<AttendanceRosterTable> createState() => _AttendanceRosterTableState();
}

class _AttendanceRosterTableState extends State<AttendanceRosterTable> {
  static const double _headerHeight = 44.0;
  static const double _rowHeight = 48.0;

  static const double _colNumWidth = 38.0;
  static const double _colNameWidth = 190.0;
  static const double _pinnedWidth = _colNumWidth + _colNameWidth;

  static const double _colRfidWidth = 145.0;
  static const double _colStatusWidth = 210.0;
  static const double _colTimeInWidth = 95.0;
  static const double _colMethodWidth = 95.0;
  static const double _colRemarksWidth = 160.0;
  static const double _scrollableColsWidth =
      _colRfidWidth +
      _colStatusWidth +
      _colTimeInWidth +
      _colMethodWidth +
      _colRemarksWidth;

  RosterGenderFilter _genderFilter = RosterGenderFilter.all;
  int _visibleCount = 20;
  late final TextEditingController _searchController;
  late final ScrollController _pinnedScrollController;
  late final ScrollController _scrollableScrollController;
  late final ScrollController _horizontalScrollController;
  bool _isSyncingScroll = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
    _pinnedScrollController = ScrollController();
    _scrollableScrollController = ScrollController();
    _horizontalScrollController = ScrollController();

    _pinnedScrollController.addListener(() {
      if (_isSyncingScroll) return;
      _isSyncingScroll = true;
      if (_scrollableScrollController.hasClients &&
          _scrollableScrollController.offset !=
              _pinnedScrollController.offset) {
        _scrollableScrollController.jumpTo(_pinnedScrollController.offset);
      }
      _isSyncingScroll = false;
    });

    _scrollableScrollController.addListener(() {
      if (_isSyncingScroll) return;
      _isSyncingScroll = true;
      if (_pinnedScrollController.hasClients &&
          _pinnedScrollController.offset !=
              _scrollableScrollController.offset) {
        _pinnedScrollController.jumpTo(_scrollableScrollController.offset);
      }
      _isSyncingScroll = false;
    });
  }

  @override
  void didUpdateWidget(covariant AttendanceRosterTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery &&
        _searchController.text != widget.searchQuery) {
      _searchController.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pinnedScrollController.dispose();
    _scrollableScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  bool _isMale(AttendanceRosterStudent s) {
    final g = s.gender.trim().toLowerCase();
    return g == 'male' || g == 'm';
  }

  bool _isFemale(AttendanceRosterStudent s) {
    final g = s.gender.trim().toLowerCase();
    return g == 'female' || g == 'f';
  }

  List<AttendanceRosterStudent> _buildFilteredSortedRoster() {
    final q = widget.searchQuery.trim().toLowerCase();
    final filtered = widget.students.where((s) {
      if (_genderFilter == RosterGenderFilter.male && !_isMale(s)) {
        return false;
      }
      if (_genderFilter == RosterGenderFilter.female && !_isFemale(s)) {
        return false;
      }
      if (q.isNotEmpty) {
        final full = '${s.lastName} ${s.firstName} ${s.middleName ?? ''}'
            .toLowerCase();
        final display = s.displayName.toLowerCase();
        final lrn = (s.lrn ?? '').toLowerCase();
        final id = s.studentId.toLowerCase();
        final rfid = (s.rfidUid ?? '').toLowerCase();
        if (!full.contains(q) &&
            !display.contains(q) &&
            !lrn.contains(q) &&
            !id.contains(q) &&
            !rfid.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    // Strict Alphabetical Sorting: lastName.toLowerCase(), then firstName.toLowerCase()
    filtered.sort((a, b) {
      final lnCmp = a.lastName.trim().toLowerCase().compareTo(
            b.lastName.trim().toLowerCase(),
          );
      if (lnCmp != 0) return lnCmp;
      return a.firstName.trim().toLowerCase().compareTo(
            b.firstName.trim().toLowerCase(),
          );
    });

    return filtered;
  }

  Future<void> _openRemarkDialog(AttendanceRosterStudent student) async {
    if (widget.isLocked) return;
    final currentRemark = widget.remarks[student.studentId] ?? '';
    final result = await _AttendanceRemarkModal.show(
      context,
      studentName: student.displayName,
      initialRemark: currentRemark,
    );
    if (result != null) {
      widget.onRemarkChanged(
        student.studentId,
        result.trim().isEmpty ? null : result.trim(),
      );
    }
  }

  static String _formatTimeIn(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '—';
    final clean = raw.trim();

    // Already formatted with AM/PM
    if (clean.toUpperCase().contains('AM') ||
        clean.toUpperCase().contains('PM')) {
      return clean;
    }

    // ISO-8601 timestamp
    final parsedDt = DateTime.tryParse(clean);
    if (parsedDt != null) {
      final local = parsedDt.toLocal();
      return _formatHourMinute(local.hour, local.minute);
    }

    // HH:mm:ss or HH:mm
    final parts = clean.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60) {
        return _formatHourMinute(h, m);
      }
    }

    return clean;
  }

  static String _formatHourMinute(int hour24, int minute) {
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final h12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final hStr = h12.toString().padLeft(2, '0');
    final mStr = minute.toString().padLeft(2, '0');
    return '$hStr:$mStr $period';
  }

  static String _truncateUid(String uid) {
    final clean = uid.trim().toUpperCase();
    if (clean.length <= 10) return clean;
    return '${clean.substring(0, 4)}…${clean.substring(clean.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (widget.isLoading && widget.students.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
        child: const CircularProgressIndicator(),
      );
    }

    if (widget.errorMessage != null && widget.students.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.catRed.withValues(alpha: 0.25),
          ),
        ),
        child: AppEmptyState(
          icon: LucideIcons.circleAlert,
          title: 'Unable to Load Class Roster',
          message: widget.errorMessage!,
          actionLabel: widget.onRetry != null ? 'Retry' : null,
          onAction: widget.onRetry,
        ),
      );
    }

    if (widget.students.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
        child: const AppEmptyState(
          icon: LucideIcons.users,
          title: 'No Students Enrolled',
          message:
              'Enroll students in this class section from the Student Directory tab to begin recording attendance.',
        ),
      );
    }

    final totalCount = widget.students.length;
    final maleCount = widget.students.where(_isMale).length;
    final femaleCount = widget.students.where(_isFemale).length;
    final unmarkedCount = widget.students
        .where((s) => widget.statuses[s.studentId] == null)
        .length;

    final filteredStudents = _buildFilteredSortedRoster();

    final cardBorderColor = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.12)
        : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── TOP FILTER & BULK ACTION BAR ──
            _buildTopFilterBar(
              theme: theme,
              isDark: isDark,
              totalCount: totalCount,
              maleCount: maleCount,
              femaleCount: femaleCount,
              unmarkedCount: unmarkedCount,
            ),

            // ── ROSTER BODY ──
            if (filteredStudents.isEmpty)
              AppEmptyState(
                icon: LucideIcons.searchX,
                title: 'No Matching Students',
                message:
                    'No students match your active gender tab or search query.',
                actionLabel: 'Reset Filters',
                onAction: () {
                  setState(() {
                    _genderFilter = RosterGenderFilter.all;
                    _searchController.clear();
                  });
                  widget.onSearchChanged('');
                },
              )
            else ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final visibleStudents = filteredStudents.take(_visibleCount).toList();
                  final isWideDesktop = constraints.maxWidth >= 900;
                  if (isWideDesktop) {
                    return _buildWideDesktopTable(
                      theme: theme,
                      isDark: isDark,
                      students: visibleStudents,
                    );
                  } else {
                    return _buildNarrowStickyTable(
                      theme: theme,
                      isDark: isDark,
                      students: visibleStudents,
                      maxHeight: constraints.maxHeight,
                    );
                  }
                },
              ),
              if (_visibleCount < filteredStudents.length)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                    border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                  ),
                  child: TextButton.icon(
                    onPressed: () => setState(() => _visibleCount += 20),
                    icon: const Icon(LucideIcons.chevronDown, size: 16),
                    label: Text(
                      'Load More (${filteredStudents.length - _visibleCount} remaining)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
            ],
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildTopFilterBar({
    required ThemeData theme,
    required bool isDark,
    required int totalCount,
    required int maleCount,
    required int femaleCount,
    required int unmarkedCount,
  }) {
    final barBg = isDark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
        : const Color(0xFFF8FAFC);
    final dividerColor = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.1)
        : const Color(0xFFE2E8F0);

    final genderTabs = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.25)
            : const Color(0xFFE2E8F0).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildGenderSegment(
            theme: theme,
            isDark: isDark,
            label: 'All ($totalCount)',
            selected: _genderFilter == RosterGenderFilter.all,
            onTap: () => setState(() => _genderFilter = RosterGenderFilter.all),
          ),
          _buildGenderSegment(
            theme: theme,
            isDark: isDark,
            label: 'Male ($maleCount)',
            selected: _genderFilter == RosterGenderFilter.male,
            onTap: () =>
                setState(() => _genderFilter = RosterGenderFilter.male),
          ),
          _buildGenderSegment(
            theme: theme,
            isDark: isDark,
            label: 'Female ($femaleCount)',
            selected: _genderFilter == RosterGenderFilter.female,
            onTap: () =>
                setState(() => _genderFilter = RosterGenderFilter.female),
          ),
        ],
      ),
    );

    final searchBox = SizedBox(
      width: 240,
      height: 36,
      child: TextField(
        controller: _searchController,
        onChanged: widget.onSearchChanged,
        style: TextStyle(
          fontSize: 12.5,
          color: theme.colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          hintText: 'Search student or LRN...',
          hintStyle: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          prefixIcon: Icon(
            LucideIcons.search,
            size: 15,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
          suffixIcon: widget.searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(LucideIcons.x, size: 13),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    _searchController.clear();
                    widget.onSearchChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: theme.colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: dividerColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: dividerColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: theme.colorScheme.primary,
              width: 1.4,
            ),
          ),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: barBg,
        border: Border(bottom: BorderSide(color: dividerColor)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              genderTabs,
              searchBox,
            ],
          ),
          if (!widget.isLocked)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (widget.onMarkAllPresent != null)
                  AppButton.success(
                    label: 'Mark All Present',
                    icon: LucideIcons.checkCheck,
                    isSmall: true,
                    onPressed: widget.onMarkAllPresent,
                  ),
                if (widget.onAutoAbsentUnmarked != null)
                  AppButton.outline(
                    label: unmarkedCount > 0
                        ? 'Auto-Absent Unmarked ($unmarkedCount)'
                        : 'Auto-Absent Unmarked',
                    icon: LucideIcons.clockAlert,
                    isSmall: true,
                    onPressed:
                        unmarkedCount > 0 ? widget.onAutoAbsentUnmarked : null,
                  ),
                if (widget.onSaveAttendance != null)
                  AppButton.primary(
                    label: (widget.dirtyCount ?? 0) > 0
                        ? 'Save Attendance (${widget.dirtyCount})'
                        : 'Save Attendance',
                    icon: LucideIcons.check,
                    isSmall: true,
                    isLoading: widget.isSavingBatch ?? false,
                    onPressed: (widget.dirtyCount ?? 0) > 0 ? widget.onSaveAttendance : null,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildGenderSegment({
    required ThemeData theme,
    required bool isDark,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? theme.colorScheme.primary : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: selected && !isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected
                ? (isDark ? Colors.white : theme.colorScheme.onSurface)
                : theme.colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // WIDE DESKTOP (>= 900px) — Full-width aligned columns
  // ===========================================================================
  Widget _buildWideDesktopTable({
    required ThemeData theme,
    required bool isDark,
    required List<AttendanceRosterStudent> students,
  }) {
    final headerBg = isDark
        ? theme.colorScheme.primary.withValues(alpha: 0.14)
        : theme.colorScheme.primary.withValues(alpha: 0.08);
    final headerBorder = theme.colorScheme.primary.withValues(alpha: 0.25);
    final rowBorderColor =
        theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.1 : 0.07);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: _headerHeight,
          decoration: BoxDecoration(
            color: headerBg,
            border: Border(bottom: BorderSide(color: headerBorder)),
          ),
          child: Row(
            children: [
              _buildHeaderCell(
                theme: theme,
                width: _colNumWidth,
                alignment: Alignment.center,
                label: '#',
              ),
              Expanded(
                flex: 3,
                child: _buildFlexHeaderCell(
                  theme: theme,
                  label: 'STUDENT NAME',
                ),
              ),
              _buildHeaderCell(
                theme: theme,
                width: _colRfidWidth,
                label: 'RFID CARD',
              ),
              _buildHeaderCell(
                theme: theme,
                width: _colStatusWidth,
                alignment: Alignment.center,
                label: 'ATTENDANCE STATUS',
              ),
              _buildHeaderCell(
                theme: theme,
                width: _colTimeInWidth,
                alignment: Alignment.center,
                label: 'TIME IN',
              ),
              _buildHeaderCell(
                theme: theme,
                width: _colMethodWidth,
                alignment: Alignment.center,
                label: 'METHOD',
              ),
              Expanded(
                flex: 2,
                child: _buildFlexHeaderCell(
                  theme: theme,
                  label: 'REMARKS',
                  hasRightBorder: false,
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: students.length,
          itemBuilder: (context, index) {
            final student = students[index];
            final rowBg = _rowBackground(theme, isDark, index);
            return Container(
              height: _rowHeight,
              decoration: BoxDecoration(
                color: rowBg,
                border: Border(bottom: BorderSide(color: rowBorderColor)),
              ),
              child: Row(
                children: [
                  _buildFixedCell(
                    theme: theme,
                    width: _colNumWidth,
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: _buildFlexCell(
                      theme: theme,
                      child: _buildStudentNameRichText(theme, student),
                    ),
                  ),
                  _buildFixedCell(
                    theme: theme,
                    width: _colRfidWidth,
                    child: _buildRfidChip(theme, isDark, student),
                  ),
                  _buildFixedCell(
                    theme: theme,
                    width: _colStatusWidth,
                    alignment: Alignment.center,
                    child: _buildStatusSegmentedPills(theme, isDark, student),
                  ),
                  _buildFixedCell(
                    theme: theme,
                    width: _colTimeInWidth,
                    alignment: Alignment.center,
                    child: _buildTimeInCell(theme, isDark, student),
                  ),
                  _buildFixedCell(
                    theme: theme,
                    width: _colMethodWidth,
                    alignment: Alignment.center,
                    child: _buildMethodCell(theme, isDark, student),
                  ),
                  Expanded(
                    flex: 2,
                    child: _buildFlexCell(
                      theme: theme,
                      hasRightBorder: false,
                      child: _buildRemarkCell(theme, isDark, student),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ===========================================================================
  // NARROW VIEWPORT (< 900px) — Synced Two-Pane Sticky Left Column + Scrollbar
  // ===========================================================================
  Widget _buildNarrowStickyTable({
    required ThemeData theme,
    required bool isDark,
    required List<AttendanceRosterStudent> students,
    required double maxHeight,
  }) {
    final headerBg = isDark
        ? theme.colorScheme.primary.withValues(alpha: 0.14)
        : theme.colorScheme.primary.withValues(alpha: 0.08);
    final headerBorder = theme.colorScheme.primary.withValues(alpha: 0.25);
    final rowBorderColor =
        theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.1 : 0.07);
    final stickyDividerColor = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.18)
        : const Color(0xFFCBD5E1);

    final contentHeight = students.length * _rowHeight;
    final double bodyHeight = maxHeight.isFinite
        ? math.max(120.0, math.min(contentHeight, maxHeight - _headerHeight))
        : math.min(contentHeight, 528.0);
    final bool needsVerticalScroll = contentHeight > bodyHeight + 1.0;

    return SizedBox(
      height: _headerHeight + bodyHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── PINNED STICKY LEFT SECTION (# + STUDENT NAME) ──
          Container(
            width: _pinnedWidth,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                right: BorderSide(color: stickyDividerColor, width: 1.5),
              ),
            ),
            child: Column(
              children: [
                Container(
                  height: _headerHeight,
                  decoration: BoxDecoration(
                    color: headerBg,
                    border: Border(bottom: BorderSide(color: headerBorder)),
                  ),
                  child: Row(
                    children: [
                      _buildHeaderCell(
                        theme: theme,
                        width: _colNumWidth,
                        alignment: Alignment.center,
                        label: '#',
                      ),
                      _buildHeaderCell(
                        theme: theme,
                        width: _colNameWidth - 1.5,
                        hasRightBorder: false,
                        label: 'STUDENT NAME',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _pinnedScrollController,
                    physics: needsVerticalScroll
                        ? const ClampingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final student = students[index];
                      return Container(
                        height: _rowHeight,
                        decoration: BoxDecoration(
                          color: _rowBackground(theme, isDark, index),
                          border: Border(
                            bottom: BorderSide(color: rowBorderColor),
                          ),
                        ),
                        child: Row(
                          children: [
                            _buildFixedCell(
                              theme: theme,
                              width: _colNumWidth,
                              alignment: Alignment.center,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.65,
                                  ),
                                ),
                              ),
                            ),
                            _buildFixedCell(
                              theme: theme,
                              width: _colNameWidth - 1.5,
                              hasRightBorder: false,
                              child: _buildStudentNameRichText(theme, student),
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

          // ── SCROLLABLE RIGHT SECTION ──
          Expanded(
            child: Scrollbar(
              controller: _horizontalScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: _scrollableColsWidth,
                  height: _headerHeight + bodyHeight,
                  child: Column(
                    children: [
                      Container(
                        height: _headerHeight,
                        decoration: BoxDecoration(
                          color: headerBg,
                          border: Border(
                            bottom: BorderSide(color: headerBorder),
                          ),
                        ),
                        child: Row(
                          children: [
                            _buildHeaderCell(
                              theme: theme,
                              width: _colRfidWidth,
                              label: 'RFID CARD',
                            ),
                            _buildHeaderCell(
                              theme: theme,
                              width: _colStatusWidth,
                              alignment: Alignment.center,
                              label: 'ATTENDANCE STATUS',
                            ),
                            _buildHeaderCell(
                              theme: theme,
                              width: _colTimeInWidth,
                              alignment: Alignment.center,
                              label: 'TIME IN',
                            ),
                            _buildHeaderCell(
                              theme: theme,
                              width: _colMethodWidth,
                              alignment: Alignment.center,
                              label: 'METHOD',
                            ),
                            _buildHeaderCell(
                              theme: theme,
                              width: _colRemarksWidth,
                              hasRightBorder: false,
                              label: 'REMARKS',
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollableScrollController,
                          physics: needsVerticalScroll
                              ? const ClampingScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                          itemCount: students.length,
                          itemBuilder: (context, index) {
                            final student = students[index];
                            return Container(
                              height: _rowHeight,
                              decoration: BoxDecoration(
                                color: _rowBackground(theme, isDark, index),
                                border: Border(
                                  bottom: BorderSide(color: rowBorderColor),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _buildFixedCell(
                                    theme: theme,
                                    width: _colRfidWidth,
                                    child: _buildRfidChip(
                                      theme,
                                      isDark,
                                      student,
                                    ),
                                  ),
                                  _buildFixedCell(
                                    theme: theme,
                                    width: _colStatusWidth,
                                    alignment: Alignment.center,
                                    child: _buildStatusSegmentedPills(
                                      theme,
                                      isDark,
                                      student,
                                    ),
                                  ),
                                  _buildFixedCell(
                                    theme: theme,
                                    width: _colTimeInWidth,
                                    alignment: Alignment.center,
                                    child: _buildTimeInCell(
                                      theme,
                                      isDark,
                                      student,
                                    ),
                                  ),
                                  _buildFixedCell(
                                    theme: theme,
                                    width: _colMethodWidth,
                                    alignment: Alignment.center,
                                    child: _buildMethodCell(
                                      theme,
                                      isDark,
                                      student,
                                    ),
                                  ),
                                  _buildFixedCell(
                                    theme: theme,
                                    width: _colRemarksWidth,
                                    hasRightBorder: false,
                                    child: _buildRemarkCell(
                                      theme,
                                      isDark,
                                      student,
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
            ),
          ),
        ],
      ),
    );
  }

  Color _rowBackground(ThemeData theme, bool isDark, int index) {
    if (index.isOdd) {
      return isDark
          ? theme.colorScheme.onSurface.withValues(alpha: 0.03)
          : theme.colorScheme.primary.withValues(alpha: 0.025);
    }
    return theme.colorScheme.surface;
  }

  Widget _buildHeaderCell({
    required ThemeData theme,
    required double width,
    required String label,
    Alignment alignment = Alignment.centerLeft,
    bool hasRightBorder = true,
  }) {
    return Container(
      width: width,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: alignment,
      decoration: BoxDecoration(
        border: hasRightBorder
            ? Border(
                right: BorderSide(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                ),
              )
            : null,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildFlexHeaderCell({
    required ThemeData theme,
    required String label,
    Alignment alignment = Alignment.centerLeft,
    bool hasRightBorder = true,
  }) {
    return Container(
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: alignment,
      decoration: BoxDecoration(
        border: hasRightBorder
            ? Border(
                right: BorderSide(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                ),
              )
            : null,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildFixedCell({
    required ThemeData theme,
    required double width,
    required Widget child,
    Alignment alignment = Alignment.centerLeft,
    bool hasRightBorder = true,
  }) {
    return Container(
      width: width,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: alignment,
      decoration: BoxDecoration(
        border: hasRightBorder
            ? Border(
                right: BorderSide(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                ),
              )
            : null,
      ),
      child: child,
    );
  }

  Widget _buildFlexCell({
    required ThemeData theme,
    required Widget child,
    Alignment alignment = Alignment.centerLeft,
    bool hasRightBorder = true,
  }) {
    return Container(
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: alignment,
      decoration: BoxDecoration(
        border: hasRightBorder
            ? Border(
                right: BorderSide(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                ),
              )
            : null,
      ),
      child: child,
    );
  }

  Widget _buildStudentNameRichText(
    ThemeData theme,
    AttendanceRosterStudent student,
  ) {
    final ln = student.lastName.trim();
    final fn = student.firstName.trim();
    final mi = student.middleInitial;
    final restParts = [
      if (fn.isNotEmpty) fn,
      ?mi,
    ].join(' ');

    return Align(
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: ln.isNotEmpty ? ln : student.displayName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (ln.isNotEmpty && restParts.isNotEmpty)
              TextSpan(
                text: ', $restParts',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.88),
                ),
              ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildRfidChip(
    ThemeData theme,
    bool isDark,
    AttendanceRosterStudent student,
  ) {
    if (widget.linkingStudentId == student.studentId) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF2563EB),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
            ),
            const SizedBox(width: 5),
            const Flexible(
              child: Text(
                'Waiting RFID',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2563EB),
                ),
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: widget.onCancelLinkingRfid,
              child: const Icon(Icons.close, size: 13, color: Color(0xFF2563EB)),
            ),
          ],
        ),
      );
    }

    final assigned = student.hasRfidAssigned;
    if (assigned) {
      final uid = _truncateUid(student.rfidUid!);
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (widget.onStartLinkingRfid != null) {
            widget.onStartLinkingRfid!(student);
          } else {
            widget.onLinkRfidTap(student);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.catTeal.withValues(alpha: isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.catTeal.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.contactless_rounded,
                size: 13,
                color: isDark ? const Color(0xFF5EEAD4) : AppTheme.catTeal,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  uid,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFF5EEAD4)
                        : const Color(0xFF0F766E),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        if (widget.onStartLinkingRfid != null) {
          widget.onStartLinkingRfid!(student);
        } else {
          widget.onLinkRfidTap(student);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.03)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(
              alpha: isDark ? 0.22 : 0.18,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.plus,
              size: 12,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                'Link RFID',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSegmentedPills(
    ThemeData theme,
    bool isDark,
    AttendanceRosterStudent student,
  ) {
    final activeStatus = widget.statuses[student.studentId];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStatusPill(
          theme: theme,
          isDark: isDark,
          shortCode: 'P',
          tooltip: 'Mark Present',
          status: AttendanceStatus.present,
          activeStatus: activeStatus,
          activeColor: AppTheme.catGreen,
          studentId: student.studentId,
        ),
        const SizedBox(width: 5),
        _buildStatusPill(
          theme: theme,
          isDark: isDark,
          shortCode: 'L',
          tooltip: 'Mark Late',
          status: AttendanceStatus.late,
          activeStatus: activeStatus,
          activeColor: AppTheme.catOrange,
          studentId: student.studentId,
        ),
        const SizedBox(width: 5),
        _buildStatusPill(
          theme: theme,
          isDark: isDark,
          shortCode: 'A',
          tooltip: 'Mark Absent',
          status: AttendanceStatus.absent,
          activeStatus: activeStatus,
          activeColor: AppTheme.catRed,
          studentId: student.studentId,
        ),
        const SizedBox(width: 5),
        _buildStatusPill(
          theme: theme,
          isDark: isDark,
          shortCode: 'E',
          tooltip: 'Mark Excused',
          status: AttendanceStatus.excused,
          activeStatus: activeStatus,
          activeColor: AppTheme.catBlue,
          studentId: student.studentId,
        ),
      ],
    );
  }

  Widget _buildStatusPill({
    required ThemeData theme,
    required bool isDark,
    required String shortCode,
    required String tooltip,
    required AttendanceStatus status,
    required AttendanceStatus? activeStatus,
    required Color activeColor,
    required String studentId,
  }) {
    final isSelected = activeStatus == status;
    final isDisabled = widget.isLocked;

    final bgColor = isSelected
        ? (isDisabled ? activeColor.withValues(alpha: 0.55) : activeColor)
        : (isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFF1F5F9));

    final borderColor = isSelected
        ? activeColor
        : theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.16 : 0.12);

    final textColor = isSelected
        ? Colors.white
        : theme.colorScheme.onSurface.withValues(
            alpha: isDisabled ? 0.35 : 0.75,
          );

    return Tooltip(
      message: isDisabled ? '$tooltip (Locked)' : tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: isDisabled
            ? null
            : () {
                final next = isSelected ? null : status;
                widget.onStatusChanged(studentId, next);
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 42,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Text(
            shortCode,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeInCell(
    ThemeData theme,
    bool isDark,
    AttendanceRosterStudent student,
  ) {
    final status = widget.statuses[student.studentId];
    if (status == null) {
      return Text(
        '—',
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      );
    }

    final timeLabel = _formatTimeIn(widget.timesIn[student.studentId]);
    return Text(
      timeLabel,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        fontFamily: timeLabel == '—' ? null : 'monospace',
        color: theme.colorScheme.onSurface.withValues(
          alpha: timeLabel == '—' ? 0.45 : 0.85,
        ),
      ),
    );
  }

  Widget _buildMethodCell(
    ThemeData theme,
    bool isDark,
    AttendanceRosterStudent student,
  ) {
    final status = widget.statuses[student.studentId];
    if (status == null) {
      return Text(
        '—',
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      );
    }

    final source = widget.sources[student.studentId] ?? AttendanceSource.manual;
    Color badgeColor;
    switch (source) {
      case AttendanceSource.rfid:
        badgeColor = AppTheme.catTeal;
        break;
      case AttendanceSource.system:
        badgeColor = AppTheme.catOrange;
        break;
      case AttendanceSource.manual:
        badgeColor = AppTheme.catSlate;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        source.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white.withValues(alpha: 0.9) : badgeColor,
        ),
      ),
    );
  }

  Widget _buildRemarkCell(
    ThemeData theme,
    bool isDark,
    AttendanceRosterStudent student,
  ) {
    final remark = widget.remarks[student.studentId]?.trim() ?? '';
    final hasRemark = remark.isNotEmpty;

    if (widget.isLocked) {
      return Text(
        hasRemark ? remark : '—',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.onSurface.withValues(
            alpha: hasRemark ? 0.75 : 0.4,
          ),
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => _openRemarkDialog(student),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasRemark ? LucideIcons.fileText : LucideIcons.messageSquarePlus,
              size: 13,
              color: hasRemark
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.48),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                hasRemark ? remark : 'Add note',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: hasRemark ? FontWeight.w600 : FontWeight.w500,
                  color: hasRemark
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.88)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.52),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceRemarkModal extends StatefulWidget {
  final String studentName;
  final String initialRemark;

  const _AttendanceRemarkModal({
    required this.studentName,
    required this.initialRemark,
  });

  static Future<String?> show(
    BuildContext context, {
    required String studentName,
    required String initialRemark,
  }) {
    final theme = Theme.of(context);
    return showDialog<String>(
      context: context,
      builder: (ctx) => Theme(
        data: theme,
        child: _AttendanceRemarkModal(
          studentName: studentName,
          initialRemark: initialRemark,
        ),
      ),
    );
  }

  @override
  State<_AttendanceRemarkModal> createState() => _AttendanceRemarkModalState();
}

class _AttendanceRemarkModalState extends State<_AttendanceRemarkModal> {
  static const Color _errorRed = Color(0xFFDC2626);
  static const int _maxLength = 150;

  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialRemark);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSave() {
    final raw = _controller.text;
    final trimmed = raw.trim();

    if (raw.isNotEmpty && trimmed.isEmpty) {
      setState(() {
        _errorText =
            'Remark cannot contain spaces only. Enter a note or clear the field.';
      });
      return;
    }

    if (trimmed.length > _maxLength) {
      setState(() {
        _errorText = 'Remark must not exceed $_maxLength characters.';
      });
      return;
    }

    Navigator.of(context).pop(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasError = _errorText != null;
    final borderColor = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.16)
        : const Color(0xFFCBD5E1);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 16,
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    LucideIcons.messageSquareText,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Attendance Remark',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (widget.initialRemark.trim().isNotEmpty)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(''),
                      style: TextButton.styleFrom(
                        foregroundColor: _errorRed,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text(
                        'Clear Note',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.studentName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                autofocus: true,
                maxLines: 3,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(180),
                ],
                onChanged: (_) {
                  if (_errorText != null) {
                    setState(() => _errorText = null);
                  }
                },
                style: TextStyle(
                  fontSize: 13.5,
                  color: theme.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. Medical certificate presented, excused for competition...',
                  hintStyle: TextStyle(
                    fontSize: 12.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.white,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: hasError ? _errorRed : borderColor,
                      width: hasError ? 1.5 : 1.0,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: hasError ? _errorRed : borderColor,
                      width: hasError ? 1.5 : 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: hasError ? _errorRed : theme.colorScheme.primary,
                      width: hasError ? 1.5 : 1.6,
                    ),
                  ),
                ),
              ),
              if (hasError) ...[
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 14,
                      color: _errorRed,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _errorText!,
                        style: const TextStyle(
                          color: _errorRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: AppSecondaryButton(
                      label: 'Cancel',
                      height: 42,
                      onPressed: () => Navigator.of(context).pop(null),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppPrimaryButton(
                      label: 'Save Note',
                      height: 42,
                      onPressed: _handleSave,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
