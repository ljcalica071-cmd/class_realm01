# Manage Student Feature — Detailed End-to-End Plan

## 1. Goal and scope

This plan defines how a teacher should add and manage students in a specific
classroom, both one at a time and through bulk CSV/Excel import. It covers the
full path from choosing an offering, validating identity, creating or reusing
an account, enrolling the student, reporting outcomes, and safely recovering
from partial failures.

The feature must support the ClassRealm model described in `Master_Plan.md`:

- A student has one global account, identified by a unique 12-digit LRN.
- A student may have many separate enrollments for different subject offerings
  and teachers.
- A teacher only manages and sees students and enrollment data for offerings
  assigned to that teacher.
- The same LRN must never create multiple student accounts.
- Student accounts, enrollments, and academic history are distinct records.
- Enrollment is assigned to one exact `subject_offering_id`, not inferred from
  subject or section display names.

This is a plan only. It does not implement or change application behavior.

## 2. Product rules and safe defaults

### 2.1 Identity versus enrollment

Treat **account creation** and **class enrollment** as separate operations:

1. Resolve the student globally using the normalized LRN.
2. If the student does not exist, create the identity/account once.
3. If the student already exists, verify their identity details and reuse that
   account without changing credentials.
4. Create an enrollment only for the selected teacher-owned offering.
5. Never create a second account just because another teacher is adding the
   student to a different subject.

The student profile is shared across teachers. Teaching records are private to
their owning offering. A shared student account does not grant one teacher
access to another teacher's enrollments, attendance, classwork, submissions, or
grades.

### 2.2 Exact class target

Before adding any student, the teacher selects one active subject offering.
The selector should display enough context to distinguish duplicate labels:

- school year and term;
- grade level;
- subject name;
- section name; and
- any strand/track or schedule context available.

All enrollment, duplicate checks, review, progress, and results are scoped to
the selected offering ID. Never use the section name or subject name alone as
the security or persistence key.

### 2.3 Non-destructive lifecycle

- Archive/deactivate only the selected enrollment for a teacher's ordinary
  class-management action.
- Do not deactivate the global student account or other subject enrollments
  from one teacher's Manage Students tab.
- A formal school-wide withdrawal/drop is a separate authorized action. It
  requires the policy conflicts in `Master_Plan.md` §5 to be resolved before
  implementation.
- Do not hard-delete a student with academic, attendance, parent-link, or
  enrollment history through the ordinary UI.
- A cancelled archive, move, or deletion confirmation changes nothing.
- Restoring an enrollment must not overwrite an existing active enrollment or
  bypass current offering/section limits.

### 2.4 Production validation contract (AppValidators & ClassRealm standards)

All student data entry—whether manual single-student input, CSV/XLSX bulk imports, or trusted backend writes—must use one unified validation contract conforming to `AppValidators` and DepEd standards:

| Field | Production rule | Validation details & formatters |
|---|---|---|
| **First name** | Required; 2–30 characters | Allowed characters: letters, spaces, hyphens, and periods (`[a-zA-Z\s\-\.]`). Auto-capitalizes first letter, rejects leading space/period, rejects consecutive spaces (`  `) and consecutive periods (`..`) via `_CleanInputFormatter`. |
| **Middle name** | Optional; 0–30 characters | When provided, strictly enforces the same character rules and `_CleanInputFormatter` as First Name. |
| **Last name** | Required; 2–30 characters | Allowed characters: letters, spaces, hyphens, and periods (`[a-zA-Z\s\-\.]`). Enforces `_CleanInputFormatter`. |
| **LRN** | Required; exactly 12 digits | Must match `^\d{12}$` (numeric digits only). Non-digits stripped or rejected. Must be globally unique across ClassRealm. |
| **Email** | Required; max 60 characters | Mandatory for student account creation, password delivery, and portal login. No spaces allowed. Validated against RFC 5322 regex. Subject to: (1) domain typo checks (.con, .cpm, Levenshtein distance <= 2 against Gmail, Yahoo, Outlook, etc.), and (2) live DNS-over-HTTPS (DoH) MX deliverability verification via Google Public DNS and Cloudflare DoH. |
| **Birthday** | Required; valid past date | DepEd Senior High School standard: age 10–25 (or up to 60 for ALS / adult learners). Birth year must be 2000 or later. Supported formats: ISO 8601 `YYYY-MM-DD`, `YYYY/MM/DD`, or `MM/DD/YYYY`. Future or impossible dates strictly rejected. |
| **Gender** | Required; Male or Female | Strict normalized values: `'Male'` or `'Female'`. Import parsing safely accepts aliases: `'m'`, `'f'`, `'male'`, `'female'`, `'lalaki'`, `'babae'`. |
| **Offering** | Required; active offering | Must correspond to an active `subject_offering_id` owned by the authenticated teacher. |
| **Contact number** | Optional; 10–13 digits | Numeric format if provided (e.g., `09XXXXXXXXX` or `+639XXXXXXXXX`). |

#### Inline input validation standard (MANDATORY)

In accordance with the `inline-input-validation` standard:
1. **Never use bottom SnackBars, banners, or floating toast notifications for form and input validation errors.** Bottom toasts block UI buttons, disappear too fast, and detach the error from the field.
2. **Red Border Outline**: Whenever a field fails validation, its container border must immediately turn red (`Color(0xFFDC2626)` or `Colors.red.shade600`).
3. **Inline Error Message**: Display clear, 12–13px red error text directly **underneath** the invalid input field.
4. **Live Error Clearing**: As soon as the teacher types or edits the invalid field, clear the inline red border and error message immediately.
5. **Clear English Messages**: All error text must be professional, grammatically correct English (e.g., *"LRN must be exactly 12 digits"*, *"Email domain does not exist or has no mail servers"*).

### 2.5 Resolve conflicting specifications before implementation

The following reconciliations between `Master_Plan.md`, existing UI widgets, and production schema are established:

1. **Email Requirement**: Student email is **mandatory** because ClassRealm relies on email delivery for first-login temporary credentials and authentication. The official CSV/XLSX template includes `Email` as a required column.
2. **Name Length**: Standardized to **2–30 characters** (matching `AppValidators` and database optimization) rather than 50 characters.
3. **Supported Import Formats**: Strictly support **CSV** (`.csv`) and modern **Excel** (`.xlsx`). Disallow old binary Excel (`.xls`) at file picker level and show a clear message if an unsupported file is dropped. File size limit: **5 MiB**; row limit: **500 rows** per batch.
4. **Age & Birthday Policy**: Age must be 10–25 for standard SHS tracks (extended to 60 for ALS adult students). Birth year >= 2000. No future dates.
5. **LRN Resolution**: Existing LRNs must be reused across different subjects/teachers without overwriting the existing profile. Profile field mismatches (name/gender/birthday mismatch against existing LRN) must halt enrollment and alert the teacher to verify records.
6. **Transferee Workflow**: Transferees entering mid-school year with previous grades remain a separate flow and are not mixed with standard bulk import.
7. **Database Schema Harmonization**: The single-student and bulk flows must align with the normalized Supabase schema (`users`, `student_profiles`, `student_settings`, `student_enrollments`, and `subject_offerings`), incorporating the required Migration 007 updates detailed in §8.

## 3. Teacher-facing Manage Students workspace

### 3.1 Main page

The teacher opens **Manage Students** and sees a roster for their own active
offerings. The page should provide:

- offering/subject/section filters that are based on offering IDs, even if the
  UI presents names;
- search by student name or LRN;
- active and archived enrollment views;
- sort and pagination that preserve filter context;
- counts for active, archived, and selected students that match the displayed
  offering/filter;
- **Add Student** for one student;
- **Bulk Upload** for CSV/XLSX import;
- a clear loading state, true empty state, and error state with retry; and
- a visible indication of the current school year/term and selected offering.

The data list must not fall back to mock students when a Supabase request fails.
An error is not an empty roster and must not be shown as a successful load.

### 3.2 Selection and bulk actions

If row selection is supported:

- selections apply only to the currently authorized offering and current
  filtered result set;
- changing the offering clears or explicitly revalidates selection;
- bulk archive actions show the count and exact offering scope before
  confirmation;
- one teacher cannot globally archive or deactivate a shared student account;
- a partial failure identifies each affected enrollment and does not claim all
  rows succeeded.

## 4. Individual Add Student flow

### Step 1: Select offering

The teacher chooses one active offering they own. If they opened the form from
a particular section, preselect that offering but still show the full class
context and allow deliberate correction.

If no eligible offering exists, do not open an unusable form. Explain that the
teacher must first create or activate a subject/section offering.

### Step 2: Enter student information

Collect the approved fields using standard `AppValidators` formatters:

- **Name inputs**: Apply `_CleanInputFormatter` (auto-capitalizes first letter, strips leading space/period, collapses consecutive spaces and consecutive periods, max 30 characters).
- **LRN input**: Digits-only input formatter (`FilteringTextInputFormatter.digitsOnly`), max 12 characters. Validate exact length of 12 digits.
- **Email input**: Apply `_NoSpaceFormatter`, max 60 characters. Validate RFC 5322 regex.
- **Birthday input**: Date picker or structured text input (`YYYY-MM-DD` / `MM/DD/YYYY`). Calculate age dynamically; require age 10–25 (or up to 60 for ALS) and birth year >= 2000.
- **Gender selector**: Segmented control or dropdown restricted to `'Male'` or `'Female'`.

**Strict Inline Validation Rule:**
- **Zero Bottom Toasts/SnackBars**: Under no circumstances should bottom SnackBars, banners, or floating toasts be displayed for field validation.
- **Red Border**: The container or outline border turns red (`Color(0xFFDC2626)`) on error.
- **Inline Error Text**: Error message displays directly underneath the field in 12–13px red text.
- **Live Error Clearing**: Hook listeners to text controllers; clear the inline error immediately when the teacher starts typing.

### Step 3: Email deliverability & typo verification

Email verification utilizes a two-tier check before submitting:

1. **Typo Detection**: Detect common TLD typos (`.con`, `.cpm`) or domain typos via Levenshtein distance (e.g., `gamil.com` → `gmail.com`). Show an interactive modal dialog allowing the teacher to **Use suggested email** or **Keep entered email**.
2. **DNS-over-HTTPS (DoH) Deliverability Check**: Query Google Public DNS (`https://dns.google/resolve`) and Cloudflare DoH (`https://cloudflare-dns.com/dns-query`) for MX records.
   - If the domain does not exist (NXDOMAIN) or has no mail exchange records, display an inline error underneath the email field: *"This email domain does not exist or cannot receive emails."*
   - Never proceed to account creation with an undeliverable domain.

### Step 4: Resolve the LRN

The backend performs an authoritative LRN lookup immediately before writing:

- **No LRN match:** continue as a new account candidate.
- **One exact match:** show the existing profile's identifying details and
  distinguish an existing account from a new enrollment.
- **More than one match:** stop; treat this as data-integrity corruption and
  require an authorized administrator to resolve it.
- **LRN match but entered name/birthday/gender differs:** do not overwrite the
  existing profile or enroll silently. Show the fields that differ, ask the
  teacher to verify the LRN and source record, and block the enrollment until
  corrected or sent through an authorized profile-correction flow.
- **Same offering already has an active enrollment:** report “Already enrolled”
  and make no duplicate enrollment.
- **Same offering has an archived/dropped/completed enrollment:** show the
  existing status and offer only an authorized restore/reactivation workflow;
  do not create a second row.
- **LRN exists under another teacher/offering:** reuse the global account and
  create only the current offering's enrollment after identity verification.
  Do not reveal the other teacher's private subject records. If a policy allows
  showing other enrollments, it must be limited to an authorized school-wide
  role, not this teacher.

### Step 5: Confirm account/enrollment action

Before final save, show a concise confirmation:

- student identity and LRN;
- selected subject, section, school year, and term;
- whether the action creates a new account or adds an enrollment to an
  existing account;
- whether an invitation/first-login message will be sent; and
- any special transferee handling, if explicitly enabled.

Do not reveal or export a raw generated password. Prefer a secure,
server-generated first-login invitation/OTP flow. The student must establish
their own password through the first-login process.

### Step 6: Save and confirm

The operation must be idempotent and authorized server-side. For a new account,
provision identity/profile/status/enrollment as one recoverable workflow. For an
existing account, create only the enrollment. Do not report success until the
database confirms the intended result.

After success:

- close or reset the form only after persistence is confirmed;
- refresh the roster from the authoritative source;
- show whether the account was created or an enrollment was added;
- show invitation delivery as a separate state (`sent`, `pending`, or
  `failed`), not as proof that enrollment failed; and
- avoid displaying sensitive credentials.

If account provisioning succeeds but enrollment fails, do not create a second
account on retry. Show that the account exists and allow a safe retry of the
missing enrollment step or route the inconsistent state for recovery.

## 5. Bulk Upload flow

### Step 1: Select target offering and template download

Before selecting a file, the teacher chooses one active owned offering (Grade Level -> Subject -> Section). The UI shows the exact class context and offers:

- **Download Official Template**: Instantly saves the official, versioned ClassRealm CSV/XLSX template.
- **Accepted Formats & Schema**: Explains required columns, acceptable date formats (`YYYY-MM-DD`), and accepted file types (`.csv` and modern `.xlsx`).
- **File Limits**: Maximum 5 MiB (5,242,880 bytes) and up to 500 rows per batch.
- **Safety Guarantee**: Clear notice that all student rows will undergo thorough validation and pre-flight review before any account or enrollment write occurs.

#### Template Specifications and Reliable Download Architecture

The template must be download-ready on both Web (`kIsWeb`) and Desktop (Windows):

1. **Columns and Format Contract**:
   - `LRN` (Required): Exactly 12 numeric digits (DepEd Learner Reference Number, e.g., `101234567890`).
   - `Email` (Required): Student's active email address for receiving first-login temporary credentials (e.g., `juan.delacruz@example.com`).
   - `Last Name` (Required): 2–30 characters, clean capitalized format (e.g., `Dela Cruz`).
   - `First Name` (Required): 2–30 characters, clean capitalized format (e.g., `Juan`).
   - `Middle Name` (Optional): 0–30 characters (e.g., `Protacio`).
   - `Gender` (Required): `Male` or `Female` (case-insensitive, aliases `M`, `F`, `Lalaki`, `Babae` accepted during parsing).
   - `Birthday` (Required): ISO format `YYYY-MM-DD` (e.g., `2007-06-19`). Age must evaluate to 10–25 (or up to 60 for ALS learners), birth year >= 2000.

2. **Cross-Platform Download Handling**:
   - **Flutter Web**: Use an anchor-tag blob URL download (`dart:html` / `universal_html` / `package:web`) or `FilePicker.platform.saveFile` with raw bytes to guarantee the browser prompts the user or writes directly to their default browser `Downloads/` folder.
   - **Windows Desktop**: Prompt `FilePicker.platform.saveFile(fileName: 'classrealm_student_template.csv', allowedExtensions: ['csv', 'xlsx'])`. If cancelled or path is null, automatically fall back to saving directly in `Directory('${Platform.environment['USERPROFILE']}\\Downloads')` and display a success dialog showing the exact file path and clickable directory opener.

---

### Step 2: Pick and read file safely

1. **Format Validation**: Accept `.csv` and `.xlsx` only. Disallow deprecated legacy `.xls` (Excel 97–2003) at picker level; if dropped, show a clear message explaining modern `.xlsx` or `.csv` is required.
2. **File Size & Safety Ceiling**: Reject files exceeding 5 MiB immediately prior to memory loading.
3. **Empty / Corrupt Guard**: If file contains 0 bytes or lacks header rows, abort gracefully with an actionable error.
4. **Picker Cancellation**: Treat user cancellation as a normal no-op with zero state changes.

---

### Step 3: Phase 1 — Parsing, Header Mapping & Validation Loading State

To ensure smooth UX, validation is separated from the actual database commit:

1. **Validation Loading Indicator**:
   - As soon as the file is selected, display an active processing modal: *"Validating spreadsheet data... Checking Row X of Y"*.
   - Never freeze the UI thread while reading large spreadsheets. Run XLSX ZIP extraction (`archive` package) and CSV parsing asynchronously.
2. **Header Normalization & Alias Matching**:
   - Read row 1 as headers; match case-insensitively against recognized aliases:
     - LRN: `lrn`, `student id`, `learner reference number`.
     - Email: `email`, `email address`, `student email`.
     - Last Name: `last name`, `lastname`, `surname`, `last_name`.
     - First Name: `first name`, `firstname`, `given name`, `first_name`.
     - Middle Name: `middle name`, `middlename`, `middle_name`.
     - Gender: `gender`, `sex`.
     - Birthday: `birthday`, `birthdate`, `birth date`, `dob`.
   - If required headers are missing, stop parsing immediately and list missing columns alongside the "Download Official Template" button.
3. **Row-Level Structural & Syntax Validation**:
   - Validate 12-digit numeric LRN.
   - Validate name lengths (2–30 chars) and prohibited characters.
   - Validate Gender against allowed options (`Male`, `Female`).
   - Validate Birthday format (`YYYY-MM-DD`), past date, age range (10–25, birth year >= 2000).
   - Validate Email syntax (RFC 5322 regex).
4. **Intra-File Duplicate Detection**:
   - Track seen LRNs within the file. If an LRN repeats, flag subsequent rows as `Duplicate in file` with their exact row numbers.
5. **Database Pre-Check & Identity Classification**:
   - Query Supabase `student_profiles` and `student_enrollments` for all valid LRNs in the batch in a single batch query:
     - **`New account + enrollment`**: LRN does not exist anywhere in ClassRealm.
     - **`Existing account + new enrollment`**: LRN exists under another teacher/offering; identity fields (Name, Gender, Birthday) match trusted profile. Eligible for enrollment without altering existing credentials.
     - **`Already enrolled`**: Student with this LRN already has an active enrollment in this exact `subject_offering_id`. Classified as a safe no-op.
     - **`Archived enrollment`**: Prior enrollment in this offering exists in archived state. Needs dedicated restore flow; cannot create duplicate.
     - **`Identity mismatch`**: LRN exists, but name/gender/birthday in the spreadsheet differs from the registered profile. Flagged for review; blocked from blind enrollment.
     - **`Invalid row`**: Failed any structural or formatting check.

---

### Step 4: Phase 2 — Pre-Flight Review Modal & Compact Error Presentation

Before writing any records to the database, display the Pre-Flight Review dialog modal:

1. **Target Classroom Context**: Displays Grade Level, Subject Name, and Section Name.
2. **Summary Metric Pills**:
   - **Eligible New Students** (Green): Valid LRNs needing new accounts + enrollment.
   - **Eligible Existing Students** (Blue): Existing ClassRealm students to be added to this section.
   - **Already Enrolled** (Grey): Safe no-ops (will be skipped without error).
   - **Duplicates / Invalids** (Red/Amber): Rows with issues, with row numbers and exact rejection reasons.
3. **Dedicated Concise Error Modal Presentation**:
   - If invalid rows or identity conflicts exist, present a scrollable review container directly inside the modal.
   - **Structure of Each Error Item**:
     - `Row [Number]`: Original row index in the spreadsheet.
     - `Student Identifier`: Name (if present) or `LRN [value]`.
     - `Field Badge`: Highlighted badge indicating the exact column (e.g., `[LRN]`, `[Birthday]`, `[Email]`, `[Gender]`, `[Name]`).
     - `Short Error Message`: A concise, human-friendly, 2–6 word description explaining the exact issue (no raw code or verbose stack traces).
   - **Canonical Short Error Message Catalog**:

| Failed Column / Check | Verbose Backend Exception | Pinaikling Display Message (Short Version) |
|---|---|---|
| **LRN** | Regex failed or length != 12 | `Must be exactly 12 digits` |
| **LRN (Non-digits)** | Contains letters or symbols | `Numbers only, exactly 12 digits` |
| **LRN (File Duplicate)** | LRN repeated in spreadsheet | `Duplicate LRN in this file` |
| **LRN (Mismatch)** | Name/Bday mismatch against DB | `Name/Birthday mismatch with existing LRN` |
| **First Name** | Empty or < 2 characters | `First name required (min 2 letters)` |
| **Last Name** | Empty or < 2 characters | `Last name required (min 2 letters)` |
| **Gender** | Unknown string (not M/F) | `Must be Male or Female` |
| **Birthday (Format)** | Unparseable date format | `Invalid date (use YYYY-MM-DD)` |
| **Birthday (Future)** | Date is today or future | `Cannot be today or future date` |
| **Birthday (Age)** | Age < 10 or > 25 (non-ALS) | `Age out of range (10–25 yrs old)` |
| **Email (Syntax)** | Invalid RFC 5322 format | `Invalid email address format` |
| **Email (Domain)** | DoH DNS check NXDOMAIN | `Email domain does not exist` |
| **Email (Typo)** | Levenshtein match (.con) | `Possible typo: did you mean @gmail.com?` |

4. **Teacher Control Actions**:
   - Checkbox or toggle allowing the teacher to exclude specific rows if desired.
   - **Confirm Button**: *"Enroll X Eligible Students"* — Enabled ONLY if at least 1 student is eligible.
   - **Cancel Button**: Closes review without touching any database or user accounts.

---

### Step 5: Phase 3 — Real-Time Batch Upload & Enrollment Execution

Once the teacher clicks "Enroll Eligible Students", execute the batch enrollment with live progress feedback:

1. **Real-Time Progress Modal**:
   - Animated Circular / Linear Progress Bar with percentage indicator (`(current / total) * 100%`).
   - Dynamic Counter: *"Student X of Y (Z%)"*.
   - Live Student Indicator: *"Enrolling: Juan Dela Cruz (LRN: 101234567890)..."*.
   - Current stage tag: *"Creating user account"*, *"Enrolling to section"*, *"Persisting local cache"*.
2. **Idempotent Per-Row Provisioning**:
   - **New Student**:
     1. Create Auth account (Firebase/Supabase Auth) with generated secure temporary password (`${cleanLastName}${YYYYMMDD}`).
     2. Upsert record into `users` table (`role: 'student'`, `status: 'pending_first_login'`).
     3. Insert record into `student_profiles` (`student_id`, `lrn`, `first_name`, `middle_name`, `last_name`, `gender`, `birthday`).
     4. Insert record into `student_settings` (`status: 'pending_first_login'`).
     5. Insert record into `student_enrollments` (`student_id`, `subject_offering_id`, `status: 'enrolled'`).
     6. Persist to local Drift SQLite database (`local_students`).
   - **Existing Student (Cross-Teacher Reuse)**:
     1. Retrieve existing `student_id`.
     2. Verify target offering enrollment does not already exist.
     3. Insert single record into `student_enrollments` (`student_id`, `subject_offering_id`, `status: 'enrolled'`).
     4. DO NOT overwrite profile, DO NOT reset password, DO NOT resend original welcome email.
3. **Row-Scoped Error Isolation**:
   - If Row 5 fails due to an unexpected constraint or network blip, catch the error, log Row 5 as failed with its exact message, and **continue processing Row 6**. Never abort the entire batch for isolated student failures.

---

### Step 6: Proper High-Volume Credential Email Dispatch Architecture

Sending 30 to 100 emails simultaneously at the exact moment of database insertion is a critical production anti-pattern:
- Causes SMTP gateway timeouts and connection drops.
- Exceeds transactional email rate limits (e.g., Gmail/SendGrid/Resend rate limits).
- Triggers spam filters or IP throttling.
- Freezes client UI thread and delays feedback.

#### ClassRealm Bulk Email Delivery Protocol:

1. **Decoupled Two-Phase Execution**:
   - **Phase A (Fast Database Enrollment)**: All accounts and enrollments are written and committed to Supabase/Firebase first. The teacher's class roster is immediately populated and functional.
   - **Phase B (Throttled Background Queue)**: Welcome emails containing temporary login credentials are submitted to an asynchronous queue.
2. **Throttled Chunking Strategy**:
   - If executing on client/Edge Function: Group outbound emails into **micro-chunks of 3 to 5 emails**.
   - Enforce an asynchronous pause / jitter of **1,500ms to 2,000ms between chunks** to strictly adhere to SMTP quotas and deliverability best practices.
3. **Separate Delivery Tracking**:
   - Delivery status is tracked independently per student (`email_sent: true/false`, `email_error: String?`).
   - A failed email delivery **DOES NOT roll back or cancel the student's enrollment**.
   - If an email fails to deliver (e.g., mail server timeout or bounce), mark the student record as `Email Delivery Failed`.
4. **Teacher Fallback & Resend Controls**:
   - In the Batch Result summary dialog, provide:
     - An **"Email Credentials" status report** showing succeeded vs pending/failed emails.
     - A **"Retry Failed Emails"** button to retry only the failed recipients.
     - A **"Copy Credentials Roster"** or **"Export Credentials CSV"** option, allowing the teacher to print or manually distribute temporary passwords if email access is down.

---

### Step 7: Interruption Recovery, Offline Handling & Accidental Refresh

Unplanned events must never corrupt the class database or leave ghost accounts:

1. **Local Session Persistence (`SharedPreferences`)**:
   - At batch start, save an active session object keyed by `batch_enroll_session_<offering_id>`:
     ```json
     {
       "fileName": "Grade11_Students.xlsx",
       "offeringId": "offering_uuid_123",
       "total": 45,
       "pending": [ ...list of pending parsed student rows... ]
     }
     ```
   - Each time a student is confirmed committed in Supabase, remove their LRN from the persisted `pending` array.
2. **Accidental Page Refresh / Tab Close**:
   - Upon reopening the Manage Students tab or the Unified Dialog:
   - Detect the existing `batch_enroll_session_<offering_id>`.
   - Display an Amber Alert Banner at the top of the Import Tab:
     *"Interrupted Session Detected: 18 students from 'Grade11_Students.xlsx' were not yet enrolled. [Discard] [Resume Batch]"*.
   - When the teacher clicks **Resume**:
     - The system re-checks Supabase by LRN + `subject_offering_id` to guarantee no duplicate writes.
     - Resumes enrollment seamlessly from the first uncommitted student.
3. **Internet Disconnect / Packet Drop Mid-Batch**:
   - If a network error occurs mid-loop, display a clear modal:
     *"Network Connection Lost. Upload paused at student 14 of 45. Please check your internet connection."*
   - Provide **[Retry Now]** and **[Save for Later]** options.
   - Students already enrolled prior to the disconnect remain 100% active and saved in the database.
4. **Session Cleanup**:
   - Upon 100% batch completion or explicit "Discard", remove the session key from `SharedPreferences`.

---

### Step 8: Final Outcome Report

Dismiss the progress dialog and present the Batch Result summary dialog:

- **Total Processed**: Count of students evaluated.
- **Successfully Enrolled** (Green pill): Count of students now active in the section.
- **Already Enrolled / Skipped** (Grey pill): Safe no-ops that required no changes.
- **Failed Rows** (Red pill, if any): List of failed rows with original row number, student name, and actionable error explanation.
- **Action Buttons**:
  - **[Done]**: Closes modal and triggers `widget.onStudentCreated()` to instantly reload the teacher's active class roster via Drift/Supabase.
  - **[Export Error Report]**: Downloads a CSV of only the failed rows with error reasons for easy correction.

---

## 6. Scenario catalog: expected system response

The following scenarios detail every edge case and unexpected event, ensuring zero conflicts and predictable behavior.

### Identity, Duplication, and Multi-Teacher Scenarios

| Scenario | Expected system response |
|---|---|
| **New student with valid 12-digit LRN** | Creates global student account in `users` and `student_profiles`, creates enrollment in target `subject_offering_id`, queues welcome email, caches locally in Drift. |
| **Student already enrolled by another teacher in another subject** | **Zero Conflict**: System detects existing LRN in `student_profiles`. Verifies identity details (Name, Birthday, Gender). Reuses existing `student_id`. Inserts single new record into `student_enrollments` for current teacher's offering. **Does NOT create new account, does NOT reset password, does NOT leak Teacher A's subject data.** |
| **Student already enrolled in this exact subject offering** | System detects existing active enrollment for this `(student_id, subject_offering_id)`. Marks row as `Already enrolled`. Skips safely as a no-op; shows in summary without error or duplicate records. |
| **Same student appears twice in the same spreadsheet** | First instance is processed; subsequent instance is flagged as `Duplicate in file` with its exact row number. Teacher is notified in pre-flight review. |
| **Student exists in system, but spreadsheet has conflicting name/birthday** | System halts enrollment for this row and flags `Identity mismatch (LRN matches existing student, but Name/Birthday differs)`. Prevents accidental identity overwrite. Requires manual teacher verification. |
| **Two teachers concurrently import the same new student at the same time** | Supabase unique constraint on `lrn` guarantees only one global account is created. The second write safely falls back to creating the enrollment for the second teacher's offering. |

### Network, Interruption, and Unexpected Scenarios

| Scenario | Expected system response |
|---|---|
| **Internet cuts out mid-upload (e.g. at student 15 of 50)** | Upload loop pauses gracefully without crash. Displays *"Connection lost at Student 15"*. Students 1–14 remain permanently enrolled. Allows teacher to [Retry Connection] or [Save & Resume Later]. |
| **Teacher accidentally refreshes or closes browser/app mid-batch** | System has persisted uncommitted rows in `SharedPreferences`. On next visit, displays amber *"Interrupted session found"* banner with one-click **[Resume]** button. Idempotently skips already enrolled students. |
| **Teacher cancels file picker dialog** | Clean no-op. Preserves dialog state with zero errors or side effects. |
| **Teacher downloads template on restricted browser or Windows device** | On Web: triggers direct browser anchor blob download. On Windows: prompts Save File dialog; if inaccessible, silently writes directly to `%USERPROFILE%\Downloads\classrealm_student_template.csv` and displays confirmation modal with file location. |
| **File uploaded has invalid extension or legacy .xls format** | Rejection before parsing: *"Unsupported file format. Please upload modern Excel (.xlsx) or CSV (.csv). Use 'Download Official Template' to view format."* |
| **File uploaded exceeds 5 MiB ceiling** | Immediate rejection before reading into memory: *"File size exceeds 5 MB limit. Please split your file or reduce unneeded formatting."* |
| **Spreadsheet has blank rows between student records** | Parser detects empty cells across all columns, silently ignores blank rows, and notes count of skipped blank rows in pre-flight review. |
| **Date of birth in non-standard format (e.g., '19-06-2007' or words)** | Robust parser attempts ISO `YYYY-MM-DD`, `YYYY/MM/DD`, and `MM/DD/YYYY`. If unrecognizable or invalid date (e.g. Feb 31), marks row as `Invalid birthday format` with row number. |
| **Student email domain has no mail servers / typo** | Pre-flight DNS-over-HTTPS (DoH) verification flags invalid domain. Typo helper suggests correction (e.g. `@gamil.com` -> `@gmail.com`). Row is excluded or corrected before committing. |
| **Email sending fails for 3 out of 30 students due to SMTP timeout** | **Enrollment is NOT cancelled.** Students are successfully enrolled and visible in roster. Batch result displays *"27 Credential Emails Sent, 3 Pending/Failed"*. Teacher can click **[Retry Failed Emails]** or copy passwords. |
| **Teacher has no assigned subject offerings** | Dialog disables import actions and displays prominent message: *"No active classroom sections found. Please complete Classroom Setup before enrolling students."* |

### File, parser, and validation scenarios

| Scenario | Expected response |
|---|---|
| Teacher cancels file picker | No error and no state/data changes. |
| Unsupported extension or disguised file type | Reject with supported formats; do not parse based on extension alone. |
| XLS selected while XLS is not implemented | Explain that legacy XLS is unsupported and offer CSV/XLSX conversion; do not accept it in the picker and later fail unexpectedly. |
| File exceeds the approved size limit | Reject before parsing; show actual size and exact limit. |
| File is empty or contains only headers | Show “No student rows found”; perform no writes. |
| File is corrupt, encrypted, or malformed | Identify the file/worksheet issue, preserve the selected offering, allow retry, and perform no writes. |
| Required header missing or ambiguous | Show missing/ambiguous columns and allow mapping or template download; do not guess silently. |
| Header order differs | Map by recognized header labels, not fixed column positions. |
| Header has known alias/case variation | Accept only approved aliases, case-insensitively; show the resolved mapping in review. |
| CSV contains commas, quotes, newlines, BOM, or Unicode names | Parse correctly or reject with a precise row/column error; never shift subsequent values. |
| Row has missing/extra cells | Mark that row invalid with its row number; do not map values into the wrong fields. |
| Blank rows between data | Ignore and count them in the review summary. |
| Birthday has an invalid date or future date | Mark row invalid; do not auto-correct ambiguous dates. |
| Birthday format is ambiguous, e.g. `03/04/2008` | Prefer ISO `YYYY-MM-DD`; ask for clarification/correction rather than guessing day/month. |
| Student is below/above approved age | Mark row invalid with the computed age and allowed range; do not create account. |
| Gender value uses an approved alias such as `M`/`F` | Normalize only according to approved mapping and show the normalized value in review. |
| Email has likely domain typo | Warn and suggest correction; require confirmation; do not silently alter. |
| Email is invalid or missing when required | Mark row invalid; no account invitation is attempted. |
| Optional middle name/contact number is blank | Accept as null/empty according to schema; do not reject the row. |
| File contains formulas instead of values | Import calculated values only if parser can read them reliably; otherwise reject affected cells and explain. |
| File contains unexpected macros or external links | Do not execute them. Treat spreadsheet contents as untrusted data. |
| Extremely large row count despite small compressed file | Apply a documented maximum row count and parsing/resource limits; reject safely before exhausting memory. |

### Enrollment, offering, and permissions scenarios

| Scenario | Expected response |
|---|---|
| Teacher has no active subject offerings | Disable add/import and explain that classroom setup is required first. |
| Selected offering is archived or becomes inactive before commit | Revalidate at commit; stop writes for that offering and ask teacher to select an active offering. |
| Teacher manipulates offering ID in browser/request | Trusted backend verifies ownership; deny access and record the denied action where audit logging exists. |
| Offering display labels duplicate another teacher's offering | Use offering ID and full context; never enroll to another teacher by matching names. |
| Student has multiple subject enrollments | Keep one account and one enrollment per offering; do not treat other enrollments as duplicates. |
| Same student is enrolled in another section of this subject | Do not move automatically. Follow the approved section-change workflow; Master Plan currently says archive incorrect enrollment and create a new one, preserving history. |
| Student's grade/section changes mid-year | Do not rewrite historical enrollment or scores. Require explicit authorized transfer/move procedure; current policy says section shifting is not allowed. |
| Student is archived globally but a teacher tries to enroll | Block and route to authorized account restore/review; a class teacher cannot globally restore/deactivate shared identity by assumption. |
| Existing target enrollment is archived/dropped | Offer the dedicated restore action only if policy permits and no active conflict exists. Do not create duplicate enrollment. |
| Parent link exists for student | Do not alter the parent link during enrollment. Parent visibility follows the existing authorized link only. |
| Teacher searches by LRN | Show only data permitted for the teacher's current relationship; avoid exposing unrelated classes or sensitive records. |

### Batch reliability, interruption, and notification scenarios

| Scenario | Expected response |
|---|---|
| Teacher cancels pre-flight review | No accounts, enrollments, or invitations are created. |
| Teacher excludes some valid rows | Commit only the explicitly selected eligible rows; report excluded rows separately. |
| Network drops before any write | Preserve review state if safe; allow retry after rechecking offering and identities. |
| Network drops during account provisioning | Query batch/server state before retry; do not create a duplicate Firebase or Supabase identity. |
| Network drops after account creation but before enrollment | Mark row as recoverable/incomplete; retry only enrollment after verifying the same account. |
| Network drops after enrollment but before client receives response | Recheck enrollment by LRN/account ID and offering ID; classify success rather than inserting again. |
| Browser refreshes or app closes during batch | Resume from server-confirmed batch state; do not trust only local pending rows. |
| Two teachers import the same new LRN at the same time | Enforce unique LRN in the database; one creates the account, the other re-resolves and may create only its own enrollment if identity matches. |
| Two teachers concurrently enroll same existing student into same offering | Enforce unique `(student_id, subject_offering_id)`; return one success and one “already enrolled,” not duplicate rows. |
| One row fails while other rows succeed | Continue only if the failure is row-scoped and safe; show exact partial result and allow retry of failed rows only. |
| Global service/database outage or authorization failure | Stop the batch; preserve status; do not continue with local/mock success. |
| Email invitation fails after account/enrollment succeeded | Keep enrollment successful; mark invitation failed/pending and provide safe retry without changing account or resending to other rows. |
| Progress dialog is dismissed or app goes to background | Define whether operation continues server-side; if it does, show a recoverable batch status when reopened. Never leave uncertain background writes. |
| Local device storage is cleared | Recover batch from server-side import ID; if unavailable, require safe LRN/offering recheck before any retry. |
| Batch includes raw PII | Restrict access and retention; do not store raw files indefinitely or put credentials/secrets in recovery data. |

### Lifecycle and history scenarios

| Scenario | Expected response |
|---|---|
| Teacher archives one student's enrollment | Archive only that teacher-owned enrollment; keep global account, other enrollments, and history active. |
| Teacher tries to archive the global student account | Block; require authorized school-wide action. This follows the Master Plan priority scenario. |
| Student formally drops from school | Follow a separate school-wide process only after the §1.16/§1.18 scope conflict is resolved; freeze/preserve grades and history as approved. |
| Teacher archives an incorrect enrollment | Preserve grades, attendance, classwork, and audit history; keep the record available in archived view. |
| Teacher restores archived enrollment but another active enrollment now conflicts | Keep it archived and explain the conflict; do not overwrite active records. |
| User cancels archive/restore | No change to enrollment or login access. |
| Teacher requests hard delete for a student with history | Do not hard-delete from ordinary UI; direct to approved retention/privacy review. |
| Admin discovers duplicate LRN accounts | Use controlled merge/link correction preserving enrollments and history; do not simply delete one record. |
| Student is a transfer-in with prior grades | Use dedicated transferee workflow to record previous school, completed term, and verified prior grades. Do not mix this silently into ordinary bulk import. |

## 7. Security, privacy, and audit requirements

- Authenticate the actor and authorize teacher ownership on the server for every
  read and write.
- Enforce unique LRN and unique student/offering enrollment in the database.
- Treat spreadsheet content, filenames, formulas, and all cell values as
  untrusted input.
- Use parameterized database operations; do not build SQL from imported text.
- Never expose service-role credentials, generated passwords, OTPs, or Firebase
  admin credentials to Flutter or the client.
- Provision accounts through a trusted server-side path and use a secure
  first-login flow.
- Minimize visibility of cross-teacher data. Profile mismatch checks should
  return only the minimum information needed to resolve the identity.
- Audit batch ID, actor, offering ID, template version, counts, row number,
  outcome, timestamp, and recoverable error code. Restrict access to detailed
  PII in the audit record.
- Keep an explicit retention policy for uploaded spreadsheets and error
  reports. Delete temporary source files when no longer needed, subject to
  school policy.
- Make manual profile correction a separately authorized operation with
  before/after audit history.

## 8. Data and state model requirements

The implementation should use explicit states rather than success-shaped
fallbacks.

### Student identity/account

- one canonical student ID;
- unique normalized LRN;
- shared profile fields;
- account/login status separate from enrollment status; and
- first-login invitation delivery state separate from account creation.

### Enrollment

- enrollment ID;
- student ID;
- exact subject offering ID;
- status (`enrolled`, `archived`, `dropped`, `transferred`, `completed`, or
  other approved values);
- enrolled-by teacher/admin ID;
- created/updated timestamps;
- effective date and reason for lifecycle changes; and
- references/history for grades, attendance, classwork, and schedules.

### Import batch

- unique batch ID and idempotency key;
- authenticated actor and target offering ID;
- file name for display only, digest, and template version;
- created/start/completed timestamps and batch state;
- counts by classification and final outcome;
- per-row original row number, normalized LRN, status, and safe error code; and
- no passwords, OTPs, or unnecessary raw credentials.

The existing client-side resume payload is not authoritative. Persist enough
server-side state to determine which rows have actually succeeded and what can
be safely retried.

## 9. Error and empty-state behavior

All user-visible failures must explain whether data changed:

- **Validation failure:** no writes occurred; show row/field and correction.
- **Identity conflict:** no enrollment occurred for that row; explain
  verification path.
- **Already enrolled:** no write was needed; classify as a safe no-op.
- **Invitation failure:** account/enrollment may have succeeded; show separate
  invitation state and safe retry.
- **Partial batch failure:** display confirmed successes, no-ops, and failures
  independently; enable retry only for confirmed failed/recoverable rows.
- **Permission failure:** stop; do not fall back to mock or local success.
- **Network timeout with unknown outcome:** reconcile against backend before
  retry; do not tell the user “failed” if the server may have committed.
- **Roster query failure:** show error/retry, not an empty roster.
- **No enrolled students:** show a true empty state and next step to add/import.

## 10. Test plan and acceptance criteria

### Individual Add tests

- Valid new LRN creates exactly one account and one target enrollment.
- Existing matching LRN creates only an enrollment and does not change
  password/email/profile.
- Existing LRN already enrolled returns a safe no-op.
- Mismatching profile blocks without mutation.
- Invalid LRN, name, gender, birthday, age, email, and missing offering are
  rejected consistently.
- Cancel, validation error, and network failure preserve entered values.
- Teacher A cannot enroll a student into Teacher B's offering by changing an
  ID or display label.
- Account provision success followed by enrollment failure can be recovered
  without a duplicate account.

### Bulk tests

- CSV and XLSX template download, header mapping, aliases, BOM, Unicode, quoted
  commas, blank rows, reordered columns, and missing headers.
- Unsupported XLS behavior is consistent with the picker and documentation.
- Exact file-size boundary and one byte over the limit.
- Empty/corrupt/encrypted/oversized-row-count files produce no writes.
- Required fields, LRN length, duplicate-in-file, birthdays, age, gender,
  email, and row cell-count errors retain correct source row numbers.
- New account, existing account enrollment, already enrolled, archived
  enrollment, mismatch, and lookup error classifications are correct.
- Cancel review performs zero writes.
- Excluding rows imports only the rows explicitly selected.
- A preflight-to-commit race cannot create duplicate accounts/enrollments.
- Partial batch and email failures are independently reported.
- Refresh/network loss resumes only server-confirmed pending rows.
- Retrying a completed batch does not duplicate accounts, enrollments, or
  invitation messages.
- Two concurrent teachers importing the same LRN preserve global uniqueness
  and teacher isolation.

### Lifecycle and authorization tests

- Archive one enrollment preserves global account and other teacher's active
  enrollment.
- Restore conflicts remain archived and are explained.
- Cancel archive/restore makes no change.
- Unauthorized actor cannot query, import to, or mutate another teacher's
  offering.
- Hard delete is unavailable for records with academic history.
- Roster errors are not presented as empty lists or mock data.

### Release acceptance

Do not consider the feature ready until:

1. The canonical template, format support, email policy, age rule, and
   transferee scope are approved and consistent across UI, backend, and docs.
2. Unique LRN and unique offering enrollment are enforced in the deployed
   database.
3. Firebase/Supabase account provisioning and rollback/recovery behavior are
   tested without creating duplicate identities.
4. RLS or trusted backend authorization isolates teacher offerings and student
   records.
5. Batch review, idempotent processing, interruption recovery, and row-level
   reporting pass tests.
6. No path claims success after a failed or unconfirmed database write.
7. Archived and historical records remain available to authorized reports.
8. A controlled end-to-end test covers a new student, an existing student
   enrolled by another teacher, a duplicate import, a mismatch, a network
   interruption, and an invitation failure.

## 11. Recommended implementation sequence

1. Resolve the specification conflicts listed in §2.5.
2. Verify the deployed Supabase schema and current RLS policies; compare with
   migrations and the account provisioning endpoint.
3. Define typed models and status enums for account, enrollment, import batch,
   and row outcome.
4. Implement server-side LRN resolution, teacher-offering ownership checks,
   idempotency, account provisioning, enrollment, and recoverable batch state.
5. Implement shared validators and model/repository tests before UI wiring.
6. Refine the individual-add flow and its duplicate/mismatch confirmations.
7. Implement file parsing, mapping, pre-flight review, and error report.
8. Implement server-backed batch progress, resume, and retry.
9. Connect the Manage Students list, filters, archive/restore, and realtime
   refresh to authoritative enrollment-scoped data.
10. Run the acceptance matrix with two teacher accounts and separate offerings
    before production use.

## 12. Current implementation notes

The current workspace has a unified add/import dialog, CSV/XLSX parsing,
row-level validation, a pre-flight summary, and a client-side resume concept.
Those are useful UI starting points, but they do not by themselves establish
that the whole workflow is production-safe.

In the current repository, the student enrollment repository has code paths
that attempt Firebase user creation, then write Supabase records, and catch
some failures while still continuing with a generated fallback ID/local
records. That can leave Firebase, Supabase, and local state inconsistent or
make a failed save look successful. Production enrollment should use one
trusted, idempotent provisioning workflow whose confirmed outcome is returned
to the UI. Bulk resume must consult that authoritative outcome rather than
assuming a locally removed pending row means the account and enrollment were
both committed.

The current roster loader also contains a mock-data fallback after a cloud
query error. For this feature, a cloud failure must remain an explicit error;
mock data must not be shown as a real teacher roster.

These notes describe observed implementation risks, not changes made by this
plan.
