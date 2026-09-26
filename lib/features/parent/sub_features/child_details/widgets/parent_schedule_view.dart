import 'package:flutter/material.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/models/academic_models.dart';

class ParentScheduleView extends StatelessWidget {
  final UserModel? linkedStudent;

  const ParentScheduleView({super.key, required this.linkedStudent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final schedules = linkedStudent == null
        ? <ScheduleModel>[]
        : MockDatabase.instance.scheduleForSection(
            linkedStudent!.departmentOrSection ?? '',
          );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Schedule'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: Container(
        color: theme.scaffoldBackgroundColor,
        child: linkedStudent == null
            ? const Center(child: Text('No linked student found.'))
            : schedules.isEmpty
            ? const Center(child: Text('No schedule records found.'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: schedules.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final item = schedules[index];
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.schedule_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(
                        item.subject,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${item.dayOfWeek} • ${item.room}',
                      ),
                      trailing: Text(
                        '${item.startTime}\n${item.endTime}',
                        textAlign: TextAlign.end,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
