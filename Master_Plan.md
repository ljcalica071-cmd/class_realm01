# ClassRealm — Master Plan

> **Document Type:** System Architecture & Planning Document (NO CODE YET)  
> **Project:** ClassRealm — Integrated Senior High School Management System  
> **Date Created:** 2026-09-25  
> **Status:** 🔴 Step 1 Complete · Steps 2–3 Pending  
> **Focus:** Teacher Side First  

---

## TABLE OF CONTENTS

- [Step 1: System Flow & Architecture](#step-1-system-flow--architecture)
  - [1.1 High-Level System Architecture](#11-high-level-system-architecture)
  - [1.2 User Roles & Platform Distribution](#12-user-roles--platform-distribution)
  - [1.3 Teacher Account Creation Flow](#13-teacher-account-creation-flow)
  - [1.4 Admin Approval Flow](#14-admin-approval-flow)
  - [1.5 First-Time Login & Password Change](#15-first-time-login--password-change)
  - [1.6 Academic Setup Wizard (Post-Login Onboarding)](#16-academic-setup-wizard-post-login-onboarding)
  - [1.7 Tutorial Mode (Coach Marks)](#17-tutorial-mode-coach-marks)
  - [1.8 Teacher Self-Management: Subject & Section Lifecycle](#18-teacher-self-management-subject--section-lifecycle)
  - [1.9 Student Onboarding by Teacher](#19-student-onboarding-by-teacher)
  - [1.10 Complete Teacher Journey (Step-by-Step)](#110-complete-teacher-journey-step-by-step)
  - [1.11 Account State Machine](#111-account-state-machine)
  - [1.12 DepEd Curriculum Alignment (SY 2026-2027)](#112-deped-curriculum-alignment-sy-2026-2027)
  - [1.13 Student Account Deduplication Logic (CRITICAL)](#113-student-account-deduplication-logic-critical)
  - [1.14 Client Intelligence Summary](#114-client-intelligence-summary)
  - [1.15 SHS Subject Catalog (Assumed for Prototype)](#115-shs-subject-catalog-assumed-for-prototype)
  - [1.16 Student Status Lifecycle (Drop / Transfer)](#116-student-status-lifecycle-drop--transfer)
- [Step 2: Database Schema Strategy](#step-2-database-schema-strategy) _(Pending)_
- [Step 3: API Security & Rate Limiting](#step-3-api-security--rate-limiting) _(Pending)_

---

# Step 1: System Flow & Architecture

## 1.1 High-Level System Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                        CLASSREALM SYSTEM                             │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   ┌──────────────┐    ┌──────────────┐    ┌──────────────────────┐   │
│   │  WEB APP      │    │  MOBILE APP   │    │  ESP32 + RFID       │   │
│   │  (Flutter Web)│    │  (Flutter)    │    │  (Attendance HW)    │   │
│   │               │    │               │    │                     │   │
│   │  • Admin      │    │  • Student    │    │  • Offline scan     │   │
│   │  • Teacher    │    │  • Parent     │    │  • Local buffer     │   │
│   └──────┬───────┘    └──────┬───────┘    │  • WiFi sync        │   │
│          │                   │            └──────────┬───────────┘   │
│          │                   │                       │               │
│          ▼                   ▼                       ▼               │
│   ┌─────────────────────────────────────────────────────────────┐    │
│   │                    SERVICE / REPOSITORY LAYER               │    │
│   │  AuthRepository │ AcademicRepository │ AttendanceRepository │    │
│   │  AssessmentRepo │ GradebookRepository│ SyncRepository       │    │
│   └──────────────────────────┬──────────────────────────────────┘    │
│                              │                                       │
│            ┌─────────────────┼─────────────────┐                     │
│            ▼                 ▼                 ▼                     │
│   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │
│   │  Firebase     │  │  Supabase    │  │  Local Store │              │
│   │  Auth         │  │  PostgreSQL  │  │  Hive/SQLite │              │
│   │  FCM          │  │  Storage     │  │  Offline     │              │
│   │  Storage      │  │  Realtime    │  │  Queue       │              │
│   └──────────────┘  └──────────────┘  └──────────────┘              │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### Why This Hybrid?

| Service | Role | Justification |
|---|---|---|
| **Firebase Auth** | Authentication & session management | Handles password hashing, email verification, token refresh. Zero custom auth code needed. |
| **Firebase Storage** | File uploads (materials, submissions, profile photos) | Integrated CDN, security rules per user, direct upload from client. |
| **Firebase Cloud Messaging (FCM)** | Push notifications | Real-time alerts for attendance, grades, violations. Cross-platform. |
| **Supabase (PostgreSQL)** | Primary relational database | Structured relational data (grades, enrollments, assessments) needs JOINs, foreign keys, and transactional integrity that Firestore's NoSQL model cannot guarantee. Row Level Security (RLS) policies enforce data isolation per teacher. |
| **Supabase Realtime** | Live subscriptions | Assessment monitoring (anti-cheat live feed), attendance sync status. |
| **Hive / SQLite (Local)** | Offline attendance queue | ESP32 writes attendance locally when offline. Flutter app caches session data. Syncs to Supabase when online. |

> [!IMPORTANT]
> **"No Exposed APIs" Requirement:** Supabase's PostgREST auto-generates REST endpoints, but we lock them down using Row Level Security (RLS) policies. No endpoint is callable without a valid Firebase Auth JWT token verified server-side. Details in Step 3.

---

## 1.2 User Roles & Platform Distribution

| Role | Platform | Registration | Account Creator |
|---|---|---|---|
| **Admin** | Web only | Pre-seeded (the capstone team) | System |
| **Teacher** | Web only | Self-registration on web | Teacher themselves |
| **Student** | Mobile only | Created by Teacher | Teacher |
| **Parent** | Mobile only | Created by Teacher | Teacher |

### Account Credentials Auto-Generation Rules

All accounts use the same formula for auto-generated credentials:

| Field | Format | Example |
|---|---|---|
| **Username** | `{first_name} {last_name}` | `Karen Gonzaga` |
| **Temp Password** | `{last_name_lowercase_no_spaces}{MMDDYYYY_of_birthday}` | `gonzaga03151990` |

> [!NOTE]
> Teachers set their own credentials during registration. The auto-generated formula above applies **only** to Student and Parent accounts created by a Teacher. Teachers still go through a temp-password-change flow on first login — their initial password is the auto-generated one based on the registration form data, which they must change immediately upon first approved login.

---

## 1.3 Teacher Account Creation Flow

### Registration Form (Web Only)

**URL:** `/register` — Only accessible on web. Mobile app must NOT show a registration link.

```
┌─────────────────────────────────────────────────────┐
│           TEACHER REGISTRATION FORM                  │
├─────────────────────────────────────────────────────┤
│                                                      │
│  ┌─── Personal Information ────────────────────────┐ │
│  │                                                  │ │
│  │  First Name *    [________________]              │ │
│  │  Middle Name     [________________]  (optional)  │ │
│  │  Last Name *     [________________]              │ │
│  │  Birthday *      [____/____/______]  (picker)    │ │
│  │  Age             [  auto-calc  ]     (read-only) │ │
│  │  Email *         [________________]              │ │
│  │  Gender *        [▼ dropdown     ]               │ │
│  │                                                  │ │
│  └──────────────────────────────────────────────────┘ │
│                                                      │
│  ┌─── Terms & Conditions ──────────────────────────┐ │
│  │  ☐  I agree to the Terms and Conditions and     │ │
│  │     Privacy Policy of ClassRealm.               │ │
│  │     [View Terms] [View Privacy Policy]          │ │
│  └──────────────────────────────────────────────────┘ │
│                                                      │
│  [ Create Account ]                                  │
│                                                      │
└─────────────────────────────────────────────────────┘
```

### Field Validation Rules

| Field | Type | Rules |
|---|---|---|
| `first_name` | `String` | Required. 2–50 chars. Letters, spaces, hyphens, apostrophes only. Trimmed. No leading/trailing spaces. |
| `middle_name` | `String?` | Optional. Same char rules as first_name. Can be blank. |
| `last_name` | `String` | Required. 2–50 chars. Same char rules. |
| `birthday` | `DateTime` | Required. Must be a valid past date. **Age must be ≥ 21** (minimum teaching age). **Year must be ≥ 1960** (blocks implausible birthdates). Age is auto-calculated from birthday. |
| `age` | `int` | Read-only. Auto-calculated: `today.year - birthday.year` adjusted for whether birthday has occurred this year. |
| `email` | `String` | Required. Valid email format (`RegExp`). Must be unique in the system. Will receive confirmation and approval notifications. |
| `gender` | `Enum` | Required. Options: `Male`, `Female`. Dropdown. |
| `terms_accepted` | `bool` | Required. Must be `true` to submit. Timestamp recorded. |

### What Happens After Submission

```
Teacher clicks "Create Account"
│
├── Client-side validation passes? 
│   ├── NO → Show inline field errors, red borders, error messages
│   └── YES ↓
│
├── Check email uniqueness (query Supabase)
│   ├── EMAIL EXISTS → Show error: "This email is already registered."
│   └── UNIQUE ↓
│
├── Create Firebase Auth account (email + auto-generated temp password)
│   └── Temp password = {lastname_lower}{MMDDYYYY_birthday}
│
├── Insert teacher record into Supabase `users` table
│   ├── account_status = 'pending'
│   ├── is_first_login = true
│   ├── registration_date = now()
│   └── terms_accepted_at = now()
│
├── Send email to teacher:
│   Subject: "ClassRealm — Account Created Successfully"
│   Body: "Your account has been created. Please wait for the 
│          administrator to review and approve your registration.
│          You will receive an email notification once approved."
│
├── Navigate to Pending Account Screen
│   └── Message: "Your account is pending approval. 
│                 You'll be notified via email when approved."
│
└── Send notification to Admin dashboard
    └── "New teacher registration: {full_name} — Pending Review"
```

> [!WARNING]
> **Security Note:** The auto-generated temp password is deterministic (lastname + birthday). This is acceptable ONLY because the teacher is forced to change it on first login. The temp password is never shown on screen — it exists only to create the Firebase Auth entry. The teacher uses it to log in the first time, then immediately changes it.

---

## 1.4 Admin Approval Flow

### What Admin Sees

When a teacher registers, their record appears in the Admin's **Pending Approvals** tab.

```
┌──────────────────────────────────────────────────────────────────┐
│  ⏳ PENDING TEACHER APPROVALS                         [3 pending]│
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  Karen P. Gonzaga                                          │  │
│  │  Email: karen.gonzaga@email.com                            │  │
│  │  Gender: Female  │  Age: 36  │  Birthday: Mar 15, 1990    │  │
│  │  Registered: Sep 25, 2026 at 10:30 AM                     │  │
│  │                                                            │  │
│  │  [ ✅ Approve ]  [ ❌ Reject ]  [ 👁 View Details ]       │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  Juan D. Santos                                            │  │
│  │  Email: juan.santos@email.com                              │  │
│  │  ...                                                       │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### Approval Decision Flow

```
Admin clicks "Approve" on a pending teacher
│
├── Show confirmation dialog:
│   "Are you sure you want to approve Karen P. Gonzaga's 
│    teacher account? This will grant them full access."
│   [ Cancel ]  [ Confirm Approve ]
│
├── Admin confirms
│   ├── Update Supabase: account_status = 'active'
│   ├── Update: approved_at = now(), approved_by = admin_id
│   │
│   ├── Send email to teacher:
│   │   Subject: "ClassRealm — Account Approved! 🎉"
│   │   Body: "Your teacher account has been approved.
│   │          You can now log in using your email.
│   │          Your temporary password is your last name (lowercase)
│   │          followed by your birthday (MMDDYYYY).
│   │          Example: gonzaga03151990
│   │          You will be asked to change this on first login."
│   │
│   └── Show success toast: "Teacher account approved successfully."
│
Admin clicks "Reject"
│
├── Show confirmation dialog WITH reason field:
│   "Please provide a reason for rejecting this registration."
│   [Reason text field: ____________________________]
│   [ Cancel ]  [ Confirm Reject ]
│
├── Admin confirms
│   ├── Update Supabase: account_status = 'rejected'
│   ├── Update: rejected_at = now(), rejection_reason = text
│   │
│   ├── Send email to teacher:
│   │   Subject: "ClassRealm — Registration Not Approved"
│   │   Body: "We're sorry, your registration has not been approved.
│   │          Reason: {rejection_reason}
│   │          If you believe this is an error, please contact
│   │          the school administrator."
│   │
│   └── Show success toast: "Teacher registration rejected."
```

> [!TIP]
> **Admin also has a "Create Teacher Directly" option:** When Admin creates a teacher account manually (from the Teacher Management tab), the account is set to `active` immediately — no approval needed. The temp password is still auto-generated using the same formula and included in the welcome email.

---

## 1.5 First-Time Login & Password Change

### Flow: Teacher Logs In For The First Time

```
Teacher enters email + temp password on Login Screen
│
├── Firebase Auth validates credentials
│   ├── INVALID → Show error: "Invalid email or password."
│   └── VALID ↓
│
├── Query Supabase for user record
│   ├── account_status == 'pending'  → Navigate to Pending Account Screen
│   ├── account_status == 'rejected' → Show error dialog with rejection reason
│   ├── account_status == 'archived' → Show error: "Account deactivated."
│   └── account_status == 'active' ↓
│
├── Check: is_first_login == true?
│   ├── YES → Navigate to Change Password Screen
│   └── NO  → Check: has_completed_setup == true?
│             ├── YES → Navigate to Teacher Dashboard
│             └── NO  → Navigate to Academic Setup Wizard
```

### Change Password Screen

```
┌─────────────────────────────────────────────────────┐
│           🔐 CHANGE YOUR PASSWORD                    │
├─────────────────────────────────────────────────────┤
│                                                      │
│  Welcome, Karen! For your security, please set a     │
│  new password before continuing.                     │
│                                                      │
│  New Password *          [________________]          │
│  Confirm New Password *  [________________]          │
│                                                      │
│  Password Requirements:                              │
│  ☐ At least 8 characters                            │
│  ☐ At least 1 uppercase letter                      │
│  ☐ At least 1 lowercase letter                      │
│  ☐ At least 1 number                                │
│  ☐ At least 1 special character (!@#$%^&*)          │
│                                                      │
│  [ Set New Password ]                                │
│                                                      │
└─────────────────────────────────────────────────────┘
```

### Password Validation Rules

| Rule | Regex / Logic |
|---|---|
| Min 8 characters | `password.length >= 8` |
| Uppercase letter | `RegExp(r'[A-Z]')` |
| Lowercase letter | `RegExp(r'[a-z]')` |
| Number | `RegExp(r'[0-9]')` |
| Special character | `RegExp(r'[!@#$%^&*(),.?":{}|<>]')` |
| Not same as temp password | `newPassword != tempPassword` |
| Passwords match | `newPassword == confirmPassword` |

### After Password Change

```
Teacher submits valid new password
│
├── Update Firebase Auth password
├── Update Supabase: is_first_login = false
├── Show success message: "Password updated! Let's set up your classes."
│
└── Navigate to Academic Setup Wizard (Step 1.6)
```

---

## 1.6 Academic Setup Wizard (Post-Login Onboarding)

This is the **critical onboarding flow** that every teacher must complete before they can use the dashboard. The wizard is **sequential and mandatory** — no step can be skipped.

### Wizard Overview

```
┌─────────────────────────────────────────────────────────────┐
│  ACADEMIC SETUP WIZARD                                       │
│                                                              │
│  Step 1 ──▶ Step 2 ──▶ Step 3 ──▶ Step 4 ──▶ ✅ Done       │
│  School     Grade &    Section    Schedule                   │
│  Year       Subjects   Setup      Setup                      │
│                                                              │
│  ● ─── ○ ─── ○ ─── ○    (progress indicator)                │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

### STEP 1: School Year Setup

```
┌─────────────────────────────────────────────────────┐
│  📅 STEP 1 OF 4: SCHOOL YEAR                        │
├─────────────────────────────────────────────────────┤
│                                                      │
│  School Year *        [ 2026 ] - [ 2027 ]            │
│                       (two dropdowns, auto-paired)   │
│                                                      │
│  Term Structure       [ 3 Terms (Trimester) ]        │
│                       (read-only, DepEd DO 9 s.2026) │
│                                                      │
│  ┌─── Term Dates ──────────────────────────────────┐ │
│  │                                                  │ │
│  │  Term 1:                                         │ │
│  │    Start Date * [________]  End Date * [________] │ │
│  │                                                  │ │
│  │  Term 2:                                         │ │
│  │    Start Date * [________]  End Date * [________] │ │
│  │                                                  │ │
│  │  Term 3:                                         │ │
│  │    Start Date * [________]  End Date * [________] │ │
│  │                                                  │ │
│  └──────────────────────────────────────────────────┘ │
│                                                      │
│  Total School Days:  [ auto-calculated ]             │
│                                                      │
│                            [ Back ] [ Next: Subjects ]│
└─────────────────────────────────────────────────────┘
```

**Validation Rules (Step 1):**

| Rule | Description |
|---|---|
| School year pair | Second year must be first year + 1. E.g., `2026-2027`. |
| Term dates required | All 6 date fields (3 terms × start/end) are required. |
| Chronological order | Term 1 start < Term 1 end < Term 2 start < Term 2 end < Term 3 start < Term 3 end. |
| No overlaps | Terms cannot overlap. Gap between terms is allowed (semester breaks). |
| Reasonable range | All dates must fall within the school year's calendar year range (August of first year through July of second year, approximately). |
| No duplicate SY | A teacher cannot create two active school year setups with the same year pair. |

---

### STEP 2: Grade Level & Subject Selection

```
┌─────────────────────────────────────────────────────┐
│  📚 STEP 2 OF 4: GRADE LEVEL & SUBJECTS             │
├─────────────────────────────────────────────────────┤
│                                                      │
│  Select Grade Level(s) you teach: *                  │
│  ☐ Grade 11                                         │
│  ☐ Grade 12                                         │
│  (can select both)                                   │
│                                                      │
│  ┌─── IF Grade 11 selected ────────────────────────┐ │
│  │  Grade 11 Subject(s): *                          │ │
│  │  [▼ Select subject(s)  ]                         │ │
│  │  Dropdown shows ONLY Grade 11 subjects from the  │ │
│  │  official DepEd subject catalog.                 │ │
│  │  Selected: ☑ General Mathematics                 │ │
│  │            ☑ Statistics and Probability           │ │
│  └──────────────────────────────────────────────────┘ │
│                                                      │
│  ┌─── IF Grade 12 selected ────────────────────────┐ │
│  │  Grade 12 Subject(s): *                          │ │
│  │  [▼ Select subject(s)  ]                         │ │
│  │  Dropdown shows ONLY Grade 12 subjects.          │ │
│  │  Selected: ☑ Basic Calculus                      │ │
│  └──────────────────────────────────────────────────┘ │
│                                                      │
│  Total Subjects Selected: 3                          │
│                                                      │
│  ℹ️ Daily teaching cap: 6 hours. Your schedule will   │
│     be validated in Step 4.                           │
│                                                      │
│                       [ Back ] [ Next: Sections ]    │
└─────────────────────────────────────────────────────┘
```

**Validation Rules (Step 2):**

| Rule | Description |
|---|---|
| At least 1 grade level | Teacher must select Grade 11, Grade 12, or both. |
| At least 1 subject per selected grade | If Grade 11 is checked, at least 1 Grade 11 subject must be selected. Same for Grade 12. |
| No hard limit on subjects | ~~Max 3 removed per client.~~ No maximum. System instead enforces 6-hour daily teaching cap via schedule validation in Step 4. |
| Subject catalog enforced | Subjects must come from the official DepEd-provided list stored in the system. Grade 11 and Grade 12 have separate, non-overlapping subject pools. |
| No duplicate subjects | A teacher cannot select the same subject twice. |

**Subject Catalog (pre-loaded in system — sourced from DepEd strengthened SHS curriculum):**

The system will store the official subject list as reference data. This includes Core Subjects (e.g., Communications, Filipino History, Basic Math & Science, Computing, Life Skills) and Applied/Specialized subjects by track (Academic / TechPro). The Admin or the system seeds this catalog.

> [!NOTE]
> **Teacher handles different subjects for different grade levels.** A teacher teaching Grade 11 General Mathematics and Grade 12 Basic Calculus will see them as two separate teaching assignments. Each has its own sections, schedule, gradebook, assessments, etc.

---

### STEP 3: Section Setup (Per Subject)

```
┌─────────────────────────────────────────────────────┐
│  🏫 STEP 3 OF 4: SECTION SETUP                      │
├─────────────────────────────────────────────────────┤
│                                                      │
│  Assign sections to each subject you handle.         │
│  Maximum 8 sections per subject.                     │
│                                                      │
│  ┌─── General Mathematics (Grade 11) ──────────────┐ │
│  │                                                  │ │
│  │  Section Name *   [ Section A          ] [+ Add] │ │
│  │                   [ Section B          ] [  ✕  ] │ │
│  │                   [ + Add Section ]              │ │
│  │                                                  │ │
│  │  Sections: 2 / 8                                 │ │
│  └──────────────────────────────────────────────────┘ │
│                                                      │
│  ┌─── Statistics & Probability (Grade 11) ─────────┐ │
│  │                                                  │ │
│  │  Section Name *   [ Section A          ] [+ Add] │ │
│  │                   [ + Add Section ]              │ │
│  │                                                  │ │
│  │  Sections: 1 / 8                                 │ │
│  └──────────────────────────────────────────────────┘ │
│                                                      │
│  ┌─── Basic Calculus (Grade 12) ───────────────────┐ │
│  │                                                  │ │
│  │  Section Name *   [ 12-STEM-A         ] [+ Add] │ │
│  │                   [ 12-STEM-B         ] [  ✕  ] │ │
│  │                   [ + Add Section ]              │ │
│  │                                                  │ │
│  │  Sections: 2 / 8                                 │ │
│  └──────────────────────────────────────────────────┘ │
│                                                      │
│                      [ Back ] [ Next: Schedule ]     │
└─────────────────────────────────────────────────────┘
```

**Validation Rules (Step 3):**

| Rule | Description |
|---|---|
| At least 1 section per subject | Each subject must have at least 1 section. |
| Maximum 8 sections per subject | Cannot add a 9th section to any single subject. |
| Section name required | Each section name is required, 1–50 characters. |
| No duplicate names within a subject | Section names must be unique within the same subject. Two different subjects can have sections with the same name (e.g., both Gen Math and Stats can have "Section A"). |

---

### STEP 4: Schedule Setup

```
┌──────────────────────────────────────────────────────────────┐
│  📅 STEP 4 OF 4: SCHEDULE SETUP                              │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  Set your class schedule for each subject × section.          │
│                                                               │
│  ┌─── General Mathematics — Section A ─────────────────────┐ │
│  │                                                          │ │
│  │  Day *      [▼ Monday  ]                                 │ │
│  │  Start *    [▼ 7:30 AM ]     End *   [▼ 8:30 AM ]       │ │
│  │  Room       [________________]                           │ │
│  │  [ + Add Another Day ]                                   │ │
│  │                                                          │ │
│  │  Current Schedule:                                       │ │
│  │  ┌──────────┬───────────┬───────────┬────────┐          │ │
│  │  │ Day      │ Start     │ End       │ Room   │          │ │
│  │  ├──────────┼───────────┼───────────┼────────┤          │ │
│  │  │ Monday   │ 7:30 AM   │ 8:30 AM   │ Rm 201 │          │ │
│  │  │ Thursday │ 7:30 AM   │ 8:30 AM   │ Rm 201 │          │ │
│  │  └──────────┴───────────┴───────────┴────────┘          │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                               │
│  ┌─── General Mathematics — Section B ─────────────────────┐ │
│  │  ...                                                     │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                               │
│  ⚠️ Conflict detected: Monday 7:30-8:30 AM is already       │
│     assigned to Gen Math Section A.                          │
│                                                               │
│                       [ Back ] [ Complete Setup ✅ ]          │
└──────────────────────────────────────────────────────────────┘
```

**Validation Rules (Step 4):**

| Rule | Description |
|---|---|
| At least 1 schedule entry per section | Every subject-section combination needs at least one day/time. |
| No time conflicts | The same teacher cannot be in two places at the same time. If a slot overlaps with an existing schedule, show an inline conflict error and block submission. |
| Valid time range | Start time must be before end time. Duration must be ≥ 30 minutes and ≤ 4 hours. |
| Day selection | Must be a school day (Monday–Friday). |
| Room optional | Room name is optional (some schools may not assign rooms). |

### After Completing Setup

```
Teacher clicks "Complete Setup"
│
├── Validate all steps (re-check all rules)
│   ├── ANY INVALID → Highlight the step with errors, navigate back
│   └── ALL VALID ↓
│
├── Save to Supabase:
│   ├── Create `school_year` record
│   ├── Create `teaching_assignment` records (1 per subject)
│   ├── Create `section` records (per subject)
│   ├── Create `schedule` records (per section × day)
│   └── Update user: has_completed_setup = true

│
├── Show success celebration screen:
│   "🎉 You're all set! Your academic setup is complete.
│    Let's get started with ClassRealm!"
│   [ Go to Dashboard ]
│
└── Navigate to Teacher Dashboard
    └── Tutorial Mode activates (Step 1.7)
```

---

## 1.7 Tutorial Mode (Coach Marks)

Tutorial Mode uses **step-by-step overlay tooltips** (coach marks / spotlight bubbles) that highlight each UI element one at a time on the Teacher Dashboard.

### When It Activates

- **Automatically** on the teacher's **very first visit** to the dashboard (after completing the Academic Setup Wizard).
- **Manually** re-triggered from Settings → "Restart Tutorial".
- State is tracked per-user: `has_seen_tutorial = true/false` in Supabase.

### Coach Mark Sequence (Teacher Dashboard)

| Step | Target Element | Tooltip Message |
|---|---|---|
| 1 | Sidebar | "This is your navigation sidebar. Use it to switch between different sections of your dashboard." |
| 2 | Dashboard Overview | "Your dashboard shows a quick summary of your classes — total students, today's attendance, and upcoming tasks." |
| 3 | Classroom Setup tab | "Start here to review your academic setup — school year, subjects, and sections. You can add or edit sections later." |
| 4 | Student Management tab | "Manage your students here. Add them one by one or import from an Excel file." |
| 5 | Assessments tab | "Create Written Works, Performance Tasks, and Examinations for your students." |
| 6 | Attendance tab | "Record daily attendance manually or view RFID scan logs from the ESP32 device." |
| 7 | Gradebook tab | "View and manage your grades. The system auto-calculates based on DepEd grading weights." |
| 8 | Lesson Planning tab | "Create and manage your lesson plans. You can also use the AI generator for drafts." |
| 9 | Schedule tab | "View your weekly schedule. You can add, edit, or remove schedule entries." |
| 10 | Profile & Settings | "Update your profile, change your password, and customize your preferences here." |

### Coach Mark UI Behavior

```
┌──────────────────────────────────────────────────────────────┐
│                                                               │
│  ╔═══════════════════════════════════════════╗                │
│  ║  ┌────────────────────────────────────┐   ║                │
│  ║  │  💡 Step 4 of 10                   │   ║                │
│  ║  │                                    │   ║                │
│  ║  │  Manage your students here. Add    │   ║                │
│  ║  │  them one by one or import from    │   ║                │
│  ║  │  an Excel file.                    │   ║                │
│  ║  │                                    │   ║                │
│  ║  │  [ ← Previous ] [ Next → ]        │   ║                │
│  ║  │  [ Skip Tutorial ]                 │   ║                │
│  ║  └────────────────────────────────────┘   ║                │
│  ╚══════════ (spotlight on target) ══════════╝                │
│                                                               │
│  (rest of screen dimmed with semi-transparent overlay)        │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

**Behavior:**
- Background is dimmed with a semi-transparent dark overlay
- Target element is "spotlighted" (cut out from the overlay)
- Tooltip arrow points to the spotlighted element
- "Next" advances to next step
- "Previous" goes back one step
- "Skip Tutorial" dismisses the tutorial entirely and sets `has_seen_tutorial = true`
- Completing the last step shows "🎉 Tutorial Complete! You're ready to use ClassRealm." and sets the flag

---

## 1.8 Teacher Self-Management: Subject & Section Lifecycle

After the initial setup wizard, teachers can **add, edit, and delete** their subjects and sections from the **Classroom Setup** tab on the dashboard.

### What Can Be Edited

| Entity | Add | Edit | Delete (Soft) | Constraints |
|---|---|---|---|---|
| **Subject Handle** | ✅ Yes | ✅ Edit name selection | ✅ Archive | No hard limit on subjects (6-hour daily teaching cap enforced via schedule). Cannot delete if it's the only active subject. |
| **Section** | ✅ Yes | ✅ Edit section name | ✅ Archive | Max 8 sections per subject. Cannot delete if it's the only active section for that subject. |
| **Schedule** | ✅ Yes | ✅ Edit day/time/room | ✅ Hard delete | No time conflicts allowed. Warns if daily total exceeds 6 hours. |

### Subject Add Flow (Post-Setup)

```
Teacher clicks "Add Subject" in Classroom Setup
│
├── No hard limit on subjects — teacher can add freely
│   (6-hour daily teaching cap is enforced during schedule setup)
│
├── Show Add Subject dialog:
│   ├── Grade Level: [▼ Grade 11 / Grade 12]
│   ├── Subject: [▼ dropdown of available subjects for selected grade]
│   │   (excludes subjects already assigned to this teacher)
│   └── [ Cancel ] [ Add Subject ]
│
├── Validate & create teaching_assignment record
├── Prompt: "Would you like to add sections for this subject now?"
│   ├── YES → Open Section Setup for this subject
│   └── NO  → Return to Classroom Setup (subject appears with 0 sections warning)
```

### Section Delete (Archive) Flow

```
Teacher clicks "Delete" on Section B of General Mathematics
│
├── Show confirmation dialog:
│   ┌──────────────────────────────────────────────┐
│   │  ⚠️ Archive Section?                         │
│   │                                               │
│   │  You are about to archive "Section B" from    │
│   │  General Mathematics.                         │
│   │                                               │
│   │  This will:                                   │
│   │  • Hide this section from your active view    │
│   │  • Preserve all student data, grades, and     │
│   │    attendance records                         │
│   │  • You can restore this section later from    │
│   │    Settings → Archived Items                  │
│   │                                               │
│   │  ⚠️ Students in this section will no longer   │
│   │     appear in your active class lists.        │
│   │                                               │
│   │  Type "ARCHIVE" to confirm:                   │
│   │  [_________________]                          │
│   │                                               │
│   │  [ Cancel ]  [ Archive Section ]              │
│   └──────────────────────────────────────────────┘
│
├── Teacher types "ARCHIVE" and confirms
│   ├── Supabase: Set section.is_archived = true, archived_at = now()
│   ├── All related data (students, grades, attendance, assessments) 
│   │   remains in the database — filtered out of active views by
│   │   is_archived flag
│   └── Schedule entries for this section are also soft-archived
│
└── Section disappears from active view
    └── Recoverable from Settings → Archived Items → Restore
```

### Subject Delete (Archive) Flow

```
Teacher clicks "Remove Subject" on Statistics & Probability
│
├── Pre-check: Is this the teacher's ONLY active subject?
│   ├── YES → Block: "You must have at least 1 active subject."
│   └── NO ↓
│
├── Show confirmation dialog (similar to section, but stronger warning):
│   "Archiving this subject will also archive ALL sections, students,
│    grades, attendance, and assessments under it."
│
│   Type "ARCHIVE SUBJECT" to confirm.
│
├── Cascade archive:
│   ├── teaching_assignment.is_archived = true
│   ├── All sections under this subject → is_archived = true
│   └── All schedules for this subject → is_archived = true
│
└── Subject and all its sections disappear from active views
```

### Restore Flow

```
Settings → Archived Items
│
├── Shows list of archived subjects and sections with archive date
│   ├── [ Restore Subject: Statistics & Probability (archived Sep 28) ]
│   └── [ Restore Section: Gen Math Section C (archived Sep 30) ]
│
├── Teacher clicks "Restore"
│   ├── Check: Would restoring exceed limits? (8 sections per subject)
│   │   ├── YES → Block: "Cannot restore. Maximum sections per subject reached."
│   │   └── NO ↓
│   ├── Set is_archived = false
│   └── Item reappears in active views with all data intact
```

---

## 1.9 Student Onboarding by Teacher

### Two Methods for Adding Students

#### Method 1: Individual Add

```
Teacher clicks "Add Student" in Student Management
│
├── Show Add Student Dialog:
│   ┌──────────────────────────────────────────────┐
│   │  ADD NEW STUDENT                              │
│   │                                               │
│   │  First Name *     [________________]          │
│   │  Middle Name      [________________] (opt.)   │
│   │  Last Name *      [________________]          │
│   │  LRN *            [____________] (12 digits)  │
│   │  Birthday *       [____/____/______]          │
│   │  Age              [ auto-calculated ]         │
│   │  Gender *         [▼ dropdown       ]         │
│   │  Contact #        [________________] (opt.)   │
│   │                                               │
│   │  Assign to: *                                 │
│   │  Subject: [▼ General Mathematics    ]         │
│   │  Section: [▼ Section A              ]         │
│   │                                               │
│   │  ── Generated Credentials (preview) ──        │
│   │  Username: alyssa reyes                       │
│   │  Temp Password: reyes03202010                 │
│   │                                               │
│   │  [ Cancel ]  [ Create Student Account ]       │
│   └──────────────────────────────────────────────┘
```

**Validation Rules:**

| Field | Rules |
|---|---|
| First Name | Required. 2–50 chars. Letters, spaces, hyphens only. |
| Middle Name | Optional. Same rules if provided. |
| Last Name | Required. 2–50 chars. |
| LRN | Required. Exactly 12 digits. `RegExp(r'^\d{12}$')`. Must be unique in the system. |
| Birthday | Required. Valid past date. **Age must be ≥ 10 and ≤ 25** for Senior High School (blocks implausible ages). Year must be ≥ 2000. |
| Gender | Required. Male / Female. |
| Subject | Required. From teacher's active subjects. |
| Section | Required. From sections under the selected subject. |

#### Method 2: Bulk Import via Excel

```
Teacher clicks "Import Students" in Student Management
│
├── Show Import Dialog:
│   ┌──────────────────────────────────────────────┐
│   │  IMPORT STUDENTS FROM EXCEL                   │
│   │                                               │
│   │  📥 Download Template (.xlsx)                 │
│   │     [Download Template File]                  │
│   │                                               │
│   │  Template Columns:                            │
│   │  first_name | middle_name | last_name | LRN   │
│   │  birthday | gender | contact_number           │
│   │                                               │
│   │  📤 Upload Filled Template:                   │
│   │  [Choose File...] or drag & drop              │
│   │                                               │
│   │  Assign ALL imported students to:             │
│   │  Subject: [▼ General Mathematics    ]         │
│   │  Section: [▼ Section A              ]         │
│   │                                               │
│   │  [ Cancel ]  [ Upload & Validate ]            │
│   └──────────────────────────────────────────────┘
│
├── System validates each row:
│   ├── Check required fields present
│   ├── Validate LRN format and uniqueness
│   ├── Validate birthday/age range
│   ├── Flag duplicates (by LRN or name match)
│   └── Show validation summary:
│       "25 valid, 2 errors (Row 8: invalid LRN, Row 14: duplicate LRN)"
│
├── Teacher reviews and fixes errors or excludes bad rows
│   [ Import 25 Valid Students ]
│
└── System creates accounts with auto-generated credentials
    └── Credentials can be exported as PDF/Excel for distribution
```

---

## 1.10 Complete Teacher Journey (Step-by-Step)

This is the full end-to-end journey a new teacher goes through, serving as the basis for the Tutorial Mode script:

```
TEACHER JOURNEY — COMPLETE FLOW
════════════════════════════════

1. CREATE ACCOUNT
   └── Teacher visits ClassRealm web → clicks "Register" 
       → fills form (first_name, middle_name, last_name, birthday, email, gender)
       → accepts Terms & Conditions
       → submits → sees "Account Created — Awaiting Approval"
       → receives confirmation email

2. WAIT FOR APPROVAL
   └── Admin reviews registration → approves or rejects
       → Teacher receives approval email with temp password instructions

3. FIRST LOGIN
   └── Teacher logs in with email + temp password
       → forced to Change Password screen
       → sets new secure password
       → proceeds to Academic Setup Wizard

4. ACADEMIC SETUP WIZARD (mandatory, one-time)
   ├── Step 1: Set School Year (SY 2026-2027) + 3 Term dates
   ├── Step 2: Select Grade Level(s) + Subject(s) (max 3 total)
   ├── Step 3: Create Sections per subject (max 8 per subject)
   └── Step 4: Set Schedule per section (day/time/room)
       → completes → "🎉 Setup Complete!" → goes to Dashboard

5. TUTORIAL MODE (first dashboard visit)
   └── Coach marks highlight each sidebar item one by one
       → teacher can navigate along or skip

6. ADD STUDENTS (teacher's first real task)
   ├── Option A: Add individually via form (LRN, name, birthday, etc.)
   └── Option B: Bulk import via Excel template
       → system generates username + temp password for each student
       → teacher can export credentials for distribution

7. DAILY OPERATIONS (ongoing)
   ├── Record attendance (manual or RFID)
   ├── Create assessments (WW, PT, EX → Quiz, ST1, ST2, TE)
   ├── Grade submissions
   ├── View gradebook (auto-calculated)
   ├── Create lesson plans
   ├── Upload learning materials
   └── Monitor exam sessions (anti-cheating)

8. ONGOING MANAGEMENT
   ├── Add/edit/archive subjects (max 3)
   ├── Add/edit/archive sections (max 8 per subject)
   ├── Edit schedule (no conflicts)
   ├── View analytics and reports
   └── Manage profile and settings
```

---

## 1.11 Account State Machine

Every user account (Admin, Teacher, Student, Parent) follows this state machine:

```
                    ┌─────────────┐
                    │   CREATED   │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
              ▼            ▼            │
     ┌──────────────┐ ┌──────────┐     │
     │   PENDING    │ │  ACTIVE  │     │
     │ (awaiting    │ │(directly │     │  (Admin-created accounts
     │  approval)   │ │ by Admin)│     │   skip 'pending')
     └──────┬───────┘ └────┬─────┘     │
            │              │           │
     ┌──────┼──────┐       │           │
     │             │       │           │
     ▼             ▼       ▼           │
┌──────────┐ ┌──────────────────┐      │
│ REJECTED │ │ PENDING FIRST    │      │
│          │ │ LOGIN            │◄─────┘
│          │ │ (must change pwd)│   (Student/Parent
└──────────┘ └────────┬─────────┘   created by Teacher)
                      │
                      ▼
               ┌──────────┐
               │  ACTIVE  │
               └────┬─────┘
                    │
            ┌───────┼───────┐
            ▼               ▼
   ┌──────────────┐  ┌──────────┐
   │ DEACTIVATED  │  │ ARCHIVED │
   │ (by Admin or │  │ (soft    │
   │  Teacher)    │  │  delete) │
   └──────┬───────┘  └──────────┘
          │                ▲
          │ (reactivate)   │ (restore)
          └────────────────┘
```

### State Definitions

| State | Who Sets It | Can Login? | Behavior |
|---|---|---|---|
| `pending` | System (on teacher self-registration) | ❌ No | Shows "Pending Approval" screen |
| `rejected` | Admin (reject registration) | ❌ No | Shows rejection reason dialog |
| `pending_first_login` | System (on teacher approval or student/parent creation) | ✅ Yes | Forces password change screen |
| `active` | System (after password change) or Admin (direct create) | ✅ Yes | Normal access |
| `deactivated` | Admin or Teacher | ❌ No | Shows "Account Deactivated" error |
| `archived` | Admin or Teacher (soft delete) | ❌ No | Hidden from all views. Data preserved. |

---

## 1.12 DepEd Curriculum Alignment (SY 2026-2027)

### Key Facts (Researched from DepEd Orders)

| Item | Value | Source |
|---|---|---|
| **Calendar Structure** | 3 Terms (Trimester) | DepEd Order No. 9, s. 2026 |
| **Previous Structure** | 4 Quarters (being phased out) | DepEd Order No. 8, s. 2015 |
| **System Support** | 3 Terms ONLY (new format) | Per user decision |
| **Grading Components** | Written Works (WW), Performance Tasks (PT), Examinations (EX) | DO 015, s. 2026 |
| **Component Weights** | Varies by subject area (WW: 20-40%, PT: 50-60%, EX: 20-30%) | Per subject type |
| **Default Weights** | WW: 20%, PT: 50%, EX: 30% | Standard academic subjects |
| **Examination Sub-types** | Summative Test 1 (ST1), Summative Test 2 (ST2), Term Examination (TE) | DepEd assessment framework |
| **Grade Computation** | Raw → Percentage → Weighted → Initial Grade → Transmuted Grade | DepEd transmutation table |
| **Upcoming Change** | Zero-Based Grading (no transmutation) planned for SY 2027-2028 | DepEd announcement |
| **SHS Curriculum** | "Strengthened SHS" — streamlined to 5-7 core subjects + electives | DepEd SHS reform |
| **Tracks** | Academic Track, Technical-Professional (TechPro) Track | DO structure |

### How ClassRealm Aligns

| DepEd Requirement | ClassRealm Implementation |
|---|---|
| 3-term calendar | School Year Setup enforces 3 terms with start/end dates per term |
| Subject-specific weights | Teacher configures WW/PT/EX weights per subject (must sum to 100%) |
| Transmutation table | Built into the grading engine (Step 2 will define schema) |
| Assessment categories | Explicit `AssessmentCategory` enum: `writtenWork`, `performanceTask`, `summativeTest1`, `summativeTest2`, `termExamination` |
| Term-based final grade | Final Grade = average of 3 term grades |

---

## 1.13 Student Account Deduplication Logic (CRITICAL)

> [!IMPORTANT]
> **THE PROBLEM:** Multiple teachers handle the same students (e.g., a Grade 11 student takes General Mathematics from Teacher A AND Effective Communication from Teacher B). Each teacher independently adds students to their subject. If Teacher A already created Juan Santos's account, what happens when Teacher B tries to add the same student?

### Core Design Principle: SEPARATE Account Creation from Enrollment

```
┌──────────────────────────────────────────────────────────────────┐
│                   ACCOUNT vs ENROLLMENT                          │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  STUDENT ACCOUNT (created ONCE)                                  │
│  ├── id (UUID)                                                   │
│  ├── LRN (unique 12-digit identifier — THE dedup key)           │
│  ├── first_name, middle_name, last_name                         │
│  ├── birthday, gender, email                                    │
│  ├── username (auto-generated)                                  │
│  ├── password (auto-generated, changed on first login)          │
│  └── account_status                                             │
│                                                                  │
│  ENROLLMENT (created PER subject — can have MANY)                │
│  ├── id (UUID)                                                   │
│  ├── student_id → references student account                    │
│  ├── teaching_assignment_id → references teacher+subject+SY     │
│  ├── section_id → which section of that subject                 │
│  ├── enrolled_at                                                │
│  ├── status (active / dropped / transferred / completed)        │
│  └── enrolled_by (teacher_id who enrolled this student)         │
│                                                                  │
│  ONE student → MANY enrollments (one per subject they take)      │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### The Deduplication Flow

```
Teacher B clicks "Add Student" → enters LRN: 123456789012
│
├── System queries Supabase: SELECT * FROM students WHERE lrn = '123456789012'
│
├── CASE 1: LRN NOT FOUND (new student)
│   └── Normal flow:
│       ├── Teacher fills in all fields (name, birthday, etc.)
│       ├── System creates student ACCOUNT
│       ├── System creates ENROLLMENT record for Teacher B's subject
│       ├── Auto-generate username + temp password
│       └── Student can now log in
│
├── CASE 2: LRN FOUND (student already exists in the system)
│   └── Dedup flow:
│       ├── System shows confirmation dialog:
│       │   ┌────────────────────────────────────────────────────┐
│       │   │  ℹ️ STUDENT ALREADY REGISTERED                     │
│       │   │                                                    │
│       │   │  This student already has an account in ClassRealm:│
│       │   │                                                    │
│       │   │  Name: Juan D. Santos                              │
│       │   │  LRN:  123456789012                                │
│       │   │  Grade: 11                                         │
│       │   │                                                    │
│       │   │  Currently enrolled in:                            │
│       │   │  • General Mathematics (Teacher A — Section A)     │
│       │   │                                                    │
│       │   │  Would you like to enroll this student in your     │
│       │   │  subject?                                          │
│       │   │                                                    │
│       │   │  Your subject: Effective Communication             │
│       │   │  Section: [▼ Section A  ]                          │
│       │   │                                                    │
│       │   │  [ Cancel ]  [ Enroll Student ]                    │
│       │   └────────────────────────────────────────────────────┘
│       │
│       ├── Teacher B confirms → System creates ONLY an enrollment record
│       │   (NO new account, NO new password, NO duplicate)
│       │
│       └── Student now sees BOTH subjects when they log in:
│           • General Mathematics (Teacher A)
│           • Effective Communication (Teacher B)
│
└── CASE 3: LRN FOUND but student info doesn't match
    └── Edge case: Teacher entered a valid LRN but the name/birthday
        doesn't match the existing record.
        ├── System shows warning:
        │   "The LRN matches an existing student, but the name
        │    doesn't match. Please verify the LRN is correct."
        └── Block enrollment until teacher confirms or corrects the LRN.
```

### What the Student Sees (Multi-Subject View)

```
┌──────────────────────────────────────────────────────────────┐
│  🏠 STUDENT HOME — Juan D. Santos (Grade 11)                 │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  📚 My Subjects (Active Enrollments)                         │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐   │
│  │  📐 General Mathematics                                │   │
│  │  Teacher: Karen P. Gonzaga  │  Section: Section A      │   │
│  │  Term 1  │  Next class: Mon 7:30 AM                    │   │
│  │  [ View Assessments ] [ View Grades ] [ View Materials ]│   │
│  └────────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐   │
│  │  💬 Effective Communication                            │   │
│  │  Teacher: Maria L. Reyes  │  Section: Section A        │   │
│  │  Term 1  │  Next class: Tue 9:00 AM                    │   │
│  │  [ View Assessments ] [ View Grades ] [ View Materials ]│   │
│  └────────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐   │
│  │  🔬 General Science                                    │   │
│  │  Teacher: Jose R. Cruz  │  Section: Section B          │   │
│  │  Term 1  │  Next class: Wed 1:00 PM                    │   │
│  │  [ View Assessments ] [ View Grades ] [ View Materials ]│   │
│  └────────────────────────────────────────────────────────┘   │
│                                                               │
│  📦 Past / Completed Subjects [Toggle]                       │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

### Bulk Import Deduplication

When a teacher imports students via Excel, the same LRN check applies per row:

```
Teacher B uploads Excel with 30 students
│
├── System processes each row:
│   ├── Row 1: LRN 123456789012 → FOUND → auto-flag as "Enroll Only"
│   ├── Row 2: LRN 234567890123 → FOUND → auto-flag as "Enroll Only"
│   ├── Row 3: LRN 345678901234 → NOT FOUND → flag as "New Account"
│   └── ... (continues for all rows)
│
├── Show validation summary:
│   ┌────────────────────────────────────────────────────────┐
│   │  IMPORT VALIDATION RESULTS                             │
│   │                                                        │
│   │  ✅ 22 New students (accounts will be created)         │
│   │  🔄 6 Existing students (will be enrolled only)        │
│   │  ❌ 2 Errors (Row 8: invalid LRN, Row 25: duplicate)  │
│   │                                                        │
│   │  [ View Details ] [ Import 28 Valid Students ]         │
│   └────────────────────────────────────────────────────────┘
│
└── Teacher confirms → 22 new accounts created + 6 enrollment-only records
```

### Data Isolation Per Teacher

Even though the student ACCOUNT is shared, each teacher's VIEW is isolated:

| Data | Scoped To | Teacher A Sees | Teacher B Sees |
|---|---|---|---|
| Student profile (name, LRN) | Global (shared) | ✅ Same data | ✅ Same data |
| Assessments | Teaching Assignment | Only Math assessments | Only CommArts assessments |
| Grades | Teaching Assignment | Only Math grades | Only CommArts grades |
| Attendance | Teaching Assignment + Section | Only Math attendance | Only CommArts attendance |
| Submissions | Teaching Assignment | Only Math submissions | Only CommArts submissions |
| Gradebook | Teaching Assignment | Math gradebook only | CommArts gradebook only |

> [!CAUTION]
> **Teacher A CANNOT see Teacher B's assessments, grades, or gradebook for the same student.** Each teacher's data is scoped by their `teaching_assignment_id`. This is enforced at the database level via Supabase Row Level Security (RLS).

---

## 1.14 Client Intelligence Summary

Data gathered from client interview (Ms. [Client Name], School Representative):

### School Demographics

| Item | Value | System Impact |
|---|---|---|
| Total Teachers | **9** | System must handle multi-teacher data isolation |
| Teachers handling both G11 & G12 | **Yes, some do** | Teacher setup must support selecting both grade levels |
| Grade 11 students (total) | **~60** | Enrollment planning |
| Grade 12 students (total) | **~70** | Enrollment planning |
| Total students | **~130** | Scale reference for testing & mock data |

### Academic Rules (From Client)

| Rule | Client's Answer | System Implementation |
|---|---|---|
| Max subjects per teacher | **No hard limit** — max 6 hours of teaching per day | ~~Max 3 subjects~~ → Removed. Enforce 6-hour daily teaching cap via schedule validation. System warns when a teacher's total scheduled hours exceed 6/day. |
| Section shifting / transfer mid-year | **NOT ALLOWED** — students stay in their section | No section transfer feature needed for students. Enrollment is permanent per school year. |
| Teacher with 2+ subjects | **Yes** (e.g., Statistics AND General Mathematics) | Already supported in our multi-subject design. |
| Who moves between rooms? | **Teachers move**, not students | Room assignment is per schedule entry, not per section. Teacher's schedule shows different rooms at different times. |
| Grading weights (WW/PT/EX) | **Teacher self-configures** per subject | No global weight enforcement. Teacher sets percentages in Gradebook Setup. Must sum to 100%. |
| Student dropout handling | Letter → Home visitation → Agreement → then status change | System has `dropped` status. Teacher marks student as dropped after completing the offline process. |
| Transfer student (incoming) | Accepted if completed the term + has grades from previous school | Teacher manually enters previous grades when enrolling a transfer student. Special `is_transferee` flag. |

> [!WARNING]
> **DESIGN CHANGE FROM STEP 1:** The original "max 3 subjects" rule has been replaced by "max 6 hours of teaching per day" based on client feedback. The system will:
> 1. Allow unlimited subjects per teacher.
> 2. Track total scheduled hours per day.
> 3. Show a warning (NOT a hard block) when daily hours exceed 6.
> 4. This is a soft limit because the school might have exceptions.

---

## 1.15 SHS Subject Catalog (Assumed for Prototype)

Since the client has not yet provided the specific list of subjects offered at their school, we will use the **official DepEd Strengthened SHS Curriculum** as the base catalog. The Admin can edit this list later.

### Core Subjects (All Students — Grade 11 Only)

Per DepEd's Strengthened SHS Curriculum, all students take 5 core subjects:

| # | Subject Name | Grade Level |
|---|---|---|
| 1 | Effective Communication / Mabisang Komunikasyon | Grade 11 |
| 2 | Life and Career Skills | Grade 11 |
| 3 | General Mathematics | Grade 11 |
| 4 | General Science | Grade 11 |
| 5 | Pag-aaral ng Kasaysayan at Lipunang Pilipino | Grade 11 |

### Elective Subjects (Assumed — Organized by Cluster)

These are representative subjects per cluster. The actual list depends on what the school offers.

**STEM Cluster:**

| # | Subject Name | Grade Level(s) |
|---|---|---|
| 6 | Pre-Calculus | Grade 11 |
| 7 | Basic Calculus | Grade 12 |
| 8 | General Biology 1 | Grade 11 |
| 9 | General Biology 2 | Grade 12 |
| 10 | General Physics 1 | Grade 12 |
| 11 | General Chemistry 1 | Grade 11 |
| 12 | General Chemistry 2 | Grade 12 |
| 13 | Statistics and Probability | Grade 11 |

**Business & Entrepreneurship Cluster:**

| # | Subject Name | Grade Level(s) |
|---|---|---|
| 14 | Applied Economics | Grade 11 |
| 15 | Business Ethics and Social Responsibility | Grade 11 |
| 16 | Fundamentals of Accountancy, Business and Management 1 | Grade 11 |
| 17 | Fundamentals of Accountancy, Business and Management 2 | Grade 12 |
| 18 | Business Math | Grade 11 |
| 19 | Business Finance | Grade 12 |
| 20 | Organization and Management | Grade 11 |

**Arts, Social Sciences & Humanities Cluster:**

| # | Subject Name | Grade Level(s) |
|---|---|---|
| 21 | Creative Writing | Grade 12 |
| 22 | Introduction to World Religions and Belief Systems | Grade 11 |
| 23 | Philippine Politics and Governance | Grade 12 |
| 24 | Disciplines and Ideas in the Social Sciences | Grade 12 |
| 25 | Community Engagement, Solidarity, and Citizenship | Grade 12 |
| 26 | Creative Nonfiction | Grade 12 |

**ICT Cluster:**

| # | Subject Name | Grade Level(s) |
|---|---|---|
| 27 | Empowerment Technologies | Grade 11 |
| 28 | Computer Programming 1 | Grade 11 |
| 29 | Computer Programming 2 | Grade 12 |
| 30 | Animation | Grade 12 |

**Sports, Health & Wellness:**

| # | Subject Name | Grade Level(s) |
|---|---|---|
| 31 | Physical Education and Health | Grade 11 |
| 32 | Exercise Science | Grade 12 |

**Cross-Grade Subjects:**

| # | Subject Name | Grade Level(s) |
|---|---|---|
| 33 | Research in Daily Life 1 | Grade 11 |
| 34 | Research in Daily Life 2 / Practical Research | Grade 12 |
| 35 | Work Immersion / Research | Grade 12 |
| 36 | Filipino (Panitikan) | Grade 12 |
| 37 | English for Academic and Professional Purposes | Grade 12 |
| 38 | Understanding Culture, Society, and Politics | Grade 12 |
| 39 | Media and Information Literacy | Grade 11 |
| 40 | Personal Development | Grade 11 |

> [!NOTE]
> **This is a placeholder catalog.** When the client provides their actual subject list, we will update this. The system stores subjects as reference data in a `subject_catalog` table that Admin can manage. Teachers select from this catalog during Academic Setup.

### How the Catalog Works in the System

```
subject_catalog table (seeded by system, editable by Admin)
├── id: UUID
├── name: "General Mathematics"
├── grade_level: 11
├── cluster: "Core" | "STEM" | "Business" | "ASSH" | "ICT" | ...
├── track: "Academic" | "TechPro" | "Both"
├── is_active: true (Admin can deactivate subjects not offered)
└── created_at / updated_at

When teacher selects subjects in Academic Setup:
├── Filter by grade_level (11 or 12)
├── Filter by is_active = true
├── Exclude subjects already assigned to this teacher
└── Show grouped by cluster for easy browsing
```

---

## 1.16 Student Status Lifecycle (Drop / Transfer)

### Student Enrollment Statuses

| Status | Meaning | Triggers |
|---|---|---|
| `active` | Currently enrolled and participating | Default on enrollment |
| `dropped` | Student has dropped out after formal process | Teacher marks after completing letter → visitation → agreement process |
| `transferred_out` | Student transferred to another school | Teacher marks when student leaves |
| `transferred_in` | Student is a transferee from another school | Teacher marks during enrollment, enters previous grades |
| `completed` | Student finished the school year | Auto-set at end of school year if all grades are finalized |

### Drop Flow

```
Teacher identifies student to be dropped
│
├── Teacher clicks "Mark as Dropped" on student's record
│
├── System shows confirmation dialog:
│   ┌──────────────────────────────────────────────────────┐
│   │  ⚠️ MARK STUDENT AS DROPPED                          │
│   │                                                       │
│   │  Student: Juan D. Santos (LRN: 123456789012)         │
│   │  Section: Grade 11 — Section A                       │
│   │                                                       │
│   │  This action will:                                   │
│   │  • Freeze all current grades at their present values │
│   │  • Remove student from active class lists            │
│   │  • Preserve all records for reporting                │
│   │  • Student's login will be deactivated               │
│   │                                                       │
│   │  Note: The offline process (letter of invitation,    │
│   │  home visitation, agreement) should be completed     │
│   │  before marking a student as dropped.                │
│   │                                                       │
│   │  Reason: [▼ Select reason         ]                  │
│   │  • Voluntary withdrawal                              │
│   │  • Non-attendance (exceeded absences)                 │
│   │  • Family decision                                   │
│   │  • Other: [_________________]                        │
│   │                                                       │
│   │  Date of Drop: [________] (defaults to today)        │
│   │                                                       │
│   │  [ Cancel ]  [ Confirm Drop ]                        │
│   └──────────────────────────────────────────────────────┘
│
├── Teacher confirms
│   ├── Update enrollment status to 'dropped'
│   ├── Freeze grades (no more edits allowed for this enrollment)
│   ├── Student account status → 'deactivated'
│   ├── Student disappears from active class lists
│   └── Record preserved for end-of-year reporting
│
└── Note: Dropping applies to ALL enrollments for that student,
    not just the current teacher's subject (since the student
    is leaving the school entirely).
```

### Transfer-In Flow

```
Teacher clicks "Add Student" → marks "Transfer Student" toggle
│
├── Normal student fields (name, LRN, birthday, etc.)
│
├── Additional Transfer Fields:
│   ├── Previous School Name *    [________________]
│   ├── Date of Transfer *        [________]
│   ├── Term Completed *          [▼ Term 1 / Term 2 ]
│   │
│   └── Previous Grades (manual entry):
│       ┌──────────────────────────────────────────┐
│       │  PREVIOUS SCHOOL GRADES                   │
│       │                                           │
│       │  Term 1 Grade: [____] (if completed)     │
│       │  Term 2 Grade: [____] (if completed)     │
│       │                                           │
│       │  These grades will be carried over into  │
│       │  the student's grade computation.         │
│       └──────────────────────────────────────────┘
│
├── System creates account + enrollment with is_transferee = true
└── Previous grades are stored and factored into final grade computation
```

---

## CLARIFYING QUESTIONS ANSWERED (For Reference)

### Round 1 (Initial Design)

| Question | Answer | Impact on Design |
|---|---|---|
| Who generates teacher's temp password? | Auto-generated: `{lastname_lower}{MMDDYYYY_birthday}`. Teacher changes it on first login after admin approval. | Same formula for all user types. Teacher never "chooses" their initial password — it's deterministic from their registration data. |
| Tutorial mode style? | Step-by-step overlay tooltips (coach marks / spotlight bubbles) | No dedicated walkthrough page. In-context tooltips that highlight sidebar items and key UI areas. |
| What happens when a section is deleted? | Soft-delete (archive). All data preserved but hidden. Teacher can restore later. | `is_archived` flag on section, cascading hide for students/grades/attendance. No data loss. |
| 3-term or 4-quarter? | 3 terms only (new DepEd format, SY 2026-2027 onwards) | System does NOT support the old 4-quarter format. Academic Setup shows 3 term date fields. |

### Round 2 (Post Client Interview)

| Question | Answer | Impact on Design |
|---|---|---|
| Max subjects per teacher? | No hard limit — 6 hours daily teaching cap | ~~Max 3 subjects~~ removed. Schedule validation warns at >6 hours/day. |
| Student dedup identifier? | LRN (12-digit unique DepEd ID) | LRN is the primary deduplication key. System checks LRN before creating any new student account. |
| Student view scope? | Active enrollments + toggle for past/completed | Student home shows current subjects by default. "Past Subjects" toggle shows completed/archived. |
| Dropped student handling? | Mark as 'Dropped' — account preserved, grades frozen | `dropped` enrollment status. Login deactivated. Records preserved for reporting. |
| Transfer student grades? | Teacher manually enters previous school grades | `is_transferee` flag + manual grade entry during enrollment. Grades carry over to computation. |

---

> [!IMPORTANT]
> **NEXT STEPS:**
> - **Step 2 (Pending):** High-Level Database Schema Strategy — entity relationship diagram, Supabase table design, local storage schema for offline sync, conflict resolution rules.
> - **Step 3 (Pending):** API Security & Rate Limiting — Supabase RLS policies, Firebase Auth JWT verification, rate limiting strategy, cache/cookie management, zero-exposed-API architecture.
>
> **Awaiting your go-ahead to proceed to Step 2.** Please also send any additional information you mentioned you'd share later.
