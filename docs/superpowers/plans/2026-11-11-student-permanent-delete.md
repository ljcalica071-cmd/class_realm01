# Student Permanent Deletion with Academic Record Guard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable teachers to permanently delete a student from the archives only if the student has no academic records (attendance, grades, or classwork), protected by a type-to-confirm dialog (`AppModals.showTypeToConfirmDeleteDialog`).

**Architecture:** 
- Database as single source of truth: Pre-flight query checks `attendance_records`, `term_grades`, `student_classwork_submissions`, and `assessment_attempts` before allowing deletion.
- Two-tier safeguard: If records exist, display an informative block modal (`AppModals.showErrorDialog`). If no records exist, require the teacher to type `"I confirm"` in `AppModals.showTypeToConfirmDeleteDialog`.
- Cleanup: Deletes class enrollment, cascades to global account (`users`, `student_profiles`, `student_settings`, `parent_student_links`, Firebase Auth) only if no other class enrollments exist, and invalidates caches.

**Tech Stack:** Flutter, Dart, Supabase Flutter, Firebase Auth Admin, Drift SQLite.

**Spec:** Teacher Class Management - Student Permanent Deletion Feature

---

## Global Constraints

- Never delete a student with existing attendance records, term grades, or classwork submissions (preserves academic history & DepEd compliance).
- Always use `AppModals.showTypeToConfirmDeleteDialog` with required text `"I confirm"`.
- Action must be available inside the **View Archive** list next to the Restore button.
- Always perform cache invalidation (`teacher_students_`, `attendance_`) and call `_loadData(forceRefresh: true)`.

---

## Tasks

### Task 1: Academic Record Guard in `SupabaseStudentRepository`

**Files:**
- Modify: `lib/data/repositories/student_repository.dart`
- Modify: `lib/data/repositories/supabase_student_repository.dart`

**Interfaces:**
- Produces: `Future<StudentRecordCheckResult> checkStudentAcademicRecords(String studentId, [String? subjectOfferingId])`
- `StudentRecordCheckResult`:
  ```dart
  class StudentRecordCheckResult {
    final bool hasRecords;
    final bool hasAttendance;
    final bool hasClasswork;
    final bool hasGrades;
    final bool hasAssessments;
    final String summaryReason;

    const StudentRecordCheckResult({
      required this.hasRecords,
      this.hasAttendance = false,
      this.hasClasswork = false,
      this.hasGrades = false,
      this.hasAssessments = false,
      this.summaryReason = '',
    });
  }
  ```

- [ ] **Step 1: Define `StudentRecordCheckResult` model and abstract method in `student_repository.dart`**
- [ ] **Step 2: Implement `checkStudentAcademicRecords` in `SupabaseStudentRepository`**
  - Check `attendance_records` where `student_id = studentId`.
  - Check `student_classwork_submissions` where `student_id = studentId`.
  - Check `term_grades` where `student_id = studentId`.
  - Check `assessment_attempts` where `student_id = studentId`.
  - Return detailed `StudentRecordCheckResult`.
- [ ] **Step 3: Run static analysis to verify compilation**
  Run: `flutter analyze lib/data/repositories/supabase_student_repository.dart`

---

### Task 2: Refine `permanentlyDeleteStudent` in `SupabaseStudentRepository`

**Files:**
- Modify: `lib/data/repositories/supabase_student_repository.dart:1010-1060`

**Interfaces:**
- Produces: `Future<bool> permanentlyDeleteStudent(String id, [String? subjectId])`

- [ ] **Step 1: Add offering resolution to `permanentlyDeleteStudent`**
  - If `subjectId` is provided, check if it matches `subject_offering_id` or find corresponding offering from `subject_offerings`.
  - Delete matching record in `student_enrollments`.
  - Check if student has remaining enrollments in other classes.
- [ ] **Step 2: Clean up orphaned student account and credentials**
  - If no remaining enrollments:
    - Delete from `parent_student_links`
    - Delete from `student_settings`
    - Delete from `student_profiles`
    - Delete from `users`
    - Delete from Firebase Auth via `FirebaseAuthAdminService.deleteUser(uid: id)`
  - Invalidate caches (`teacher_students_`, `attendance_`).
- [ ] **Step 3: Run static analysis to verify**
  Run: `flutter analyze lib/data/repositories/supabase_student_repository.dart`

---

### Task 3: UI Integration in `TeacherStudentManagementTab`

**Files:**
- Modify: `lib/features/teacher/sub_features/class_management/widgets/teacher_student_management_tab.dart`

**Interfaces:**
- Consumes: `SupabaseStudentRepository.checkStudentAcademicRecords`, `SupabaseStudentRepository.permanentlyDeleteStudent`

- [ ] **Step 1: Add Delete icon button in archived row actions**
  - Locate `if (_showArchivedStudents)` branch (where `Restore Student` icon exists).
  - Add `IconButton` with `Icons.delete_outline`, red accent color, tooltip `"Permanently Delete"`.
  - Connect to `_handlePermanentlyDeleteStudent(s)`.
- [ ] **Step 2: Implement `_handlePermanentlyDeleteStudent(UserModel student)`**
  - Pre-flight check:
    ```dart
    final check = await SupabaseStudentRepository().checkStudentAcademicRecords(
      student.id,
      student.enrolledSubjectId,
    );
    ```
  - If `check.hasRecords`:
    Show `AppModals.showErrorDialog`:
    - Title: `'Cannot Delete Student'`
    - Message: `'${student.fullName} cannot be permanently deleted because they have existing academic records (${check.summaryReason}).\n\nTo preserve academic history and DepEd compliance, please keep this student in the archives instead of deleting.'`
  - If `!check.hasRecords`:
    Show `AppModals.showTypeToConfirmDeleteDialog`:
    - Title: `'Permanently Delete Student'`
    - Message: `'Are you sure you want to permanently delete ${student.fullName}?\n\n• This student has NO attendance records, grades, or classwork submissions.\n• This action is permanent and IRREVERSIBLE.\n• Their profile and account records will be permanently erased.'`
    - Required text: `'I confirm'`
  - On confirm:
    Call `await SupabaseStudentRepository().permanentlyDeleteStudent(student.id, student.enrolledSubjectId);`
    Call `await _loadData(forceRefresh: true);`
    Show toast: `AppTopToast.success(context, '${student.fullName} has been permanently deleted.');`
- [ ] **Step 3: Run static analysis to verify**
  Run: `flutter analyze lib/features/teacher/sub_features/class_management/widgets/teacher_student_management_tab.dart`

---

### Task 4: Verification and Knowledge Graph Update

- [ ] **Step 1: Run static analysis across modified files**
- [ ] **Step 2: Run `graphify update .` to keep knowledge graph in sync**
- [ ] **Step 3: Test deletion guard with an active/recorded student and an empty student in Supabase**
