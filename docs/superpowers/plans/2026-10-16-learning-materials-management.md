# Teacher & Student Learning Materials Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement full lifecycle Learning Material and Folder management for Teachers with free-tier deduplication, 5 allowed upload formats, magic-byte checks, reference-counted deletion, and live in-app modal preview/editor, along with a strict read-only Student portal featuring hierarchical visibility, server-time enforcement, and offline download protection.

**Architecture:** Extended DTOs and magic-byte validators live inside `learning_material_repository.dart`. `SupabaseLearningMaterialRepository` manages deduplicated multi-section publishing, reference-counted deletion, scoped file replacement, and ancestor folder visibility checks. The teacher UI provides split folder navigation, multi-section publishing, and an in-app viewer/editor modal with auto-save drafts. The student screen provides strict enrollment-scoped read-only viewing with chunked paragraph rendering and debounced downloads.

**Tech Stack:** Flutter, Dart, Supabase Storage (`learning_materials` bucket), Supabase Database (`folders`, `learning_materials`, `student_enrollments`, `subject_offerings`), SharedPreferences (draft persistence), Lucide Icons, Flutter Test.

**Spec:** USER_REQUEST Task (Part 1 & 2): Teacher Learning Materials & Folder Management and Student Read-Only Portal.

## Global Constraints
- Strictly touch ONLY allowed files:
  - `lib/data/repositories/learning_material_repository.dart`
  - `lib/data/repositories/supabase_learning_material_repository.dart`
  - `lib/features/teacher/sub_features/schedule_and_lessons/widgets/teacher_learning_materials_tab.dart`
  - Helper widgets in `lib/features/teacher/sub_features/schedule_and_lessons/widgets/`
  - `lib/features/student/sub_features/academics/screens/student_learning_materials_screen.dart`
  - `lib/data/repositories/supabase_parent_repository.dart`
  - `test/features/teacher/learning_materials_test.dart`
  - `test/features/student/student_learning_materials_test.dart`
- DO NOT touch or modify: `academic_models.dart`, `mock_database.dart`, `teacher_dashboard_screen.dart`, or any Classwork/Gradebook files.
- Max file size: 3 MB (3,145,728 bytes).
- 5 allowed upload formats: PDF, DOC, DOCX, PPT, PPTX with magic-byte verification, plus Rich-Text Lesson (`text/markdown`, 0 bytes) and Embedded Cloud Link (`text/uri-list`, 0 bytes).
- Zero raw URLs displayed in teacher or student UI.
- Strict WCAG AA contrast (>= 4.5:1) in dark and light modes.

## Review Focus
1. An uploaded file claiming `.pdf` extension contains invalid bytes -> rejected with magic-byte verification error.
2. A material shared across Sections A and B has Section A deleted -> Section B retains access, physical storage object is NOT deleted until reference count reaches 0.
3. A parent folder is hidden or archived -> child folder and its materials are hidden from student query results even if child's own flag is visible.
4. Low-end device viewing a 50,000-character lesson note -> chunked into paragraph widgets in a `ListView.builder` without UI thread freeze, text selection disabled for students.
5. Student rapidly clicks download button 50 times -> locked in-flight, downloads exactly once, catches storage errors gracefully.

---

### Task 1: DTO Extensions, Magic-Byte Validator, & Repository Interface
**Files:**
- Modify: `lib/data/repositories/learning_material_repository.dart`
- Test: `test/features/teacher/learning_materials_test.dart`

- [ ] Add `MaterialFileValidator` with magic-byte checking for PDF (`0x25 0x50 0x44 0x46 0x2D`), DOC/PPT (`0xD0 0xCF 0x11 0xE0`), DOCX/PPTX (`0x50 0x4B 0x03 0x04`), 3MB limit (`3,145,728` bytes), sanitization (max 100 chars), and deterministic content fingerprinting.
- [ ] Extend `ClassRealmMaterial` with `availableFrom`, `updatedAt`, `isRichTextLesson`, `isEmbedUrl`, and `isLessonModule` helper properties.
- [ ] Extend `ClassRealmFolder` with `updatedAt` and hierarchy status helpers.
- [ ] Add repository methods to `LearningMaterialRepository` for:
  - `uploadDeduplicatedMaterial` across multiple section offerings.
  - `deleteMaterialReferenceCounted` with single-section vs all-sections logic.
  - `replaceMaterialFile` with scoped ('this section only' vs 'all shared sections') logic.
  - `getStudentMaterialsWithHierarchy` checking ancestor folder visibility and server UTC time.
  - `getServerUtcTime`.
- [ ] Write unit tests verifying validation: valid/invalid magic bytes, size cap, file name sanitization, and fingerprint calculation.

### Task 2: Supabase Implementation of Deduplication, Reference Counting, & Scoped Replacement
**Files:**
- Modify: `lib/data/repositories/supabase_learning_material_repository.dart`
- Test: `test/features/teacher/learning_materials_test.dart`

- [ ] Implement `uploadDeduplicatedMaterial`: uploads physical file once with content fingerprint key (`offerings/shared/<fingerprint>_<safe_ext>`), inserts one `learning_materials` row per selected target section's folder with matching `storage_path_url`.
- [ ] Implement `deleteMaterialReferenceCounted`: checks count of active rows referencing `storage_path_url`; if count > 1, deletes only the specified material row; if count <= 1, deletes row and purges physical file from `_bucket`.
- [ ] Implement `replaceMaterialFile`:
  - If `forSectionOnly`: uploads new file, updates target row with new `storage_path_url` and size.
  - If `forAllShared`: updates all rows sharing the old `storage_path_url` to the new URL, and purges the old file if no other references exist.
- [ ] Implement `getStudentMaterialsWithHierarchy`: joins ancestor folders, filters out any whose ancestor has `is_visible_to_students == false` or `is_archived == true`, and verifies `available_from <= serverNow`.
- [ ] Implement `getServerUtcTime` with fallback to `DateTime.now().toUtc()`.

### Task 3: Teacher In-App Material Viewer & Live Editor Modal with Auto-Save
**Files:**
- Create: `lib/features/teacher/sub_features/schedule_and_lessons/widgets/teacher_material_viewer_modal.dart`
- Modify: `lib/features/teacher/sub_features/schedule_and_lessons/widgets/teacher_learning_materials_tab.dart`
- Test: `test/features/teacher/learning_materials_test.dart`

- [ ] Build `TeacherMaterialViewerModal`:
  - Split / modal layout: Document Preview Area + Live Lesson Editor.
  - Document Preview Area: File badge, clean metadata (file size, type, updated date), graceful fallback card if corrupted with "Replace Corrupted File" button. Embed validator for Google Drive/Slides/YouTube with reminder.
  - Live Lesson Editor: Editable title, folder dropdown (move to folder), visibility switch, lesson notes editor (up to 50,000 chars, dark/light theme adaptive).
  - Auto-save draft: Timer-based draft saving every 3 seconds to `SharedPreferences` with "Draft saved" badge and restore prompt on reopening.
  - Scoped Replace File: File picker dialog with "Update this section only" vs "Update all shared sections" choices.
- [ ] Update `TeacherLearningMaterialsTab`:
  - Add Grade Level (`All`, `Grade 11`, `Grade 12`), Subject, and Section filters.
  - Add multi-section checklist in upload modal ("Publish to other sections of this subject").
  - Support Rich-Text Lesson Module creation (`text/markdown`, 0 bytes) and Embed URL creation (`text/uri-list`, 0 bytes).
  - Replace raw URLs with clean document cards showing badges, file sizes, visibility, and updated timestamps.
  - Enforce non-empty folder soft-archiving before permanent deletion.
  - Visually indicate that child items inside hidden/archived folders are hidden from students.

### Task 4: Student Read-Only Learning Materials Portal
**Files:**
- Modify: `lib/features/student/sub_features/academics/screens/student_learning_materials_screen.dart`
- Test: `test/features/student/student_learning_materials_test.dart`

- [ ] Enforce strict 100% read-only UI: remove any edit/delete/archive/upload controls.
- [ ] Add toggle between "Current Classes" and "Past / Archived Classes (Review Only)".
- [ ] Add irregular student deduplication: label offerings with Section & Term, deduplicate identical materials across offerings.
- [ ] Integrate hierarchical visibility: exclude any material whose parent or ancestor folder is hidden/archived, and check `available_from` against server UTC time.
- [ ] Build Student Reader Modal:
  - Document preview / embed view without raw URLs.
  - Chunked lesson reader: renders `description` using `ListView.builder` with paragraph blocks for 50,000 char chapters, smooth scrolling on low-end devices, theme-adaptive Dark/Light colors, text selection/copying disabled (`SelectionArea` omitted).
  - Debounced offline download: in-flight lock (`_downloadingIds`), catches `FileSystemException` and shows storage error dialog.
  - Fallback banner if file is corrupted/unreachable while keeping lesson notes readable.

### Task 5: Parent Repository Helper & Verification
**Files:**
- Modify: `lib/data/repositories/supabase_parent_repository.dart`
- Test: `test/features/teacher/learning_materials_test.dart`
- Test: `test/features/student/student_learning_materials_test.dart`

- [ ] Add read-only helper method in `supabase_parent_repository.dart` for viewing linked student learning materials with enrollment and hierarchy checks.
- [ ] Run widget and unit tests in `test/features/teacher/learning_materials_test.dart` and `test/features/student/student_learning_materials_test.dart`.
- [ ] Verify zero regressions and check formatting.
