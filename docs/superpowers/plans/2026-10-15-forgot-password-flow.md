# Forgot Password Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a production-ready, full "Forgot Password" workflow with pure Dart OTP verification, shared password complexity validation, and desktop split-screen/mobile card UI alignment for Admin, Teacher, and Student roles without touching files assigned to other agents.

**Architecture:** Centralize password complexity validation into `AppValidators` and create a reusable `PasswordRequirementsChecklist` widget; enhance `AuthRepository` with user lookup by email, pure Dart OTP dispatch/verification via `EmailService`, and secure password updating; rebuild `ForgotPasswordScreen` with desktop split-screen / mobile card UI matching `LoginScreen` and `FirstLoginScreen`; extract or mirror `PasswordOtpDialog` for robust OTP input, countdown, and resend timers.

**Tech Stack:** Flutter / Dart, Supabase Flutter, Firebase Auth, `EmailService` (Resend/Brevo REST API + fallback logger), `EmailVerificationService`.

**Spec:** USER_REQUEST specification for Forgot Password Flow with OTP Verification & UI Alignment for Admin, Teacher, and Student Roles.

## Global Constraints

- Zero file conflict with Copilot: Do NOT touch `android/`, `lib/data/repositories/student_dashboard_repository.dart`, `lib/models/student_dashboard_models.dart`, and `lib/features/student/`.
- Do NOT create git worktrees or run `flutter clean`.
- Strict existing Supabase schema: Only use `public.users`, `public.admin_profiles`, `public.teacher_profiles`, `public.student_profiles`, `public.student_settings`, `public.teacher_settings`. Do NOT alter schema.
- Parent role exclusion: Parent accounts (`@classrealm.com`) do not use email OTP. Show the helpful recovery modal advising them to ask their teacher.

## Review Focus

1. Parent domain email (`@classrealm.com`) entered in Forgot Password screen: must immediately show Parent Recovery dialog and abort OTP dispatch.
2. Non-existent email: must show a friendly error without attempting to send OTP.
3. Weak password or mismatched confirmation: submit button remains disabled or blocks OTP request before form is valid.
4. Security gate: database/auth password update must NEVER execute before OTP verification succeeds.
5. Desktop vs. Mobile layout: Desktop displays two-column split screen (school photo on left, elevated form card on right); Mobile displays single-column scrollable branding header + form card.

---

### Task 1: Centralize Password Complexity Validation in `lib/core/utils/validators.dart`

**Files:**
- Modify: `lib/core/utils/validators.dart`
- Test: `test/core/utils/validators_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class PasswordValidationResult {
    final bool hasMinLength;
    final bool hasUpper;
    final bool hasLower;
    final bool hasNumber;
    final bool passwordsMatch;
    bool get isValid => hasMinLength && hasUpper && hasLower && hasNumber && passwordsMatch;
  }
  ```
- Methods in `AppValidators`:
  - `static bool hasMinLength(String password, {int min = 8})`
  - `static bool hasUppercase(String password)`
  - `static bool hasLowercase(String password)`
  - `static bool hasNumber(String password)`
  - `static bool passwordsMatch(String password, String confirm)`
  - `static PasswordValidationResult validatePasswordComplexity({required String password, required String confirmPassword})`

- [ ] **Step 1: Write unit tests for password complexity in `test/core/utils/validators_test.dart`**
- [ ] **Step 2: Run test to verify it fails initially or tests the new methods**
- [ ] **Step 3: Implement `PasswordValidationResult` and helper methods in `lib/core/utils/validators.dart`**
- [ ] **Step 4: Run unit tests to verify they pass**

---

### Task 2: Create Reusable `PasswordRequirementsChecklist` Widget

**Files:**
- Create: `lib/widgets/common/password_requirements_checklist.dart`
- Modify: `lib/features/auth/screens/first_login_screen.dart` (optional refactor to use shared checklist widget)

**Interfaces:**
- Produces:
  ```dart
  class PasswordRequirementsChecklist extends StatelessWidget {
    final bool hasMinLength;
    final bool hasUpper;
    final bool hasLower;
    final bool hasNumber;
    const PasswordRequirementsChecklist({
      super.key,
      required this.hasMinLength,
      required this.hasUpper,
      required this.hasLower,
      required this.hasNumber,
    });
  }
  ```

- [ ] **Step 1: Implement `PasswordRequirementsChecklist` widget with clean design-system styling (subtle background, check/circle icons, green/grey states)**
- [ ] **Step 2: Connect with `AppValidators` for clean reusability**

---

### Task 3: Enhance `AuthRepository` with Forgot Password Flow

**Files:**
- Modify: `lib/data/repositories/auth_repository.dart`
- Test: `test/data/repositories/auth_repository_forgot_password_test.dart`

**Interfaces:**
- Produces:
  - `Future<custom.UserModel?> getUserByEmail(String email)`
  - `Future<Map<String, dynamic>> sendForgotPasswordOtp({required String email, String? recipientName})`
  - `Future<FirstLoginOtpVerification> verifyForgotPasswordOtp(String code)`
  - `Future<String?> updateForgottenPassword({required String email, required String newPassword})`

- [ ] **Step 1: Write test verifying OTP generation, verification, and rate limiting in `test/data/repositories/auth_repository_forgot_password_test.dart`**
- [ ] **Step 2: Implement `getUserByEmail`, `sendForgotPasswordOtp`, `verifyForgotPasswordOtp`, and `updateForgottenPassword` in `lib/data/repositories/auth_repository.dart`**
- [ ] **Step 3: Ensure strict security: password is never updated without verified OTP**

---

### Task 4: Rebuild `ForgotPasswordScreen` UI & Integration

**Files:**
- Modify: `lib/features/auth/screens/forgot_password_screen.dart`
- Test: `test/features/auth/forgot_password_screen_test.dart`

**Interfaces:**
- Consumes:
  - `AppValidators`
  - `PasswordRequirementsChecklist`
  - `AuthRepository.instance.getUserByEmail`
  - `AuthRepository.instance.sendForgotPasswordOtp`
  - `AuthRepository.instance.verifyForgotPasswordOtp`
  - `AuthRepository.instance.updateForgottenPassword`
  - `ParentCredentialHelper.isParentDomain`

- [ ] **Step 1: Build the responsive layout in `forgot_password_screen.dart`:**
  - Desktop (`width >= 900`): Two-column split-screen matching `LoginScreen` (school photo with dark gradient overlay on left, elevated form card on right).
  - Mobile (`width < 900`): Scrollable header with school logo & branding + elevated form card.
- [ ] **Step 2: Add form fields:**
  - Email input with `AppValidators.validateEmail` and real-time formatting.
  - New Password input with show/hide toggle and live `PasswordRequirementsChecklist`.
  - Confirm Password input with show/hide toggle and mismatch indicator.
- [ ] **Step 3: Integrate Step 1 (Request OTP):**
  - Check `ParentCredentialHelper.isParentDomain(email)`. If parent domain, show Parent Recovery Dialog.
  - Query `AuthRepository.instance.getUserByEmail(email)`. If null or parent, show error.
  - Dispatch OTP with `AuthRepository.instance.sendForgotPasswordOtp`.
- [ ] **Step 4: Integrate Step 2 (OTP Dialog):**
  - Present `_PasswordOtpDialog` (6-digit PIN boxes, resend cooldown timer, 10-minute expiry countdown, max 5 attempts lockout).
- [ ] **Step 5: Integrate Step 3 (Finalize Update):**
  - Upon valid OTP, call `AuthRepository.instance.updateForgottenPassword`.
  - On success, show success modal/snackbar and navigate to `AppRoutes.login`.

---

### Task 5: Verification & End-to-End Review

**Files:**
- Verification: `lib/core/utils/validators.dart`, `lib/widgets/common/password_requirements_checklist.dart`, `lib/data/repositories/auth_repository.dart`, `lib/features/auth/screens/forgot_password_screen.dart`

- [ ] **Step 1: Verify code cleanliness, types, and null safety**
- [ ] **Step 2: Confirm zero conflicts with parallel agent files**
- [ ] **Step 3: Verify parent authentication and recovery flows are completely intact**
