# ClassRealm — Student Side Flow

> **Status:** Working draft — not final
> **Platform:** Mobile-first (bottom navigation + drawer)
> **Last updated:** 2026-09-21

---

## 1. STUDENT ROLE DEFINITION

The Student is an **academic participant** — they consume content, complete assessments, submit work, and view their academic progress. Students do NOT create or manage academic content.

### What Student IS
- Assessment taker (quizzes, exams, activities, performance tasks)
- Work submitter (activity submissions, requirement submissions)
- Information viewer (grades, attendance, schedule, materials, notifications)

### What Student IS NOT
- NOT an academic manager
- Cannot create/edit assessments, grade themselves, manage other students, or access teacher/admin functions
- Cannot take quizzes/exams offline (internet required)

### Account Lifecycle
```
Teacher creates student account (generates temp credentials)
→ Student receives username + temporary password
→ Student logs in for the first time
→ First Login Screen: must change password
→ Account becomes "active"
→ Student can now access all student features
```

---

## 2. STUDENT NAVIGATION

```
Bottom Navigation (Primary — always visible):
├── 🏠 Home
│     ├── Student name, grade, section
│     ├── Academic summary cards
│     ├── Pending Activities & Tasks
│     └── Recent notifications preview
│
├── 📝 Activities
│     ├── List of WW activities/assignments
│     ├── Submission status per activity (Pending/Submitted/Graded/Missing)
│     ├── Score + feedback for graded items
│     └── Submit button (or "Submitted" / "Missing" badge)
│
├── 📋 Quiz/Exam
│     ├── List of published quizzes and exams
│     ├── Status: Available / Submitted (awaiting release) / Score Released
│     ├── Start Quiz/Exam → Assessment Screen
│     │     ├── Rules acknowledgment
│     │     ├── Timer countdown
│     │     ├── Question-by-question answering
│     │     ├── Anti-cheating monitoring
│     │     ├── Submit → auto-check → result
│     │     └── View result (when released)
│     └── Cannot retake once submitted
│
├── 🔔 Notifications
│     ├── Academic alerts (deadlines, grades released, etc.)
│     └── Tap → navigate to relevant screen
│
└── 👤 Profile
      ├── Student name, LRN, section, grade level
      └── Account information

Side Drawer (Secondary features):
├── 📊 Attendance Records
│     ├── Attendance history (date, time in, status, method)
│     ├── Summary header (X present / Y total days)
│     └── Status badges: Present / Late / Absent / Excused
│
├── 📅 Class Schedule
│     ├── Weekly view grouped by day
│     ├── Subject, Room, Start/End time
│     └── Per student's section
│
├── 📁 Learning Materials
│     ├── Materials for student's section/subjects
│     ├── Title, category icon (PDF/Doc/PPT/Image/Link)
│     ├── File size, uploaded date
│     └── Mock download action
│
├── 📒 Published Grades
│     ├── Per-subject breakdown
│     ├── Per-item scores (activities, quizzes, exams)
│     ├── Category breakdown (WW / PT / EX)
│     └── Quarterly grade summary
│
├── 📋 Academic Requirements (PT)
│     ├── Performance task list
│     ├── Submission status and deadlines
│     └── Score + feedback for graded items
│
├── ⚙️ Settings
│     ├── Connectivity toggle (demo control for online/offline simulation)
│     ├── Change password
│     └── Notification preferences (placeholder)
│
└── 🚪 Logout
```

---

## 3. STUDENT FEATURES — DETAILED STATUS

### 3.1 Home Tab

| Feature | Status | Notes |
|---|---|---|
| Student name, grade, section display | ⚠️ Partial | Some screens show hardcoded "Juan Dela Cruz" instead of `currentUser` |
| Academic summary cards | ✅ Built | |
| Pending activities list | ✅ Built | Shows recent activities |
| Recent notifications | ✅ Built | Static mock data |

### 3.2 Activities Tab

| Feature | Status | Notes |
|---|---|---|
| List WW activities/assignments | ✅ Built | Reads from `MockDatabase.activities` |
| View activity details + instructions | ✅ Built | |
| Upload & Submit (mock) | ✅ Built | Mock file interaction |
| **Submission status visibility** | ⚠️ In progress | STUDENT_SIDE plan Phase 2 — student can't tell if submitted/graded/missing |
| **Score + feedback for graded items** | ⚠️ In progress | Phase 2 — teacher grades aren't visible to student yet |
| **Separate requirements from activities** | ⚠️ In progress | Phase 3 — requirements mixed into activities list |

### 3.3 Quiz/Exam Tab

| Feature | Status | Notes |
|---|---|---|
| List published quizzes/exams | ✅ Built | Reads from `MockDatabase.quizzesAndExams` |
| **Start Quiz/Exam → real assessment screen** | ⚠️ In progress | Phase 1.1 — was showing fake success dialog, being wired to real screen |
| Assessment rules acknowledgment | ✅ Built | `student_assessment_screen.dart` has rules step |
| Question answering interface | ✅ Built | Supports MC, T/F, Identification, Matching |
| **Timer countdown** | ⚠️ In progress | Phase 1.3 — timer text exists but doesn't actually count down |
| **Auto-submit on timer expiry** | ⚠️ In progress | Phase 1.3 |
| Answer auto-check against key | ✅ Built | Local comparison |
| Result creation | ✅ Built | Creates `AssessmentResultModel` |
| **Result reflection on quiz tab** | ⚠️ In progress | Phase 1.4 — can still "start" already-taken quiz |
| **Connectivity gate** | ⚠️ In progress | Phase 1.2 — button says "Offline Safe" which contradicts spec |
| **View released result** | ⚠️ In progress | Phase 1.4 |

### 3.4 Anti-Cheating (During Quiz/Exam)

| Feature | Status | Notes |
|---|---|---|
| Violation counter display | ✅ Built | `_violations` variable exists |
| **Lifecycle detection (app switch/minimize)** | ❌ Missing | Phase 1.3 — `_violations` never increments |
| **Copy/paste detection** | ❌ Missing | Phase 1.3 — simulate where Flutter can't detect |
| **Warning modal on violation** | ❌ Missing | Phase 1.3 |
| **3-violation auto-submit/lock** | ❌ Missing | Phase 1.3 |
| **Violation log persistence** | ❌ Missing | Phase 1.6 — `violationLog` field on AssessmentResultModel |
| Demo simulate buttons | ❌ Missing | Phase 1.3 — for events Flutter can't detect |

### 3.5 Attendance (Drawer)

| Feature | Status | Notes |
|---|---|---|
| Attendance history list | ✅ Built | `student_attendance_screen.dart` |
| Status badges (P/L/A/E) | ✅ Built | |
| Summary header | ✅ Built | X present / Y total |
| Data from MockDatabase | ✅ Built | Reads shared attendance records |

### 3.6 Schedule (Drawer)

| Feature | Status | Notes |
|---|---|---|
| Weekly schedule view | ✅ Built | `student_schedule_screen.dart` |
| Grouped by day | ✅ Built | |
| Subject, room, time | ✅ Built | |
| **Schedule data populated** | ⚠️ In progress | Phase 0.2 — `MockDatabase.schedules` was empty |

### 3.7 Learning Materials (Drawer)

| Feature | Status | Notes |
|---|---|---|
| Materials list for section | ✅ Built | `student_learning_materials_screen.dart` |
| Category icons | ✅ Built | PDF/Doc/PPT/Image/Link |
| Mock download | ✅ Built | Dialog interaction |
| **Section scoping** | ⚠️ In progress | Phase 0.1 — `LearningMaterialModel` needed `section` field |

### 3.8 Grades (Drawer)

| Feature | Status | Notes |
|---|---|---|
| Grades screen | ✅ Built | `student_grades_screen.dart` |
| Per-item score list | ⚠️ In progress | Phase 5 — needs real per-item breakdown |
| Quarterly grade summary | ⚠️ In progress | Uses `quarterlyGradeFor()` which is a placeholder |
| **Real grade calculation behind it** | ❌ Blocked | Requires grading engine (Phase B in main plan) |

### 3.9 Requirements (Drawer)

| Feature | Status | Notes |
|---|---|---|
| Requirements screen | ⚠️ In progress | `student_requirements_screen.dart` exists (Phase 3) |
| Separate from activities | ⚠️ In progress | Phase 3.3 — uses `activitiesOnly` vs `requirements` |

### 3.10 Settings (Drawer)

| Feature | Status | Notes |
|---|---|---|
| Settings screen | ✅ Built | `student_settings_screen.dart` |
| Connectivity toggle | ✅ Built | Demo control for online/offline |
| Change password | ⚠️ Placeholder | |

### 3.11 Notifications

| Feature | Status | Notes |
|---|---|---|
| Notification list | ✅ Built | Static mock data |
| **Tap-through navigation** | ❌ Missing | Phase 6.2 — tap notification → relevant screen |

---

## 4. STUDENT DATA CONNECTIONS

### What Student reads from MockDatabase
- `currentUser` → Profile, identity (SHOULD read this, some screens hardcode identity)
- `activities` filtered by student's section → Activities tab
- `quizzesAndExams` filtered by student's section → Quiz/Exam tab
- `activitySubmissions` filtered by student ID → Submission status
- `assessmentResults` filtered by student ID → Quiz/exam results
- `attendanceRecords` filtered by student ID → Attendance screen
- `schedules` filtered by student's section → Schedule screen
- `materials` filtered by student's section → Learning Materials screen
- `notifications` → Notifications tab

### What Student writes to MockDatabase
- Submit activity (creates `StudentSubmission`)
- Submit quiz/exam answers (creates `AssessmentResultModel`)
- Change password (updates `_mockPasswords`)

### Important: Student data is READ from the SAME records Teacher writes
This is by design. When a teacher scores a submission, the student should see that score. When a teacher publishes grades, the student sees them. They share the same underlying `MockDatabase` records, just filtered differently.

---

## 5. STUDENT ↔ OTHER ROLE CONNECTIONS

```
Student ↔ Teacher:
   Teacher creates student account → Student can log in
   Teacher publishes activity → Student sees it in Activities tab
   Teacher publishes quiz/exam → Student sees it in Quiz/Exam tab
   Student submits work → Teacher sees it in Submissions
   Teacher scores submission → Student sees score + feedback
   Teacher records attendance → Student sees their attendance
   Teacher publishes grades → Student sees grades
   Teacher uploads materials → Student sees materials
   Teacher sets schedule → Student sees schedule

Student ↔ Parent:
   Student's attendance/grades/activities are visible to linked parent
   Student cannot manage parent's view

Student ↔ Admin:
   No direct interaction
   Admin sees student count only
```

---

## 6. MULTI-TEACHER/SUBJECT DESIGN

### Current State
The prototype shows ONE teacher (Karen P. Gonzaga) teaching ONE subject (General Mathematics) to the student.

### Required Design
Students can have **multiple teachers** for **multiple subjects**:

```
Student: Reyes, Alyssa M. (Section A, Grade 11)
├── General Mathematics → Teacher: Karen P. Gonzaga
│     ├── Activities: Functions Activity, Function Operations
│     ├── Quizzes: Functions Quiz
│     ├── PT: Functions Project
│     ├── Exams: ST1, ST2, TE
│     ├── Attendance: per this teacher's class
│     └── Grade: computed by this teacher
│
├── English → Teacher: (future teacher B)
│     ├── Activities: ...
│     ├── Quizzes: ...
│     └── Grade: computed by teacher B
│
├── Science → Teacher: (future teacher C)
│     └── ...
│
└── Filipino → Teacher: (future teacher D)
      └── ...
```

### UI Implications
- Home tab: group pending items by **subject**
- Activities tab: filter by subject or show all with subject label
- Quiz/Exam tab: show which subject each quiz belongs to
- Grades screen: per-subject breakdown → per-subject quarterly grade
- Schedule: shows all subjects/teachers for the section
- Notifications: may come from different teachers (label by subject)

### Data Implications
- Assessments must belong to a `TeachingAssignment` (not global)
- Student sees only assessments from teachers whose sections they're enrolled in
- Each subject has its own grading configuration (WW/PT/EX weights)
- Each subject has its own attendance (per that teacher's class schedule)

---

## 7. WHAT STUDENT STILL NEEDS

### 🔴 Critical

| # | Gap | Why It Matters | Plan Reference |
|---|---|---|---|
| 1 | **Fix hardcoded identity** | "Juan Dela Cruz" shows instead of actual logged-in student | Phase C (main plan) |
| 2 | **Wire quiz/exam to real assessment screen** | Start button shows fake dialog instead of actual assessment | STUDENT_SIDE Phase 1.1 |
| 3 | **Assessment result reflection** | Can "start" already-taken quiz, no score shown | STUDENT_SIDE Phase 1.4 |
| 4 | **Connectivity gate for quiz/exam** | Button says "Offline Safe" — contradicts spec | STUDENT_SIDE Phase 1.2 |

### 🟡 Important

| # | Gap | Why It Matters | Plan Reference |
|---|---|---|---|
| 5 | **Anti-cheating detection** | Violations never increment, timer doesn't count down | STUDENT_SIDE Phase 1.3 |
| 6 | **Submission status visibility** | Student can't tell if activity is graded/pending/missing | STUDENT_SIDE Phase 2 |
| 7 | **Separate requirements from activities** | PTs mixed into activities list | STUDENT_SIDE Phase 3 |
| 8 | **Real grades with per-item breakdown** | Only shows one hardcoded quarterly number | STUDENT_SIDE Phase 5 |

### 🟢 Nice to Have

| # | Gap | Plan Reference |
|---|---|---|
| 9 | Notification tap-through navigation | STUDENT_SIDE Phase 6.2 |
| 10 | De-duplicate Home vs Activities tab code | STUDENT_SIDE Phase 6.3 |
| 11 | Multi-subject UI grouping | Future phase |

---

## 8. STUDENT DEMO SCRIPT ALIGNMENT

Current demo script (`student_demo_script.md`) covers:

| Demo Step | Implemented? | Notes |
|---|---|---|
| Login with student/student123 | ✅ | |
| Student Home (name, grade, section, summary) | ✅ | Some hardcoded identity |
| Attendance Records | ✅ | Real screen built |
| Class Schedule | ✅ | Real screen built (needs data) |
| Learning Materials | ✅ | Real screen built |
| Academic Requirements | ⚠️ | Screen exists but in progress |
| Assessment / quiz/exam | ⚠️ | Being wired to real flow |
| Published Grades | ⚠️ | Screen exists but needs real calculation |
| Settings (connectivity toggle) | ✅ | |
| Logout | ✅ | |

---

## 9. KEY SOURCE FILES

| File | Size | Purpose |
|---|---|---|
| [`student_home_screen.dart`](file:///c:/Users/Admin/AndroidStudioProjects/class_realm/lib/features/student/screens/student_home_screen.dart) | 18 KB | Main student screen (bottom nav + drawer) |
| [`student_assessment_screen.dart`](file:///c:/Users/Admin/AndroidStudioProjects/class_realm/lib/features/student/screens/student_assessment_screen.dart) | 30 KB | Quiz/exam taking flow |
| [`student_attendance_screen.dart`](file:///c:/Users/Admin/AndroidStudioProjects/class_realm/lib/features/student/screens/student_attendance_screen.dart) | 7 KB | Attendance history |
| [`student_grades_screen.dart`](file:///c:/Users/Admin/AndroidStudioProjects/class_realm/lib/features/student/screens/student_grades_screen.dart) | 9 KB | Grades display |
| [`student_schedule_screen.dart`](file:///c:/Users/Admin/AndroidStudioProjects/class_realm/lib/features/student/screens/student_schedule_screen.dart) | 6 KB | Weekly schedule |
| [`student_learning_materials_screen.dart`](file:///c:/Users/Admin/AndroidStudioProjects/class_realm/lib/features/student/screens/student_learning_materials_screen.dart) | 5 KB | Materials list |
| [`student_requirements_screen.dart`](file:///c:/Users/Admin/AndroidStudioProjects/class_realm/lib/features/student/screens/student_requirements_screen.dart) | 2 KB | Performance tasks |
| [`student_settings_screen.dart`](file:///c:/Users/Admin/AndroidStudioProjects/class_realm/lib/features/student/screens/student_settings_screen.dart) | 4 KB | Settings + connectivity toggle |
| [`STUDENT_SIDE_IMPLEMENTATION_PLAN.md`](file:///c:/Users/Admin/AndroidStudioProjects/class_realm/STUDENT_SIDE_IMPLEMENTATION_PLAN.md) | 25 KB | Detailed phase-by-phase plan for student fixes |
