# CLASSREALM — Comprehensive Flutter Architecture Analysis & Enterprise Blueprint

> **System Name:** ClassRealm  
> **Type:** Integrated Senior High School Management System (Frontend-First Prototype)  
> **Target Roles:** Admin, Teacher, Student, Parent  
> **Analysis Date:** 2026-09-23  
> **Status:** Architecture Audit & Migration Blueprint ONLY (No source code or behavior modified)

---

## 1. CURRENT PROJECT STRUCTURE

The existing codebase consists of **45 Dart files**, static assets, and markdown/text documentation files located directly within `lib/` and the project root.

```
class_realm/
├── .artifacts/
├── docs/
│   ├── ADMIN_SIDE_FLOW.md
│   ├── MAIN_SYSTEM_FLOW.md
│   ├── PARENT_SIDE_FLOW.md
│   ├── STUDENT_SIDE_FLOW.md
│   └── TEACHER_SIDE_FLOW.md
├── lib/
│   │   # Documentation & Specifications (Misplaced in lib/)
│   ├── ACTIVITY_2_DFD.md                      (232 lines)
│   ├── CLASSREALM_SSTruth_Mock_Data.txt        (227 lines)
│   ├── admin_demo_script.md                    (35 lines)
│   ├── classrealm_documentation.txt            (340 lines)
│   ├── parent_demo_script.md                   (35 lines)
│   ├── student_demo_script.md                  (39 lines)
│   ├── system_plan.txt                         (1,189 lines)
│   ├── teacher_demo_script.md                  (36 lines)
│   │
│   │   # Static Assets (Misplaced in lib/)
│   ├── school.jpg                              (65 KB campus image)
│   ├── school_logo.png                         (419 KB brand crest)
│   │
│   │   # Application Bootstrap & Routes
│   ├── main.dart                               (44 lines)
│   ├── routes/
│   │   └── app_routes.dart                     (14 lines)
│   │
│   │   # Core Tokens & Theming
│   ├── core/
│   │   └── theme/
│   │       ├── app_colors.dart                 (47 lines)
│   │       └── app_theme.dart                  (97 lines)
│   │
│   │   # Data Layer (Active Mock & Dead Backups)
│   ├── data/
│   │   ├── mock_database.dart                  (1,233 lines - ACTIVE singleton)
│   │   ├── mock_database_backup.dart           (1,022 lines - UNUSED duplicate)
│   │   ├── mock_database_original.dart         (1,866 lines - UNUSED duplicate)
│   │   └── mock_database_partner.dart          (1,829 lines - UNUSED duplicate)
│   │
│   │   # Domain Models
│   ├── models/
│   │   ├── academic_models.dart                (612 lines - God model file)
│   │   └── user_model.dart                     (110 lines - God model class)
│   │
│   │   # Shared UI Components
│   ├── widgets/
│   │   └── common/
│   │       ├── app_buttons.dart                (124 lines)
│   │       ├── app_modals.dart                 (187 lines)
│   │       ├── app_text_field.dart             (66 lines)
│   │       ├── status_badge.dart               (125 lines)
│   │       └── sync_status_badge.dart          (109 lines)
│   │
│   │   # Features by Role
│   └── features/
│       ├── admin/
│       │   └── screens/
│       │       └── admin_dashboard_screen.dart (672 lines)
│       ├── auth/
│       │   └── screens/
│       │       ├── first_login_screen.dart     (252 lines)
│       │       ├── forgot_password_screen.dart (221 lines)
│       │       ├── login_screen.dart           (586 lines)
│       │       ├── pending_account_screen.dart (56 lines)
│       │       └── register_screen.dart        (172 lines)
│       ├── parent/
│       │   └── screens/
│       │       └── parent_home_screen.dart     (638 lines)
│       ├── student/
│       │   ├── screens/
│       │   │   ├── student_assessment_screen.dart        (795 lines)
│       │   │   ├── student_attendance_screen.dart        (185 lines)
│       │   │   ├── student_grades_screen.dart            (252 lines)
│       │   │   ├── student_home_screen.dart              (532 lines)
│       │   │   ├── student_learning_materials_screen.dart(115 lines)
│       │   │   ├── student_requirements_screen.dart      (51 lines)
│       │   │   ├── student_schedule_screen.dart          (135 lines)
│       │   │   └── student_settings_screen.dart          (122 lines)
│       │   └── widgets/
│       │       └── student_activity_card.dart            (211 lines)
│       └── teacher/
│           ├── screens/
│           │   ├── activity_submissions_screen.dart      (465 lines)
│           │   ├── create_assessment_flow.dart           (1,501 lines)
│           │   ├── create_requirement_flow.dart          (485 lines)
│           │   ├── edit_assessment_flow.dart             (168 lines)
│           │   └── teacher_dashboard_screen.dart         (8,626 lines - MONOLITH)
│           └── widgets/
│               ├── add_student_dialog.dart               (654 lines)
│               ├── edit_student_dialog.dart              (364 lines)
│               ├── timetable_grid_widget.dart            (272 lines)
│               └── view_student_dialog.dart              (107 lines)
│
├── pubspec.yaml                                (94 lines)
├── README.md
├── STUDENT_SIDE_IMPLEMENTATION_PLAN.md
└── SYSTEM_CURRENT.txt
```

---

## 2. ARCHITECTURE ASSESSMENT

### What Is Currently Organized:
- **High-level feature separation:** Folders exist for `admin`, `teacher`, `student`, `parent`, and `auth`.
- **Centralized styling:** `core/theme/app_colors.dart` and `core/theme/app_theme.dart` cleanly isolate colors and GoogleFonts (Inter) Material 3 theming.
- **Shared widgets:** Button abstractions (`AppPrimaryButton`), modal dialogs (`AppModals`), and status chips (`StatusBadge`, `SyncStatusBadge`) are isolated in `widgets/common/` and reused across roles.
- **Canonical Mock Data Seeding:** A single source of truth exists in `MockDatabase._seedCanonicalData()` covering 10 students, 10 parents, 1 teacher, 1 admin, assessments, and attendance.

### What Is NOT Organized (Architectural Anti-Patterns):
- **Gigantic God Screen:** `teacher_dashboard_screen.dart` is **8,626 lines long**, containing 20 tabs, sidebar navigation, form controllers, validation rules, dialogs, calculations, and data mutations.
- **God Models:**
  - `user_model.dart` mixes Admin, Teacher, Student (LRN, birthday, parent info), and Parent (linked student ID) concerns into a single class with 25+ mostly nullable fields.
  - `academic_models.dart` clumps 12 distinct domain entities and 6 enums into one 612-line file with zero JSON serialization.
- **Absence of Repository and Service Layers:** Every screen directly reads and mutates `MockDatabase.instance`. There is no abstraction boundary to swap mock data for Firebase.
- **Dead Code and Orphaned Backups:** `lib/data/` contains three dead backup files (`mock_database_original.dart`, `mock_database_partner.dart`, `mock_database_backup.dart`) totaling **4,717 lines of unused code**.
- **Static Assets and Documentation Inside `lib/`:** `school.jpg`, `school_logo.png`, and 8 markdown/text documentation files are scattered inside `lib/`.
- **Dialogs Disguised as Screens:** `create_assessment_flow.dart` (1,501 lines), `create_requirement_flow.dart`, and `edit_assessment_flow.dart` are dialog flows located inside `screens/`.
- **Incomplete Routing Table:** Only 9 routes are registered in `app_routes.dart`. Over 10 screens and flows are pushed using ad-hoc `Navigator.push(context, MaterialPageRoute(...))`.

---

## 3. LARGE FILES ANALYSIS

| File Path | Lines | Bytes | Current Responsibilities |
|---|---|---|---|
| `lib/features/teacher/screens/teacher_dashboard_screen.dart` | **8,626** | 345 KB | **Contains 22+ separate responsibilities:** Collapsible sidebar (20 tabs); Topbar & user identity; Dashboard overview with metrics; Classroom setup; Academic calendar setup; Student management (table, sorting, search, soft archive, restore, permanent deletion, single transfer, bulk transfer, import modal); Parent management table & filters; Unified assessments (Written Work, Performance Tasks, Examinations); Legacy activities & quizzes tabs; Exam checker; Item analysis; Assessment monitoring with real-time violation logs; Grading criteria; Gradebook weighting and DepEd transmutation calculations; Gradebook matrix & export; Grades summary with rankings; Performance analytics & at-risk student alerts; Lesson planning & AI simulation prompt generator; Learning materials repository; Schedule timetable & modal; Notifications tab; Teacher profile; 15 `TextEditingController`s and direct `MockDatabase` mutations. |
| `lib/features/teacher/screens/create_assessment_flow.dart` | **1,501** | 58 KB | **Contains 4 separate responsibilities:** 3-step wizard flow (Details, Question Builder, Review/Publish); Question builder forms for 4 question types (Multiple Choice, True/False, Identification, Matching); Schedule & deadline overrides by section; Direct persistence to `MockDatabase.instance`. |
| `lib/data/mock_database.dart` | **1,233** | 41 KB | **Contains 8 separate responsibilities:** Singleton data container; In-memory seed generation for all 4 roles and academic items; Plaintext password store; Auth simulation; Student onboarding & username/temp-password generation; DepEd grading calculations (`categoryAverageFor`, `quarterlyGradeFor`); CRUD methods for 7 entities; Simulated offline sync toggle. |
| `lib/features/student/screens/student_assessment_screen.dart` | **795** | 30 KB | **Contains 6 separate responsibilities:** 3-step test wizard (Rules, Answering, Results); Anti-cheating lifecycle monitoring via `WidgetsBindingObserver`; Timer countdown & auto-submission; Question renderers for 4 question types; Scoring against answer keys; Direct result persistence. |
| `lib/features/admin/screens/admin_dashboard_screen.dart` | **672** | 30 KB | **Contains 6 separate responsibilities:** Sidebar shell & topbar; Institutional overview metric cards; Teacher management table & search; Pending teacher approvals review (Approve/Reject); System statistics breakdown; Profile and Settings tabs. |
| `lib/features/teacher/widgets/add_student_dialog.dart` | **654** | 22 KB | **Contains 5 separate responsibilities:** Modal dialog UI; 10-field form state; Real-time username & temp-password live preview; 12-digit LRN regex & date validation; Account creation via `MockDatabase`. |
| `lib/features/parent/screens/parent_home_screen.dart` | **638** | 22 KB | **Contains 6 separate responsibilities:** 5-tab BottomNavigationBar shell; Navigation drawer; Linked student resolution; Child attendance log; Child DepEd grades breakdown; Inline page builders pushed to Navigator (`_buildSchedulePage`, `_buildTeacherContactPage`). |
| `lib/models/academic_models.dart` | **612** | 17 KB | **God model file:** Clumps 12 model classes and 6 enums without JSON serialization or domain boundaries. |
| `lib/features/auth/screens/login_screen.dart` | **586** | 20 KB | **Contains 5 separate responsibilities:** Responsive layout (Desktop split vs Mobile); Role selector & demo autofill for 4 roles; Form validation; Auth verification against MockDatabase; Role-based route dispatch. |
| `lib/features/student/screens/student_home_screen.dart` | **532** | 19 KB | **Contains 5 separate responsibilities:** 5-tab BottomNavigationBar shell; Navigation drawer linking to 6 sub-screens; Home overview; Activities list; Quizzes/Exams list; Notifications; Profile. |
| `lib/features/teacher/screens/create_requirement_flow.dart` | **485** | 19 KB | **Contains 3 separate responsibilities:** Performance task creation dialog; Section deadline overrides; Persisting `ActivityModel(isRequirement: true)`. |
| `lib/features/teacher/screens/activity_submissions_screen.dart` | **465** | 18 KB | **Contains 3 separate responsibilities:** Submission list viewer; Score & feedback input form; Persisting graded status. |
| `lib/features/teacher/widgets/edit_student_dialog.dart` | **364** | 13 KB | **Contains 3 separate responsibilities:** Modal UI; Form validation with LRN regex; Persisting full student update. |

---

## 4. FOUR USER-SIDE FEATURES (VERIFIED IN CODE)

### ADMIN (Features that actually exist):
- [x] **Authentication:** Login via `admin` / `admin123`, route dispatch to `/admin/dashboard`.
- [x] **Institutional Overview:** 4 stat cards (Total Teachers, Total Students, Total Parents, Pending Approvals), recent pending approvals preview list.
- [x] **Teacher Management:** Search filter, Status filter (`All`, `Active`, `Pending`, `Deactivated`), teacher data table, status badges.
- [x] **Pending Approvals:** Dedicated list of registrations, `Approve` (`AccountStatus.active`) and `Reject` (`AccountStatus.rejected`) actions.
- [x] **System Statistics:** Institutional metrics, user role distribution breakdown, active vs inactive ratios.
- [x] **Admin Profile:** Admin identity display (School Administrator, email, avatar).
- [x] **Settings:** Mock toggles for maintenance mode, registration gateway, and system notifications.

### TEACHER (Features that actually exist):
- [x] **Dashboard Overview:** Collapsible sidebar (20 navigation items), summary metric cards, classroom shortcut cards, quick-action tiles.
- [x] **Classroom Setup:** Section selector (`Section A`, `Section B`), School Year selector (`2026-2027`), Add Class form, Classroom prototype cards.
- [x] **Academic Setup:** Academic year configuration form, start/end dates, 4-quarter structure definition.
- [x] **Student Management:** Active and Archived tabs, real-time search, column sorting, Add Student dialog (with LRN & birthday validation), Edit Student dialog, View Student profile modal, Soft archive / restore, Permanent deletion, Deactivate / reactivate, Single section transfer dialog, Bulk section transfer dialog, Import students CSV modal.
- [x] **Parent Management:** Parent table, linked student ID, phone, relationship, search, sorting, Add Parent modal, Edit Parent modal.
- [x] **Classwork / Unified Assessments:** Unified tab grouping Written Work (WW), Performance Tasks (PT), and Examinations (EX); category filter chips; section deadline overrides; Create Chooser modal; Delete assessment with confirmation.
- [x] **Performance Tasks / Requirements:** `CreateRequirementFlowDialog` with title, instructions, max score, deadline, section deadlines, rubric attachment, and submission type.
- [x] **Quizzes & Examinations:** `CreateAssessmentFlowDialog` with 4 question types (Multiple Choice, True/False, Identification, Matching), question point values, exam duration, schedule date, section deadlines; `EditAssessmentFlowDialog` for existing items.
- [x] **Activity Submissions & Grading:** `ActivitySubmissionsScreen` (embedded or standalone), view submitted student files, score input, feedback entry, and submission status update (`graded`).
- [x] **Exam Checker:** Automated multiple-choice answer validation against `QuestionModel.correctAnswer`, manual score adjustments, finalized state flag.
- [x] **Item Analysis:** Table of assessment questions displaying difficulty index, discrimination index, correct answer percentage, and auto-recommendation badges (`Retain`, `Revise`).
- [x] **Assessment Monitoring:** Real-time online assessment tracker showing active student sessions, elapsed duration, violation count, and detailed anti-cheating violation log modal (tab switch events).
- [x] **Attendance Management:** Daily attendance records table, manual status toggle (`Present`, `Late`, `Absent`, `Excused`), simulated RFID card scan logs, date picker, section filter, sync status indicator.
- [x] **Gradebook:** DepEd grading configuration (Written Works 20%, Performance Tasks 50%, Examinations 30%), editable weight controls with sum-to-100 validation, student score matrix, quarterly transmuted grade display, Export Grades confirmation dialog.
- [x] **Grades Summary:** Student summary cards, ranking order filter, section filter.
- [x] **Performance Analytics:** Grade distribution bar chart representation, passing rate percentage, at-risk student alert cards.
- [x] **Lesson Planning:** Lesson plan repository, AI lesson plan generator form simulating automated objectives, materials, procedures, assessment, and homework.
- [x] **Learning Materials:** Material repository (PDFs, presentations, documents), section filtering, upload simulation modal.
- [x] **My Schedule:** `TimetableGridWidget` displaying weekly schedule across days and time slots, Add Schedule entry dialog.
- [x] **Notifications & Alerts:** Low attendance alerts, academic risk warnings, RFID synchronization logs.
- [x] **Teacher Profile:** Teacher details (Karen P. Gonzaga, General Mathematics, Department of Mathematics).
- [x] **Reports:** Institutional reporting cards, export confirmation modals.

### STUDENT (Features that actually exist):
- [x] **Authentication & First Login:** Login via `student` / `student123`, forced password reset screen (`FirstLoginScreen`) for `pendingFirstLogin` state.
- [x] **Student Home / Dashboard:** Welcome banner, quick summary metrics, active Written Works list, upcoming exams.
- [x] **Written Works / Activities Tab:** `StudentActivityCard` widgets displaying due date, max points, submission status (`Submitted`, `Graded`, `Missing`), and file upload simulation modal.
- [x] **Exam / Quiz Tab:** Available assessments list, schedule date, duration, status badge, Start Assessment button.
- [x] **Student Assessment Flow (`StudentAssessmentScreen`):** Full-screen test-taking wizard with rules agreement step, question pager, countdown timer, anti-cheating detection (lifecycle app backgrounding / tab switch listener), auto-submit on 3 violations, automated grading against answer key, and immediate result breakdown summary.
- [x] **Requirements Screen (`StudentRequirementsScreen`):** Dedicated view for Performance Tasks and major requirements.
- [x] **Attendance Screen (`StudentAttendanceScreen`):** Personal attendance history, Present/Late/Absent counters, date breakdown.
- [x] **Grades Screen (`StudentGradesScreen`):** Quarterly grades card, DepEd category breakdown (WW 20%, PT 50%, EX 30%), transmuted final rating.
- [x] **Schedule Screen (`StudentScheduleScreen`):** Weekly class schedule list by day, room, and time.
- [x] **Learning Materials Screen (`StudentLearningMaterialsScreen`):** Access to teacher-uploaded materials filtered by enrolled section.
- [x] **Alerts / Notifications Tab:** Attendance notices, academic alerts, system announcements.
- [x] **Student Profile Tab:** Student identity, LRN (12 digits), enrolled section, birthday, contact, guardian info.
- [x] **Student Settings Screen (`StudentSettingsScreen`):** Notification toggles, password change placeholder, app version.

### PARENT (Features that actually exist):
- [x] **Authentication:** Login via `parent` / `parent123`, role redirect to `/parent/home`.
- [x] **Linked Student Overview Tab:** Linked child card (Alyssa M. Reyes, Grade 11 Section A), Class Adviser card, quick attendance percentage, recent activities.
- [x] **Attendance Log Tab:** Chronological attendance log for the linked child, time-in timestamps, status badges (`Present`, `Late`, `Absent`).
- [x] **Grades Tab:** Child's quarterly grades, category breakdown (WW, PT, EX), DepEd rating and status (`Passed`).
- [x] **Alerts / Notifications Tab:** Real-time attendance notifications ("Attendance Confirmed - Gate 1").
- [x] **Parent Profile Tab:** Parent identity, contact details, relationship (`Mother`/`Father`), linked child information.
- [x] **Student Schedule Page:** Push route to view the linked student's class timetable.
- [x] **Teacher Contact Page:** Push route with class adviser contact card, office hours, email, and contact actions.

---

## 5. MOCK DATA ANALYSIS

### Storage Location:
All active mock data is centralized in `lib/data/mock_database.dart` inside `MockDatabase.instance._seedCanonicalData()`.

### Inventory of Existing Mock Entities:
1. **Users (`List<UserModel>`):**
   - **Admin (1):** `usr_admin` (`admin` / `admin123`)
   - **Teacher (1):** `T001` - Karen P. Gonzaga (`teacher` / `teacher123`, General Mathematics)
   - **Students (10):**
     - Section A (5): `A01` (Alyssa Reyes - demo student), `A02` (Joshua Navarro), `A03` (Bianca Dela Cruz), `A04` (Daniel Mendoza), `A05` (Camille Villanueva).
     - Section B (5): `B01` (Nathan Garcia), `B02` (Sofia Bautista), `B03` (Ethan Aquino), `B04` (Jasmine Santiago), `B05` (Marco Castillo).
   - **Parents (10):** `PA01` to `PA05`, `PB01` to `PB05` (`parent` / `parent123` linked to `A01`).
2. **Passwords:** Stored in in-memory map `_mockPasswords` keyed by user ID.
3. **Academic Setup:** Academic Year: `'2026-2027'`, Grade Level: `'Grade 11'`, Subject: `'General Mathematics'`, Sections: `['Section A', 'Section B']`.
4. **Attendance Records (`List<AttendanceRecord>`):** 50 records covering 5 school days (2026-09-14 to 2026-09-18) for all 10 students, including preset Late and Absent statuses.
5. **Activities (`List<ActivityModel>`):** 4 items: `WW1` (Functions Activity), `WW2` (Function Operations), `WW3` (Functions Quiz), `PT1` (Functions Project - `isRequirement: true`).
6. **Quizzes & Exams (`List<QuizOrExamModel>`):** 4 items: `WW3` (Functions Quiz, 5 questions), `EX1` (ST1, 10 questions), `EX2` (ST2, 10 questions), `EX3` (TE, 10 questions).
7. **Scores Matrix (`Map<String, Map<String, double>>`):** Raw scores for 10 students across all 7 assessment items.
8. **Submissions (`List<StudentSubmission>`):** Seeded submissions for activities with simulated PDF attachment names.
9. **Assessment Results (`List<AssessmentResultModel>`):** Seeded exam attempts for `EX1` (`A01` clean, `A02` with 2 tab switch violations, `B01` clean).
10. **Grading Criteria (`List<GradingCriteria>`):** WW = 20%, PT = 50%, EX = 30%.
11. **Lesson Plans (`List<LessonPlanModel>`):** `LP1` (Functions and Relations), `LP2` (Rational Functions).
12. **Learning Materials (`List<LearningMaterialModel>`):** 5 items (`mat_1`, `mat_2`, `mat_lp_1`, `mat_lp_2`, `mat_lp_3`).
13. **Schedules (`List<ScheduleModel>`):** 4 schedule entries (`sch_1` to `sch_4` for Sections A & B).
14. **Notifications (`List<AppNotificationModel>`):** `notif_att_1` (attendance drop), `notif_risk_1` (academic risk), `notif_att_2` (RFID gate sync).

### Duplicated and Dead Mock Data:
- `mock_database_original.dart` (1,866 lines): Obsolete mock database, not imported anywhere.
- `mock_database_partner.dart` (1,829 lines): Duplicate branch database, not imported anywhere.
- `mock_database_backup.dart` (1,022 lines): Obsolete backup copy, not imported anywhere.
- `CLASSREALM_SSTruth_Mock_Data.txt`: Raw text file duplicating canonical seed specifications.
- **Model-Level Duplication:** `WW3` ("Functions Quiz") is seeded as both an `ActivityModel` and a `QuizOrExamModel`.

---

## 6. ASSET ANALYSIS

### Current Assets on Disk:
Only **two static assets** exist in the project:
1. `lib/school_logo.png` (418,858 bytes): School crest PNG.
2. `lib/school.jpg` (65,140 bytes): School campus building JPEG.

### Current Declaration in `pubspec.yaml`:
```yaml
flutter:
  uses-material-design: true
  assets:
    - lib/school_logo.png
    - lib/school.jpg
```

### Exact References in Source Code:
- `lib/school_logo.png` is referenced in:
  - `lib/features/auth/screens/login_screen.dart` (Lines 160, 203, 335, 412)
  - `lib/features/admin/screens/admin_dashboard_screen.dart` (Line 49)
  - `lib/features/teacher/screens/teacher_dashboard_screen.dart` (Line 145)
- `lib/school.jpg` is referenced in:
  - `lib/features/auth/screens/login_screen.dart` (Line 130)

### Asset Types Not Present on Disk:
No SVGs, WEBP, GIFs, Videos, Audios, or actual PDFs exist. File names like `GenMath_Module_1_Functions.pdf` are metadata strings used for simulation.

---

## 7. ROUTING ANALYSIS

### Routes in `app_routes.dart` & `main.dart`:
```dart
AppRoutes.login:           '/'
AppRoutes.register:        '/register' (web only)
AppRoutes.forgotPassword:  '/forgot-password'
AppRoutes.pendingAccount:  '/pending-account'
AppRoutes.firstLogin:      '/student/first-login'
AppRoutes.adminDashboard:  '/admin/dashboard'
AppRoutes.teacherDashboard:'/teacher/dashboard'
AppRoutes.studentHome:     '/student/home'
AppRoutes.parentHome:      '/parent/home'
```

### Routing Problems:
1. **10+ Unregistered Screens:** `StudentAssessmentScreen`, `StudentAttendanceScreen`, `StudentGradesScreen`, `StudentLearningMaterialsScreen`, `StudentRequirementsScreen`, `StudentScheduleScreen`, `StudentSettingsScreen`, `ActivitySubmissionsScreen`, `CreateAssessmentFlowDialog`, and `CreateRequirementFlowDialog` have no named routes.
2. **Direct Screen Coupling:** Screens navigate by directly instantiating target widgets via `Navigator.push(context, MaterialPageRoute(builder: (_) => Screen(...)))`.
3. **Inline Scaffold Builders:** `parent_home_screen.dart` pushes ad-hoc widget methods (`_buildSchedulePage`, `_buildTeacherContactPage`) directly onto the navigator.
4. **No Route Guards:** There is zero authentication or role authorization validation. Any route can be launched without checking user credentials or permissions.

---

## 8. STATE / CONTROLLER ANALYSIS

### Current State Approach:
Pure local `StatefulWidget` state using `setState()`. No external state management library is present in `pubspec.yaml`.

### State Problems:
- `teacher_dashboard_screen.dart` manages 40+ state variables simultaneously (tab index, search queries, sort columns, sort directions, selection sets, weighting edit mode, 15 text controllers).
- `student_assessment_screen.dart` mixes timer ticks, anti-cheating lifecycle hooks, answer recording, step progression, and score calculation in a single state class.
- **Zero Cross-Screen Sync:** If a teacher updates a student's grade or marks attendance, other screens do not update reactively because data is read once during `build()`.

---

## 9. DATA-LAYER ANALYSIS

### Current Architecture Flow:
```
UI Screen ──(Direct Access)──> MockDatabase.instance Singleton
```

### Concrete Violations:
1. **Direct Singleton Ingestion:** Every screen directly reads properties like `MockDatabase.instance.users` and `MockDatabase.instance.activities`.
2. **Direct Mutation Calls:** CRUD operations (`createStudentAccount`, `scoreSubmission`, `toggleAttendance`, `generateLessonPlan`) are called directly from UI button callbacks.
3. **No Repository Interfaces:** There are zero repository or service abstractions. Introducing Cloud Firestore or a REST API currently requires touching every UI file in the system.

---

## 10. SHARED COMPONENT ANALYSIS

### Genuine Shared Components (`shared/`):
- `AppPrimaryButton`, `AppSecondaryButton`, `AppDangerButton` -> Used across all 4 roles.
- `AppTextField` -> Used in login, registration, and form dialogs.
- `AppModals` (`showErrorDialog`, `showSuccessDialog`, `showWarningDialog`, `showConfirmDialog`) -> Used everywhere.
- `StatusBadge` -> Used for Account statuses (`Active`, `Pending`, `Rejected`, `Deactivated`) and Attendance statuses (`Present`, `Late`, `Absent`, `Excused`).
- `SyncStatusBadge` -> Used in the topbars of Admin, Teacher, Student, and Parent.
- `AppColors` and `AppTheme` -> Global styling.

### Feature-Specific Components (Must NOT be Global):
- `StudentActivityCard` -> Specific to Student activities tab.
- `TimetableGridWidget` -> Specific to Teacher schedule tab.
- `AddStudentDialog`, `EditStudentDialog`, `ViewStudentDialog` -> Specific to Teacher student management.
- `CreateAssessmentFlowDialog`, `CreateRequirementFlowDialog`, `EditAssessmentFlowDialog` -> Specific to Teacher assessment management.

---

## 11. PROBLEMS WITH CURRENT ARCHITECTURE

1. **8,626-line Monolithic Screen:** `teacher_dashboard_screen.dart` violates Single Responsibility and is impossible to maintain cleanly.
2. **4,717 Lines of Dead Code:** Three duplicate mock database files sit unused in `lib/data/`.
3. **Misplaced Assets & Documentation:** Images and documentation files reside in `lib/` root.
4. **God Model Anti-Pattern:** `UserModel` combines 4 roles with 25+ nullable fields.
5. **No Data Layer Abstraction:** Zero repositories or data source interfaces exist to support future Firebase integration.
6. **Incomplete Routing & Tightly Coupled Navigation:** Over 10 screens lack route registration and are navigated via direct class instantiation.
7. **Business Logic in Data Singleton:** DepEd grade transmutation and category weight calculations are embedded inside `mock_database.dart` and UI screens.

---

## 12. PROPOSED ENTERPRISE-LEVEL FOLDER STRUCTURE

This proposed structure preserves all existing features, UI, and mock data while cleanly separating roles, layers, and concerns:

```
class_realm/
├── assets/
│   ├── branding/
│   │   └── school_logo.png
│   └── images/
│       └── auth/
│           └── school.jpg
│
├── docs/
│   ├── ADMIN_SIDE_FLOW.md
│   ├── MAIN_SYSTEM_FLOW.md
│   ├── PARENT_SIDE_FLOW.md
│   ├── STUDENT_SIDE_FLOW.md
│   ├── TEACHER_SIDE_FLOW.md
│   ├── ACTIVITY_2_DFD.md
│   ├── CLASSREALM_SSTruth_Mock_Data.txt
│   ├── system_plan.txt
│   └── scripts/
│       ├── admin_demo_script.md
│       ├── teacher_demo_script.md
│       ├── student_demo_script.md
│       └── parent_demo_script.md
│
├── lib/
│   ├── main.dart
│   │
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_constants.dart
│   │   │   └── asset_paths.dart
│   │   ├── network/
│   │   │   └── sync_status.dart
│   │   ├── theme/
│   │   │   ├── app_colors.dart
│   │   │   └── app_theme.dart
│   │   └── utils/
│   │       ├── date_formatters.dart
│   │       └── deped_grading_engine.dart
│   │
│   ├── routes/
│   │   ├── app_routes.dart
│   │   └── route_guards.dart
│   │
│   ├── shared/
│   │   ├── models/
│   │   │   ├── user_role.dart
│   │   │   ├── account_status.dart
│   │   │   └── notification_model.dart
│   │   └── widgets/
│   │       ├── buttons/
│   │       │   └── app_buttons.dart
│   │       ├── inputs/
│   │       │   └── app_text_field.dart
│   │       ├── modals/
│   │       │   └── app_modals.dart
│   │       ├── badges/
│   │       │   ├── status_badge.dart
│   │       │   └── sync_status_badge.dart
│   │       └── layout/
│   │           └── responsive_layout_builder.dart
│   │
│   ├── data/
│   │   ├── datasources/
│   │   │   └── mock/
│   │   │       ├── mock_database.dart
│   │   │       └── canonical_seed_data.dart
│   │   └── repositories/
│   │       ├── auth_repository.dart
│   │       ├── student_repository.dart
│   │       ├── teacher_repository.dart
│   │       ├── assessment_repository.dart
│   │       └── attendance_repository.dart
│   │
│   └── features/
│       ├── auth/
│       │   ├── models/
│       │   │   └── auth_credentials.dart
│       │   ├── screens/
│       │   │   ├── login_screen.dart
│       │   │   ├── register_screen.dart
│       │   │   ├── first_login_screen.dart
│       │   │   ├── forgot_password_screen.dart
│       │   │   └── pending_account_screen.dart
│       │   └── widgets/
│       │       ├── demo_role_selector.dart
│       │       └── login_branding_panel.dart
│       │
│       ├── admin/
│       │   ├── screens/
│       │   │   └── admin_shell_screen.dart
│       │   └── tabs/
│       │       ├── admin_overview_tab.dart
│       │       ├── teacher_management_tab.dart
│       │       ├── pending_approvals_tab.dart
│       │       ├── system_statistics_tab.dart
│       │       ├── admin_profile_tab.dart
│       │       └── system_settings_tab.dart
│       │
│       ├── teacher/
│       │   ├── screens/
│       │   │   └── teacher_shell_screen.dart
│       │   ├── widgets/
│       │   │   ├── teacher_sidebar.dart
│       │   │   └── teacher_topbar.dart
│       │   ├── dashboard/
│       │   │   └── tabs/
│       │   │       └── teacher_overview_tab.dart
│       │   ├── classroom/
│       │   │   ├── tabs/
│       │   │   │   ├── classroom_setup_tab.dart
│       │   │   │   └── academic_setup_tab.dart
│       │   │   └── widgets/
│       │   │       └── classroom_card.dart
│       │   ├── students/
│       │   │   ├── tabs/
│       │   │   │   └── student_management_tab.dart
│       │   │   ├── dialogs/
│       │   │   │   ├── add_student_dialog.dart
│       │   │   │   ├── edit_student_dialog.dart
│       │   │   │   ├── view_student_dialog.dart
│       │   │   │   ├── transfer_section_dialog.dart
│       │   │   │   └── import_students_dialog.dart
│       │   │   └── widgets/
│       │   │       └── student_data_table.dart
│       │   ├── parents/
│       │   │   ├── tabs/
│       │   │   │   └── parent_management_tab.dart
│       │   │   └── dialogs/
│       │   │       ├── add_parent_dialog.dart
│       │   │       └── edit_parent_dialog.dart
│       │   ├── assessments/
│       │   │   ├── tabs/
│       │   │   │   ├── unified_assessments_tab.dart
│       │   │   │   └── assessment_monitoring_tab.dart
│       │   │   ├── dialogs/
│       │   │   │   ├── create_assessment_flow_dialog.dart
│       │   │   │   ├── create_requirement_flow_dialog.dart
│       │   │   │   ├── edit_assessment_flow_dialog.dart
│       │   │   │   └── violation_detail_dialog.dart
│       │   │   ├── screens/
│       │   │   │   └── activity_submissions_screen.dart
│       │   │   └── widgets/
│       │   │       ├── assessment_card.dart
│       │   │       └── question_builder_widget.dart
│       │   ├── evaluation/
│       │   │   └── tabs/
│       │   │       ├── exam_checker_tab.dart
│       │   │       └── item_analysis_tab.dart
│       │   ├── attendance/
│       │   │   ├── tabs/
│       │   │   │   └── teacher_attendance_tab.dart
│       │   │   └── widgets/
│       │   │       └── attendance_roster_table.dart
│       │   ├── gradebook/
│       │   │   ├── tabs/
│       │   │   │   ├── gradebook_tab.dart
│       │   │   │   └── grades_summary_tab.dart
│       │   │   └── widgets/
│       │   │       ├── grade_weight_editor.dart
│       │   │       └── gradebook_table.dart
│       │   ├── analytics/
│       │   │   └── tabs/
│       │   │       └── performance_analytics_tab.dart
│       │   ├── curriculum/
│       │   │   └── tabs/
│       │   │       ├── lesson_planning_tab.dart
│       │   │       └── learning_materials_tab.dart
│       │   ├── schedule/
│       │   │   ├── tabs/
│       │   │   │   └── teacher_schedule_tab.dart
│       │   │   ├── dialogs/
│       │   │   │   └── schedule_entry_dialog.dart
│       │   │   └── widgets/
│       │   │       └── timetable_grid_widget.dart
│       │   └── account/
│       │       └── tabs/
│       │           ├── teacher_notifications_tab.dart
│       │           ├── teacher_profile_tab.dart
│       │           └── teacher_reports_tab.dart
│       │
│       ├── student/
│       │   ├── screens/
│       │   │   ├── student_shell_screen.dart
│       │   │   ├── student_assessment_screen.dart
│       │   │   ├── student_requirements_screen.dart
│       │   │   ├── student_attendance_screen.dart
│       │   │   ├── student_grades_screen.dart
│       │   │   ├── student_schedule_screen.dart
│       │   │   ├── student_learning_materials_screen.dart
│       │   │   └── student_settings_screen.dart
│       │   ├── tabs/
│       │   │   ├── student_home_tab.dart
│       │   │   ├── student_activities_tab.dart
│       │   │   ├── student_exam_tab.dart
│       │   │   ├── student_notifications_tab.dart
│       │   │   └── student_profile_tab.dart
│       │   └── widgets/
│       │       ├── student_drawer.dart
│       │       └── student_activity_card.dart
│       │
│       └── parent/
│           ├── screens/
│           │   ├── parent_shell_screen.dart
│           │   ├── parent_schedule_screen.dart
│           │   └── parent_teacher_contact_screen.dart
│           ├── tabs/
│           │   ├── parent_overview_tab.dart
│           │   ├── parent_attendance_tab.dart
│           │   ├── parent_grades_tab.dart
│           │   ├── parent_alerts_tab.dart
│           │   └── parent_profile_tab.dart
│           └── widgets/
│               └── parent_drawer.dart
```

---

## 13. FEATURE-BY-FEATURE DECOMPOSITION

### Decomposition of `teacher_dashboard_screen.dart` (8,626 lines):
1. **Navigation Shell:** Extract lines 132–380 into `TeacherShellScreen`, `TeacherSidebar`, and `TeacherTopbar`.
2. **Overview:** Extract lines 563–943 into `teacher_overview_tab.dart`.
3. **Classroom & Academic Setup:** Extract lines 3628–4575 into `classroom_setup_tab.dart` and `academic_setup_tab.dart`.
4. **Student Management:** Extract lines 2229–3627 into `student_management_tab.dart`. Move inline dialogs (`_showTransferSectionDialog`, `_showBulkTransferSectionDialog`, `_showImportStudentsDialog`) to dedicated dialog files.
5. **Parent Management:** Extract lines 1379–2228 into `parent_management_tab.dart`.
6. **Unified Assessments:** Extract lines 5382–5831 into `unified_assessments_tab.dart`.
7. **Assessment Monitoring & Violations:** Extract lines 6563–6779 into `assessment_monitoring_tab.dart` and `violation_detail_dialog.dart`.
8. **Exam Checker & Item Analysis:** Extract lines 6222–6562 into `exam_checker_tab.dart` and `item_analysis_tab.dart`.
9. **Attendance:** Extract lines 4576–5381 into `teacher_attendance_tab.dart`.
10. **Gradebook & Grades:** Extract lines 6850–7933 into `gradebook_tab.dart` and `grades_summary_tab.dart`.
11. **Curriculum:** Extract lines 7990–8191 into `lesson_planning_tab.dart` and `learning_materials_tab.dart`.
12. **Schedule:** Extract lines 8192–8482 into `teacher_schedule_tab.dart` and `schedule_entry_dialog.dart`.
13. **Account & Reports:** Extract lines 8483–8626 into `teacher_notifications_tab.dart`, `teacher_profile_tab.dart`, and `teacher_reports_tab.dart`.

---

## 14. ASSET FOLDER STRUCTURE

Based strictly on the assets currently present in the codebase:

```
assets/
├── branding/
│   └── school_logo.png
└── images/
    └── auth/
        └── school.jpg
```

### `pubspec.yaml` Update Blueprint:
```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/branding/
    - assets/images/auth/
```

### Centralized Asset Constant Class (`lib/core/constants/asset_paths.dart`):
```dart
class AssetPaths {
  static const String schoolLogo = 'assets/branding/school_logo.png';
  static const String schoolBackground = 'assets/images/auth/school.jpg';
}
```

---

## 15. SAFE MIGRATION PLAN

```
Phase 1: Housekeeping & Asset Relocation
  1. Move school_logo.png to assets/branding/ and school.jpg to assets/images/auth/.
  2. Update pubspec.yaml asset paths and verify asset resolution.
  3. Move documentation and demo markdown files to docs/ and remove dead backup mock files.

Phase 2: Core & Shared Layer Extraction
  1. Extract DepEd grading calculations from mock_database.dart into deped_grading_engine.dart.
  2. Organize shared widgets under shared/widgets/ without altering styling or properties.

Phase 3: Domain Entity Decomposition
  1. Split academic_models.dart into domain-specific model files.
  2. Decompose UserModel into distinct or clean role-specific models while preserving copyWith.

Phase 4: Data Layer Repositories
  1. Define abstract repository interfaces wrapping MockDatabase.instance.
  2. Keep all mock methods and canonical seed data exactly as they are.

Phase 5: Feature Decomposition (Student & Parent)
  1. Split student_home_screen.dart into tab widgets and student_drawer.dart.
  2. Extract parent inline scaffold builders into clean standalone screens.

Phase 6: Teacher Monolith Decomposition
  1. Extract each tab from teacher_dashboard_screen.dart into its dedicated tab file.
  2. Maintain identical Widget trees, paddings, colors, and controllers.

Phase 7: Centralized Routing & Route Guards
  1. Register all unregistered screens in app_routes.dart with role verification guards.

Phase 8: Full Regression Verification
  1. Verify every workflow across Admin, Teacher, Student, and Parent.
```

---

## 16. HIGH-RISK BEHAVIORAL AREAS

1. **12-Digit LRN Validation:** `add_student_dialog.dart` and `edit_student_dialog.dart` strictly enforce `RegExp(r'^\d{12}$')`. Any modification will break student account creation.
2. **Auto-Generated Username & Temp-Password Formatter:**
   - Username: `${firstName.trim()} ${lastName.trim()}`
   - Temp Password: `${lastName.toLowerCase().replaceAll(' ', '')}${MMDDYYYY}`
   - Any change in case, trim, or date formatting will break `firstLogin` verification.
3. **DepEd Transmutation & Category Formulas:**
   - Category weights: Written Works: 20%, Performance Tasks: 50%, Examinations: 30%.
   - Exam sub-weights: ST1 (30%), ST2 (30%), TE (40%).
4. **Anti-Cheating Lifecycle Detection (`StudentAssessmentScreen`):**
   - Relies on `WidgetsBindingObserver.didChangeAppLifecycleState`.
   - Records `AppLifecycleState.paused` and `inactive` as violations.
   - Automatically locks and submits the assessment upon reaching 3 violations.
5. **Periodic Timer Disposal:** `Timer.periodic` in assessment screens must be cleanly cancelled in `dispose()` to prevent memory leaks and ghost submissions.

---

## 17. FINAL RULE

> **"Do not implement this structure yet. This response is an architecture analysis and migration blueprint only."**
