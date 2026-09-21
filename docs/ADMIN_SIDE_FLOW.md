# ClassRealm — Admin Side Flow

> **Status:** Working draft — not final
> **Platform:** Desktop/Web-first
> **Last updated:** 2026-09-21

---

## 1. ADMIN ROLE DEFINITION

The Admin is the **system-level manager**. In this capstone context, the Admin represents the developers (you — the capstone team).

### What Admin IS
- Teacher account manager (approve, reject, create, edit, deactivate, delete)
- System monitor (user counts, system health, statistics)

### What Admin IS NOT
- NOT an academic manager
- Admin does NOT manage: activities, requirements, quizzes, exams, exam checking, item analysis, lesson plans, learning materials, student grades, attendance, grading systems, schedules, academic years, sections, subjects, teacher-subject assignments, or student academic records

### Why this boundary exists
The system is designed so that **teachers manage their own academic operations**. The Admin only ensures that teacher accounts are legitimate and the system is running properly. This keeps the roles clean and prevents confusion about who controls academic data.

---

## 2. ADMIN NAVIGATION

```
Desktop Sidebar:
├── 📊 Dashboard (Institutional Overview)
│     ├── Total Teachers count
│     ├── Total Students count
│     ├── Total Parents count
│     ├── Pending Approvals count/badge
│     └── System health summary cards
│
├── 👩‍🏫 Teacher Management
│     ├── Teacher accounts directory (table/list)
│     ├── Search teachers
│     ├── Filter by status: All / Active / Pending / Deactivated
│     ├── Create new teacher account
│     ├── View teacher details
│     ├── Edit teacher account
│     ├── Deactivate / Reactivate teacher
│     └── Delete teacher account
│
├── ⏳ Pending Approvals
│     ├── List of pending teacher registration requests
│     ├── View applicant details (name, email, department)
│     ├── Approve → account becomes "active"
│     └── Reject → account becomes "rejected"
│
├── 📈 System Statistics
│     ├── User count analytics
│     ├── Account status distribution
│     └── System-wide charts (placeholder)
│
├── 👤 Admin Profile
│     ├── Admin name, email
│     └── System-wide access level display
│
├── ⚙️ Settings
│     ├── Simulated email notification toggle
│     └── Simulated maintenance mode toggle
│
└── 🚪 Logout → Return to login screen
```

---

## 3. ADMIN FEATURES — DETAILED STATUS

### 3.1 Dashboard (Institutional Overview)
| Feature | Status | Details |
|---|---|---|
| Summary cards (teacher/student/parent counts) | ✅ Built | Reads from MockDatabase user list, counts by role |
| Pending Teacher Onboarding section | ✅ Built | Shows badge with count of pending teachers |
| System status overview | ⚠️ Partial | Cards exist, some are placeholder |

### 3.2 Teacher Management
| Feature | Status | Details |
|---|---|---|
| Teacher accounts directory | ✅ Built | Lists all teacher users from MockDatabase |
| Search teachers | ✅ Built | Name-based search |
| Filter by status | ✅ Built | All / Active / Pending tabs |
| Create teacher account | ✅ Built | Form creates account as "active" directly |
| View teacher details | ✅ Built | Modal/detail view |
| Edit teacher account | ✅ Built | Edit form |
| Deactivate teacher | ✅ Built | Changes status to deactivated |
| Reactivate teacher | ✅ Built | Changes status back to active |
| Delete teacher | ✅ Built | Removes from list (in-memory only) |

### 3.3 Pending Approvals
| Feature | Status | Details |
|---|---|---|
| List pending requests | ✅ Built | Filters users with "pending" status |
| View applicant details | ✅ Built | Shows name, email, department info |
| Approve | ✅ Built | Changes status to "active", confirmation dialog |
| Reject | ✅ Built | Changes status to "rejected", confirmation dialog |

### 3.4 System Statistics
| Feature | Status | Details |
|---|---|---|
| Analytics cards | ⚠️ Partial | Cards exist, data is mock |
| Charts | ⚠️ Placeholder | Visual elements present but not from real calculations |

### 3.5 Admin Profile
| Feature | Status | Details |
|---|---|---|
| Admin name/email display | ✅ Built | |
| Access level display | ✅ Built | |

### 3.6 Settings
| Feature | Status | Details |
|---|---|---|
| Email notification toggle | ⚠️ Simulated | Toggle exists, doesn't control real behavior |
| Maintenance mode toggle | ⚠️ Simulated | Toggle exists, doesn't control real behavior |

---

## 4. ADMIN DATA CONNECTIONS

### What Admin reads from MockDatabase
- `users` list filtered by `role == teacher` → Teacher Management
- `users` list filtered by `accountStatus == pending` → Pending Approvals
- `users` count by role → Dashboard cards
- `currentUser` → Admin Profile

### What Admin writes to MockDatabase
- Change teacher `accountStatus` (approve / reject / deactivate / reactivate)
- Create new teacher user entry
- Edit teacher profile fields
- Delete teacher entry

### What Admin does NOT access
- `activities`, `quizzesAndExams`, `attendanceRecords`, `assessmentResults`
- `gradingCriteria`, `lessonPlans`, `materials`, `schedules`
- Student/parent academic data

---

## 5. ADMIN CONNECTION TO OTHER ROLES

```
Admin ←→ Teacher:
   Admin approves teacher registration → Teacher can log in
   Admin creates teacher account → Teacher gets active account
   Admin deactivates teacher → Teacher can't log in
   Admin does NOT see teacher's academic data

Admin ←→ Student:
   Admin sees student count only (dashboard card)
   Admin does NOT manage student accounts
   Admin does NOT see student grades/attendance

Admin ←→ Parent:
   Admin sees parent count only (dashboard card)
   Admin does NOT manage parent accounts
```

---

## 6. WHAT ADMIN STILL NEEDS

### 🔴 Critical
| # | Gap | Why It Matters |
|---|---|---|
| 1 | **Route guards** | Currently any user can navigate to `/admin` URL — no server-side or centralized guard checking that the user is actually an admin |
| 2 | **Session validation** | No check that `currentUser` is admin before rendering the dashboard |

### 🟡 Important
| # | Gap | Why It Matters |
|---|---|---|
| 3 | **Activity log / audit trail** | Admin should know who approved/rejected which teacher and when — needed for accountability |
| 4 | **Password reset management** | Admin should be able to force-reset a teacher's password if they're locked out |
| 5 | **Durable persistence** | All admin actions only affect in-memory state — lost on restart |

### 🟢 Nice to Have
| # | Gap |
|---|---|
| 6 | Admin notification when new teacher registers |
| 7 | Bulk teacher import (for schools with many teachers) |
| 8 | System maintenance controls (real, not simulated) |
| 9 | Responsive mobile layout for admin dashboard |

---

## 7. ADMIN DEMO SCRIPT ALIGNMENT

Current demo script (`admin_demo_script.md`) covers:
1. ✅ Login with admin/admin123
2. ✅ Institutional overview (dashboard cards)
3. ✅ Teacher Management (directory, status filter, create, deactivate)
4. ✅ Pending Approvals (review, approve/reject)
5. ✅ System Statistics (analytics cards)
6. ✅ Admin Profile
7. ✅ Settings
8. ✅ Logout

**All demo script items are implemented.** Admin is the most complete role in terms of demo coverage.

---

## 8. KEY SOURCE FILES

| File | Purpose |
|---|---|
| [`admin_dashboard_screen.dart`](file:///c:/Users/Admin/AndroidStudioProjects/class_realm/lib/features/admin/screens/admin_dashboard_screen.dart) (30KB) | Entire admin dashboard — sidebar + all sections |
| [`mock_database.dart`](file:///c:/Users/Admin/AndroidStudioProjects/class_realm/lib/data/mock_database.dart) | Admin reads/writes user data here |
| [`user_model.dart`](file:///c:/Users/Admin/AndroidStudioProjects/class_realm/lib/models/user_model.dart) | UserModel, UserRole, AccountStatus definitions |
| [`login_screen.dart`](file:///c:/Users/Admin/AndroidStudioProjects/class_realm/lib/features/auth/screens/login_screen.dart) | Login flow that routes to admin dashboard |
