# ClassRealm — Main System Flow
# Auth, Backend, Database, Data Models, Shared Logic

> **Status:** Working draft — not final
> **Last updated:** 2026-09-21

---

## 1. AUTHENTICATION & ACCOUNT LIFECYCLE

### Login Flow
```
App Launch
   → Login Screen
   → Validate credentials (mock authentication)
   → Check account status:
      - Active → Route to role dashboard
      - Pending → Pending Account Screen
      - Deactivated → Error modal
      - PendingFirstLogin → First Login Screen (change temp password) → Route to dashboard
      - Rejected → Error modal
   → Check role:
      - Admin → Admin Dashboard
      - Teacher → Teacher Dashboard
      - Student → Student Home
      - Parent → Parent Home
```

### Account States
| State | Meaning | Can Login? |
|---|---|---|
| `active` | Normal operating state | ✅ Yes |
| `pending` | Awaiting approval (teacher) or activation (student/parent) | ❌ No → Pending screen |
| `rejected` | Admin rejected teacher registration | ❌ No → Error |
| `archived` | Soft-deleted from active lists | ❌ No |
| `pendingFirstLogin` | Account created by teacher, must change temp password | ✅ Yes → forced to change password first |
| `deactivated` | Blocked from system | ❌ No → Error |

### Account Creation Flows

**Teacher Account (2 paths):**
```
Path 1: Self-registration (WEB ONLY — Android must NOT show registration)
   Teacher fills registration form (no Department/Specialization fields)
   → Account created as "pending"
   → Admin reviews in Pending Approvals
   → Admin approves → Account becomes "active"
   → Admin rejects → Account becomes "rejected"

Path 2: Admin creates directly
   Admin fills teacher account form
   → Account created as "active" immediately
```

**Student Account:**
```
Teacher creates student in Manage Students
   → System generates username + temporary password
   → Duplicate check (username uniqueness)
   → Account created as "pendingFirstLogin"
   → Student logs in with temp credentials
   → First Login Screen: must change password
   → Account becomes "active"
```

**Parent Account:**
```
Teacher creates parent in Manage Parents
   → Linked to specific student via linkedStudentId
   → System generates username + temporary password
   → Account created as "pendingFirstLogin"
   → Parent logs in with temp credentials
   → First Login Screen: must change password
   → Account becomes "active"
```

### Demo Accounts (for prototype)
| Role | Username | Password |
|---|---|---|
| Admin | `admin` | `admin123` |
| Teacher | `teacher` | `teacher123` |
| Student | `student` | `student123` |
| Parent | `parent` | `parent123` |

### Registration Rules
- Teacher registration: **web-only**. Android app must NOT route to registration screen.
- Student/Parent: **NO self-registration.** Only Teacher creates these accounts.
- Passwords: stored plain-text in mock (`_mockPasswords` map). Future: Firebase Auth with hashing.

---

## 2. TARGET BACKEND ARCHITECTURE (Not yet implemented)

> ⚠️ Everything in this section describes the **future** architecture. Currently the prototype uses `MockDatabase` (in-memory singleton).

### Target Technology Stack
| Layer | Technology | Purpose |
|---|---|---|
| Auth | Firebase Authentication | Secure login, password hashing, sessions |
| Database | Cloud Firestore | All academic records |
| File Storage | Firebase Storage | Materials, submissions, profile photos |
| Push Notifications | Firebase Cloud Messaging | Real-time alerts |
| Local Storage | Hive / SharedPreferences | Offline attendance queue, cached session |
| Hardware | ESP32 + RFID | Attendance data collection |

### Current State (Prototype)
- **MockDatabase singleton** in `lib/data/mock_database.dart` (40KB)
- All data lives in-memory, **resets on app restart**
- Widgets call `MockDatabase.instance` directly — **no repository/service layer**
- No state management library (no Provider, Riverpod, Bloc, etc.)
- Screens use `setState` after mutations — no cross-screen reactive sync

---

## 3. DATA MODEL DESIGN

### Core Entities That SHOULD Exist

```
SchoolYear (e.g., "2026-2027")
   └── Section (e.g., "Section A", "Section B")
         └── Enrollment (Student ↔ Section ↔ SchoolYear)

Teacher
   └── TeachingAssignment (Teacher ↔ Subject ↔ Section ↔ SchoolYear)
         ├── AssessmentItem (WW / PT / EX items created by teacher)
         │     └── Submission (student's work for that item)
         ├── AttendanceSession (a day's attendance for a section)
         │     └── AttendanceRecord (per-student attendance)
         ├── GradingCriteria (WW %, PT %, EX % configured by teacher)
         ├── GradeRecord (calculated quarterly grade per student)
         ├── LessonPlan
         ├── LearningMaterial
         ├── Schedule
         └── Notification

Student
   └── ParentStudentLink → Parent
```

### Current State vs Required State

| Entity | Current State | What's Needed |
|---|---|---|
| SchoolYear | String `"2026-2027"` | Real entity with ID |
| Section | String `"Section A"` | Real entity with ID, linked to SchoolYear |
| Subject | String `"General Mathematics"` | Real entity with ID |
| Enrollment | ❌ Does not exist | Model linking Student ↔ Section ↔ SchoolYear |
| TeachingAssignment | ❌ Does not exist | Model linking Teacher ↔ Subject ↔ Section ↔ Year |
| AssessmentItem | Split: `ActivityModel` + `QuizOrExamModel` with boolean flags | Unified model with explicit `AssessmentCategory` enum |
| Submission | Split: `StudentSubmission` + `AssessmentResultModel` | Should reference source item's maxScore, section, subject, term, student |
| GradeRecord | ❌ Does not exist | Quarterly grade per student/subject/section |
| AttendanceSession | ❌ Does not exist | Container for a day's attendance per section |
| ParentStudentLink | `linkedStudentId` (single string) | Should support multiple children (`List<String>`) |
| GradingCriteria | Exists but not connected to calculations | Must feed into grading engine |

### Assessment Category Model (NEEDED)

Currently:
- Activities: `ActivityModel` with `isRequirement = false`
- Performance Tasks: `ActivityModel` with `isRequirement = true` (overloaded boolean)
- Quizzes: `QuizOrExamModel` with `isExam = false`
- Exams (ST1/ST2/TE): `QuizOrExamModel` with `isExam = true`, subtype inferred from title string

Should be:
```dart
enum AssessmentCategory {
  writtenWork,        // WW — Activities, Assignments, Quizzes
  performanceTask,    // PT — Performance Tasks, Projects
  summativeTest1,     // EX — ST1
  summativeTest2,     // EX — ST2
  termExamination,    // EX — TE
}
```

---

## 4. DATA FLOW PATTERN

### Current (Prototype)
```
Widget/Screen → reads/writes → MockDatabase.instance (singleton)
```
Problems:
- No abstraction layer
- Can't swap mock for Firebase without editing every widget
- No reactive updates across screens
- Restarting app loses all data

### Target Pattern
```
Widget/Screen → Repository Interface → Implementation (Mock or Firebase)
                                            ↓
                                     MockDatabase (now)
                                     Firebase Firestore (later)
                                     Local Storage/Hive (offline)
```

### What to build (before Firebase phase)
1. Create `lib/repositories/` or `lib/services/` directory
2. Define interfaces: `AuthRepository`, `AssessmentRepository`, `AttendanceRepository`, `GradeRepository`, etc.
3. Create mock implementations that wrap MockDatabase
4. Widgets call repository interfaces instead of MockDatabase directly
5. Later: create Firebase implementations that replace mock implementations

---

## 5. MULTI-TEACHER DESIGN LOGIC

### Current limitation
The entire prototype is built around ONE teacher (Karen P. Gonzaga). Adding a second teacher would cause data leaks — they'd see each other's students, assessments, and grades.

### Required isolation rules
1. A teacher sees **only** sections assigned to them via TeachingAssignment
2. Students visible to a teacher only if enrolled in that teacher's sections
3. Assessments belong to a TeachingAssignment, not globally
4. Grades, attendance, submissions scoped by teacher's assignment
5. Two teachers handling the same section (different subjects) → same students, different assessments/grades

### Example scenario
```
Teacher A (Karen Gonzaga): General Mathematics, Section A + B
Teacher B (future): English, Section A + B

Section A students appear to BOTH teachers
BUT:
- Teacher A sees only Math assessments/grades for Section A
- Teacher B sees only English assessments/grades for Section A
- They never see each other's gradebook, activities, or exams
```

### What needs to change
- Replace string-based section/subject/year with proper entity IDs
- Filter ALL queries by `currentUser.teacherId` + TeachingAssignment scope
- Add TeachingAssignment check before showing any academic data

---

## 6. SHARED LOGIC MODULES

These are modules used by multiple roles that need to be built as independent, testable services:

| Module | Description | Current State | Priority |
|---|---|---|---|
| **Grading Engine** | Calculate WW 20%, PT 50%, EX 30%, transmutation, quarterly grade | ❌ Not implemented | 🔴 Critical |
| **Assessment Category** | Explicit enum replacing boolean flags | ❌ Not implemented | 🔴 Critical |
| **Route Guards** | Centralized role-based permission checks | ❌ Not implemented | 🔴 Critical |
| **Notification Generator** | Auto-create notifications from academic events | ❌ Not implemented | 🟡 High |
| **Offline Sync Queue** | Queue attendance mutations offline, sync when online | ⚠️ Simulated only | 🟠 Medium |
| **Export Engine** | Generate CSV/PDF for grades, attendance, reports | ⚠️ Placeholder button only | 🟢 Lower |

### Grading Engine Specification
```
Input per student per subject per quarter:
  - All WW scores (activities, assignments, quizzes)
  - All PT scores (performance tasks, projects)
  - All EX scores (ST1, ST2, TE)
  - Category weights: WW = 20%, PT = 50%, EX = 30%

Calculation:
  1. Per category: total_earned / total_possible × 100 = category_percentage_score
  2. Weighted: (WW_score × 0.20) + (PT_score × 0.50) + (EX_score × 0.30) = initial_grade
  3. Apply DepEd transmutation table → transmuted_grade
  4. Round to nearest whole number
  5. Store as GradeRecord

Special rules:
  - EX sub-weights: ST1 + ST2 + TE (TE at 40% per teacher specification)
  - Missing scores: teacher decides policy (zero or exclude)
  - Must validate that category weights sum to 100%
```

---

## 7. OFFLINE / SYNCHRONIZATION DESIGN

### What works offline: ATTENDANCE ONLY
```
ESP32/RFID scans student card
→ If online: record sent directly to server
→ If offline: record saved to local storage (Hive/SharedPreferences)
   → Show "Saved locally" / "Pending synchronization"
   → When connectivity returns:
      → Show "Syncing..."
      → Attempt upload
      → Show "Synced successfully" or "Sync error"
```

### What REQUIRES internet: QUIZ & EXAM
```
Student taps "Start Quiz/Exam"
→ Check connectivity
→ If offline: BLOCK entry with warning
   "Internet connection lost. Quiz access is temporarily unavailable."
→ If online: proceed to assessment
→ If connection lost DURING assessment: show blocking banner
```

### Connection States
- `ONLINE`
- `OFFLINE`
- `PENDING_SYNC`
- `SYNCING`
- `SYNCED`
- `SYNC_ERROR`

### Current state: simulated via `SyncStatus` enum and mock toggle. No real queue, retry, or conflict resolution.

---

## 8. CANONICAL MOCK DATA REFERENCE

All modules must use the same data source:
- **Teacher:** Karen P. Gonzaga (T001), Grade 11 General Mathematics
- **Sections:** Section A and Section B ONLY
- **Students:** 10 total (5 per section) — see CLASSREALM_SSTruth_Mock_Data.txt
- **Parents:** 10 total (1 per student)
- **Assessments:** 7 total (WW1, WW2, WW3, PT1, EX1/ST1, EX2/ST2, EX3/TE)
- **Attendance:** 5 school days (09-14 to 09-18-2026), 1 Late + 1 Absent per section
- **Grading weights:** WW = 20%, PT = 50%, EX = 30%

Source file: `lib/CLASSREALM_SSTruth_Mock_Data.txt`
