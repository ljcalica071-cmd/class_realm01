import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart';
import 'package:class_realm/data/datasources/local/app_database.dart';
import 'package:class_realm/data/repositories/supabase_attendance_repository.dart';

class SyncCoordinator {
  static final SyncCoordinator instance = SyncCoordinator._internal();
  SyncCoordinator._internal();

  /// Web uses online-first direct Supabase client + memory/local storage cache.
  /// Drift SQLite Web Worker (sqlite3.wasm / drift_worker.js) is reserved for native platforms.
  static bool get isLocalDbSupported => !kIsWeb;

  SupabaseClient get _client => Supabase.instance.client;
  AppDatabase get _db => AppDatabase.instance;

  Timer? _periodicSyncTimer;
  bool _isSyncing = false;

  void startBackgroundSync() {
    if (!isLocalDbSupported) return;
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      processPendingQueue();
    });
  }

  void stopBackgroundSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
  }

  // =========================================================================
  // 1. TEACHER INITIAL & BACKGROUND SYNC
  // =========================================================================

  Future<void> syncTeacherData(String teacherId) async {
    if (!isLocalDbSupported || teacherId.isEmpty) return;

    try {
      // 1. Fetch active offerings with subjects and sections
      final offeringsResponse = await _client
          .from('subject_offerings')
          .select('''
            id,
            ww_weight,
            pt_weight,
            ex_weight,
            subjects ( id, subject_name, grade_level, subject_code ),
            sections ( id, section_name, grade_level )
          ''')
          .eq('teacher_id', teacherId)
          .eq('is_archived', false);

      if (offeringsResponse.isNotEmpty) {
        final offeringCompanions = <LocalSubjectOfferingsCompanion>[];
        final sectionCompanions = <LocalSectionsCompanion>[];
        final subjectCompanions = <LocalSubjectsCompanion>[];

        for (final row in offeringsResponse as List) {
          final sub = row['subjects'] as Map<String, dynamic>? ?? {};
          final sec = row['sections'] as Map<String, dynamic>? ?? {};

          final subjectId = sub['id']?.toString() ?? '';
          final sectionId = sec['id']?.toString() ?? '';
          final offeringId = row['id']?.toString() ?? '';

          if (subjectId.isNotEmpty) {
            subjectCompanions.add(
              LocalSubjectsCompanion.insert(
                id: subjectId,
                subjectCode: sub['subject_code']?.toString() ?? 'SUB',
                subjectName: sub['subject_name']?.toString() ?? 'Subject',
                gradeLevel: (sub['grade_level'] as num?)?.toInt() ?? 11,
              ),
            );
          }

          if (sectionId.isNotEmpty) {
            sectionCompanions.add(
              LocalSectionsCompanion.insert(
                id: sectionId,
                sectionName: sec['section_name']?.toString() ?? 'Section',
                gradeLevel: (sec['grade_level'] as num?)?.toInt() ?? 11,
              ),
            );
          }

          if (offeringId.isNotEmpty) {
            offeringCompanions.add(
              LocalSubjectOfferingsCompanion.insert(
                id: offeringId,
                teacherId: teacherId,
                subjectId: subjectId,
                sectionId: sectionId,
                subjectName: sub['subject_name']?.toString() ?? 'Subject',
                sectionName: sec['section_name']?.toString() ?? 'Section',
                gradeLevel:
                    (sub['grade_level'] ?? sec['grade_level'] as num?)
                        ?.toInt() ??
                    11,
                wwWeight: Value((row['ww_weight'] as num?)?.toDouble() ?? 20.0),
                ptWeight: Value((row['pt_weight'] as num?)?.toDouble() ?? 50.0),
                exWeight: Value((row['ex_weight'] as num?)?.toDouble() ?? 30.0),
              ),
            );
          }
        }

        // Batch save into SQLite
        await _db.batch((b) {
          b.insertAllOnConflictUpdate(_db.localSubjects, subjectCompanions);
          b.insertAllOnConflictUpdate(_db.localSections, sectionCompanions);
          b.insertAllOnConflictUpdate(
            _db.localSubjectOfferings,
            offeringCompanions,
          );
        });
      }

      // 2. Fetch enrolled students for this teacher
      final enrollmentResponse = await _client
          .from('student_enrollments')
          .select('''
            id,
            student_id,
            subject_offering_id,
            status,
            student_profiles!inner (
              student_id, lrn, first_name, middle_name, last_name, gender, department_or_section
            ),
            subject_offerings!inner ( teacher_id )
          ''')
          .eq('subject_offerings.teacher_id', teacherId)
          .ilike('status', 'enrolled');

      if ((enrollmentResponse as List).isNotEmpty) {
        final studentCompanions = <LocalStudentsCompanion>[];
        final enrollCompanions = <LocalEnrollmentsCompanion>[];

        for (final row in enrollmentResponse as List) {
          final st = row['student_profiles'] as Map<String, dynamic>? ?? {};
          final stId =
              st['student_id']?.toString() ?? row['student_id']?.toString();
          final enrollId = row['id']?.toString() ?? '';
          final offeringId = row['subject_offering_id']?.toString() ?? '';

          if (stId != null && stId.isNotEmpty) {
            studentCompanions.add(
              LocalStudentsCompanion.insert(
                studentId: stId,
                lrn: Value(st['lrn']?.toString()),
                firstName: st['first_name']?.toString() ?? '',
                middleName: Value(st['middle_name']?.toString()),
                lastName: st['last_name']?.toString() ?? '',
                gender: Value(st['gender']?.toString() ?? 'unspecified'),
                departmentOrSection: Value(
                  st['department_or_section']?.toString(),
                ),
              ),
            );

            if (enrollId.isNotEmpty) {
              enrollCompanions.add(
                LocalEnrollmentsCompanion.insert(
                  id: enrollId,
                  studentId: stId,
                  subjectOfferingId: offeringId,
                  status: Value(row['status']?.toString() ?? 'enrolled'),
                ),
              );
            }
          }
        }

        await _db.batch((b) {
          b.insertAllOnConflictUpdate(_db.localStudents, studentCompanions);
          b.insertAllOnConflictUpdate(_db.localEnrollments, enrollCompanions);
        });
      }

      // 3. Process any pending offline mutations
      await processPendingQueue();
    } catch (e) {
      debugPrint(
        'SyncCoordinator teacher sync error (safe offline fallback active): $e',
      );
    }
  }

  // =========================================================================
  // 2. STUDENT INITIAL & BACKGROUND SYNC
  // =========================================================================

  Future<void> syncStudentData(String studentId) async {
    if (!isLocalDbSupported || studentId.isEmpty) return;
    try {
      final enrollments = await _client
          .from('student_enrollments')
          .select('''
            id,
            subject_offering_id,
            status,
            subject_offerings (
              id, teacher_id, ww_weight, pt_weight, ex_weight,
              subjects ( id, subject_name, grade_level, subject_code ),
              sections ( id, section_name, grade_level )
            )
          ''')
          .eq('student_id', studentId)
          .ilike('status', 'enrolled');

      if ((enrollments as List).isNotEmpty) {
        final offerings = <LocalSubjectOfferingsCompanion>[];
        for (final row in enrollments as List) {
          final off = row['subject_offerings'] as Map<String, dynamic>? ?? {};
          final sub = off['subjects'] as Map<String, dynamic>? ?? {};
          final sec = off['sections'] as Map<String, dynamic>? ?? {};
          final offId = off['id']?.toString() ?? '';

          if (offId.isNotEmpty) {
            offerings.add(
              LocalSubjectOfferingsCompanion.insert(
                id: offId,
                teacherId: off['teacher_id']?.toString() ?? '',
                subjectId: sub['id']?.toString() ?? '',
                sectionId: sec['id']?.toString() ?? '',
                subjectName: sub['subject_name']?.toString() ?? 'Subject',
                sectionName: sec['section_name']?.toString() ?? 'Section',
                gradeLevel:
                    (sub['grade_level'] ?? sec['grade_level'] as num?)
                        ?.toInt() ??
                    11,
              ),
            );
          }
        }

        await _db.batch((b) {
          b.insertAllOnConflictUpdate(_db.localSubjectOfferings, offerings);
        });
      }
    } catch (e) {
      debugPrint('SyncCoordinator student sync notice: $e');
    }
  }

  // =========================================================================
  // 3. PARENT INITIAL & BACKGROUND SYNC
  // =========================================================================

  Future<void> syncParentData(String parentId) async {
    if (!isLocalDbSupported || parentId.isEmpty) return;
    try {
      final links = await _client
          .from('parent_student_links')
          .select('''
            id,
            parent_id,
            student_id,
            relationship,
            student_profiles (
              student_id, lrn, first_name, middle_name, last_name, gender, department_or_section
            )
          ''')
          .eq('parent_id', parentId);

      if ((links as List).isNotEmpty) {
        final studentCompanions = <LocalStudentsCompanion>[];
        final linkCompanions = <LocalParentStudentLinksCompanion>[];

        for (final row in links as List) {
          final st = row['student_profiles'] as Map<String, dynamic>? ?? {};
          final stId =
              st['student_id']?.toString() ?? row['student_id']?.toString();
          final linkId = row['id']?.toString() ?? '${parentId}_$stId';

          if (stId != null && stId.isNotEmpty) {
            studentCompanions.add(
              LocalStudentsCompanion.insert(
                studentId: stId,
                lrn: Value(st['lrn']?.toString()),
                firstName: st['first_name']?.toString() ?? '',
                middleName: Value(st['middle_name']?.toString()),
                lastName: st['last_name']?.toString() ?? '',
                gender: Value(st['gender']?.toString() ?? 'unspecified'),
                departmentOrSection: Value(
                  st['department_or_section']?.toString(),
                ),
              ),
            );

            linkCompanions.add(
              LocalParentStudentLinksCompanion.insert(
                id: linkId,
                parentId: parentId,
                studentId: stId,
                relationship: Value(
                  row['relationship']?.toString() ?? 'Guardian',
                ),
              ),
            );
          }
        }

        await _db.batch((b) {
          b.insertAllOnConflictUpdate(_db.localStudents, studentCompanions);
          b.insertAllOnConflictUpdate(
            _db.localParentStudentLinks,
            linkCompanions,
          );
        });
      }
    } catch (e) {
      debugPrint('SyncCoordinator parent sync notice: $e');
    }
  }

  // =========================================================================
  // 4. OFFLINE MUTATION SYNC QUEUE PROCESSOR (PUSH SYNC)
  // =========================================================================

  Future<void> processPendingQueue() async {
    if (!isLocalDbSupported || _isSyncing) return;
    _isSyncing = true;

    try {
      await SupabaseAttendanceRepository.instance.syncOfflineAttendanceQueue();
      final pendingItems = await _db.getPendingSyncQueue();
      if (pendingItems.isEmpty) {
        _isSyncing = false;
        return;
      }

      for (final item in pendingItems) {
        try {
          final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;

          if (item.action == 'save_attendance') {
            final offeringId = payload['subject_offering_id']?.toString();
            final date = payload['date']?.toString();
            final records = (payload['records'] as List? ?? []);

            if (offeringId != null && date != null && records.isNotEmpty) {
              final rows = records
                  .map(
                    (r) => {
                      'student_id': r['student_id'],
                      'subject_offering_id': offeringId,
                      'attendance_date': date,
                      'status': r['status'],
                      'remarks': r['remarks'],
                    },
                  )
                  .toList();

              await _client
                  .from('attendance_records')
                  .upsert(
                    rows,
                    onConflict:
                        'student_id,subject_offering_id,attendance_date',
                  );
            }
          }

          // Mark item as synced / remove from queue
          await (_db.delete(
            _db.offlineSyncQueue,
          )..where((t) => t.id.equals(item.id))).go();
        } catch (itemErr) {
          debugPrint('Error syncing item ${item.id}: $itemErr');
          // Increment retry count
          await (_db.update(
            _db.offlineSyncQueue,
          )..where((t) => t.id.equals(item.id))).write(
            OfflineSyncQueueCompanion(
              retryCount: Value(item.retryCount + 1),
              errorMessage: Value(itemErr.toString()),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('SyncCoordinator queue processing error: $e');
    } finally {
      _isSyncing = false;
    }
  }
}
