import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/repositories/attendance_repository.dart';
import 'package:class_realm/data/repositories/supabase_attendance_repository.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/models/attendance_workspace_models.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentAttendanceScreen extends StatefulWidget {
  final AttendanceRepository? repository;

  const StudentAttendanceScreen({super.key, this.repository});

  @override
  State<StudentAttendanceScreen> createState() =>
      _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  static const int _pageSize = 10;

  late final AttendanceRepository _repo;

  bool _isLoading = true;
  String? _errorMessage;

  AttendanceStudentSummary? _summary;
  final List<AttendanceRecord> _records = [];
  int _currentPage = 1;
  AttendanceStatus? _selectedStatusFilter;
  String? _selectedSubject;
  List<String> _enrolledSubjectNames = [];
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? SupabaseAttendanceRepository.instance;
    _loadInitialData();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && !_isLoading) {
        _loadInitialData(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData({bool silent = false}) async {
    setState(() {
      if (!silent) {
        _isLoading = true;
      }
      _errorMessage = null;
    });

    try {
      if (silent) {
        AppDataCache.instance.invalidatePrefix('my_attendance_summary_');
      }
      final results = await Future.wait([
        _repo.getMyAttendanceSummary(),
        _repo.getMyAttendancePage(offset: 0, pageSize: 100),
      ]);

      final summary = results[0] as AttendanceStudentSummary;
      final page = results[1] as AttendancePage<AttendanceRecord>;

      // Attempt to load active enrolled subjects for this student
      try {
        final client = Supabase.instance.client;
        final user = client.auth.currentUser;
        if (user != null) {
          final enrollments = await client
              .from('student_enrollments')
              .select('''
                subject_offerings!inner (
                  is_archived,
                  subjects!inner ( subject_name, is_archived )
                )
              ''')
              .eq('student_id', user.id)
              .eq('status', 'enrolled')
              .eq('subject_offerings.is_archived', false)
              .eq('subject_offerings.subjects.is_archived', false);
          final subs = <String>{};
          for (final e in (enrollments as List)) {
            final off = e['subject_offerings'] as Map<String, dynamic>?;
            final isOfferingArchived = off?['is_archived'] == true;
            final sub = off?['subjects'] as Map<String, dynamic>?;
            final isSubArchived = sub?['is_archived'] == true;
            if (isOfferingArchived || isSubArchived) continue;
            final name = sub?['subject_name']?.toString().trim();
            if (name != null && name.isNotEmpty) {
              subs.add(name);
            }
          }
          if (subs.isNotEmpty) {
            _enrolledSubjectNames = subs.toList()..sort();
          }
        }
      } catch (_) {
        // Safe fallback in test or offline environment
      }

      if (!mounted) return;
      setState(() {
        _summary = summary;
        _records
          ..clear()
          ..addAll(page.rows);
        if (_currentPage > _totalPages && _totalPages > 0) {
          _currentPage = _totalPages;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent || _records.isEmpty) {
          _errorMessage = AppModals.sanitizeErrorMessage(e);
        }
        _isLoading = false;
      });
    }
  }

  static bool _isMethodKeyword(String value) {
    final v = value.trim().toLowerCase();
    return v.isEmpty ||
        v == 'manual' ||
        v == 'rfid' ||
        v == 'rfid scan' ||
        v == 'rfid (esp32)' ||
        v == 'system' ||
        v == 'auto' ||
        v == 'auto (system)';
  }

  static String _extractSubjectName(AttendanceRecord record) {
    final meth = record.method.trim();
    if (meth.contains(' • ')) {
      final s = meth.split(' • ').first.trim();
      if (s.isNotEmpty && !_isMethodKeyword(s)) return s;
    }
    final sec = record.section.trim();
    if (sec.contains(' (')) {
      final s = sec.split(' (').first.trim();
      if (s.isNotEmpty) return s;
    }
    if (!_isMethodKeyword(meth) && meth.isNotEmpty) {
      return meth;
    }
    if (sec.isNotEmpty && !sec.toLowerCase().startsWith('section')) {
      return sec;
    }
    return 'Class';
  }

  List<String> get _availableSubjectNames {
    if (_enrolledSubjectNames.isNotEmpty) {
      return _enrolledSubjectNames;
    }
    final set = <String>{};
    for (final r in _records) {
      final name = _extractSubjectName(r);
      if (name.isNotEmpty && name != 'General' && name != 'Class') {
        set.add(name);
      }
    }
    final list = set.toList();
    list.sort();
    return list;
  }

  List<AttendanceRecord> get _filteredRecords {
    var result = _records;
    if (_selectedSubject != null) {
      result = result
          .where((r) => _extractSubjectName(r) == _selectedSubject)
          .toList();
    }
    if (_selectedStatusFilter != null) {
      result = result.where((r) => r.status == _selectedStatusFilter).toList();
    }
    return result;
  }

  int get _totalPages {
    final count = _filteredRecords.length;
    if (count == 0) return 1;
    return (count / _pageSize).ceil();
  }

  List<AttendanceRecord> get _currentPageRecords {
    final filtered = _filteredRecords;
    final startIndex = (_currentPage - 1) * _pageSize;
    if (startIndex >= filtered.length) return [];
    final endIndex = min(startIndex + _pageSize, filtered.length);
    return filtered.sublist(startIndex, endIndex);
  }

  int get _scopedPresentCount {
    if (_selectedSubject == null) {
      return _summary?.presentCount ??
          _records.where((r) => r.status == AttendanceStatus.present).length;
    }
    return _records
        .where((r) =>
            _extractSubjectName(r) == _selectedSubject &&
            r.status == AttendanceStatus.present)
        .length;
  }

  int get _scopedLateCount {
    if (_selectedSubject == null) {
      final countedLate =
          _records.where((r) => r.status == AttendanceStatus.late).length;
      return max(_summary?.lateCount ?? 0, countedLate);
    }
    return _records
        .where((r) =>
            _extractSubjectName(r) == _selectedSubject &&
            r.status == AttendanceStatus.late)
        .length;
  }

  int get _scopedAbsentCount {
    if (_selectedSubject == null) {
      final countedAbsent =
          _records.where((r) => r.status == AttendanceStatus.absent).length;
      return max(_summary?.absentCount ?? 0, countedAbsent);
    }
    return _records
        .where((r) =>
            _extractSubjectName(r) == _selectedSubject &&
            r.status == AttendanceStatus.absent)
        .length;
  }

  int get _scopedRatePercent {
    final p = _scopedPresentCount;
    final l = _scopedLateCount;
    final a = _scopedAbsentCount;
    if (_selectedSubject == null) {
      final rawRate = _summary?.presenceRate ?? 0.0;
      final normalizedRate =
          (rawRate > 0.0 && rawRate <= 1.0 && (p + l) > 1)
              ? rawRate * 100.0
              : rawRate;
      return normalizedRate.clamp(0.0, 100.0).round();
    }
    final total = p + l + a;
    if (total == 0) return 0;
    return (((p + l) / total) * 100).clamp(0.0, 100.0).round();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Attendance Logs',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onPrimary,
          ),
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Container(
            color: theme.scaffoldBackgroundColor,
            child: _buildBody(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Center(
        child: LoadingAnimationWidget.staggeredDotsWave(
          color: theme.colorScheme.primary,
          size: 36,
        ),
      );
    }

    if (_errorMessage != null) {
      return AppPullToRefresh(
        onRefresh: () => _loadInitialData(silent: true),
        child: AppPullToRefresh.scrollableState(
          padding: EdgeInsets.zero,
          child: AppEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Unable to Load Attendance',
            message: _errorMessage!,
            actionLabel: 'Retry',
            onAction: _loadInitialData,
          ),
        ),
      );
    }

    final presentCount = _scopedPresentCount;
    final lateCount = _scopedLateCount;
    final absentCount = _scopedAbsentCount;
    final ratePercent = _scopedRatePercent;

    final filtered = _filteredRecords;
    final currentRows = _currentPageRecords;
    final totalCount = filtered.length;

    return Column(
      children: [
        // ── 1. Top Section: 4 Stat Cards, Subject Filter Bar & Stretched Pills ──
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          color: theme.colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 4 Stat Cards (Present, Late, Absent, Rate) — Strict 60-30-10
              Row(
                children: [
                  _buildStatCard(
                    theme,
                    'Present',
                    '$presentCount',
                    isSelected:
                        _selectedStatusFilter == AttendanceStatus.present,
                    onTap: () {
                      setState(() {
                        _selectedStatusFilter =
                            _selectedStatusFilter == AttendanceStatus.present
                                ? null
                                : AttendanceStatus.present;
                        _currentPage = 1;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildStatCard(
                    theme,
                    'Late',
                    '$lateCount',
                    isSelected: _selectedStatusFilter == AttendanceStatus.late,
                    onTap: () {
                      setState(() {
                        _selectedStatusFilter =
                            _selectedStatusFilter == AttendanceStatus.late
                                ? null
                                : AttendanceStatus.late;
                        _currentPage = 1;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildStatCard(
                    theme,
                    'Absent',
                    '$absentCount',
                    isSelected:
                        _selectedStatusFilter == AttendanceStatus.absent,
                    onTap: () {
                      setState(() {
                        _selectedStatusFilter =
                            _selectedStatusFilter == AttendanceStatus.absent
                                ? null
                                : AttendanceStatus.absent;
                        _currentPage = 1;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildStatCard(
                    theme,
                    'Rate',
                    '$ratePercent%',
                    isSelected:
                        _selectedStatusFilter == null &&
                        _selectedSubject == null,
                    onTap: () {
                      setState(() {
                        _selectedStatusFilter = null;
                        _selectedSubject = null;
                        _currentPage = 1;
                      });
                    },
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Subject Filter Button / Modal Trigger
              _buildSubjectSelectorBar(theme, isDark),

              const SizedBox(height: 8),

              // Filter Pills Row (All, Present, Late, Absent) — Stretched Edge-to-Edge
              Row(
                children: [
                  Expanded(
                    child: _buildFilterChip(
                      theme: theme,
                      label: 'All',
                      isSelected: _selectedStatusFilter == null,
                      onTap: () => setState(() {
                        _selectedStatusFilter = null;
                        _currentPage = 1;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFilterChip(
                      theme: theme,
                      label: 'Present',
                      isSelected:
                          _selectedStatusFilter == AttendanceStatus.present,
                      onTap: () => setState(() {
                        _selectedStatusFilter = AttendanceStatus.present;
                        _currentPage = 1;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFilterChip(
                      theme: theme,
                      label: 'Late',
                      isSelected: _selectedStatusFilter == AttendanceStatus.late,
                      onTap: () => setState(() {
                        _selectedStatusFilter = AttendanceStatus.late;
                        _currentPage = 1;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFilterChip(
                      theme: theme,
                      label: 'Absent',
                      isSelected:
                          _selectedStatusFilter == AttendanceStatus.absent,
                      onTap: () => setState(() {
                        _selectedStatusFilter = AttendanceStatus.absent;
                        _currentPage = 1;
                      }),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),

        // ── 2. Table of Attendance Logs ──
        Expanded(
          child: AppPullToRefresh(
            onRefresh: () => _loadInitialData(silent: true),
            child: currentRows.isEmpty
                ? AppPullToRefresh.scrollableState(
                    padding: EdgeInsets.zero,
                    child: AppEmptyState(
                      icon: Icons.fact_check_outlined,
                      title: _selectedStatusFilter != null
                          ? 'No ${_selectedStatusFilter!.name.toUpperCase()} Records'
                          : (_selectedSubject != null
                              ? 'No Records for $_selectedSubject'
                              : 'No Attendance Records Yet'),
                      message: _selectedStatusFilter != null
                          ? 'No attendance records matching this status.'
                          : (_selectedSubject != null
                              ? 'No attendance logged for this subject yet.'
                              : 'Your class attendance logs will appear here once recorded.'),
                      actionLabel:
                          (_selectedStatusFilter != null ||
                              _selectedSubject != null)
                          ? 'Clear Filters'
                          : null,
                      onAction:
                          (_selectedStatusFilter != null ||
                              _selectedSubject != null)
                          ? () => setState(() {
                                _selectedStatusFilter = null;
                                _selectedSubject = null;
                                _currentPage = 1;
                              })
                          : null,
                    ),
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: currentRows.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == 0) {
                        return _buildTableHeader(theme, isDark);
                      }
                      final record = currentRows[i - 1];
                      return _buildTableRow(
                        theme,
                        isDark,
                        record,
                        i - 1,
                        currentRows.length,
                      );
                    },
                  ),
          ),
        ),

        // ── 3. Table Pagination Bar (10 per page, always visible) ──
        _buildPaginationBar(theme, isDark, totalCount),
      ],
    );
  }

  Widget _buildSubjectSelectorBar(ThemeData theme, bool isDark) {
    final hasFilter = _selectedSubject != null;
    final accent = theme.colorScheme.primary;

    return InkWell(
      onTap: () => _showSubjectFilterModal(context, theme, isDark),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: hasFilter
              ? accent.withValues(alpha: isDark ? 0.14 : 0.07)
              : (isDark ? const Color(0xFF1F2937) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasFilter
                ? accent.withValues(alpha: isDark ? 0.45 : 0.35)
                : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.book_outlined,
              size: 15,
              color: hasFilter ? accent : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 7),
            Text(
              'Subject:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                _selectedSubject ?? 'All Subjects',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: hasFilter ? FontWeight.w700 : FontWeight.w600,
                  color: hasFilter ? accent : theme.colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasFilter) ...[
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedSubject = null;
                    _currentPage = 1;
                  });
                },
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.close_rounded,
                    size: 15,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Icon(
              Icons.unfold_more_rounded,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  void _showSubjectFilterModal(
    BuildContext context,
    ThemeData theme,
    bool isDark,
  ) {
    final subjects = _availableSubjectNames;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filter by Subject',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(ctx),
                      borderRadius: BorderRadius.circular(999),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Select a subject to view its specific attendance history.',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.55,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      _buildSubjectOptionTile(
                        theme: theme,
                        isDark: isDark,
                        title: 'All Subjects',
                        subtitle: 'Show attendance across all subjects',
                        isSelected: _selectedSubject == null,
                        logCount: _records.length,
                        onTap: () {
                          setState(() {
                            _selectedSubject = null;
                            _currentPage = 1;
                          });
                          Navigator.pop(ctx);
                        },
                      ),
                      for (final s in subjects) ...[
                        Divider(
                          height: 1,
                          color: isDark
                              ? Colors.white10
                              : const Color(0xFFE2E8F0),
                        ),
                        _buildSubjectOptionTile(
                          theme: theme,
                          isDark: isDark,
                          title: s,
                          isSelected: _selectedSubject == s,
                          logCount: _records
                              .where((r) => _extractSubjectName(r) == s)
                              .length,
                          onTap: () {
                            setState(() {
                              _selectedSubject = s;
                              _currentPage = 1;
                            });
                            Navigator.pop(ctx);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubjectOptionTile({
    required ThemeData theme,
    required bool isDark,
    required String title,
    String? subtitle,
    required bool isSelected,
    required int logCount,
    required VoidCallback onTap,
  }) {
    final accent = theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: isDark ? 0.16 : 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? accent
                      : (isDark ? Colors.white30 : const Color(0xFFCBD5E1)),
                  width: isSelected ? 5 : 1.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? accent : theme.colorScheme.onSurface,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$logCount ${logCount == 1 ? 'log' : 'logs'}',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 85,
            child: Text(
              'DATE & TIME',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'SUBJECT & INFO',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Container(
            width: 65,
            alignment: Alignment.centerRight,
            child: Text(
              'STATUS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(
    ThemeData theme,
    bool isDark,
    AttendanceRecord record,
    int rowIndex,
    int totalRows,
  ) {
    final isLast = rowIndex == totalRows - 1;
    final source = _resolveProvenance(record);
    final subjectName = _extractSubjectName(record);
    final classLabel = _resolveClassLabel(record);
    final timeInDisplay =
        record.timeIn.trim().isEmpty ? '—' : record.timeIn.trim();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: rowIndex % 2 == 1
            ? (isDark
                ? Colors.white.withValues(alpha: 0.02)
                : const Color(0xFFFAFAFB))
            : (isDark ? const Color(0xFF263040) : Colors.white),
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(10))
            : BorderRadius.zero,
        border: Border(
          left: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
          right: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
          bottom: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date & Time
          SizedBox(
            width: 85,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(record.date),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeInDisplay,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Subject & Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subjectName != 'Class' ? subjectName : classLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    _buildProvenancePill(theme, source),
                    if (record.section.isNotEmpty &&
                        record.section != subjectName) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          record.section,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                if (record.remarks != null &&
                    record.remarks!.trim().isNotEmpty &&
                    !_isSystemRemark(record.remarks)) ...[
                  const SizedBox(height: 4),
                  Text(
                    record.remarks!.trim(),
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10.5,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Status Badge
          Container(
            width: 65,
            alignment: Alignment.topRight,
            child: StatusBadge.fromAttendance(record.status),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationBar(ThemeData theme, bool isDark, int totalCount) {
    final totalPages = _totalPages;
    final startIndex =
        totalCount == 0 ? 0 : (_currentPage - 1) * _pageSize + 1;
    final endIndex = min(_currentPage * _pageSize, totalCount);

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                totalCount == 0
                    ? 'Showing 0 of 0 logs'
                    : 'Showing $startIndex–$endIndex of $totalCount logs',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Previous button
                InkWell(
                  onTap: _currentPage > 1
                      ? () => setState(() => _currentPage--)
                      : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color:
                            isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chevron_left_rounded,
                          size: 16,
                          color: _currentPage > 1
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.3),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Prev',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: _currentPage > 1
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Page indicator pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(
                      alpha: isDark ? 0.2 : 0.1,
                    ),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(
                        alpha: isDark ? 0.4 : 0.25,
                      ),
                    ),
                  ),
                  child: Text(
                    '$_currentPage / ${max(1, totalPages)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Next button
                InkWell(
                  onTap: _currentPage < totalPages
                      ? () => setState(() => _currentPage++)
                      : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color:
                            isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: _currentPage < totalPages
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.3),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: _currentPage < totalPages
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required ThemeData theme,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: isDark ? 0.22 : 0.12)
              : (isDark
                  ? const Color(0xFF1F2937)
                  : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? accent
                : (isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? accent : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    ThemeData theme,
    String label,
    String value, {
    VoidCallback? onTap,
    bool isSelected = false,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withValues(alpha: isDark ? 0.2 : 0.08)
                : (isDark ? const Color(0xFF263040) : Colors.white),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? accent
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: !isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? accent : theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildProvenancePill(ThemeData theme, AttendanceSource source) {
    final isDark = theme.brightness == Brightness.dark;
    late final Color bg;
    late final Color fg;
    late final Color border;
    late final IconData icon;

    switch (source) {
      case AttendanceSource.rfid:
        bg = AppTheme.catTeal.withValues(alpha: isDark ? 0.18 : 0.11);
        fg = isDark ? const Color(0xFF2DD4BF) : AppTheme.catTeal;
        border = AppTheme.catTeal.withValues(alpha: isDark ? 0.4 : 0.28);
        icon = Icons.sensors_rounded;
        break;
      case AttendanceSource.manual:
        bg = AppTheme.catSlate.withValues(alpha: isDark ? 0.22 : 0.1);
        fg = isDark ? const Color(0xFFCBD5E1) : AppTheme.catSlate;
        border = AppTheme.catSlate.withValues(alpha: isDark ? 0.4 : 0.25);
        icon = Icons.edit_note_rounded;
        break;
      case AttendanceSource.system:
        bg = isDark
            ? const Color(0xFFFBBF24).withValues(alpha: 0.16)
            : const Color(0xFFFEF3C7);
        fg = isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
        border = isDark
            ? const Color(0xFFFBBF24).withValues(alpha: 0.36)
            : const Color(0xFFF59E0B).withValues(alpha: 0.35);
        icon = Icons.auto_mode_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 3),
          Text(
            source.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  static AttendanceSource _resolveProvenance(AttendanceRecord record) {
    final m = record.method.trim().toLowerCase();
    if (m.contains('rfid') || m.contains('esp32') || m.contains('scan')) {
      return AttendanceSource.rfid;
    }
    if (m.contains('system') || m.contains('auto')) {
      return AttendanceSource.system;
    }
    if (m == 'manual') {
      return AttendanceSource.manual;
    }
    final rem = (record.remarks ?? '').trim().toLowerCase();
    if (rem.contains('rfid') || rem.contains('esp32')) {
      return AttendanceSource.rfid;
    }
    if (rem.contains('system') || rem.contains('auto')) {
      return AttendanceSource.system;
    }
    try {
      return AttendanceSource.parse(record.method);
    } on FormatException {
      return AttendanceSource.manual;
    }
  }

  static bool _isSystemRemark(String? r) {
    if (r == null) return false;
    final t = r.trim().toLowerCase();
    if (t.isEmpty) return false;
    return t.startsWith('recorded via') ||
        t.startsWith('promoted from') ||
        t.startsWith('promoted to') ||
        t.startsWith('timestamp updated') ||
        t == 'hardware_esp32' ||
        t == 'auto-absent' ||
        t.startsWith('system auto-absent') ||
        t.startsWith('esp32_');
  }

  static String _resolveClassLabel(AttendanceRecord record) {
    final sec = record.section.trim();
    final meth = record.method.trim();
    final sName = record.studentName.trim();

    if (!_isMethodKeyword(meth) &&
        sec.isNotEmpty &&
        meth.toLowerCase() != sec.toLowerCase()) {
      return '$meth • $sec';
    }
    if (!_isMethodKeyword(meth)) return meth;
    if (sec.isNotEmpty) return sec;
    if (sName.isNotEmpty) return sName;
    return 'Class Attendance';
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
