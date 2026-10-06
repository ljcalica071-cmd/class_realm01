# Class Realm Core Rules

## 1. Context & Curriculum Rules
* **Curriculum Pattern**: The system follows a new curriculum. Subjects are taken across all **3 Terms (Trimesters)** automatically. Do not ask the user/teacher to select a specific term/semester or strand.
* **School Year (SY)**: The active School Year is dictated by the global dashboard state. It should not be an editable dropdown in teacher forms.

## 2. Grading & Assessment Rules
* **Grading Components**: Grades are always composed of **WW** (Written Work), **PT** (Performance Task), and **EX** (Exam/Quarterly Assessment).
* **Weight Validation**: The sum of WW + PT + EX must **always equal exactly 100%**. Inputs must be strictly numeric, non-negative, and maximum 2 digits (0-99).

## 3. UI Validation & Constraints
* **Template/Subject Selectors**: Do not use standard Dropdowns for long lists. Use an `AppButton` or `InkWell` that opens an `AlertDialog` containing a Search `TextField`.
* **Subject Name**: Minimum 2, Maximum 60 characters. Auto-trim spaces. Max 10 subjects per teacher.
* **Section Name**: Minimum 2, Maximum 30 characters. Auto-trim spaces. Max 10 sections per subject.

## 4. Database & Supabase Conventions
* **Analysis Before Changes**: Always scan and analyze the **complete existing Supabase schema** (including foreign key relationships) before proposing table modifications or drops.
* **Replacement Safety**: Ensure that new tables properly replace and map to existing workflows (e.g., student enrollments, schedules) without breaking the system's core relationships to `users`, `teacher_info`, or `student_info`.
* **Normalization**: Tables must be strictly normalized. Do not create overlapping or duplicate columns without a clear architectural reason.
* **Deletion Logic**: 
  * Soft Delete: Use `archived_at` timestamp columns for soft deletes/archiving (so data can be recovered).
  * Permanent Delete: Use `ON DELETE CASCADE` on foreign keys so that when a parent record is permanently deleted, all child records (files, grades, attendance) are cleanly wiped without leaving orphan data.
* **Clean Slate**: Never mix old dummy/template table structures with new production schemas. Use `DELETE FROM table_name;` to wipe rows if the user wants to empty a table while preserving the existing connections. Only use structural drops (`DROP TABLE`) when the architecture itself is being rebuilt and the user has explicitly approved dropping tables.

## 5. Authentication & Production Readiness
* **Real Authentication Enforcement**: Admin and Teacher accounts use **REAL Firebase authentication**. Do not revert them to mock data or bypass logic. (For testing the teacher account, use `Uzumaki123`).
* **Final Cleanup Goal**: Once the Student and Parent modules are fully implemented with real Supabase data and Firebase auth, the "Developer Quick Login" buttons and all mock bypass logic must be completely removed from the login screen.
* **Dashboard Personalization**: The Student and Parent sides must not use hard-coded prototype data. Just like the Teacher dashboard, they must fetch and display data uniquely associated with the logged-in user's credentials from Supabase.
