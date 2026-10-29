# Backend & Database Architecture Survey Report
**Project:** ClassRealm Attendance Feature Overhaul  
**Date:** 2026-10-29  
**Agent:** `teamwork_explorer` (Survey Phase — Backend & Database Architecture)  
**Working Directory:** `c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\explorer_survey_1`  
**Reference Document:** `c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\ORIGINAL_REQUEST.md`

---

## 1. Observation

Direct, verbatim findings across the ClassRealm codebase (`c:\Users\Admin\AndroidStudioProjects\class_realm01`):

### 1.1 Existing Supabase Database Schema & Migrations
Located in `supabase/migrations/`:
- `001_initial_schema.sql` (2,266 lines)
- `002_supabas.sql` (534 lines)
- `005_enterprise_rate_limits_and_otp.sql` (95 lines)
- `006_performance_indexes.sql` (52 lines)
- `007_cleanup_logout_reasons.sql` (15 lines)

#### Key Tables Directly Observed:
1. **`users`** (`001_initial_schema.sql:36-56`):
   - `id varchar(30) PRIMARY KEY` (Stores Firebase Auth UID directly).
   - `email varchar(100) NOT NULL UNIQUE (lower(email))`.
   - `role varchar(10) CHECK (role IN ('admin', 'teacher', 'student', 'parent'))`.
   - `is_archived boolean NOT NULL DEFAULT false`.

2. **`student_profiles`** (`001_initial_schema.sql:173-200`, `002_supabas.sql:47-58`):
   - `student_id varchar(30) PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE`.
   - `lrn varchar(12) NOT NULL UNIQUE`.
   - `first_name varchar(30) NOT NULL`.
   - `middle_name varchar(30)`.
   - `last_name varchar(30) NOT NULL`.
   - `birthday date NOT NULL`.
   - `gender varchar(6) CHECK (gender IN ('Male', 'Female'))`.
   - **Critical Observation:** `student_profiles` **does NOT possess** an `rfid_uid` or card identifier column. There is no existing unique index or field for hardware card registration.

3. **`parent_profiles` & `parent_student_links`** (`002_supabas.sql:68-89`):
   - `parent_profiles(parent_id varchar(30) PRIMARY KEY REFERENCES users(id), first_name, last_name, contact_number, status)`.
   - `parent_student_links(parent_id varchar(30) REFERENCES parent_profiles(parent_id), student_id varchar(30) REFERENCES student_profiles(student_id), relationship varchar NOT NULL, PRIMARY KEY (parent_id, student_id))`.

4. **`teacher_schedule`** (`001_initial_schema.sql:632-664`, `002_supabas.sql:162-173`):
   ```sql
   CREATE TABLE public.teacher_schedule (
       id uuid NOT NULL DEFAULT gen_random_uuid(),
       subject_offering_id uuid NOT NULL REFERENCES public.subject_offerings(id) ON DELETE CASCADE,
       day_of_week smallint NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
       start_time time without time zone NOT NULL,
       end_time time without time zone NOT NULL,
       room varchar(50),
       is_active boolean NOT NULL DEFAULT true,
       created_at timestamptz NOT NULL DEFAULT now(),
       CONSTRAINT teacher_schedule_pkey PRIMARY KEY (id),
       CONSTRAINT teacher_schedule_valid_time CHECK (end_time > start_time)
   );
   ```
   - **Critical Observation:** `teacher_schedule` defines weekly recurring classes (1=Monday ... 7=Sunday). It **does NOT possess** any cutoff threshold columns (e.g., `present_cutoff`, `late_cutoff`, `absent_cutoff`), nor does any dedicated cutoff table exist.

5. **`attendance_records`** (`001_initial_schema.sql:681-741`, `002_supabas.sql:174-188`):
   ```sql
   CREATE TABLE public.attendance_records (
       id uuid NOT NULL DEFAULT gen_random_uuid(),
       student_id varchar(30) NOT NULL REFERENCES public.student_profiles(student_id) ON DELETE RESTRICT,
       subject_offering_id uuid NOT NULL REFERENCES public.subject_offerings(id) ON DELETE RESTRICT,
       attendance_date date NOT NULL,
       status varchar(10) NOT NULL CHECK (status IN ('present', 'absent', 'late', 'excused')),
       remarks varchar(100),
       recorded_by varchar(30) REFERENCES public.users(id) ON DELETE RESTRICT,
       created_at timestamptz NOT NULL DEFAULT now(),
       CONSTRAINT attendance_records_pkey PRIMARY KEY (id),
       CONSTRAINT attendance_records_unique_record UNIQUE (student_id, subject_offering_id, attendance_date)
   );
   ```
   - **Critical Observation:** `attendance_records` **lacks**:
     - `recording_method` / `source` column (differentiating 'RFID' vs 'Manual' vs 'System').
     - `scanned_at` / `time_in` timestamp (only `attendance_date` date exists; no scan clock time is stored).
     - `device_id` column (for ESP32 hardware device or mobile scanner auditing).

6. **School Holidays / Academic Calendar Exceptions:**
   - **Critical Observation:** No `school_holidays` or calendar exception table exists anywhere in the database schema.

7. **Row Level Security (RLS) Status:**
   - In `005_enterprise_rate_limits_and_otp.sql:72-73`, RLS is enabled ONLY for `auth_rate_limits` and `password_reset_otps`.
   - In `001_initial_schema.sql` and `002_supabas.sql`, `attendance_records`, `student_profiles`, `student_enrollments`, and `parent_student_links` **DO NOT have RLS enabled**.
   - `SupabaseService` (`lib/core/services/supabase_service.dart:9-14`) initializes Supabase using `EnvConfig.supabaseAnonKey`.
   - No Supabase Auth login occurs in Flutter; authentication is handled solely by Firebase Auth (`FirebaseAuth.instance.currentUser`).

8. **Cron Jobs & Edge Functions:**
   - `supabase/config.toml:2` explicitly states: `# All backend logic, CRUD operations, caching, and emails have been migrated to 100% Pure Dart in lib/.`
   - There are **ZERO existing cron jobs, triggers, pg_cron tasks, or Supabase Edge Functions** in the project repository.
   - The current "auto-absent" feature is an in-memory client-side visual simulation executed inside `teacher_attendance_tab.dart:310-327` (`if (isPastDay || isTodayPast8Pm)`) and does not run server-side.

---

### 1.2 Current Flutter / Dart Data Models
1. **`AttendanceWorkspaceRecord`** (`lib/models/attendance_workspace_models.dart:25-77`):
   - Fields: `id`, `studentId`, `subjectOfferingId`, `attendanceDate`, `status` (`AttendanceStatus`), `source` (`AttendanceSource`), `remarks`, `recordedBy`, `createdAt`, `modifiedBy`.
   - `AttendanceSource` enum (`lib/models/attendance_workspace_models.dart:5-23`): values `manual`, `rfid`.
   - In `SupabaseAttendanceRepository:94`, `source: AttendanceSource.manual` is hardcoded when fetching records from Supabase because Supabase does not have the column.
   - In `saveAttendanceBatch` (`lib/data/repositories/supabase_attendance_repository.dart:167-175`), `source` is stripped and omitted during insert because the column does not exist on Supabase.

2. **`AttendanceRecord` (Legacy Academic Model)** (`lib/models/academic_models.dart:20-46`):
   - Fields: `id`, `studentId`, `studentName`, `section`, `date`, `timeIn`, `timeOut`, `remarks`, `status`, `method` (`String`, default `'Manual'`), `isSynced`.
   - In `SupabaseAttendanceRepository:452, 520, 581`, the `method` field was overloaded to display subject names (e.g. `method: subject`)!
   - In `student_attendance_screen.dart:257`, it renders: `Text('Class: ${record.method}')`.
   - In `parent_attendance_tab.dart:100`, it renders: `Text('Method: ${att.method}')`.

3. **`AttendanceRosterStudent`** (`lib/models/attendance_workspace_models.dart:243-291`):
   - Fields: `studentId`, `firstName`, `middleName`, `lastName`, `gender`.
   - Missing: `rfidUid` (cannot currently display linked RFID badge status in the roster).

4. **`ScheduleModel`** (`lib/models/academic_models.dart:700-731`):
   - Fields: `id`, `subject`, `section`, `room`, `dayOfWeek` (`String`), `startTime` (`"HH:MM AM/PM"`), `endTime`, `sectionId`, `subjectId`, `teacherId`, weights.
   - Weekday mapping: `ScheduleModel.dayOfWeekIndex` (1=Monday ... 7=Sunday), aligned with Dart `DateTime.weekday` and PostgreSQL `day_of_week`.

5. **Local Drift SQLite Database** (`lib/data/datasources/local/tables.dart`):
   - `LocalStudents` (`lines 79-90`): `studentId`, `lrn`, `firstName`, `middleName`, `lastName`, `gender`, `departmentOrSection`. (Missing `rfidUid`).
   - `LocalAttendanceRecords` (`lines 129-142`): `id`, `studentId`, `subjectOfferingId`, `attendanceDate`, `status`, `remarks`, `source`, `recordedBy`, `syncStatus`. (Has `source`, missing `scannedAt`/`timeIn`, `deviceId`).
   - `LocalSchedules` (`lines 144-155`): `id`, `subjectOfferingId`, `teacherId`, `dayOfWeek`, `startTime`, `endTime`, `room`.

---

### 1.3 How Schedules Are Defined, Plotted, and Queried
- **Definition & Querying:**
  - `SupabaseScheduleRepository.getSchedules({String? teacherId, String? section})` (`lib/data/repositories/supabase_schedule_repository.dart:150-217`) queries `teacher_schedule` joined with `subject_offerings`, `subjects`, and `sections`.
  - Filtered by `subject_offerings.teacher_id = teacherId` and ordered by `day_of_week` and `start_time`.
  - Clash detection is implemented in `validateClash(...)` (`lines 220-310`) to prevent overlapping schedules for the same teacher or same section on the same `day_of_week`.
- **Current Attendance Tab Interaction:**
  - In `teacher_attendance_tab.dart`, the teacher selects Grade Level, Subject, Section (`subject_offering_id`), and Date (`_attendanceSelectedDate`).
  - **Critical Flaw:** The attendance tab **does not query `teacher_schedule`** prior to unlocking attendance recording. A teacher can mark attendance or tap RFID cards on ANY day of the week, even if the class is not scheduled on that date.

---

### 1.4 Current RFID & Hardware Scanning Code
In `teacher_attendance_tab.dart:530-580`:
- Uses `KeyEvent` via `_handleHardwareKey(KeyEvent event)` listening on `_scannerFocusNode`.
- Captures characters into `_rfidBuffer` until `LogicalKeyboardKey.enter`.
- In `_processScannedRfid`:
  ```dart
  final studentIndex = _rosterStudents.indexWhere(
    (s) => s.studentId.toLowerCase() == cleanId || 
           (s.studentId.contains(cleanId) && cleanId.length > 5)
  );
  ```
  It attempts to match the scanned string against the student's primary Firebase ID or LRN!
- It displays a `SnackBar` for feedback (`lines 564-578`), which explicitly violates Requirement R7.
- It sets `_tempAttendanceStates[student.studentId] = AttendanceStatus.present` in memory, but when saved, `source` is hardcoded to `AttendanceSource.manual` (`line 476`).

---

### 1.5 Student and Parent Attendance Views
- **Student App (`student_attendance_screen.dart`):**
  - Calls `getMyAttendanceSummary()` and `getMyAttendancePage(offset, pageSize)` on `SupabaseAttendanceRepository`.
  - Filters by `.eq('student_id', user.uid)` in client queries.
  - Contains `SnackBar` error handlers on lines 93-98 (violates R7).
  - Empty state is a basic unstyled `Text('No attendance records found.')` (line 196).
- **Parent App (`parent_home_screen.dart` & `parent_attendance_tab.dart`):**
  - In `parent_home_screen.dart:184`, the tab is instantiated with:
    `const ParentAttendanceTab(attendance: [])`
    **Parent attendance fetching is completely unpopulated/dead code.**
  - `ParentAttendanceTab` displays an unstyled `Center(child: Text('No attendance records found.'))` and displays `Text('Method: ${att.method}')`.

---

## 2. Logic Chain

From the observed facts to the necessary architectural conclusions:

```
[Observation: student_profiles has only student_id and lrn]
   │
   ├─► [Logic Step 1]: RFID cards emit unique physical UIDs (4-byte or 7-byte hexadecimal strings).
   │   Because students cannot be scanned by hardware without associating this hardware UID,
   │   and R2 mandates duplicate conflict detection, student_profiles MUST store rfid_uid
   │   with a UNIQUE database constraint.
   ▼
[Observation: attendance_records lacks source, time_in, device_id]
   │
   ├─► [Logic Step 2]: R2 mandates an explicit indicator in logs distinguishing "RFID" from "Manual".
   │   R3 mandates cutoff evaluation based on scan clock time. R4 mandates dual-path capture
   │   (ESP32 vs Mobile NFC). Therefore, attendance_records MUST store recording_method ('RFID', 'Manual', 'System'),
   │   time_in (or scanned_at timestamptz), and device_id.
   ▼
[Observation: teacher_schedule has start_time and end_time, but NO cutoff rules]
   │
   ├─► [Logic Step 3]: R3 requires teacher-configurable cutoffs for Present, Late, and Absent
   │   with chronological validation (Present window starts at/before start; Late is strictly
   │   after Present; Absent is strictly after Late and within class hours).
   │   A new table `attendance_cutoffs` (or direct schedule columns) is required, bound to
   │   teacher_schedule or subject_offering_id with strict CHECK constraints.
   ▼
[Observation: No school holiday table exists; zero existing cron jobs or edge functions]
   │
   ├─► [Logic Step 4]: R3 mandates a 23:59 daily backend job marking unscanned students as Absent
   │   ONLY for active scheduled classes on that date, never on rest days, and never on holidays.
   │   Therefore:
   │   1. A `school_holidays` table must be introduced.
   │   2. A PostgreSQL stored procedure `fn_trigger_daily_auto_absent()` must query active schedules
   │      for EXTRACT(ISODOW FROM date), check holidays, find unscanned enrolled students,
   │      and insert 'absent' records without overwriting existing marks.
   │   3. A scheduled trigger (via pg_cron or Supabase Edge Function) must invoke this at 23:59 Asia/Manila.
   ▼
[Observation: Supabase client uses anonKey; no Supabase Auth session; RLS disabled on records]
   │
   ├─► [Logic Step 5]: R6 mandates Student and Parent apps be strictly scoped via RLS to their own
   │   or their linked child's records.
   │   Because Firebase Auth is used, the Firebase JWT or verified UID must be recognized by Supabase:
   │   - Strategy A: Pass Firebase JWT in Supabase headers and read `auth.jwt() ->> 'sub'` in RLS.
   │   - Strategy B: Postgres SECURITY DEFINER RPC functions / View scoping keyed to authenticated UID.
   │   In both strategies, RLS policies on `attendance_records` MUST isolate student reads to
   │   `student_id = auth_uid` and parent reads to `student_id IN (SELECT student_id FROM parent_student_links WHERE parent_id = auth_uid)`.
   ▼
[Observation: SnackBars used in teacher, student, and parent views]
   │
   └─► [Logic Step 6]: R7 strictly prohibits SnackBars, toasts, and top/bottom banners.
       All validation feedback, RFID conflict notices, and network alerts must use Inline Errors
       (under input fields) or Modal Dialogs (for hardware/scanner/conflict alerts).
```

---

## 3. Caveats

1. **Firebase Auth vs Supabase Auth Integration:**
   The application uses Firebase Auth for user identity and Supabase PostgreSQL for application data. In standard Supabase setups, `auth.uid()` resolves against Supabase Auth. Because ClassRealm stores Firebase UIDs in `public.users.id`, Supabase RLS policies must inspect the JWT claim `auth.jwt() ->> 'sub'` (when Firebase JWT is forwarded) or use PostgreSQL session settings (`current_setting('request.jwt.claims', true)::jsonb ->> 'sub'`). Both configurations are fully specified below.
2. **PostgreSQL pg_cron vs Supabase Edge Function:**
   In Supabase Cloud, `pg_cron` runs on UTC. 23:59 in the Philippines (UTC+8 / Asia/Manila) corresponds to **15:59 UTC**. If using `pg_cron`, the cron expression must be `59 15 * * *` (or the database timezone must be set to `Asia/Manila`). If using a Supabase Edge Function, the cron trigger in `supabase/config.toml` or scheduled HTTP webhook must account for this offset.
3. **Legacy Data Compatibility:**
   Existing `attendance_records` rows have `status` and `attendance_date`, but null `remarks` and no `recording_method` or `time_in`. When applying schema migrations, existing records must default to `recording_method = 'Manual'` with `time_in = NULL` without causing migration failure or breaking tests.

---

## 4. Conclusion & Required Specifications

### 4.1 Schema Evolution: Current vs Required Additions

| Entity | Current Schema | Required Additions / Evolutions | Requirement Link |
|---|---|---|---|
| **`student_profiles`** | `student_id`, `lrn`, `first_name`, `middle_name`, `last_name`, `birthday`, `gender`, `created_at` | Add `rfid_uid varchar(64) UNIQUE NULL`. Add index `idx_student_profiles_rfid_uid`. | **R2** (RFID Assignment & Conflict Detection) |
| **`attendance_records`** | `id`, `student_id`, `subject_offering_id`, `attendance_date`, `status`, `remarks`, `recorded_by`, `created_at` | Add `recording_method varchar(10) NOT NULL DEFAULT 'Manual'` CHECK (`recording_method IN ('Manual', 'RFID', 'System')`).<br>Add `time_in time without time zone`.<br>Add `time_out time without time zone`.<br>Add `device_id varchar(64)`.<br>Add `updated_at timestamptz DEFAULT now()`. | **R2, R3, R4** (Audit trail & provenance) |
| **`attendance_cutoffs`** *(New Table)* | *Does not exist* | `id uuid PRIMARY KEY`, `subject_offering_id uuid REFERENCES subject_offerings(id)`, `schedule_id uuid REFERENCES teacher_schedule(id)`, `present_start_mins_before int DEFAULT 15`, `present_grace_mins int DEFAULT 15`, `late_cutoff_mins int DEFAULT 45`, `absent_cutoff_mins int DEFAULT 60`. Enforces chronological validation. | **R3** (Teacher-configurable cutoffs) |
| **`school_holidays`** *(New Table)* | *Does not exist* | `id uuid PRIMARY KEY`, `holiday_date date NOT NULL UNIQUE`, `holiday_name varchar(100) NOT NULL`, `is_active boolean DEFAULT true`, `created_at timestamptz DEFAULT now()`. | **R3** (23:59 Cron skips holidays) |
| **`rfid_devices`** *(New Table)* | *Does not exist* | `id uuid PRIMARY KEY`, `device_uid varchar(64) UNIQUE NOT NULL`, `device_name varchar(100)`, `assigned_teacher_id varchar(30)`, `assigned_room varchar(50)`, `last_sync_at timestamptz`, `is_active boolean DEFAULT true`. | **R4** (ESP32 & Mobile NFC tracking) |

---

### 4.2 Supabase SQL Migration Script (`008_attendance_overhaul.sql`)

```sql
-- ============================================================
-- CLASSREALM: ATTENDANCE OVERHAUL MIGRATION
-- Migration: 008_attendance_overhaul.sql
-- Covers: R2 (RFID), R3 (Schedule Cutoffs & Holidays), R6 (RLS)
-- ============================================================

-- 1. ADD RFID UID TO STUDENT PROFILES (R2)
ALTER TABLE public.student_profiles 
  ADD COLUMN IF NOT EXISTS rfid_uid varchar(64) NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'uq_student_profiles_rfid_uid'
  ) THEN
    ALTER TABLE public.student_profiles
      ADD CONSTRAINT uq_student_profiles_rfid_uid UNIQUE (rfid_uid);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_student_profiles_rfid_uid
  ON public.student_profiles (rfid_uid)
  WHERE rfid_uid IS NOT NULL;

-- 2. EVOLVE ATTENDANCE RECORDS (R2, R3, R4)
ALTER TABLE public.attendance_records
  ADD COLUMN IF NOT EXISTS recording_method varchar(10) NOT NULL DEFAULT 'Manual',
  ADD COLUMN IF NOT EXISTS time_in time without time zone NULL,
  ADD COLUMN IF NOT EXISTS time_out time without time zone NULL,
  ADD COLUMN IF NOT EXISTS device_id varchar(64) NULL,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'attendance_records_recording_method_check'
  ) THEN
    ALTER TABLE public.attendance_records
      ADD CONSTRAINT attendance_records_recording_method_check
      CHECK (recording_method IN ('Manual', 'RFID', 'System'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_attendance_records_method
  ON public.attendance_records (recording_method);

CREATE INDEX IF NOT EXISTS idx_attendance_records_student_date
  ON public.attendance_records (student_id, attendance_date);

-- 3. SCHOOL HOLIDAYS TABLE (R3)
CREATE TABLE IF NOT EXISTS public.school_holidays (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    holiday_date date NOT NULL,
    holiday_name varchar(100) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT school_holidays_pkey PRIMARY KEY (id),
    CONSTRAINT school_holidays_holiday_date_key UNIQUE (holiday_date)
);

CREATE INDEX IF NOT EXISTS idx_school_holidays_date
  ON public.school_holidays (holiday_date)
  WHERE is_active = true;

-- 4. ATTENDANCE CUTOFF CONFIGURATION TABLE (R3)
CREATE TABLE IF NOT EXISTS public.attendance_cutoffs (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    subject_offering_id uuid NOT NULL,
    schedule_id uuid NULL,
    
    -- Minutes relative to class start_time
    present_start_mins_before integer NOT NULL DEFAULT 15 CHECK (present_start_mins_before >= 0 AND present_start_mins_before <= 60),
    present_grace_mins integer NOT NULL DEFAULT 15 CHECK (present_grace_mins >= 0 AND present_grace_mins <= 120),
    late_cutoff_mins integer NOT NULL DEFAULT 45 CHECK (late_cutoff_mins > present_grace_mins),
    absent_cutoff_mins integer NOT NULL DEFAULT 60 CHECK (absent_cutoff_mins >= late_cutoff_mins),

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT attendance_cutoffs_pkey PRIMARY KEY (id),
    CONSTRAINT attendance_cutoffs_subject_offering_id_fkey 
        FOREIGN KEY (subject_offering_id) REFERENCES public.subject_offerings(id) ON DELETE CASCADE,
    CONSTRAINT attendance_cutoffs_schedule_id_fkey 
        FOREIGN KEY (schedule_id) REFERENCES public.teacher_schedule(id) ON DELETE CASCADE,
    CONSTRAINT attendance_cutoffs_unique_offering_schedule 
        UNIQUE (subject_offering_id, schedule_id)
);

-- 5. REGISTERED RFID DEVICES TABLE (R4)
CREATE TABLE IF NOT EXISTS public.rfid_devices (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    device_uid varchar(64) NOT NULL UNIQUE,
    device_name varchar(100) NOT NULL,
    assigned_teacher_id varchar(30) REFERENCES public.teacher_profiles(teacher_id) ON DELETE SET NULL,
    assigned_room varchar(50) NULL,
    last_sync_at timestamptz NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT rfid_devices_pkey PRIMARY KEY (id)
);
```

---

### 4.3 Supabase Row Level Security (RLS) Policies (R6)

To securely support Student and Parent view-only access while maintaining Teacher authoring permissions:

```sql
-- Enable RLS on core tables
ALTER TABLE public.attendance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parent_student_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teacher_schedule ENABLE ROW LEVEL SECURITY;

-- Helper function to extract authenticated Firebase UID
CREATE OR REPLACE FUNCTION public.current_auth_uid()
RETURNS varchar(30) AS $$
BEGIN
  RETURN COALESCE(
    NULLIF(current_setting('request.jwt.claim.sub', true), ''),
    (NULLIF(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'),
    (NULLIF(current_setting('request.jwt.claims', true), '')::jsonb ->> 'user_id')
  )::varchar(30);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- -------------------------------------------------------------
-- ATTENDANCE RECORDS POLICIES
-- -------------------------------------------------------------

-- 1. Student Policy: View-only personal records
CREATE POLICY "student_view_own_attendance"
ON public.attendance_records
FOR SELECT
TO authenticated, anon
USING (
  student_id = public.current_auth_uid()
);

-- 2. Parent Policy: View-only linked child records
CREATE POLICY "parent_view_child_attendance"
ON public.attendance_records
FOR SELECT
TO authenticated, anon
USING (
  EXISTS (
    SELECT 1 FROM public.parent_student_links psl
    WHERE psl.parent_id = public.current_auth_uid()
      AND psl.student_id = attendance_records.student_id
  )
);

-- 3. Teacher Policy: Read & Manage attendance for assigned offerings
CREATE POLICY "teacher_manage_own_attendance"
ON public.attendance_records
FOR ALL
TO authenticated, anon
USING (
  EXISTS (
    SELECT 1 FROM public.subject_offerings so
    WHERE so.id = attendance_records.subject_offering_id
      AND so.teacher_id = public.current_auth_uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.subject_offerings so
    WHERE so.id = attendance_records.subject_offering_id
      AND so.teacher_id = public.current_auth_uid()
  )
);

-- 4. Admin Policy: Full access
CREATE POLICY "admin_all_attendance"
ON public.attendance_records
FOR ALL
TO authenticated, anon
USING (
  EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = public.current_auth_uid()
      AND u.role = 'admin'
  )
);
```

---

### 4.4 23:59 EOD Automated Auto-Absent Stored Procedure & Trigger (R3)

```sql
-- ============================================================
-- 23:59 DAILY AUTO-ABSENT STORED PROCEDURE
-- ============================================================
CREATE OR REPLACE FUNCTION public.fn_trigger_daily_auto_absent(
    p_target_date date DEFAULT CURRENT_DATE
)
RETURNS jsonb AS $$
DECLARE
    v_dow smallint;
    v_is_holiday boolean;
    v_inserted_count integer := 0;
BEGIN
    -- 1. Check if target date is a registered holiday
    SELECT EXISTS (
        SELECT 1 FROM public.school_holidays 
        WHERE holiday_date = p_target_date AND is_active = true
    ) INTO v_is_holiday;

    IF v_is_holiday THEN
        RETURN jsonb_build_object(
            'status', 'skipped',
            'reason', 'Target date is a registered holiday',
            'date', p_target_date,
            'inserted', 0
        );
    END IF;

    -- 2. Extract day of week (ISO: 1 = Monday ... 7 = Sunday)
    v_dow := EXTRACT(ISODOW FROM p_target_date)::smallint;

    -- 3. Insert absences for students enrolled in classes scheduled on this day
    --    Only insert if NO attendance record exists for that student on that date.
    WITH eligible_schedules AS (
        SELECT DISTINCT ts.subject_offering_id
        FROM public.teacher_schedule ts
        JOIN public.subject_offerings so ON so.id = ts.subject_offering_id
        WHERE ts.day_of_week = v_dow
          AND ts.is_active = true
          AND so.is_archived = false
    ),
    unmarked_students AS (
        SELECT 
            se.student_id,
            se.subject_offering_id,
            p_target_date AS attendance_date
        FROM public.student_enrollments se
        JOIN eligible_schedules es ON es.subject_offering_id = se.subject_offering_id
        WHERE se.status = 'enrolled'
          AND NOT EXISTS (
              SELECT 1 FROM public.attendance_records ar
              WHERE ar.student_id = se.student_id
                AND ar.subject_offering_id = se.subject_offering_id
                AND ar.attendance_date = p_target_date
          )
    ),
    inserted_rows AS (
        INSERT INTO public.attendance_records (
            student_id,
            subject_offering_id,
            attendance_date,
            status,
            remarks,
            recording_method,
            recorded_by
        )
        SELECT 
            student_id,
            subject_offering_id,
            attendance_date,
            'absent',
            'Auto-Absent (Unscanned at EOD)',
            'System',
            NULL
        FROM unmarked_students
        ON CONFLICT (student_id, subject_offering_id, attendance_date) DO NOTHING
        RETURNING id
    )
    SELECT COUNT(*) FROM inserted_rows INTO v_inserted_count;

    RETURN jsonb_build_object(
        'status', 'success',
        'date', p_target_date,
        'day_of_week', v_dow,
        'inserted_absences', v_inserted_count
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Schedule daily execution at 23:59 Asia/Manila (15:59 UTC)
-- Enable pg_cron extension if supported:
-- CREATE EXTENSION IF NOT EXISTS pg_cron;
-- SELECT cron.schedule(
--   'daily-auto-absent-2359',
--   '59 15 * * *',
--   'SELECT public.fn_trigger_daily_auto_absent(CURRENT_DATE);'
-- );
```

#### Supabase Edge Function Architecture (Deno / TypeScript alternative):
If triggered via Supabase Edge Function (`supabase/functions/daily-auto-absent/index.ts`):
```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  // Enforce service-role authorization
  const authHeader = req.headers.get("Authorization");
  if (!authHeader || !authHeader.includes(Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "")) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  );

  const { data, error } = await supabase.rpc("fn_trigger_daily_auto_absent");
  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  return new Response(JSON.stringify(data), {
    headers: { "Content-Type": "application/json" },
    status: 200,
  });
});
```

---

### 4.5 Updated Flutter / Dart Model Definitions

#### 1. Evolution of `AttendanceWorkspaceRecord` (`lib/models/attendance_workspace_models.dart`):
```dart
enum AttendanceSource {
  manual,
  rfid,
  system;

  static AttendanceSource parse(String? value) {
    if (value == null) return AttendanceSource.manual;
    switch (value.trim().toLowerCase()) {
      case 'manual':
        return AttendanceSource.manual;
      case 'rfid':
        return AttendanceSource.rfid;
      case 'system':
        return AttendanceSource.system;
      default:
        return AttendanceSource.manual;
    }
  }

  String toJson() {
    switch (this) {
      case AttendanceSource.manual:
        return 'Manual';
      case AttendanceSource.rfid:
        return 'RFID';
      case AttendanceSource.system:
        return 'System';
    }
  }
}

class AttendanceWorkspaceRecord {
  final String? id;
  final String studentId;
  final String subjectOfferingId;
  final DateTime attendanceDate;
  final AttendanceStatus status;
  final AttendanceSource source;
  final String? remarks;
  final String? recordedBy;
  final String? timeIn; // "HH:MM:SS" or "08:15 AM"
  final String? timeOut;
  final String? deviceId;
  final DateTime? createdAt;
  final String? modifiedBy;

  const AttendanceWorkspaceRecord({
    required this.id,
    required this.studentId,
    required this.subjectOfferingId,
    required this.attendanceDate,
    required this.status,
    required this.source,
    this.remarks,
    this.recordedBy,
    this.timeIn,
    this.timeOut,
    this.deviceId,
    this.createdAt,
    this.modifiedBy,
  });

  factory AttendanceWorkspaceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceWorkspaceRecord(
      id: _optionalString(json, 'id'),
      studentId: _requiredString(json, 'student_id'),
      subjectOfferingId: _requiredString(json, 'subject_offering_id'),
      attendanceDate: _parseDate(_requiredValue(json, 'attendance_date')),
      status: _parseStatus(_requiredString(json, 'status')),
      source: AttendanceSource.parse(_optionalString(json, 'recording_method') ?? _optionalString(json, 'source')),
      remarks: _optionalString(json, 'remarks'),
      recordedBy: _optionalString(json, 'recorded_by'),
      timeIn: _optionalString(json, 'time_in'),
      timeOut: _optionalString(json, 'time_out'),
      deviceId: _optionalString(json, 'device_id'),
      createdAt: _optionalDate(json, 'created_at'),
      modifiedBy: _optionalString(json, 'modified_by'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'student_id': studentId,
    'subject_offering_id': subjectOfferingId,
    'attendance_date': _formatDate(attendanceDate),
    'status': status.name,
    'recording_method': source.toJson(),
    'remarks': remarks,
    'recorded_by': recordedBy,
    'time_in': timeIn,
    'time_out': timeOut,
    'device_id': deviceId,
    'created_at': createdAt?.toUtc().toIso8601String(),
    'modified_by': modifiedBy,
  };
}
```

#### 2. Evolution of `AttendanceRosterStudent` (`lib/models/attendance_workspace_models.dart`):
```dart
class AttendanceRosterStudent {
  final String studentId;
  final String? lrn;
  final String? rfidUid; // Nullable; indicates whether RFID card is linked
  final String firstName;
  final String? middleName;
  final String lastName;
  final String gender;

  const AttendanceRosterStudent({
    required this.studentId,
    this.lrn,
    this.rfidUid,
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.gender,
  });

  bool get hasRfidAssigned => rfidUid != null && rfidUid!.trim().isNotEmpty;

  factory AttendanceRosterStudent.fromJson(Map<String, dynamic> json) {
    return AttendanceRosterStudent(
      studentId: json['student_id']?.toString() ?? '',
      lrn: json['lrn']?.toString(),
      rfidUid: json['rfid_uid']?.toString(),
      firstName: json['first_name']?.toString() ?? '',
      middleName: json['middle_name']?.toString(),
      lastName: json['last_name']?.toString() ?? '',
      gender: (json['gender']?.toString() ?? 'unspecified').toLowerCase(),
    );
  }

  Map<String, dynamic> toJson() => {
    'student_id': studentId,
    'lrn': lrn,
    'rfid_uid': rfidUid,
    'first_name': firstName,
    'middle_name': middleName,
    'last_name': lastName,
    'gender': gender,
  };
}
```

---

### 4.6 Schedule Guarding & Chronological Cutoff Validation Engine

#### Mathematical Cutoff Invariant
For a scheduled class session on `day_of_week` with `start_time` and `end_time`:
$$T_{\text{present\_open}} \le T_{\text{start}} < T_{\text{present\_cutoff}} < T_{\text{late\_cutoff}} \le T_{\text{absent\_cutoff}} \le T_{\text{end}}$$

#### Validation Engine Algorithm:
When a scan event arrives $(UID, t_{\text{scan}}, \text{offeringId})$:

1. **Card Association Check:**
   - Find student where `rfid_uid = UID`. If not found, raise **UnregisteredCardException** (Display friendly modal: *"Card [UID] is not registered. Would you like to assign it to a student?"*).
2. **Section Enrollment Check:**
   - Verify student is actively enrolled in `offeringId`. If enrolled in a different section, raise **CrossSectionCardException** (Display modal: *"Student [Name] belongs to [Other Section], not this class."*).
3. **Plotted Schedule Guard:**
   - Query `teacher_schedule` for `offeringId` where `day_of_week = t_scan.weekday` and `is_active = true`.
   - If no schedule exists, raise **NonScheduledDayException** (Display modal: *"No class scheduled for [Subject] on [Day]. Attendance is locked."*).
4. **Holiday Guard:**
   - Check `school_holidays` for `t_scan.date`. If holiday, raise **SchoolHolidayException** (Display modal: *"Today is [Holiday Name]. Attendance cannot be recorded."*).
5. **Time Window & Status Determination:**
   - Let $t$ be the time of day in minutes from midnight.
   - If $t < T_{\text{present\_open}}$: Reject scan (*"Too early. Scans open at [Time]. Class starts at [Start]."*).
   - If $T_{\text{present\_open}} \le t \le T_{\text{present\_cutoff}}$: Evaluate as **`present`**.
   - If $T_{\text{present\_cutoff}} < t \le T_{\text{late\_cutoff}}$: Evaluate as **`late`**.
   - If $T_{\text{late\_cutoff}} < t \le T_{\text{absent\_cutoff}}$: Evaluate as **`absent`**.
   - If $t > T_{\text{end}}$: Reject scan (*"Class session ended at [End]. Scans closed."*).
6. **Deterministic Idempotency Check:**
   - Query existing attendance mark for `(studentId, offeringId, t_scan.date)`.
   - If marked `present`: Keep `present` and keep original `time_in`. Do not overwrite or downgrade.
   - If marked `late` and a duplicate scan arrives: Keep original.
   - If teacher previously made a manual override with audit remarks: Preserve teacher manual override unless explicitly confirmed.

---

## 5. Verification Method

To independently verify all observations and conclusions:

1. **Verify Migrations & Absence of `rfid_uid` and Cutoff Tables:**
   ```powershell
   Select-String -Path "supabase/migrations/*.sql" -Pattern "rfid_uid"
   Select-String -Path "supabase/migrations/*.sql" -Pattern "attendance_cutoffs"
   Select-String -Path "supabase/migrations/*.sql" -Pattern "school_holidays"
   ```
   *(Expected result: No matches found, verifying that these schema elements do not yet exist).*

2. **Verify RLS Status:**
   ```powershell
   Select-String -Path "supabase/migrations/*.sql" -Pattern "ENABLE ROW LEVEL SECURITY"
   ```
   *(Expected result: Matches found only in `005_enterprise_rate_limits_and_otp.sql` for auth rate limits).*

3. **Verify Pure Dart Attendance Tests:**
   ```powershell
   flutter test test/models/attendance_workspace_models_test.dart
   ```
   *(Confirmed: All 8 value model and parsing tests pass with exit code 0).*
   Note: `test/data/repositories/supabase_attendance_repository_test.dart` verifies `AttendanceDateRange` and `AttendanceHistoryFilter`, but testing `SupabaseAttendanceRepository` directly requires supplying a mock `SupabaseClient` to avoid uninitialized `Supabase.instance` assertions during headless unit runs.

4. **Verify Dead Parent Attendance Code:**
   Inspect `lib/features/parent/screens/parent_home_screen.dart:184`:
   `const ParentAttendanceTab(attendance: [])`
   *(Confirmed: Parent attendance tab receives an empty constant list).*

5. **Invalidation Conditions:**
   - If Supabase is switched to native Supabase Auth instead of Firebase Auth, RLS policies should use `auth.uid()` directly rather than JWT `sub` extraction.
   - If school schedule shifts to a non-weekly cyclical timetable (e.g., 6-day cycle), `teacher_schedule.day_of_week` smallint constraint must be revised.
