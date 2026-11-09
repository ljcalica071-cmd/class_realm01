import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/anti_cheating/models/student_live_proctor_state.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';

enum ProctorGenderFilter { all, male, female }

class ProctoringRosterTable extends StatefulWidget {
  final List<StudentLiveProctorState> students;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final void Function(StudentLiveProctorState student) onReset;
  final void Function(StudentLiveProctorState student) onForceSubmit;
  final void Function(StudentLiveProctorState student) onToggleAllow;

  const ProctoringRosterTable({
    super.key,
    required this.students,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onReset,
    required this.onForceSubmit,
    required this.onToggleAllow,
  });

  @override
  State<ProctoringRosterTable> createState() => _ProctoringRosterTableState();
}

class _ProctoringRosterTableState extends State<ProctoringRosterTable> {
  static const double _headerHeight = 44.0;
  static const double _rowHeight = 52.0;

  static const double _colNumWidth = 40.0;
  static const double _colStatusWidth = 160.0;
  static const double _colViolationsWidth = 110.0;
  static const double _colScoreWidth = 110.0;
  static const double _colActionsWidth = 190.0;

  ProctorGenderFilter _genderFilter = ProctorGenderFilter.all;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant ProctoringRosterTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery &&
        _searchController.text != widget.searchQuery) {
      _searchController.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isMale(StudentLiveProctorState s) {
    final g = (s.gender ?? '').trim().toLowerCase();
    return g == 'male' || g == 'm';
  }

  bool _isFemale(StudentLiveProctorState s) {
    final g = (s.gender ?? '').trim().toLowerCase();
    return g == 'female' || g == 'f';
  }

  List<StudentLiveProctorState> _buildFilteredSortedRoster() {
    final q = widget.searchQuery.trim().toLowerCase();

    final filtered = widget.students.where((s) {
      if (_genderFilter == ProctorGenderFilter.male && !_isMale(s)) {
        return false;
      }
      if (_genderFilter == ProctorGenderFilter.female && !_isFemale(s)) {
        return false;
      }
      if (q.isNotEmpty) {
        final full = '${s.lastName ?? ''} ${s.firstName ?? ''} ${s.studentName}'
            .toLowerCase();
        final lrn = s.lrn.toLowerCase();
        final id = s.studentId.toLowerCase();
        if (!full.contains(q) && !lrn.contains(q) && !id.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      final aLast = (a.lastName ?? a.studentName).trim().toLowerCase();
      final bLast = (b.lastName ?? b.studentName).trim().toLowerCase();
      final lnCmp = aLast.compareTo(bLast);
      if (lnCmp != 0) return lnCmp;
      final aFirst = (a.firstName ?? '').trim().toLowerCase();
      final bFirst = (b.firstName ?? '').trim().toLowerCase();
      return aFirst.compareTo(bFirst);
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final totalCount = widget.students.length;
    final maleCount = widget.students.where(_isMale).length;
    final femaleCount = widget.students.where(_isFemale).length;
    final filtered = _buildFilteredSortedRoster();

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopFilterBar(
              theme: theme,
              isDark: isDark,
              totalCount: totalCount,
              maleCount: maleCount,
              femaleCount: femaleCount,
            ),
            if (filtered.isEmpty && widget.students.isNotEmpty)
              AppEmptyState(
                icon: LucideIcons.searchX,
                title: 'No Matching Learners',
                message:
                    'No learners match the selected gender or search filter.',
                actionLabel: 'Reset Filters',
                onAction: () {
                  setState(() {
                    _genderFilter = ProctorGenderFilter.all;
                    _searchController.clear();
                  });
                  widget.onSearchChanged('');
                },
              )
            else if (widget.students.isEmpty)
              const AppEmptyState(
                icon: LucideIcons.users,
                title: 'No Learners Enrolled',
                message: 'No learners enrolled in this section.',
              )
            else
              _buildTableBody(theme: theme, isDark: isDark, items: filtered),
          ],
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
  }) {
    final barBg = isDark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
        : const Color(0xFFF8FAFC);
    final dividerColor = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.1)
        : const Color(0xFFE2E8F0);

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
          Container(
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
                  selected: _genderFilter == ProctorGenderFilter.all,
                  onTap: () =>
                      setState(() => _genderFilter = ProctorGenderFilter.all),
                ),
                _buildGenderSegment(
                  theme: theme,
                  isDark: isDark,
                  label: 'Male ($maleCount)',
                  selected: _genderFilter == ProctorGenderFilter.male,
                  onTap: () =>
                      setState(() => _genderFilter = ProctorGenderFilter.male),
                ),
                _buildGenderSegment(
                  theme: theme,
                  isDark: isDark,
                  label: 'Female ($femaleCount)',
                  selected: _genderFilter == ProctorGenderFilter.female,
                  onTap: () => setState(
                    () => _genderFilter = ProctorGenderFilter.female,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 260,
            height: 36,
            child: TextField(
              controller: _searchController,
              onChanged: widget.onSearchChanged,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Search student or LRN...',
                hintStyle: TextStyle(
                  fontSize: 12.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
                prefixIcon: const Icon(LucideIcons.search, size: 16),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 34,
                  minHeight: 34,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 14),
                        onPressed: () {
                          _searchController.clear();
                          widget.onSearchChanged('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 0,
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
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

  Widget _buildTableBody({
    required ThemeData theme,
    required bool isDark,
    required List<StudentLiveProctorState> items,
  }) {
    final headerBg = isDark
        ? theme.colorScheme.primary.withValues(alpha: 0.14)
        : theme.colorScheme.primary.withValues(alpha: 0.08);
    final headerBorder = theme.colorScheme.primary.withValues(alpha: 0.25);
    final rowBorder = theme.colorScheme.onSurface.withValues(
      alpha: isDark ? 0.1 : 0.07,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 860,
        child: Column(
          children: [
            // Header Row
            Container(
              height: _headerHeight,
              decoration: BoxDecoration(
                color: headerBg,
                border: Border(bottom: BorderSide(color: headerBorder)),
              ),
              child: Row(
                children: [
                  _buildHeaderCell(theme: theme, width: _colNumWidth, label: '#', alignment: Alignment.center),
                  Expanded(
                    flex: 3,
                    child: _buildHeaderCell(theme: theme, label: 'STUDENT NAME'),
                  ),
                  _buildHeaderCell(theme: theme, width: _colStatusWidth, label: 'STATUS', alignment: Alignment.center),
                  _buildHeaderCell(theme: theme, width: _colViolationsWidth, label: 'VIOLATIONS', alignment: Alignment.center),
                  _buildHeaderCell(theme: theme, width: _colScoreWidth, label: 'SCORE', alignment: Alignment.center),
                  _buildHeaderCell(theme: theme, width: _colActionsWidth, label: 'ACTIONS', alignment: Alignment.center, hasRightBorder: false),
                ],
              ),
            ),
            // Item Rows
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final student = items[index];
                final rowBg = index.isOdd
                    ? (isDark
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.03)
                        : theme.colorScheme.primary.withValues(alpha: 0.025))
                    : theme.colorScheme.surface;

                return Container(
                  height: _rowHeight,
                  decoration: BoxDecoration(
                    color: rowBg,
                    border: Border(bottom: BorderSide(color: rowBorder)),
                  ),
                  child: Row(
                    children: [
                      // #
                      SizedBox(
                        width: _colNumWidth,
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                            ),
                          ),
                        ),
                      ),
                      // Student Name
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: _buildStudentNameCell(theme, student),
                        ),
                      ),
                      // Status
                      SizedBox(
                        width: _colStatusWidth,
                        child: Center(child: _buildStatusBadge(theme, student)),
                      ),
                      // Violations
                      SizedBox(
                        width: _colViolationsWidth,
                        child: Center(child: _buildViolationsBadge(theme, student)),
                      ),
                      // Score
                      SizedBox(
                        width: _colScoreWidth,
                        child: Center(child: _buildScoreCell(theme, student)),
                      ),
                      // Actions
                      SizedBox(
                        width: _colActionsWidth,
                        child: _buildActionsCell(theme, isDark, student),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell({
    required ThemeData theme,
    double? width,
    required String label,
    Alignment alignment = Alignment.centerLeft,
    bool hasRightBorder = true,
  }) {
    final cell = Container(
      height: double.infinity,
      width: width,
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

    return width != null ? cell : Expanded(child: cell);
  }

  Widget _buildStudentNameCell(ThemeData theme, StudentLiveProctorState s) {
    final ln = (s.lastName ?? '').trim();
    final fn = (s.firstName ?? '').trim();
    final mn = (s.middleName ?? '').trim();
    final mi = mn.isNotEmpty ? '${mn[0].toUpperCase()}.' : '';
    final restParts = [if (fn.isNotEmpty) fn, if (mi.isNotEmpty) mi].join(' ');

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: ln.isNotEmpty ? ln : s.studentName,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (ln.isNotEmpty && restParts.isNotEmpty)
                TextSpan(
                  text: ', $restParts',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.88),
                  ),
                ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (s.lrn.isNotEmpty)
          Text(
            'LRN: ${s.lrn}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusBadge(ThemeData theme, StudentLiveProctorState s) {
    if (s.isMissing) {
      return _badge(
        label: 'Missing',
        color: AppTheme.catRed,
        icon: LucideIcons.circleAlert,
      );
    }
    if (!s.isEntryAllowed) {
      return _badge(
        label: 'Not Allowed',
        color: AppTheme.catRed,
        icon: LucideIcons.lock,
      );
    }

    switch (s.status) {
      case ProctorSessionStatus.inProgress:
        final qText = s.currentQuestionNumber != null
            ? ' • Q${s.currentQuestionNumber}'
            : '';
        return _badge(
          label: 'Taking$qText',
          color: AppTheme.catBlue,
          icon: LucideIcons.loader,
        );
      case ProctorSessionStatus.submitted:
        return _badge(
          label: 'Completed',
          color: AppTheme.catGreen,
          icon: LucideIcons.checkCircle,
        );
      case ProctorSessionStatus.kicked:
        return _badge(
          label: 'Disqualified',
          color: AppTheme.catRed,
          icon: LucideIcons.ban,
        );
      case ProctorSessionStatus.retakeRequested:
        return _badge(
          label: 'Retake',
          color: Colors.amber.shade700,
          icon: LucideIcons.rotateCcw,
        );
      case ProctorSessionStatus.notStarted:
        return _badge(
          label: 'Pending',
          color: AppTheme.catSlate,
          icon: LucideIcons.clock,
        );
    }
  }

  Widget _badge({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViolationsBadge(ThemeData theme, StudentLiveProctorState s) {
    if (s.violationCount == 0) {
      return Text(
        '0',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
        ),
      );
    }

    final isSevere = s.violationCount >= 3;
    final color = isSevere ? AppTheme.catRed : Colors.orange.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.triangleAlert, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '${s.violationCount}',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCell(ThemeData theme, StudentLiveProctorState s) {
    if (s.status == ProctorSessionStatus.submitted && s.score != null) {
      final scoreStr = s.score!.toInt().toString();
      final totalStr = (s.totalPoints ?? 0.0).toInt().toString();
      return Text(
        '$scoreStr / $totalStr pts',
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: AppTheme.catGreen,
        ),
      );
    }
    return Text(
      '—',
      style: TextStyle(
        fontSize: 13,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
      ),
    );
  }

  Widget _buildActionsCell(
    ThemeData theme,
    bool isDark,
    StudentLiveProctorState student,
  ) {
    final isAllowed = student.isEntryAllowed;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Reset Button
        Tooltip(
          message: 'Reset Student Progress',
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => widget.onReset(student),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                ),
              ),
              child: const Icon(LucideIcons.rotateCcw, size: 14),
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Force Submit Button
        Tooltip(
          message: 'Force Submit',
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: student.status == ProctorSessionStatus.inProgress
                ? () => widget.onForceSubmit(student)
                : null,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: student.status == ProctorSessionStatus.inProgress
                      ? AppTheme.catBlue.withValues(alpha: 0.5)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
              child: Icon(
                LucideIcons.send,
                size: 14,
                color: student.status == ProctorSessionStatus.inProgress
                    ? AppTheme.catBlue
                    : theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Allow / Disallow Toggle Pill Button
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => widget.onToggleAllow(student),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isAllowed
                  ? AppTheme.catRed.withValues(alpha: 0.08)
                  : AppTheme.catGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isAllowed
                    ? AppTheme.catRed.withValues(alpha: 0.3)
                    : AppTheme.catGreen.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              isAllowed ? 'Disallow' : 'Allow Entry',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isAllowed ? AppTheme.catRed : AppTheme.catGreen,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
