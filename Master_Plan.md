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

The system will store the official subject list as reference data. The setup reflects the Excel E-Class Record templates:
1. **Curriculum Type Selection:** Teacher chooses "Strengthened SHS (New)" or "Old Curriculum".
2. **If Strengthened SHS:** Teacher selects from dropdowns:
   - **Subject Category:** `SSHS - CORE`, `SSHS - ACADEMIC`, `SSHS - TECH-PRO`, etc.
   - **Cluster:** Filters based on Category (e.g., `CORE`, `ARTS, SOCIAL SCIENCES, AND HUMANITIES`, `BUSINESS AND ENTREPRENEURSHIP`).
   - **Subject:** Filters based on Cluster (e.g., `General Mathematics`, `Earth and Life Science`).
   - **Terms:** Auto-fills `No. Terms Taught` (3), `Units per term` (2), `Units per year` (6).
3. **If Old Curriculum:** Uses a "Custom" setup where the teacher manually inputs the WW, PT, EX weights without pre-filled dropdowns.

> [!NOTE]
> **Instructions & Input Data Views:** Similar to the Excel file, the UI will feature an "Instructions" tab guiding the teacher. The "Input Data" tab will auto-populate School Info and Learner Names into grading terms. Teachers only manually configure the Grade Level, Section Name, and Subject Area Info.

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
| **Component Weights Presets** | • Core & Academic: WW 20%, PT 50%, EX 30%<br>• TechPro (TVL/ICT): WW 15%, PT 65%, EX 20%<br>• Arts/Sports: WW 20%, PT 60%, EX 20%<br>• Research/Design: WW 15%, PT 70%, EX 15%<br>• Work Immersion: WW 40%, PT 60% | DO 015, s. 2026 (SSHS ECR Preset) |
| **Examination Sub-types** | Summative Test 1 (ST1: 30%), Summative Test 2 (ST2: 30%), Term Examination (TE: 40%) | DO 015, s. 2026 EX Internal Weights |
| **Grade Computation** | Raw → Percentage → Weighted → Initial Grade → Transmuted Grade (Adjusted Table) | DepEd Adjusted Transmutation Table |
| **Descriptors** | Advancing (90-100), Benchmarking (80-89), Connecting (75-79), Developing (65-74), Emerging (60-64) | DO 015, s. 2026 Qualitative Scale |
| **Final Grade Formula** | $\text{Final Grade} = \text{ROUND}((\text{TG}_1 + \text{TG}_2 + \text{TG}_3) / 3, 0)$ | 3-Term Trimester Averaging |
| **Upcoming Change** | Zero-Based Grading (no transmutation) planned for SY 2027-2028 | DepEd announcement |
| **SHS Curriculum** | "Strengthened SHS" — streamlined to core subjects + electives | DepEd SHS reform |
| **Tracks** | Academic Track, Technical-Professional (TechPro) Track | DO structure |

### How ClassRealm Aligns

| DepEd Requirement | ClassRealm Implementation |
|---|---|
| 3-term calendar | School Year Setup enforces 3 terms with start/end dates per term |
| Subject-specific weights | Automatic presets via Category/Cluster selection + Custom Override mode (See [Gradebook_Architecture.md](file:///c:/Users/Admin/AndroidStudioProjects/class_realm01/Gradebook_Architecture.md#L24-L135)) |
| Transmutation table | 41-tier Adjusted Transmutation Table built into DB & grading engine |
| Assessment categories | Explicit `AssessmentCategory` enum: `writtenWork`, `performanceTask`, `summativeTest1`, `summativeTest2`, `termExamination` |
| Term-based final grade | Final Grade = average of 3 term grades rounded to nearest integer |

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
| Section shifting / transfer mid-year | **NOT ALLOWED** — students stay in their section | No section transfer feature needed for students. Enrollment is permanent per school year. If enrolled in the wrong section, the record must be Archived and a new enrollment created. |
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
subject_catalog table (seeded by system, matching Excel template)
├── id: UUID
├── category: "SSHS - CORE" | "SSHS - ACADEMIC" | "SSHS - TECH-PRO"
├── cluster: "CORE" | "ARTS, SOCIAL SCIENCES, AND HUMANITIES" | "BUSINESS AND ENTREPRENEURSHIP" | etc.
├── name: "General Mathematics"
├── grade_level: 11
├── no_terms_taught: 3
├── units_per_term: 2.0
├── units_per_year: 6.0
└── is_active: true

When teacher selects "Strengthened SHS" in Academic Setup:
├── 1. Select Category (Dropdown)
├── 2. Select Cluster (Filtered by Category)
├── 3. Select Subject (Filtered by Cluster)
└── Auto-fills Terms and Units
```

---

## 1.16 Student Status Lifecycle (Drop / Transfer)

### Student Enrollment Statuses

| Status | Meaning | Triggers |
|---|---|---|
| `Pending` | Student data entered, awaiting finalization | Created by Teacher |
| `PendingFirstLogin` | Account created, awaiting student login | Teacher finalizes enrollment |
| `Active` | Currently enrolled and participating | Student logs in / verified |
| `Dropped` | Student has dropped out after formal process | Teacher marks after completing offline process |
| `Transferred` | Student transferred to another school (In/Out) | Teacher marks when student leaves or arrives |
| `Archived` | Student record is invalid or from a past year | Admin/Teacher soft-deletes the record |

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

## 1.17 Forgot Password Flow

> [!NOTE]
> Applies to ALL user types (Teacher, Student, Parent). Same process regardless of role.

### When to Use

- User forgets their password (including the auto-generated temp password).
- User wants to reset after suspected account compromise.

### Flow

```
User clicks "Forgot Password?" on Login Screen
│
├── Show Forgot Password Screen:
│   ┌──────────────────────────────────────────────────┐
│   │  FORGOT PASSWORD                                  │
│   │                                                   │
│   │  Enter the email address linked to your account. │
│   │  We'll send you a password reset link.           │
│   │                                                   │
│   │  Email *  [________________________]             │
│   │                                                   │
│   │  [ Back to Login ]  [ Send Reset Link ]          │
│   └──────────────────────────────────────────────────┘
│
├── User enters email → clicks "Send Reset Link"
│   ├── Client-side: Valid email format?
│   │   ├── NO → Inline error: "Please enter a valid email address."
│   │   └── YES ↓
│   │
│   ├── Firebase Auth: sendPasswordResetEmail(email)
│   │   ├── Generates one-time secure reset link
│   │   ├── Sends email to user
│   │   └── Link expires in 1 hour (Firebase default)
│   │
│   └── Show confirmation (SAME message whether email exists or not):
│       ┌──────────────────────────────────────────────────┐
│       │  📧 CHECK YOUR EMAIL                              │
│       │                                                   │
│       │  If an account exists with that email, we've     │
│       │  sent a password reset link.                      │
│       │                                                   │
│       │  • Check your inbox (and spam folder)            │
│       │  • Link expires in 1 hour                        │
│       │  • Didn't receive it? Try again                  │
│       │                                                   │
│       │  [ Back to Login ]  [ Resend Link ]              │
│       └──────────────────────────────────────────────────┘
│
├── User clicks link in email → Firebase Reset Page
│   ├── Enter new password (same rules as Section 1.5):
│   │   ├── Min 8 chars, 1 uppercase, 1 lowercase, 1 number, 1 special char
│   │   └── Confirm password must match
│   ├── Firebase updates password
│   └── Redirect to Login: "Password reset successful!"
│
└── Rate Limiting (Anti-Abuse):
    ├── Max 3 reset requests per email per hour
    └── Firebase built-in IP-based rate limiting
```

### Edge Cases

| Scenario | System Behavior |
|---|---|
| Email not registered | Same "check your email" message (prevents email enumeration attack) |
| Student/Parent without email | Must contact Teacher → Teacher resets from Dashboard (see below) |
| Reset link expired | "Link expired. Please request a new one." |
| Account is `pending` / `rejected` | Reset processes, but login blocked until approved |
| Account is `deactivated` | Reset processes, but Supabase status check blocks login |

### Manual Password Reset by Teacher (For Students/Parents Without Email)

```
Teacher Dashboard → Student Management → Select Student → "Reset Password"
│
├── Confirmation dialog:
│   ┌──────────────────────────────────────────────────┐
│   │  🔄 RESET STUDENT PASSWORD                       │
│   │                                                   │
│   │  Reset password for Juan Dela Cruz to the        │
│   │  default temporary password?                      │
│   │                                                   │
│   │  New temp password: delacruz03202010              │
│   │  (lastname + birthday MMDDYYYY)                   │
│   │                                                   │
│   │  Student will be required to change this          │
│   │  password on their next login.                    │
│   │                                                   │
│   │  [ Cancel ]  [ Reset Password ]                  │
│   └──────────────────────────────────────────────────┘
│
├── Teacher confirms
│   ├── Firebase Auth: update password → temp password
│   ├── Supabase: is_first_login = true (forces change on next login)
│   └── Teacher notifies student verbally of the reset
│
└── Student logs in with temp password → forced to change again
```

---

## 1.18 Attendance Computation & Auto-Drop Rules

> [!IMPORTANT]
> **Per-term rule** drops from **THAT SUBJECT ONLY** (hindi lahat). **Overall rule** drops from **ALL SUBJECTS**. These are separate, independent checks.

### Rule 1: Per-Subject Per-Term Auto-Drop

| Parameter | Value |
|---|---|
| **Threshold** | ≥ 12 absent days in ONE subject in ONE term |
| **Scope** | Per subject, per term (based on subject's class schedule) |
| **Based On** | Only the scheduled class days of that specific subject |
| **Result** | Student → **DROPPED from THAT SUBJECT ONLY** |
| **Other Subjects** | **NOT affected** — student remains active in all other subjects |

#### How "Absent Day" Is Counted

```
"Absent Day" = 1 scheduled class meeting that the student did NOT attend.

Example: General Mathematics is scheduled Mon, Wed, Fri
├── Student absent on Monday → 1 absent day for Math
├── Student absent on Monday AND Wednesday → 2 absent days for Math
├── Only MATH class days are counted, NOT other subjects
├── Late ≠ Absent (Late has its own separate tracking)
└── Excused absence = still counted as absent (affects threshold)

Per-Term Calculation:
├── Term 1 has ~65 total school days
├── Math (MWF) has ~39 class meetings in Term 1
├── Science (TTh) has ~26 class meetings in Term 1
├── If student misses 12 of those 39 Math meetings → DROP THRESHOLD HIT for Math
├── But student only missed 4 Science meetings → Science is SAFE
└── Student gets dropped from Math ONLY, stays in Science
```

#### Warning Flow

```
System detects student has reached 12 absences in Math (Term 1)
│
├── Teacher Dashboard shows alert:
│   ┌──────────────────────────────────────────────────────┐
│   │  ⚠️ ATTENDANCE DROP ALERT                            │
│   │                                                       │
│   │  Juan Dela Cruz has reached 12 absences in           │
│   │  General Mathematics (Term 1).                       │
│   │                                                       │
│   │  Absent: 12 / 39 class meetings (30.8%)              │
│   │                                                       │
│   │  Per school policy, this student is eligible          │
│   │  for dropping from this subject.                      │
│   │                                                       │
│   │  [ View Attendance Record ]                          │
│   │  [ Mark as Dropped ]  [ Dismiss ]                    │
│   └──────────────────────────────────────────────────────┘
│
├── NOTE: System does NOT auto-drop. It WARNS the teacher.
│   Teacher makes the final decision after reviewing.
│
└── If teacher confirms drop:
    ├── Enrollment status for THIS subject → 'dropped'
    ├── Grades for this subject → frozen
    └── Student remains ACTIVE in all OTHER subjects
```

### Rule 2: Overall Cross-Term Auto-Drop (Buong School Year)

| Parameter | Value |
|---|---|
| **Threshold** | ≥ 20% of total school days absent across Terms 1-3 |
| **Scope** | ALL subjects combined, entire school year |
| **Result** | Student → **DROPPED from ALL SUBJECTS** |

#### How It's Computed

```
At any point during the school year:
│
├── total_class_meetings = SUM of all scheduled meetings across ALL subjects
│   Example: Math(39) + Science(26) + English(39) + PE(13) + ... = 200 total
│
├── total_absent = SUM of all absences across ALL subjects in Terms 1-3
│   Example: Math(5) + Science(8) + English(12) + PE(3) + ... = 40 total
│
├── absence_rate = (total_absent / total_class_meetings) × 100
│   = (40 / 200) × 100 = 20.0%
│
├── IF absence_rate >= 20%:
│   ├── Alert ALL teachers handling this student:
│   │   "🔴 CRITICAL: Juan Dela Cruz has exceeded 20% total absences
│   │    across all subjects (20.0%). Eligible for school-wide dropping."
│   │
│   ├── Admin also notified for review
│   │
│   └── Once confirmed by Admin/Teacher:
│       ├── ALL enrollments → 'dropped'
│       ├── Student account → 'deactivated'
│       └── All grades → frozen at current values
│
└── IF absence_rate < 20%:
    └── No action. Continue monitoring.
```

### Attendance Dashboard Indicators (Per Student)

```
┌────────────────────────────────────────────────────────────┐
│  Juan Dela Cruz — General Mathematics (Term 1)             │
│                                                            │
│  Present: 28  │  Absent: 9  │  Late: 3  │  Excused: 2    │
│                                                            │
│  Per-Subject:  ██████████████████░░░░  9/12 absences       │
│  ▲ WARNING — 3 absences away from subject drop             │
│                                                            │
│  Overall (All Subjects): 14.2% absent (threshold: 20%)     │
│  ████████████████░░░░░░░░░░  14.2% / 20%                  │
│  ▲ Approaching overall threshold                           │
└────────────────────────────────────────────────────────────┘
```

### Color-Coded Alert Levels

**Per-Subject (Per Term):**

| Absent Count | Color | Alert Level |
|---|---|---|
| 0 – 6 | 🟢 Green | Normal |
| 7 – 9 | 🟡 Yellow | Warning — Nearing limit |
| 10 – 11 | 🟠 Orange | Critical — 1-2 absences away |
| 12+ | 🔴 Red | Drop threshold reached — Action required |

**Overall (Cross-Term, All Subjects):**

| Absence Rate | Color | Alert Level |
|---|---|---|
| 0% – 10% | 🟢 Green | Normal |
| 10% – 15% | 🟡 Yellow | Warning |
| 15% – 19% | 🟠 Orange | Critical |
| 20%+ | 🔴 Red | Drop threshold — Action required |

---

## 1.19 Assessment Engine (WW, PT, Quiz, ST1, ST2, TE)

> 🔲 **TODO — Awaiting detailed specifications.** Add your details below the marker.

### Topics to Cover When Complete

- [ ] How teachers create Written Works (WW) activities
- [ ] How teachers create Performance Tasks (PT)
- [ ] How to create Quizzes
- [ ] Summative Tests (ST1, ST2) creation flow
- [ ] Term Examination (TE) creation flow
- [ ] Question types: Multiple Choice, True/False, Identification, Essay
- [ ] Scoring rules, total points, passing scores
- [ ] Deadline and late submission handling
- [ ] Student submission flow (file upload, online answer)
- [ ] Teacher grading/checking flow

<!-- ═══════════════════════════════════════════════════════ -->
<!-- 📝 ADD YOUR ASSESSMENT ENGINE DETAILS BELOW THIS LINE  -->
<!-- ═══════════════════════════════════════════════════════ -->



---

## 1.20 Anti-Cheat Exam Engine

> 🔲 **TODO — Awaiting detailed specifications.** Add your details below the marker.

### Topics to Cover When Complete

- [ ] Full-screen lock during exams (mobile & web)
- [ ] Tab-switch / app-switch detection and penalties
- [ ] How many warnings before auto-submit? (e.g., 3 warnings)
- [ ] Randomized question order per student
- [ ] Randomized answer choices per question
- [ ] Time limit per exam and per question (optional)
- [ ] Auto-submit when time runs out
- [ ] Exam violation logging and teacher notification
- [ ] Teacher live monitoring view during exam
- [ ] Copy-paste blocking
- [ ] Screen record/screenshot detection (if possible)

<!-- ═══════════════════════════════════════════════════════ -->
<!-- 📝 ADD YOUR ANTI-CHEAT ENGINE DETAILS BELOW THIS LINE  -->
<!-- ═══════════════════════════════════════════════════════ -->



---

## 1.21 Item Analysis Engine

> 🔲 **TODO — Awaiting detailed specifications.** Add your details below the marker.

### Topics to Cover When Complete

- [ ] Difficulty Index formula: P = R / N
- [ ] Discrimination Index formula: D = (U - L) / Ng
- [ ] How questions are classified: Retain, Revise, or Discard
- [ ] Per-question breakdown view for teachers
- [ ] Per-exam summary statistics
- [ ] Auto-computed after all students finish the exam

<!-- ═══════════════════════════════════════════════════════ -->
<!-- 📝 ADD YOUR ITEM ANALYSIS ENGINE DETAILS BELOW THIS LINE -->
<!-- ═══════════════════════════════════════════════════════ -->



---

## 1.22 DepEd Grading Computation Engine

> 🔲 **TODO — Awaiting detailed specifications.** Add your details below the marker.

### Topics to Cover When Complete

- [ ] Step-by-step formula: Raw Score → Percentage Score → Weighted Score → Initial Grade → Transmuted Grade
- [ ] DepEd Transmutation Table (exact values)
- [ ] How WW, PT, EX weights are applied per subject
- [ ] Term grade computation
- [ ] Final Grade = average of 3 term grades
- [ ] Teacher grade override/adjustment capability
- [ ] Passing grade threshold (75 transmuted = passing)
- [ ] Zero-Based Grading readiness (SY 2027-2028)
- [ ] Handling of incomplete grades

<!-- ═══════════════════════════════════════════════════════ -->
<!-- 📝 ADD YOUR GRADING ENGINE DETAILS BELOW THIS LINE     -->
<!-- ═══════════════════════════════════════════════════════ -->



---

## 1.23 Lesson Plan Generator & Learning Materials

> 🔲 **TODO — Awaiting detailed specifications.** Add your details below the marker.

### Topics to Cover When Complete

- [ ] Lesson plan template structure (topic, objectives, activities, assessment)
- [ ] AI-assisted lesson plan generation flow (if applicable)
- [ ] Manual creation flow
- [ ] File upload for learning materials (PDF, images, documents, links)
- [ ] File size limits (max 2MB per file, enforced)
- [ ] Organization by subject, term, and topic
- [ ] How students access uploaded materials
- [ ] Editing and versioning of saved lesson plans

<!-- ═══════════════════════════════════════════════════════ -->
<!-- 📝 ADD YOUR LESSON PLAN DETAILS BELOW THIS LINE        -->
<!-- ═══════════════════════════════════════════════════════ -->



---

## 1.24 Student Mobile App Flow

> 🔲 **TODO — Awaiting detailed specifications.** Add your details below the marker.
> See also: [Section 1.30 Input Fields Registry](#130-input-fields-registry) for Student account fields.

### Topics to Cover When Complete

- [ ] Student first-time login and password change (mobile)
- [ ] Multi-subject dashboard navigation (shows all enrolled subjects)
- [ ] Viewing attendance record per subject
- [ ] Taking quizzes/exams on phone (with anti-cheat fullscreen lock)
- [ ] Submitting assignments and performance tasks (file upload or online)
- [ ] Viewing grades per term and general average
- [ ] Viewing and downloading learning materials
- [ ] Viewing class schedule
- [ ] Viewing announcements
- [ ] Profile settings and password change

<!-- ═══════════════════════════════════════════════════════ -->
<!-- 📝 ADD YOUR STUDENT APP FLOW DETAILS BELOW THIS LINE   -->
<!-- ═══════════════════════════════════════════════════════ -->



---

## 1.25 Parent Mobile App Flow

> 🔲 **TODO — Awaiting detailed specifications.** Add your details below the marker.
> See also: [Section 1.30 Input Fields Registry](#130-input-fields-registry) for Parent account fields.

### Topics to Cover When Complete

- [ ] Parent account creation by Teacher (linked to student via LRN)
- [ ] Parent first-time login and password change (mobile)
- [ ] How parent links to their child's account (LRN + birthday verification?)
- [ ] Viewing child's attendance (real-time alerts via FCM push notification)
- [ ] Viewing child's grades per subject and term
- [ ] Viewing child's class schedule
- [ ] Receiving announcements from teachers
- [ ] Multiple children support (can 1 parent link to many students?)
- [ ] Parent notification preferences

<!-- ═══════════════════════════════════════════════════════ -->
<!-- 📝 ADD YOUR PARENT APP FLOW DETAILS BELOW THIS LINE    -->
<!-- ═══════════════════════════════════════════════════════ -->



---

## 1.26 Admin Portal Complete Flow

> 🔲 **TODO — Awaiting detailed specifications.** Add your details below the marker.
> Note: Basic approval/rejection flow is already defined in [Section 1.4](#14-admin-approval-flow).

### Topics to Cover When Complete

- [ ] Admin dashboard overview (total teachers, students, pending approvals)
- [ ] Teacher account management (approve, reject, deactivate, view all)
- [ ] Master Student Directory (search by LRN across all teachers/sections)
- [ ] System settings (school year management, subject catalog editing)
- [ ] Audit logs (who did what, when)
- [ ] Data export capabilities (DepEd reports, attendance summaries)
- [ ] Admin account management (how to add more admins? Pre-seeded only?)
- [ ] System monitoring and usage statistics

<!-- ═══════════════════════════════════════════════════════ -->
<!-- 📝 ADD YOUR ADMIN PORTAL DETAILS BELOW THIS LINE       -->
<!-- ═══════════════════════════════════════════════════════ -->



---

## 1.27 ESP32/RFID Hardware Integration

> 🔲 **TODO — Awaiting detailed specifications.** Add your details below the marker.

### Topics to Cover When Complete

- [ ] ESP32 microcontroller + RC522 RFID reader hardware setup
- [ ] Data format transmitted by ESP32 (UID, timestamp, format)
- [ ] Connection method: USB Serial / Bluetooth / Local WiFi AP
- [ ] RFID card registration flow (teacher assigns card UID to student LRN)
- [ ] What happens when an unregistered card taps
- [ ] Multiple readers support (1 per classroom?)
- [ ] Power supply and hardware placement considerations
- [ ] Offline buffering on ESP32 vs on Flutter app

<!-- ═══════════════════════════════════════════════════════ -->
<!-- 📝 ADD YOUR HARDWARE INTEGRATION DETAILS BELOW THIS LINE -->
<!-- ═══════════════════════════════════════════════════════ -->



---

## 1.28 Notification System

> 🔲 **TODO — Awaiting detailed specifications.** Add your details below the marker.

### Topics to Cover When Complete

- [ ] Notification types (attendance alert, grade posted, announcement, assessment due, drop warning)
- [ ] Who receives what (Teacher → ?, Student → ?, Parent → ?, Admin → ?)
- [ ] Push notification via Firebase FCM (mobile)
- [ ] In-app notification center (web & mobile)
- [ ] Email notifications (which events trigger email?)
- [ ] Read/unread status tracking
- [ ] Notification preferences (can users mute certain types?)

<!-- ═══════════════════════════════════════════════════════ -->
<!-- 📝 ADD YOUR NOTIFICATION SYSTEM DETAILS BELOW THIS LINE -->
<!-- ═══════════════════════════════════════════════════════ -->



---

## 1.29 Reports & Data Export

> 🔲 **TODO — Awaiting detailed specifications.** Add your details below the marker.

### Topics to Cover When Complete

- [ ] DepEd School Form 2 (SF2) — Daily Attendance Report export
- [ ] Class record / Grade sheet export (per subject, per term)
- [ ] Student performance summary (per student, across subjects)
- [ ] Attendance summary report (monthly, per term)
- [ ] Item analysis report (per exam)
- [ ] Export formats: PDF, Excel (.xlsx), CSV
- [ ] Who can generate which reports (Teacher, Admin)

<!-- ═══════════════════════════════════════════════════════ -->
<!-- 📝 ADD YOUR REPORTS & EXPORT DETAILS BELOW THIS LINE   -->
<!-- ═══════════════════════════════════════════════════════ -->



---

## 1.30 Input Fields Registry

> [!IMPORTANT]
> This section lists **ALL input fields for EVERY form** in the system.
> Fields marked 🔲 **TODO** still need to be decided — **ikaw ang mag-fill in** kung kailangan o hindi.
> Fields marked ✅ are already defined in earlier sections.
> I-edit mo lang ang tables below para mag-add, mag-remove, o mag-change ng field requirements.

### A. Teacher Account — Registration Form (Ref: Section 1.3)

| # | Field Name | Type | Required? | Status | Notes |
|---|---|---|---|---|---|
| 1 | First Name | String | ✅ Required | ✅ Defined | 2-50 chars, letters/spaces/hyphens |
| 2 | Middle Name | String | Optional | ✅ Defined | Same rules if provided |
| 3 | Last Name | String | ✅ Required | ✅ Defined | 2-50 chars |
| 4 | Birthday | DateTime | ✅ Required | ✅ Defined | Age ≥ 21, Year ≥ 1960 |
| 5 | Age | int | Auto-calc | ✅ Defined | Read-only, computed from birthday |
| 6 | Email | String | ✅ Required | ✅ Defined | Must be unique in system |
| 7 | Gender | Enum | ✅ Required | ✅ Defined | Male / Female |
| 8 | Terms Accepted | bool | ✅ Required | ✅ Defined | Must be true to submit |
| 9 | Name Extension (Jr., III) | String | ? | 🔲 TODO | _Decide if needed_ |
| 10 | Phone / Contact Number | String | ? | 🔲 TODO | _Decide if needed_ |
| 11 | DepEd Employee ID | String | ? | 🔲 TODO | _For Admin verification?_ |
| 12 | PRC License Number | String | ? | 🔲 TODO | _Optional teaching license proof?_ |
| 13 | Profile Photo | File | Optional (in Profile Settings) | ✅ Defined | **Only allowed image type in system:** `.jpg`, `.jpeg`, `.png` only (Max 500 KB, auto-compressed to $\le 100\text{ KB}$, 1:1 square crop). Excluded from initial registration form. |
| 14 | Specialization / Major | String | ? | 🔲 TODO | _e.g., "Mathematics", "English"_ |
| 15 | Address | String | ? | 🔲 TODO | _Full address or barangay/city only?_ |

<!-- 📝 ADD MORE TEACHER FIELDS ABOVE IF NEEDED -->

### B. Student Account — Add Student Form (Ref: Section 1.9)

| # | Field Name | Type | Required? | Status | Notes |
|---|---|---|---|---|---|
| 1 | First Name | String | ✅ Required | ✅ Defined | 2-50 chars |
| 2 | Middle Name | String | Optional | ✅ Defined | |
| 3 | Last Name | String | ✅ Required | ✅ Defined | 2-50 chars |
| 4 | LRN | String | ✅ Required | ✅ Defined | Exactly 12 digits, unique |
| 5 | Birthday | DateTime | ✅ Required | ✅ Defined | Age 10-25, Year ≥ 2000 |
| 6 | Age | int | Auto-calc | ✅ Defined | Read-only |
| 7 | Gender | Enum | ✅ Required | ✅ Defined | Male / Female |
| 8 | Contact # | String | Optional | ✅ Defined | Student's own or guardian's |
| 9 | Subject Assignment | FK | ✅ Required | ✅ Defined | From teacher's active subjects |
| 10 | Section Assignment | FK | ✅ Required | ✅ Defined | From sections under subject |
| 11 | Name Extension (Jr., III) | String | ? | 🔲 TODO | _Decide if needed_ |
| 12 | Strand / Track | Enum | ? | 🔲 TODO | _STEM, ABM, HUMSS, TVL, etc._ |
| 13 | Guardian / Parent Name | String | ? | 🔲 TODO | _For linking parent accounts_ |
| 14 | Guardian Contact # | String | ? | 🔲 TODO | _If different from student contact_ |
| 15 | Email | String | ? | 🔲 TODO | _Not all students have email_ |
| 16 | Address | String | ? | 🔲 TODO | _Home address_ |
| 17 | RFID Card UID | String | ? | 🔲 TODO | _Assigned during RFID card registration_ |
| 18 | Profile Photo | File | Optional (in Profile Settings) | ✅ Defined | **Only allowed image type:** `.jpg`/`.png` only, Max 500 KB (auto-compressed to $\le 100\text{ KB}$, 1:1 square crop). |

<!-- 📝 ADD MORE STUDENT FIELDS ABOVE IF NEEDED -->

### C. Parent Account — Created by Teacher

> 🔲 **TODO — Parent account creation flow is not yet defined.**
> Fill in the fields below when ready. All fields are tentative.

| # | Field Name | Type | Required? | Status | Notes |
|---|---|---|---|---|---|
| 1 | First Name | String | ? | 🔲 TODO | |
| 2 | Middle Name | String | ? | 🔲 TODO | |
| 3 | Last Name | String | ? | 🔲 TODO | |
| 4 | Name Extension (Jr., III) | String | ? | 🔲 TODO | |
| 5 | Relationship to Student | Enum | ? | 🔲 TODO | _Mother, Father, Guardian_ |
| 6 | Linked Student LRN | String | ? | 🔲 TODO | _Which student is this parent linked to?_ |
| 7 | Birthday | DateTime | ? | 🔲 TODO | _For temp password generation_ |
| 8 | Gender | Enum | ? | 🔲 TODO | |
| 9 | Email | String | ? | 🔲 TODO | _"Not all have Gmail" — make optional?_ |
| 10 | Phone / Contact # | String | ? | 🔲 TODO | _For SMS or app-based notifications_ |
| 11 | Address | String | ? | 🔲 TODO | _Same as student or different?_ |

<!-- 📝 ADD MORE PARENT FIELDS ABOVE WHEN DECIDED -->

### D. Admin Account — Pre-Seeded by Capstone Team

> Admin accounts are **NOT** created through registration. Pre-seeded by the development team.

| # | Field Name | Type | Required? | Status | Notes |
|---|---|---|---|---|---|
| 1 | First Name | String | Required | 🔲 TODO | _Define validation rules_ |
| 2 | Last Name | String | Required | 🔲 TODO | |
| 3 | Email | String | Required | 🔲 TODO | _Used for login_ |
| 4 | Password | String | Required | 🔲 TODO | _Set manually during seeding_ |
| 5 | Role | Enum | Required | ✅ Defined | Always 'admin' |

### E. Assessment Form Fields

> 🔲 **TODO — Define when Assessment Engine (Section 1.19) is completed.**

| # | Field Name | Type | Required? | Status | Notes |
|---|---|---|---|---|---|
| 1 | Title | String | ? | 🔲 TODO | _e.g., "Quiz 1: Polynomials"_ |
| 2 | Assessment Category | Enum | ? | 🔲 TODO | _WW, PT, ST1, ST2, TE_ |
| 3 | Total Points | int | ? | 🔲 TODO | |
| 4 | Passing Score | int | ? | 🔲 TODO | |
| 5 | Due Date / Schedule | DateTime | ? | 🔲 TODO | |
| 6 | Term | Enum | ? | 🔲 TODO | _Term 1, 2, or 3_ |
| 7 | Time Limit (minutes) | int | ? | 🔲 TODO | _For exams only?_ |
| 8 | Anti-Cheat Enabled | bool | ? | 🔲 TODO | _For online exams_ |
| 9 | Shuffle Questions | bool | ? | 🔲 TODO | |
| 10 | Instructions | String | ? | 🔲 TODO | |
| 11 | Assigned Section(s) | FK[] | ? | 🔲 TODO | _Which sections take this?_ |

<!-- 📝 ADD MORE ASSESSMENT FIELDS ABOVE WHEN DECIDED -->

### F. Question / Item Fields (Per Question in an Assessment)

> 🔲 **TODO — Define when Assessment Engine (Section 1.19) is completed.**

| # | Field Name | Type | Required? | Status | Notes |
|---|---|---|---|---|---|
| 1 | Question Text | String | ? | 🔲 TODO | |
| 2 | Question Type | Enum | ? | 🔲 TODO | _MC, True/False, Identification, Essay_ |
| 3 | Image Attachment | File | ? | 🔲 TODO | _Optional per question_ |
| 4 | Choices (A-D) | String[] | ? | 🔲 TODO | _For MC questions only_ |
| 5 | Correct Answer | String | ? | 🔲 TODO | |
| 6 | Points | int | ? | 🔲 TODO | _Per question_ |
| 7 | Cognitive Level (Bloom's) | Enum | ? | 🔲 TODO | _Remember, Understand, Apply, etc._ |

<!-- 📝 ADD MORE QUESTION FIELDS ABOVE WHEN DECIDED -->

### G. Lesson Plan Form Fields

> 🔲 **TODO — Define when Lesson Plan section (Section 1.23) is completed.**

| # | Field Name | Type | Required? | Status | Notes |
|---|---|---|---|---|---|
| 1 | Lesson Topic | String | ? | 🔲 TODO | |
| 2 | Learning Objectives | String[] | ? | 🔲 TODO | |
| 3 | Subject | FK | ? | 🔲 TODO | |
| 4 | Term | Enum | ? | 🔲 TODO | |
| 5 | Lesson Content / Info | String | ? | 🔲 TODO | |
| 6 | Activities | String | ? | 🔲 TODO | |
| 7 | Assessment Method | String | ? | 🔲 TODO | |

<!-- 📝 ADD MORE LESSON PLAN FIELDS ABOVE WHEN DECIDED -->

### H. Learning Material Upload Fields

> 📄 **Document Formats Only:** Strictly `.pdf`, `.docx`, `.doc`, `.xlsx`, `.xls`, `.pptx`, `.ppt` (Max 5 MB). Direct image (`.jpg`/`.png`) and video (`.mp4`) uploads are strictly prohibited. For video lessons, teachers use the Video Resource Link field (YouTube/Google Drive).

| # | Field Name | Type | Required? | Status | Notes / Restrictions |
|---|---|---|---|---|---|
| 1 | Material Title | String | ✅ Required | ✅ Defined | 2–100 characters |
| 2 | File Upload | File | Optional (if link provided) | ✅ Defined | **Strictly PDF, Word, Excel, PPT only (Max 5 MB)**. Direct JPG/PNG/MP4 blocked. |
| 3 | Video Resource Link | String (URL) | Optional | ✅ Defined | YouTube (Unlisted) or Google Drive link for video lectures (0 MB storage consumed). |
| 4 | File Type | Enum | Auto | ✅ Defined | Auto-detected: `PDF`, `DOCX`, `XLSX`, `PPTX`, `VIDEO_LINK` |
| 5 | Category / Topic | String | ✅ Required | 🔲 TODO | e.g. "Lesson 1: Functions and Graphs" |
| 6 | Subject | FK | ✅ Required | ✅ Defined | References teacher's active teaching assignment |
| 7 | Term | Enum | ✅ Required | ✅ Defined | `Term 1`, `Term 2`, or `Term 3` |
| 8 | Upload Date | DateTime | Auto | ✅ Defined | System-generated timestamp |

<!-- 📝 ADD MORE MATERIAL FIELDS ABOVE WHEN DECIDED -->

### I. Schedule Data Fields

> Partially defined in Section 1.6 (Academic Setup Wizard Step 4).

| # | Field Name | Type | Required? | Status | Notes |
|---|---|---|---|---|---|
| 1 | Subject | FK | ✅ Required | ✅ Defined | |
| 2 | Section | FK | ✅ Required | ✅ Defined | |
| 3 | Day of Week | Enum | ✅ Required | ✅ Defined | _Mon-Fri_ |
| 4 | Start Time | Time | ✅ Required | ✅ Defined | |
| 5 | End Time | Time | ✅ Required | ✅ Defined | _Duration ≥ 30 min, ≤ 4 hours_ |
| 6 | Room | String | Optional | ✅ Defined | _Some schools don't assign rooms_ |

### J. Notification Fields

> 🔲 **TODO — Define when Notification System (Section 1.28) is completed.**

| # | Field Name | Type | Required? | Status | Notes |
|---|---|---|---|---|---|
| 1 | Notification Type | Enum | ? | 🔲 TODO | _attendance, grade, announcement, etc._ |
| 2 | Message | String | ? | 🔲 TODO | |
| 3 | Recipient | FK | ? | 🔲 TODO | |
| 4 | Date/Time | DateTime | ? | 🔲 TODO | |
| 5 | Read/Unread Status | bool | ? | 🔲 TODO | |

<!-- 📝 ADD MORE NOTIFICATION FIELDS ABOVE WHEN DECIDED -->

### K. Offline Sync Data Fields

> System-managed. Users do NOT manually control sync.

| # | Field Name | Type | Required? | Status | Notes |
|---|---|---|---|---|---|
| 1 | Offline Record ID | UUID | Auto | 🔲 TODO | _Local primary key_ |
| 2 | Record Type | Enum | Auto | 🔲 TODO | _attendance, etc._ |
| 3 | Payload (JSON) | String | Auto | 🔲 TODO | _The data to sync_ |
| 4 | Created At | DateTime | Auto | 🔲 TODO | _When recorded offline_ |
| 5 | Sync Status | Enum | Auto | 🔲 TODO | _PENDING, SYNCED, FAILED_ |
| 6 | Synced At | DateTime | Auto | 🔲 TODO | _When successfully uploaded_ |

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
