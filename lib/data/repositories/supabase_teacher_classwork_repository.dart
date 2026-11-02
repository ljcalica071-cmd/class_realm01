import 'package:class_realm/core/services/app_data_cache.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/core/services/supabase_service.dart';
import 'package:class_realm/models/academic_models.dart';

import 'teacher_classwork_repository.dart';

class SupabaseTeacherClassworkRepository implements TeacherClassworkRepository {
  static const int maxFileSizeBytes =
      10 * 1024 * 1024; // 10 MiB = 10,485,760 bytes
  static const List<String> allowedExtensions = ['.pdf', '.doc', '.docx'];

  final SupabaseClient _client;

  SupabaseTeacherClassworkRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService().client;

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
        'File size exceeds the 10 MiB limit (${fileBytes.lengthInBytes} bytes > $maxFileSizeBytes bytes).',
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
  Future<List<ActivityModel>> getActivities({String? subjectOfferingId}) async {
    final cacheKey = 'teacher_activities_${subjectOfferingId ?? "all"}';
    return AppDataCache.instance.fetchWithSvr<List<ActivityModel>>(
      cacheKey: cacheKey,
      fetcher: () async {
        try {
          var query = _client
              .from('classwork_items')
              .select()
              .eq('is_archived', false);

          if (subjectOfferingId != null && subjectOfferingId.isNotEmpty) {
            query = query.eq('subject_offering_id', subjectOfferingId);
          }

          final rows = await query;
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
    final isNew = activity.id.trim().isEmpty;
    String? storagePath;

    if (fileBytes != null && fileName != null && fileName.trim().isNotEmpty) {
      _validateFile(fileName, fileBytes);

      final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      storagePath =
          '$subjectOfferingId/${DateTime.now().millisecondsSinceEpoch}_$safeName';

      try {
        await _client.storage
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
        debugPrint('Direct storage upload notice: $e');
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
        'deadline': activity.deadline.toIso8601String(),
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
            .select()
            .single();
        AppDataCache.instance.invalidatePrefix('teacher_activities_');
        AppDataCache.instance.invalidatePrefix('student_dashboard_');
        return ActivityModel.fromJson(Map<String, dynamic>.from(res));
      } catch (e) {
        debugPrint('Pure Dart insert classwork notice: $e');
        return activity;
      }
    } else {
      final updateData = <String, dynamic>{
        'title': activity.title,
        'instructions': activity.instructions,
        'max_score': activity.maxScore.round(),
        'deadline': activity.deadline.toIso8601String(),
        'term_number': activity.termNumber,
        'gradebook_column_index': activity.gradebookColumnIndex,
        'completion_mode': activity.completionMode,
        'allow_late_submission': activity.allowLateSubmission,
        'storage_path': storagePath,
        'file_name': fileName,
        'mime_type': mimeType,
        if (fileBytes != null) 'file_size_bytes': fileBytes.lengthInBytes,
        if (removeExistingAttachment) 'storage_path': null,
      };

      try {
        final res = await _client
            .from('classwork_items')
            .update(updateData)
            .eq('id', activity.id)
            .select()
            .single();
        AppDataCache.instance.invalidatePrefix('teacher_activities_');
        AppDataCache.instance.invalidatePrefix('student_dashboard_');
        return ActivityModel.fromJson(Map<String, dynamic>.from(res));
      } catch (e) {
        debugPrint('Pure Dart update classwork notice: $e');
        return activity;
      }
    }
  }

  @override
  Future<void> deleteActivity(String activityId) async {
    if (activityId.trim().isEmpty) {
      throw ArgumentError('Classwork ID cannot be empty.');
    }
    try {
      await _client
          .from('classwork_items')
          .update({'is_archived': true})
          .eq('id', activityId);
      AppDataCache.instance.invalidatePrefix('teacher_activities_');
      AppDataCache.instance.invalidatePrefix('student_dashboard_');
    } catch (e) {
      debugPrint('Pure Dart delete classwork notice: $e');
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
    try {
      var query = _client
          .from('classwork_items')
          .select('id')
          .eq('subject_offering_id', subjectOfferingId)
          .eq('grading_category', gradingCategory)
          .eq('term_number', termNumber)
          .eq('gradebook_column_index', gradebookColumnIndex)
          .eq('is_archived', false);

      if (excludeClassworkId != null && excludeClassworkId.isNotEmpty) {
        query = query.neq('id', excludeClassworkId);
      }

      final res = await query.limit(1).maybeSingle();
      return res != null;
    } catch (e) {
      debugPrint('isGradebookSlotOccupied error: $e');
      return false; // Fallback to allow if query fails, or could throw.
    }
  }

  Future<List<QuizOrExamModel>> getAssessments({String? subjectOfferingId}) async {
    try {
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
            subject_offerings (
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
                option_label,
                option_text,
                is_correct
              )
            )
          """)
          .eq('is_archived', false);

      if (subjectOfferingId != null && subjectOfferingId.isNotEmpty) {
        query = query.eq('subject_offering_id', subjectOfferingId);
      }

      final rows = await query.order('created_at', ascending: false);
      final list = <QuizOrExamModel>[];

      for (final raw in (rows as List? ?? [])) {
        final r = Map<String, dynamic>.from(raw as Map);
        final off = r['subject_offerings'] as Map<String, dynamic>? ?? {};
        final sub = off['subjects'] as Map<String, dynamic>? ?? {};
        final sec = off['sections'] as Map<String, dynamic>? ?? {};

        final qRows = (r['assessment_questions'] as List? ?? [])
            .map((q) => Map<String, dynamic>.from(q as Map))
            .toList();
        qRows.sort((a, b) =>
            ((a['position'] as num?) ?? 0).compareTo((b['position'] as num?) ?? 0));

        final questions = qRows.map((q) {
          final qTypeStr = q['question_type']?.toString().toLowerCase() ?? '';
          final qType = switch (qTypeStr) {
            'multiple_choice' => QuestionType.multipleChoice,
            'true_false' => QuestionType.trueFalse,
            'identification' => QuestionType.identification,
            'matching_type' => QuestionType.matching,
            _ => QuestionType.multipleChoice,
          };

          final opts = (q['assessment_question_options'] as List? ?? [])
              .map((o) => Map<String, dynamic>.from(o as Map))
              .toList();
          final choices = <String>[];
          String correctAnswer = '';

          if (qType == QuestionType.multipleChoice) {
            for (final opt in opts) {
              final text = opt['option_text']?.toString() ?? '';
              choices.add(text);
              if (opt['is_correct'] == true) {
                correctAnswer = opt['option_label']?.toString() ?? text;
              }
            }
          } else if (qType == QuestionType.trueFalse) {
            choices.addAll(['True', 'False']);
            for (final opt in opts) {
              if (opt['is_correct'] == true) {
                correctAnswer = opt['option_label']?.toString() ?? 'True';
              }
            }
          } else if (qType == QuestionType.identification) {
            for (final opt in opts) {
              if (opt['is_correct'] == true) {
                correctAnswer = opt['option_text']?.toString() ?? '';
              }
            }
          }

          return QuestionModel(
            id: q['id']?.toString() ?? '',
            questionText: q['question_text']?.toString() ?? '',
            type: qType,
            choices: choices,
            correctAnswer: correctAnswer,
            points: (q['points'] as num?)?.toDouble() ?? 1.0,
          );
        }).toList();

        final schedDateStr = r['available_from'] ?? r['deadline'];
        final schedDate = schedDateStr != null
            ? DateTime.tryParse(schedDateStr.toString()) ?? DateTime.now()
            : DateTime.now();

        final aType = r['assessment_type']?.toString().toLowerCase();
        final isExam = aType == 'st1' ||
            aType == 'st2' ||
            aType == 'term_exam' ||
            r['grading_category'] == 'ex';

        list.add(
          QuizOrExamModel(
            id: r['id'].toString(),
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
          ),
        );
      }

      // Also fetch in-person exams from classwork_items
      try {
        var inPersonQuery = _client
            .from('classwork_items')
            .select("""
              id,
              subject_offering_id,
              grading_category,
              title,
              instructions,
              max_score,
              deadline,
              completion_mode,
              is_published,
              subject_offerings (
                subjects ( subject_name ),
                sections ( section_name, grade_level )
              )
            """)
            .eq('grading_category', 'ex')
            .eq('completion_mode', 'in_person')
            .eq('is_archived', false);

        if (subjectOfferingId != null && subjectOfferingId.isNotEmpty) {
          inPersonQuery =
              inPersonQuery.eq('subject_offering_id', subjectOfferingId);
        }

        final inPersonRows = await inPersonQuery;
        for (final raw in (inPersonRows as List? ?? [])) {
          final r = Map<String, dynamic>.from(raw as Map);
          final off = r['subject_offerings'] as Map<String, dynamic>? ?? {};
          final sub = off['subjects'] as Map<String, dynamic>? ?? {};
          final sec = off['sections'] as Map<String, dynamic>? ?? {};
          final deadlineStr = r['deadline'];
          final schedDate = deadlineStr != null
              ? DateTime.tryParse(deadlineStr.toString()) ?? DateTime.now()
              : DateTime.now();

          list.add(
            QuizOrExamModel(
              id: r['id'].toString(),
              title: r['title']?.toString() ?? '',
              description: r['instructions']?.toString() ?? '',
              subject: sub['subject_name']?.toString() ?? '',
              section: sec['section_name']?.toString() ?? '',
              isExam: true,
              durationMinutes: 0,
              scheduleDate: schedDate,
              isPublished: r['is_published'] != false,
              resultsReleased: false,
              questions: [],
            ),
          );
        }
      } catch (_) {}

      return list;
    } catch (e) {
      debugPrint('getAssessments notice: $e');
      return [];
    }
  }
}
