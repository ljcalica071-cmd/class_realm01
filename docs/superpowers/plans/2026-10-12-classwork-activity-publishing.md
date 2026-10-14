# Classwork Activity Publishing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish teacher activities/assignments and performance tasks to Supabase so enrolled students can see their details and securely open an optional teacher attachment.

**Architecture:** Keep file bytes in a private Supabase Storage bucket. A Firebase-authenticated teacher classwork Edge Function verifies teacher/offering ownership, issues one-use upload authorization, persists classwork and attachment metadata, and handles teacher list/edit/delete operations; the student dashboard function returns short-lived signed links only for classwork in the authenticated student's enrolled offerings. Flutter uses a repository for persisted teacher classwork, inline validation in the existing create/edit dialog, and a student attachment action that opens the signed URL externally.

**Tech Stack:** Flutter/Dart, `file_picker`, `url_launcher`, Supabase PostgreSQL/Storage/Edge Functions (Deno + `supabase-js`), Firebase ID-token verification.

**Spec:** `docs/superpowers/specs/2026-10-12-classwork-activity-publishing-design.md`

## Global Constraints

- One classwork item targets one explicit subject offering.
- Allow zero or one PDF, DOC, or DOCX attachment per classwork item.
- Enforce a maximum file size of 5 MiB (5 * 1024 * 1024 bytes).
- Title, total points, and detailed instructions are required and display an asterisk.
- Respect database text limits: title is at most 100 characters and detailed instructions at most 1,000 characters.
- Total points remain whole numbers from 10 through 100.
- Validation errors are shown inline with a red field outline; do not show validation errors in modal dialogs.
- Keep classwork attachments private; expose only short-lived signed download links to enrolled students.
- Verify Firebase teacher identity and subject-offering ownership server-side; never expose service-role credentials to Flutter.
- Persist edit/delete actions and clean up replaced/deleted Storage objects without affecting unrelated mock-backed quizzes or exams.

## Review Focus

- A 9, 10, 100, 101, blank, or non-integer score must show the correct inline state; test at the form boundary.
- A file with a disallowed extension/MIME type, unreadable bytes, or a size of 5 MiB + 1 byte must be rejected before publish and by the backend; test client and shared backend validation.
- An authenticated teacher attempting to write to another teacher's offering must be rejected; test the Edge Function authorization path.
- An un-enrolled student must not receive a classwork item or signed attachment link; test the student classwork query/response path.
- A Storage or database failure during create/replace/delete must preserve recoverable state and report the failure; test cleanup decisions and retained form state.

---

### Task 1: Secure classwork storage and teacher Edge Function

**Files:**
- Create: `supabase/migrations/005_classwork_private_attachments.sql`
- Create: `supabase/functions/_shared/classwork_validation.ts`
- Create: `supabase/functions/_shared/classwork_validation_test.ts`
- Create: `supabase/functions/teacher-classwork/index.ts`
- Test: `supabase/functions/teacher-classwork/index_test.ts`

**Interfaces:**
- Edge Function actions: `list`, `create_upload`, `create`, `update`, and `delete`.
- `create_upload` accepts `subject_offering_id`, `file_name`, `mime_type`, and `file_size_bytes`; returns `storage_path` and a one-use signed upload token.
- `create`/`update` accept classwork metadata, the offering ID, and an optional previously authorized `storage_path`; return the persisted activity and optional attachment metadata.
- `list` returns only classwork for subject offerings owned by the authenticated teacher.
- `delete` accepts a classwork ID and deletes its row and private object only after ownership is verified.
- Shared validation exports a MIME/extension validator and a 5 MiB size validator.
- Export a handler factory with injectable Firebase verification and Supabase admin client dependencies so request authorization and cleanup paths can be tested without deployed secrets.

- [ ] **Step 1: Write failing tests** in `classwork_validation_test.ts` for PDF/DOC/DOCX MIME-extension pairs, unsupported files, exactly 5 MiB, and 5 MiB + 1 byte; write `index_test.ts` cases for non-teacher identity, unowned/archived offerings, successful create/list, and create/update/delete cleanup failure paths.
- [ ] **Step 2: Run the tests and verify they fail** with the expected missing/incorrect validator result:
  `deno test supabase/functions/_shared/classwork_validation_test.ts`
- [ ] **Step 3: Add the forward migration** creating a private `classwork_attachments` bucket with the three allowed MIME types and a 5,242,880-byte limit; add nullable `storage_path` to `public.classwork_attachments` while retaining `storage_url` for compatibility.
- [ ] **Step 4: Implement shared validation and the teacher Edge Function.** Use `requireFirebaseUser`; require `users.role = 'teacher'` and `teacher_settings.status = 'active'`; verify the caller owns a non-archived offering for every action; constrain upload paths to a teacher-scoped unpredictable path; verify uploaded-object metadata before persistence; compensate failed writes with Storage cleanup; keep old objects until replacement/deletion database changes succeed.
- [ ] **Step 5: Run the validation tests** and verify all allowed/rejected boundary cases pass. Inspect migration and function diffs for public-read policies, service-role leakage, and unverified offering IDs.
- [ ] **Step 6: Commit** only the migration, helper, tests, and Edge Function.

### Task 2: Teacher classwork model and repository

**Files:**
- Create: `lib/data/repositories/teacher_classwork_repository.dart`
- Create: `lib/data/repositories/supabase_teacher_classwork_repository.dart`
- Modify: `lib/models/academic_models.dart`
- Test: `test/models/academic_models_test.dart`
- Test: `test/data/repositories/teacher_classwork_repository_test.dart`

**Interfaces:**
- `TeacherClassworkRepository.getActivities({String? subjectOfferingId}) -> Future<List<ActivityModel>>`
- `TeacherClassworkRepository.saveActivity({required ActivityModel activity, required String subjectOfferingId, Uint8List? fileBytes, String? fileName, String? mimeType, bool removeExistingAttachment = false}) -> Future<ActivityModel>`
- `TeacherClassworkRepository.deleteActivity(String activityId) -> Future<void>`
- `ActivityModel` carries the persisted `subjectOfferingId` and attachment name while retaining compatible defaults for existing mock-backed quiz/exam consumers.
- Repository calls the teacher Edge Function for authorization/persistence and uses the returned signed upload token with Supabase Storage; all failures propagate to the caller.

- [ ] **Step 1: Write failing model/repository tests** for mapping activity/performance-task type, one offering, deadline, score, attachment metadata, and upload rejection at 5 MiB + 1 byte.
- [ ] **Step 2: Run the targeted tests** and verify they fail for the missing persistence model/repository behavior:
  `flutter test test/models/academic_models_test.dart test/data/repositories/teacher_classwork_repository_test.dart`
- [ ] **Step 3: Implement the repository interface and Supabase-backed implementation.** Convert `ActivityModel` to/from the Edge Function JSON contract; upload bytes only after successful authorization; call create/update only after upload succeeds; preserve an existing attachment unless replacement/removal is explicit.
- [ ] **Step 4: Run the targeted tests** and verify serialization, upload validation, and error propagation pass.
- [ ] **Step 5: Commit** only the model, repository, and tests.

### Task 3: Inline validation, offering selection, and real teacher upload

**Files:**
- Modify: `lib/features/teacher/sub_features/assessments/screens/create_requirement_flow.dart`
- Modify: `lib/shared/widgets/inputs/app_text_field.dart` only if its existing `validator`/`InputDecoration` cannot render the required inline outline/error state
- Modify: `pubspec.yaml` and `pubspec.lock` to add `url_launcher` for opening student links externally
- Test: `test/features/teacher/create_requirement_flow_test.dart`

**Interfaces:**
- The dialog receives an injectable `TeacherClassworkRepository` and continues to use `SubjectRepository.getTeacherSubjects()` to load offerings.
- It selects exactly one offering and maps it to `ActivityModel.subjectOfferingId`.
- The file picker is single-select, custom type, extensions `pdf`, `doc`, `docx`, with bytes loaded for upload.

- [ ] **Step 1: Write failing widget tests** for the three required asterisk labels, simultaneous inline required errors after submit, red error border/message, score 9/10/100/101 behavior, and errors clearing when fields are corrected.
- [ ] **Step 2: Run the widget tests** and verify the missing labels/errors fail as expected:
  `flutter test test/features/teacher/create_requirement_flow_test.dart`
- [ ] **Step 3: Implement the form changes.** Use field validators for title (non-empty, max 100 characters), whole-number points (10-100), and instructions (non-empty, max 1,000 characters); replace section multi-select with one subject-offering selector; remove validation `AppModals`; keep field values/errors visible until corrected; show upload progress and inline file errors; retain values/file when repository save fails; preserve replace/remove attachment behavior for edit.
- [ ] **Step 4: Add tests for attachment selection and failure retention.** Verify invalid extensions and oversized files are rejected, picker cancellation is harmless, and a repository failure leaves the dialog and values intact.
- [ ] **Step 5: Add the compatible `url_launcher` dependency and run `flutter pub get`.**
- [ ] **Step 6: Run the targeted widget tests** and verify all required validation/upload states pass.
- [ ] **Step 7: Commit** only the form, any shared text-field change, dependency files if needed, and tests.

### Task 4: Persisted teacher list, edit, and delete

**Files:**
- Modify: `lib/features/teacher/screens/teacher_dashboard_screen.dart`
- Modify: `lib/features/teacher/sub_features/assessments/widgets/teacher_unified_assessments_tab.dart`
- Test: `test/features/teacher/teacher_classwork_list_test.dart`

**Interfaces:**
- The teacher dashboard loads activity/assignment/performance-task rows through `TeacherClassworkRepository`; quiz/exam data continues to use its existing source.
- Create/edit completion reloads teacher classwork from the repository.
- Edit and delete actions on persisted classwork call `saveActivity` and `deleteActivity`, not `MockDatabase`.

- [ ] **Step 1: Write failing tests** proving a repository-loaded activity is displayed after refresh and that edit/delete invoke the repository.
- [ ] **Step 2: Run the tests** and verify they fail because the teacher classwork list is mock-backed:
  `flutter test test/features/teacher/teacher_classwork_list_test.dart`
- [ ] **Step 3: Implement teacher-side loading and actions.** Keep loading/errors explicit, refresh after create/update/delete, and leave quiz/exam mock behavior unchanged.
- [ ] **Step 4: Run the list tests** and verify persisted create/edit/delete behavior passes.
- [ ] **Step 5: Commit** only the teacher dashboard/list changes and tests.

### Task 5: Student classwork attachments and signed viewer links

**Files:**
- Modify: `supabase/functions/student-dashboard/index.ts`
- Modify: `lib/models/student_dashboard_models.dart`
- Modify: `lib/features/student/shared/widgets/student_classwork_card.dart`
- Create: `supabase/functions/student-dashboard/index_test.ts`
- Test: `test/models/student_dashboard_models_test.dart`
- Test: `test/features/student/student_classwork_card_test.dart`

**Interfaces:**
- `student-dashboard` returns `attachments: [{file_name, mime_type, file_size_bytes, signed_url}]` for each published classwork item only after matching the student's enrolled offering; signed URLs expire after 15 minutes.
- `StudentClassworkModel` exposes the parsed instructions and zero-or-one attachment.
- `StudentClassworkCard` displays instructions and an attachment action that opens the signed URL with `LaunchMode.externalApplication`; an open failure is shown to the student instead of silently ignored.
- Export a student-dashboard handler factory with injectable auth/database dependencies so tests can verify no attachment link is issued to an un-enrolled student.

- [ ] **Step 1: Write failing Edge Function/model/widget tests** for an un-enrolled student receiving no classwork/link, attachment parsing, instructions rendering, attachment filename/action, absent attachment, and failed open feedback.
- [ ] **Step 2: Run the targeted tests** and verify they fail because the response/model/card omit attachments:
  `flutter test test/models/student_dashboard_models_test.dart test/features/student/student_classwork_card_test.dart`
- [ ] **Step 3: Extend `student-dashboard`.** Query attachments only for the already-filtered published/enrolled classwork IDs, create 15-minute signed URLs from private object paths, and surface signing/query failures explicitly.
- [ ] **Step 4: Implement the student model/card.** Render detailed instructions and an accessible attachment action; open the signed URL externally and report launch failure.
- [ ] **Step 5: Run the targeted tests** and verify authorized attachment rendering/opening passes.
- [ ] **Step 6: Commit** only the Edge Function, student model/card, dependency files if needed, and tests.

### Task 6: End-to-end verification

**Files:**
- No additional files unless a failing test identifies a required correction.

- [ ] **Step 1: Run all classwork-focused Flutter tests** in Tasks 2-5 together.
- [ ] **Step 2: Run `flutter analyze`** and resolve diagnostics introduced by this feature.
- [ ] **Step 3: Run Edge Function validation tests** with Deno if the runtime is available; if it is unavailable, report that limitation and do not claim those tests passed.
- [ ] **Step 4: Review the final diff** for accidental changes outside classwork activity publishing, private bucket access, and the authorized student signed-link path.
- [ ] **Step 5: Commit** any final fixes separately, limited to the files changed for this feature.
