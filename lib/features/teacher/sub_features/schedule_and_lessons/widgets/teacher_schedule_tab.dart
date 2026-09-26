import 'package:flutter/material.dart';

import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';

class TeacherScheduleTab extends StatefulWidget {
  final List<ScheduleModel> schedules;
  final List<String> classroomSections;

  const TeacherScheduleTab({
    super.key,
    required this.schedules,
    this.classroomSections = const ['Section A', 'Section B'],
  });

  @override
  State<TeacherScheduleTab> createState() => _TeacherScheduleTabState();
}

class _TeacherScheduleTabState extends State<TeacherScheduleTab> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedSchedules = List<ScheduleModel>.from(widget.schedules);
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

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Class Schedule & Timetable',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage your weekly teaching hours and room assignments.',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              AppButton.primary(
                label: 'Add Schedule Entry',
                icon: Icons.add,
                onPressed: () => _showScheduleEntryDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: sortedSchedules.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final s = sortedSchedules[i];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.12)),
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
                              'Section: ${s.section} • Room: ${s.room}',
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
                                  '${s.dayOfWeek} • ${s.startTime} - ${s.endTime}',
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
                                    'Are you sure you want to remove this entry for ${s.section}?',
                                confirmLabel: 'Delete',
                                confirmColor: AppTheme.catRed,
                              );
                              if (confirm == true) {
                                setState(() {
                                  MockDatabase.instance.deleteSchedule(s.id);
                                });
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
            ),
          ),
        ],
      ),
    );
  }

  void _showScheduleEntryDialog(
    BuildContext context, {
    ScheduleModel? schedule,
  }) {
    final isEditing = schedule != null;
    final subjectCtrl = TextEditingController(
      text: schedule?.subject ?? 'General Mathematics',
    );
    final roomCtrl = TextEditingController(text: schedule?.room ?? '');
    final startCtrl = TextEditingController(text: schedule?.startTime ?? '');
    final endCtrl = TextEditingController(text: schedule?.endTime ?? '');
    String selectedSection = schedule?.section ?? widget.classroomSections.first;
    String selectedDay = schedule?.dayOfWeek ?? 'Monday';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(isEditing ? 'Edit Schedule Entry' : 'Add Schedule Entry'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 450,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: subjectCtrl,
                    decoration: const InputDecoration(
                      labelText: 'SUBJECT',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedSection,
                    decoration: const InputDecoration(
                      labelText: 'SECTION',
                      border: OutlineInputBorder(),
                    ),
                    items: widget.classroomSections
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setModalState(() => selectedSection = v!),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: roomCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ROOM / VENUE',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedDay,
                    decoration: const InputDecoration(
                      labelText: 'DAY OF WEEK',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      'Monday',
                      'Tuesday',
                      'Wednesday',
                      'Thursday',
                      'Friday',
                      'Saturday',
                    ]
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (v) => setModalState(() => selectedDay = v!),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: startCtrl,
                          decoration: const InputDecoration(
                            labelText: 'START TIME',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: endCtrl,
                          decoration: const InputDecoration(
                            labelText: 'END TIME',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            AppButton.primary(
              label: isEditing ? 'Update Entry' : 'Add Entry',
              onPressed: () {
                final newSchedule = ScheduleModel(
                  id: schedule?.id ??
                      'sch_${DateTime.now().millisecondsSinceEpoch}',
                  subject: subjectCtrl.text.trim(),
                  section: selectedSection,
                  room: roomCtrl.text.trim(),
                  dayOfWeek: selectedDay,
                  startTime: startCtrl.text.trim(),
                  endTime: endCtrl.text.trim(),
                );
                setState(() {
                  if (isEditing) {
                    MockDatabase.instance.updateSchedule(newSchedule);
                  } else {
                    MockDatabase.instance.addSchedule(newSchedule);
                  }
                });
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}
