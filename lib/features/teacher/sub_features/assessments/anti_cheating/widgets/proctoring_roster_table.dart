import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/features/teacher/sub_features/assessments/anti_cheating/models/student_live_proctor_state.dart';

enum ProctorRosterFilter { allActives, male, female, all }

enum ProctorSortColumn { studentName, violations, score }

class ProctoringRosterTable extends StatefulWidget {
  final List<StudentLiveProctorState> students;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final void Function(StudentLiveProctorState student) onReset;
  final void Function(StudentLiveProctorState student) onToggleAllow;
  final bool isScheduleExpired;
  final VoidCallback? onUpdateSchedule;
  final String? scheduleDateFormatted;
  final Future<void> Function()? onRefresh;

  const ProctoringRosterTable({
    super.key,
    required this.students,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onReset,
    required this.onToggleAllow,
    this.isScheduleExpired = false,
    this.onUpdateSchedule,
    this.scheduleDateFormatted,
    this.onRefresh,
  });

  @override
  State<ProctoringRosterTable> createState() => _ProctoringRosterTableState();
}

class _ProctoringRosterTableState extends State<ProctoringRosterTable>
    with SingleTickerProviderStateMixin {
  static const double _headerHeight = 44.0;
  static const double _rowHeight = 52.0;

  static const double _colNumWidth = 44.0;

  ProctorRosterFilter _filter = ProctorRosterFilter.all;
  ProctorSortColumn _sortColumn = ProctorSortColumn.studentName;
  bool _sortAscending = true;
  bool _isRefreshing = false;
  late final AnimationController _refreshSpinController;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
    _refreshSpinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
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
    _refreshSpinController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _triggerRefresh() async {
    if (_isRefreshing || widget.onRefresh == null) return;
    setState(() => _isRefreshing = true);
    _refreshSpinController.repeat();
    try {
      await Future.wait([
        widget.onRefresh!(),
        Future<void>.delayed(const Duration(milliseconds: 650)),
      ]);
    } finally {
      if (mounted) {
        _refreshSpinController.stop();
        _refreshSpinController.reset();
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _toggleSort(ProctorSortColumn column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        // Default direction: A-Z for studentName, Highest-to-Lowest for violations & score
        _sortAscending = column == ProctorSortColumn.studentName;
      }
    });
  }

  int _compareByNameAsc(StudentLiveProctorState a, StudentLiveProctorState b) {
    final aLast = (a.lastName ?? a.studentName).trim().toLowerCase();
    final bLast = (b.lastName ?? b.studentName).trim().toLowerCase();
    final lnCmp = aLast.compareTo(bLast);
    if (lnCmp != 0) return lnCmp;
    final aFirst = (a.firstName ?? '').trim().toLowerCase();
    final bFirst = (b.firstName ?? '').trim().toLowerCase();
    return aFirst.compareTo(bFirst);
  }

  bool _isMale(StudentLiveProctorState s) {
    final g = (s.gender ?? '').trim().toLowerCase();
    return g == 'male' || g == 'm' || g == 'boy';
  }

  bool _isFemale(StudentLiveProctorState s) {
    final g = (s.gender ?? '').trim().toLowerCase();
    return g == 'female' || g == 'f' || g == 'girl';
  }

  List<StudentLiveProctorState> _buildFilteredSortedRoster() {
    final q = widget.searchQuery.trim().toLowerCase();

    final filtered = widget.students.where((s) {
      if (_filter == ProctorRosterFilter.allActives) {
        if (s.status != ProctorSessionStatus.inProgress) {
          return false;
        }
      } else if (_filter == ProctorRosterFilter.male && !_isMale(s)) {
        return false;
      } else if (_filter == ProctorRosterFilter.female && !_isFemale(s)) {
        return false;
      }
      if (q.isNotEmpty) {
        final full =
            '${s.lastName ?? ''} ${s.firstName ?? ''} ${s.middleName ?? ''} ${s.studentName}'
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
      switch (_sortColumn) {
        case ProctorSortColumn.studentName:
          final cmp = _compareByNameAsc(a, b);
          return _sortAscending ? cmp : -cmp;
        case ProctorSortColumn.violations:
          final vCmp = a.violationCount.compareTo(b.violationCount);
          if (vCmp != 0) {
            return _sortAscending ? vCmp : -vCmp;
          }
          return _compareByNameAsc(a, b);
        case ProctorSortColumn.score:
          final aHasScore = a.score != null;
          final bHasScore = b.score != null;
          if (aHasScore != bHasScore) {
            // Always place students with recorded scores before ungraded '—' rows
            return aHasScore ? -1 : 1;
          }
          if (aHasScore && bHasScore) {
            final sCmp = a.score!.compareTo(b.score!);
            if (sCmp != 0) {
              return _sortAscending ? sCmp : -sCmp;
            }
          }
          return _compareByNameAsc(a, b);
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final totalCount = widget.students.length;
    final activeCount = widget.students
        .where((s) => s.status == ProctorSessionStatus.inProgress)
        .length;
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
              activeCount: activeCount,
              maleCount: maleCount,
              femaleCount: femaleCount,
              totalCount: totalCount,
            ),
            _buildTableBody(
              theme: theme,
              isDark: isDark,
              items: filtered,
              totalEnrolled: totalCount,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopFilterBar({
    required ThemeData theme,
    required bool isDark,
    required int activeCount,
    required int maleCount,
    required int femaleCount,
    required int totalCount,
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
                  label: 'All Actives ($activeCount)',
                  selected: _filter == ProctorRosterFilter.allActives,
                  onTap: () =>
                      setState(() => _filter = ProctorRosterFilter.allActives),
                ),
                _buildGenderSegment(
                  theme: theme,
                  isDark: isDark,
                  label: 'Male ($maleCount)',
                  selected: _filter == ProctorRosterFilter.male,
                  onTap: () =>
                      setState(() => _filter = ProctorRosterFilter.male),
                ),
                _buildGenderSegment(
                  theme: theme,
                  isDark: isDark,
                  label: 'Female ($femaleCount)',
                  selected: _filter == ProctorRosterFilter.female,
                  onTap: () =>
                      setState(() => _filter = ProctorRosterFilter.female),
                ),
                _buildGenderSegment(
                  theme: theme,
                  isDark: isDark,
                  label: 'All ($totalCount)',
                  selected: _filter == ProctorRosterFilter.all,
                  onTap: () =>
                      setState(() => _filter = ProctorRosterFilter.all),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 240,
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
              if (widget.onUpdateSchedule != null) ...[
                const SizedBox(width: 10),
                _buildScheduleDatePill(theme, isDark),
              ],
              if (widget.onRefresh != null) ...[
                const SizedBox(width: 8),
                _buildRefreshButton(theme, isDark),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshButton(ThemeData theme, bool isDark) {
    return Tooltip(
      message: 'Refresh Proctoring Roster & Scores',
      child: InkWell(
        onTap: _isRefreshing ? null : _triggerRefresh,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RotationTransition(
                turns: _refreshSpinController,
                child: Icon(
                  LucideIcons.refreshCw,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Refresh',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleDatePill(ThemeData theme, bool isDark) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_outlined,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            widget.scheduleDateFormatted != null
                ? 'Set Date: ${widget.scheduleDateFormatted}'
                : 'Set Date: --',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: widget.onUpdateSchedule,
            icon: const Icon(Icons.edit_calendar, size: 15),
            label: const Text('Update Schedule'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
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
    required int totalEnrolled,
  }) {
    final headerBg = isDark
        ? theme.colorScheme.primary.withValues(alpha: 0.14)
        : theme.colorScheme.primary.withValues(alpha: 0.08);
    final headerBorder = theme.colorScheme.primary.withValues(alpha: 0.25);
    final rowBorder = theme.colorScheme.onSurface.withValues(
      alpha: isDark ? 0.1 : 0.07,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final tableWidth = availableWidth > 860 ? availableWidth : 860.0;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Row (Always visible & stretches edge-to-edge)
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
                        label: '#',
                        alignment: Alignment.center,
                      ),
                      _buildSortableHeaderCell(
                        theme: theme,
                        flex: 3,
                        label: 'STUDENT NAME',
                        column: ProctorSortColumn.studentName,
                        alignment: Alignment.centerLeft,
                      ),
                      _buildHeaderCell(
                        theme: theme,
                        flex: 2,
                        label: 'STATUS',
                        alignment: Alignment.center,
                      ),
                      _buildSortableHeaderCell(
                        theme: theme,
                        flex: 2,
                        label: 'VIOLATIONS',
                        column: ProctorSortColumn.violations,
                        alignment: Alignment.center,
                      ),
                      _buildSortableHeaderCell(
                        theme: theme,
                        flex: 2,
                        label: 'SCORE',
                        column: ProctorSortColumn.score,
                        alignment: Alignment.center,
                      ),
                      _buildHeaderCell(
                        theme: theme,
                        flex: 3,
                        label: 'ACTIONS',
                        alignment: Alignment.center,
                        hasRightBorder: false,
                      ),
                    ],
                  ),
                ),
                // Item Rows or Polished Full-Width Empty Row
                if (items.isEmpty)
                  Container(
                    width: tableWidth,
                    padding: const EdgeInsets.symmetric(
                      vertical: 48,
                      horizontal: 24,
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: isDark ? 0.14 : 0.08,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              totalEnrolled == 0
                                  ? LucideIcons.users
                                  : LucideIcons.searchX,
                              size: 26,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          totalEnrolled == 0
                              ? 'No Learners Enrolled'
                              : (_filter == ProctorRosterFilter.allActives
                                  ? 'No Active Learners Currently Answering'
                                  : 'No Matching Learners Found'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Text(
                            totalEnrolled == 0
                                ? 'No learners have been enrolled in this section yet. Students will appear here automatically once enrolled in this subject.'
                                : (_filter == ProctorRosterFilter.allActives
                                    ? 'Learners will appear here once they start answering the test. Select "All" to view the complete roster.'
                                    : 'Try adjusting your search query or gender filter.'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ),
                        if (totalEnrolled > 0 &&
                            _filter != ProctorRosterFilter.all) ...[
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              side: BorderSide(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _filter = ProctorRosterFilter.all;
                                _searchController.clear();
                              });
                              widget.onSearchChanged('');
                            },
                            icon: const Icon(LucideIcons.users, size: 14),
                            label: const Text(
                              'View All Enrolled Learners',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final student = items[index];
                      final rowBg = index.isOdd
                          ? (isDark
                              ? theme.colorScheme.onSurface.withValues(
                                  alpha: 0.03,
                                )
                              : theme.colorScheme.primary.withValues(
                                  alpha: 0.025,
                                ))
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
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.65),
                                  ),
                                ),
                              ),
                            ),
                            // Student Name
                            Expanded(
                              flex: 3,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: _buildStudentNameCell(theme, student),
                              ),
                            ),
                            // Status
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: _buildStatusBadge(theme, student),
                              ),
                            ),
                            // Violations
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: _buildViolationsBadge(theme, student),
                              ),
                            ),
                            // Score
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: _buildScoreCell(theme, student),
                              ),
                            ),
                            // Actions
                            Expanded(
                              flex: 3,
                              child: Center(
                                child: _buildActionsCell(theme, isDark, student),
                              ),
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
      },
    );
  }

  Widget _buildHeaderCell({
    required ThemeData theme,
    double? width,
    int? flex,
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

    if (width != null) return cell;
    if (flex != null) return Expanded(flex: flex, child: cell);
    return Expanded(child: cell);
  }

  Widget _buildSortableHeaderCell({
    required ThemeData theme,
    required int flex,
    required String label,
    required ProctorSortColumn column,
    Alignment alignment = Alignment.center,
    bool hasRightBorder = true,
  }) {
    final isActive = _sortColumn == column;
    String badgeText = '';
    if (isActive) {
      if (column == ProctorSortColumn.studentName) {
        badgeText = _sortAscending ? 'A–Z' : 'Z–A';
      } else {
        badgeText = _sortAscending ? 'Low–High' : 'High–Low';
      }
    }

    final IconData sortIcon = !isActive
        ? LucideIcons.arrowUpDown
        : (_sortAscending ? LucideIcons.arrowUp : LucideIcons.arrowDown);

    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => _toggleSort(column),
        child: Container(
          height: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: alignment,
          decoration: BoxDecoration(
            color: isActive
                ? theme.colorScheme.primary.withValues(alpha: 0.08)
                : null,
            border: hasRightBorder
                ? Border(
                    right: BorderSide(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                    ),
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: alignment == Alignment.centerLeft
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Icon(
                sortIcon,
                size: 13,
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
              if (isActive && badgeText.isNotEmpty) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
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
          label: 'In Progress$qText',
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
    final isExpired = widget.isScheduleExpired;
    final isCompleted = student.status == ProctorSessionStatus.submitted;
    final isInProgress = student.status == ProctorSessionStatus.inProgress;
    final isKicked = student.status == ProctorSessionStatus.kicked;

    // 1. Reset progress: enabled when student is actively taking, completed, or disqualified (and schedule not expired)
    final canReset = !isExpired && (isInProgress || isCompleted || isKicked);

    // 2. Allow entry / disallow toggle:
    // Disabled if schedule expired, completed, or actively in progress (teacher cannot disallow active student)
    final canToggleAllow = !isExpired && !isCompleted && !isInProgress;

    final String toggleLabel = isCompleted
        ? 'Completed'
        : isInProgress
            ? 'Answering'
            : (isAllowed ? 'Disallow' : 'Allow Entry');

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Reset Button (Fixed 28x28)
        Tooltip(
          message: isExpired
              ? 'Examination schedule has ended'
              : !canReset
                  ? 'Student has not started the assessment yet'
                  : 'Reset Student Attempt & Progress',
          child: SizedBox(
            width: 28,
            height: 28,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: canReset ? () => widget.onReset(student) : null,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: canReset
                      ? AppTheme.catOrange.withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: canReset
                        ? AppTheme.catOrange.withValues(alpha: 0.45)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                  ),
                ),
                child: Icon(
                  LucideIcons.rotateCcw,
                  size: 14,
                  color: canReset
                      ? AppTheme.catOrange
                      : theme.colorScheme.onSurface.withValues(alpha: 0.25),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Allow / Disallow Toggle Pill Button (Fixed Width 92px so Reset NEVER shifts)
        Tooltip(
          message: isExpired
              ? 'Examination schedule has ended'
              : isCompleted
                  ? 'Student has already completed the assessment'
                  : isInProgress
                      ? 'Cannot lock out student while test is in progress'
                      : (isAllowed ? 'Disallow Learner Entry' : 'Allow Learner Entry'),
          child: SizedBox(
            width: 92,
            height: 28,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: canToggleAllow ? () => widget.onToggleAllow(student) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: !canToggleAllow
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.04)
                      : isAllowed
                          ? AppTheme.catRed.withValues(alpha: 0.08)
                          : AppTheme.catGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: !canToggleAllow
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.1)
                        : isAllowed
                            ? AppTheme.catRed.withValues(alpha: 0.3)
                            : AppTheme.catGreen.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  toggleLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: !canToggleAllow
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.32)
                        : isAllowed
                            ? AppTheme.catRed
                            : AppTheme.catGreen,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
