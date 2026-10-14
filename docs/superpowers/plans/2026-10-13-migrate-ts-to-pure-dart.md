# Migration Plan: Transition from TypeScript Edge Functions to Pure Dart/Flutter

> **Goal:** Eliminate unnecessary and complex `.ts` Edge Functions from `supabase/functions/` and replace all backend logic with clean, organized, high-performance, and maintainable **100% Pure Dart/Flutter** services in `lib/`.

---

## 1. Executive Summary & Inventory

Kasulukuyang mayroong **12 Edge Function directories** sa `supabase/functions/`. Karamihan sa mga ito ay simpleng database CRUD o REST queries lamang na ipinasa sa TypeScript sa halip na gawin direkta sa Dart.

### Comprehensive Audit of Edge Functions:

| Edge Function (`.ts`) | Kasalukuyang Ginagawa | Bagong Pure Dart/Flutter Solusyon | Katayuan |
| :--- | :--- | :--- | :--- |
| **`approve-teacher`** | Wala nang gamit / Empty folder | Inalis ang lahat ng tawag. | **COMPLETED** |
| **`teacher-attendance`** | Nagse-save at nagfe-fetch ng attendance records sa Supabase | Inilipat sa direktang PostgREST queries sa `supabase_attendance_repository.dart`. | **COMPLETED** |
| **`teacher-classwork`** | Nagke-create at nag-e-edit ng activities/assignments | Inilipat sa direktang PostgREST at Storage sa `supabase_teacher_classwork_repository.dart`. | **COMPLETED** |
| **`update-student`** | Nag-a-update ng student info sa `student_profiles` | Diretso sa `SupabaseStudentRepository.updateStudentFull()` gamit ang Pure Dart. | **COMPLETED** |
| **`student-dashboard`** | Kumukuha ng student profile, enrollments, at classwork | Diretso sa `StudentDashboardRepository` via Dart relational queries + Drift SQLite. | **COMPLETED** |
| **`provision-student`** | Nag-e-enroll ng estudyante at gumagawa ng profile | Inilipat sa `SupabaseStudentRepository.enrollStudent()` sa purong Dart. | **COMPLETED** |
| **`first-login-otp`** | Nagpapadala at nagve-verify ng 6-digit OTP sa email | Inilipat sa `AuthRepository` sa purong Dart gamit ang secure random OTP generator. | **COMPLETED** |
| **`complete-first-login`** | Nagpapalit ng status sa `active` at nag-a-update ng password | Inilipat sa `AuthRepository.completeFirstLogin()` gamit ang Pure Dart client. | **COMPLETED** |
| **`admin-teacher`** | Nag-a-approve/reject o nagse-setup ng teacher profiles | Inilipat sa `AuthRepository.createTeacherDirectlyByAdmin()` sa Pure Dart. | **COMPLETED** |
| **`delete-firebase-user`** | Nagde-delete ng user sa Firebase | Direct Supabase user cleanup sa `AuthRepository.deleteTeacherRecord()` sa Pure Dart. | **COMPLETED** |
| **`send-email`** | Nagpapadala ng emails via third-party HTTP API | Gamitin ang direct HTTP REST API call (Resend / Brevo) o standard Dart package (`http` / `mailer`) direkta sa Dart `EmailService`. | Pure Dart Migration |
| **`first-login-otp`** | Nagpapadala at nagve-verify ng 6-digit OTP sa email | Ilipat sa `AuthRepository` gamit ang Firebase Auth built-in email verification o direct Dart OTP generator + `EmailService`. | Pure Dart Migration |
| **`complete-first-login`** | Nagpapalit ng status sa `active` at nag-a-update ng password | Ginagawa na sa Dart client via `FirebaseAuth.currentUser.updatePassword()` + `.from('user_profiles').update()`. | Pure Dart Migration |
| **`admin-teacher`** | Nag-a-approve/reject o nagse-setup ng teacher profiles | Direct PostgREST query sa `user_profiles` gamit ang Dart. | Pure Dart Migration |
| **`delete-firebase-user`** | Nagde-delete ng user sa Firebase | Direct Supabase soft-delete / archive flag sa Dart (`is_archived = true`). | Pure Dart Migration |
| **`_shared`** | Shared TypeScript validation helpers | Ilipat ang validation rules sa `lib/core/utils/validators.dart` sa Dart. | Pure Dart Migration |

---

## 2. Phase-by-Phase Execution Plan

### Phase 1: Pure Dart Classroom & Academic Features (Attendance, Classwork, Dashboard)
* **Target Files:**
  * `lib/data/repositories/supabase_attendance_repository.dart`
  * `lib/data/repositories/supabase_teacher_classwork_repository.dart`
  * `lib/data/repositories/student_dashboard_repository.dart`
* **Mga Hakbang:**
  1. Palitan ang `_client.functions.invoke('teacher-attendance')` ng direktang:
     ```dart
     await _client.from('attendance_records').upsert(...);
     ```
  2. Palitan ang `_client.functions.invoke('teacher-classwork')` ng direktang:
     ```dart
     await _client.from('classworks').insert(...);
     ```
  3. Palitan ang `_client.functions.invoke('student-dashboard')` ng direktang PostgREST relational query at Drift SQLite cache.
  4. **Resulta:** 0ms latency, walang serverless cold start, 100% purong Dart.

---

### Phase 2: Pure Dart Student Directory & Enrollment (`update-student`, `provision-student`)
* **Target Files:**
  * `lib/data/repositories/supabase_student_repository.dart`
* **Mga Hakbang:**
  1. I-rewrite ang `updateStudent()` para direktang mag-update sa `student_profiles` at `users` tables gamit ang `supabase_flutter`.
  2. I-rewrite ang `enrollStudent()` para direktang mag-insert sa `student_profiles` at `student_enrollments`.
  3. Alisin ang tawag sa `functions.invoke('update-student')` at `functions.invoke('provision-student')`.

---

### Phase 3: Pure Dart Email & Authentication Services (`send-email`, `first-login-otp`, `complete-first-login`)
* **Target Files:**
  * `lib/core/services/email_service.dart` *(Bagong Pure Dart Service)*
  * `lib/data/repositories/auth_repository.dart`
* **Mga Hakbang:**
  1. **Gumawa ng Pure Dart `EmailService`:**
     * Direkta itong tatawag sa email provider REST API (hal. Resend / SendGrid / Brevo) gamit ang simpleng `http.post` sa Dart, o standard SMTP via `mailer` package.
     * Hindi na kailangan ng hiwalay na `.ts` edge function para mag-send ng email!
  2. **Pure Dart OTP Flow:**
     * Bumuo ng secure 6-digit random code sa Dart.
     * I-save ang hashed OTP sa Supabase table (`otp_verifications`) na may 10-minute expiry.
     * Ipadala ang OTP gamit ang Dart `EmailService`.
     * I-verify ang code nang direkta sa Dart.
  3. **Complete First Login:**
     * Ipatupad ang password update direkta sa `FirebaseAuth.currentUser.updatePassword()` at i-update ang `user_profiles` status sa `'active'`.

---

### Phase 4: Pagbura at Paglilinis ng `supabase/functions/`
* **Mga Hakbang:**
  1. Burahin ang mga luma at kalat na `.ts` directories:
     * `supabase/functions/approve-teacher`
     * `supabase/functions/teacher-attendance`
     * `supabase/functions/teacher-classwork`
     * `supabase/functions/update-student`
     * `supabase/functions/student-dashboard`
     * `supabase/functions/provision-student`
     * `supabase/functions/send-email`
     * `supabase/functions/first-login-otp`
     * `supabase/functions/complete-first-login`
     * `supabase/functions/admin-teacher`
     * `supabase/functions/delete-firebase-user`
     * `supabase/functions/_shared`
  2. Linisin ang anumang naiwang unused imports o configs.

---

## 3. Bakit Mas Maganda ang Pure Dart/Flutter?

1. **Isang Wika Lang (Unified Tech Stack):**
   * Lahat ng logic, validation, data models, at services ay nasa **Dart** (`.dart`). Walang context-switching sa pagitan ng Dart at TypeScript.
2. **Mas Mabilis (Zero Cold Starts):**
   * Ang Edge functions ay may 1-3 seconds na cold start kapag matagal hindi ginamit. Ang direct Dart PostgREST queries ay instant (10-50ms) at lalong bumibilis (0ms) dahil sa ating Drift SQLite local cache.
3. **Mas Madaling I-debug:**
   * Makikita agad sa Flutter debugger / console ang anumang error nang hindi na kailangang mag-check ng Supabase dashboard logs.
4. **Mas Malinis ang Project Structure:**
   * Mawawala ang 12 folders ng `.ts` sa file tree ng Android Studio. Lahat ng logic ay naka-organisa sa `lib/core/services/` at `lib/data/repositories/`.

---

## 4. Verification & Safety Gate

Bago burahin ang bawat `.ts` function, susundin ang protocol na ito:
1. **Side-by-side Test:** Tiyaking gumagana ang bagong Dart implementation (parehong inputs at outputs).
2. **Offline Fallback Check:** Tiyaking may fallback sa Drift SQLite at MockDatabase kapag walang internet.
3. **No Breaking Changes:** Hindi magbabago ang UI o data flow—pareho pa rin ang mararanasan ng guro, mag-aaral, at magulang.
