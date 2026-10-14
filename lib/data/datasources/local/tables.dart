import 'package:drift/drift.dart';

// =========================================================================
// 1. Settings & App State (Cross-Role: Teacher, Student, Parent, Admin)
// =========================================================================

class LocalSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}

class LocalUserProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get email => text()();
  TextColumn get role => text()();
  TextColumn get firstName => text().withDefault(const Constant(''))();
  TextColumn get middleName => text().nullable()();
  TextColumn get lastName => text().withDefault(const Constant(''))();
  TextColumn get status => text().withDefault(const Constant('active'))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// =========================================================================
// 2. Academic Structure (Subjects, Sections, Offerings)
// =========================================================================

class LocalSubjects extends Table {
  TextColumn get id => text()();
  TextColumn get subjectCode => text()();
  TextColumn get subjectName => text()();
  IntColumn get gradeLevel => integer()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalSections extends Table {
  TextColumn get id => text()();
  TextColumn get sectionName => text()();
  IntColumn get gradeLevel => integer()();
  TextColumn get schoolYear => text().withDefault(const Constant('2026-2027'))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalSubjectOfferings extends Table {
  TextColumn get id => text()();
  TextColumn get teacherId => text()();
  TextColumn get subjectId => text()();
  TextColumn get sectionId => text()();
  TextColumn get subjectName => text()();
  TextColumn get sectionName => text()();
  IntColumn get gradeLevel => integer()();
  RealColumn get wwWeight => real().withDefault(const Constant(20.0))();
  RealColumn get ptWeight => real().withDefault(const Constant(50.0))();
  RealColumn get exWeight => real().withDefault(const Constant(30.0))();
  TextColumn get schoolYear => text().withDefault(const Constant('2026-2027'))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// =========================================================================
// 3. Students, Enrollments & Parents
// =========================================================================

class LocalStudents extends Table {
  TextColumn get studentId => text()();
  TextColumn get lrn => text().nullable()();
  TextColumn get firstName => text()();
  TextColumn get middleName => text().nullable()();
  TextColumn get lastName => text()();
  TextColumn get gender => text().withDefault(const Constant('unspecified'))();
  TextColumn get departmentOrSection => text().nullable()();

  @override
  Set<Column> get primaryKey => {studentId};
}

class LocalEnrollments extends Table {
  TextColumn get id => text()();
  TextColumn get studentId => text()();
  TextColumn get subjectOfferingId => text()();
  TextColumn get status => text().withDefault(const Constant('enrolled'))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalParents extends Table {
  TextColumn get parentId => text()();
  TextColumn get firstName => text()();
  TextColumn get middleName => text().nullable()();
  TextColumn get lastName => text()();
  TextColumn get contactNumber => text().withDefault(const Constant(''))();
  TextColumn get relationship => text().withDefault(const Constant('Guardian'))();
  TextColumn get email => text().nullable()();

  @override
  Set<Column> get primaryKey => {parentId};
}

class LocalParentStudentLinks extends Table {
  TextColumn get id => text()();
  TextColumn get parentId => text()();
  TextColumn get studentId => text()();
  TextColumn get relationship => text().withDefault(const Constant('Guardian'))();

  @override
  Set<Column> get primaryKey => {id};
}

// =========================================================================
// 4. Attendance & Schedules
// =========================================================================

class LocalAttendanceRecords extends Table {
  TextColumn get id => text()();
  TextColumn get studentId => text()();
  TextColumn get subjectOfferingId => text()();
  TextColumn get attendanceDate => text()();
  TextColumn get status => text()(); // present, absent, late, excused
  TextColumn get remarks => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get recordedBy => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))(); // synced, pending

  @override
  Set<Column> get primaryKey => {id};
}

class LocalSchedules extends Table {
  TextColumn get id => text()();
  TextColumn get subjectOfferingId => text()();
  TextColumn get teacherId => text()();
  TextColumn get dayOfWeek => text()();
  TextColumn get startTime => text()();
  TextColumn get endTime => text()();
  TextColumn get room => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// =========================================================================
// 5. Assessments & Grades (DepEd Standards)
// =========================================================================

class LocalAssessments extends Table {
  TextColumn get id => text()();
  TextColumn get subjectOfferingId => text()();
  TextColumn get title => text()();
  TextColumn get component => text()(); // WW, PT, EX
  RealColumn get totalScore => real()();
  IntColumn get quarter => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalStudentScores extends Table {
  TextColumn get id => text()();
  TextColumn get assessmentId => text()();
  TextColumn get studentId => text()();
  RealColumn get score => real()();
  TextColumn get remarks => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// =========================================================================
// 6. Durable Offline Sync Queue (For All Roles)
// =========================================================================

class OfflineSyncQueue extends Table {
  TextColumn get id => text()();
  TextColumn get action => text()(); // e.g. save_attendance, create_parent, submit_quiz
  TextColumn get targetTable => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, syncing, failed
  TextColumn get errorMessage => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
