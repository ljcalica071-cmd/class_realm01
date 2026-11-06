-- ============================================================
-- Migration: 015_clean_rfid_remarks.sql
-- Description:
-- 1. Updates record_rfid_attendance to store remarks as NULL on initial scan
--    and promotions instead of 'Recorded via ...' or 'Promoted from ...'.
--    Hardware device tracking remains fully preserved in public.attendance_records.device_id.
--    The remarks column is strictly reserved for teacher notes and excuses.
-- 2. Updates fn_trigger_daily_auto_absent to store remarks as NULL instead of
--    'System Auto-Absent (End of Day)'. Recording method remains 'System'.
-- 3. Cleans any historical system string remarks from public.attendance_records.
-- ============================================================

-- 1. CLEAN HISTORICAL SYSTEM REMARKS
UPDATE public.attendance_records
SET remarks = NULL
WHERE remarks ILIKE 'Recorded via%'
   OR remarks ILIKE 'Promoted %'
   OR remarks ILIKE 'Timestamp updated%'
   OR remarks = 'Auto-Absent'
   OR remarks ILIKE 'System Auto-Absent%';

-- 2. ATOMIC PL/pgSQL RPC: record_rfid_attendance (Clean Remarks)
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

    -- 2. STUDENT LOOKUP BY RFID UID
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

        -- Rule 2A: Promote System Auto-Absent when delayed offline RFID tap arrives
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

        -- Rule 2B: Hardware RFID tap upgrades 'absent' to 'present' or 'late'
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

    -- 7. INSERT NEW RFID ATTENDANCE RECORD (remarks = NULL reserved for teacher notes)
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

-- 3. EOD 23:59 ASIA/MANILA AUTO-ABSENT ENGINE (Clean Remarks)
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
            NULL,
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

