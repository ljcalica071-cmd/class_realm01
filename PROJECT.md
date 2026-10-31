# ClassRealm — Senior High School Management System
**Master Project Architecture, Design System & Operational Specification**

---

## 1. System Overview

**ClassRealm** is an integrated Senior High School (SHS) management platform tailored specifically for Philippine educational institutions adhering to Department of Education (DepEd) curriculum guidelines and reporting standards (including School Form 2 / SF2 attendance registers). The platform unifies administrative records, class scheduling, interactive classroom tools, grading, and automated attendance management across web and mobile platforms.

### Core Architecture Highlights
- **Cross-Platform Client**: Built with Flutter (Dart 3.x) targeting Desktop Web (Teacher Admin), Android/iOS (Teacher Mobile, Student Portal, Parent Portal).
- **Backend Infrastructure**: Hybrid architecture combining **Firebase Authentication** for identity and session lifecycle with **Supabase PostgreSQL** for relational persistence, Row Level Security (RLS), real-time subscriptions, and Edge Function automation.
- **Local Persistence & Offline Sync**: Native SQLite backing via **Drift ORM** (`app_database.dart`), resilient offline queue (`OfflineSyncQueue`), and background sync coordination (`SyncCoordinator.dart`).
- **Hardware Integration**: Dual-path automated attendance pipeline comprising an autonomous **ESP32 microcontroller RFID reader** with LittleFS non-volatile ring buffering, and a zero-hardware **Mobile Phone NFC fallback** via `nfc_manager`.

---

## 2. Technology Stack & Key Dependencies

| Layer | Technologies / Packages | Version / Specification | Purpose |
|---|---|---|---|
| **Frontend Framework** | Flutter SDK | `>=3.3.0 <4.0.0` (Dart 3.x) | Cross-platform UI development for Web, Android, iOS |
| **Authentication** | Firebase Auth (`firebase_auth`) | `^5.4.4` | User identity, email/password, session tokens |
| **Cloud Database** | Supabase (`supabase_flutter`) | `^2.5.4` | Relational PostgreSQL, Realtime channels, RPC functions |
| **Local SQLite ORM** | Drift (`drift`, `drift_flutter`) | `^2.24.0` | Local database caching, offline queue, reactive queries |
| **Hardware NFC** | `nfc_manager` | `^3.5.0` | Reading ISO 14443-A RFID/NFC cards via teacher smartphones |
| **Network Listener** | `connectivity_plus` | `^6.1.0` | Real-time network reachability detection for sync triggers |
| **UI Design System** | Custom 60-30-10 Design Tokens | Defined in `AppTheme` | Accessible, unified styling across themes |
| **Iconography** | `lucide_icons_flutter` | `^3.1.20` | Semantic outline iconography |
| **Hardware Reader** | ESP-WROOM-32 (DevKit V1) | 240MHz Dual-Core, 4MB Flash | Autonomous classroom RFID card reader |
| **Firmware Stack** | FreeRTOS + LittleFS + ArduinoJson | C++17 | Core 1 RFID polling + Core 0 HTTPS cloud sync |

---

## 3. Design System & UI Architecture (60-30-10 Rule)

ClassRealm strictly adheres to the **60-30-10 Color Rule** across all screens, preventing visual fatigue and establishing clear visual hierarchy.

```
+-------------------------------------------------------+
|  60% Base / Background (Dominant Neutral Canvas)      |
|  - Light: #F5F5F5 (Warm off-white)                    |
|  - Dark:  #111827 (Deep midnight slate)               |
|                                                       |
|   +-----------------------------------------------+   |
|   |  30% Structural Surface (Cards, Tables, Nav)  |   |
|   |  - Light: #FFFFFF / #E8EBE2 (Card / Sage Nav)  |   |
|   |  - Dark:  #1F2937 / #263040 (Slate Surface)   |   |
|   |                                               |   |
|   |   +---------------------------------------+   |   |
|   |   |  10% Intentional Accent (Focus/CTAs)  |   |   |
|   |   |  - Light: #487898 (Steel Blue)         |   |   |
|   |   |  - Dark:  #60A5FA (Sky Blue Accent)   |   |   |
|   |   +---------------------------------------+   |   |
|   +-----------------------------------------------+   |
+-------------------------------------------------------+
```

### Semantic Categorical Tokens (`AppTheme`)
- **`catGreen` (`#16A34A`)**: Present, Verified, Success actions, Online status.
- **`catRed` (`#DC2626`)**: Absent, Danger, Inline Error borders, Unregistered card alert.
- **`catOrange` (`#D97706`)**: Late, Warning, At-Risk warning (>= 3 absences), Conflict alert.
- **`catSlate` (`#475569`)**: Excused, Neutral tags, Secondary metadata.
- **`catTeal` (`#0D9488`)**: RFID hardware scan badge, NFC hardware indicators.
- **`catBlue` (`#2563EB`)**: Academic links, information callouts.

### Typography & Component Layout Standards
- **Font Family**: Inter (Clean, legible sans-serif with high x-height).
- **Row Density**: Compact data table row height standardized at **44px** for maximum information density without clutter.
- **Card Badges**: Circular avatar/initials badges are strictly removed from data tables; records display clear typographic hierarchy: `Last Name, First Name M.I.` alongside DepEd LRN in monospace font.
- **Button Geometry**: All action buttons standardize on `BorderRadius.circular(10)` or `BorderRadius.circular(8)` for harmonized button geometry.

---

## 4. Strict UI Error Presentation Standard

To maintain professional user experience and prevent UI layout breakage, ClassRealm enforces a **Zero Technical Error Policy**:

### Mandatory Rules
1. **NO RAW TECHNICAL STRINGS**: Database exceptions (e.g. `PostgresException (code 23505)`), stack traces, or raw Dart error strings (`$e`) must NEVER be shown to the user. All errors pass through `AppModals.sanitizeErrorMessage()`.
2. **STRICTLY INLINE INPUT VALIDATION**: Form and input field validation errors (e.g., invalid card UID, missing date, invalid time threshold) MUST be rendered directly beneath the input container as **12px helper text with a 1.5px red border (`#DC2626`)**. The error clears immediately when the user alters input.
3. **MODAL DIALOGS FOR ACTION ALERTS**: Hardware scanning errors, RFID card assignment conflicts, cross-section tap alerts, and network sync notifications MUST be presented via centered modal dialogs (`AppModals.showErrorDialog` or `AppModals.showConfirmationDialog`).
4. **PROHIBITION OF SNACKBARS & FLOATING TOASTS**: Bottom SnackBars, floating toasts, and top banners are **STRICTLY PROHIBITED** for error feedback and scanner notifications. They obscure sticky action bars, disconnect error context from input fields, and violate classroom focus.

---

## 5. Attendance Domain Architecture

### 5.1 Dual-Path Attendance Pipeline
```
               [Student Physical RFID Card (13.56MHz)]
                                  |
         +------------------------+------------------------+
         |                                                 |
         v                                                 v
  [ESP32 Hardware Scanner]                      [Mobile Phone NFC Fallback]
  - Dedicated Classroom Unit                    - Teacher Android/iOS App
  - FreeRTOS Dual-Core (Core 1 Polling)         - nfc_manager Reader Session
  - LittleFS Flash Spool (>6,800 records)       - Drift SQLite OfflineSyncQueue
  - Independent Battery / 5V DC                 - Instant Haptic Feedback
         |                                                 |
         +------------------------+------------------------+
                                  |
                                  v
                  [Supabase PostgreSQL Cloud Backend]
                  - RPC: record_rfid_attendance()
                  - Batch RPC: record_rfid_attendance_batch() (bulk drain <2s / 100 scans)
                  - 3-Way Deterministic Conflict Engine
                  - Status Monotonicity & Earlier Timestamp Priority
                  - System Auto-Absent Promotion via Spool Drain
                  - Realtime Broadcast to Web & Mobile UI
```

### 5.2 Deterministic Conflict Resolution Engine
When scans synchronize asynchronously across offline hardware, mobile devices, and live teacher edits:
1. **Teacher Manual Override Prevents Overwrite**: Any manual mark set by a teacher (`recording_method = 'Manual'`) or Excused status represents administrative authority and is strictly immutable against automated hardware taps.
2. **System Auto-Absent Promotion (Fix 2)**: When an offline tap arrives for a student marked absent by the 23:59 EOD System job (`status = 'absent' AND recording_method = 'System'`), the delayed physical tap promotes the record to **Present** or **Late** with the physical tap timestamp (`recording_method = 'RFID'`).
3. **Earliest Physical Tap Promotes (Late -> Present)**: If a student tapped the door ESP32 at 07:55 AM (on time) while offline, but was later marked Late at 08:08 AM via mobile NFC due to sync delay, the earlier timestamp (07:55 AM) promotes the record to **Present**.
4. **Timestamp Priority for Matching Status (Fix 1)**: If a student is already marked Present (e.g. at 08:05 AM via Mobile NFC roll call) and an earlier on-time physical tap arrives from the ESP32 door reader (07:55 AM), `time_in` is updated to `07:55:00` and `remarks = 'Timestamp updated to earlier physical tap'`, returning status `TIMESTAMP_PROMOTED`.
5. **Status Monotonicity**: An automated scan can never downgrade a verified Present mark to Late or Absent.
6. **Schedule Bound & Cutoff Validation (Fix 3, Fix 4)**: Scans arriving outside the plotted class schedule window, beyond `absent_cutoff_mins`, or on non-scheduled days are rejected.

### 5.3 Daily 23:59 EOD Automated Auto-Absent
A server-side background job (executed via PostgreSQL stored procedure `fn_trigger_daily_auto_absent()` triggered by `pg_cron` at **15:59 UTC / 23:59 Asia/Manila** or Supabase Edge Function):
- Queries active classes plotted for the day of the week.
- Checks if the date is an active holiday in `school_holidays`. If so, skips execution entirely.
- Identifies enrolled students in active sections who possess NO attendance record for the date.
- Inserts automated `absent` records with `recording_method = 'System'` and remarks `'Auto-Absent (Unscanned at EOD)'`.
- Never overwrites existing `present`, `late`, or `excused` records.

---

## 6. Database Schema Overview

```
                          +------------------------+
                          |      users (Auth)      |
                          +-----------+------------+
                                      |
         +----------------------------+----------------------------+
         |                                                         |
         v                                                         v
+-----------------------+                                 +-----------------------+
|   student_profiles    |                                 |    parent_profiles    |
| - student_id (PK)     |                                 | - parent_id (PK)      |
| - lrn (UNIQUE)        |                                 +-----------+-----------+
| - rfid_uid (UNIQUE)   |<-----------+                                |
+-----------+-----------+            |                                v
            |                        |                    +-----------------------+
            v                        |                    | parent_student_links  |
+-----------------------+            |                    | - parent_id (FK)      |
|  student_enrollments  |            |                    | - student_id (FK)     |
| - student_id (FK)     |            |                    +-----------------------+
| - subject_offering_id |            |
+-----------+-----------+            |
            |                        |
            v                        |
+-----------------------+            |
|   subject_offerings   |            |
+-----------+-----------+            |
            |                        |
            +------------+           |
            |            |           |
            v            v           |
+----------------+  +----------------+------+     +-----------------------+
|teacher_schedule|  |  attendance_records   |     |    school_holidays    |
| - id (PK)      |  | - id (PK)             |     | - id (PK)             |
| - day_of_week  |  | - student_id (FK)     |     | - holiday_date (UQ)   |
| - start_time   |  | - subject_offering_id |     | - holiday_name        |
| - end_time     |  | - attendance_date     |     | - is_active           |
+-------+--------+  | - status              |     +-----------------------+
        |           | - recording_method    |
        |           | - time_in / time_out  |     +-----------------------+
        |           | - device_id           |     |     rfid_devices      |
        v           +-----------------------+     | - device_uid (UQ)     |
+----------------------+                          | - assigned_room       |
|  attendance_cutoffs  |                          | - last_sync_at        |
| - present_start_mins |                          +-----------------------+
| - present_grace_mins |
| - late_cutoff_mins   |
| - absent_cutoff_mins |
+----------------------+
```

### Table Specifications
1. **`student_profiles`**: Added `rfid_uid varchar(64) UNIQUE NULL` with index `idx_student_profiles_rfid_uid`.
2. **`attendance_records`**: Added `recording_method varchar(10) NOT NULL DEFAULT 'Manual' CHECK (recording_method IN ('Manual', 'RFID', 'System'))`, `time_in time`, `time_out time`, `device_id varchar(64)`, `updated_at timestamptz`.
3. **`attendance_cutoffs`**: Configurable thresholds per `subject_offering_id` and `schedule_id` enforcing chronological validation:
   $$\text{present\_grace\_mins} < \text{late\_cutoff\_mins} < \text{absent\_cutoff\_mins} \le \text{class\_duration}$$
   Enforced via strict `CHECK (absent_cutoff_mins > late_cutoff_mins)` and `trg_validate_attendance_cutoffs` database trigger preventing cutoffs from exceeding scheduled class duration.
4. **`school_holidays`**: Stores official institutional and national holidays; suppresses 23:59 auto-absent job and rejects live scans.
5. **`rfid_devices`**: Authoritative registry of physical ESP32 readers and mobile scanning endpoints.

---

## 7. Row Level Security (RLS) Policy Architecture

To ensure strict data privacy and isolation across Teacher, Student, and Parent accounts:

- **Students (`student_view_own_attendance`)**:
  - `FOR SELECT USING (student_id = public.current_auth_uid())`
  - Students can view ONLY their personal attendance records and summary metrics.
- **Parents (`parent_view_child_attendance`)**:
  - `FOR SELECT USING (EXISTS (SELECT 1 FROM parent_student_links psl WHERE psl.parent_id = public.current_auth_uid() AND psl.student_id = attendance_records.student_id))`
  - Parents can view ONLY records for their verified linked children.
- **Teachers (`teacher_manage_own_attendance`)**:
  - `FOR ALL USING (EXISTS (SELECT 1 FROM subject_offerings so WHERE so.id = attendance_records.subject_offering_id AND so.teacher_id = public.current_auth_uid()))`
  - Teachers have read/write access ONLY for classes assigned to their teacher profile.
- **Admins (`admin_all_attendance`)**:
  - Full institutional read/write access.

---

## 8. Code Layout & Repository Organization

```
c:\Users\Admin\AndroidStudioProjects\class_realm01\
├── android/                             # Android native platform files (NFC permissions)
├── ios/                                 # iOS native platform files (CoreNFC capabilities)
├── lib/
│   ├── core/
│   │   ├── services/
│   │   │   ├── mobile_nfc_service.dart  # Mobile NFC reader & Drift queue dispatcher
│   │   │   ├── supabase_service.dart    # Cloud backend client initialization
│   │   │   └── sync_coordinator.dart    # Background offline sync orchestrator
│   │   └── theme/
│   │       ├── app_colors.dart          # Palette tokens
│   │       └── app_theme.dart           # Master 60-30-10 theme configurations
│   ├── data/
│   │   ├── datasources/local/
│   │   │   ├── app_database.dart        # Drift SQLite database definition
│   │   │   └── tables.dart              # Drift tables (LocalAttendanceRecords, OfflineSyncQueue)
│   │   └── repositories/
│   │       ├── supabase_attendance_repository.dart # Cloud attendance queries & RPCs
│   │       └── supabase_schedule_repository.dart   # Class schedule & clash validation
│   ├── features/
│   │   ├── parent/                      # Parent portal (Child switcher, Attendance tab)
│   │   ├── student/                     # Student portal (View-only attendance, Empty state)
│   │   └── teacher/                     # Teacher portal (Roster table, RFID modal, Analytics)
│   ├── models/
│   │   ├── academic_models.dart         # Academic structures (ScheduleModel, Section)
│   │   └── attendance_workspace_models.dart # Roster, Record, Cutoff, Source models
│   └── shared/
│       └── widgets/
│           ├── badges/                  # AttendanceSourceBadge (RFID vs Manual)
│           ├── empty_states/            # AppEmptyState (60-30-10 compliant empty view)
│           └── modals/
│               ├── app_modals.dart      # Sanitized error & confirmation dialogs
│               └── rfid_assignment_modal.dart # Dual USB/NFC card assignment dialog
├── docs/                                # Technical & Architectural Specifications
│   ├── ATTENDANCE_REDESIGN_IMPLEMENTATION_PLAN.md # Master attendance overhaul plan
│   ├── ESP32_RFID_BUILD_GUIDE.md        # Hardware BOM, wiring, FreeRTOS code & tutorial
│   └── ATTENDANCE_VALIDATION_MATRIX.md  # Exhaustive edge cases, UI copy & validation matrix
├── supabase/
│   ├── functions/
│   │   └── daily-auto-absent/           # EOD 23:59 Supabase Edge Function
│   └── migrations/
│       └── 008_attendance_overhaul.sql  # SQL schema migration for attendance redesign
└── test/                                # Unit, widget, and repository test suites
```

---

## 9. Verification & Quality Assurance Protocol

Before any release or production deployment:
1. **Database Schema & Constraints**: Verify all migrations execute cleanly; verify unique constraints on `student_profiles.rfid_uid` and `(student_id, subject_offering_id, attendance_date)`.
2. **Drift Schema Parity**: Ensure `LocalAttendanceRecords` and `OfflineSyncQueue` match cloud payload contracts.
3. **UI Error Audit**: Ensure zero occurrences of `showSnackBar` or raw `$e` exceptions in attendance and student management modules.
4. **Hardware Bench Test**: Run the ESP32 offline buffering test (5 taps offline -> power cycle -> reconnect WiFi -> verify all 5 sync cleanly).
5. **Test Execution**: All automated unit and widget test suites must pass:
   ```powershell
   flutter test
   ```


---

## 10. Feature Inventory (R1–R6 Overhaul)

| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| F1.1 | 5-Slot Score Columns | Reduce default assessment score columns from 10 to 5 per category | M1 | R1 |
| F1.2 | Inline '+' Expansion Button | Inline '+' button in sub-headers up to 10 slots, hiding when 10 slots reached | M1 | R1 |
| F1.3 | Fix Duplicate Key Crash | Eliminate duplicate rows/keys `[gradebook-row-zV0ZGShD46TGOcXrfsLIX1Jd45j2-true]` | M1 | R1 |
| F1.4 | Fix Filter Duplication & Assertion | Symmetrical gender filtering ('All', 'Male', 'Female') without duplicate headers | M1 | R1 |
| F2.1 | Manage Students Font Standard | Standardize student names to legible, consistent 13.5–14pt font | M2 | R2 |
| F2.2 | Manage Parents Font Standard | Standardize parent names to legible, consistent 13.5–14pt font | M2 | R2 |
| F2.3 | Remove Checkbox Column | Remove unnecessary checkbox column adjacent to '#' in Manage Parents | M2 | R2 |
| F2.4 | Birthday Column Replacement | Replace 'SECTION' with 'BIRTHDAY' column (YYYY-MM-DD) in Manage Parents | M2 | R2 |
| F2.5 | Specific Subject Filter | Remove 'All Subjects' option; teachers select only specific assigned subjects | M2 | R2 |
| F2.6 | Table Header Overflow Fix | Eliminate horizontal RenderFlex overflow stripes in Manage Parents table headers | M2 | R2 |
| F3.1 | Attendance Typography & LRN Removal | Increase student name font to 14pt and remove LRN label underneath | M3 | R3 |
| F3.2 | Attendance Roster Lazy Loading | Load students lazily in batches of 20 per scroll | M3 | R3 |
| F3.3 | Inline RFID Tap-to-Link | Inline "Waiting for RFID..." badge capturing 8-char UID without popup modal | M3 | R3 |
| F3.4 | Action Button Reorganization | "Save Attendance" beside "Auto Absent", "Cut off rules" before "Take Attendance" | M3 | R3 |
| F3.5 | Filter Container Integration | Rename to "Analytics & History", embed date filters & export in filter box | M3 | R3 |
| F3.6 | Active Schedule Filtering | Filter dropdowns strictly list grades, subjects, sections with active schedules | M3 | R3 |
| F4.1 | Audit Log 20-Item Pagination | Structured pagination (20 items/page) with full First/Prev/Page/Next/Last controls | M4 | R4 |
| F4.2 | Full Student Names in Audit Logs | Display "Lastname, Firstname Middlename" instead of raw alphanumeric IDs | M4 | R4 |
| F4.3 | Dedicated Time In & Method Columns | Place Time In and Attendance Method in dedicated separate table columns | M4 | R4 |
| F5.1 | Client-Side Performance Caching | Frame-1 caching for Classroom Setup, Gradebook, Directory, Materials, Schedule | M5 | R5 |
| F5.2 | Cross-Viewport Responsiveness | Ensure layouts adapt responsively without overflow stripes across screens | M5 | R5 |
| F5.3 | 60-30-10 Color Rule Adherence | Strict adherence to background (60%), surface (30%), accent (10%) tokens | M5 | R5 |
| F6.1 | Student Portal Views | View-only attendance history and personal schedule in Student Portal | M6 | R6 |
| F6.2 | Parent Portal Child Attendance & Schedule | Connect linked child's attendance & schedule in Parent Portal | M6 | R6 |
| F6.3 | Multi-Tier Absence Push Notifications | Automated in-app & FCM push alerts at exactly 3, 5, and 10 absences | M6 | R6 |
| FE.1 | E2E Opaque-Box Test Suite | Comprehensive 4-Tier test suite verifying all R1–R6 requirements | E2E Track | All |

---

## 11. Milestones & Execution Plan

| # | Milestone Name | Scope | Dependencies | Status |
|---|----------------|-------|--------------|--------|
| M1 | Gradebook Optimization & Crash Fixes | `teacher_gradebook_tab.dart`, `gradebook_grid_cell.dart` | None | PLANNED |
| M2 | Manage Students & Parents UI Polish | `teacher_student_management_tab.dart`, `teacher_parent_management_tab.dart` | None | PLANNED |
| M3 | Attendance Improvements & Inline RFID | `attendance_roster_table.dart`, `teacher_attendance_tab.dart` | None | PLANNED |
| M4 | Attendance Audit & History Logs Refactoring | `attendance_history_analytics_view.dart`, `attendance_workspace_models.dart`, `supabase_attendance_repository.dart` | M3 | PLANNED |
| M5 | Performance Caching & Responsiveness | `AppDataCache`, `teacher_classroom_setup_tab.dart`, `teacher_gradebook_tab.dart`, `teacher_parent_management_tab.dart`, `supabase_learning_material_repository.dart`, `supabase_schedule_repository.dart` | M1, M2 | PLANNED |
| M6 | Student & Parent Portals & Multi-Tier Alerts | `parent_home_screen.dart`, `parent_attendance_tab.dart`, `supabase_attendance_repository.dart`, `firebase_auth_admin_service.dart` | M3, M4 | PLANNED |
| E2E | E2E Testing Suite (Tiers 1–4) | Requirement-driven opaque-box test suite (`test/e2e/`) | None (Parallel) | IN_PROGRESS |

---

## 12. Cross-Module Interface Contracts

### 1. `AttendanceWorkspaceRecord` (M3 ↔ M4 ↔ M6)
- Properties:
  - `studentName` / `formattedStudentName`: getter returning `"Lastname, Firstname Middlename"`.
  - `timeIn`: nullable `String` formatted as `"hh:mm a"`.
  - `source`: `AttendanceSource` enum (`manual`, `rfid`, `system`).
- Contract: M4 and M6 consume this contract without altering underlying database schema.

### 2. `AppDataCache` SWR Keys (M1 ↔ M2 ↔ M5)
- Standardized keys:
  - Subjects: `'teacher_subjects_${teacherId}_${schoolYear}'`
  - Students: `'teacher_students_${teacherId}_all_false'`
  - Parents: `'teacher_parents_${teacherId}_all_false'`
  - Schedules: `'teacher_schedules_${teacherId}'`
  - Folders: `'teacher_material_folders_${offeringId}'`
- Contract: Repository mutations must call `AppDataCache.instance.invalidatePrefix(...)` to guarantee cache consistency.

### 3. Inline RFID Tap-to-Link (M3 ↔ Hardware Keyboard)
- Callback: `onStartInlineLinkRfid(AttendanceRosterStudent student)`
- State: `_inlineLinkingStudentId`
- Hardware key listener: routes 8–14 character buffered UID to `_repository.assignStudentRfid(studentId, uid, forceReassign: true)` without launching any modal dialog.

### 4. Multi-Tier Absence Push Notification (M6 ↔ FCM / Supabase)
- Trigger: `saveAttendanceBatch()` and `correctAttendanceRecord()`
- Thresholds: Exactly 3 (Early Warning), 5 (Second Warning), 10 (Final Warning) cumulative absences per subject offering.
- Deliverables: Insert into `public.notifications` & `public.notification_recipients`, and post FCM v1 push notification to `parent_${studentId}` and `admin_alerts`.
