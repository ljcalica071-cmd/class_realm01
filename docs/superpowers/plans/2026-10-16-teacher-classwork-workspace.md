# Teacher Classwork Workspace Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace mock-backed teacher classwork with persisted Supabase classwork, a Grade/Subject/Section/Term/Status workspace, and validated multi-section WW/PT creation.

**Architecture:** Extend `ActivityModel` and `TeacherClassworkRepository` to represent the SQL fields already applied to Supabase and to expose enrolled teacher offerings and occupied gradebook slots. Keep the workspace and creation dialog repository-driven; create one classwork row per selected offering with a shared batch UUID and that section's due date, without changing quiz or examination behavior.

**Tech Stack:** Flutter/Dart, Supabase Flutter client, `file_picker`, Flutter widget/unit tests.

**Spec:** User-provided Task Part 1 of 3 (2026-10-16); prerequisite SQL was reported as already applied to the Supabase project.

## Global Constraints

- Limit this work to teacher classwork activities/assignments and performance tasks; do not change Examination (EX) or quiz-builder behavior.
- Use the existing `classwork_items`, `classwork_attachments`, and enrollment tables; do not apply remote SQL or add a migration.
- Persist `classwork_type`, `grading_category`, `term_number` (1–3), `gradebook_column_index` (1–10), `batch_group_id`, `target_student_ids`, `is_published`, `is_archived`, `deadline`, and `updated_instructions_at`.
- Use one classwork row per selected section/offering, one shared batch UUID, and an independently nullable deadline per row.
- Show only active teacher offerings/sections with enrolled students in classwork creation and applicable workspace filters.
- Reject past dates and deadlines not more than five minutes in the future; preserve the exact validation message from the task.
- Allow no more than one teacher attachment per classwork item; allow only PDF, DOC, or DOCX with matching MIME types and a maximum size of 3,145,728 bytes.
- Do not silently replace failed Supabase reads/writes with mock data or success-shaped values.
- Preserve unrelated existing worktree changes, including the existing `ScheduleModel.subjectName` edit in `academic_models.dart`.

## Review Focus

- A subject offering without enrolled learners must not appear as a selectable section or be accepted for creation; test the offering loader and selection state.
- The gradebook slot selected for a batch must be free for every selected offering, term, and category; test shared-slot availability and the no-free-slot case.
- A missing deadline stays null, while a same-day deadline at or within five minutes is rejected; test both branches at the form boundary.
- The exact 3 MiB file-size boundary and matching extension/MIME pair must be enforced in both the form and repository; test the boundary and mismatches.
- Supabase query, write, or upload failures must remain visible and must not produce mock classwork or a success-shaped return; test repository propagation and workspace error state.

---

### Task 1: Classwork model and real Supabase repository

**Files:**
- Modify: `lib/models/academic_models.dart`
- Modify: `lib/data/repositories/teacher_classwork_repository.dart`
- Modify: `lib/data/repositories/supabase_teacher_classwork_repository.dart`
- Test: `test/data/repositories/teacher_classwork_repository_test.dart`
- Test: `test/models/academic_models_test.dart` (create if absent)

**Interfaces:**
- Extend `ActivityModel` to round-trip the task's classwork fields, including nullable deadline, classwork type/category, term/slot, batch id, selected student ids, archived state, and instruction update timestamp.
- Extend `TeacherClassworkRepository` with typed operations to load active teacher offerings with enrolled students, load occupied WW/PT slots by offering/term/category, and persist a batch of classwork items.
- Retain a single-item save path for edits; all repository failures propagate to callers.

- [ ] Write failing tests for JSON mapping of every added classwork field, deadline nullability, the 3,145,728-byte limit, disallowed extension/MIME pairs, actual Supabase insert/update payloads, and propagated read/upload/write errors.
- [ ] Run `flutter test test/models/academic_models_test.dart test/data/repositories/teacher_classwork_repository_test.dart` and confirm failures are caused by missing behavior.
- [ ] Implement the typed model and repository operations. Query teacher-owned active offerings and enrolled student IDs from Supabase; query active gradebook slots for WW/PT; persist category/type, term, slot, batch, targeting, publication, archive, deadline, and instruction timestamp fields. Preserve/reuse existing attachment behavior while enforcing one file per item and the 3 MiB allowlist.
- [ ] Run the same targeted tests and confirm model mapping, slot/enrollment retrieval, batch persistence, validation, and failure propagation.

### Task 2: WW/PT creation, batching, and deadline validation

**Files:**
- Modify: `lib/features/teacher/sub_features/assessments/screens/create_requirement_flow.dart`
- Modify: `test/features/teacher/create_requirement_flow_test.dart`
- Modify: repository fakes in `test/features/teacher/teacher_classwork_list_test.dart` if interface changes require it.

**Interfaces:**
- The dialog accepts the workspace-selected term and optional grade/subject/section context, and uses the injected classwork repository for offerings, occupied slots, and persistence.
- WW permits `activity` or `assignment` with category `ww`; PT fixes type `performance_task` and category `pt`.
- A multi-section save sends one item per selected offering with a shared UUID batch group and the selected offering's due date, nullable when “No Due Date” is selected.

- [ ] Write failing widget tests for WW Activity/Assignment type choice, PT mapping, term and column defaults, subject/section selection, select-all, per-section deadlines, copying a deadline, no-due-date, optional single-section student targeting, reuse prefill, draft/publish values, and multi-section batch payload.
- [ ] Write failing date tests for disabled past dates and the exact “Due date and time cannot be in the past.” error when a same-day time is not more than five minutes ahead.
- [ ] Write failing attachment tests for one-file-only selection, allowed extension/MIME pairs, the exact size boundary, and rejection above 3,145,728 bytes.
- [ ] Run `flutter test test/features/teacher/create_requirement_flow_test.dart` and verify the new cases fail for missing behavior.
- [ ] Implement the multi-step form using the repository-provided active offerings and occupied columns; select the next shared free slot across selected offerings, and prevent publish when no common slot is free. Set `firstDate` to today, validate the five-minute threshold at submit, keep repository errors inline, and preserve entered state when saving fails.
- [ ] Run the widget tests and verify all requested behavior, including draft vs. publish persistence and reuse without submissions.

### Task 3: Workspace filters and mock-free classwork wiring

**Files:**
- Modify: `lib/features/teacher/sub_features/assessments/widgets/teacher_unified_assessments_tab.dart`
- Modify: `lib/features/teacher/screens/teacher_dashboard_screen.dart`
- Test: `test/features/teacher/teacher_classwork_list_test.dart`

**Interfaces:**
- The workspace receives repository-loaded classwork and repository-backed active offerings; grade/subject/section/term/status filters affect WW/PT classwork only.
- The existing EX tab and quiz-builder flow retain their existing data/actions.
- Workspace create actions pass the current term and applicable subject/section context to the dialog; refresh reloads classwork after save/archive.

- [ ] Write failing widget tests for grade-level, subject, enrolled-section, term, and Active/Archived filters; verify WW/PT create button labels and that EX remains unchanged.
- [ ] Write failing tests proving classwork read/delete errors do not fall back to `MockDatabase` and that archived rows remain visible under the Archived filter.
- [ ] Run `flutter test test/features/teacher/teacher_classwork_list_test.dart` and confirm the regressions.
- [ ] Implement the structured filter bar and category-specific `+ Create Activity / Assignment` / `+ Create Performance Task` buttons. Remove mock fallback for classwork reads and writes while preserving quiz/exam mock behavior.
- [ ] Run the targeted workspace tests and verify filtering, refresh, archive, and error states.

### Task 4: Required verification

**Files:**
- No additional files unless a failing test identifies a task-related correction.

- [ ] Run `flutter test test/features/teacher/create_requirement_flow_test.dart test/data/repositories/teacher_classwork_repository_test.dart test/features/teacher/teacher_classwork_list_test.dart test/models/academic_models_test.dart`.
- [ ] Run `flutter analyze` and resolve diagnostics introduced by this task.
- [ ] Review the final diff for unrelated changes, SQL/schema assumptions, altered quiz/EX behavior, swallowed repository failures, and attachment constraints.
