import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/data/repositories/supabase_schedule_repository.dart';
import 'package:class_realm/features/teacher/widgets/timetable_grid_widget.dart';

class TeacherScheduleTab extends StatefulWidget {
  const TeacherScheduleTab({super.key});

  @override
  State<TeacherScheduleTab> createState() => _TeacherScheduleTabState();
}

class _TeacherScheduleTabState extends State<TeacherScheduleTab> {
  bool _isGridView = true;
  bool _isLoading = true;
  String? _loadError;
  List<ScheduleModel> _liveSchedules = [];
  List<Map<String, dynamic>> _dbSections = [];
  List<Map<String, dynamic>> _dbSubjects = [];

  final SupabaseScheduleRepository _repo = SupabaseScheduleRepository.instance;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final teacherId = _requireTeacherId();

      final results = await Future.wait([
        _repo.getSchedules(teacherId: teacherId),
        _repo.getSections(teacherId: teacherId),
        _repo.getSubjects(teacherId: teacherId),
      ]);

      final fetchedSchedules = results[0] as List<ScheduleModel>;
      final fetchedSections = results[1] as List<Map<String, dynamic>>;
      final fetchedSubjects = results[2] as List<Map<String, dynamic>>;

      setState(() {
        _liveSchedules = fetchedSchedules;
        _dbSections = fetchedSections;
        _dbSubjects = fetchedSubjects;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _liveSchedules = [];
        _dbSections = [];
        _dbSubjects = [];
        _loadError = e.toString(); 
        _isLoading = false;
      });
    }
  }

  String _requireTeacherId() {
    final teacherId = AuthRepository.instance.currentUser?.id;
    if (teacherId == null || teacherId.isEmpty) {
      throw StateError('A signed-in teacher is required to manage schedules.');
    }
    return teacherId;
  }

  // Calculate daily hours for soft warning (> 6 hours)
  Map<String, double> _calculateDailyHours() {
    final map = <String, double>{};
    for (final s in _liveSchedules) {
      final hours = s.durationMinutes / 60.0;
      map[s.dayOfWeek] = (map[s.dayOfWeek] ?? 0.0) + hours;
    }
    return map;
  }

  int _timeToMinutes(String timeStr) {
    try {
      final formatted = ScheduleModel.formatTime12to24(timeStr);
      final parts = formatted.split(':');
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      return h * 60 + m;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedSchedules = List<ScheduleModel>.from(_liveSchedules);
    const dayOrder = {
      'Monday': 1,
      'Tuesday': 2,
      'Wednesday': 3,
      'Thursday': 4,
      'Friday': 5,
      'Saturday': 6,
      'Sunday': 7,
    };
    sortedSchedules.sort((a, b) {
      final dayA = dayOrder[a.dayOfWeek] ?? 8;
      final dayB = dayOrder[b.dayOfWeek] ?? 8;
      if (dayA != dayB) return dayA.compareTo(dayB);
      return a.startTime.compareTo(b.startTime);
    });

    final dailyHours = _calculateDailyHours();
    final heavyDays = dailyHours.entries.where((e) => e.value > 6.0).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Class Schedule & Timetable',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Weekly teaching timetable, room assignments, and DepEd grading templates.',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // View Toggle (Timetable Grid / List)
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(7),
                      ),
                      onTap: () => setState(() => _isGridView = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        color: _isGridView
                            ? theme.colorScheme.primary.withValues(alpha: 0.12)
                            : Colors.transparent,
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.calendar,
                              size: 16,
                              color: _isGridView
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: 0.6,
                                    ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Grid',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _isGridView
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: _isGridView
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.8,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.12,
                      ),
                    ),
                    InkWell(
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(7),
                      ),
                      onTap: () => setState(() => _isGridView = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        color: !_isGridView
                            ? theme.colorScheme.primary.withValues(alpha: 0.12)
                            : Colors.transparent,
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.list,
                              size: 16,
                              color: !_isGridView
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: 0.6,
                                    ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'List',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: !_isGridView
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: !_isGridView
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.8,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (_isLoading ||
                  _loadError != null ||
                  _dbSections.isEmpty ||
                  _dbSubjects.isEmpty)
                Tooltip(
                  message: 'You must set up sections and subjects first.',
                  child: Opacity(
                    opacity: 0.5,
                    child: AppButton.primary(
                      label: 'Add Schedule Entry',
                      icon: Icons.add,
                      onPressed: () {},
                    ),
                  ),
                )
              else
                AppButton.primary(
                  label: 'Add Schedule Entry',
                  icon: Icons.add,
                  onPressed: () => _showScheduleEntryDialog(context),
                ),
            ],
          ),

          // Daily Teaching Limit Soft Warning
          if (heavyDays.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Notice: Your teaching load on ${heavyDays.map((e) => "${e.key} (${e.value.toStringAsFixed(1)} hrs)").join(", ")} exceeds the recommended 6-hour daily target.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.amber,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),

          // Body Content (Timetable Grid or List View)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _liveSchedules.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            LucideIcons.calendarX,
                            size: 48,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No Class Schedules Yet',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your teaching schedule and timetable will appear here.\nClick "Add Schedule Entry" to start organizing your classes.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_dbSections.isEmpty || _dbSubjects.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  'You must set up Sections and Subjects in Classroom Setup first.',
                                  style: TextStyle(color: Colors.amber.shade800, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          )
                        else
                          FilledButton.icon(
                            onPressed: () => _showScheduleEntryDialog(context),
                            icon: const Icon(LucideIcons.plus),
                            label: const Text('Create First Schedule'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                      ],
                    ),
                  )
                : _isGridView
                ? Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.12,
                        ),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: TimetableGridWidget(
                      schedules: _liveSchedules,
                      onEdit: (s) =>
                          _showScheduleEntryDialog(context, schedule: s),
                    ),
                  )
                : _buildListView(sortedSchedules, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(List<ScheduleModel> sortedSchedules, ThemeData theme) {
    if (sortedSchedules.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.calendarX,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Class Schedules Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your teaching schedule and timetable will appear here.\nClick "Add Schedule Entry" to start organizing your classes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            if (_dbSections.isEmpty || _dbSubjects.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'You must set up Sections and Subjects in Classroom Setup first.',
                      style: TextStyle(color: Colors.amber.shade800, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )
            else
              FilledButton.icon(
                onPressed: () => _showScheduleEntryDialog(context),
                icon: const Icon(LucideIcons.plus),
                label: const Text('Create First Schedule'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: sortedSchedules.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final s = sortedSchedules[i];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.calendar_today,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.subject,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Section: ${s.section} • Room: ${s.room.isEmpty ? "TBD" : s.room} • Grading: WW ${s.wwWeight?.toInt() ?? 20}% / PT ${s.ptWeight?.toInt() ?? 50}% / EX ${s.exWeight?.toInt() ?? 30}%',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${s.dayOfWeek} • ${s.startTime} - ${s.endTime} (${s.durationMinutes} mins)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    onPressed: () =>
                        _showScheduleEntryDialog(context, schedule: s),
                    tooltip: 'Edit entry',
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: AppTheme.catRed,
                    ),
                    onPressed: () async {
                      final confirm = await AppModals.showConfirmDialog(
                        context: context,
                        title: 'Delete Schedule Entry',
                        message:
                            'Are you sure you want to remove this schedule for ${s.subject} (${s.section})?',
                        confirmLabel: 'Delete',
                        confirmColor: AppTheme.catRed,
                      );
                      if (confirm == true) {
                        try {
                          await _repo.deleteSchedule(s.id);
                          await _loadData();
                        } catch (_) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Could not delete this schedule. Please try again.',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    tooltip: 'Delete entry',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showScheduleEntryDialog(
    BuildContext context, {
    ScheduleModel? schedule,
  }) {
    final isEditing = schedule != null;
    int selectedGrade = schedule?.gradeLevel ?? 11;

    // Filter sections for selected grade
    List<Map<String, dynamic>> filteredSections = _dbSections
        .where((sec) => sec['grade_level'] == selectedGrade)
        .toList();

    String selectedSectionId =
        schedule?.sectionId ??
        (filteredSections.isNotEmpty
            ? filteredSections.first['id']?.toString() ?? ''
            : '');
    String selectedSectionName =
        schedule?.section ??
        (filteredSections.isNotEmpty
            ? filteredSections.first['name']?.toString() ?? ''
            : '');

    // Filter subjects for selected grade
    List<Map<String, dynamic>> filteredSubjects = _dbSubjects
        .where((sub) => sub['grade_level'] == selectedGrade)
        .toList();

    String selectedSubjectId =
        schedule?.subjectId ??
        (filteredSubjects.isNotEmpty
            ? filteredSubjects.first['id']?.toString() ?? ''
            : '');
    String selectedSubjectName =
        schedule?.subject ??
        (filteredSubjects.isNotEmpty
            ? filteredSubjects.first['name']?.toString() ?? ''
            : '');

    double wwWeight = schedule?.wwWeight ?? 20.0;
    double ptWeight = schedule?.ptWeight ?? 50.0;
    double exWeight = schedule?.exWeight ?? 30.0;

    final roomCtrl = TextEditingController(text: schedule?.room ?? '');
    String selectedDay = schedule?.dayOfWeek ?? 'Monday';
    String startTime = schedule?.startTime ?? '07:30 AM';
    String endTime = schedule?.endTime ?? '09:00 AM';

    String? clashErrorMessage;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final timeSlots = [
            '07:00 AM',
            '07:30 AM',
            '08:00 AM',
            '08:30 AM',
            '09:00 AM',
            '09:30 AM',
            '10:00 AM',
            '10:30 AM',
            '11:00 AM',
            '11:30 AM',
            '12:00 PM',
            '12:30 PM',
            '01:00 PM',
            '01:30 PM',
            '02:00 PM',
            '02:30 PM',
            '03:00 PM',
            '03:30 PM',
            '04:00 PM',
            '04:30 PM',
            '05:00 PM',
            '05:30 PM',
            '06:00 PM',
          ];

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  isEditing ? Icons.edit_calendar : Icons.add_alarm,
                  color: Theme.of(ctx).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(isEditing ? 'Edit Schedule Entry' : 'Add Schedule Entry'),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Clash Error Banner
                    if (clashErrorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.catRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.catRed.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: AppTheme.catRed,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                clashErrorMessage!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.catRed,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Grade Level Selector
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: selectedGrade,
                            decoration: const InputDecoration(
                              labelText: 'GRADE LEVEL',
                              border: OutlineInputBorder(),
                            ),
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(
                                value: 11,
                                child: Text('Grade 11 (Strengthened SHS)', overflow: TextOverflow.ellipsis),
                              ),
                              DropdownMenuItem(
                                value: 12,
                                child: Text('Grade 12', overflow: TextOverflow.ellipsis),
                              ),
                            ],
                            onChanged: (val) {
                              if (val == null) return;
                              setModalState(() {
                                selectedGrade = val;
                                // Reload sections
                                filteredSections = _dbSections
                                    .where((sec) => sec['grade_level'] == val)
                                    .toList();
                                selectedSectionId = filteredSections.isNotEmpty
                                    ? filteredSections.first['id'].toString()
                                    : '';
                                selectedSectionName =
                                    filteredSections.isNotEmpty
                                    ? filteredSections.first['name'].toString()
                                    : '';

                                // Reload subjects
                                filteredSubjects = _dbSubjects
                                    .where((sub) => sub['grade_level'] == val)
                                    .toList();
                                if (filteredSubjects.isNotEmpty) {
                                  selectedSubjectId = filteredSubjects
                                      .first['id']
                                      .toString();
                                  selectedSubjectName = filteredSubjects
                                      .first['name']
                                      .toString();
                                } else {
                                  selectedSubjectId = '';
                                  selectedSubjectName = '';
                                }
                                clashErrorMessage = null;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Section Selector
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedSectionId.isNotEmpty
                                ? selectedSectionId
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'SECTION',
                              border: OutlineInputBorder(),
                            ),
                            isExpanded: true,
                            items: filteredSections.map((sec) {
                              return DropdownMenuItem<String>(
                                value: sec['id'].toString(),
                                child: Text(sec['name'].toString(), overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val == null) return;
                              setModalState(() {
                                selectedSectionId = val;
                                final found = filteredSections.firstWhere(
                                  (sec) => sec['id'].toString() == val,
                                  orElse: () => {'name': 'Section'},
                                );
                                selectedSectionName = found['name'].toString();
                                clashErrorMessage = null;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Subject Selector
                    DropdownButtonFormField<String>(
                      value: selectedSubjectId.isNotEmpty
                          ? selectedSubjectId
                          : (filteredSubjects.isNotEmpty
                                ? filteredSubjects.first['id'].toString()
                                : null),
                      decoration: const InputDecoration(
                        labelText: 'SUBJECT',
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      items: filteredSubjects.map((sub) {
                        return DropdownMenuItem<String>(
                          value: sub['id'].toString(),
                          child: Text(
                            sub['name'].toString(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        setModalState(() {
                          selectedSubjectId = val;
                          final found = filteredSubjects.firstWhere(
                            (s) => s['id'].toString() == val,
                            orElse: () => {'name': 'Subject'},
                          );
                          selectedSubjectName = found['name'].toString();

                          // Auto load DepEd weights
                          final templates =
                              found['subject_grading_templates']
                                  as List<dynamic>?;
                          if (templates != null && templates.isNotEmpty) {
                            final tm = templates.first as Map<String, dynamic>;
                            wwWeight =
                                (tm['default_ww_weight'] as num?)?.toDouble() ??
                                20.0;
                            ptWeight =
                                (tm['default_pt_weight'] as num?)?.toDouble() ??
                                50.0;
                            exWeight =
                                (tm['default_ex_weight'] as num?)?.toDouble() ??
                                30.0;
                          } else if (found['default_ww_weight'] != null) {
                            wwWeight = (found['default_ww_weight'] as num)
                                .toDouble();
                            ptWeight = (found['default_pt_weight'] as num)
                                .toDouble();
                            exWeight = (found['default_ex_weight'] as num)
                                .toDouble();
                          }
                          clashErrorMessage = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Day of Week
                    DropdownButtonFormField<String>(
                      value: selectedDay,
                      decoration: const InputDecoration(
                        labelText: 'DAY OF WEEK',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          const [
                                'Monday',
                                'Tuesday',
                                'Wednesday',
                                'Thursday',
                                'Friday',
                                'Saturday',
                              ]
                              .map(
                                (d) =>
                                    DropdownMenuItem(value: d, child: Text(d)),
                              )
                              .toList(),
                      onChanged: (v) => setModalState(() {
                        selectedDay = v!;
                        clashErrorMessage = null;
                      }),
                    ),
                    const SizedBox(height: 16),

                    // Time Row
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: timeSlots.contains(startTime)
                                ? startTime
                                : timeSlots.first,
                            decoration: const InputDecoration(
                              labelText: 'START TIME',
                              border: OutlineInputBorder(),
                            ),
                            items: timeSlots
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setModalState(() {
                              startTime = v!;
                              clashErrorMessage = null;
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: timeSlots.contains(endTime)
                                ? endTime
                                : timeSlots[4],
                            decoration: const InputDecoration(
                              labelText: 'END TIME',
                              border: OutlineInputBorder(),
                            ),
                            items: timeSlots
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setModalState(() {
                              endTime = v!;
                              clashErrorMessage = null;
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Room / Venue
                    TextField(
                      controller: roomCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ROOM / VENUE (OPTIONAL)',
                        hintText: 'e.g., Room 204 or Science Lab',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              if (isEditing)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.catRed),
                  tooltip: 'Delete Schedule Entry',
                  onPressed: isSaving
                      ? null
                      : () async {
                          final confirm = await AppModals.showConfirmDialog(
                            context: ctx,
                            title: 'Delete Schedule Entry',
                            message:
                                'Are you sure you want to remove this schedule for ${schedule.subject} (${schedule.section})?',
                            confirmLabel: 'Delete',
                            confirmColor: AppTheme.catRed,
                          );
                          if (confirm == true) {
                            try {
                              await _repo.deleteSchedule(schedule.id);
                              if (ctx.mounted) Navigator.pop(ctx);
                              await _loadData();
                            } catch (_) {
                              setModalState(() {
                                clashErrorMessage =
                                    'Could not delete this schedule. Please try again.';
                              });
                            }
                          }
                        },
                ),
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              AppButton.primary(
                label: isSaving
                    ? 'Validating...'
                    : (isEditing ? 'Update Entry' : 'Add Entry'),
                onPressed: isSaving
                    ? null
                    : () async {
                        // 1. Validate Weights
                        if (wwWeight + ptWeight + exWeight != 100) {
                          setModalState(() {
                            clashErrorMessage =
                                'Ang kabuuan ng DepEd weights (WW + PT + EX) ay dapat eksaktong 100%.';
                          });
                          return;
                        }

                        // 2. Validate Time order & duration
                        final start24 = ScheduleModel.formatTime12to24(
                          startTime,
                        );
                        final end24 = ScheduleModel.formatTime12to24(endTime);
                        if (start24.compareTo(end24) >= 0) {
                          setModalState(() {
                            clashErrorMessage =
                                'Ang Start Time ay dapat mas maaga kaysa End Time.';
                          });
                          return;
                        }

                        final startMins = _timeToMinutes(startTime);
                        final endMins = _timeToMinutes(endTime);
                        final durationMins = endMins - startMins;

                        if (durationMins < 30) {
                          setModalState(() {
                            clashErrorMessage =
                                'Ang bawat schedule ay dapat hindi bababa sa 30 minuto.';
                          });
                          return;
                        }

                        // RULE 1: Max 3 hours (180 mins) single plot validation
                        if (durationMins > 180) {
                          setModalState(() {
                            clashErrorMessage =
                                'Error: Bawal mag-plot ng lampas 3 oras sa isang tuloy-tuloy na klase ng subject (Maximum 3 hours / 180 mins).';
                          });
                          return;
                        }

                        // RULE 2: Max 8 hours hard block & 6 hours warning validation for teacher daily hours
                        final existingDailyMins = _liveSchedules
                            .where(
                              (s) =>
                                  s.dayOfWeek == selectedDay &&
                                  s.id != schedule?.id,
                            )
                            .fold(
                              0,
                              (sum, s) => sum + s.durationMinutes,
                            );

                        final totalDailyMins =
                            existingDailyMins + durationMins;
                        final totalDailyHours = totalDailyMins / 60.0;

                        if (totalDailyMins > 480) {
                          setModalState(() {
                            clashErrorMessage =
                                'Error: Lalampas sa maximum 8 teaching hours per day ang schedule ni teacher sa $selectedDay (Kabuuan: ${totalDailyHours.toStringAsFixed(1)} hrs). Naka-block para maiwasan ang sobrang pagod ng guro.';
                          });
                          return;
                        }

                        if (totalDailyMins > 360) {
                          final confirmWarning =
                              await AppModals.showConfirmDialog(
                                context: ctx,
                                title: 'High Workload Alert (> 6 Hours)',
                                message:
                                    'Babala: Aabot sa ${totalDailyHours.toStringAsFixed(1)} oras ang kabuuang klase ni teacher sa $selectedDay (higit sa recommended 6 hours/day).\n\nNais mo pa rin bang ituloy ang pag-save ng schedule na ito?',
                                confirmLabel: 'Proceed & Save',
                                confirmColor: Colors.amber.shade800,
                              );
                          if (confirmWarning != true) return;
                        }

                        // 3. Check Live Clash via Repository
                        setModalState(() => isSaving = true);
                        try {
                          final teacherId = _requireTeacherId();
                          final dayIndex = ScheduleModel(
                            id: '',
                            subject: '',
                            section: '',
                            room: '',
                            dayOfWeek: selectedDay,
                            startTime: startTime,
                            endTime: endTime,
                          ).dayOfWeekIndex;

                          final clash = await _repo.validateClash(
                            teacherId: teacherId,
                            sectionId: selectedSectionId,
                            dayOfWeek: dayIndex,
                            startTime24: start24,
                            endTime24: end24,
                            excludeScheduleId: schedule?.id,
                          );

                          if (clash != null) {
                            setModalState(() {
                              clashErrorMessage = clash;
                              isSaving = false;
                            });
                            return;
                          }

                          final newSchedule = ScheduleModel(
                            id: schedule?.id ?? '',
                            subject: selectedSubjectName,
                            section: selectedSectionName,
                            room: roomCtrl.text.trim(),
                            dayOfWeek: selectedDay,
                            startTime: startTime,
                            endTime: endTime,
                            sectionId: selectedSectionId,
                            subjectId: selectedSubjectId,
                            teacherId: teacherId,
                            gradeLevel: selectedGrade,
                            wwWeight: wwWeight,
                            ptWeight: ptWeight,
                            exWeight: exWeight,
                          );

                          if (isEditing) {
                            await _repo.updateSchedule(newSchedule);
                          } else {
                            await _repo.addSchedule(newSchedule);
                          }
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          await _loadData();
                        } catch (e) {
                          setModalState(() {
                            clashErrorMessage =
                                'Unable to validate or save this schedule. Please try again.';
                            isSaving = false;
                          });
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }
}
