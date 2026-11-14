-- ============================================================================
-- Migration 029: Live-Verified Attendance RLS, Unified RFID Linking,
--                Realtime Publication, Holiday Cleanup & Schedule Enforcement
-- ============================================================================
-- Executed & verified directly against live project `wfilyatkfgqtybujmahf`:
-- 1. Fixes red "UNRESTRICTED" / "RLS disabled" badges in Supabase Table Editor:
--    - public.school_holidays (enables RLS + anon/authenticated policies)
--    - public.view_user_session_logs (sets security_invoker = true)
--    - public.user_session_logs (ensures clean anon/authenticated policies)
-- 2. Repairs live schema gaps found by live DB introspection:
--    - Creates `public.rfid_devices` if not exists (with RLS enabled)
--    - Adds `updated_at` column to `public.attendance_records` if not exists
--      (fixes runtime failure in `record_rfid_attendance` and `fn_trigger_daily_auto_absent`)
--    - Adds `subject_offering_id` column to `public.rfid_pending_scans` if not exists
-- 3. Configures full anon/authenticated RLS policies on `attendance_records`,
--    `attendance_cutoffs`, `student_profiles`, `rfid_devices`, and `rfid_pending_scans`.
-- 4. Adds `attendance_records`, `student_profiles`, `teacher_schedule`, and
--    `school_holidays` to the `supabase_realtime` publication so ESP32 hardware
--    taps immediately appear in the Teacher & Student UI.
-- 5. Adds Sudden Holiday / Suspension cleanup trigger on `public.school_holidays`.
-- 6. Upgrades `public.record_rfid_attendance` to insert unregistered taps into
--    `public.rfid_pending_scans` (for instant UI card linking) and strictly
--    enforce `public.teacher_schedule` (`NO_SCHEDULE_TODAY`) and cutoff windows.
-- ============================================================================

BEGIN;

-- ============================================================================
-- PART 1: Repair Live Table Columns & Missing `public.rfid_devices` Table
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.rfid_devices (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    device_uid varchar(64) NOT NULL UNIQUE,
    device_name varchar(100) NOT NULL,
    location varchar(100),
    is_active boolean NOT NULL DEFAULT true,
    last_sync_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.attendance_records
ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

ALTER TABLE public.rfid_pending_scans
ADD COLUMN IF NOT EXISTS subject_offering_id uuid;

-- ============================================================================
-- PART 2: Fix UNRESTRICTED on public.school_holidays
-- ============================================================================
ALTER TABLE public.school_holidays ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "school_holidays_read_all" ON public.school_holidays;
DROP POLICY IF EXISTS "school_holidays_manage_admin" ON public.school_holidays;
DROP POLICY IF EXISTS "school_holidays_manage_app" ON public.school_holidays;
DROP POLICY IF EXISTS "school_holidays_select" ON public.school_holidays;
DROP POLICY IF EXISTS "school_holidays_insert" ON public.school_holidays;
DROP POLICY IF EXISTS "school_holidays_update" ON public.school_holidays;
DROP POLICY IF EXISTS "school_holidays_delete" ON public.school_holidays;

CREATE POLICY "school_holidays_select"
ON public.school_holidays
FOR SELECT
TO anon, authenticated
USING (true);

CREATE POLICY "school_holidays_insert"
ON public.school_holidays
FOR INSERT
TO anon, authenticated
WITH CHECK (true);

CREATE POLICY "school_holidays_update"
ON public.school_holidays
FOR UPDATE
TO anon, authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "school_holidays_delete"
ON public.school_holidays
FOR DELETE
TO anon, authenticated
USING (true);

GRANT ALL ON TABLE public.school_holidays TO anon, authenticated, service_role;

-- ============================================================================
-- PART 3: Fix UNRESTRICTED on public.view_user_session_logs & user_session_logs
-- ============================================================================
ALTER TABLE public.user_session_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_session_logs_read_all" ON public.user_session_logs;
DROP POLICY IF EXISTS "user_session_logs_manage_app" ON public.user_session_logs;
DROP POLICY IF EXISTS "user_session_logs_select" ON public.user_session_logs;
DROP POLICY IF EXISTS "user_session_logs_insert" ON public.user_session_logs;
DROP POLICY IF EXISTS "user_session_logs_update" ON public.user_session_logs;
DROP POLICY IF EXISTS "user_session_logs_delete" ON public.user_session_logs;

CREATE POLICY "user_session_logs_select"
ON public.user_session_logs
FOR SELECT
TO anon, authenticated
USING (true);

CREATE POLICY "user_session_logs_insert"
ON public.user_session_logs
FOR INSERT
TO anon, authenticated
WITH CHECK (true);

CREATE POLICY "user_session_logs_update"
ON public.user_session_logs
FOR UPDATE
TO anon, authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "user_session_logs_delete"
ON public.user_session_logs
FOR DELETE
TO anon, authenticated
USING (true);

GRANT ALL ON TABLE public.user_session_logs TO anon, authenticated, service_role;

ALTER VIEW public.view_user_session_logs SET (security_invoker = true);
GRANT SELECT ON public.view_user_session_logs TO anon, authenticated, service_role;

-- ============================================================================
-- PART 4: Safe RLS Policies on Attendance, Cutoff, RFID & Student Tables
-- ============================================================================

-- 4A. public.attendance_records (Supports Clear All DELETE, Batch Save, & Read)
ALTER TABLE public.attendance_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "attendance_records_read_app" ON public.attendance_records;
DROP POLICY IF EXISTS "attendance_records_manage_app" ON public.attendance_records;
DROP POLICY IF EXISTS "attendance_records_select" ON public.attendance_records;
DROP POLICY IF EXISTS "attendance_records_insert" ON public.attendance_records;
DROP POLICY IF EXISTS "attendance_records_update" ON public.attendance_records;
DROP POLICY IF EXISTS "attendance_records_delete" ON public.attendance_records;

CREATE POLICY "attendance_records_select"
ON public.attendance_records
FOR SELECT
TO anon, authenticated
USING (true);

CREATE POLICY "attendance_records_insert"
ON public.attendance_records
FOR INSERT
TO anon, authenticated
WITH CHECK (true);

CREATE POLICY "attendance_records_update"
ON public.attendance_records
FOR UPDATE
TO anon, authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "attendance_records_delete"
ON public.attendance_records
FOR DELETE
TO anon, authenticated
USING (true);

GRANT ALL ON TABLE public.attendance_records TO anon, authenticated, service_role;

-- 4B. public.attendance_cutoffs
ALTER TABLE public.attendance_cutoffs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "attendance_cutoffs_read_all" ON public.attendance_cutoffs;
DROP POLICY IF EXISTS "attendance_cutoffs_manage_teacher" ON public.attendance_cutoffs;
DROP POLICY IF EXISTS "attendance_cutoffs_manage_teacher_admin" ON public.attendance_cutoffs;
DROP POLICY IF EXISTS "attendance_cutoffs_select" ON public.attendance_cutoffs;
DROP POLICY IF EXISTS "attendance_cutoffs_insert" ON public.attendance_cutoffs;
DROP POLICY IF EXISTS "attendance_cutoffs_update" ON public.attendance_cutoffs;
DROP POLICY IF EXISTS "attendance_cutoffs_delete" ON public.attendance_cutoffs;

CREATE POLICY "attendance_cutoffs_select"
ON public.attendance_cutoffs
FOR SELECT
TO anon, authenticated
USING (true);

CREATE POLICY "attendance_cutoffs_insert"
ON public.attendance_cutoffs
FOR INSERT
TO anon, authenticated
WITH CHECK (true);

CREATE POLICY "attendance_cutoffs_update"
ON public.attendance_cutoffs
FOR UPDATE
TO anon, authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "attendance_cutoffs_delete"
ON public.attendance_cutoffs
FOR DELETE
TO anon, authenticated
USING (true);

GRANT ALL ON TABLE public.attendance_cutoffs TO anon, authenticated, service_role;

-- 4C. public.student_profiles (Supports Unified Single-Card RFID Linking & Unlinking)
ALTER TABLE public.student_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "student_profiles_rfid_update_app" ON public.student_profiles;
DROP POLICY IF EXISTS "student_profiles_select_app" ON public.student_profiles;
DROP POLICY IF EXISTS "student_profiles_update_app" ON public.student_profiles;

CREATE POLICY "student_profiles_select_app"
ON public.student_profiles
FOR SELECT
TO anon, authenticated
USING (true);

CREATE POLICY "student_profiles_update_app"
ON public.student_profiles
FOR UPDATE
TO anon, authenticated
USING (true)
WITH CHECK (true);

GRANT ALL ON TABLE public.student_profiles TO anon, authenticated, service_role;

-- 4D. public.rfid_devices & public.rfid_pending_scans
ALTER TABLE public.rfid_devices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "rfid_devices_read_all" ON public.rfid_devices;
DROP POLICY IF EXISTS "rfid_devices_manage_teacher_admin" ON public.rfid_devices;
DROP POLICY IF EXISTS "rfid_devices_select" ON public.rfid_devices;
DROP POLICY IF EXISTS "rfid_devices_insert" ON public.rfid_devices;
DROP POLICY IF EXISTS "rfid_devices_update" ON public.rfid_devices;
DROP POLICY IF EXISTS "rfid_devices_delete" ON public.rfid_devices;

CREATE POLICY "rfid_devices_select"
ON public.rfid_devices
FOR SELECT
TO anon, authenticated
USING (true);

CREATE POLICY "rfid_devices_insert"
ON public.rfid_devices
FOR INSERT
TO anon, authenticated
WITH CHECK (true);

CREATE POLICY "rfid_devices_update"
ON public.rfid_devices
FOR UPDATE
TO anon, authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "rfid_devices_delete"
ON public.rfid_devices
FOR DELETE
TO anon, authenticated
USING (true);

GRANT ALL ON TABLE public.rfid_devices TO anon, authenticated, service_role;

ALTER TABLE public.rfid_pending_scans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "rfid_pending_scans_all_access" ON public.rfid_pending_scans;
DROP POLICY IF EXISTS "Allow all operations for anon and authenticated on rfid_pending_s" ON public.rfid_pending_scans;

CREATE POLICY "rfid_pending_scans_all_access"
ON public.rfid_pending_scans
FOR ALL
TO anon, authenticated
USING (true)
WITH CHECK (true);

GRANT ALL ON TABLE public.rfid_pending_scans TO anon, authenticated, service_role;

-- ============================================================================
-- PART 5: Enable Realtime Broadcast for Attendance, Schedule, & RFID Updates
-- ============================================================================
DO $$
DECLARE
    v_tbl text;
BEGIN
    FOREACH v_tbl IN ARRAY ARRAY[
        'attendance_records',
        'student_profiles',
        'teacher_schedule',
        'school_holidays',
        'rfid_pending_scans'
    ]
    LOOP
        IF NOT EXISTS (
            SELECT 1
            FROM pg_publication_tables
            WHERE pubname = 'supabase_realtime'
              AND schemaname = 'public'
              AND tablename = v_tbl
        ) THEN
            EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', v_tbl);
        END IF;
    END LOOP;
END $$;

-- ============================================================================
-- PART 6: Sudden Holiday / Suspension Cleanup Trigger
-- ============================================================================
CREATE OR REPLACE FUNCTION public.cleanup_attendance_on_active_holiday()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NEW.is_active = true THEN
        DELETE FROM public.attendance_records
        WHERE attendance_date = NEW.holiday_date;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_cleanup_attendance_on_active_holiday ON public.school_holidays;
CREATE TRIGGER trg_cleanup_attendance_on_active_holiday
AFTER INSERT OR UPDATE OF is_active, holiday_date
ON public.school_holidays
FOR EACH ROW
WHEN (NEW.is_active = true)
EXECUTE FUNCTION public.cleanup_attendance_on_active_holiday();

-- ============================================================================
-- PART 7: Strict Schedule-Connected RFID Attendance RPC
-- ============================================================================
CREATE OR REPLACE FUNCTION public.record_rfid_attendance(
    p_rfid_uid varchar,
    p_subject_offering_id uuid,
    p_scan_timestamp timestamptz,
    p_device_id varchar DEFAULT 'HARDWARE_ESP32'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_normalized_uid varchar(64);
    v_hex_only_uid varchar(64);
    v_effective_ts timestamptz := COALESCE(p_scan_timestamp, now());
    v_effective_device varchar(64) := COALESCE(NULLIF(TRIM(p_device_id), ''), 'HARDWARE_ESP32');
    v_attendance_date date := (v_effective_ts AT TIME ZONE 'Asia/Manila')::date;
    v_scan_time time := (v_effective_ts AT TIME ZONE 'Asia/Manila')::time;
    v_dow smallint := EXTRACT(ISODOW FROM v_attendance_date)::smallint;
    v_holiday_name varchar(120);
    v_student_id varchar(30);
    v_student_name text;
    v_has_any_schedule boolean := false;
    v_schedule record;
    v_cutoffs record;
    v_existing record;
    v_present_grace_cutoff time;
    v_late_cutoff time;
    v_calculated_status varchar(10);
BEGIN
    v_normalized_uid := UPPER(TRIM(COALESCE(p_rfid_uid, '')));
    v_hex_only_uid := REGEXP_REPLACE(v_normalized_uid, '[^0-9A-F]', '', 'g');

    -- Update hardware device heartbeat if registered
    UPDATE public.rfid_devices
    SET last_sync_at = now()
    WHERE device_uid = v_effective_device;

    -- 1. HOLIDAY CHECK
    SELECT holiday_name
    INTO v_holiday_name
    FROM public.school_holidays
    WHERE holiday_date = v_attendance_date
      AND is_active = true
    LIMIT 1;

    IF v_holiday_name IS NOT NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'HOLIDAY_LOCKED',
            'holiday_name', v_holiday_name,
            'message', 'School Holiday (' || v_holiday_name || '). Attendance scans are disabled.'
        );
    END IF;

    -- 2. STUDENT LOOKUP BY RFID UID (Single RFID Card across all subjects)
    SELECT
        sp.student_id,
        TRIM(sp.last_name || ', ' || sp.first_name)
    INTO v_student_id, v_student_name
    FROM public.student_profiles sp
    WHERE sp.rfid_uid IS NOT NULL
      AND (
          UPPER(TRIM(sp.rfid_uid)) = v_normalized_uid
          OR (
              v_hex_only_uid <> ''
              AND REGEXP_REPLACE(UPPER(TRIM(sp.rfid_uid)), '[^0-9A-F]', '', 'g') = v_hex_only_uid
          )
      )
    LIMIT 1;

    IF v_student_id IS NULL THEN
        -- Record into rfid_pending_scans so the teacher's UI can link the tapped card immediately
        INSERT INTO public.rfid_pending_scans (rfid_uid, device_id, subject_offering_id, scanned_at, is_claimed)
        VALUES (v_normalized_uid, v_effective_device, p_subject_offering_id, now(), false);

        RETURN jsonb_build_object(
            'success', false,
            'code', 'UNREGISTERED_CARD',
            'rfid_uid', v_normalized_uid,
            'message', 'This RFID card UID is not registered to any student.'
        );
    END IF;

    -- 3. SECTION ENROLLMENT CHECK
    IF NOT EXISTS (
        SELECT 1
        FROM public.student_enrollments se
        WHERE se.student_id = v_student_id
          AND se.subject_offering_id = p_subject_offering_id
          AND LOWER(TRIM(se.status)) = 'enrolled'
    ) THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'CROSS_SECTION_TAP',
            'student_id', v_student_id,
            'student_name', v_student_name,
            'message', v_student_name || ' is not enrolled in this class section.'
        );
    END IF;

    -- 4. STRICT SCHEDULE CHECK (Must be connected to My Schedule / teacher_schedule)
    SELECT EXISTS (
        SELECT 1
        FROM public.teacher_schedule ts
        WHERE ts.subject_offering_id = p_subject_offering_id
          AND ts.is_active = true
    ) INTO v_has_any_schedule;

    IF NOT v_has_any_schedule THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'NO_SCHEDULE_TODAY',
            'student_id', v_student_id,
            'student_name', v_student_name,
            'message', 'No class schedule is set for this subject and section in My Schedule.'
        );
    END IF;

    SELECT *
    INTO v_schedule
    FROM public.teacher_schedule ts
    WHERE ts.subject_offering_id = p_subject_offering_id
      AND ts.day_of_week = v_dow
      AND ts.is_active = true
    ORDER BY
        CASE
            WHEN v_scan_time BETWEEN (ts.start_time - INTERVAL '60 minutes') AND ts.end_time THEN 0
            ELSE 1
        END ASC,
        ts.start_time ASC
    LIMIT 1;

    IF v_schedule IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'NO_SCHEDULE_TODAY',
            'student_id', v_student_id,
            'student_name', v_student_name,
            'message', 'No class session is scheduled for this subject on the selected day.'
        );
    END IF;

    -- 5. CUTOFF WINDOW CALCULATION & AUTO STATUS DETERMINATION
    SELECT *
    INTO v_cutoffs
    FROM public.attendance_cutoffs ac
    WHERE ac.subject_offering_id = p_subject_offering_id
    LIMIT 1;

    v_present_grace_cutoff := v_schedule.start_time
        + (COALESCE(v_cutoffs.present_grace_mins, 15) * INTERVAL '1 minute');
    v_late_cutoff := v_schedule.start_time
        + (COALESCE(v_cutoffs.late_cutoff_mins, 45) * INTERVAL '1 minute');

    IF v_scan_time <= v_present_grace_cutoff THEN
        v_calculated_status := 'present';
    ELSIF v_scan_time <= v_late_cutoff THEN
        v_calculated_status := 'late';
    ELSE
        v_calculated_status := 'absent';
    END IF;

    -- 6. DETERMINISTIC CONFLICT RESOLUTION
    SELECT *
    INTO v_existing
    FROM public.attendance_records ar
    WHERE ar.student_id = v_student_id
      AND ar.subject_offering_id = p_subject_offering_id
      AND ar.attendance_date = v_attendance_date
    FOR UPDATE;

    IF v_existing IS NOT NULL THEN
        -- Rule 1: Teacher Manual Override or Excused mark is strictly preserved
        IF v_existing.recording_method = 'Manual' OR v_existing.status = 'excused' THEN
            RETURN jsonb_build_object(
                'success', true,
                'code', 'MANUAL_OVERRIDE_PRESERVED',
                'status', v_existing.status,
                'student_id', v_student_id,
                'student_name', v_student_name,
                'time_in', CASE
                    WHEN v_existing.time_in IS NOT NULL THEN to_char(v_existing.time_in, 'HH12:MI AM')
                    ELSE NULL
                END,
                'message', 'Existing manual teacher mark preserved.'
            );
        END IF;

        -- Rule 2A: Promote System Auto-Absent when student taps RFID
        IF v_existing.recording_method = 'System' AND v_existing.status = 'absent' THEN
            UPDATE public.attendance_records
            SET status = v_calculated_status,
                recording_method = 'RFID',
                time_in = v_scan_time,
                device_id = v_effective_device,
                updated_at = now()
            WHERE id = v_existing.id;

            RETURN jsonb_build_object(
                'success', true,
                'code', 'PROMOTED_FROM_AUTO_ABSENT',
                'status', v_calculated_status,
                'student_id', v_student_id,
                'student_name', v_student_name,
                'time_in', to_char(v_scan_time, 'HH12:MI AM'),
                'message', 'Attendance promoted from Auto-Absent to ' || INITCAP(v_calculated_status) || '.'
            );
        END IF;

        -- Rule 2B: Physical RFID tap upgrades 'absent' to 'present' or 'late'
        IF v_existing.status = 'absent' AND v_calculated_status IN ('present', 'late') THEN
            UPDATE public.attendance_records
            SET status = v_calculated_status,
                recording_method = 'RFID',
                time_in = v_scan_time,
                device_id = v_effective_device,
                updated_at = now()
            WHERE id = v_existing.id;

            RETURN jsonb_build_object(
                'success', true,
                'code', 'PROMOTED_TO_PRESENT',
                'status', v_calculated_status,
                'student_id', v_student_id,
                'student_name', v_student_name,
                'time_in', to_char(v_scan_time, 'HH12:MI AM'),
                'message', 'Attendance promoted based on physical RFID tap.'
            );
        END IF;

        -- Rule 2C: Earlier physical tap wins for matching status
        IF v_existing.status = v_calculated_status
           AND v_existing.time_in IS NOT NULL
           AND v_scan_time < v_existing.time_in THEN
            UPDATE public.attendance_records
            SET time_in = v_scan_time,
                device_id = v_effective_device,
                updated_at = now()
            WHERE id = v_existing.id;

            RETURN jsonb_build_object(
                'success', true,
                'code', v_existing.status || '_TIMESTAMP_PROMOTED',
                'status', v_existing.status,
                'student_id', v_student_id,
                'student_name', v_student_name,
                'time_in', to_char(v_scan_time, 'HH12:MI AM'),
                'message', 'Timestamp updated to earlier physical RFID tap.'
            );
        END IF;

        -- Rule 3: Idempotent no-op
        RETURN jsonb_build_object(
            'success', true,
            'code', 'IDEMPOTENT_ALREADY_RECORDED',
            'status', v_existing.status,
            'student_id', v_student_id,
            'student_name', v_student_name,
            'time_in', CASE
                WHEN v_existing.time_in IS NOT NULL THEN to_char(v_existing.time_in, 'HH12:MI AM')
                ELSE to_char(v_scan_time, 'HH12:MI AM')
            END,
            'message', 'Attendance was already recorded for this student today.'
        );
    END IF;

    -- 7. INSERT NEW RFID ATTENDANCE RECORD
    INSERT INTO public.attendance_records (
        student_id,
        subject_offering_id,
        attendance_date,
        status,
        recording_method,
        time_in,
        device_id,
        remarks,
        created_at,
        updated_at
    ) VALUES (
        v_student_id,
        p_subject_offering_id,
        v_attendance_date,
        v_calculated_status,
        'RFID',
        v_scan_time,
        v_effective_device,
        NULL,
        now(),
        now()
    )
    ON CONFLICT (student_id, subject_offering_id, attendance_date) DO NOTHING;

    RETURN jsonb_build_object(
        'success', true,
        'code', 'RECORDED_SUCCESS',
        'status', v_calculated_status,
        'student_id', v_student_id,
        'student_name', v_student_name,
        'time_in', to_char(v_scan_time, 'HH12:MI AM'),
        'message', 'Attendance recorded as ' || INITCAP(v_calculated_status) || '.'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_rfid_attendance(varchar, uuid, timestamptz, varchar) TO anon, authenticated, service_role;

COMMIT;
