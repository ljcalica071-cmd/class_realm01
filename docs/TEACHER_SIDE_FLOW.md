# ClassRealm — Teacher Side Flow

> **Status:** Working draft — not final
> **Platform:** Desktop/Web-first (responsive to tablet)
> **Last updated:** 2026-09-21

---

## 1. TEACHER ROLE DEFINITION

The Teacher is the **primary academic manager** — the heart of the system. In this capstone context, the client is Ms. Karen P. Gonzaga, a Grade 11 Mathematics teacher. But the system design must accommodate additional teachers handling different subjects/sections without data leaks.

### What Teacher IS
- Academic setup owner (school year, sections, subjects, schedules)
- Student/parent account creator
- Assessment creator and grader (activities, quizzes, exams)
- Attendance recorder (RFID + manual)
- Gradebook manager (configure weights, calculate, publish grades)
- Lesson planner and materials manager
- Performance analyst and report generator

### What Teacher IS NOT
- NOT a system administrator (can't manage other teacher accounts)
- NOT able to see another teacher's data (isolation by TeachingAssignment)

### Self-Managed Design
- **Teacher sets up their own academic structure** — Admin does NOT assign sections, subjects, or schedules
- After Admin approves the account, Teacher independently defines: Academic Year, Grade Level, Section, Subject, Schedule, Grading Criteria

---

## 2. TEACHER NAVIGATION

```
Desktop Sidebar:
├── 📊 Dashboard
│     ├── Class summary cards (total students, sections, today's attendance)
│     ├── Today's Classes panel
│     ├── Upcoming assessments
│     ├── Pending submissions count
│     ├── Anti-cheating alerts
│     ├── Offline/sync status for attendance
│     └── View All Schedule link
│
├── 🏫 Classroom Setup
│     ├── Academic Year (e.g., 2026-2027)
│     ├── Grade Level (e.g., Grade 11)
│     ├── Subject (e.g., General Mathematics)
│     ├── Sections (e.g., Section A, Section B)
│     ├── Manage Students
│     │     ├── Student list (active/archived tabs)
│     │     ├── Add student (generate temp credentials)
│     │     ├── Edit student
│     │     ├── View student details
│     │     ├── Archive / Restore student
│     │     ├── Deactivate / Reactivate student
│     │     ├── Permanent delete
│     │     └── Search / Filter by section
│     └── Manage Parents
│           ├── Parent directory
│           ├── Linked student display
│           └── Search / Sort
│
├── 📝 Assessments & Classwork
│     ├── Tab: Written Works (WW)
│     │     ├── Activities / Assignments
│     │     └── Quizzes
│     ├── Tab: Performance Tasks (PT)
│     │     └── Performance Tasks / Projects
│     ├── Tab: Examinations (EX)
│     │     ├── Summative Test 1 (ST1)
│     │     ├── Summative Test 2 (ST2)
│     │     └── Term Examination (TE)
│     ├── Create new (type chooser → opens appropriate form)
│     ├── Publish / Unpublish
│     ├── View submissions per activity
│     ├── Score submissions with feedback
│     └── Per-section due date/time
│
├── 📋 Attendance
│     ├── Daily attendance records
│     ├── Section filter
│     ├── Date selection
│     ├── Status summary (Present/Late/Absent/Excused)
│     ├── Manual status toggle
│     ├── RFID method indicator (simulated)
│     ├── Sync status (Online/Offline/Pending/Synced)
│     └── Search students
│
├── ✅ Exam Checker
│     ├── Select submitted exam
│     ├── View student answers vs answer key
│     ├── Auto-check objective questions
│     ├── Calculate score
│     ├── Manual review / adjust score
│     ├── Finalize result
│     └── Release result to student
│
├── 🔍 Assessment Monitoring
│     ├── Per quiz/exam submission list
│     ├── Columns: Student, Start time, Submit time, Duration, Status, Score, Violations
│     ├── Status: Normal / Warning / Suspicious Activity / Auto Submitted
│     └── Violation timeline detail view
│
├── 📊 Item Analysis
│     ├── Exam filter / Section filter / Date filter
│     ├── Per-question stats: correct count, incorrect count, % correct
│     ├── Difficulty indicator
│     ├── Summary cards
│     └── Charts
│
├── 📐 Grading System
│     ├── Configure grading components (WW / PT / EX / custom)
│     ├── Set percentage per component
│     ├── Validate total = 100%
│     ├── Save grading configuration
│     └── View grading breakdown
│
├── 📒 Gradebook
│     ├── Grading period / Section filter
│     ├── WW / PT / EX category sections
│     ├── Per-student score rows
│     ├── Weighted grade calculation (NEEDS IMPLEMENTATION)
│     ├── Transmutation (NEEDS IMPLEMENTATION)
│     └── Export Grades (placeholder)
│
├── 📈 Performance Analytics
│     ├── Class average
│     ├── Per-student performance
│     ├── Quiz / Exam / Activity performance
│     ├── Attendance correlation
│     ├── Quarter comparison (Q1-Q4)
│     ├── Students needing attention
│     └── Charts and visualizations
│
├── 📄 Reports
│     ├── Attendance reports
│     ├── Grade reports
│     └── Summary reports
│
├── 📚 Lesson Planning
│     ├── Create lesson plan (manual)
│     ├── AI Generate lesson plan (simulated — no real API)
│     ├── Edit / Save lesson plan
│     ├── Search lesson plans
│     ├── View previous plans
│     └── Archive plans
│
├── 📁 Learning Materials
│     ├── Upload material (mock file interaction)
│     ├── Categorize: PDF / Document / Presentation / Image / Link
│     ├── Section assignment
│     ├── Search materials
│     ├── View / Mock download
│     └── Archive materials
│
├── 📅 Schedule
│     ├── Create schedule entries
│     ├── Edit / Delete schedule
│     ├── Daily / Weekly view
│     ├── Subject, Section, Room, Day, Start/End time
│     └── Calendar view
│
├── 🔔 Notifications
│     ├── System alerts
│     ├── Academic event notifications
│     └── Student activity alerts
│
├── 👤 Profile
├── ⚙️ Settings
└── 🚪 Logout
```

---

## 3. TEACHER FEATURES — DETAILED STATUS

### 3.1 Classroom Setup & Students

| Feature | Status | Notes |
|---|---|---|
| Academic year / grade / subject / section setup | ✅ Built | String-based; needs proper entity models |
| Student CRUD (add, edit, view, archive, search) | ✅ Built | Generates username + temp password |
| Student duplicate check | ✅ Built | Checks username uniqueness |
| Student account generation | ✅ Built | pendingFirstLogin → first login changes password |
| Parent directory | ✅ Built | Shows linked parents |
| Section association | ✅ Built | Students assigned to Section A / B |
| LRN validation | ✅ Built | 12-digit numeric per DepEd format |

### 3.2 Assessments & Classwork

| Feature | Status | Notes |
|---|---|---|
| Unified WW/PT/EX tab view | ✅ Built | Groups by category |
| Activity/Assignment creation (WW) | ✅ Built | Title, instructions, section, deadline, maxScore, publish state |
| Performance Task creation (PT) | ✅ Built | Uses `isRequirement=true` → **should be explicit category** |
| Quiz creation (WW) | ✅ Built | Question builder, answer keys, choices, points, duration |
| Exam creation (ST1/ST2/TE) | ✅ Built | Uses `isExam` boolean → **should be explicit category** |
| Question types: MC, T/F, Matching, Identification | ✅ Built | |
| Per-section due date/time | ✅ Built | Section A/B selection with separate due dates |
| Publish / Unpublish | ✅ Built | |
| View submissions list | ✅ Built | activity_submissions_screen.dart |
| Score submissions with feedback | ✅ Built | Local mutation |
| Submission status display | ✅ Built | Graded/Pending/Unsubmitted with color coding |
| **Bulk quiz upload from file** | ❌ Missing | System plan mentions this |

### 3.3 Attendance

| Feature | Status | Notes |
|---|---|---|
| Daily attendance records | ✅ Built | Mock data: 5 days, 10 students |
| Section filter | ✅ Built | |
| Date selection | ✅ Built | |
| Status summary (P/L/A/E) | ✅ Built | |
| Manual status toggle | ✅ Built | Teacher can change P/L/A/E |
| RFID method display | ⚠️ Simulated | Shows "RFID" vs "Manual" tag, no hardware |
| Offline sync status | ⚠️ Simulated | Visual toggle, no real queue |
| Search students | ✅ Built | |

### 3.4 Grading

| Feature | Status | Notes |
|---|---|---|
| Grading criteria display (WW 20%, PT 50%, EX 30%) | ✅ Built | |
| Configure/update criteria | ✅ Built | Can change percentages |
| Validate total = 100% | ✅ Built | |
| Gradebook item grouping | ✅ Built | Shows WW/PT/EX sections with items |
| **Grade calculation engine** | ❌ Missing | **CRITICAL GAP** — no formula, no aggregation |
| **Transmutation table** | ❌ Missing | Required for DepEd grading |
| **Quarter/Final grade per student** | ❌ Missing | No GradeRecord entity |
| **Grade publication to students/parents** | ❌ Missing | |
| **Grade correction/history** | ❌ Missing | |
| **Export grades** | ⚠️ Placeholder | Button exists, no file generation |

### 3.5 Exam Checker & Assessment Monitoring

| Feature | Status | Notes |
|---|---|---|
| Exam checker UI | ✅ Built | View answers, compare with key |
| Auto-check objective questions | ✅ Built | Local comparison against correctAnswer |
| Manual review | ⚠️ Partial | UI exists, complete workflow missing |
| Finalize & release results | ⚠️ Partial | Not a complete end-to-end flow |
| Assessment Monitoring tab | ⚠️ In progress | Being built per STUDENT_SIDE plan Phase 1.7 |
| Violation timeline view | ⚠️ In progress | Needs violationLog data from student side |

### 3.6 Other Features

| Feature | Status | Notes |
|---|---|---|
| Item Analysis | ✅ Built | Per-question stats, filters, charts (mock data) |
| Performance Analytics | ✅ Built | Class average, per-student, charts (mock) |
| Reports | ⚠️ Placeholder | Views exist, no calculation pipeline behind them |
| Lesson Planning | ✅ Built | Create, edit, search, view history |
| AI Lesson Plan Generator | ⚠️ Simulated | Shows mock generated content, no real API |
| Learning Materials | ✅ Built | Upload mock, categorize, section assignment |
| Schedule | ⚠️ Partial | ScheduleModel exists, needs populated data |
| Notifications | ✅ Built | Static mock notifications |

---

## 4. TEACHER DATA CONNECTIONS

### What Teacher reads from MockDatabase
- `currentUser` → Profile, dashboard identity
- `users` filtered by students in teacher's sections → Manage Students
- `users` filtered by parents linked to those students → Manage Parents
- `activities` → WW and PT items
- `quizzesAndExams` → WW quizzes and EX exams
- `activitySubmissions` → Student submission tracking
- `assessmentResults` → Quiz/exam results, violations
- `attendanceRecords` → Daily attendance
- `gradingCriteria` → Grading configuration
- `lessonPlans` → Lesson planning
- `materials` → Learning materials
- `schedules` → Class schedule
- `notifications` → Alert center

### What Teacher writes to MockDatabase
- Create/edit/archive students and parents
- Create/edit/delete activities, quizzes, exams
- Score student submissions
- Toggle attendance status
- Create/edit lesson plans
- Upload/edit learning materials
- Create/edit schedule entries
- Update grading criteria

### Data scoping requirement
All teacher reads/writes should be filtered by the teacher's TeachingAssignment (teacher → subject → sections → school year). Currently **NOT scoped** — a second teacher would see all data.

---

## 5. TEACHER ↔ OTHER ROLE CONNECTIONS

```
Teacher ↔ Admin:
   Admin approves/creates teacher account → Teacher can log in
   Teacher cannot manage other teacher accounts

Teacher ↔ Student:
   Teacher creates student account (temp credentials)
   Teacher creates/publishes assessments → Students see them
   Teacher records attendance → Students see their records
   Teacher scores submissions → Students see scores/feedback
   Teacher publishes grades → Students see grades
   Teacher uploads materials → Students access materials
   Teacher sets schedule → Students see schedule

Teacher ↔ Parent:
   Teacher creates parent account linked to student
   Teacher publishes grades → Parents see linked student's grades
   Teacher records attendance → Parents see linked student's attendance
   Teacher creates activities → Parents see linked student's activity status
```

---

## 6. WHAT TEACHER STILL NEEDS

### 🔴 Critical

| # | Gap | Why It Matters |
|---|---|---|
| 1 | **Grading calculation engine** | System claims to calculate grades but NO formula exists. Gradebook shows items only — no WW/PT/EX weighted calculation, no transmutation, no quarterly grade |
| 2 | **Split teacher_dashboard_screen.dart** | 316KB file with 7000+ lines. Contains legacy + new renderers. Extremely fragile to edit. Must split into feature files |
| 3 | **Explicit assessment category** | `isRequirement` boolean and title-string exam subtype are fragile. Need explicit `AssessmentCategory` enum |
| 4 | **Data scoping by teacher** | Adding a second teacher would leak data. Needs TeachingAssignment-based filtering |

### 🟡 Important

| # | Gap | Why It Matters |
|---|---|---|
| 5 | **Complete exam review/release workflow** | Teacher needs end-to-end: view → review → adjust → finalize → release → student sees |
| 6 | **Assessment Monitoring with real data** | Needs student-side violation logging to actually show data |
| 7 | **Notification generation from events** | All notifications are static. Should auto-generate when: deadline approaching, grade published, submission received, violation detected |
| 8 | **Schedule data population** | MockDatabase.schedules was empty — being populated per STUDENT_SIDE plan |
| 9 | **Reports calculation pipeline** | Report views exist but show placeholder data |

### 🟢 Nice to Have

| # | Gap |
|---|---|
| 10 | Bulk quiz upload from file |
| 11 | Real CSV/PDF export for grades and attendance |
| 12 | Responsive tablet/mobile layout for teacher dashboard |
| 13 | Teacher-to-teacher schedule conflict detection (when multi-teacher) |

---

## 7. TEACHER DEMO SCRIPT ALIGNMENT

Current demo script (`teacher_demo_script.md`) covers:

| Demo Step | Implemented? | Notes |
|---|---|---|
| Login with teacher/teacher123 | ✅ | |
| Dashboard overview + Today's Classes | ✅ | |
| View All Schedule | ⚠️ | Schedule data was empty, being populated |
| Classroom Setup (year/level/subject/sections) | ✅ | |
| Manage Students (list, search, add) | ✅ | |
| Manage Parents | ✅ | |
| Classwork (create activity/requirement) | ✅ | |
| View submissions | ✅ | |
| Lesson Planning | ✅ | |
| Learning Materials | ✅ | |
| Attendance (records, sync status) | ✅ | |
| Assessment Monitoring | ⚠️ | Being built |
| Item Analysis | ✅ | |
| Gradebook / Grades | ⚠️ | Shows structure, no calculated grades |
| Logout | ✅ | |

---

## 8. KEY SOURCE FILES

| File | Size | Purpose |
|---|---|---|
| [`teacher_dashboard_screen.dart`](file:///c:/Users/Admin/AndroidStudioProjects/class_realm/lib/features/teacher/screens/teacher_dashboard_screen.dart) | 316 KB | **MASSIVE** — entire teacher dashboard, all tabs, legacy + new code |
| [`create_assessment_flow.dart`](file:///c:/Users/Admin/AndroidStudioProjects/class_realm/lib/features/teacher/screens/create_assessment_flow.dart) | 56 KB | Quiz/exam creation with question builder |
| [`create_requirement_flow.dart`](file:///c:/Users/Admin/AndroidStudioProjects/class_realm/lib/features/teacher/screens/create_requirement_flow.dart) | 19 KB | Performance Task creation (still uses "requirement" naming) |
| [`activity_submissions_screen.dart`](file:///c:/Users/Admin/AndroidStudioProjects/class_realm/lib/features/teacher/screens/activity_submissions_screen.dart) | 18 KB | View and score student submissions |
| [`edit_assessment_flow.dart`](file:///c:/Users/Admin/AndroidStudioProjects/class_realm/lib/features/teacher/screens/edit_assessment_flow.dart) | 8 KB | Edit existing assessment |
| [`mock_database.dart`](file:///c:/Users/Admin/AndroidStudioProjects/class_realm/lib/data/mock_database.dart) | 40 KB | All teacher data operations |
| [`academic_models.dart`](file:///c:/Users/Admin/AndroidStudioProjects/class_realm/lib/models/academic_models.dart) | 16 KB | All academic entity definitions |
