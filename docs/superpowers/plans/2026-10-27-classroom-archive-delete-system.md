# Classroom Setup Archive, Section Archiving & Permanent Deletion System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a comprehensive, elegant, and modular Archive & Deletion architecture for Classroom Setup with separate Subject and Section archive views, section-level restoration grouped under parent subjects, academic-record-guarded permanent deletion, and unified UI/UX Pro Max confirmation dialogs.

**Architecture:**
1. **Backend & Data Layer (`SubjectRepository`)**:
   - Provide section-level archiving (`archiveSingleOffering`) and restoring (`restoreSingleOffering`).
   - Guard permanent deletions with `hasAcademicRecords` / `hasSubjectAcademicRecords`: if grades, term sheets, or submissions exist, block hard deletion to preserve academic integrity. If no records exist, allow safe cascade deletion even with enrolled students (student user accounts remain completely untouched).
   - Fetch real enrolled student counts from `student_enrollments` for all active and archived sections.
   - Fetch and group archived sections by parent subject in `getTeacherArchivedSections`.
2. **Frontend UI/UX Layer (`teacher_classroom_setup_tab.dart`)**:
   - Add responsive header view switcher pills: `Active Subjects (X)`, `Archived Subjects (Y)`, and `Archived Sections (Z)`.
   - Build `_buildArchivedSectionsView`: displays parent Subject Cards containing only their respective archived sections, with real student count badges and an inline `[ 🔄 Restore Section ]` action button.
   - Create a single, modular, reusable confirmation dialog `_showConfirmationDialog` (DRY principle) for all Archive, Restore, and Delete actions with consistent 60-30-10 palette (`#487898` Steel Blue accent), Lucide vector icons, and English-only copy.
   - Soft-archive sections from the Edit Subject modal instead of immediately hard-deleting them.

**Tech Stack:** Flutter / Dart, Supabase Flutter, Drift SQLite, Lucide Icons Flutter, UI/UX Pro Max design system.

**Spec:** Direct user requirements from chat:
- Side-by-side header buttons with dynamic counters: `Archived Subjects (X)` and `Archived Sections (Y)`.
- Archived Sections view formatted identically to subject cards, grouping archived sections under their parent subject with WW/PT/EX weights and grade level.
- Section-by-section restore button `[ 🔄 Restore Section ]` placed to the right of the section name and real student count.
- Permanent deletion allowed if NO grade records or student submissions exist (even if students are enrolled). If grade records exist, permanent deletion is strictly blocked and teacher is advised to keep it archived.
- Explicit confirmation modal before ANY Archive, Restore, or Delete action asking: *"Are you sure you want to [archive / restore / delete]...?"*
- English-only text, clean and modular code without repetition.

---

## Global Constraints

- **Language:** English-only for all modal dialog titles, warning messages, snackbars, and buttons.
- **Design System:** Strictly follow `/ui-ux-pro-max` (60-30-10 color hierarchy: 60% surface white/dark `#121212`, 30% slate/borders, 10% Steel Blue `#487898` brand accent, red only for destructive delete, Lucide vector icons, 8dp grid spacing).
- **Academic Record Protection:** Under NO circumstances may a subject or section with existing grades, submissions, or score records be permanently deleted.
- **DRY Code Quality:** Zero duplicated dialog code; all confirmation flows must reuse the centralized modal helper.
- **Student Account Safety:** Student enrollments may be cleaned during safe un-enrolled deletion, but student auth and profile accounts are never deleted.

---

## Review Focus

1. **Academic Record Guard Integrity:** Attempting to permanently delete a subject or section that has entries in `gradebook_term_sheets`, `term_grades`, `student_classwork_submissions`, or `assessment_attempts` must be blocked with an informative explanation dialog.
2. **Zero-Record Permanent Delete with Enrolled Students:** Deleting a subject or section that has enrolled students but NO gradebook records or submissions must succeed, cleaning up enrollments while keeping student accounts intact.
3. **Archived Sections Grouping:** Restoring a section whose parent subject is also archived should cleanly restore the section and handle parent subject visibility.
4. **Real-time Student Counts:** Section student counts must reflect real-time counts from `student_enrollments` rather than defaulting to 0.
5. **Confirmation Modal Consistency:** Every single trigger of Archive, Restore, or Delete (for both Subject and Section) must display the confirmation modal before executing any mutation.

---

## Task Decomposition

### Task 1: Extend `SubjectRepository` with Section Archiving, Restoring, and Academic Records Guard

**Files:**
- Modify: `lib/data/repositories/subject_repository.dart:650-740`
- Modify: `lib/data/repositories/subject_repository.dart:945-1010`

**Interfaces:**
- Produces:
  - `Future<void> archiveSingleOffering(String offeringId)`
  - `Future<void> restoreSingleOffering(String offeringId)`
  - `Future<bool> hasAcademicRecords(String offeringId)`
  - `Future<bool> hasSubjectAcademicRecords(String teacherId, String subjectId)`
  - `Future<List<Map<String, dynamic>>> getTeacherArchivedSections(String teacherId, {String schoolYear})`
  - `Future<int> getOfferingEnrolledCount(String offeringId)`

- [ ] **Step 1: Implement `hasAcademicRecords` & `hasSubjectAcademicRecords`**
  Check `gradebook_term_sheets`, `term_grades`, `student_classwork_submissions`, and `assessment_attempts` for the offering ID. If count > 0 in any of these tables, return `true`.

- [ ] **Step 2: Implement `archiveSingleOffering` & `restoreSingleOffering`**
  Update `subject_offerings.is_archived` to `true` / `false` for the given offering ID, sync with Drift SQLite `AppDatabase.instance.updateOfferingsArchivedStatus`, and update `LocalStorageService`.

- [ ] **Step 3: Implement `getTeacherArchivedSections` & `getOfferingEnrolledCount`**
  Query `subject_offerings` where `teacher_id = teacherId AND is_archived = true`, joining `subjects`, `sections`, and querying enrolled student count from `student_enrollments`.

- [ ] **Step 4: Update `getTeacherSubjects` & `getTeacherArchivedSubjects` to include real student counts**
  Ensure each section in the response includes real enrolled count from `student_enrollments`.

- [ ] **Step 5: Verify syntax and method contracts**
  Inspect `subject_repository.dart` to verify error handling, null safety, and clean async operations.

---

### Task 2: Build Centralized Reusable Confirmation & Blocking Modals in `teacher_classroom_setup_tab.dart`

**Files:**
- Modify: `lib/features/teacher/sub_features/setup/widgets/teacher_classroom_setup_tab.dart:980-1040`
- Modify: `lib/features/teacher/sub_features/setup/widgets/teacher_classroom_setup_tab.dart:2220-2550`

**Interfaces:**
- Produces:
  - `Future<bool> _showActionConfirmationDialog({ required String title, required String message, required String confirmLabel, required IconData icon, Color? iconColor, Widget? detailsWidget, bool isDestructive = false })`
  - `void _showAcademicRecordsBlockedDialog({ required String itemName, required bool isSection })`

- [ ] **Step 1: Implement `_showActionConfirmationDialog`**
  Build a clean, UI/UX Pro Max modal (max width 440px, rounded 16px, 60-30-10 palette, Lucide icons, Cancel button and styled Action button).

- [ ] **Step 2: Implement `_showAcademicRecordsBlockedDialog`**
  Displays an amber/neutral alert dialog explaining that student grades or submissions exist, and the item cannot be permanently deleted to protect academic records.

- [ ] **Step 3: Refactor existing `_confirmArchive` and `_confirmPermanentDelete` to use the unified helper**
  Replace verbose duplicate dialog code with calls to `_showActionConfirmationDialog`.

- [ ] **Step 4: Add confirmation before `_restoreSubject`**
  Show `_showActionConfirmationDialog` asking *"Are you sure you want to restore [Subject Name] to your active classroom?"* before triggering restoration.

---

### Task 3: Implement Header View Switcher with Dynamic Counts (`Active`, `Archived Subjects`, `Archived Sections`)

**Files:**
- Modify: `lib/features/teacher/sub_features/setup/widgets/teacher_classroom_setup_tab.dart:90-120`
- Modify: `lib/features/teacher/sub_features/setup/widgets/teacher_classroom_setup_tab.dart:325-375`

**Interfaces:**
- Consumes: `_subjects`, `_archivedSubjects`, `_archivedSections`
- Produces:
  - Enum or state `_ViewMode { active, archivedSubjects, archivedSections }`
  - Dynamic buttons in title bar:
    - Active view: `[ 📦 Archived Subjects (X) ]` and `[ 👥 Archived Sections (Y) ]`
    - Archived Subjects view: `[ 📖 Active Subjects (Z) ]` and `[ 👥 Archived Sections (Y) ]`
    - Archived Sections view: `[ 📖 Active Subjects (Z) ]` and `[ 📦 Archived Subjects (X) ]`

- [ ] **Step 1: Define `_ClassroomViewMode` state and `_archivedSections` collection**
  Add `_ClassroomViewMode _viewMode = _ClassroomViewMode.active;` and `final List<_SubjectClass> _archivedSectionsSubjects = [];`.

- [ ] **Step 2: Update `_loadSubjects` to fetch archived sections**
  Call `SubjectRepository.instance.getTeacherArchivedSections(teacherId)` and populate `_archivedSectionsSubjects`.

- [ ] **Step 3: Render responsive side-by-side header action buttons**
  Replace the single toggle button with the side-by-side pill buttons matching UI/UX Pro Max aesthetics.

- [ ] **Step 4: Update title text and icon**
  Switch between `ACTIVE SUBJECTS`, `ARCHIVED SUBJECTS`, and `ARCHIVED SECTIONS` according to `_viewMode`.

---

### Task 4: Build the `Archived Sections` View with Parent Subject Cards & Inline Restore Buttons

**Files:**
- Modify: `lib/features/teacher/sub_features/setup/widgets/teacher_classroom_setup_tab.dart:580-610`
- Modify: `lib/features/teacher/sub_features/setup/widgets/teacher_classroom_setup_tab.dart:770-870`

**Interfaces:**
- Produces:
  - `Widget _buildArchivedSectionsView()`
  - Inline row for archived section: Section name, enrolled student count, and `[ 🔄 Restore Section ]` button.

- [ ] **Step 1: Implement `_buildArchivedSectionsView`**
  If `_archivedSectionsSubjects.isEmpty`, show a clean empty state with `LucideIcons.layers` and text *"No Archived Sections. Sections you archive will appear here under their respective subjects."*

- [ ] **Step 2: Render Subject Cards grouping archived sections**
  Render the parent Subject Card with its grade badge, subject title, WW/PT/EX weights, and card accent border.

- [ ] **Step 3: Render section rows with right-aligned `[ 🔄 Restore Section ]` button**
  In each section item:
  - Left: `LucideIcons.users` icon + Section Name (e.g. `STEM 11-A`).
  - Right: Real student count badge (e.g. `28 students`) + `[ 🔄 Restore Section ]` outlined button.

- [ ] **Step 4: Implement `_restoreSection` with confirmation dialog**
  - Show confirmation: *"Are you sure you want to restore section [Section Name] to [Subject Name]?"*
  - On confirm, call `SubjectRepository.instance.restoreSingleOffering(sectionId)`.
  - Refresh state and show confirmation toast.

---

### Task 5: Safe Soft-Archiving & Guarded Deletion in Subject Edit Form

**Files:**
- Modify: `lib/features/teacher/sub_features/setup/widgets/teacher_classroom_setup_tab.dart:1860-1895`
- Modify: `lib/features/teacher/sub_features/setup/widgets/teacher_classroom_setup_tab.dart:2520-2550`

**Interfaces:**
- Consumes: `SubjectRepository.instance.hasAcademicRecords`, `SubjectRepository.instance.archiveSingleOffering`

- [ ] **Step 1: Wire Section Row Trash Button to Soft-Archive**
  In `_removeSectionRow`, prompt teacher with confirmation: *"Archive Section [Name]? This will move the section to Archived Sections while preserving all records."*
  Call `SubjectRepository.instance.archiveSingleOffering(row.id)`.

- [ ] **Step 2: Guard Permanent Delete of Subject against Academic Records**
  In `_confirmPermanentDelete`:
  - First check `await SubjectRepository.instance.hasSubjectAcademicRecords(teacherId, subject.subjectId)`.
  - If `true`, call `_showAcademicRecordsBlockedDialog(itemName: subject.name, isSection: false)` and abort deletion.
  - If `false`, proceed to `_showActionConfirmationDialog` with reassuring notice that student accounts remain safe.

- [ ] **Step 3: Guard Permanent Delete of Section in Archived Sections view**
  If permanent delete is requested on an individual archived section:
  - Check `hasAcademicRecords(offeringId)`.
  - Block if academic records exist, or allow permanent cascade if no records exist.

---

### Task 6: End-to-End Verification and Polish

**Files:**
- Verify: `lib/data/repositories/subject_repository.dart`
- Verify: `lib/features/teacher/sub_features/setup/widgets/teacher_classroom_setup_tab.dart`

- [ ] **Step 1: Code Quality & Syntax Verification**
  Review all modified lines for null safety, unused imports, correct typography, and proper context mounting checks (`if (!mounted) return;`).

- [ ] **Step 2: UI/UX Pro Max Consistency Check**
  Verify 60-30-10 color palette adherence, button padding, icon sizing, and clear English copy across all dialogs.
