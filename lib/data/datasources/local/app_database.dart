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
  LocalAttendanceCutoffs,
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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await _safeAddColumn(m, localStudents, localStudents.rfidUid);
            await _safeAddColumn(
              m,
              localAttendanceRecords,
              localAttendanceRecords.recordingMethod,
            );
            await _safeAddColumn(
              m,
              localAttendanceRecords,
              localAttendanceRecords.timeIn,
            );
            await _safeAddColumn(
              m,
              localAttendanceRecords,
              localAttendanceRecords.deviceId,
            );
            try {
              await m.createTable(localAttendanceCutoffs);
            } catch (e) {
              debugPrint('Drift createTable(localAttendanceCutoffs) notice: $e');
            }
          }
        },
      );

  Future<void> _safeAddColumn(
    Migrator m,
    TableInfo<Table, Object?> table,
    GeneratedColumn<Object> column,
  ) async {
    try {
      await m.addColumn(table, column);
    } catch (e) {
      debugPrint('Drift addColumn(${column.$name}) notice: $e');
    }
  }

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
  Future<void> upsertOfferings(
    List<LocalSubjectOfferingsCompanion> offerings,
  ) async {
    if (offerings.isEmpty) return;
    await batch((b) {
      b.insertAllOnConflictUpdate(localSubjectOfferings, offerings);
    });
  }

  /// Get subject offerings for a teacher (Instant read)
  Future<List<LocalSubjectOffering>> getOfferingsForTeacher(String teacherId) {
    return (select(localSubjectOfferings)..where(
          (t) => t.teacherId.equals(teacherId) & t.isArchived.equals(false),
        ))
        .get();
  }

  /// Watch subject offerings (Reactive stream - auto refreshes UI on change)
  Stream<List<LocalSubjectOffering>> watchOfferingsForTeacher(
    String teacherId,
  ) {
    return (select(localSubjectOfferings)..where(
          (t) => t.teacherId.equals(teacherId) & t.isArchived.equals(false),
        ))
        .watch();
  }

  /// Update archive status for subject offerings of a teacher and subject
  Future<void> updateOfferingsArchivedStatus({
    required String teacherId,
    required String subjectId,
    required bool isArchived,
  }) async {
    await (update(localSubjectOfferings)..where(
          (t) => t.teacherId.equals(teacherId) & t.subjectId.equals(subjectId),
        ))
        .write(LocalSubjectOfferingsCompanion(isArchived: Value(isArchived)));
  }

  /// Update archive status for a single offering by id
  Future<void> updateSingleOfferingArchivedStatus({
    required String offeringId,
    required bool isArchived,
  }) async {
    await (update(localSubjectOfferings)
          ..where((t) => t.id.equals(offeringId)))
        .write(LocalSubjectOfferingsCompanion(isArchived: Value(isArchived)));
  }

  /// Delete offerings for a teacher and subject
  Future<void> deleteOfferingsForSubject({
    required String teacherId,
    required String subjectId,
  }) async {
    await (delete(localSubjectOfferings)..where(
          (t) => t.teacherId.equals(teacherId) & t.subjectId.equals(subjectId),
        ))
        .go();
  }

  /// Delete a single offering by id
  Future<void> deleteOfferingById(String offeringId) async {
    await (delete(localSubjectOfferings)
          ..where((t) => t.id.equals(offeringId)))
        .go();
  }

  // =========================================================================
  // Students & RFID Local Persistence
  // =========================================================================

  /// Batch upsert local students
  Future<void> upsertStudents(List<LocalStudentsCompanion> rows) async {
    if (rows.isEmpty) return;
    await batch((b) {
      b.insertAllOnConflictUpdate(localStudents, rows);
    });
  }

  /// Batch upsert local enrollments
  Future<void> upsertEnrollments(List<LocalEnrollmentsCompanion> rows) async {
    if (rows.isEmpty) return;
    await batch((b) {
      b.insertAllOnConflictUpdate(localEnrollments, rows);
    });
  }

  /// Update or unlink a student's RFID UID locally (clearing previous holder on reassignment)
  Future<void> updateStudentRfid(String studentId, String? rfidUid) async {
    final normalized = (rfidUid == null || rfidUid.trim().isEmpty)
        ? null
        : rfidUid.trim().toUpperCase();

    await transaction(() async {
      if (normalized != null) {
        final existingMatch = await findStudentByRfid(normalized);
        if (existingMatch != null && existingMatch.studentId != studentId) {
          await (update(localStudents)
                ..where((t) => t.studentId.equals(existingMatch.studentId)))
              .write(const LocalStudentsCompanion(rfidUid: Value(null)));
        }
      }

      await (update(localStudents)
            ..where((t) => t.studentId.equals(studentId)))
          .write(LocalStudentsCompanion(rfidUid: Value(normalized)));
    });
  }

  /// Find a local student by RFID UID (case-insensitive & colon-tolerant)
  Future<LocalStudent?> findStudentByRfid(String rfidUid) async {
    final cleanUid = rfidUid.trim().toUpperCase();
    if (cleanUid.isEmpty) return null;
    final hexOnly = cleanUid.replaceAll(RegExp(r'[^0-9A-F]'), '');

    final candidates = await (select(localStudents)
          ..where((t) => t.rfidUid.isNotNull()))
        .get();

    for (final student in candidates) {
      final stored = student.rfidUid?.trim().toUpperCase();
      if (stored == null || stored.isEmpty) continue;
      if (stored == cleanUid) return student;
      if (hexOnly.isNotEmpty &&
          stored.replaceAll(RegExp(r'[^0-9A-F]'), '') == hexOnly) {
        return student;
      }
    }
    return null;
  }

  /// Get all local students (Instant 0ms read)
  Future<List<LocalStudent>> getAllStudents() {
    return select(localStudents).get();
  }

  /// Get students for a specific offering
  Future<List<LocalStudent>> getStudentsForOffering(String offeringId) async {
    final query = select(localStudents).join([
      innerJoin(
        localEnrollments,
        localEnrollments.studentId.equalsExp(localStudents.studentId),
      ),
    ])
      ..where(
        localEnrollments.subjectOfferingId.equals(offeringId) &
            localEnrollments.status.lower().equals('enrolled'),
      );
    final rows = await query.get();
    return rows.map((r) => r.readTable(localStudents)).toList();
  }

  // =========================================================================
  // Attendance Records, Cutoffs & Schedules Local Persistence
  // =========================================================================

  /// Batch upsert local attendance records
  Future<void> upsertAttendanceRecords(
    List<LocalAttendanceRecordsCompanion> rows,
  ) async {
    if (rows.isEmpty) return;
    await batch((b) {
      b.insertAllOnConflictUpdate(localAttendanceRecords, rows);
    });
  }

  /// Get cached attendance records for a specific offering and YYYY-MM-DD date
  Future<List<LocalAttendanceRecord>> getAttendanceForOfferingAndDate(
    String offeringId,
    String dateStr,
  ) {
    return (select(localAttendanceRecords)..where(
          (t) =>
              t.subjectOfferingId.equals(offeringId) &
              t.attendanceDate.equals(dateStr),
        ))
        .get();
  }

  /// Upsert cutoff configuration for a subject offering
  Future<void> upsertCutoffConfig(LocalAttendanceCutoffsCompanion row) {
    return into(localAttendanceCutoffs).insertOnConflictUpdate(row);
  }

  /// Retrieve cached cutoff configuration for a subject offering
  Future<LocalAttendanceCutoff?> getCutoffConfig(String offeringId) {
    return (select(localAttendanceCutoffs)
          ..where((t) => t.subjectOfferingId.equals(offeringId)))
        .getSingleOrNull();
  }

  /// Batch upsert schedules for offline schedule guarding
  Future<void> upsertSchedules(List<LocalSchedulesCompanion> rows) async {
    if (rows.isEmpty) return;
    await batch((b) {
      b.insertAllOnConflictUpdate(localSchedules, rows);
    });
  }

  /// Retrieve cached schedules for a subject offering
  Future<List<LocalSchedule>> getSchedulesForOffering(String offeringId) {
    return (select(localSchedules)
          ..where((t) => t.subjectOfferingId.equals(offeringId)))
        .get();
  }

  // =========================================================================
  // Durable Offline Sync Queue Management
  // =========================================================================

  /// Enqueue offline action
  Future<void> enqueueOfflineAction({
    String? id,
    required String action,
    required String targetTable,
    required String payloadJson,
  }) {
    final effectiveId =
        id ?? '${action}_${DateTime.now().microsecondsSinceEpoch}';
    return into(offlineSyncQueue).insertOnConflictUpdate(
      OfflineSyncQueueCompanion.insert(
        id: effectiveId,
        action: action,
        targetTable: targetTable,
        payloadJson: payloadJson,
        createdAt: Value(DateTime.now()),
        status: const Value('pending'),
      ),
    );
  }

  /// Get pending offline actions ordered FIFO
  Future<List<OfflineSyncQueueData>> getPendingSyncQueue() {
    return (select(offlineSyncQueue)
          ..where((t) => t.status.equals('pending'))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// Remove a completed sync queue item
  Future<void> markSyncQueueCompleted(String id) async {
    await (delete(offlineSyncQueue)..where((t) => t.id.equals(id))).go();
  }

  /// Mark a sync queue item as failed (or increment retry count)
  Future<void> markSyncQueueFailed(String id, String error) async {
    final existing = await (select(offlineSyncQueue)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    final nextRetry = (existing?.retryCount ?? 0) + 1;
    await (update(offlineSyncQueue)..where((t) => t.id.equals(id))).write(
      OfflineSyncQueueCompanion(
        retryCount: Value(nextRetry),
        status: const Value('failed'),
        errorMessage: Value(error),
      ),
    );
  }
}
