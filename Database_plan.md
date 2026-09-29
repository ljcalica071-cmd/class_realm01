# ClassRealm — Database Plan & Optimization Rules

> **Document Type:** System Architecture & Best Practices
> **Project:** ClassRealm (Hybrid: Supabase PostgreSQL + Firebase)
> **Target Audience:** Backend Developers & Database Administrators

---

## 1. Hybrid Storage Strategy
1. **Relational Data goes to Supabase:** Use PostgreSQL for structured data with relationships (Users, Enrollments, Grades, Schedules, Attendance).
2. **Authentication goes to Firebase Auth:** Handle all login, session tokens, and password hashing via Firebase. Use Firebase UID as the primary key reference in Supabase.
3. **Binary Files go to Firebase Storage:** Profile pictures, PDF modules, and image submissions must be stored in Firebase Storage. Only save the download URL in Supabase.
4. **Offline Queue via Local Storage:** Use Hive/SQLite for offline caching. Hardware (RFID) or mobile apps must write locally first, then sync to Supabase when online.

## 2. Table Design & Normalization (3NF)
5. **Enforce 3NF (Third Normal Form):** Eliminate duplicate data. Do not store student names in the `grades` table; only store the `student_id` and `subject_id`.
6. **Use UUIDs as Primary Keys:** All tables should use UUID `gen_random_uuid()` instead of auto-incrementing integers to prevent ID-guessing attacks and make offline syncing easier.
7. **Soft Deletes Only:** Never use `DELETE`. Add an `is_archived` (boolean) column to tables like `sections` and `subjects`. This preserves historical grading data.
8. **Audit Trails:** Every major table must have `created_at` and `updated_at` timestamps. Update `updated_at` automatically via PostgreSQL triggers.

## 3. Data Integrity & Constraints
9. **Foreign Key Cascades:** Be careful with `ON DELETE CASCADE`. Only use it for dependent child data (e.g., deleting a quiz deletes its quiz_items). For critical records (students/teachers), use `ON DELETE RESTRICT`.
10. **Unique Constraints:** Prevent duplicates. The `lrn` column in the students table must be `UNIQUE`. The combination of `teacher_id`, `subject_id`, and `section_id` in schedules must be `UNIQUE`.
11. **Check Constraints:** Use constraints to prevent bad data (e.g., `CHECK (grade >= 0 AND grade <= 100)` or `CHECK (hps > 0)` for Highest Possible Score).

## 4. Query Optimization & Indexing
12. **Index Frequent Lookups:** Add B-Tree indexes on columns used in `WHERE` and `JOIN` clauses (e.g., `student_id`, `section_id`, `teacher_id`).
13. **Avoid SELECT *:** Always specify the exact columns needed (`SELECT id, name FROM users`) to reduce bandwidth and memory usage, especially for mobile clients.
14. **Pagination for Large Lists:** Use `LIMIT` and `OFFSET` for lists like attendance logs or system notifications to avoid crashing the app with massive payloads.

## 5. Security & Access Control
15. **Enable Row Level Security (RLS):** Supabase RLS must be enabled on ALL tables. A student should only be able to `SELECT` their own grades. A teacher can only `SELECT` students in their assigned sections.
16. **No Client-Side Trust:** Never trust computations sent from the frontend. If the frontend says the grade is 95, the backend must recalculate the WW, PT, and EX scores to verify.
17. **Role-Based Access Control (RBAC):** Create a `roles` enum (`admin`, `teacher`, `student`, `parent`) and use it in RLS policies to restrict `INSERT` and `UPDATE` commands.

## 6. Offline & Hardware Syncing
18. **Idempotency for Sync:** When the RFID ESP32 hardware uploads offline attendance logs, ensure the endpoint is idempotent. If it sends the same log twice, the database should gracefully ignore the duplicate using `ON CONFLICT DO NOTHING`.
19. **Batch Processing:** When syncing offline data, use batch inserts instead of looping single inserts to reduce database round-trips.

## 7. Performance Monitoring
20. **Monitor Table Bloat:** Regularly run `VACUUM` on highly updated tables (like real-time attendance or live assessment monitoring) to reclaim space and maintain query speed.

---

# DATA SCHEMA & PLATFORM ALLOCATION
> **Execution Priority (Alin ang unang ise-setup?):**
> 1. **Firebase Authentication (UNA):** Kailangan ito unahin dahil lahat ng users ay bibigyan ng unique `UID` ng Firebase. Ang UID na ito ang gagamitin nating Primary Key (ID) sa lahat ng tables sa Supabase.
> 2. **Supabase PostgreSQL (PANGALAWA):** Dito ilalagay ang lahat ng relational tables sa ibaba na nakadugtong sa Firebase UID.
> 3. **Firebase Storage (PANGATLO):** Para sa mga profile pictures, forms, at lesson files.
> 4. **Local Storage / Hive (PANG-APAT):** Ise-setup lang ito sa huli kapag gagawin na natin ang "Offline Mode" ng mobile app at RFID hardware.

---

## A. FIREBASE (Authentication & Storage)
Wala tayong gagawing tables dito dahil NoSQL at pre-built ang Firebase para dito.
1. **Firebase Auth:** Mag-i-istore ng Email, Password (hashed), at magbibigay ng `Firebase_UID`.
2. **Firebase Storage:** Mag-i-istore ng Binary Files. Mga return values lang (like `https://firebasestorage.../profile.jpg`) ang ise-save natin papunta sa Supabase.

---

## B. SUPABASE POSTGRESQL (Relational Database)
*Ito ang mga SQL tables na gagawin natin. Lahat ay naka-3NF at hiwalay ang First/Last/Middle name na may strict character limits.*

### 1. Core Users & Profiles
**Table: `users`** *(Central record ng system)*
*   `id` : `UUID` (Primary Key, **Tugma sa Firebase UID**)
*   `role` : `VARCHAR(20)` (Enum: 'teacher', 'admin', 'student', 'parent')
*   `is_active` : `BOOLEAN` (Default: TRUE)
*   `created_at` : `TIMESTAMPTZ`

**Table: `teacher_profiles`**
*   `id` : `UUID` (Primary Key -> `users.id`)
*   `employee_id` : `VARCHAR(50)` (Unique)
*   `first_name` : `VARCHAR(30)` (Required)
*   `last_name` : `VARCHAR(30)` (Required)
*   `middle_name` : `VARCHAR(30)` (Optional)
*   `department` : `VARCHAR(100)`
*   `is_setup_complete` : `BOOLEAN` (Default: FALSE)

**Table: `student_profiles`**
*   `id` : `UUID` (Primary Key -> `users.id`)
*   `lrn` : `VARCHAR(12)` (Unique, Required, Exactly 12 chars limit)
*   `first_name` : `VARCHAR(30)`
*   `last_name` : `VARCHAR(30)`
*   `middle_name` : `VARCHAR(30)`
*   `gender` : `VARCHAR(6)` (Enum: 'Male', 'Female')
*   `birth_date` : `DATE`
*   `status` : `VARCHAR(20)` (Enum: 'Pending', 'PendingFirstLogin', 'Active', 'Dropped', 'Transferred', 'Archived')

**Table: `parent_profiles`**
*   `id` : `UUID` (Primary Key -> `users.id`)
*   `first_name` : `VARCHAR(30)`
*   `last_name` : `VARCHAR(30)`
*   `middle_name` : `VARCHAR(30)`
*   `contact_number` : `VARCHAR(11)` (Must start with '09' format)

### 2. Academic Setup (Setup Wizard Data & Templates)
**Table: `subject_catalog`** *(The Global Template for Subjects based on DepEd Strengthened SHS)*
*   `id` : `UUID` (Primary Key)
*   `category` : `VARCHAR(20)` (e.g., 'SSHS - CORE', 'SSHS - ACADEMIC', 'SSHS - TECH-PRO')
*   `cluster` : `VARCHAR(60)` (e.g., 'CORE', 'ARTS, SOCIAL SCIENCES, AND HUMANITIES')
*   `name` : `VARCHAR(100)` (e.g., 'General Mathematics', 'Earth and Life Science')
*   `grade_level` : `INTEGER` (11 or 12)
*   `no_terms_taught` : `INTEGER` (Default: 3)
*   `units_per_term` : `NUMERIC(4,2)` (Default: 2)
*   `units_per_year` : `NUMERIC(4,2)` (Default: 6)
*   `default_ww_weight` : `NUMERIC(5,2)` (e.g. 20.00, 15.00)
*   `default_pt_weight` : `NUMERIC(5,2)` (e.g. 50.00, 65.00)
*   `default_ex_weight` : `NUMERIC(5,2)` (e.g. 30.00, 20.00)

**Table: `sections`**
*   `id` : `UUID` (Primary Key)
*   `name` : `VARCHAR(50)`
*   `grade_level` : `INTEGER` (11 or 12)
*   `curriculum_type` : `VARCHAR(20)` (Enum: 'Strengthened SHS (New)', 'Old Curriculum')
*   `adviser_id` : `UUID` (Foreign Key -> `teacher_profiles.id`, Optional)
*   `school_year` : `VARCHAR(20)`

**Table: `schedules`** *(Saan tuturo ang teacher)*
*   `id` : `UUID` (Primary Key)
*   `teacher_id` : `UUID` (Foreign Key -> `teacher_profiles.id`)
*   `section_id` : `UUID` (Foreign Key -> `sections.id`)
*   `subject_id` : `UUID` (Foreign Key -> `subject_catalog.id`)
*   `day_of_week` : `INTEGER` (1=Mon, 7=Sun)
*   `start_time` : `TIME` (e.g., '07:30:00')
*   `end_time` : `TIME` (e.g., '09:00:00')
*   `room` : `VARCHAR(30)`

### 3. Enrollments & Connections
**Table: `enrollments`** *(Sinong bata ang nasa anong section? Bawal mag-transfer once set!)*
*   `id` : `UUID` (Primary Key)
*   `student_id` : `UUID` (Foreign Key -> `student_profiles.id`)
*   `section_id` : `UUID` (Foreign Key -> `sections.id`)

**Table: `parent_student_link`** *(Sinong parent ang naka-link sa bata?)*
*   `parent_id` : `UUID` (Foreign Key -> `parent_profiles.id`)
*   `student_id` : `UUID` (Foreign Key -> `student_profiles.id`)
*   `relationship` : `VARCHAR(15)` (Mother, Father, Guardian, etc.)

### 4. Gradebook System
**Table: `gradebook_settings`** *(Kung custom, dito nakasave, kung old curriculum)*
*   `id` : `UUID` (Primary Key)
*   `schedule_id` : `UUID` (Foreign Key -> `schedules.id`)
*   `ww_weight` : `NUMERIC(5,2)`
*   `pt_weight` : `NUMERIC(5,2)`
*   `ex_weight` : `NUMERIC(5,2)`

**Table: `grade_items`** *(Quiz 1, Exam, etc.)*
*   `id` : `UUID` (Primary Key)
*   `schedule_id` : `UUID` (Foreign Key -> `schedules.id`)
*   `term` : `INTEGER` (1, 2, or 3)
*   `component_type` : `VARCHAR(10)` (Enum: 'WW', 'PT', 'ST1', 'ST2', 'TE')
*   `name` : `VARCHAR(100)`
*   `highest_possible_score` : `NUMERIC(7,2)`

**Table: `grades`** *(Mga mismong score)*
*   `id` : `UUID` (Primary Key)
*   `grade_item_id` : `UUID` (Foreign Key -> `grade_items.id`)
*   `student_id` : `UUID` (Foreign Key -> `student_profiles.id`)
*   `raw_score` : `NUMERIC(7,2)` (NULL kapag excused/blank)

### 5. Attendance (Online Server)
**Table: `attendance_records`**
*   `id` : `UUID` (Primary Key)
*   `schedule_id` : `UUID` (Foreign Key -> `schedules.id`)
*   `student_id` : `UUID` (Foreign Key -> `student_profiles.id`)
*   `date` : `DATE`
*   `status` : `VARCHAR(20)` (Enum: 'Present', 'Absent', 'Late', 'Excused')
*   `time_in` : `TIMESTAMPTZ`

---

## C. LOCAL STORAGE (Hive / SQLite sa Flutter App)
*Dito natin ita-temporary save yung data kapag WALANG INTERNET ang teacher o ang RFID scanner. Kapag nagka-wifi na, ipu-push niya ito sa Supabase.*
1. **`offline_attendance_queue`:** Listahan ng mga na-scan ng RFID na hindi pa napapadala sa Supabase.
2. **`cached_schedules`:** Para mabuksan ni teacher ang schedule niya ngayong araw kahit naka-airplane mode ang phone.
