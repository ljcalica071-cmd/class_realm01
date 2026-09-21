# ClassRealm — Parent Side Flow

> **Status:** Working draft — not final
> **Platform:** Mobile-first (bottom navigation + drawer)
> **Last updated:** 2026-09-21

---

## 1. PARENT ROLE DEFINITION

The Parent is a **monitoring role** — they can VIEW their linked student's academic information but cannot edit, submit, or manage anything. The parent provides a guardian's window into the student's school life.

### What Parent IS
- Academic progress monitor (grades, attendance, activities, requirements)
- Schedule viewer (student's class schedule)
- Teacher contact viewer
- Notification receiver (about linked student's academic events)

### What Parent IS NOT
- NOT able to submit work, take quizzes, or edit any data
- NOT able to manage student accounts or academic settings
- NOT able to access teacher or admin functions
- View-only access to authorized student information

### Account Lifecycle
```
Teacher creates parent account linked to a specific student
→ Parent receives username + temporary password
→ Parent logs in for the first time
→ First Login Screen: must change password
→ Account becomes "active"
→ Parent sees linked student's academic information
```

---

## 2. PARENT NAVIGATION

```
Bottom Navigation (Primary):
├── 🏠 Overview
│     ├── Linked student name, section, grade level
│     ├── Academic summary cards
│     │     ├── Attendance summary (present/total days)
│     │     ├── Current grade overview
│     │     └── Recent activity count
│     └── Recent notices / academic updates
│
├── 📊 Attendance
│     ├── Student's attendance history
│     ├── Status badges: Present / Late / Absent / Excused
│     ├── Attendance rate percentage
│     └── Date-by-date breakdown
│
├── 📒 Grades
│     ├── Grading breakdown: WW 20% | PT 50% | EX 30%
│     ├── Per-category scores
│     ├── Performance summary
│     └── Quarterly grade (when published by teacher)
│
├── 🔔 Notifications
│     ├── Academic alerts about linked student
│     └── Deadline reminders, grade releases, attendance alerts
│
└── 👤 Profile
      ├── Parent name, email, contact
      ├── Linked student information
      └── Account settings

Side Drawer (Secondary):
├── 📅 Student's Schedule
│     ├── Weekly class schedule
│     ├── Subject, Room, Day, Start/End time
│     └── Per student's section
│
├── 📞 Teacher Contact
│     ├── Teacher name
│     ├── Subject taught
│     ├── Contact information
│     └── Communication channel
│
├── 📝 Activities & Requirements Status
│     ├── List of student's assigned activities
│     ├── Submission status (Submitted/Pending/Missing)
│     └── Requirement completion status
│
└── 🚪 Logout
```

---

## 3. PARENT FEATURES — DETAILED STATUS

### 3.1 Overview (Home)

| Feature | Status | Notes |
|---|---|---|
| Linked student name/section display | ⚠️ Hardcoded | Shows fixed presentation values, not from `currentUser` + student lookup |
| Academic summary cards | ✅ Built | Attendance, grades, activity counts |
| Recent academic updates | ✅ Built | Static mock notifications |
| Current academic info | ⚠️ Hardcoded | Labels show fixed values |

### 3.2 Attendance

| Feature | Status | Notes |
|---|---|---|
| Attendance records view | ✅ Built | Shows attendance data |
| Status badges | ✅ Built | Present/Late/Absent/Excused |
| Attendance rate | ⚠️ Hardcoded | Shows fixed "100% attendance" type values |
| **Real data from MockDatabase** | ⚠️ Partial | Should read same records as Teacher/Student |

### 3.3 Grades

| Feature | Status | Notes |
|---|---|---|
| Grading breakdown display | ✅ Built | Shows WW 20%, PT 50%, EX 30% |
| Performance summary | ✅ Built | Visual display |
| **Real grade data** | ❌ Blocked | Requires grading engine to exist first |
| **Per-item scores** | ❌ Missing | Only shows category-level summary |

### 3.4 Notifications

| Feature | Status | Notes |
|---|---|---|
| Notification list | ✅ Built | Static mock data |
| **Real event-based notifications** | ❌ Missing | All notifications are static, not generated from events |

### 3.5 Profile

| Feature | Status | Notes |
|---|---|---|
| Parent info display | ✅ Built | |
| Linked student info | ⚠️ Hardcoded | Fixed values, not dynamically loaded |

### 3.6 Student's Schedule (Drawer)

| Feature | Status | Notes |
|---|---|---|
| Schedule display | ⚠️ Placeholder | Shows a dialog with hardcoded schedule text, not a real screen |
| **Real schedule screen** | ❌ Missing | Should be a full screen reading from `MockDatabase.schedules` |

### 3.7 Teacher Contact (Drawer)

| Feature | Status | Notes |
|---|---|---|
| Teacher info display | ⚠️ Placeholder | Shows a dialog with hardcoded teacher info |
| **Real teacher contact screen** | ❌ Missing | Should read teacher info from MockDatabase |

### 3.8 Activities & Requirements Status (Drawer)

| Feature | Status | Notes |
|---|---|---|
| Activity status view | ⚠️ Partial | Not fully wired to real submission data |
| Requirement status view | ⚠️ Partial | Not fully wired |

---

## 4. PARENT DATA CONNECTIONS

### What Parent reads from MockDatabase
- `currentUser` → Parent profile (SHOULD read, currently hardcoded)
- `users` filtered by `linkedStudentId` → Linked student info
- `attendanceRecords` filtered by linked student ID → Attendance view
- `activities` filtered by linked student's section → Activity status
- `activitySubmissions` filtered by linked student ID → Submission status
- `assessmentResults` filtered by linked student ID → Exam results
- `gradingCriteria` → Grading breakdown percentages
- Grade records (when grading engine exists) → Published grades
- `schedules` filtered by linked student's section → Schedule
- `users` filtered by teacher role + student's section → Teacher contact
- `notifications` → Alerts

### What Parent writes to MockDatabase
- Nothing academic. Parent is **view-only**.
- Only: change own password

### Critical rule: Parent sees the SAME data as Student and Teacher
Parent attendance view = Student attendance view = Teacher attendance records — all from the same `MockDatabase.attendanceRecords`. When teacher records attendance, both student and parent should see it.

---

## 5. PARENT ↔ OTHER ROLE CONNECTIONS

```
Parent ↔ Student:
   Parent is LINKED to student via linkedStudentId
   Parent sees student's attendance, grades, activities, requirements, schedule
   Parent cannot edit student's data
   Parent cannot submit work on behalf of student

Parent ↔ Teacher:
   Parent sees teacher contact information
   Teacher creates parent account (linked to student)
   Teacher's academic actions (grades, attendance) are visible to parent
   Parent cannot communicate directly through the app (no messaging feature)

Parent ↔ Admin:
   No direct interaction
   Admin sees parent count only
```

---

## 6. MULTI-CHILD SUPPORT

### Current State
- Parent has single `linkedStudentId` (one student only)
- All parent content is hardcoded to one child
- No way to switch between children

### Required Design
A parent may have multiple children in the school:

```
Parent: Maricel Reyes
├── Child 1: Reyes, Alyssa M. (Section A, Grade 11)
│     ├── Attendance: ...
│     ├── Grades: ...
│     └── Activities: ...
│
└── Child 2: Reyes, Marco M. (Section B, Grade 12) [future]
      ├── Attendance: ...
      ├── Grades: ...
      └── Activities: ...
```

### What needs to change

| Change | Description |
|---|---|
| Model change | Replace `String linkedStudentId` with `List<String> linkedStudentIds` |
| UI change | Add student switcher (dropdown/tab at top of parent home) |
| Data change | All parent queries filter by **selected** student, not fixed student |
| Default | Auto-select first child on login |
| Mock data change | Keep current 1:1 parent-student mapping but model supports multiple |

### UI Concept for Multi-Child
```
┌──────────────────────────────────┐
│  👦 Alyssa Reyes (Section A) ▼  │  ← Student switcher dropdown
├──────────────────────────────────┤
│  [Overview] [Attendance] [Grades]│  ← Bottom nav
│                                  │
│  Content for selected child      │
│  All data filtered by selected   │
│  student's ID                    │
│                                  │
└──────────────────────────────────┘
```

---

## 7. WHAT PARENT STILL NEEDS

### 🔴 Critical

| # | Gap | Why It Matters |
|---|---|---|
| 1 | **Fix hardcoded content** | Parent shows static labels instead of real data from `currentUser` + linked student lookup. Demo looks fake. |
| 2 | **Wire to real MockDatabase data** | Attendance, grades, activities should read from same shared records that Teacher/Student use. Currently many values are presentation-only. |

### 🟡 Important

| # | Gap | Why It Matters |
|---|---|---|
| 3 | **Replace schedule dialog with real screen** | Currently a `showSuccessDialog` with hardcoded text. Should be a full screen like student's schedule screen. |
| 4 | **Replace teacher contact dialog with real screen** | Same — dialog with hardcoded teacher info. Should read from MockDatabase. |
| 5 | **Activity/requirement status view** | Parent should see what activities the student has submitted/missing, with status badges. |
| 6 | **Real grade data connection** | Blocked by grading engine — but once it exists, parent must show published grades. |
| 7 | **Multi-child model support** | Even if demo uses 1 child, the model should support `List<linkedStudentIds>` for future-proofing. |

### 🟢 Nice to Have

| # | Gap |
|---|---|
| 8 | Multi-child student switcher UI |
| 9 | Real event-based notifications (grade published, attendance alert) |
| 10 | Responsive tablet layout |
| 11 | Performance trends / charts for parent view |

---

## 8. PARENT DEMO SCRIPT ALIGNMENT

Current demo script (`parent_demo_script.md`) covers:

| Demo Step | Implemented? | Notes |
|---|---|---|
| Login with parent/parent123 | ✅ | |
| Linked student overview | ✅ | Hardcoded content though |
| Summary cards (attendance, grades, activity) | ✅ | Hardcoded values |
| Student's Schedule | ⚠️ | Dialog only, not real screen |
| Teacher Contact | ⚠️ | Dialog only, not real screen |
| Attendance records | ✅ | But some values hardcoded |
| Grades / performance area | ✅ | Shows breakdown, but not from real calculation |
| Grading breakdown (WW 20%, PT 50%, EX 30%) | ✅ | |
| Recent updates | ✅ | Static mock |
| Profile | ✅ | |
| Logout | ✅ | |

### Gap between demo script and reality
The demo script can be walked through successfully because all the screens exist. However, the **data shown is mostly hardcoded presentation values**, not real data from MockDatabase. A careful reviewer would notice that changing the logged-in parent wouldn't change the displayed student information.

---

## 9. KEY SOURCE FILES

| File | Size | Purpose |
|---|---|---|
| [`parent_home_screen.dart`](file:///c:/Users/Admin/AndroidStudioProjects/class_realm/lib/features/parent/screens/parent_home_screen.dart) | 22 KB | Entire parent interface — bottom nav + drawer + all sections |
| [`mock_database.dart`](file:///c:/Users/Admin/AndroidStudioProjects/class_realm/lib/data/mock_database.dart) | 40 KB | Parent reads student/attendance/grade data here |
| [`user_model.dart`](file:///c:/Users/Admin/AndroidStudioProjects/class_realm/lib/models/user_model.dart) | 3 KB | `linkedStudentId` field, parent-student relationship |

### Observation
Parent has only **ONE source file** (`parent_home_screen.dart`). Everything is in one screen. This is manageable for now since parent is a simpler role, but the schedule/contact/activities features should eventually become separate screens instead of dialogs.
