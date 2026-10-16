# Teacher Classroom Setup UI, Subject Colors, Edit Flow, & Safe Cascade Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

---

### Overview
This plan refactors the Teacher Classroom Setup experience, provides a centralized deterministic 16-color palette for teacher subjects, adds an Edit Subject & Sections flow with cross-feature sync, fixes the archive state filtering bug, redesigns the archived cards with side-by-side danger action buttons, adds Term Block required validation, and implements a safe foreign-key cascade cleanup for subject and section deletions.

---

### Files Affected
- `lib/core/theme/subject_palette.dart` (New): Centralized 16-color curated accessible palette with WCAG AA contrast helpers and deterministic assignment.
- `lib/data/repositories/subject_repository.dart` (Modified): Update subject/section methods, safe cascade delete for subject and single offering, fix archive/restore cache sync, strictly filter active vs archived in both cloud and local cache.
- `lib/features/teacher/sub_features/setup/widgets/teacher_classroom_setup_tab.dart` (Modified): Remove secondary schedule button, remove subject logo/avatar box, relocate active/archived toggle button, add Edit icon & edit mode in form, add Term Block required validation, redesign archived card footer with side-by-side buttons, wire safe section deletion prompt.
- `lib/features/teacher/widgets/timetable_grid_widget.dart` (Modified): Wire `SubjectPalette` to schedule tiles for consistent color and accessible contrast.
- `test/features/teacher/teacher_classroom_setup_tab_test.dart` (New / Modified): Unit and widget tests covering active/archived toggle relocation, full-width Add Students button, Edit button, Term Block validation, and archive filtering.

---

### Proposed Tasks

#### Task 1: Create Centralized `SubjectPalette` with Accessible High-Contrast Colors
- [ ] Create `lib/core/theme/subject_palette.dart` with 16 curated high-contrast colors (Royal Blue, Emerald, Violet, Amber/Gold, Rose, Cyan, Indigo, Teal, Coral, Magenta, Lime-Green, Slate-Blue, Plum, Deep Ocean, Terracotta, Bronze).
- [ ] Provide `getColorForSubject(String subjectName, {List<String>? teacherSubjectNames, int? index})` ensuring zero duplicate colors for a teacher's subjects.
- [ ] Provide `getPastelBackground(Color color, bool isDark)` and `getTextColor(Color color, bool isDark)` ensuring WCAG AA (>= 4.5:1) contrast.
- [ ] Write unit test in `test/core/theme/subject_palette_test.dart` verifying deterministic unique assignment and contrast ratios.

#### Task 2: Repository Updates: Safe Cascade Delete, Edit Subject/Sections, & Cache-Accurate Archive Filtering
- [ ] In `lib/data/repositories/subject_repository.dart`, implement `deleteSubjectOffering` with proper child-to-parent deletion order:
  1. `submission_attachments` -> `student_classwork_submissions` -> `classwork_attachments` & `classwork_extensions` -> `classwork_items`
  2. `anti_cheating_logs` & `assessment_responses` -> `assessment_attempts` -> `assessment_question_options` -> `assessment_questions` -> `digital_assessment_extensions` -> `digital_assessments`
  3. `learning_materials` -> `folders`
  4. `attendance_records`, `gradebook_term_sheets`, `term_grades`, `teacher_schedule`, `student_enrollments`
  5. `subject_offerings`, clean up orphaned sections/subjects.
  6. Clean up `AppDatabase` (Drift) and `LocalStorageService`.
- [ ] Implement `deleteSingleOffering(String offeringId)` using the same safe cascade cleanup for removing a single section offering.
- [ ] Implement `updateSubjectAndSections(...)` to update subject name, grade level, grading weights, term configurations, section names, adding new sections and deleting removed sections.
- [ ] Fix `archiveSubjectOffering` and `restoreSubjectOffering` to immediately update `subject_offerings.is_archived` in Supabase, update Drift SQLite `AppDatabase`, and update `LocalStorageService` teacher subjects cache.
- [ ] Ensure `getTeacherSubjects` strictly filters `is_archived == false` in both cloud and local Drift/LocalStorage paths.

#### Task 3: Classroom Setup UI: Card Cleanup, Toggle Relocation, & Term Block Validation
- [ ] In `lib/features/teacher/sub_features/setup/widgets/teacher_classroom_setup_tab.dart`:
  - **A.1**: Remove secondary "Schedule" button next to "Add Students", and expand `Add Students` to span the full card footer width.
  - **A.2**: Remove the colored square avatar/icon box next to the subject name. Align the Grade Level badge and Subject Name cleanly to the left edge of the card header.
  - **B.1 & B.2**: Remove the active/archived toggle pill from the top banner. In the section title bar, remove the `Back to Active Subjects` text button, and add the toggle button at the far right styled with `AppButton.outline`.
  - **C.1**: Wire `SubjectPalette` for subject card accent border and tints.
  - **D.1**: Add Term Block required validation: red asterisk on label, red border on error, and `! Term block is required.` error message below the field.

#### Task 4: Classroom Setup UI: Edit Subject & Sections Flow & Section Removal Warning
- [ ] In `_buildResponsiveSubjectCard`, add an Edit icon button (`LucideIcons.pencil`) next to the Archive icon button.
- [ ] Clicking Edit opens the form pre-populated with current subject name, grade level, term configuration, grading weights, and sections.
- [ ] Form title displays "Edit Subject & Sections", submit button displays "Save Changes".
- [ ] Saving calls `SubjectRepository.instance.updateSubjectAndSections(...)`, reloads subjects, and syncs across tabs.
- [ ] When removing a section that is already persisted in database: show a warning confirmation dialog before removing, and call `deleteSingleOffering`.

#### Task 5: Classroom Setup UI: Redesign Archived Subject Card Actions
- [ ] On cards in `ARCHIVED SUBJECTS`:
  - Remove small top-right `Restore` and `Delete` icon buttons in the header.
  - Replace the single footer button with two side-by-side full-styled buttons (`Row` with `Expanded` children and `12px` gap):
    1. `Restore Subject` (left): Outlined blue button with restore icon.
    2. `Delete Permanently` (right): Outlined danger red button (`theme.colorScheme.error`) with trash icon and subtle red tint.
- [ ] Wire the `Delete Permanently` button to `_confirmPermanentDelete(subject)`.

#### Task 6: Wire `SubjectPalette` in `TimetableGridWidget`
- [ ] In `lib/features/teacher/widgets/timetable_grid_widget.dart`, replace random pastel hashing with `SubjectPalette` so that each subject has a consistent accessible color matching its Classroom card, with WCAG AA compliant text color.

#### Task 7: Verification & Testing
- [ ] Write tests in `test/features/teacher/teacher_classroom_setup_tab_test.dart` and `test/core/theme/subject_palette_test.dart`.
- [ ] Verify all code compiles without errors or regressions.
