# In-App Change Password Feature & Unified OTP Security Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a secure, role-aware In-App Change Password feature across Admin, Teacher, Student, and Parent portals with standardized 5-minute OTP lifecycle, distinct email templates, and strict inline validation following the 60-30-10 design rule.

**Architecture:** A unified Flutter modal (`ChangePasswordModal`) dynamically branches on user role: Parent accounts re-authenticate via Firebase credentials without OTP; email-holding accounts (Admin, Teacher, Student) verify current password and complete 2FA verification using `PasswordOtpDialog`. All OTP actions across the system (First Login, Forgot Password, Change Password) utilize dedicated email templates in `EmailService` and enforce an exact 5-minute (300s) expiration and lockout policy.

**Tech Stack:** Pure Dart & Flutter (`lib/`), Firebase Authentication (`firebase_auth`), Supabase Database (`supabase_flutter`), Lucide Icons (`lucide_icons_flutter`), Google Fonts Inter.

**Spec:** [docs/superpowers/specs/2026-11-09-change-password-feature-design.md](file:///c:/Users/rexsa/AndroidStudioProjects\class_realm01\docs\superpowers\specs\2026-11-09-change-password-feature-design.md)

---

## Global Constraints

- **Pure Flutter/Dart Only:** Zero TypeScript (`.ts`), Node.js, or external web scripts. All code resides in `lib/` and tests in `test/`.
- **60-30-10 Color System:** 60% dominant base (`#FFFFFF` light / `#111827` dark), 30% structural hierarchy (`#E2E8F0` borders, `#475569` text, `#F1F5F9` surfaces), 10% interactive accent (`#487898` / `#2563EB`, `#16A34A` success, `#DC2626` error).
- **Inline Input Validation (Zero SnackBars):** All form errors must display directly beneath the relevant input with a `#DC2626` red border. Bottom SnackBars or floating toasts for validation errors are strictly prohibited.
- **Unified 5-Minute Timer:** All OTP expiration timers, backend tokens, and progressive lockouts are set to exactly 300 seconds (5 minutes). Email footer text strictly reads `"This code will expire in 5 minutes."`
- **Targeted Fast Testing:** Tests must be targeted single files using `flutter test <target_file>` or fast static analysis `flutter analyze <modified_file>`.

---

## Review Focus

1. **Parent Email Trap:** Ensure Parent accounts (@classrealm.com) never trigger OTP generation or network email dispatch; they must verify via `reauthenticateWithCredential` only.
2. **Same Password Rejection:** Entering a New Password that matches the Current Password must immediately display an inline warning: *"New password must be different from your current password."*
3. **Template Copy Bleed:** Ensure Forgot Password emails never contain first-login phrases (*"To complete your first login"*), and each flow uses its own distinct header, subject, and body text.
4. **Brute Force Lockout:** Entering 5 incorrect OTPs or current passwords must trigger the 300-second lockout timer in `LocalStorageService` and lock the interface.
5. **State Cleanup on Dismissal:** Canceling or dismissing the modal midway must safely clean up controllers, timers, and focus nodes without memory leaks or dangling background tasks.

---

## Task Breakdown

### Task 1: Separate Semantic Email Templates & Unify Expiry in `EmailService`

**Files:**
- Modify: `lib/core/services/email_service.dart`
- Test: `test/core/services/email_service_templates_test.dart`

**Interfaces:**
- Consumes: `EmailService.instance.sendEmail(to, subject, html)`
- Produces: 
  - `sendFirstLoginOtpEmail({required String recipientEmail, required String recipientName, required String otpCode}) -> Future<bool>`
  - `sendForgotPasswordOtpEmail({required String recipientEmail, required String recipientName, required String otpCode}) -> Future<bool>`
  - `sendChangePasswordOtpEmail({required String recipientEmail, required String recipientName, required String otpCode}) -> Future<bool>`

- [ ] **Step 1: Write targeted unit tests for `EmailService` templates**

Create `test/core/services/email_service_templates_test.dart` testing that each method produces HTML containing its specific subject, heading, body text, and the uniform `"This code will expire in 5 minutes."` footer without first-login bleed.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/email_service_templates_test.dart`  
Expected: Compilation failure or missing methods `sendForgotPasswordOtpEmail` / `sendChangePasswordOtpEmail`.

- [ ] **Step 3: Implement the three distinct email template methods in `lib/core/services/email_service.dart`**

Add `sendFirstLoginOtpEmail`, `sendForgotPasswordOtpEmail`, and `sendChangePasswordOtpEmail`. Update `sendPasswordChangeOtpEmail` as a deprecated redirect or replace it cleanly. Ensure all three methods include the 5-minute footer and their respective semantic text.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/email_service_templates_test.dart`  
Expected: All tests PASS.

- [ ] **Step 5: Run static analysis and commit**

Run: `flutter analyze lib/core/services/email_service.dart`  
Commit:
```bash
git add lib/core/services/email_service.dart test/core/services/email_service_templates_test.dart
git commit -m "feat(auth): add distinct semantic OTP email templates with unified 5-minute expiry"
```

---

### Task 2: Implement Change Password Logic in `AuthRepository` & Unify `PasswordOtpDialog`

**Files:**
- Modify: `lib/data/repositories/auth_repository.dart`
- Modify: `lib/shared/widgets/modals/password_otp_dialog.dart`
- Test: `test/data/repositories/auth_repository_change_password_test.dart`

**Interfaces:**
- Consumes: `EmailService`, Firebase Auth SDK, Supabase `password_reset_otps` table
- Produces:
  - `AuthRepository.instance.sendChangePasswordOtp({required String email, required String recipientName}) -> Future<Map<String, dynamic>>`
  - `AuthRepository.instance.verifyAndChangePassword({required String email, required String currentPassword, required String newPassword, required String otpCode}) -> Future<String?>`
  - `AuthRepository.instance.changeParentPassword({required UserModel parent, required String currentPassword, required String newPassword}) -> Future<Map<String, String>?>`

- [ ] **Step 1: Write unit tests for Change Password repository operations**

Create `test/data/repositories/auth_repository_change_password_test.dart` testing:
1. `sendChangePasswordOtp` dispatches with `feature: 'change_password'` and returns `expiresIn: 300`.
2. Rejection when new password equals current password.
3. Verification flow logic and failure on wrong OTP.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/repositories/auth_repository_change_password_test.dart`  
Expected: Missing methods on `AuthRepository`.

- [ ] **Step 3: Implement repository methods and unify `PasswordOtpDialog` defaults**

1. In `lib/data/repositories/auth_repository.dart`:
   - Point `sendFirstLoginOtp` to `EmailService.instance.sendFirstLoginOtpEmail`.
   - Point `sendForgotPasswordOtp` to `EmailService.instance.sendForgotPasswordOtpEmail`.
   - Implement `sendChangePasswordOtp` calling `EmailService.instance.sendChangePasswordOtpEmail`.
   - Implement `verifyAndChangePassword` verifying the OTP challenge, re-authenticating with current password, updating Firebase Auth via `user.updatePassword(newPassword)` (with Service Account fallback), and clearing the challenge.
   - Implement/expose `changeParentPassword` wrapping `reauthenticateWithCredential` and direct update.
2. In `lib/shared/widgets/modals/password_otp_dialog.dart`:
   - Set default field declaration `int _inputCountdown = 300;` (replacing the legacy 600s).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/repositories/auth_repository_change_password_test.dart`  
Expected: All tests PASS.

- [ ] **Step 5: Run static analysis and commit**

Run: `flutter analyze lib/data/repositories/auth_repository.dart lib/shared/widgets/modals/password_otp_dialog.dart`  
Commit:
```bash
git add lib/data/repositories/auth_repository.dart lib/shared/widgets/modals/password_otp_dialog.dart test/data/repositories/auth_repository_change_password_test.dart
git commit -m "feat(auth): implement change password repository methods and unify OTP countdown to 300s"
```

---

### Task 3: Build Reusable `ChangePasswordModal` with Strict Inline Validation

**Files:**
- Create: `lib/shared/widgets/modals/change_password_modal.dart`
- Test: `test/shared/widgets/modals/change_password_modal_test.dart`

**Interfaces:**
- Consumes: `UserModel`, `AuthRepository`, `AppValidators`, `PasswordOtpDialog`, `AppTheme`
- Produces: `ChangePasswordModal.show(BuildContext context, {required UserModel user}) -> Future<bool?>`

- [ ] **Step 1: Write widget test for `ChangePasswordModal`**

Create `test/shared/widgets/modals/change_password_modal_test.dart` testing:
1. Renders `Current Password`, `New Password`, and `Confirm New Password` fields.
2. Live password checklist turns items green as complexity requirements are satisfied.
3. Shows inline error beneath New Password when it matches Current Password.
4. Shows inline red border when Current Password is wrong without showing a SnackBar.
5. Directly executes `changeParentPassword` for `UserRole.parent`.
6. Launches `PasswordOtpDialog` for `UserRole.student`, `teacher`, `admin`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/widgets/modals/change_password_modal_test.dart`  
Expected: `ChangePasswordModal` does not exist.

- [ ] **Step 3: Implement `ChangePasswordModal` in `lib/shared/widgets/modals/change_password_modal.dart`**

Follow the 60-30-10 color specification and strict inline validation:
- Input fields with `AuthResponsiveScaffold.inputDecoration` style, show/hide eye icon toggles.
- Real-time `AppValidators.validatePasswordComplexity` listener.
- Dynamic button: "Update Password" for Parent; "Continue to Verification" for Email accounts.
- Inline error display widgets directly under each field.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/widgets/modals/change_password_modal_test.dart`  
Expected: All tests PASS.

- [ ] **Step 5: Run static analysis and commit**

Run: `flutter analyze lib/shared/widgets/modals/change_password_modal.dart`  
Commit:
```bash
git add lib/shared/widgets/modals/change_password_modal.dart test/shared/widgets/modals/change_password_modal_test.dart
git commit -m "feat(ui): create ChangePasswordModal with 60-30-10 styling and inline validation"
```

---

### Task 4: Integrate `ChangePasswordModal` into Portal Settings & Admin Profile

**Files:**
- Modify: `lib/shared/widgets/portal_settings_content.dart`
- Modify: `lib/features/admin/sub_features/profile/widgets/admin_profile_tab.dart`
- Test: `test/features/settings/portal_settings_change_password_test.dart`

**Interfaces:**
- Consumes: `ChangePasswordModal`, `AuthRepository.instance.currentUser`
- Produces: Functional Change Password trigger for Teacher, Student, Parent, and Admin.

- [ ] **Step 1: Write widget tests for portal settings trigger**

Create `test/features/settings/portal_settings_change_password_test.dart` testing that tapping "Change Password" in `PortalSettingsContent` and `AdminProfileTab` displays the `ChangePasswordModal`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/settings/portal_settings_change_password_test.dart`  
Expected: Currently shows `UpcomingFeatureDialog` instead of `ChangePasswordModal`.

- [ ] **Step 3: Wire `ChangePasswordModal` into `PortalSettingsContent` and `AdminProfileTab`**

1. In `lib/shared/widgets/portal_settings_content.dart`:
   - Replace `AppModals.showUpcomingFeatureDialog(...)` with `ChangePasswordModal.show(context, user: currentUser)`.
   - Remove the `_buildNextUpdateBadge(theme)` badge from the Change Password `ListTile`.
2. In `lib/features/admin/sub_features/profile/widgets/admin_profile_tab.dart`:
   - Add a "Change Password" action button in the profile header/card that invokes `ChangePasswordModal.show(context, user: user)`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/settings/portal_settings_change_password_test.dart`  
Expected: All tests PASS.

- [ ] **Step 5: Run static analysis and commit**

Run: `flutter analyze lib/shared/widgets/portal_settings_content.dart lib/features/admin/sub_features/profile/widgets/admin_profile_tab.dart`  
Commit:
```bash
git add lib/shared/widgets/portal_settings_content.dart lib/features/admin/sub_features/profile/widgets/admin_profile_tab.dart test/features/settings/portal_settings_change_password_test.dart
git commit -m "feat(settings): connect ChangePasswordModal to portal settings and admin profile"
```

---

### Task 5: Final End-to-End Regression & Static Analysis Verification

**Files:**
- Review: `lib/core/services/email_service.dart`
- Review: `lib/data/repositories/auth_repository.dart`
- Review: `lib/shared/widgets/modals/change_password_modal.dart`
- Review: `lib/shared/widgets/modals/password_otp_dialog.dart`
- Review: `lib/shared/widgets/portal_settings_content.dart`
- Review: `lib/features/admin/sub_features/profile/widgets/admin_profile_tab.dart`

- [ ] **Step 1: Run all targeted tests**

Run:
```bash
flutter test test/core/services/email_service_templates_test.dart
flutter test test/data/repositories/auth_repository_change_password_test.dart
flutter test test/shared/widgets/modals/change_password_modal_test.dart
flutter test test/features/settings/portal_settings_change_password_test.dart
```
Expected: All targeted suites PASS.

- [ ] **Step 2: Run targeted static analysis on all touched files**

Run:
```bash
flutter analyze lib/core/services/email_service.dart lib/data/repositories/auth_repository.dart lib/shared/widgets/modals/change_password_modal.dart lib/shared/widgets/modals/password_otp_dialog.dart lib/shared/widgets/portal_settings_content.dart lib/features/admin/sub_features/profile/widgets/admin_profile_tab.dart
```
Expected: "No issues found!".

- [ ] **Step 3: Update knowledge graph**

Run: `graphify update .` (per `RULE[graphify]`).

- [ ] **Step 4: Final commit**

Commit:
```bash
git commit --allow-empty -m "chore: complete in-app change password implementation and test suite verification"
```
