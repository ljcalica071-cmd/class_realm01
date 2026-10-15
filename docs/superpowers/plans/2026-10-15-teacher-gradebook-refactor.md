# Refactor Teacher Gradebook UI, Dropdown Enrollment Filtering, Full-Cell Square Inputs, and Strict Per-Offering/Per-Term Data Isolation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the ClassRealm Teacher Gradebook to remove redundant headers and metadata pills, filter offerings to only those with enrolled students, provide a friendly informational note for zero-enrollment states, transform input cells into full-cell square spreadsheet-style targets, and enforce strict per-offering and per-term data isolation.

**Architecture:**
1. Clean and modernize UI headers in `teacher_gradebook_tab.dart` by removing duplicate page titles and card header metadata pills, adding an informational state banner when zero students are enrolled while keeping the grid layout visible.
2. Upgrade `gradebook_grid_cell.dart` to sharp rectangular/square spreadsheet-style cells with maximized hit-targets and prominent focus indicators.
3. Filter offerings in `SubjectRepository` so Gradebook dropdowns only display subjects/sections with active enrolled students.
4. Ensure `SubjectRepository.getGradebookTermSheet` and `_decodeSheet` gracefully handle new/empty sheets without raising false error banners, using standard JSON structure (`ww`: 1..10, `pt`: 1..10, `ex`: st1, st2, te).
5. Enforce strict keying and state isolation per `subject_offering_id` and `term_number` (1, 2, 3) to prevent state bleed across terms or sections.

**Tech Stack:** Flutter, Dart, Supabase Flutter, Shared Preferences, Drift SQLite, Google Fonts, DepEd DO 15 s. 2026 grading rules.

**Spec:** User request and requirements in prompt.

## Global Constraints
- Database schema in Supabase must NOT be altered.
- Preserve existing grading calculation rules in `DepEdGradingEngine`.
- Maintain dark and light theme token fidelity (`AppColors` & `AppTheme`).
- Tests must pass without regressions.

---

## Tasks

### Task 1: Gradebook Grid Cell Modernization & Square Spreadsheet Styling
**Files:**
- Modify: `lib/features/teacher/sub_features/grading/widgets/gradebook_grid_cell.dart`
- Modify: `test/features/teacher/gradebook_grid_cell_test.dart`

- [ ] **Step 1:** Review current cell tests in `test/features/teacher/gradebook_grid_cell_test.dart` and add tests asserting full-cell square styling, hit-test focus, and font styling.
- [ ] **Step 2:** Refactor `GradebookGridCell` in `lib/features/teacher/sub_features/grading/widgets/gradebook_grid_cell.dart`:
  - Replace pill border radius with sharp/square corners (`BorderRadius.circular(2)` or zero).
  - Expand hit area so clicking anywhere inside cell focuses the `TextField`.
  - Set `textAlignVertical: TextAlignVertical.center`.
  - Ensure font size is `13` with `FontWeight.w600`.
  - When focused, render full-cell highlight border (`1.5px` primary color).
- [ ] **Step 3:** Run widget tests in `test/features/teacher/gradebook_grid_cell_test.dart` to verify behavior.

### Task 2: Local Storage Gradebook Sheet Keying & JSON Schema Verification
**Files:**
- Modify: `lib/core/services/local_storage_service.dart`
- Modify: `test/core/services/local_storage_gradebook_test.dart`

- [ ] **Step 1:** Update `test/core/services/local_storage_gradebook_test.dart` to verify persistence of standard JSON schemas (`ww` 1..10, `pt` 1..10, `ex` st1, st2, te).
- [ ] **Step 2:** Ensure `saveGradebookSheet` and `getGradebookSheet` in `lib/core/services/local_storage_service.dart` use consistent caching keys (`gradebook_${offeringId}_term_$termNumber`) via `saveJson` and `getJson`.
- [ ] **Step 3:** Run test `test/core/services/local_storage_gradebook_test.dart` to confirm passing.

### Task 3: Filter Offerings to Enrolled Students & Fix Empty Sheet Handling
**Files:**
- Modify: `lib/data/repositories/subject_repository.dart`
- Modify: `lib/features/teacher/sub_features/grading/widgets/teacher_gradebook_tab.dart`

- [ ] **Step 1:** In `lib/data/repositories/subject_repository.dart`, add enrollment filtering logic (`getTeacherSubjects` with `onlyWithEnrollments: true` or dedicated method) by checking `student_enrollments` where `status == 'enrolled'`.
- [ ] **Step 2:** Fix `getGradebookTermSheet` in `lib/data/repositories/subject_repository.dart` so that when a sheet does not exist in Supabase (`maybeSingle()` returns `null`), it returns `null` cleanly instead of throwing, allowing the caller to initialize default empty data.
- [ ] **Step 3:** In `teacher_gradebook_tab.dart`, update `_loadOfferingSheets`:
  - When `getGradebookTermSheet` returns `null`, initialize a clean default sheet without setting `_sheetLoadError`.
  - Update `_decodeNumericColumns` to support both numeric indices and exam string keys (`st1`, `st2`, `te`, `ex1`, `ex2`, `ex3`) without throwing `FormatException`.
  - Set `_sheetLoadError` only upon an actual unhandled exception.

### Task 4: Header Cleanup, Zero-Enrollment Informational State, and Strict Term/Offering Data Isolation
**Files:**
- Modify: `lib/features/teacher/sub_features/grading/widgets/teacher_gradebook_tab.dart`

- [ ] **Step 1: Header Cleanup:**
  - In `_buildTopControls`, remove the duplicate `"Grades Management"` and `"Strengthened Senior High School Class Record"` column. Keep a clean, compact controls bar containing the Subject and Section selectors.
  - In `_buildSchoolInfoBar`, remove the row of pill badges (`Subject`, `Section`, `Grade`, `Terms`, `Units`, `S.Y.`), retaining only the clean subject title and section subtitle on the left.
- [ ] **Step 2: Zero-Enrollment State:**
  - If `_teacherSubjects` is empty or no offerings have enrolled students:
    - Retain the full Gradebook grid structure (with `"No students yet"` under Male/Female).
    - Display an informational note banner above the table:
      > *"Note: You currently have no subjects with enrolled students. Once you enroll students into a subject and section, they will appear in the dropdowns and you can begin recording scores here."*
    - Disable HPS and score editing while no offering with enrolled students is active (`isEnabled: false`).
- [ ] **Step 3: Strict Data Isolation & Serialization:**
  - Standardize in-memory structures and JSON encoding:
    - `hps`: `{"ww": {"1": ...}, "pt": {"1": ...}, "ex": {"st1": ..., "st2": ..., "te": ...}}`
    - `scores`: `{"<student_id>": {"ww": {"1": ...}, "pt": {"1": ...}, "ex": {"st1": ..., "st2": ..., "te": ...}}}`
  - Unique keys for cells:
    `ValueKey('hps-${_currentSubjectData?['id']}-term-$_selectedTerm-$category-$col')`
    `ValueKey('score-${_currentSubjectData?['id']}-term-$_selectedTerm-$studentId-$category-$col')`
  - In `_selectOffering` and `_changeTerm`, cancel existing save timers, save current sheet if valid, and cleanly re-initialize state maps so data never bleeds across subjects, sections, or terms.
- [ ] **Step 4: Live Computation & Persistence:**
  - Verify `DepEdGradingEngine` calculates metrics dynamically when scores or HPS change.
  - Verify debounce save persists to `LocalStorageService` and Supabase `gradebook_term_sheets`.

### Task 5: Final Review & Quality Verification
**Files:**
- Verify all modified files

- [ ] **Step 1:** Run `test/core/services/local_storage_gradebook_test.dart` and `test/features/teacher/gradebook_grid_cell_test.dart`.
- [ ] **Step 2:** Check for any compilation/analyzer issues across `lib/features/teacher/sub_features/grading/`.
- [ ] **Step 3:** Confirm all 4 major sections (A, B, C, D) of the user's requirements are completely satisfied.
