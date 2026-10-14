import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' show Value;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/data/datasources/local/app_database.dart';
import 'package:class_realm/data/mock_database.dart';
import 'package:class_realm/models/user_model.dart';

class SubjectRepository {
  final SupabaseClient _client;

  SubjectRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  static final SubjectRepository instance = SubjectRepository();

  /// Saves a subject along with multiple sections into the database.
  Future<void> saveSubjects({
    required String teacherId,
    required String subjectName,
    required String gradeLevel,
    required double wwWeight,
    required double ptWeight,
    required double exWeight,
    required List<String> sectionNames,
    String schoolYear = '2026-2027',
  }) async {
    int gLevel = 11;
    if (gradeLevel.contains('12')) {
      gLevel = 12;
    }

    // 1. Get or create current school_year
    final syRes = await _client
        .from('school_years')
        .select('id')
        .eq('school_year', schoolYear)
        .maybeSingle();
    final schoolYearId = syRes?['id'] ?? '232f3169-2880-4703-b8c6-4167a13cf148';

    // 2. Get active or first term
    final termRes = await _client
        .from('terms')
        .select('id')
        .eq('school_year_id', schoolYearId)
        .order('term_number')
        .limit(1)
        .maybeSingle();
    final termId = termRes?['id'] ?? '1a66dbf9-7395-42df-960f-4e22c07e20d4';

    // 3. Find or insert subject in `subjects`
    final cleanSubjectName = subjectName.trim();
    final existingSubject = await _client
        .from('subjects')
        .select('id')
        .eq('subject_name', cleanSubjectName)
        .eq('grade_level', gLevel)
        .maybeSingle();

    String subjectId;
    if (existingSubject != null) {
      subjectId = existingSubject['id'].toString();
    } else {
      final words = cleanSubjectName.split(' ').where((w) => w.isNotEmpty).toList();
      final codePrefix = words.map((w) => w[0].toUpperCase()).join();
      final randomSuffix = (DateTime.now().millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
      final code = '${codePrefix.length > 1 ? codePrefix : "SUB"}_G${gLevel}_$randomSuffix';

      final insSub = await _client.from('subjects').insert({
        'subject_code': code,
        'subject_name': cleanSubjectName,
        'grade_level': gLevel,
        'is_archived': false,
      }).select('id').single();
      subjectId = insSub['id'].toString();
    }

    // 4. For each section, find or insert section, then insert subject_offering
    for (final secName in sectionNames) {
      final cleanSecName = secName.trim();
      if (cleanSecName.isEmpty) continue;

      final existingSec = await _client
          .from('sections')
          .select('id')
          .eq('section_name', cleanSecName)
          .eq('grade_level', gLevel)
          .eq('school_year_id', schoolYearId)
          .maybeSingle();

      String sectionId;
      if (existingSec != null) {
        sectionId = existingSec['id'].toString();
      } else {
        final insSec = await _client.from('sections').insert({
          'section_name': cleanSecName,
          'grade_level': gLevel,
          'school_year_id': schoolYearId,
          'is_archived': false,
        }).select('id').single();
        sectionId = insSec['id'].toString();
      }

      // Check if offering already exists
      final existingOffering = await _client
          .from('subject_offerings')
          .select('id')
          .eq('subject_id', subjectId)
          .eq('section_id', sectionId)
          .eq('teacher_id', teacherId)
          .maybeSingle();

      if (existingOffering == null) {
        await _client.from('subject_offerings').insert({
          'subject_id': subjectId,
          'section_id': sectionId,
          'teacher_id': teacherId,
          'term_id': termId,
          'ww_weight': wwWeight,
          'pt_weight': ptWeight,
          'ex_weight': exWeight,
          'is_archived': false,
        });
      }
    }
  }

  /// Synchronously returns cached teacher subjects from local storage or mock fallback.
  List<Map<String, dynamic>> getCachedTeacherSubjects(String teacherId) {
    final cached = LocalStorageService.getTeacherSubjects(teacherId);
    if (cached.isNotEmpty) {
      return cached;
    }

    // Secondary fallback: reconstruct from MockDatabase so offline teachers still see layout
    final mockDb = MockDatabase.instance;
    final List<Map<String, dynamic>> mockOfferings = [];
    if (mockDb.currentSubject.isNotEmpty && mockDb.sections.isNotEmpty) {
      for (int i = 0; i < mockDb.sections.length; i++) {
        final sec = mockDb.sections[i];
        mockOfferings.add({
          'id': 'offering_mock_${sec.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}',
          'subject_id': 'sub_mock_1',
          'subject_name': mockDb.currentSubject,
          'grade_level': mockDb.gradeLevel.contains('12') ? 12 : 11,
          'section_id': 'sec_mock_$i',
          'section_name': sec,
          'ww_weight': 20.0,
          'pt_weight': 50.0,
          'ex_weight': 30.0,
          'school_year': '2026-2027',
        });
      }
    }

    if (mockOfferings.isEmpty) {
      final studentSections = mockDb.users
          .where((u) => u.role == UserRole.student && u.departmentOrSection != null && u.departmentOrSection!.isNotEmpty)
          .map((u) => u.departmentOrSection!)
          .toSet()
          .toList();
      for (int i = 0; i < studentSections.length; i++) {
        final sec = studentSections[i];
        mockOfferings.add({
          'id': 'offering_auto_${sec.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}',
          'subject_id': 'sub_auto_1',
          'subject_name': 'Core Academic Subject',
          'grade_level': 11,
          'section_id': 'sec_auto_$i',
          'section_name': sec,
          'ww_weight': 20.0,
          'pt_weight': 50.0,
          'ex_weight': 30.0,
          'school_year': '2026-2027',
        });
      }
    }

    return mockOfferings;
  }

  /// Fetches all subjects for a specific teacher with Drift SQLite cache-first (0ms) and background sync.
  Future<List<Map<String, dynamic>>> getTeacherSubjects(
    String teacherId, {
    String schoolYear = '2026-2027',
  }) async {
    // 1. FAST LOCAL DRIFT SQLITE READ (0 milliseconds load)
    try {
      final localOfferings = await AppDatabase.instance.getOfferingsForTeacher(teacherId);
      if (localOfferings.isNotEmpty) {
        // Trigger silent background sync without blocking UI
        unawaited(_syncOfferingsFromCloud(teacherId, schoolYear));

        return localOfferings.map((r) => {
          'id': r.id,
          'subject_id': r.subjectId,
          'subject_name': r.subjectName,
          'grade_level': r.gradeLevel,
          'section_id': r.sectionId,
          'section_name': r.sectionName,
          'ww_weight': r.wwWeight,
          'pt_weight': r.ptWeight,
          'ex_weight': r.exWeight,
          'school_year': r.schoolYear,
        }).toList();
      }
    } catch (e) {
      debugPrint('Drift local read notice: $e');
    }

    // 2. Fallback / Initial fetch from cloud
    return _syncOfferingsFromCloud(teacherId, schoolYear);
  }

  Future<List<Map<String, dynamic>>> _syncOfferingsFromCloud(
    String teacherId,
    String schoolYear,
  ) async {
    try {
      final response = await _client
          .from('subject_offerings')
          .select('''
            id,
            ww_weight,
            pt_weight,
            ex_weight,
            subjects ( id, subject_name, grade_level ),
            sections ( id, section_name, grade_level )
          ''')
          .eq('teacher_id', teacherId)
          .eq('is_archived', false);

      if (response == null || (response as List).isEmpty) {
        return getCachedTeacherSubjects(teacherId);
      }

      final mapped = (response as List).map<Map<String, dynamic>>((row) {
        final sub = row['subjects'] as Map<String, dynamic>? ?? {};
        final sec = row['sections'] as Map<String, dynamic>? ?? {};
        return {
          'id': row['id']?.toString() ?? '',
          'subject_id': sub['id']?.toString() ?? '',
          'subject_name': sub['subject_name']?.toString() ?? 'Subject',
          'grade_level': sub['grade_level'] ?? sec['grade_level'] ?? 11,
          'section_id': sec['id']?.toString() ?? '',
          'section_name': sec['section_name']?.toString() ?? 'Section',
          'ww_weight': (row['ww_weight'] as num?)?.toDouble() ?? 20.0,
          'pt_weight': (row['pt_weight'] as num?)?.toDouble() ?? 50.0,
          'ex_weight': (row['ex_weight'] as num?)?.toDouble() ?? 30.0,
          'school_year': schoolYear,
        };
      }).toList();

      // Persist into Drift SQLite safely without blocking data return on web
      try {
        final companions = mapped.map((m) => LocalSubjectOfferingsCompanion.insert(
          id: m['id'],
          teacherId: teacherId,
          subjectId: m['subject_id'],
          sectionId: m['section_id'],
          subjectName: m['subject_name'],
          sectionName: m['section_name'],
          gradeLevel: m['grade_level'],
          wwWeight: Value(m['ww_weight']),
          ptWeight: Value(m['pt_weight']),
          exWeight: Value(m['ex_weight']),
          schoolYear: Value(schoolYear),
        )).toList();
        await AppDatabase.instance.upsertOfferings(companions);
      } catch (dbErr) {
        debugPrint('Drift local save notice on web: $dbErr');
      }

      // Also persist to secondary local storage
      try {
        await LocalStorageService.saveTeacherSubjects(teacherId, mapped);
      } catch (lsErr) {
        debugPrint('LocalStorage save notice: $lsErr');
      }
      return mapped;
    } catch (e) {
      debugPrint('Error syncing teacher subjects from cloud: $e');
      return getCachedTeacherSubjects(teacherId);
    }
  }

  /// Fetches archived subjects for a specific teacher.
  Future<List<Map<String, dynamic>>> getTeacherArchivedSubjects(
    String teacherId, {
    String schoolYear = '2026-2027',
  }) async {
    try {
      final response = await _client
          .from('subject_offerings')
          .select('''
            id,
            ww_weight,
            pt_weight,
            ex_weight,
            subjects ( id, subject_name, grade_level ),
            sections ( id, section_name, grade_level )
          ''')
          .eq('teacher_id', teacherId)
          .eq('is_archived', true);

      if (response == null || (response as List).isEmpty) {
        return [];
      }

      return (response as List).map<Map<String, dynamic>>((row) {
        final sub = row['subjects'] as Map<String, dynamic>? ?? {};
        final sec = row['sections'] as Map<String, dynamic>? ?? {};
        return {
          'id': row['id']?.toString() ?? '',
          'subject_id': sub['id']?.toString() ?? '',
          'subject_name': sub['subject_name']?.toString() ?? 'Subject',
          'grade_level': sub['grade_level'] ?? sec['grade_level'] ?? 11,
          'section_id': sec['id']?.toString() ?? '',
          'section_name': sec['section_name']?.toString() ?? 'Section',
          'ww_weight': row['ww_weight'] ?? 20.0,
          'pt_weight': row['pt_weight'] ?? 50.0,
          'ex_weight': row['ex_weight'] ?? 30.0,
          'school_year': schoolYear,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting teacher archived subjects: $e');
      return [];
    }
  }

  /// Archives all subject offerings for a teacher and subject
  Future<void> archiveSubjectOffering({
    required String teacherId,
    required String subjectId,
  }) async {
    await _client
        .from('subject_offerings')
        .update({'is_archived': true})
        .eq('teacher_id', teacherId)
        .eq('subject_id', subjectId);
  }

  /// Restores all subject offerings for a teacher and subject
  Future<void> restoreSubjectOffering({
    required String teacherId,
    required String subjectId,
  }) async {
    await _client
        .from('subject_offerings')
        .update({'is_archived': false})
        .eq('teacher_id', teacherId)
        .eq('subject_id', subjectId);
  }

  /// Permanently deletes subject offerings for a teacher and subject.
  /// Note: Students remain unaffected in the system.
  Future<void> deleteSubjectOffering({
    required String teacherId,
    required String subjectId,
  }) async {
    await _client
        .from('subject_offerings')
        .delete()
        .eq('teacher_id', teacherId)
        .eq('subject_id', subjectId);
  }
}
