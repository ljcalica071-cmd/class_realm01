import 'dart:typed_data';
import 'package:class_realm/models/academic_models.dart';

abstract class TeacherClassworkRepository {
  /// Fetches all classwork items (activities, assignments, and performance tasks)
  /// owned by the authenticated teacher. Optionally filters by [subjectOfferingId].
  Future<List<ActivityModel>> getActivities({String? subjectOfferingId});

  /// Saves (creates or updates) a classwork item.
  /// If [fileBytes] and [fileName] are supplied, uploads the attachment to private storage
  /// via the authorized teacher upload endpoint before persisting the classwork record.
  /// If [removeExistingAttachment] is true, removes any current attachment.
  Future<ActivityModel> saveActivity({
    required ActivityModel activity,
    required String subjectOfferingId,
    Uint8List? fileBytes,
    String? fileName,
    String? mimeType,
    bool removeExistingAttachment = false,
  });

  /// Deletes a classwork item and cleans up any associated attachment.
  Future<void> deleteActivity(String activityId);

  /// Checks if a gradebook slot is already occupied.
  /// Returns `true` if the slot is occupied (i.e. another active classwork uses it).
  Future<bool> isGradebookSlotOccupied({
    required String subjectOfferingId,
    required String gradingCategory,
    required int termNumber,
    required int gradebookColumnIndex,
    String? excludeClassworkId,
  });
}
