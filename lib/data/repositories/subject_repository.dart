import 'package:class_realm/core/services/app_data_cache.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' show Value;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/data/datasources/local/app_database.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';

class SubjectRepository {
  final SupabaseClient _client;
  static const Set<String> _termMetadataColumns = {
    'terms_taught',
    'term_block',
    'units_per_term',
    'st1_weight',
    'st2_weight',
    'te_weight',
  };

  SubjectRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static final SubjectRepository instance = SubjectRepository();

  bool _isMissingTermMetadata(PostgrestException error) {
    return error.code == '42703' ||
        error.code == 'PGRST204' ||
        _termMetadataColumns.any(error.message.contains);
  }

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
    int termsTaught = 3,
    String? termBlock,
    double unitsPerTerm = 2,
    double st1Weight = 30,
    double st2Weight = 30,
    double teWeight = 40,
  }) async {
    if (termsTaught < 1 || termsTaught > 3) {
      throw ArgumentError.value(
        termsTaught,
        'termsTaught',
        'Must be 1, 2, or 3.',
      );
    }
    final resolvedTermBlock =
        termBlock ??
        (termsTaught == 3
            ? '1ST, 2ND, 3RD'
            : termsTaught == 1
            ? 'FIRST TERM'
            : '1ST & 2ND');

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
      final words = cleanSubjectName
          .split(' ')
          .where((w) => w.isNotEmpty)
          .toList();
      final codePrefix = words.map((w) => w[0].toUpperCase()).join();
      final randomSuffix = (DateTime.now().millisecondsSinceEpoch % 10000)
          .toString()
          .padLeft(4, '0');
      final code =
          '${codePrefix.length > 1 ? codePrefix : "SUB"}_G${gLevel}_$randomSuffix';

      final insSub = await _client
          .from('subjects')
          .insert({
            'subject_code': code,
            'subject_name': cleanSubjectName,
            'grade_level': gLevel,
            'is_archived': false,
          })
          .select('id')
          .single();
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
        final insSec = await _client
            .from('sections')
            .insert({
              'section_name': cleanSecName,
              'grade_level': gLevel,
              'school_year_id': schoolYearId,
              'is_archived': false,
            })
            .select('id')
            .single();
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

      final offeringData = {
        'subject_id': subjectId,
        'section_id': sectionId,
        'teacher_id': teacherId,
        'term_id': termId,
        'ww_weight': wwWeight,
        'pt_weight': ptWeight,
        'ex_weight': exWeight,
        'terms_taught': termsTaught,
        'term_block': resolvedTermBlock,
        'units_per_term': unitsPerTerm,
        'st1_weight': st1Weight,
        'st2_weight': st2Weight,
        'te_weight': teWeight,
        'is_archived': false,
      };
      if (existingOffering == null) {
        try {
          await _client.from('subject_offerings').insert(offeringData);
        } on PostgrestException catch (error) {
          if (!_isMissingTermMetadata(error)) rethrow;
          final legacyData = Map<String, dynamic>.from(offeringData)
            ..removeWhere((key, _) => _termMetadataColumns.contains(key));
          await _client.from('subject_offerings').insert(legacyData);
        }
      } else {
        try {
          await _client
              .from('subject_offerings')
              .update(offeringData)
              .eq('id', existingOffering['id']);
        } on PostgrestException catch (error) {
          if (!_isMissingTermMetadata(error)) rethrow;
          final legacyData = Map<String, dynamic>.from(offeringData)
            ..removeWhere((key, _) => _termMetadataColumns.contains(key));
          await _client
              .from('subject_offerings')
              .update(legacyData)
              .eq('id', existingOffering['id']);
        }
      }
    }
    AppDataCache.instance.invalidatePrefix('teacher_subjects_$teacherId');
  }

  /// Synchronously returns cached teacher subjects from local storage.
  List<Map<String, dynamic>> getCachedTeacherSubjects(String teacherId) {
    return LocalStorageService.getTeacherSubjects(teacherId);
  }

  /// Fetches all subjects for a specific teacher with Drift SQLite cache-first (0ms) and background sync.
  Future<List<Map<String, dynamic>>> getTeacherSubjects(
    String teacherId, {
    String schoolYear = '2026-2027',
    bool onlyWithEnrolledStudents = false,
  }) async {
    final cacheKey =
        'teacher_subjects_${teacherId}_${schoolYear}_$onlyWithEnrolledStudents';
    final cached = AppDataCache.instance.getCached<List<Map<String, dynamic>>>(
      cacheKey,
      (json) => (json as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
    if (cached != null && AppDataCache.instance.isFresh(cacheKey)) {
      return cached;
    }
    List<Map<String, dynamic>> results;
    // 1. FAST LOCAL DRIFT SQLITE READ (0 milliseconds load)
    try {
      final localOfferings = await AppDatabase.instance.getOfferingsForTeacher(
        teacherId,
      );
      if (localOfferings.isNotEmpty) {
        final cachedMetadata = {
          for (final offering in LocalStorageService.getTeacherSubjects(
            teacherId,
          ))
            offering['id']?.toString() ?? '': offering,
        };
        // Trigger silent background sync without blocking UI
        unawaited(_syncOfferingsFromCloud(teacherId, schoolYear));

        results = localOfferings.map((r) {
          final metadata = cachedMetadata[r.id] ?? const <String, dynamic>{};
          return {
            'id': r.id,
            'subject_id': r.subjectId,
            'subject_name': r.subjectName,
            'grade_level': r.gradeLevel,
            'section_id': r.sectionId,
            'section_name': r.sectionName,
            'ww_weight': r.wwWeight,
            'pt_weight': r.ptWeight,
            'ex_weight': r.exWeight,
            'terms_taught': metadata['terms_taught'] ?? 3,
            'term_block': metadata['term_block'] ?? '1ST, 2ND, 3RD',
            'units_per_term': metadata['units_per_term'] ?? 2.0,
            'st1_weight': metadata['st1_weight'] ?? 30.0,
            'st2_weight': metadata['st2_weight'] ?? 30.0,
            'te_weight': metadata['te_weight'] ?? 40.0,
            'school_year': r.schoolYear,
          };
        }).toList();

        if (onlyWithEnrolledStudents) {
          final filtered = await _filterOfferingsWithEnrolledStudents(
            teacherId,
            results,
          );
          unawaited(AppDataCache.instance.setCache(cacheKey, filtered));
          return filtered;
        }
        return results;
      }
    } catch (e) {
      debugPrint('Drift local read notice: $e');
    }

    // 2. Fallback / Initial fetch from cloud
    results = await _syncOfferingsFromCloud(teacherId, schoolYear);
    if (onlyWithEnrolledStudents) {
      final filtered = await _filterOfferingsWithEnrolledStudents(
        teacherId,
        results,
      );
      unawaited(AppDataCache.instance.setCache(cacheKey, filtered));
      return filtered;
    }
    unawaited(AppDataCache.instance.setCache(cacheKey, results));
    return results;
  }

  Future<List<Map<String, dynamic>>> _filterOfferingsWithEnrolledStudents(
    String teacherId,
    List<Map<String, dynamic>> offerings,
  ) async {
    if (offerings.isEmpty) return [];
    final offeringIds = offerings.map((m) => m['id'].toString()).toList();
    try {
      final enrollmentsResponse = await _client
          .from('student_enrollments')
          .select('subject_offering_id')
          .inFilter('subject_offering_id', offeringIds)
          .ilike('status', 'enrolled');

      final activeOfferingIds = (enrollmentsResponse as List)
          .map((e) => e['subject_offering_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .toSet();

      return offerings
          .where((m) => activeOfferingIds.contains(m['id']))
          .toList();
    } catch (enrollErr) {
      debugPrint('Error filtering offerings by cloud enrollments: $enrollErr');
      try {
        final activeIds = <String>{};
        for (final offering in offerings) {
          final offId = offering['id'].toString();
          final localStudents = await AppDatabase.instance
              .getStudentsForOffering(offId);
          if (localStudents.isNotEmpty) {
            activeIds.add(offId);
          }
        }
        if (activeIds.isNotEmpty) {
          return offerings.where((m) => activeIds.contains(m['id'])).toList();
        }
      } catch (_) {}
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _syncOfferingsFromCloud(
    String teacherId,
    String schoolYear,
  ) async {
    try {
      dynamic response;
      try {
        response = await _client
            .from('subject_offerings')
            .select('''
            id,
            ww_weight,
            pt_weight,
            ex_weight,
            terms_taught,
            term_block,
            units_per_term,
            st1_weight,
            st2_weight,
            te_weight,
            subjects ( id, subject_name, grade_level ),
            sections ( id, section_name, grade_level )
          ''')
            .eq('teacher_id', teacherId)
            .eq('is_archived', false);
      } on PostgrestException catch (error) {
        if (!_isMissingTermMetadata(error)) rethrow;
        debugPrint(
          'Subject term metadata unavailable before migration: $error',
        );
        response = await _client
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
      }

      final rows = response as List;
      if (rows.isEmpty) {
        return getCachedTeacherSubjects(teacherId);
      }

      final mapped = rows.map<Map<String, dynamic>>((row) {
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
          'terms_taught': (row['terms_taught'] as num?)?.toInt() ?? 3,
          'term_block': row['term_block']?.toString() ?? '1ST, 2ND, 3RD',
          'units_per_term': (row['units_per_term'] as num?)?.toDouble() ?? 2.0,
          'st1_weight': (row['st1_weight'] as num?)?.toDouble() ?? 30.0,
          'st2_weight': (row['st2_weight'] as num?)?.toDouble() ?? 30.0,
          'te_weight': (row['te_weight'] as num?)?.toDouble() ?? 40.0,
          'school_year': schoolYear,
        };
      }).toList();

      // Persist into Drift SQLite safely without blocking data return on web
      try {
        final companions = mapped
            .map(
              (m) => LocalSubjectOfferingsCompanion.insert(
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
              ),
            )
            .toList();
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

  Future<void> saveGradebookTermSheet(
    String offeringId,
    int termNumber,
    Map<String, dynamic> payload,
  ) async {
    _validateOfferingTerm(offeringId, termNumber);
    await LocalStorageService.saveGradebookSheet(
      offeringId,
      termNumber,
      payload,
    );

    final teacherId = AuthRepository.instance.currentUser?.id;
    if (teacherId == null || teacherId.isEmpty) {
      debugPrint(
        'Gradebook sheet saved locally; cloud sync deferred without a teacher session.',
      );
      return;
    }
    unawaited(
      _syncGradebookTermSheet(offeringId, termNumber, payload, teacherId),
    );
  }

  Future<Map<String, dynamic>?> getGradebookTermSheet(
    String offeringId,
    int termNumber,
  ) async {
    _validateOfferingTerm(offeringId, termNumber);
    final cached = LocalStorageService.getGradebookSheet(
      offeringId,
      termNumber,
    );
    final teacherId = AuthRepository.instance.currentUser?.id;
    if (cached != null) {
      if (teacherId != null && teacherId.isNotEmpty) {
        unawaited(
          _refreshGradebookTermSheet(offeringId, termNumber, teacherId),
        );
      }
      return cached;
    }
    if (teacherId == null || teacherId.isEmpty) {
      return null;
    }

    try {
      await _verifyOfferingTeacher(offeringId, teacherId);

      final row = await _client
          .from('gradebook_term_sheets')
          .select('hps_json, scores_json')
          .eq('subject_offering_id', offeringId)
          .eq('term_number', termNumber)
          .maybeSingle();
      if (row == null) return null;

      final payload = {
        'hps': Map<String, dynamic>.from(row['hps_json'] as Map? ?? {}),
        'scores': Map<String, dynamic>.from(row['scores_json'] as Map? ?? {}),
      };
      await LocalStorageService.saveGradebookSheet(
        offeringId,
        termNumber,
        payload,
      );
      return payload;
    } catch (e) {
      debugPrint('Notice loading gradebook sheet from cloud: $e');
      return null;
    }
  }

  Future<void> _syncGradebookTermSheet(
    String offeringId,
    int termNumber,
    Map<String, dynamic> payload,
    String teacherId,
  ) async {
    try {
      await _verifyOfferingTeacher(offeringId, teacherId);
      final hps =
          payload['hps_json'] ?? payload['hps'] ?? const <String, dynamic>{};
      final scores =
          payload['scores_json'] ??
          payload['scores'] ??
          const <String, dynamic>{};
      if (hps is! Map || scores is! Map) {
        throw const FormatException(
          'Gradebook HPS and scores must be JSON objects.',
        );
      }

      await _client.from('gradebook_term_sheets').upsert({
        'subject_offering_id': offeringId,
        'term_number': termNumber,
        'hps_json': Map<String, dynamic>.from(hps),
        'scores_json': Map<String, dynamic>.from(scores),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'subject_offering_id,term_number');

      final rows = payload['term_grades'];
      if (rows is List && rows.isNotEmpty) {
        final termGrades = rows.map<Map<String, dynamic>>((value) {
          if (value is! Map) {
            throw const FormatException(
              'Each term grade must be a JSON object.',
            );
          }
          final grade = Map<String, dynamic>.from(value)
            ..['subject_offering_id'] = offeringId
            ..['term_number'] = termNumber;
          if (grade['remarks'] == 'PASSED') {
            grade['remarks'] = 'Passed';
          } else if (grade['remarks'] == 'FAILED') {
            grade['remarks'] = 'Failed';
          }
          return grade;
        }).toList();
        await _client
            .from('term_grades')
            .upsert(
              termGrades,
              onConflict: 'student_id,subject_offering_id,term_number',
            );
      }
    } catch (error) {
      debugPrint(
        'Gradebook cloud sync failed for teacher $teacherId, offering $offeringId, term $termNumber: $error',
      );
    }
  }

  Future<void> _refreshGradebookTermSheet(
    String offeringId,
    int termNumber,
    String teacherId,
  ) async {
    try {
      await _verifyOfferingTeacher(offeringId, teacherId);
      final row = await _client
          .from('gradebook_term_sheets')
          .select('hps_json, scores_json')
          .eq('subject_offering_id', offeringId)
          .eq('term_number', termNumber)
          .maybeSingle();
      if (row == null) return;
      await LocalStorageService.saveGradebookSheet(offeringId, termNumber, {
        'hps': Map<String, dynamic>.from(row['hps_json'] as Map),
        'scores': Map<String, dynamic>.from(row['scores_json'] as Map),
      });
    } catch (error) {
      debugPrint(
        'Gradebook background refresh failed for offering $offeringId, term $termNumber: $error',
      );
    }
  }

  Future<void> _verifyOfferingTeacher(
    String offeringId,
    String teacherId,
  ) async {
    try {
      final offering = await _client
          .from('subject_offerings')
          .select('id')
          .eq('id', offeringId)
          .eq('teacher_id', teacherId)
          .maybeSingle();
      if (offering == null) {
        debugPrint(
          'Notice: Offering $offeringId was not found for teacher $teacherId in cloud.',
        );
      }
    } catch (e) {
      debugPrint('Notice verifying offering teacher: $e');
    }
  }

  void _validateOfferingTerm(String offeringId, int termNumber) {
    if (offeringId.trim().isEmpty) {
      throw ArgumentError.value(offeringId, 'offeringId', 'Must not be empty.');
    }
    if (termNumber < 1 || termNumber > 3) {
      throw ArgumentError.value(
        termNumber,
        'termNumber',
        'Must be 1, 2, or 3.',
      );
    }
  }

  /// Fetches enrolled student counts for a list of offering IDs
  Future<Map<String, int>> getOfferingStudentCounts(
    List<String> offeringIds,
  ) async {
    if (offeringIds.isEmpty) return {};
    try {
      final res = await _client
          .from('student_enrollments')
          .select('subject_offering_id')
          .inFilter('subject_offering_id', offeringIds)
          .eq('status', 'enrolled');
      final Map<String, int> counts = {for (final id in offeringIds) id: 0};
      for (final row in (res as List)) {
        final offId = row['subject_offering_id']?.toString();
        if (offId != null && counts.containsKey(offId)) {
          counts[offId] = counts[offId]! + 1;
        }
      }
      return counts;
    } catch (e) {
      debugPrint('Error getting offering student counts: $e');
      return {for (final id in offeringIds) id: 0};
    }
  }

  /// Fetches enrolled student count for a single offering ID
  Future<int> getOfferingEnrolledCount(String offeringId) async {
    final counts = await getOfferingStudentCounts([offeringId]);
    return counts[offeringId] ?? 0;
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

      if (response.isEmpty) {
        return [];
      }

      final rows = response as List;
      final offeringIds = rows
          .map((r) => r['id']?.toString())
          .whereType<String>()
          .toList();
      final studentCounts = await getOfferingStudentCounts(offeringIds);

      return rows.map<Map<String, dynamic>>((row) {
        final sub = row['subjects'] as Map<String, dynamic>? ?? {};
        final sec = row['sections'] as Map<String, dynamic>? ?? {};
        final id = row['id']?.toString() ?? '';
        return {
          'id': id,
          'subject_id': sub['id']?.toString() ?? '',
          'subject_name': sub['subject_name']?.toString() ?? 'Subject',
          'grade_level': sub['grade_level'] ?? sec['grade_level'] ?? 11,
          'section_id': sec['id']?.toString() ?? '',
          'section_name': sec['section_name']?.toString() ?? 'Section',
          'student_count': studentCounts[id] ?? 0,
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

  /// Fetches archived sections for a specific teacher.
  Future<List<Map<String, dynamic>>> getTeacherArchivedSections(
    String teacherId, {
    String schoolYear = '2026-2027',
  }) async {
    try {
      dynamic response;
      try {
        response = await _client
            .from('subject_offerings')
            .select('''
              id,
              ww_weight,
              pt_weight,
              ex_weight,
              terms_taught,
              term_block,
              units_per_term,
              st1_weight,
              st2_weight,
              te_weight,
              subjects!inner ( id, subject_name, grade_level ),
              sections!inner ( id, section_name, grade_level )
            ''')
            .eq('teacher_id', teacherId)
            .eq('is_archived', true);
      } catch (_) {
        response = await _client
            .from('subject_offerings')
            .select('''
              id,
              ww_weight,
              pt_weight,
              ex_weight,
              subjects!inner ( id, subject_name, grade_level ),
              sections!inner ( id, section_name, grade_level )
            ''')
            .eq('teacher_id', teacherId)
            .eq('is_archived', true);
      }

      final rows = response as List? ?? [];
      if (rows.isEmpty) return [];

      final offeringIds = rows
          .map((r) => r['id']?.toString())
          .whereType<String>()
          .toList();
      final studentCounts = await getOfferingStudentCounts(offeringIds);

      return rows.map<Map<String, dynamic>>((row) {
        final sub = row['subjects'] as Map<String, dynamic>? ?? {};
        final sec = row['sections'] as Map<String, dynamic>? ?? {};
        final id = row['id']?.toString() ?? '';
        return {
          'id': id,
          'subject_id': sub['id']?.toString() ?? '',
          'subject_name': sub['subject_name']?.toString() ?? 'Subject',
          'grade_level': sub['grade_level'] ?? sec['grade_level'] ?? 11,
          'section_id': sec['id']?.toString() ?? '',
          'section_name': sec['section_name']?.toString() ?? 'Section',
          'student_count': studentCounts[id] ?? 0,
          'ww_weight': row['ww_weight'] ?? 20.0,
          'pt_weight': row['pt_weight'] ?? 50.0,
          'ex_weight': row['ex_weight'] ?? 30.0,
          'terms_taught': row['terms_taught'] ?? 3,
          'term_block': row['term_block'] ?? '1ST, 2ND, 3RD',
          'units_per_term': (row['units_per_term'] as num?)?.toDouble() ?? 2.0,
          'st1_weight': (row['st1_weight'] as num?)?.toDouble() ?? 30.0,
          'st2_weight': (row['st2_weight'] as num?)?.toDouble() ?? 30.0,
          'te_weight': (row['te_weight'] as num?)?.toDouble() ?? 40.0,
          'school_year': schoolYear,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting teacher archived sections: $e');
      return [];
    }
  }

  /// Checks if an offering contains any student academic records (grades, term sheets, or submissions)
  Future<bool> hasAcademicRecords(String offeringId) async {
    try {
      // 1. Gradebook term sheets
      final termSheets = await _client
          .from('gradebook_term_sheets')
          .select('id')
          .eq('subject_offering_id', offeringId)
          .limit(1);
      if ((termSheets as List).isNotEmpty) return true;

      // 2. Term grades
      final termGrades = await _client
          .from('term_grades')
          .select('id')
          .eq('subject_offering_id', offeringId)
          .limit(1);
      if ((termGrades as List).isNotEmpty) return true;

      // 3. Classwork submissions
      final cwItems = await _client
          .from('classwork_items')
          .select('id')
          .eq('subject_offering_id', offeringId);
      final cwIds = (cwItems as List)
          .map((c) => c['id']?.toString())
          .whereType<String>()
          .toList();
      if (cwIds.isNotEmpty) {
        final subs = await _client
            .from('student_classwork_submissions')
            .select('id')
            .inFilter('classwork_id', cwIds)
            .limit(1);
        if ((subs as List).isNotEmpty) return true;
      }

      // 4. Digital assessment attempts
      final assessments = await _client
          .from('digital_assessments')
          .select('id')
          .eq('subject_offering_id', offeringId);
      final assessIds = (assessments as List)
          .map((a) => a['id']?.toString())
          .whereType<String>()
          .toList();
      if (assessIds.isNotEmpty) {
        final attempts = await _client
            .from('assessment_attempts')
            .select('id')
            .inFilter('assessment_id', assessIds)
            .limit(1);
        if ((attempts as List).isNotEmpty) return true;
      }

      return false;
    } catch (e) {
      debugPrint('Notice checking academic records for $offeringId: $e');
      return false;
    }
  }

  /// Checks if all offerings under a teacher's subject contain any academic records
  Future<bool> hasSubjectAcademicRecords(
    String teacherId,
    String subjectId,
  ) async {
    try {
      final offerings = await _client
          .from('subject_offerings')
          .select('id')
          .eq('teacher_id', teacherId)
          .eq('subject_id', subjectId);

      for (final off in (offerings as List)) {
        final offId = off['id']?.toString();
        if (offId != null && await hasAcademicRecords(offId)) {
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Notice checking subject academic records: $e');
      return false;
    }
  }

  /// Archives a single offering (soft-delete / archive section)
  Future<void> archiveSingleOffering(String offeringId) async {
    final offRow = await _client
        .from('subject_offerings')
        .select('id, teacher_id')
        .eq('id', offeringId)
        .maybeSingle();

    await _client
        .from('subject_offerings')
        .update({'is_archived': true})
        .eq('id', offeringId);

    try {
      await AppDatabase.instance.updateSingleOfferingArchivedStatus(
        offeringId: offeringId,
        isArchived: true,
      );
    } catch (e) {
      debugPrint('Drift archive single offering notice: $e');
    }

    final teacherId = offRow?['teacher_id']?.toString();
    if (teacherId != null) {
      final currentCached = LocalStorageService.getTeacherSubjects(teacherId);
      final updated = currentCached
          .where((s) => s['id']?.toString() != offeringId)
          .toList();
      await LocalStorageService.saveTeacherSubjects(teacherId, updated);
    }
  }

  /// Restores a single archived offering (restore section)
  Future<void> restoreSingleOffering(String offeringId) async {
    final offRow = await _client
        .from('subject_offerings')
        .select('id, teacher_id')
        .eq('id', offeringId)
        .maybeSingle();

    await _client
        .from('subject_offerings')
        .update({'is_archived': false})
        .eq('id', offeringId);

    try {
      await AppDatabase.instance.updateSingleOfferingArchivedStatus(
        offeringId: offeringId,
        isArchived: false,
      );
    } catch (e) {
      debugPrint('Drift restore single offering notice: $e');
    }

    final teacherId = offRow?['teacher_id']?.toString();
    if (teacherId != null) {
      await _syncOfferingsFromCloud(teacherId, '2026-2027');
    }
  }

  /// Archives all subject offerings for a teacher and subject, synchronizing Drift & LocalStorage
  Future<void> archiveSubjectOffering({
    required String teacherId,
    required String subjectId,
  }) async {
    await _client
        .from('subject_offerings')
        .update({'is_archived': true})
        .eq('teacher_id', teacherId)
        .eq('subject_id', subjectId);

    try {
      await AppDatabase.instance.updateOfferingsArchivedStatus(
        teacherId: teacherId,
        subjectId: subjectId,
        isArchived: true,
      );
    } catch (e) {
      debugPrint('Drift archive update notice: $e');
    }

    // Update LocalStorageService cache
    final currentCached = LocalStorageService.getTeacherSubjects(teacherId);
    final updated = currentCached
        .where((s) => s['subject_id']?.toString() != subjectId)
        .toList();
    await LocalStorageService.saveTeacherSubjects(teacherId, updated);
  }

  /// Restores all subject offerings for a teacher and subject, synchronizing Drift & LocalStorage
  Future<void> restoreSubjectOffering({
    required String teacherId,
    required String subjectId,
  }) async {
    await _client
        .from('subject_offerings')
        .update({'is_archived': false})
        .eq('teacher_id', teacherId)
        .eq('subject_id', subjectId);

    try {
      await AppDatabase.instance.updateOfferingsArchivedStatus(
        teacherId: teacherId,
        subjectId: subjectId,
        isArchived: false,
      );
    } catch (e) {
      debugPrint('Drift restore update notice: $e');
    }

    // Resync active offerings from cloud into Drift & LocalStorage
    await _syncOfferingsFromCloud(teacherId, '2026-2027');
  }

  /// Safe child-to-parent cascade deletion for a single offering
  Future<void> _cascadeDeleteOffering(String offeringId) async {
    try {
      // 1. Classwork items and submissions
      try {
        final classworks = await _client
            .from('classwork_items')
            .select('id')
            .eq('subject_offering_id', offeringId);
        final cwIds = (classworks as List)
            .map((c) => c['id']?.toString())
            .whereType<String>()
            .toList();
        if (cwIds.isNotEmpty) {
          final subs = await _client
              .from('student_classwork_submissions')
              .select('id')
              .inFilter('classwork_id', cwIds);
          final subIds = (subs as List)
              .map((s) => s['id']?.toString())
              .whereType<String>()
              .toList();
          if (subIds.isNotEmpty) {
            await _client
                .from('submission_attachments')
                .delete()
                .inFilter('submission_id', subIds);
            await _client
                .from('student_classwork_submissions')
                .delete()
                .inFilter('id', subIds);
          }
          await _client
              .from('classwork_attachments')
              .delete()
              .inFilter('classwork_id', cwIds);
          await _client
              .from('classwork_extensions')
              .delete()
              .inFilter('classwork_id', cwIds);
          await _client
              .from('classwork_items')
              .delete()
              .eq('subject_offering_id', offeringId);
        }
      } catch (e) {
        debugPrint('Notice deleting classworks for $offeringId: $e');
      }

      // 2. Digital assessments
      try {
        final assessments = await _client
            .from('digital_assessments')
            .select('id')
            .eq('subject_offering_id', offeringId);
        final assessIds = (assessments as List)
            .map((a) => a['id']?.toString())
            .whereType<String>()
            .toList();
        if (assessIds.isNotEmpty) {
          final attempts = await _client
              .from('assessment_attempts')
              .select('id')
              .inFilter('assessment_id', assessIds);
          final attemptIds = (attempts as List)
              .map((a) => a['id']?.toString())
              .whereType<String>()
              .toList();
          if (attemptIds.isNotEmpty) {
            await _client
                .from('anti_cheating_logs')
                .delete()
                .inFilter('attempt_id', attemptIds);
            await _client
                .from('assessment_responses')
                .delete()
                .inFilter('attempt_id', attemptIds);
            await _client
                .from('assessment_attempts')
                .delete()
                .inFilter('id', attemptIds);
          }
          final questions = await _client
              .from('assessment_questions')
              .select('id')
              .inFilter('assessment_id', assessIds);
          final qIds = (questions as List)
              .map((q) => q['id']?.toString())
              .whereType<String>()
              .toList();
          if (qIds.isNotEmpty) {
            await _client
                .from('assessment_question_options')
                .delete()
                .inFilter('question_id', qIds);
            await _client
                .from('assessment_questions')
                .delete()
                .inFilter('id', qIds);
          }
          await _client
              .from('digital_assessment_extensions')
              .delete()
              .inFilter('assessment_id', assessIds);
          await _client
              .from('digital_assessments')
              .delete()
              .eq('subject_offering_id', offeringId);
        }
      } catch (e) {
        debugPrint('Notice deleting assessments for $offeringId: $e');
      }

      // 3. Learning materials & folders
      try {
        final folders = await _client
            .from('folders')
            .select('id')
            .eq('subject_offering_id', offeringId);
        final folderIds = (folders as List)
            .map((f) => f['id']?.toString())
            .whereType<String>()
            .toList();
        if (folderIds.isNotEmpty) {
          await _client
              .from('learning_materials')
              .delete()
              .inFilter('folder_id', folderIds);
          await _client
              .from('folders')
              .delete()
              .eq('subject_offering_id', offeringId);
        }
      } catch (e) {
        debugPrint('Notice deleting folders/materials for $offeringId: $e');
      }

      // 4. Attendance, gradebook sheets, term grades, schedule, enrollments
      try {
        await _client
            .from('attendance_records')
            .delete()
            .eq('subject_offering_id', offeringId);
      } catch (_) {}
      try {
        await _client
            .from('gradebook_term_sheets')
            .delete()
            .eq('subject_offering_id', offeringId);
      } catch (_) {}
      try {
        await _client
            .from('term_grades')
            .delete()
            .eq('subject_offering_id', offeringId);
      } catch (_) {}
      try {
        await _client
            .from('teacher_schedule')
            .delete()
            .eq('subject_offering_id', offeringId);
      } catch (_) {}
      try {
        await _client
            .from('student_enrollments')
            .delete()
            .eq('subject_offering_id', offeringId);
      } catch (_) {}

      // 5. Delete offering row itself
      await _client.from('subject_offerings').delete().eq('id', offeringId);
    } catch (e) {
      debugPrint('Cascade delete error for offering $offeringId: $e');
      rethrow;
    }
  }

  /// Permanently deletes all subject offerings for a teacher and subject with safe foreign-key cascade
  /// Note: Student, parent, and user accounts remain completely untouched.
  Future<void> deleteSubjectOffering({
    required String teacherId,
    required String subjectId,
  }) async {
    final offerings = await _client
        .from('subject_offerings')
        .select('id, section_id')
        .eq('teacher_id', teacherId)
        .eq('subject_id', subjectId);

    final sectionIds = <String>{};
    for (final off in (offerings as List)) {
      final offId = off['id']?.toString();
      final secId = off['section_id']?.toString();
      if (secId != null) sectionIds.add(secId);
      if (offId != null) {
        await _cascadeDeleteOffering(offId);
      }
    }

    // Clean up orphaned sections
    for (final secId in sectionIds) {
      try {
        final remaining = await _client
            .from('subject_offerings')
            .select('id')
            .eq('section_id', secId)
            .limit(1);
        if ((remaining as List).isEmpty) {
          await _client.from('sections').delete().eq('id', secId);
        }
      } catch (_) {}
    }

    // Clean up orphaned subject
    try {
      final remainingSubjects = await _client
          .from('subject_offerings')
          .select('id')
          .eq('subject_id', subjectId)
          .limit(1);
      if ((remainingSubjects as List).isEmpty) {
        await _client.from('subjects').delete().eq('id', subjectId);
      }
    } catch (_) {}

    // Update Drift SQLite & LocalStorageService
    try {
      await AppDatabase.instance.deleteOfferingsForSubject(
        teacherId: teacherId,
        subjectId: subjectId,
      );
    } catch (_) {}
    final currentCached = LocalStorageService.getTeacherSubjects(teacherId);
    final updatedCached = currentCached
        .where((s) => s['subject_id']?.toString() != subjectId)
        .toList();
    await LocalStorageService.saveTeacherSubjects(teacherId, updatedCached);
  }

  /// Permanently deletes a single subject offering with safe cascade
  Future<void> deleteSingleOffering(String offeringId) async {
    final offRow = await _client
        .from('subject_offerings')
        .select('id, teacher_id, subject_id, section_id')
        .eq('id', offeringId)
        .maybeSingle();
    if (offRow == null) return;

    final teacherId = offRow['teacher_id']?.toString();
    final secId = offRow['section_id']?.toString();
    final subjectId = offRow['subject_id']?.toString();

    await _cascadeDeleteOffering(offeringId);

    if (secId != null) {
      try {
        final remaining = await _client
            .from('subject_offerings')
            .select('id')
            .eq('section_id', secId)
            .limit(1);
        if ((remaining as List).isEmpty) {
          await _client.from('sections').delete().eq('id', secId);
        }
      } catch (_) {}
    }

    if (subjectId != null) {
      try {
        final remainingSub = await _client
            .from('subject_offerings')
            .select('id')
            .eq('subject_id', subjectId)
            .limit(1);
        if ((remainingSub as List).isEmpty) {
          await _client.from('subjects').delete().eq('id', subjectId);
        }
      } catch (_) {}
    }

    try {
      await AppDatabase.instance.deleteOfferingById(offeringId);
    } catch (_) {}

    if (teacherId != null) {
      final currentCached = LocalStorageService.getTeacherSubjects(teacherId);
      final updated = currentCached
          .where((s) => s['id']?.toString() != offeringId)
          .toList();
      await LocalStorageService.saveTeacherSubjects(teacherId, updated);
    }
  }

  /// Updates a subject, its grading configuration, and its sections
  Future<void> updateSubjectAndSections({
    required String teacherId,
    required String subjectId,
    required String subjectName,
    required String gradeLevel,
    required double wwWeight,
    required double ptWeight,
    required double exWeight,
    required int termsTaught,
    required String termBlock,
    required double unitsPerTerm,
    required double st1Weight,
    required double st2Weight,
    required double teWeight,
    required List<Map<String, dynamic>> sections,
    String schoolYear = '2026-2027',
  }) async {
    final cleanSubjectName = subjectName.trim();
    final gLevel =
        int.tryParse(gradeLevel.replaceAll(RegExp(r'[^0-9]'), '')) ?? 11;

    // 1. Update subjects table
    await _client
        .from('subjects')
        .update({'subject_name': cleanSubjectName, 'grade_level': gLevel})
        .eq('id', subjectId);

    // 2. Resolve school year and term
    final sy = await _client
        .from('school_years')
        .select('id')
        .eq('school_year', schoolYear)
        .maybeSingle();
    final schoolYearId = sy?['id']?.toString() ?? 'sy_default';

    final termRow = await _client
        .from('terms')
        .select('id')
        .eq('school_year_id', schoolYearId)
        .order('term_number')
        .limit(1)
        .maybeSingle();
    final termId =
        termRow?['id']?.toString() ?? '1a66dbf9-7395-42df-960f-4e22c07e20d4';

    final resolvedTermBlock = termsTaught == 3
        ? '1ST, 2ND, 3RD'
        : termBlock.trim().isEmpty
        ? (termsTaught == 1 ? 'FIRST TERM' : '1ST & 2ND')
        : termBlock;

    // 3. Update existing offerings weights and term metadata
    final offeringUpdateData = {
      'ww_weight': wwWeight,
      'pt_weight': ptWeight,
      'ex_weight': exWeight,
      'terms_taught': termsTaught,
      'term_block': resolvedTermBlock,
      'units_per_term': unitsPerTerm,
      'st1_weight': st1Weight,
      'st2_weight': st2Weight,
      'te_weight': teWeight,
    };

    try {
      await _client
          .from('subject_offerings')
          .update(offeringUpdateData)
          .eq('teacher_id', teacherId)
          .eq('subject_id', subjectId);
    } on PostgrestException catch (error) {
      if (!_isMissingTermMetadata(error)) rethrow;
      final legacy = Map<String, dynamic>.from(offeringUpdateData)
        ..removeWhere((k, _) => _termMetadataColumns.contains(k));
      await _client
          .from('subject_offerings')
          .update(legacy)
          .eq('teacher_id', teacherId)
          .eq('subject_id', subjectId);
    }

    // 4. Update or add sections
    for (final secConfig in sections) {
      final secName = (secConfig['name']?.toString() ?? '').trim();
      if (secName.isEmpty) continue;

      final isExisting = secConfig['isExisting'] == true;
      final existingOfferingId = secConfig['id']?.toString();

      if (isExisting) {
        if (existingOfferingId == null ||
            existingOfferingId.isEmpty ||
            existingOfferingId.startsWith('row-') ||
            existingOfferingId.startsWith('row_')) {
          throw StateError(
            'An existing section is missing its database offering ID.',
          );
        }

        final off = await _client
            .from('subject_offerings')
            .select('section_id')
            .eq('id', existingOfferingId)
            .eq('teacher_id', teacherId)
            .eq('subject_id', subjectId)
            .maybeSingle();
        final secId = off?['section_id']?.toString();
        if (secId == null || secId.isEmpty) {
          throw StateError(
            'The section no longer belongs to this teacher and subject. '
            'Reload the classroom setup and try again.',
          );
        }

        await _client
            .from('sections')
            .update({'section_name': secName, 'grade_level': gLevel})
            .eq('id', secId);
      } else {
        // Draft IDs are UI-only; create or reuse the database section by its fields.
        final existingSec = await _client
            .from('sections')
            .select('id')
            .eq('section_name', secName)
            .eq('grade_level', gLevel)
            .eq('school_year_id', schoolYearId)
            .maybeSingle();

        String sectionId;
        if (existingSec != null) {
          sectionId = existingSec['id'].toString();
        } else {
          final insSec = await _client
              .from('sections')
              .insert({
                'section_name': secName,
                'grade_level': gLevel,
                'school_year_id': schoolYearId,
                'is_archived': false,
              })
              .select('id')
              .single();
          sectionId = insSec['id'].toString();
        }

        final newOfferingData = {
          'subject_id': subjectId,
          'section_id': sectionId,
          'teacher_id': teacherId,
          'term_id': termId,
          'ww_weight': wwWeight,
          'pt_weight': ptWeight,
          'ex_weight': exWeight,
          'terms_taught': termsTaught,
          'term_block': resolvedTermBlock,
          'units_per_term': unitsPerTerm,
          'st1_weight': st1Weight,
          'st2_weight': st2Weight,
          'te_weight': teWeight,
          'is_archived': false,
        };

        try {
          await _client.from('subject_offerings').insert(newOfferingData);
        } on PostgrestException catch (error) {
          if (!_isMissingTermMetadata(error)) rethrow;
          final legacy = Map<String, dynamic>.from(newOfferingData)
            ..removeWhere((k, _) => _termMetadataColumns.contains(k));
          await _client.from('subject_offerings').insert(legacy);
        }
      }
    }

    // 5. Resync cloud offerings into local database and cache
    await _syncOfferingsFromCloud(teacherId, schoolYear);
  }
}
