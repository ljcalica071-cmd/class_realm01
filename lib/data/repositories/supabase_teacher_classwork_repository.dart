import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/core/services/supabase_service.dart';
import 'package:class_realm/models/academic_models.dart';
import 'teacher_classwork_repository.dart';

class SupabaseTeacherClassworkRepository implements TeacherClassworkRepository {
  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10 MiB = 10,485,760 bytes
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
        return ActivityModel.fromJson(Map<String, dynamic>.from(item as Map));
      }).toList();
    } catch (e) {
      debugPrint('Pure Dart classwork list notice: $e');
      return [];
    }
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
      storagePath = '$subjectOfferingId/${DateTime.now().millisecondsSinceEpoch}_$safeName';

      try {
        await _client.storage.from('classwork-materials').uploadBinary(
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

    final classworkType = activity.isRequirement ? 'performance_task' : 'activity';

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
}
