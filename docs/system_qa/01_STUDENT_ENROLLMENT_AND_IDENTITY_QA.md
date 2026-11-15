# ClassRealm • Student Enrollment, Identity Management & Bulk Upload Q&A Guide

**Document ID:** `CR-QA-01`  
**Primary Source Modules:**  
- `lib/features/teacher/sub_features/class_management/widgets/unified_enroll_student_dialog.dart`  
- `lib/data/repositories/supabase_student_repository.dart`  
- `lib/core/utils/excel_template_generator.dart`  
- Supabase Tables: `users`, `student_profiles`, `student_enrollments`, `subject_offerings`  
**Visual Flowchart Reference:** [student_enrollment_logic_flowchart.png](file:///c:/Users/Admin/AndroidStudioProjects/class_realm01/student_enrollment_logic_flowchart.png)

---

## Architecture Overview: The 4-Status Enrollment Pipeline

When a teacher uploads a student spreadsheet (`.xlsx` or `.csv`) into ClassRealm, the system executes a 3-tier validation and reconciliation pipeline:

1. **Client-Side Syntax & Format Validation:** Evaluates row-level fields in memory (LRN length, strict YYYY-MM-DD date regex, age boundary between 10–50 years, middle initial formatting, and required fields).
2. **Supabase Cloud Reconciliation:** Fires parallel non-blocking queries to `student_profiles` (by LRN) and `users` (by Email) to detect existing records school-wide without creating redundant accounts.
3. **Identity Verification & Status Sorting:** Sorts every student into one of four distinct status categories:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                4 ENROLLMENT STATUS BOXES                               │
├────────────────────┬────────────────────┬────────────────────┬────────────────────────┤
│   BOX 1: ISSUES    │ BOX 2: NEW STUDENT │  BOX 3: EXISTING   │    BOX 4: ENROLLED     │
│       (Red)        │      (Green)       │       (Blue)       │         (Grey)         │
├────────────────────┼────────────────────┼────────────────────┼────────────────────────┤
│ Syntax errors,     │ Brand new learner. │ Registered in the  │ Already enrolled in    │
│ duplicate emails,  │ Creates Supabase   │ school under other │ THIS specific subject/ │
│ invalid dates, or  │ Auth user, profile,│ classes. Links to  │ section. Safely        │
│ LRN Name Mismatch. │ temp password, &   │ section without    │ skipped without        │
│ Blocks the batch.  │ welcome email.     │ new credentials.   │ duplicate records.     │
└────────────────────┴────────────────────┴────────────────────┴────────────────────────┘
```

---

## Section 1: Technical & Panelist Questions

### Q1: How does ClassRealm prevent account hijacking when an uploaded LRN already exists in the database?

- **Direct Summary:** The system validates that the first name and last name provided in the spreadsheet exactly match the pre-registered identity linked to that LRN in `student_profiles`, blocking the upload if a name mismatch is detected.
- **Technical Walkthrough:**
  1. **Ano (What):** Implemented in `_UnifiedEnrollStudentDialogState` within `lib/features/teacher/sub_features/class_management/widgets/unified_enroll_student_dialog.dart` (lines 1570–1605).
  2. **Paano (How):** When an LRN query against `student_profiles` returns an existing record, the engine normalizes both the database strings and the uploaded spreadsheet strings by trimming whitespace, collapsing multiple consecutive spaces, and converting to lowercase:
     ```dart
     final dbFirst = (existingProfile['first_name'] ?? '').toString().trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
     final dbLast = (existingProfile['last_name'] ?? '').toString().trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
     final uploadFirst = s.firstName.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
     final uploadLast = s.lastName.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
     ```
     If `dbFirst != uploadFirst || dbLast != uploadLast`, the record is immediately flagged as an `_InvalidStudentRow` with the reason:
     `'Registered to "$dbFullName" (name mismatch: "${s.firstName} ${s.lastName}").'`
  3. **Bakit (Why):** In the Philippine educational system (DepEd), an LRN is permanently bound to a single learner. If a teacher inadvertently enters Student A's LRN on Student B's row, allowing the import would corrupt academic records, tie Student B's grades to Student A, and violate student data privacy (Republic Act 10173 - Data Privacy Act).
- **Edge Cases / Fallback:** If a student legitimately changed their legal name, the school administrator or registered teacher must update the student profile through the Master Directory (`EditStudentDialog`), after which spreadsheet uploads matching the updated name will succeed.

---

### Q2: Why does ClassRealm enforce an "All-or-Nothing" atomic upload policy when issues are found in a spreadsheet?

- **Direct Summary:** If `Issues > 0`, the system disables the commit button and blocks the entire batch to guarantee database consistency and prevent partial enrollments that are difficult for teachers to reconcile.
- **Technical Walkthrough:**
  1. **Ano (What):** Governed by the dialog state variables `invalidRows.isNotEmpty` and UI execution gates in `unified_enroll_student_dialog.dart`.
  2. **Paano (How):** When any row fails syntax validation (e.g. invalid date `2009-14-10`) or database checks (e.g. email conflict), it is appended to `invalidRows`. The dialog swaps the action button from `"Enroll Eligible Students"` to `"Upload Fixed File"` and renders a red summary card outlining the exact row numbers and errors.
  3. **Bakit (Why):** If a system allowed partial uploads (e.g. 15 valid students enrolled, 5 failed), the teacher would have to manually edit the spreadsheet, delete the 15 already-enrolled students, and re-upload only the 5 corrected rows. Inexperienced users often re-upload the entire file, which causes confusion and redundant API load. The all-or-nothing policy forces clean data entry before any database mutations occur.
- **Edge Cases / Fallback:** Teachers can click `"Upload Fixed File"` to instantly replace the file in memory without closing the dialog or re-selecting the Grade Level, Subject, and Section dropdowns.

---

### Q3: How are database queries optimized during bulk import so the application does not hang or hit Supabase rate limits?

- **Direct Summary:** ClassRealm bundles all candidate records into vectorized `inFilter` queries executed concurrently via `Future.wait`, reducing what would be hundreds of HTTP requests down to just two parallel database queries.
- **Technical Walkthrough:**
  1. **Ano (What):** Located in `unified_enroll_student_dialog.dart` (lines 1437–1465).
  2. **Paano (How):** Instead of executing an `await client.from(...).select()` query per spreadsheet row, the engine maps all candidate LRNs and emails into lists and issues parallel queries:
     ```dart
     final parallelResults = await Future.wait<List<dynamic>>([
       client.from('student_profiles').select('student_id, lrn, first_name, last_name').inFilter('lrn', cleanLrns),
       client.from('users').select('id, email, role').inFilter('email', cleanEmails),
       client.from('student_enrollments').select('student_profiles!inner(gender)')
             .eq('subject_offering_id', _selectedOfferingId!)
             .ilike('status', 'enrolled'),
     ]);
     ```
     In-memory lookup maps (`profileMap` and `userEmailMap`) are then constructed in $O(N)$ time.
  3. **Bakit (Why):** For a class of 50 students, individual queries would generate $50 \times 3 = 150$ network requests. If connection latency is 100ms, that would result in a 15-second freeze. Vectorized parallel querying executes in approximately 300ms total.
- **Edge Cases / Fallback:** If network disconnection occurs during `Future.wait`, the error is caught gracefully, an `AppModals.showErrorDialog` is shown, and the UI unlocks without crashing or leaving half-written records.

---

### Q4: How does ClassRealm handle cross-subject enrollment for Senior High School students (Grades 11–12) who have different teachers for different subjects?

- **Direct Summary:** Existing students are linked to new subjects via the junction table `student_enrollments` without creating duplicate authentication credentials or altering their existing passwords.
- **Technical Walkthrough:**
  1. **Ano (What):** Handled by the **"Existing"** status classification and `SupabaseStudentRepository.enrollExistingStudentInOffering`.
  2. **Paano (How):**
     - When Teacher A (e.g. Oral Communication) uploads a student, the student is in Box 2 (**New Students**), generating a record in `auth.users`, `student_profiles`, and a link in `student_enrollments`.
     - When Teacher B (e.g. General Mathematics) later uploads the same student, the system locates the student's LRN, verifies the name, checks that the student is NOT yet in Teacher B's `subject_offering_id`, and categorizes them into Box 3 (**Existing**).
     - Upon submission, only an `INSERT` into `student_enrollments` is executed:
       ```sql
       INSERT INTO student_enrollments (student_id, subject_offering_id, status)
       VALUES (existing_student_id, target_offering_id, 'enrolled');
       ```
  3. **Bakit (Why):** Senior High students take 8–9 distinct subjects per semester under different faculty members. A single unified account preserves student grades, attendance, and credentials under one identity.
- **Edge Cases / Fallback:** If the student was previously enrolled but marked `archived` in that class, the system prevents duplicate enrollment and directs the teacher to use the `"Restore"` action in the Student Management directory.

---

### Q5: How is section gender balance enforced during bulk enrollment?

- **Direct Summary:** The engine tracks current section counts by gender in real-time and rejects any candidate rows that would exceed the hard ceiling of 50 males or 50 females per section.
- **Technical Walkthrough:**
  1. **Ano (What):** Governed by section capacity limiters in `unified_enroll_student_dialog.dart` (lines 1501–1509 and 1537–1565).
  2. **Paano (How):**
     - The system queries all currently active enrollments for the target `subject_offering_id`:
       ```dart
       for (final item in currentSectionStudents) {
         final g = profile?['gender']?.toString().toLowerCase();
         if (g == 'male') currentMaleEnrolled++;
         if (g == 'female') currentFemaleEnrolled++;
       }
       ```
     - As candidate rows are processed, `currentMaleEnrolled` or `currentFemaleEnrolled` is incremented. If count exceeds 50, subsequent rows of that gender are moved to Box 1 (**Issues**) with the message:
       `'Capacity exceeded. Max 50 per gender. (Found: Male (51)).'`
  3. **Bakit (Why):** DepEd guidelines establish standard classroom sizing to ensure manageable teacher-to-student ratios and equitable facility utilization.
- **Edge Cases / Fallback:** If capacity is exceeded, the teacher can split the excess students into another section (e.g. Section 2) using the section dropdown selector in the dialog.

---

## Section 2: User & Stakeholder Questions

### Q6: What should a teacher do when a student's name is in ALL CAPS or mixed casing in the Excel file?

- **Direct Summary:** Teachers do not need to manually fix casing because ClassRealm automatically sanitizes and formats all student names into standard Title Case (e.g. `"DEMIAR, SHIELA MAE"` becomes `"Demiar, Shiela Mae"`).
- **Technical Walkthrough:**
  - **What happens:** In `_UnifiedEnrollStudentDialogState._toTitleCase()`, the system takes the raw strings from the Excel columns, breaks them into word tokens, and capitalizes only the initial character of each word while lowercasing the rest.
  - **Comparison Safety:** When verifying existing records against the database, name comparison is completely case-insensitive (`.toLowerCase()`), ensuring that `"DEMIAR"` matches `"Demiar"`.
  - **Database Persistence:** The name saved into `student_profiles` is clean, professional Title Case, ensuring uniform appearance on report cards, attendance sheets, and certificates.
- **Edge Cases / Fallback:** Compound surnames with hyphens (e.g. `"Dela-Cruz"`) or suffixes (e.g. `"Jr."`, `"III"`) preserve their casing rules.

---

### Q7: Why did Row 11 show an LRN error in our first upload, but disappeared from Issues and moved to "Existing: 1" in the second upload?

- **Direct Summary:** In the first upload, the LRN was already registered in the school database under Shiela Mae Demiar, but the row was flagged because of a name discrepancy or an older validation rule; once the name in the spreadsheet was correctly specified as `"DEMIAR, SHIELA MAE"`, the system confirmed identity alignment and moved the record to "Existing".
- **Technical Walkthrough:**
  - **First Upload:** The system detected LRN `109823150101` in the database. Because of a name mismatch against the registered profile, it was classified into Box 1 (**Issues**).
  - **Second Upload:** The teacher corrected the row in the spreadsheet. The system queried the database, normalized both names, and verified:
    `"Demiar, Shiela Mae" == "Demiar, Shiela Mae"`
  - **Resolution:** Having satisfied the identity verification check, the student was recognized as an existing learner who merely needs to be enrolled in this new subject. Box 1 dropped by 1, and Box 3 (**Existing**) incremented from 0 to 1.
- **Edge Cases / Fallback:** If the teacher accidentally uploaded the student to the wrong section, they can un-enroll or archive the student anytime from the Student Directory table.

---

### Q8: What happens if an Excel file has an invalid birthday format like `2009-14-10`?

- **Direct Summary:** The parser detects that month 14 is mathematically impossible, flags the row in Box 1 (Issues), and instructs the user to use the strict `YYYY-MM-DD` format.
- **Technical Walkthrough:**
  - In `_parseBirthday()`, the system parses dates using `DateTime.tryParse()`. In a strict `YYYY-MM-DD` format, the second token is the month (01–12) and the third is the day (01–31).
  - When given `2009-14-10`, the parser detects an invalid month (`14 > 12`) and rejects the string.
  - The row is flagged with:
    `Row 13 (Birthday: 2009-14-10): Use YYYY-MM-DD format.`
- **Edge Cases / Fallback:** The parser also handles numeric Excel date serial numbers (e.g. `40179` generated automatically by Microsoft Excel or WPS Office when dates are formatted as numbers).

---

### Q9: If a student is already enrolled in my section and I upload the whole masterlist again, will it duplicate their grades or attendance?

- **Direct Summary:** No; the student will be categorized into Box 4 (**Enrolled**) and safely skipped, preventing duplicate database entries, attendance cards, or gradebook columns.
- **Technical Walkthrough:**
  - The system checks `student_enrollments` for matches on both `student_id` and `subject_offering_id`:
    ```dart
    if (enrollStatus == 'enrolled') {
      alreadyEnrolledStudents.add(s);
      continue;
    }
    ```
  - The student is placed in Box 4 (**Enrolled**). During the final enrollment phase, Box 4 rows are ignored, meaning no database writes occur for those records.
- **Edge Cases / Fallback:** If a student was marked `archived` in this class, the upload warns the teacher that the student is archived, preventing accidental re-enrollment while keeping attendance audit histories intact.

---

### Q10: How do newly enrolled students receive their login credentials?

- **Direct Summary:** For every student in Box 2 (**New Students**), the system automatically generates an encrypted authentication account, provisions a secure temporary password, and dispatches a welcome email with their login instructions.
- **Technical Walkthrough:**
  - Upon clicking `"Enroll Eligible Students"`, the application invokes `SupabaseStudentRepository.createStudentAccount()`:
    1. Creates user in Supabase Auth with email and random temporary password.
    2. Writes record to `student_profiles` with `first_login_pending = true`.
    3. Queues an email via `EmailService.sendWelcomeStudentEmail()` containing the student's registered email, temporary password, and portal URL.
    4. Upon their first login, `AuthGuard` redirects the student to `/student/first-login` to force a password change and security verification before granting dashboard access.
- **Edge Cases / Fallback:** If SMTP or internet service drops while sending the welcome email, the teacher can view or regenerate temporary passwords directly from the Teacher Student Management table via the `"Reset Credentials"` button.
