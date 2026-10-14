import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/data/repositories/schedule_repository.dart';
import 'package:class_realm/data/datasources/local/app_database.dart';

class SupabaseScheduleRepository implements ScheduleRepository {
  final SupabaseClient _client;

  SupabaseScheduleRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static final SupabaseScheduleRepository instance =
      SupabaseScheduleRepository();

  /// Fetch all sections (distinct sections extracted from subject_offerings for this teacher)
  Future<List<Map<String, dynamic>>> getSections({int? gradeLevel, String? teacherId}) async {
    // 1. Fast Drift SQLite check (0ms load)
    if (teacherId != null && teacherId.isNotEmpty) {
      try {
        final localOfferings = await AppDatabase.instance.getOfferingsForTeacher(teacherId);
        if (localOfferings.isNotEmpty) {
          final Map<String, Map<String, dynamic>> distinctSections = {};
          for (final row in localOfferings) {
            if (gradeLevel != null && row.gradeLevel != gradeLevel) continue;
            final name = row.sectionName;
            final grade = row.gradeLevel;
            final key = '${grade}_$name';
            if (name.isNotEmpty && !distinctSections.containsKey(key)) {
              distinctSections[key] = {
                'id': row.sectionId,
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
      } catch (_) {}
    }

    try {
      var query = _client.from('subject_offerings').select('''
        id, teacher_id,
        sections!inner ( id, section_name, grade_level )
      ''');
      if (teacherId != null) {
        query = query.eq('teacher_id', teacherId);
      }
      if (gradeLevel != null) {
        query = query.eq('sections.grade_level', gradeLevel);
      }
      
      final response = await query;
      final Map<String, Map<String, dynamic>> distinctSections = {};
      for (final row in response) {
        final sec = row['sections'] as Map<String, dynamic>? ?? {};
        final name = sec['section_name']?.toString() ?? '';
        final grade = sec['grade_level'] ?? 11;
        final key = '${grade}_$name';
        if (name.isNotEmpty && !distinctSections.containsKey(key)) {
          distinctSections[key] = {
            'id': sec['id']?.toString() ?? name,
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
    } catch (_) {
      return [];
    }
  }

  /// Fetch all DepEd subjects for this teacher
  Future<List<Map<String, dynamic>>> getSubjects({int? gradeLevel, String? teacherId}) async {
    // 1. Fast Drift SQLite check (0ms load)
    if (teacherId != null && teacherId.isNotEmpty) {
      try {
        final localOfferings = await AppDatabase.instance.getOfferingsForTeacher(teacherId);
        if (localOfferings.isNotEmpty) {
          final results = <Map<String, dynamic>>[];
          for (final row in localOfferings) {
            if (gradeLevel != null && row.gradeLevel != gradeLevel) continue;
            results.add({
              'id': row.id,
              'subject_id': row.subjectId,
              'subject_name': row.subjectName,
              'name': row.subjectName,
              'grade_level': row.gradeLevel,
              'section_name': row.sectionName,
              'ww_weight': row.wwWeight,
              'pt_weight': row.ptWeight,
              'ex_weight': row.exWeight,
            });
          }
          if (results.isNotEmpty) return results;
        }
      } catch (_) {}
    }

    try {
      var query = _client.from('subject_offerings').select('''
        id, teacher_id, ww_weight, pt_weight, ex_weight,
        subjects!inner ( id, subject_name, grade_level ),
        sections!inner ( id, section_name, grade_level )
      ''');
      if (teacherId != null) {
        query = query.eq('teacher_id', teacherId);
      }
      if (gradeLevel != null) {
        query = query.eq('subjects.grade_level', gradeLevel);
      }
      final response = await query;
      return (response as List).map<Map<String, dynamic>>((row) {
        final sub = row['subjects'] as Map<String, dynamic>? ?? {};
        final sec = row['sections'] as Map<String, dynamic>? ?? {};
        return {
          'id': row['id']?.toString() ?? '',
          'subject_id': sub['id']?.toString() ?? '',
          'subject_name': sub['subject_name']?.toString() ?? 'Subject',
          'name': sub['subject_name']?.toString() ?? 'Subject',
          'grade_level': sub['grade_level'] ?? 11,
          'section_name': sec['section_name']?.toString() ?? 'Section',
          'ww_weight': row['ww_weight'] ?? 20.0,
          'pt_weight': row['pt_weight'] ?? 50.0,
          'ex_weight': row['ex_weight'] ?? 30.0,
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Get schedules for a teacher or section with full details
  @override
  Future<List<ScheduleModel>> getSchedules({
    String? teacherId,
    String? section,
  }) async {
    try {
      var query = _client.from('teacher_schedule').select('''
        id, day_of_week, start_time, end_time, room, is_active,
        subject_offerings!inner (
          id, teacher_id, ww_weight, pt_weight, ex_weight,
          subjects ( id, subject_name, grade_level ),
          sections ( id, section_name, grade_level )
        )
      ''');

      if (teacherId != null && teacherId.isNotEmpty) {
        query = query.eq('subject_offerings.teacher_id', teacherId);
      }

      final response = await query.order('day_of_week').order('start_time');
      final list = <ScheduleModel>[];

      for (final row in response) {
        final offering = row['subject_offerings'] as Map<String, dynamic>? ?? {};
        final sub = offering['subjects'] as Map<String, dynamic>? ?? {};
        final sec = offering['sections'] as Map<String, dynamic>? ?? {};

        final subName = sub['subject_name']?.toString() ?? 'Subject';
        final secName = sec['section_name']?.toString() ?? 'Section';
        
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
            sectionId: sec['id']?.toString() ?? secName,
            subjectId: sub['id']?.toString(),
            teacherId: offering['teacher_id']?.toString(),
            gradeLevel: sub['grade_level'] is int
                ? sub['grade_level'] as int
                : null,
            wwWeight: (offering['ww_weight'] as num?)?.toDouble() ?? 20.0,
            ptWeight: (offering['pt_weight'] as num?)?.toDouble() ?? 50.0,
            exWeight: (offering['ex_weight'] as num?)?.toDouble() ?? 30.0,
          ),
        );
      }

      return list;
    } catch (_) {
      return [];
    }
  }

  /// Comprehensive clash detection
  Future<String?> validateClash({
    required String teacherId,
    required String sectionId,
    required int dayOfWeek,
    required String startTime24,
    required String endTime24,
    String? excludeScheduleId,
    String? offeringId,
  }) async {
    try {
      // 1. Check Teacher Clash
      var teacherQuery = _client
          .from('teacher_schedule')
          .select('''
            id, start_time, end_time,
            subject_offerings!inner (
              id, teacher_id,
              subjects ( subject_name ),
              sections ( section_name )
            )
          ''')
          .eq('subject_offerings.teacher_id', teacherId)
          .eq('day_of_week', dayOfWeek)
          .lt('start_time', endTime24)
          .gt('end_time', startTime24);

      if (excludeScheduleId != null && excludeScheduleId.isNotEmpty) {
        teacherQuery = teacherQuery.neq('id', excludeScheduleId);
      }

      final teacherClashes = await teacherQuery;
      for (final clash in teacherClashes) {
        final offering = clash['subject_offerings'] as Map<String, dynamic>? ?? {};
        final sub = offering['subjects'] as Map<String, dynamic>? ?? {};
        final sec = offering['sections'] as Map<String, dynamic>? ?? {};
        final subName = sub['subject_name'] ?? 'Class';
        final secName = sec['section_name'] ?? 'Section';
        final st = ScheduleModel.formatTime24to12(clash['start_time']);
        final et = ScheduleModel.formatTime24to12(clash['end_time']);
        return 'Teacher Conflict: You already have a schedule ($subName - $secName) at $st - $et.';
      }

      // 2. Check Section Clash if offeringId or sectionId is provided
      final targetOfferingId = (offeringId != null && offeringId.isNotEmpty) ? offeringId : sectionId;
      if (targetOfferingId.isNotEmpty) {
        final offRes = await _client
            .from('subject_offerings')
            .select('section_id')
            .eq('id', targetOfferingId)
            .maybeSingle();

        final sId = offRes?['section_id']?.toString() ?? sectionId;
        if (sId.isNotEmpty) {
          var secQuery = _client
              .from('teacher_schedule')
              .select('''
                id, start_time, end_time,
                subject_offerings!inner (
                  id, section_id,
                  subjects ( subject_name )
                )
              ''')
              .eq('subject_offerings.section_id', sId)
              .eq('day_of_week', dayOfWeek)
              .lt('start_time', endTime24)
              .gt('end_time', startTime24);

          if (excludeScheduleId != null && excludeScheduleId.isNotEmpty) {
            secQuery = secQuery.neq('id', excludeScheduleId);
          }

          final secClashes = await secQuery;
          for (final clash in secClashes) {
            final offering = clash['subject_offerings'] as Map<String, dynamic>? ?? {};
            final sub = offering['subjects'] as Map<String, dynamic>? ?? {};
            final subName = sub['subject_name'] ?? 'Class';
            final st = ScheduleModel.formatTime24to12(clash['start_time']);
            final et = ScheduleModel.formatTime24to12(clash['end_time']);
            return 'Section Conflict: The selected section already has a class ($subName) at $st - $et.';
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error validating schedule clash: $e');
      return null;
    }
  }

  /// Add new schedule to Supabase
  @override
  Future<void> addSchedule(ScheduleModel schedule) async {
    final startTime24 = ScheduleModel.formatTime12to24(schedule.startTime);
    final endTime24 = ScheduleModel.formatTime12to24(schedule.endTime);

    await _client
        .from('teacher_schedule')
        .insert({
          'subject_offering_id': schedule.subjectId,
          'day_of_week': schedule.dayOfWeekIndex,
          'start_time': startTime24,
          'end_time': endTime24,
          'room': schedule.room,
          'is_active': true,
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

    if (schedule.subjectId != null && schedule.subjectId!.isNotEmpty) {
      updateData['subject_offering_id'] = schedule.subjectId;
    }

    await _client.from('teacher_schedule').update(updateData).eq('id', schedule.id);
  }

  /// Delete schedule from Supabase
  @override
  Future<void> deleteSchedule(String id) async {
    await _client.from('teacher_schedule').delete().eq('id', id);
  }
}
