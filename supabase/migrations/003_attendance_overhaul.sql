-- ============================================================
-- CLASSREALM: ATTENDANCE OVERHAUL MIGRATION (RFID + CUTOFFS + EOD AUTO-ABSENT)
-- Migration File: supabase/migrations/003_attendance_overhaul.sql
-- Scope: ESP32 + RC522 / USB RFID Scanner + Manual Teacher Roster Fallback
-- Idempotent PostgreSQL Migration (Safe to run multiple times)
-- ============================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 1. UPGRADE STUDENT PROFILES WITH RFID CARD BINDING
-- ============================================================

ALTER TABLE public.student_profiles
    ADD COLUMN IF NOT EXISTS rfid_uid varchar(64);

-- Normalize blank strings to NULL so partial unique index behaves cleanly
UPDATE public.student_profiles
SET rfid_uid = NULL
WHERE rfid_uid IS NOT NULL
  AND TRIM(rfid_uid) = '';

-- Safely clear any pre-existing case-insensitive duplicates before indexing
DO $$
BEGIN
    WITH ranked_cards AS (
        SELECT
            student_id,
            ROW_NUMBER() OVER (
                PARTITION BY UPPER(TRIM(rfid_uid))
                ORDER BY created_at DESC, student_id DESC
            ) AS rn
        FROM public.student_profiles
        WHERE rfid_uid IS NOT NULL
    )
    UPDATE public.student_profiles sp
    SET rfid_uid = NULL
    FROM ranked_cards rc
    WHERE sp.student_id = rc.student_id
      AND rc.rn > 1;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_student_profiles_rfid_uid
    ON public.student_profiles (UPPER(TRIM(rfid_uid)))
    WHERE rfid_uid IS NOT NULL;


-- ============================================================
-- 2. UPGRADE ATTENDANCE RECORDS TABLE
-- ============================================================

ALTER TABLE public.attendance_records
    ADD COLUMN IF NOT EXISTS recording_method varchar(20) NOT NULL DEFAULT 'Manual',
    ADD COLUMN IF NOT EXISTS time_in time without time zone,
    ADD COLUMN IF NOT EXISTS device_id varchar(64),
    ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

-- Safely widen remarks column if previously constrained to varchar(100)
DO $$
BEGIN
    ALTER TABLE public.attendance_records
        ALTER COLUMN remarks TYPE varchar(255);
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END $$;

-- Normalize any legacy recording_method values before applying CHECK constraint
UPDATE public.attendance_records
SET recording_method = CASE
    WHEN LOWER(TRIM(COALESCE(recording_method, ''))) = 'rfid' THEN 'RFID'
    WHEN LOWER(TRIM(COALESCE(recording_method, ''))) = 'system' THEN 'System'
    ELSE 'Manual'
END
WHERE recording_method NOT IN ('Manual', 'RFID', 'System');

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'attendance_records_recording_method_check'
          AND conrelid = 'public.attendance_records'::regclass
    ) THEN
        ALTER TABLE public.attendance_records
            ADD CONSTRAINT attendance_records_recording_method_check
            CHECK (recording_method IN ('Manual', 'RFID', 'System'));
    END IF;
END $$;

-- Safely deduplicate daily attendance records before adding unique constraint
DO $$
BEGIN
    WITH ranked_attendance AS (
        SELECT
            id,
            ROW_NUMBER() OVER (
                PARTITION BY student_id, subject_offering_id, attendance_date
                ORDER BY
                    CASE recording_method
                        WHEN 'Manual' THEN 1
                        WHEN 'RFID' THEN 2
                        ELSE 3
                    END ASC,
                    updated_at DESC NULLS LAST,
                    created_at DESC NULLS LAST,
                    id DESC
            ) AS rn
        FROM public.attendance_records
    )
    DELETE FROM public.attendance_records ar
    USING ranked_attendance ra
    WHERE ar.id = ra.id
      AND ra.rn > 1;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'uq_attendance_student_offering_date'
          AND conrelid = 'public.attendance_records'::regclass
    ) THEN
        ALTER TABLE public.attendance_records
            ADD CONSTRAINT uq_attendance_student_offering_date
            UNIQUE (student_id, subject_offering_id, attendance_date);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_attendance_records_offering_date
    ON public.attendance_records (subject_offering_id, attendance_date);

CREATE INDEX IF NOT EXISTS idx_attendance_records_student_date
    ON public.attendance_records (student_id, attendance_date DESC);

CREATE INDEX IF NOT EXISTS idx_attendance_records_recording_method
    ON public.attendance_records (recording_method);


-- ============================================================
-- 3. SCHOOL HOLIDAYS & ACADEMIC SUSPENSIONS TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.school_holidays (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    holiday_date date NOT NULL,
    holiday_name varchar(120) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_by varchar(30) REFERENCES public.users(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT school_holidays_pkey PRIMARY KEY (id),
    CONSTRAINT school_holidays_holiday_date_key UNIQUE (holiday_date)
);

CREATE INDEX IF NOT EXISTS idx_school_holidays_active_date
    ON public.school_holidays (holiday_date)
    WHERE is_active = true;


-- ============================================================
-- 4. ATTENDANCE CUTOFF THRESHOLDS TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.attendance_cutoffs (
    subject_offering_id uuid NOT NULL,
    present_start_mins_before smallint NOT NULL DEFAULT 15
        CHECK (present_start_mins_before >= 0 AND present_start_mins_before <= 180),
    present_grace_mins smallint NOT NULL DEFAULT 15
        CHECK (present_grace_mins >= 0),
    late_cutoff_mins smallint NOT NULL DEFAULT 45,
    absent_cutoff_mins smallint NOT NULL DEFAULT 60,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT attendance_cutoffs_pkey
        PRIMARY KEY (subject_offering_id),
    CONSTRAINT attendance_cutoffs_subject_offering_id_fkey
        FOREIGN KEY (subject_offering_id)
        REFERENCES public.subject_offerings(id)
        ON DELETE CASCADE,
    CONSTRAINT attendance_cutoffs_ordering_check
        CHECK (
            present_grace_mins < late_cutoff_mins
            AND late_cutoff_mins <= absent_cutoff_mins
        )
);


-- ============================================================
-- 5. REGISTERED RFID HARDWARE DEVICES REGISTRY
-- ============================================================

CREATE TABLE IF NOT EXISTS public.rfid_devices (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    device_uid varchar(64) NOT NULL,
    device_name varchar(100) NOT NULL,
    subject_offering_id uuid REFERENCES public.subject_offerings(id) ON DELETE SET NULL,
    assigned_teacher_id varchar(30) REFERENCES public.teacher_profiles(teacher_id) ON DELETE SET NULL,
    assigned_room varchar(50),
    last_sync_at timestamptz,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT rfid_devices_pkey PRIMARY KEY (id),
    CONSTRAINT rfid_devices_device_uid_key UNIQUE (device_uid)
);

CREATE INDEX IF NOT EXISTS idx_rfid_devices_teacher
    ON public.rfid_devices (assigned_teacher_id)
    WHERE is_active = true;


-- ============================================================
-- 6. ATOMIC PL/pgSQL RPC: record_rfid_attendance
-- ============================================================

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
    v_schedule record;
    v_cutoffs record;
    v_existing record;
    v_present_open_time time;
    v_present_grace_cutoff time;
    v_late_cutoff time;
    v_absent_cutoff time;
    v_calculated_status varchar(10);
BEGIN
    v_normalized_uid := UPPER(TRIM(COALESCE(p_rfid_uid, '')));
    v_hex_only_uid := REGEXP_REPLACE(v_normalized_uid, '[^0-9A-F]', '', 'g');

    -- Update registered hardware heartbeat when matching device_uid exists
    UPDATE public.rfid_devices
    SET last_sync_at = now()
    WHERE device_uid = v_effective_device
      AND is_active = true;

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

    -- 2. STUDENT LOOKUP BY RFID UID (Exact normalized match or hex-stripped match)
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

    -- 4. PLOTTED SCHEDULE CHECK FOR SELECTED DAY OF WEEK
    SELECT *
    INTO v_schedule
    FROM public.teacher_schedule ts
    WHERE ts.subject_offering_id = p_subject_offering_id
      AND ts.day_of_week = v_dow
      AND ts.is_active = true
    ORDER BY
        CASE
            WHEN v_scan_time BETWEEN (ts.start_time - INTERVAL '30 minutes') AND ts.end_time THEN 0
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
            'message', 'No class session is scheduled for this subject today.'
        );
    END IF;

    -- 5. CUTOFF WINDOW CALCULATION
    SELECT *
    INTO v_cutoffs
    FROM public.attendance_cutoffs ac
    WHERE ac.subject_offering_id = p_subject_offering_id
    LIMIT 1;

    v_present_open_time := v_schedule.start_time
        - (COALESCE(v_cutoffs.present_start_mins_before, 15) * INTERVAL '1 minute');
    v_present_grace_cutoff := v_schedule.start_time
        + (COALESCE(v_cutoffs.present_grace_mins, 15) * INTERVAL '1 minute');
    v_late_cutoff := v_schedule.start_time
        + (COALESCE(v_cutoffs.late_cutoff_mins, 45) * INTERVAL '1 minute');
    v_absent_cutoff := v_schedule.start_time
        + (COALESCE(v_cutoffs.absent_cutoff_mins, 60) * INTERVAL '1 minute');

    IF v_scan_time < v_present_open_time THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'BEFORE_WINDOW_OPENS',
            'student_id', v_student_id,
            'student_name', v_student_name,
            'message', 'Too early to scan. Attendance window opens at ' || to_char(v_present_open_time, 'HH12:MI AM') || '.'
        );
    ELSIF v_scan_time > v_schedule.end_time THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'AFTER_CLASS_ENDS',
            'student_id', v_student_id,
            'student_name', v_student_name,
            'message', 'Class ended at ' || to_char(v_schedule.end_time, 'HH12:MI AM') || '. Scans are closed.'
        );
    ELSIF v_scan_time > v_absent_cutoff THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'SCANS_CLOSED',
            'student_id', v_student_id,
            'student_name', v_student_name,
            'message', 'Attendance cutoff window closed at ' || to_char(v_absent_cutoff, 'HH12:MI AM') || '.'
        );
    END IF;

    IF v_scan_time <= v_present_grace_cutoff THEN
        v_calculated_status := 'present';
    ELSIF v_scan_time <= v_late_cutoff THEN
        v_calculated_status := 'late';
    ELSE
        v_calculated_status := 'absent';
    END IF;

    -- 6. 3-WAY DETERMINISTIC CONFLICT RESOLUTION
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

        -- Rule 2A: Promote System Auto-Absent when delayed offline RFID tap arrives
        IF v_existing.recording_method = 'System' AND v_existing.status = 'absent' THEN
            UPDATE public.attendance_records
            SET status = v_calculated_status,
                recording_method = 'RFID',
                time_in = v_scan_time,
                device_id = v_effective_device,
                remarks = 'Promoted from System Auto-Absent via delayed RFID tap',
                updated_at = now()
            WHERE id = v_existing.id;

            RETURN jsonb_build_object(
                'success', true,
                'code', 'PROMOTED_FROM_AUTO_ABSENT',
                'status', v_calculated_status,
                'student_id', v_student_id,
                'student_name', v_student_name,
                'time_in', to_char(v_scan_time, 'HH12:MI AM'),
                'message', 'Attendance recovered and promoted from System Auto-Absent.'
            );
        END IF;

        -- Rule 2B: Status Monotonicity (Late -> Present promotion via earlier on-time tap)
        IF v_existing.status = 'late' AND v_calculated_status = 'present' THEN
            UPDATE public.attendance_records
            SET status = 'present',
                recording_method = 'RFID',
                time_in = v_scan_time,
                device_id = v_effective_device,
                remarks = 'Promoted to Present via earlier physical RFID tap',
                updated_at = now()
            WHERE id = v_existing.id;

            RETURN jsonb_build_object(
                'success', true,
                'code', 'PROMOTED_TO_PRESENT',
                'status', 'present',
                'student_id', v_student_id,
                'student_name', v_student_name,
                'time_in', to_char(v_scan_time, 'HH12:MI AM'),
                'message', 'Attendance promoted to Present based on earlier RFID tap.'
            );
        END IF;

        -- Rule 2C: Earlier physical tap wins for matching status
        IF v_existing.status = v_calculated_status
           AND v_existing.time_in IS NOT NULL
           AND v_scan_time < v_existing.time_in THEN
            UPDATE public.attendance_records
            SET time_in = v_scan_time,
                device_id = v_effective_device,
                remarks = 'Timestamp updated to earlier physical RFID tap',
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

        -- Rule 3: Idempotent no-op (never downgrade or overwrite)
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
        'Recorded via ' || v_effective_device,
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


-- ============================================================
-- 7. BATCH RFID SPOOL DRAIN RPC: record_rfid_attendance_batch
-- Processes up to 50 queued hardware/offline RFID scans atomically
-- ============================================================

CREATE OR REPLACE FUNCTION public.record_rfid_attendance_batch(
    p_scans jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_item jsonb;
    v_res jsonb;
    v_results jsonb := '[]'::jsonb;
    v_success_count integer := 0;
    v_fail_count integer := 0;
    v_processed integer := 0;
BEGIN
    IF p_scans IS NULL OR jsonb_typeof(p_scans) <> 'array' THEN
        RETURN jsonb_build_object(
            'total', 0,
            'processed', 0,
            'success_count', 0,
            'fail_count', 0,
            'results', '[]'::jsonb
        );
    END IF;

    FOR v_item IN
        SELECT elem
        FROM jsonb_array_elements(p_scans) AS elem
        LIMIT 50
    LOOP
        v_processed := v_processed + 1;
        BEGIN
            v_res := public.record_rfid_attendance(
                p_rfid_uid => (v_item ->> 'rfid_uid')::varchar,
                p_subject_offering_id => (v_item ->> 'subject_offering_id')::uuid,
                p_scan_timestamp => COALESCE((v_item ->> 'scan_timestamp')::timestamptz, now()),
                p_device_id => COALESCE(NULLIF(TRIM(v_item ->> 'device_id'), ''), 'HARDWARE_ESP32')
            );
        EXCEPTION
            WHEN OTHERS THEN
                v_res := jsonb_build_object(
                    'success', false,
                    'code', 'INVALID_SCAN_PAYLOAD',
                    'message', 'Malformed scan payload in batch.'
                );
        END;

        v_results := v_results || jsonb_build_array(
            jsonb_build_object(
                'rfid_uid', v_item ->> 'rfid_uid',
                'student_id', v_res ->> 'student_id',
                'student_name', v_res ->> 'student_name',
                'code', v_res ->> 'code',
                'status', v_res ->> 'status',
                'time_in', v_res ->> 'time_in',
                'success', COALESCE((v_res ->> 'success')::boolean, false)
            )
        );

        IF COALESCE((v_res ->> 'success')::boolean, false) THEN
            v_success_count := v_success_count + 1;
        ELSE
            v_fail_count := v_fail_count + 1;
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'total', jsonb_array_length(p_scans),
        'processed', v_processed,
        'success_count', v_success_count,
        'fail_count', v_fail_count,
        'results', v_results
    );
END;
$$;


-- ============================================================
-- 8. EOD 23:59 ASIA/MANILA AUTO-ABSENT ENGINE
-- ============================================================

DROP FUNCTION IF EXISTS public.fn_trigger_daily_auto_absent(date);

CREATE OR REPLACE FUNCTION public.fn_trigger_daily_auto_absent(
    p_target_date date DEFAULT (now() AT TIME ZONE 'Asia/Manila')::date
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_dow smallint;
    v_is_holiday boolean;
    v_inserted_count integer := 0;
BEGIN
    -- 1. Skip recognized active school holidays
    SELECT EXISTS (
        SELECT 1
        FROM public.school_holidays sh
        WHERE sh.holiday_date = p_target_date
          AND sh.is_active = true
    ) INTO v_is_holiday;

    IF v_is_holiday THEN
        RETURN 0;
    END IF;

    -- 2. Resolve ISO day of week (1 = Monday ... 7 = Sunday)
    v_dow := EXTRACT(ISODOW FROM p_target_date)::smallint;

    -- 3. Insert 'absent' for all enrolled students in active offerings scheduled today
    WITH scheduled_offerings AS (
        SELECT DISTINCT ts.subject_offering_id
        FROM public.teacher_schedule ts
        JOIN public.subject_offerings so
          ON so.id = ts.subject_offering_id
        WHERE ts.day_of_week = v_dow
          AND ts.is_active = true
          AND so.is_archived = false
    ),
    inserted AS (
        INSERT INTO public.attendance_records (
            student_id,
            subject_offering_id,
            attendance_date,
            status,
            recording_method,
            remarks,
            created_at,
            updated_at
        )
        SELECT
            se.student_id,
            se.subject_offering_id,
            p_target_date,
            'absent',
            'System',
            'System Auto-Absent (End of Day)',
            now(),
            now()
        FROM public.student_enrollments se
        JOIN scheduled_offerings sched
          ON sched.subject_offering_id = se.subject_offering_id
        WHERE LOWER(TRIM(se.status)) = 'enrolled'
          AND NOT EXISTS (
              SELECT 1
              FROM public.attendance_records ar
              WHERE ar.student_id = se.student_id
                AND ar.subject_offering_id = se.subject_offering_id
                AND ar.attendance_date = p_target_date
          )
        ON CONFLICT (student_id, subject_offering_id, attendance_date) DO NOTHING
        RETURNING 1
    )
    SELECT COUNT(*)::integer
    INTO v_inserted_count
    FROM inserted;

    RETURN COALESCE(v_inserted_count, 0);
END;
$$;


-- ============================================================
-- 9. ROW LEVEL SECURITY & CLIENT-COMPATIBLE ACCESS POLICIES
-- Compatible with both Firebase-Auth + Supabase anon client
-- AND custom JWT sub claims when configured.
-- ============================================================

CREATE OR REPLACE FUNCTION public.current_auth_uid()
RETURNS varchar(30)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid text;
BEGIN
    v_uid := COALESCE(
        NULLIF(current_setting('request.jwt.claim.sub', true), ''),
        (NULLIF(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'),
        (NULLIF(current_setting('request.jwt.claims', true), '')::jsonb ->> 'user_id')
    );
    IF v_uid IS NULL OR TRIM(v_uid) = '' THEN
        RETURN NULL;
    END IF;
    RETURN LEFT(TRIM(v_uid), 30)::varchar(30);
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
END;
$$;

ALTER TABLE public.attendance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_holidays ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_cutoffs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rfid_devices ENABLE ROW LEVEL SECURITY;

-- Attendance Records Policies
DROP POLICY IF EXISTS "attendance_records_jwt_student_read" ON public.attendance_records;
CREATE POLICY "attendance_records_jwt_student_read"
ON public.attendance_records
FOR SELECT
TO authenticated
USING (student_id = public.current_auth_uid());

DROP POLICY IF EXISTS "attendance_records_jwt_parent_read" ON public.attendance_records;
CREATE POLICY "attendance_records_jwt_parent_read"
ON public.attendance_records
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.parent_student_links psl
        WHERE psl.parent_id = public.current_auth_uid()
          AND psl.student_id = attendance_records.student_id
    )
);

DROP POLICY IF EXISTS "attendance_records_jwt_teacher_manage" ON public.attendance_records;
CREATE POLICY "attendance_records_jwt_teacher_manage"
ON public.attendance_records
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.subject_offerings so
        WHERE so.id = attendance_records.subject_offering_id
          AND so.teacher_id = public.current_auth_uid()
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.subject_offerings so
        WHERE so.id = attendance_records.subject_offering_id
          AND so.teacher_id = public.current_auth_uid()
    )
);

DROP POLICY IF EXISTS "attendance_records_jwt_admin_all" ON public.attendance_records;
CREATE POLICY "attendance_records_jwt_admin_all"
ON public.attendance_records
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.users u
        WHERE u.id = public.current_auth_uid()
          AND u.role = 'admin'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.users u
        WHERE u.id = public.current_auth_uid()
          AND u.role = 'admin'
    )
);

-- Compatibility policy for ClassRealm Firebase-Auth + Supabase anon key client
DROP POLICY IF EXISTS "attendance_records_app_client_access" ON public.attendance_records;
CREATE POLICY "attendance_records_app_client_access"
ON public.attendance_records
FOR ALL
TO anon
USING (public.current_auth_uid() IS NULL)
WITH CHECK (public.current_auth_uid() IS NULL);

-- School Holidays Policies
DROP POLICY IF EXISTS "school_holidays_read_all" ON public.school_holidays;
CREATE POLICY "school_holidays_read_all"
ON public.school_holidays
FOR SELECT
TO anon, authenticated
USING (true);

DROP POLICY IF EXISTS "school_holidays_manage_app" ON public.school_holidays;
CREATE POLICY "school_holidays_manage_app"
ON public.school_holidays
FOR ALL
TO anon, authenticated
USING (
    public.current_auth_uid() IS NULL
    OR EXISTS (
        SELECT 1
        FROM public.users u
        WHERE u.id = public.current_auth_uid()
          AND u.role IN ('admin', 'teacher')
    )
)
WITH CHECK (
    public.current_auth_uid() IS NULL
    OR EXISTS (
        SELECT 1
        FROM public.users u
        WHERE u.id = public.current_auth_uid()
          AND u.role IN ('admin', 'teacher')
    )
);

-- Attendance Cutoffs Policies
DROP POLICY IF EXISTS "attendance_cutoffs_read_all" ON public.attendance_cutoffs;
CREATE POLICY "attendance_cutoffs_read_all"
ON public.attendance_cutoffs
FOR SELECT
TO anon, authenticated
USING (true);

DROP POLICY IF EXISTS "attendance_cutoffs_manage_teacher" ON public.attendance_cutoffs;
CREATE POLICY "attendance_cutoffs_manage_teacher"
ON public.attendance_cutoffs
FOR ALL
TO anon, authenticated
USING (
    public.current_auth_uid() IS NULL
    OR EXISTS (
        SELECT 1
        FROM public.subject_offerings so
        WHERE so.id = attendance_cutoffs.subject_offering_id
          AND so.teacher_id = public.current_auth_uid()
    )
    OR EXISTS (
        SELECT 1
        FROM public.users u
        WHERE u.id = public.current_auth_uid()
          AND u.role = 'admin'
    )
)
WITH CHECK (
    public.current_auth_uid() IS NULL
    OR EXISTS (
        SELECT 1
        FROM public.subject_offerings so
        WHERE so.id = attendance_cutoffs.subject_offering_id
          AND so.teacher_id = public.current_auth_uid()
    )
    OR EXISTS (
        SELECT 1
        FROM public.users u
        WHERE u.id = public.current_auth_uid()
          AND u.role = 'admin'
    )
);

-- RFID Devices Policies
DROP POLICY IF EXISTS "rfid_devices_read_all" ON public.rfid_devices;
CREATE POLICY "rfid_devices_read_all"
ON public.rfid_devices
FOR SELECT
TO anon, authenticated
USING (true);

DROP POLICY IF EXISTS "rfid_devices_manage_app" ON public.rfid_devices;
CREATE POLICY "rfid_devices_manage_app"
ON public.rfid_devices
FOR ALL
TO anon, authenticated
USING (
    public.current_auth_uid() IS NULL
    OR assigned_teacher_id = public.current_auth_uid()
    OR EXISTS (
        SELECT 1
        FROM public.users u
        WHERE u.id = public.current_auth_uid()
          AND u.role = 'admin'
    )
)
WITH CHECK (
    public.current_auth_uid() IS NULL
    OR assigned_teacher_id = public.current_auth_uid()
    OR EXISTS (
        SELECT 1
        FROM public.users u
        WHERE u.id = public.current_auth_uid()
          AND u.role = 'admin'
    )
);

-- Explicit Grants for PostgREST & RPC Execution
GRANT SELECT, INSERT, UPDATE, DELETE ON public.attendance_records TO anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.school_holidays TO anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.attendance_cutoffs TO anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.rfid_devices TO anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.record_rfid_attendance(varchar, uuid, timestamptz, varchar) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.record_rfid_attendance_batch(jsonb) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_trigger_daily_auto_absent(date) TO service_role, authenticated;

COMMIT;
