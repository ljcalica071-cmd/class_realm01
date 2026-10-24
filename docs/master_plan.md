# ClassRealm Master Plan — Student Enrollment & Management

## 1. Overview & Architectural Boundaries

Student enrollment in ClassRealm is dual-mode:
1. **Manual Single Student Enrollment:** Interactive form with instant validation, auto-calculated age, and duplicate checking.
2. **Bulk File Import (CSV & Excel):** Spreadsheet-driven enrollment designed for rapid whole-class onboarding, supporting pre-flight integrity analysis, resumable batch processing, and detailed error auditing.

All enrollments require an authoritative connection to a specific `subject_offering_id` (Grade Level + Subject + Section).

---

## 2. Bulk Upload Specifications & Template Schema

### Supported File Formats & Limits
- **Allowed Formats:** Standard CSV (`.csv`) and modern Excel spreadsheet (`.xlsx`).
- **File Size Ceiling:** Strict maximum of **5 MiB (5,242,880 bytes)**.
- **Upload Rate Limit:** Max 3 file uploads per minute per teacher.

### Official Template Column Order
| Column Header | Required | Format / Rules | Description |
|---|---|---|---|
| `LRN` | **Yes** | Exactly 12 numeric digits | DepEd Learner Reference Number |
| `Email` | **Yes** | Valid RFC 5322 email syntax | Student's school or personal email |
| `Last Name` | **Yes** | Min 2 characters, letters only | Student surname |
| `First Name` | **Yes** | Min 2 characters, letters only | Student given name |
| `Middle Name` | *No* | Optional letters | Student middle name |
| `Gender` | **Yes** | `Male` or `Female` (case-insensitive) | Student gender identity |
| `Birthday` | **Yes** | `YYYY-MM-DD` (e.g. `2007-06-19`) | Date of birth; Age is auto-calculated |

---

## 3. Comprehensive What-If Scenarios & Recovery Workflows

### Scenario 1: Network Loss or Accidental Refresh During Batch Enrollment
- **Problem:** A teacher is importing 45 students. At student 20, the school Wi-Fi drops or the teacher accidentally reloads the page.
- **System Defense & Recovery:**
  - Before starting execution, the system saves a local staging session into `SharedPreferences` under `batch_enroll_session_{offeringId}` containing the target offering, original filename, total count, list of completed LRNs, and list of remaining pending student objects.
  - As each student is successfully enrolled in the database, the local pending list is updated.
  - If the process is abruptly terminated, the remaining un-enrolled students are preserved in local storage.
  - When the teacher re-opens the enrollment modal for that section, the UI detects the interrupted session and displays a prominent **"Interrupted Import Session"** banner:
    > *"Interrupted Import Session Found: 25 students remaining from previous upload. [Resume Enrollment] [Discard]"*
  - Clicking **Resume** continues enrolling from student 21 onwards without requiring the teacher to re-upload the file or start over.

### Scenario 2: Duplicate LRNs Inside the Same File
- **Problem:** The teacher accidentally copy-pasted a row, or a student is listed twice in the CSV.
- **System Defense:**
  - Pre-flight scanner maintains a `Set<String> seenLrns`.
  - The second occurrence is flagged as `Duplicate LRN in this import file` and routed to the Invalid Rows report with its row number.
  - The teacher is shown the count of duplicates and can review them before choosing whether to proceed with valid rows.

### Scenario 3: LRN Already Enrolled or Exists in Database
- **Problem:** The student is already registered in ClassRealm or enrolled in another section of the subject.
- **System Defense:**
  - The repository's `enrollStudent` method checks if the student account exists:
    - If the account exists and is already enrolled in the exact same `subject_offering_id`, it is reported in the final summary as *Already Enrolled*.
    - If the student exists in another class/strand, their profile is reused and safely enrolled into the target offering without creating duplicate auth accounts.

### Scenario 4: Email Domain Typos & Common Misspellings
- **Problem:** A student or teacher wrote `user@gamil.com`, `user@yaho.com`, or `user@gmail.con`.
- **System Defense:**
  - Domain regex pattern checks for known common typos (`@(gamil\.com|yaho\.com|gmail\.con|gmal\.com|yahoo\.con)$`).
  - In manual entry, prompts with an interactive dialog: *"Did you mean @gmail.com?"*.
  - In bulk upload, warns the teacher in the pre-flight report so typo-riddled emails are caught before auth provisioning.

### Scenario 5: Missing or Misordered Column Headers
- **Problem:** The CSV/Excel file has headers in a different order or missing required columns.
- **System Defense:**
  - Column matching is case-insensitive and supports standard aliases (e.g. `birthdate`, `dob`, `sex`, `surname`, `student id`).
  - If a mandatory header (LRN, Email, First Name, Last Name, Gender, Birthday) is missing entirely, the import halts with a user-friendly modal detailing exactly which columns are missing and providing a direct link to download the official template.

### Scenario 6: Student Under Minimum Age Requirement
- **Problem:** An accidental typo entered birthday as `2024-05-10` (student is 2 years old).
- **System Defense:**
  - Dynamic age calculation validates that student is at least 10 years old.
  - In single student mode, the Age field displays "Auto" and updates dynamically as the teacher picks a date; if age < 10, inline red validation triggers: *"Must be at least 10 yrs old."*
  - In bulk upload, rows with invalid birthdates or age < 10 are flagged in the pre-flight report.

### Scenario 7: Unsupported File Formats & Oversized Uploads
- **Problem:** The user attempts to drag-and-drop a PDF, Word document, or a huge 25MB file.
- **System Defense:**
  - Allowed extensions are strictly filtered to `.csv` and `.xlsx`.
  - Any other file format is immediately rejected with a clean dialog: *"Unsupported File Format: Only CSV (.csv) and Excel (.xlsx) files are accepted."*
  - File size is checked before parsing; files exceeding 5MB trigger an instant alert: *"File Too Large: Maximum allowed size is 5 MB."*

### Scenario 8: Interactive Dropzone with Marching Ants Animation
- **UX Requirement:**
  - The large dropzone box in the Import tab has no redundant "Choose File" button.
  - When the cursor hovers over the dropzone, an animated rotating dashed border ("marching ants") continuously circles the box at 60fps to signal clickability.
  - When the cursor moves away, the border smoothly reverts to a solid outline.

---

## 4. UI/UX Standards Alignment (/ui-ux-pro-max)

1. **Button Geometry Harmony:**
   - Both "Cancel" and "Enroll Student" action buttons share the exact same `BorderRadius.circular(10)` token, eliminating mismatched pill shapes.
2. **Symmetrical Form Layout:**
   - Top Details Row: `Birthday *` (date picker) + `Age` (auto-calculated read-only) + `Gender *` (dropdown).
   - Bottom Details Row: `LRN (12-digit DepEd ID) *` + `Email Address *`.
   - Symmetrical heights, consistent 12-14px internal padding, and clear contrast.
