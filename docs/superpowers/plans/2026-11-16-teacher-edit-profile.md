# Teacher Profile Editing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable teachers to edit their complete profile (Basic Info: Name, Birthday, Age, Gender, and Email with OTP verification; Contact Info: strict 09-format phone number, verified Facebook profile URL; Professional Info: structured Monday–Sunday consultation hours picker) and replace the "Edit Profile (Next Update)" placeholder with an active, production-ready workflow.

**Architecture:** A comprehensive `EditTeacherProfileDialog` modal with real-time inline validation, email OTP verification flow for email changes, structured interactive day/time pickers for consultation hours, backed by `AuthRepository.updateTeacherCompleteProfile` that updates Supabase `users`, `teacher_profiles`, and `teacher_settings`, refreshes `LocalStorageService`, and notifies `TeacherProfileTab`.

**Tech Stack:** Flutter, Dart, Supabase Flutter client, SharedPreferences (LocalStorageService), 60-30-10 Design System.

**Spec:** Teacher Faculty Profile Management specifications.

## Global Constraints

- **Color Harmony (60-30-10 Rule):** 60% surface/background (`theme.colorScheme.surface`), 30% structural containers (`outlineVariant`, card surfaces), 10% accent (`theme.colorScheme.primary`).
- **Inline Validation Rule:** Follow the `inline-input-validation` rule: All input errors and field constraints must appear directly inline beneath text fields in red (`#DC2626`); strictly no bottom SnackBars or floating toasts for form input validation.
- **Email Security via OTP:** If the teacher changes their email, a 6-digit OTP verification step must be successfully completed on the new email before the change is committed.
- **Strict Phone Format:** Strictly digits-only, max 11 digits, must start with `09` (`^09\d{9}$`).
- **Strict Facebook URL Format:** Must match a valid profile format (`^https?:\/\/(www\.)?(facebook\.com|fb\.me)\/[A-Za-z0-9._%+-]{3,}\/?$`).
- **Consultation Hours Ordering:** End time must strictly follow start time (at least 30 min duration), selected via day chips and time pickers instead of free-text typing.

## Review Focus

1. **Email OTP Verification Flow:** Changing email triggers OTP modal; if cancelled or invalid OTP entered, original email is kept intact.
2. **Phone Number Sanitization & Strict Validation:** Enforces Philippine mobile numbers (`09XXXXXXXXX`, digits only, no letters or dashes).
3. **Facebook Link Validation:** Enforces valid URLs with profile handles; prevents generic or broken links.
4. **Consultation Hours Chronological Ordering:** Start time must be before End time; prevents setting End Time earlier than Start Time.
5. **Immediate State Reflection:** After saving, in-memory `AuthRepository.instance.currentUser` and `LocalStorageService` cache update immediately, updating profile cards without re-login.

---

### Task 1: AuthRepository Complete Profile & Email OTP Methods

**Files:**
- Modify: `lib/data/repositories/auth_repository.dart`
- Test: `test/data/repositories/teacher_profile_update_test.dart`

- [ ] **Step 1: Write unit test for `updateTeacherCompleteProfile` and email OTP flow**
  - Verify payload updates across `users`, `teacher_profiles`, and `teacher_settings`.
  - Verify that local cache (`LocalStorageService` and `currentUser`) reflects updated profile.

- [ ] **Step 2: Implement `updateTeacherCompleteProfile` in `AuthRepository`**
  - Update `teacher_profiles` table (`first_name`, `last_name`, `middle_name`, `gender`, `birthday`).
  - Update `teacher_settings` table (`subject_specialization`, `consultation_hours`, `facebook_link`, `is_facebook_public`, `contact_number`, `is_phone_public`).
  - Implement email change logic: send OTP to new email address, verify OTP, then update `users` and auth credentials.

---

### Task 2: Create `ConsultationHoursPicker` Component

**Files:**
- Create: `lib/features/teacher/sub_features/profile_and_reports/widgets/consultation_hours_picker.dart`
- Test: `test/features/teacher/consultation_hours_picker_test.dart`

- [ ] **Step 1: Write widget test for `ConsultationHoursPicker`**
  - Test selecting days of the week (Monday–Sunday).
  - Test picking Start Time and End Time.
  - Test validation when End Time is earlier than Start Time.

- [ ] **Step 2: Implement `ConsultationHoursPicker`**
  - Render day selector chips: Mon, Tue, Wed, Thu, Fri, Sat, Sun.
  - Render Start Time and End Time selector buttons triggering `showTimePicker`.
  - Validate: `end > start` and duration >= 30 mins; display inline error if invalid.
  - Output structured string: e.g. `Mon, Wed, Fri • 03:00 PM - 05:00 PM`.

---

### Task 3: Create `EditTeacherProfileDialog` Widget

**Files:**
- Create: `lib/features/teacher/sub_features/profile_and_reports/widgets/edit_teacher_profile_dialog.dart`
- Modify: `lib/features/teacher/sub_features/profile_and_reports/widgets/teacher_profile_tab.dart`
- Test: `test/features/teacher/edit_teacher_profile_dialog_test.dart`

- [ ] **Step 1: Write widget test for `EditTeacherProfileDialog`**
  - Test pre-population of teacher data.
  - Test phone number input restricts to 11 digits starting with `09`.
  - Test Facebook URL regex validation.
  - Test email change opens OTP verification.

- [ ] **Step 2: Implement `EditTeacherProfileDialog`**
  - Section 1: Basic Information (First Name, Middle Name, Last Name, Gender, Birthday, Email with OTP badge).
  - Section 2: Professional Details (Subject Specialization, `ConsultationHoursPicker`).
  - Section 3: Contact & Privacy (11-digit phone number with Public/Private switch, Facebook link with Public/Private switch).
  - Inline error display adhering to `inline-input-validation` rule.

---

### Task 4: Connect to `TeacherProfileTab`

**Files:**
- Modify: `lib/features/teacher/sub_features/profile_and_reports/widgets/teacher_profile_tab.dart`
- Modify: `test/features/teacher/teacher_profile_tab_test.dart`

- [ ] **Step 1: Update Edit button in `TeacherProfileTab`**
  - Replace `Edit Profile (Next Update)` with `Edit Profile`.
  - Launch `EditTeacherProfileDialog.show(...)`.
  - Refresh `_loadTeacherData()` on save.

- [ ] **Step 2: Run targeted test and static analysis**
  - Run `flutter analyze lib/features/teacher/sub_features/profile_and_reports/widgets/teacher_profile_tab.dart`.
  - Run `flutter test test/features/teacher/teacher_profile_tab_test.dart`.
