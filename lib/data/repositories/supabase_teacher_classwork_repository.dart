import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/core/services/supabase_service.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';

import 'teacher_classwork_repository.dart';

class SupabaseTeacherClassworkRepository implements TeacherClassworkRepository {
  static const int maxFileSizeBytes =
      15 * 1024 * 1024; // 15 MB = 15,728,640 bytes
  static const List<String> allowedExtensions = ['.pdf', '.doc', '.docx'];

  final SupabaseClient? _customClient;
  SupabaseClient get _client => _customClient ?? SupabaseService().client;

  SupabaseTeacherClassworkRepository({SupabaseClient? client})
    : _customClient = client;

  static final SupabaseTeacherClassworkRepository instance =
      SupabaseTeacherClassworkRepository();

  static String _getFileExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1) return '';
    return fileName.substring(dot).toLowerCase();
  }

  void _validateFile(String fileName, Uint8List fileBytes) {
    if (fileBytes.lengthInBytes > maxFileSizeBytes) {
      throw ArgumentError(
        'File size exceeds the 15 MB limit (${fileBytes.lengthInBytes} bytes > $maxFileSizeBytes bytes).',
      );
    }
    final ext = _getFileExtension(fileName);
    if (!allowedExtensions.contains(ext)) {
      throw ArgumentError(
        "Unsupported file format '$ext'. Only PDF, DOC, and DOCX are allowed.",
      );
    }
  }

  @override
  Future<List<ActivityModel>> getActivities({
    String? subjectOfferingId,
    String? teacherId,
    bool forceRefresh = false,
  }) async {
    final effectiveTeacherId =
        teacherId ?? AuthRepository.instance.currentUser?.id;
    final cacheKey =
        'teacher_activities_${effectiveTeacherId ?? "all"}_${subjectOfferingId ?? "all"}';
    return AppDataCache.instance.fetchWithSvr<List<ActivityModel>>(
      cacheKey: cacheKey,
      forceRefresh: forceRefresh,
      fetcher: () async {
        try {
          var query = _client
              .from('classwork_items')
              .select('''
            *,
            subject_offerings!inner (
              id,
              teacher_id,
              subjects:subject_id (
                id,
                subject_code,
                subject_name
              ),
              sections:section_id (
                id,
                section_name,
                grade_level
              )
            )
          ''')
              .inFilter('classwork_type', const [
                'activity',
                'assignment',
                'performance_task',
              ])
              .eq('is_archived', false);

          if (subjectOfferingId != null && subjectOfferingId.isNotEmpty) {
            query = query.eq('subject_offering_id', subjectOfferingId);
          } else if (effectiveTeacherId != null &&
              effectiveTeacherId.isNotEmpty) {
            query = query.eq(
              'subject_offerings.teacher_id',
              effectiveTeacherId,
            );
          }

          final rows = await query.order('created_at', ascending: false);
          final list = rows as List? ?? [];
          return list.map((item) {
            return ActivityModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            );
          }).toList();
        } catch (e) {
          debugPrint('Pure Dart classwork list notice: $e');
          return [];
        }
      },
      onUpdate: (_) {},
      fromJson: (json) => (json as List)
          .map(
            (e) => ActivityModel.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      toJson: (list) => list.map((a) => a.toJson()).toList(),
      ttl: const Duration(minutes: 5),
    );
  }

  @override
  Future<ActivityModel> saveActivity({
    required ActivityModel activity,
    required String subjectOfferingId,
    Uint8List? fileBytes,
    String? fileName,
    String? mimeType,
    bool removeExistingAttachment = false,
  }) async {
    final roundedHps = activity.maxScore.round();
    if (roundedHps < 1 || roundedHps > 100) {
      throw ArgumentError(
        'Highest Possible Score (HPS) must be between 1 and 100 (received $roundedHps).',
      );
    }

    final isNew = activity.id.trim().isEmpty;
    String? storagePath;

    if (fileBytes != null && fileName != null && fileName.trim().isNotEmpty) {
      _validateFile(fileName, fileBytes);

      final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      storagePath =
          '$subjectOfferingId/${DateTime.now().millisecondsSinceEpoch}_$safeName';

      try {
        await SupabaseService().adminClient.storage
            .from('classwork-materials')
            .uploadBinary(
              storagePath,
              fileBytes,
              fileOptions: FileOptions(
                contentType: mimeType ?? 'application/octet-stream',
                upsert: true,
              ),
            );
      } catch (e) {
        debugPrint('Direct storage upload error: $e');
        throw Exception('Failed to upload file attachment: $e');
      }
    }

    final classworkType = activity.isRequirement
        ? 'performance_task'
        : 'activity';

    if (isNew) {
      final insertData = <String, dynamic>{
        'subject_offering_id': subjectOfferingId,
        'classwork_type': classworkType,
        'grading_category': activity.isRequirement ? 'pt' : 'ww',
        'title': activity.title,
        'instructions': activity.instructions,
        'max_score': activity.maxScore.round(),
        'deadline': activity.deadline.toUtc().toIso8601String(),
        'is_published': activity.isPublished,
        'is_archived': activity.isArchived,
        'term_number': activity.termNumber,
        'gradebook_column_index': activity.gradebookColumnIndex,
        'completion_mode': activity.completionMode,
        'allow_late_submission': activity.allowLateSubmission,
        'batch_group_id': activity.batchGroupId,
        'storage_path': storagePath,
        'file_name': fileName,
        'mime_type': mimeType,
        if (fileBytes != null) 'file_size_bytes': fileBytes.lengthInBytes,
      };

      try {
        final res = await _client
            .from('classwork_items')
            .insert(insertData)
            .select('''
              *,
              subject_offerings:subject_offering_id (
                id,
                teacher_id,
                subjects:subject_id (
                  id,
                  subject_code,
                  subject_name
                ),
                sections:section_id (
                  id,
                  section_name,
                  grade_level
                )
              )
            ''')
            .single();
        AppDataCache.instance.invalidatePrefix('teacher_activities_');
        AppDataCache.instance.invalidatePrefix('student_dashboard_');
        return ActivityModel.fromJson(Map<String, dynamic>.from(res));
      } catch (e) {
        debugPrint('Pure Dart insert classwork error: $e');
        rethrow;
      }
    } else {
      final updateData = <String, dynamic>{
        'title': activity.title,
        'instructions': activity.instructions,
        'max_score': activity.maxScore.round(),
        'deadline': activity.deadline.toUtc().toIso8601String(),
        'term_number': activity.termNumber,
        'gradebook_column_index': activity.gradebookColumnIndex,
        'completion_mode': activity.completionMode,
        'allow_late_submission': activity.allowLateSubmission,
        'storage_path': ?storagePath,
        'file_name': ?fileName,
        'mime_type': ?mimeType,
        if (fileBytes != null) 'file_size_bytes': fileBytes.lengthInBytes,
        if (removeExistingAttachment) ...{
          'storage_path': null,
          'file_name': null,
          'mime_type': null,
          'file_size_bytes': null,
        },
      };

      try {
        final res = await _client
            .from('classwork_items')
            .update(updateData)
            .eq('id', activity.id)
            .select('''
              *,
              subject_offerings:subject_offering_id (
                id,
                teacher_id,
                subjects:subject_id (
                  id,
                  subject_code,
                  subject_name
                ),
                sections:section_id (
                  id,
                  section_name,
                  grade_level
                )
              )
            ''')
            .single();
        AppDataCache.instance.invalidatePrefix('teacher_activities_');
        AppDataCache.instance.invalidatePrefix('student_dashboard_');
        return ActivityModel.fromJson(Map<String, dynamic>.from(res));
      } catch (e) {
        debugPrint('Pure Dart update classwork error: $e');
        rethrow;
      }
    }
  }

  @override
  Future<void> deleteActivity(String activityId) async {
    if (activityId.trim().isEmpty) {
      throw ArgumentError('Classwork ID cannot be empty.');
    }
    try {
      // 1. Fetch item details to clean up attachment and gradebook HPS
      final itemRow = await _client
          .from('classwork_items')
          .select(
            'subject_offering_id, term_number, gradebook_column_index, grading_category, storage_path',
          )
          .eq('id', activityId)
          .maybeSingle();

      // 2. Hard delete the row from classwork_items
      await _client.from('classwork_items').delete().eq('id', activityId);

      // 3. Clean up storage attachment if any
      final storagePath = itemRow?['storage_path']?.toString();
      if (storagePath != null && storagePath.isNotEmpty) {
        try {
          await SupabaseService().adminClient.storage
              .from('classwork-materials')
              .remove([storagePath]);
        } catch (_) {}
      }

      // 4. Remove HPS from gradebook_term_sheets so gradebook immediately reflects deletion
      if (itemRow != null) {
        final offeringId = itemRow['subject_offering_id']?.toString();
        final term = (itemRow['term_number'] as num?)?.toInt() ?? 1;
        final col = (itemRow['gradebook_column_index'] as num?)?.toInt();
        final cat =
            itemRow['grading_category']?.toString().toLowerCase() ?? 'ww';

        if (offeringId != null && col != null) {
          try {
            final termSheet = await SubjectRepository.instance
                .getGradebookTermSheet(offeringId, term);
            if (termSheet != null && termSheet['hps'] is Map) {
              final hps = Map<String, dynamic>.from(
                termSheet['hps'] as Map? ?? {},
              );
              final catHps = Map<String, dynamic>.from(hps[cat] as Map? ?? {});
              if (catHps.containsKey(col.toString())) {
                catHps.remove(col.toString());
                hps[cat] = catHps;
                termSheet['hps'] = hps;
                await SubjectRepository.instance.saveGradebookTermSheet(
                  offeringId,
                  term,
                  termSheet,
                );
              }
            }
          } catch (e) {
            debugPrint('Notice updating gradebook term sheet on delete: $e');
          }
        }
        if (offeringId != null) {
          try {
            await LocalStorageService.clearGradebookSheet(offeringId, term);
          } catch (_) {}
        }
      }

      AppDataCache.instance.invalidatePrefix('gradebook_');
      AppDataCache.instance.invalidatePrefix('teacher_activities_');
      AppDataCache.instance.invalidatePrefix('teacher_assessments_');
      AppDataCache.instance.invalidatePrefix('student_dashboard_');
    } catch (e) {
      debugPrint('Pure Dart delete classwork notice: $e');
      rethrow;
    }
  }

  @override
  Future<bool> isGradebookSlotOccupied({
    required String subjectOfferingId,
    required String gradingCategory,
    required int termNumber,
    required int gradebookColumnIndex,
    String? excludeClassworkId,
  }) async {
    final summary = await getOccupiedSlots(
      subjectOfferingId: subjectOfferingId,
      termNumber: termNumber,
      excludeClassworkId: excludeClassworkId,
    );
    final cat = gradingCategory.toLowerCase().trim();
    if (cat == 'ww') {
      return summary.occupiedWwSlots.contains(gradebookColumnIndex);
    }
    if (cat == 'pt') {
      return summary.occupiedPtSlots.contains(gradebookColumnIndex);
    }
    if (cat == 'ex') {
      if (gradebookColumnIndex == 1) return summary.st1Created;
      if (gradebookColumnIndex == 2) return summary.st2Created;
      if (gradebookColumnIndex == 3) return summary.teCreated;
    }
    return false;
  }

  @override
  Future<ClassworkSlotSummary> getOccupiedSlots({
    required String subjectOfferingId,
    required int termNumber,
    String? excludeClassworkId,
  }) async {
    final occupiedWw = <int>{};
    final occupiedPt = <int>{};
    bool hasSt1 = false;
    bool hasSt2 = false;
    bool hasTe = false;
    int maxWw = 3;
    int maxPt = 3;

    String? ownCategory;
    int? ownCol;
    final cwById = <String, Map<String, dynamic>>{};

    try {
      final cwRows = await _client
          .from('classwork_items')
          .select(
            'id, title, grading_category, term_number, gradebook_column_index',
          )
          .eq('subject_offering_id', subjectOfferingId)
          .eq('is_archived', false);

      for (final raw in (cwRows as List? ?? [])) {
        final r = Map<String, dynamic>.from(raw as Map);
        final id = r['id']?.toString() ?? '';
        cwById[id] = r;

        final rowTerm = (r['term_number'] as num?)?.toInt() ?? 1;
        final cat = r['grading_category']?.toString().toLowerCase() ?? '';
        final col = (r['gradebook_column_index'] as num?)?.toInt();

        if (col != null) {
          if (cat == 'ww' && col > maxWw) maxWw = col;
          if (cat == 'pt' && col > maxPt) maxPt = col;
        }

        if (excludeClassworkId != null &&
            excludeClassworkId.isNotEmpty &&
            id == excludeClassworkId) {
          if (rowTerm == termNumber) {
            ownCategory = cat;
            ownCol = col;
          }
          continue;
        }

        if (rowTerm != termNumber) continue;

        if (cat == 'ww' && col != null && col >= 1 && col <= 10) {
          occupiedWw.add(col);
        } else if (cat == 'pt' && col != null && col >= 1 && col <= 10) {
          occupiedPt.add(col);
        } else if (cat == 'ex') {
          final t = (r['title'] ?? '').toString().toUpperCase();
          if (col == 1 || t.contains('ST1') || t.contains('SUMMATIVE TEST 1')) {
            hasSt1 = true;
          } else if (col == 2 ||
              t.contains('ST2') ||
              t.contains('SUMMATIVE TEST 2')) {
            hasSt2 = true;
          } else if (col == 3 ||
              t.contains('TE') ||
              t.contains('TERM EXAM') ||
              t.contains('PERIODICAL')) {
            hasTe = true;
          }
        }
      }
    } catch (e) {
      debugPrint('getOccupiedSlots classwork_items notice: $e');
    }

    try {
      final daRows = await _client
          .from('digital_assessments')
          .select('id, assessment_type, grading_category, title')
          .eq('subject_offering_id', subjectOfferingId)
          .eq('is_archived', false);

      for (final raw in (daRows as List? ?? [])) {
        final r = Map<String, dynamic>.from(raw as Map);
        final id = r['id']?.toString() ?? '';
        if (excludeClassworkId != null &&
            excludeClassworkId.isNotEmpty &&
            id == excludeClassworkId) {
          continue;
        }

        final linkedCw = cwById[id];
        if (linkedCw != null) {
          final linkedTerm = (linkedCw['term_number'] as num?)?.toInt() ?? 1;
          if (linkedTerm != termNumber) continue;
        }

        final aType = r['assessment_type']?.toString().toLowerCase() ?? '';
        if (aType == 'st1') {
          hasSt1 = true;
        } else if (aType == 'st2') {
          hasSt2 = true;
        } else if (aType == 'term_exam') {
          hasTe = true;
        } else if (aType == 'quiz') {
          final linkedCol =
              (linkedCw?['gradebook_column_index'] as num?)?.toInt();
          if (linkedCol != null && linkedCol >= 1 && linkedCol <= 10) {
            occupiedWw.add(linkedCol);
            if (linkedCol > maxWw) maxWw = linkedCol;
          } else {
            final match = RegExp(
              r'quiz\s+(\d+)',
              caseSensitive: false,
            ).firstMatch(r['title']?.toString() ?? '');
            final parsed = match != null ? int.tryParse(match.group(1)!) : null;
            if (parsed != null && parsed >= 1 && parsed <= 10) {
              occupiedWw.add(parsed);
              if (parsed > maxWw) maxWw = parsed;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('getOccupiedSlots digital_assessments notice: $e');
    }

    try {
      final termSheet = await SubjectRepository.instance.getGradebookTermSheet(
        subjectOfferingId,
        termNumber,
        forceRefresh: true,
      );
      if (termSheet != null) {
        final hps = termSheet['hps'] as Map? ?? {};
        final scores = termSheet['scores'] as Map? ?? {};

        final savedWwCols = hps['ww_columns'] is num
            ? (hps['ww_columns'] as num).toInt()
            : int.tryParse(hps['ww_columns']?.toString() ?? '');
        if (savedWwCols != null && savedWwCols > maxWw) {
          maxWw = savedWwCols;
        }
        final savedPtCols = hps['pt_columns'] is num
            ? (hps['pt_columns'] as num).toInt()
            : int.tryParse(hps['pt_columns']?.toString() ?? '');
        if (savedPtCols != null && savedPtCols > maxPt) {
          maxPt = savedPtCols;
        }

        bool hasScoreInSheet(String cat, List<String> keys) {
          for (final studentVal in scores.values) {
            if (studentVal is Map && studentVal[cat] is Map) {
              final catScores = studentVal[cat] as Map;
              for (final k in keys) {
                if (catScores[k] != null) return true;
              }
            }
          }
          return false;
        }

        bool hasPositiveHps(Map catHps, List<String> keys) {
          for (final k in keys) {
            final val = catHps[k];
            final numVal = val is num
                ? val
                : num.tryParse(val?.toString() ?? '');
            if (numVal != null && numVal > 0) return true;
          }
          return false;
        }

        final wwHps = hps['ww'] as Map? ?? {};
        for (int col = 1; col <= 10; col++) {
          if (ownCategory == 'ww' && ownCol == col) continue;
          final keys = [col.toString()];
          if (hasPositiveHps(wwHps, keys) || hasScoreInSheet('ww', keys)) {
            occupiedWw.add(col);
            if (col > maxWw) maxWw = col;
          }
        }

        final ptHps = hps['pt'] as Map? ?? {};
        for (int col = 1; col <= 10; col++) {
          if (ownCategory == 'pt' && ownCol == col) continue;
          final keys = [col.toString()];
          if (hasPositiveHps(ptHps, keys) || hasScoreInSheet('pt', keys)) {
            occupiedPt.add(col);
            if (col > maxPt) maxPt = col;
          }
        }

        final exHps = hps['ex'] as Map? ?? {};
        if (!(ownCategory == 'ex' && ownCol == 1)) {
          if (hasPositiveHps(exHps, const ['st1', '1']) ||
              hasScoreInSheet('ex', const ['st1', '1'])) {
            hasSt1 = true;
          }
        }
        if (!(ownCategory == 'ex' && ownCol == 2)) {
          if (hasPositiveHps(exHps, const ['st2', '2']) ||
              hasScoreInSheet('ex', const ['st2', '2'])) {
            hasSt2 = true;
          }
        }
        if (!(ownCategory == 'ex' && ownCol == 3)) {
          if (hasPositiveHps(exHps, const ['te', '3']) ||
              hasScoreInSheet('ex', const ['te', '3'])) {
            hasTe = true;
          }
        }
      }
    } catch (e) {
      debugPrint('getOccupiedSlots gradebook_term_sheets notice: $e');
    }

    return ClassworkSlotSummary(
      occupiedWwSlots: occupiedWw,
      occupiedPtSlots: occupiedPt,
      st1Created: hasSt1,
      st2Created: hasSt2,
      teCreated: hasTe,
      maxWwSlot: maxWw.clamp(3, 10),
      maxPtSlot: maxPt.clamp(3, 10),
    );
  }

  Future<List<QuizOrExamModel>> getAssessments({
    String? subjectOfferingId,
    String? teacherId,
  }) async {
    final effectiveTeacherId =
        teacherId ?? AuthRepository.instance.currentUser?.id;
    try {
      // Pre-fetch matching classwork_items metadata for quiz/exam slots & in-person items
      final cwMetaById = <String, Map<String, dynamic>>{};
      try {
        var cwQuery = _client
            .from('classwork_items')
            .select("""
              id,
              subject_offering_id,
              classwork_type,
              grading_category,
              title,
              instructions,
              max_score,
              deadline,
              completion_mode,
              term_number,
              gradebook_column_index,
              is_published,
              subject_offerings!inner (
                teacher_id,
                subjects ( subject_name ),
                sections ( section_name, grade_level )
              )
            """)
            .inFilter('classwork_type', const ['quiz', 'exam'])
            .eq('is_archived', false);

        if (subjectOfferingId != null && subjectOfferingId.isNotEmpty) {
          cwQuery = cwQuery.eq('subject_offering_id', subjectOfferingId);
        } else if (effectiveTeacherId != null &&
            effectiveTeacherId.isNotEmpty) {
          cwQuery = cwQuery.eq(
            'subject_offerings.teacher_id',
            effectiveTeacherId,
          );
        }

        final cwRows = await cwQuery.order('created_at', ascending: false);
        for (final raw in (cwRows as List? ?? [])) {
          final r = Map<String, dynamic>.from(raw as Map);
          cwMetaById[r['id'].toString()] = r;
        }
      } catch (cwErr) {
        debugPrint('getAssessments classwork_items metadata notice: $cwErr');
      }

      var query = _client
          .from('digital_assessments')
          .select("""
            id,
            subject_offering_id,
            assessment_type,
            grading_category,
            title,
            instructions,
            time_limit_minutes,
            available_from,
            deadline,
            is_published,
            results_released,
            is_archived,
            subject_offerings!inner (
              teacher_id,
              subjects ( subject_name ),
              sections ( section_name, grade_level )
            ),
            assessment_questions (
              id,
              position,
              question_type,
              question_text,
              points,
              assessment_question_options (
                id,
                position,
                option_text,
                is_correct
              )
            )
          """)
          .eq('is_archived', false);

      if (subjectOfferingId != null && subjectOfferingId.isNotEmpty) {
        query = query.eq('subject_offering_id', subjectOfferingId);
      } else if (effectiveTeacherId != null && effectiveTeacherId.isNotEmpty) {
        query = query.eq('subject_offerings.teacher_id', effectiveTeacherId);
      }

      final rows = await query.order('created_at', ascending: false);
      final list = <QuizOrExamModel>[];
      final seenIds = <String>{};

      for (final raw in (rows as List? ?? [])) {
        final r = Map<String, dynamic>.from(raw as Map);
        final id = r['id'].toString();
        seenIds.add(id);

        final off = r['subject_offerings'] as Map<String, dynamic>? ?? {};
        final sub = off['subjects'] as Map<String, dynamic>? ?? {};
        final sec = off['sections'] as Map<String, dynamic>? ?? {};

        final qRows = (r['assessment_questions'] as List? ?? [])
            .map((q) => Map<String, dynamic>.from(q as Map))
            .toList()
          ..sort(
            (a, b) => ((a['position'] as num?) ?? 0).compareTo(
              (b['position'] as num?) ?? 0,
            ),
          );

        final questions = qRows.map(QuestionModel.fromSupabaseMap).toList();

        final schedDateStr = r['available_from'] ?? r['deadline'];
        final schedDate = schedDateStr != null
            ? DateTime.tryParse(schedDateStr.toString())?.toLocal() ??
                  DateTime.now()
            : DateTime.now();

        final aType = r['assessment_type']?.toString().toLowerCase();
        final isExam =
            aType == 'st1' ||
            aType == 'st2' ||
            aType == 'term_exam' ||
            r['grading_category'] == 'ex';

        final cwMeta = cwMetaById[id];
        final termNum = (cwMeta?['term_number'] as num?)?.toInt() ?? 1;
        final colIdx =
            (cwMeta?['gradebook_column_index'] as num?)?.toInt() ??
            (aType == 'st1'
                ? 1
                : (aType == 'st2' ? 2 : (aType == 'term_exam' ? 3 : null)));

        list.add(
          QuizOrExamModel(
            id: id,
            title: r['title']?.toString() ?? '',
            description: r['instructions']?.toString() ?? '',
            subject: sub['subject_name']?.toString() ?? '',
            section: sec['section_name']?.toString() ?? '',
            isExam: isExam,
            durationMinutes: (r['time_limit_minutes'] as num?)?.toInt() ?? 60,
            scheduleDate: schedDate,
            isPublished: r['is_published'] != false,
            resultsReleased: r['results_released'] == true,
            questions: questions,
            completionMode: 'online',
            termNumber: termNum,
            gradebookColumnIndex: colIdx,
            subjectOfferingId: r['subject_offering_id']?.toString(),
            examType: aType,
          ),
        );
      }

      // Append In-Person Quizzes & Exams from classwork_items
      for (final entry in cwMetaById.entries) {
        if (seenIds.contains(entry.key)) continue;
        final r = entry.value;
        if (r['completion_mode']?.toString() != 'in_person') continue;

        final off = r['subject_offerings'] as Map<String, dynamic>? ?? {};
        final sub = off['subjects'] as Map<String, dynamic>? ?? {};
        final sec = off['sections'] as Map<String, dynamic>? ?? {};
        final deadlineStr = r['deadline'];
        final schedDate = deadlineStr != null
            ? DateTime.tryParse(deadlineStr.toString())?.toLocal() ??
                  DateTime.now()
            : DateTime.now();
        final isExam =
            r['grading_category'] == 'ex' || r['classwork_type'] == 'exam';

        list.add(
          QuizOrExamModel(
            id: entry.key,
            title: r['title']?.toString() ?? '',
            description: r['instructions']?.toString() ?? '',
            subject: sub['subject_name']?.toString() ?? '',
            section: sec['section_name']?.toString() ?? '',
            isExam: isExam,
            durationMinutes: 0,
            scheduleDate: schedDate,
            isPublished: r['is_published'] != false,
            resultsReleased: false,
            questions: const [],
            completionMode: 'in_person',
            termNumber: (r['term_number'] as num?)?.toInt() ?? 1,
            gradebookColumnIndex:
                (r['gradebook_column_index'] as num?)?.toInt(),
            subjectOfferingId: r['subject_offering_id']?.toString(),
            maxScore: (r['max_score'] as num?)?.toDouble() ?? 100.0,
            examType: isExam
                ? ((r['gradebook_column_index'] as num?)?.toInt() == 1
                      ? 'st1'
                      : ((r['gradebook_column_index'] as num?)?.toInt() == 2
                            ? 'st2'
                            : 'term_exam'))
                : 'quiz',
          ),
        );
      }

      return list;
    } catch (e) {
      debugPrint('getAssessments notice: $e');
      return [];
    }
  }
}
