import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/data/repositories/schedule_repository.dart';

class SupabaseScheduleRepository implements ScheduleRepository {
  final SupabaseClient _client;

  SupabaseScheduleRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static final SupabaseScheduleRepository instance =
      SupabaseScheduleRepository();

  /// Fetch all sections (distinct sections extracted from subjects for this teacher)
  Future<List<Map<String, dynamic>>> getSections({int? gradeLevel, String? teacherId}) async {
    var query = _client.from('subjects').select('section_name, grade_level');
    if (gradeLevel != null) {
      query = query.eq('grade_level', gradeLevel);
    }
    if (teacherId != null) {
      query = query.eq('teacher_id', teacherId);
    }
    
    final response = await query;
    final Map<String, Map<String, dynamic>> distinctSections = {};
    for (final row in response) {
      final name = row['section_name']?.toString() ?? '';
      final grade = row['grade_level'] ?? 11;
      final key = '${grade}_$name';
      if (!distinctSections.containsKey(key)) {
        distinctSections[key] = {
          'id': name, // Using section_name as ID
          'name': name,
          'grade_level': grade,
        };
      }
    }
    
    final list = distinctSections.values.toList();
    list.sort((a, b) {
      final g = (a['grade_level'] as int).compareTo(b['grade_level'] as int);
      if (g != 0) return g;
      return (a['name'] as String).compareTo(b['name'] as String);
    });
    return list;
  }

  /// Fetch all DepEd subjects for this teacher
  Future<List<Map<String, dynamic>>> getSubjects({int? gradeLevel, String? teacherId}) async {
    var query = _client.from('subjects').select('''
        id, subject_name, grade_level, section_name, ww_weight, pt_weight, ex_weight
      ''');
    if (gradeLevel != null) {
      query = query.eq('grade_level', gradeLevel);
    }
    if (teacherId != null) {
      query = query.eq('teacher_id', teacherId);
    }
    final response = await query.order('grade_level').order('subject_name');
    return response.map((row) {
      return {
        ...row,
        'name': row['subject_name'], // map to 'name' for UI dropdown
      };
    }).toList();
  }

  /// Get schedules for a teacher or section with full details
  @override
  Future<List<ScheduleModel>> getSchedules({
    String? teacherId,
    String? section,
  }) async {
    var query = _client.from('teacher_schedule').select('''
        id, teacher_id, subject_id, day_of_week, start_time, end_time, room,
        subjects (id, subject_name, section_name, grade_level, ww_weight, pt_weight, ex_weight)
      ''');

    if (teacherId != null && teacherId.isNotEmpty) {
      query = query.eq('teacher_id', teacherId);
    }

    final response = await query.order('day_of_week').order('start_time');
    final list = <ScheduleModel>[];

    for (final row in response) {
      final subMap = row['subjects'] as Map<String, dynamic>?;

      final subName = subMap?['subject_name']?.toString() ?? 'Subject';
      final secName = subMap?['section_name']?.toString() ?? 'Section';
      
      if (section != null && section.isNotEmpty && secName != section) {
        continue;
      }

      final dayIndex = row['day_of_week'] is int
          ? row['day_of_week'] as int
          : int.tryParse(row['day_of_week']?.toString() ?? '1') ?? 1;

      list.add(
        ScheduleModel(
          id: row['id'].toString(),
          subject: subName,
          section: secName,
          room: row['room']?.toString() ?? '',
          dayOfWeek: ScheduleModel.dayFromIndex(dayIndex),
          startTime: ScheduleModel.formatTime24to12(
            row['start_time']?.toString() ?? '08:00:00',
          ),
          endTime: ScheduleModel.formatTime24to12(
            row['end_time']?.toString() ?? '09:00:00',
          ),
          sectionId: secName, // Using section name as ID
          subjectId: row['subject_id']?.toString(),
          teacherId: row['teacher_id']?.toString(),
          gradeLevel: subMap?['grade_level'] is int
              ? subMap!['grade_level'] as int
              : null,
          wwWeight: subMap?['ww_weight'] != null
              ? (subMap!['ww_weight'] as num).toDouble()
              : 20.0,
          ptWeight: subMap?['pt_weight'] != null
              ? (subMap!['pt_weight'] as num).toDouble()
              : 50.0,
          exWeight: subMap?['ex_weight'] != null
              ? (subMap!['ex_weight'] as num).toDouble()
              : 30.0,
        ),
      );
    }

    return list;
  }

  /// Comprehensive clash detection
  Future<String?> validateClash({
    required String teacherId,
    required String sectionId,
    required int dayOfWeek,
    required String startTime24,
    required String endTime24,
    String? excludeScheduleId,
  }) async {
    // 1. Check Teacher Clash
    final teacherClashes = await _client
        .from('teacher_schedule')
        .select('id, start_time, end_time, subjects(subject_name)')
        .eq('teacher_id', teacherId)
        .eq('day_of_week', dayOfWeek)
        .lt('start_time', endTime24)
        .gt('end_time', startTime24);

    for (final clash in teacherClashes) {
      if (excludeScheduleId != null && clash['id'] == excludeScheduleId) {
        continue;
      }
      final subName =
          (clash['subjects'] as Map<String, dynamic>?)?['subject_name'] ?? 'Class';
      final st = ScheduleModel.formatTime24to12(clash['start_time']);
      final et = ScheduleModel.formatTime24to12(clash['end_time']);
      return 'Teacher Clash: Meron ka nang schedule ($subName) sa oras na $st - $et.';
    }

    // 2. Check Section Clash (inferred from subject's section)
    final sectionClashes = await _client
        .from('teacher_schedule')
        .select('id, start_time, end_time, subjects(subject_name, section_name)')
        .eq('day_of_week', dayOfWeek)
        .lt('start_time', endTime24)
        .gt('end_time', startTime24);

    for (final clash in sectionClashes) {
      if (excludeScheduleId != null && clash['id'] == excludeScheduleId) {
        continue;
      }
      final subMap = clash['subjects'] as Map<String, dynamic>?;
      if (subMap?['section_name'] == sectionId) {
        final subName = subMap?['subject_name'] ?? 'Class';
        final st = ScheduleModel.formatTime24to12(clash['start_time']);
        final et = ScheduleModel.formatTime24to12(clash['end_time']);
        return 'Section Clash: Ang napiling section ay may klase na ($subName) sa oras na $st - $et.';
      }
    }

    return null;
  }

  /// Add new schedule to Supabase
  @override
  Future<void> addSchedule(ScheduleModel schedule) async {
    final startTime24 = ScheduleModel.formatTime12to24(schedule.startTime);
    final endTime24 = ScheduleModel.formatTime12to24(schedule.endTime);

    await _client
        .from('teacher_schedule')
        .insert({
          'teacher_id': schedule.teacherId,
          'subject_id': schedule.subjectId,
          'day_of_week': schedule.dayOfWeekIndex,
          'start_time': startTime24,
          'end_time': endTime24,
          'room': schedule.room,
        });
  }

  /// Update schedule in Supabase
  @override
  Future<void> updateSchedule(ScheduleModel schedule) async {
    final startTime24 = ScheduleModel.formatTime12to24(schedule.startTime);
    final endTime24 = ScheduleModel.formatTime12to24(schedule.endTime);

    final updateData = <String, dynamic>{
      'day_of_week': schedule.dayOfWeekIndex,
      'start_time': startTime24,
      'end_time': endTime24,
      'room': schedule.room,
    };

    if (schedule.subjectId != null) {
      updateData['subject_id'] = schedule.subjectId;
    }

    await _client.from('teacher_schedule').update(updateData).eq('id', schedule.id);
  }

  /// Delete schedule from Supabase
  @override
  Future<void> deleteSchedule(String id) async {
    await _client.from('teacher_schedule').delete().eq('id', id);
  }
}
