import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  LocalSettings,
  LocalUserProfiles,
  LocalSubjects,
  LocalSections,
  LocalSubjectOfferings,
  LocalStudents,
  LocalEnrollments,
  LocalParents,
  LocalParentStudentLinks,
  LocalAttendanceRecords,
  LocalSchedules,
  LocalAssessments,
  LocalStudentScores,
  OfflineSyncQueue,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  static AppDatabase? _instance;
  static AppDatabase get instance => _instance ??= AppDatabase();

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'classrealm_local_db',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
        onResult: (result) {
          if (result.missingFeatures.isNotEmpty) {
            debugPrint('Web SQLite features notice: ${result.missingFeatures}');
          }
        },
      ),
    );
  }

  // =========================================================================
  // Helper Query & Mutation APIs (Instant 0ms Reads)
  // =========================================================================

  /// Save or update a single setting (Dark Mode, Session, etc.)
  Future<void> setSetting(String key, String value) {
    return into(localSettings).insertOnConflictUpdate(
      LocalSettingsCompanion.insert(
        key: key,
        value: value,
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Get setting value
  Future<String?> getSetting(String key) async {
    final query = select(localSettings)..where((tbl) => tbl.key.equals(key));
    final result = await query.getSingleOrNull();
    return result?.value;
  }

  /// Batch upsert teacher subject offerings
  Future<void> upsertOfferings(List<LocalSubjectOfferingsCompanion> offerings) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(localSubjectOfferings, offerings);
    });
  }

  /// Get subject offerings for a teacher (Instant read)
  Future<List<LocalSubjectOffering>> getOfferingsForTeacher(String teacherId) {
    return (select(localSubjectOfferings)
          ..where((t) => t.teacherId.equals(teacherId) & t.isArchived.equals(false)))
        .get();
  }

  /// Watch subject offerings (Reactive stream - auto refreshes UI on change)
  Stream<List<LocalSubjectOffering>> watchOfferingsForTeacher(String teacherId) {
    return (select(localSubjectOfferings)
          ..where((t) => t.teacherId.equals(teacherId) & t.isArchived.equals(false)))
        .watch();
  }

  /// Update archive status for subject offerings of a teacher and subject
  Future<void> updateOfferingsArchivedStatus({
    required String teacherId,
    required String subjectId,
    required bool isArchived,
  }) async {
    await (update(localSubjectOfferings)
          ..where((t) =>
              t.teacherId.equals(teacherId) & t.subjectId.equals(subjectId)))
        .write(LocalSubjectOfferingsCompanion(
      isArchived: Value(isArchived),
    ));
  }

  /// Update archive status for a single offering by id
  Future<void> updateSingleOfferingArchivedStatus({
    required String offeringId,
    required bool isArchived,
  }) async {
    await (update(localSubjectOfferings)
          ..where((t) => t.id.equals(offeringId)))
        .write(LocalSubjectOfferingsCompanion(
      isArchived: Value(isArchived),
    ));
  }

  /// Delete offerings for a teacher and subject
  Future<void> deleteOfferingsForSubject({
    required String teacherId,
    required String subjectId,
  }) async {
    await (delete(localSubjectOfferings)
          ..where((t) =>
              t.teacherId.equals(teacherId) & t.subjectId.equals(subjectId)))
        .go();
  }

  /// Delete a single offering by id
  Future<void> deleteOfferingById(String offeringId) async {
    await (delete(localSubjectOfferings)
          ..where((t) => t.id.equals(offeringId)))
        .go();
  }

  /// Get all local students (Instant 0ms read)
  Future<List<LocalStudent>> getAllStudents() {
    return select(localStudents).get();
  }

  /// Get students for a specific offering
  Future<List<LocalStudent>> getStudentsForOffering(String offeringId) async {
    final query = select(localStudents).join([
      innerJoin(localEnrollments, localEnrollments.studentId.equalsExp(localStudents.studentId)),
    ])..where(localEnrollments.subjectOfferingId.equals(offeringId) & localEnrollments.status.equals('enrolled'));
    final rows = await query.get();
    return rows.map((r) => r.readTable(localStudents)).toList();
  }

  /// Enqueue offline action
  Future<void> enqueueOfflineAction({
    required String action,
    required String targetTable,
    required String payloadJson,
  }) {
    return into(offlineSyncQueue).insertOnConflictUpdate(
      OfflineSyncQueueCompanion.insert(
        id: '${action}_${DateTime.now().millisecondsSinceEpoch}',
        action: action,
        targetTable: targetTable,
        payloadJson: payloadJson,
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  /// Get pending offline actions
  Future<List<OfflineSyncQueueData>> getPendingSyncQueue() {
    return (select(offlineSyncQueue)
          ..where((t) => t.status.equals('pending'))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }
}
