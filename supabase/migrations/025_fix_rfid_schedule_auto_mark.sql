-- ============================================================
-- Migration: 025_fix_rfid_schedule_auto_mark.sql
-- Description:
-- 1. Updates record_rfid_attendance to always auto-mark students:
--    - Present if scanned on-time (within grace period or early arrival)
--    - Late if scanned after grace period but before late cutoff
--    - Absent if scanned after late cutoff or after class ends (recorded with tap timestamp)
--    - Present if make-up class / unscheduled session
--    - Removes hard-rejection codes (AFTER_CLASS_ENDS, SCANS_CLOSED, BEFORE_WINDOW_OPENS)
--      that previously dropped RFID scans and prevented auto-marking.
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
    v_present_grace_cutoff time;
    v_late_cutoff time;
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
            WHEN v_scan_time BETWEEN (ts.start_time - INTERVAL '60 minutes') AND ts.end_time THEN 0
            ELSE 1
        END ASC,
        ts.start_time ASC
    LIMIT 1;

    -- 5. CUTOFF WINDOW CALCULATION & AUTO STATUS DETERMINATION
    IF v_schedule IS NOT NULL THEN
        SELECT *
        INTO v_cutoffs
        FROM public.attendance_cutoffs ac
        WHERE ac.subject_offering_id = p_subject_offering_id
        LIMIT 1;

        v_present_grace_cutoff := v_schedule.start_time
            + (COALESCE(v_cutoffs.present_grace_mins, 15) * INTERVAL '1 minute');
        v_late_cutoff := v_schedule.start_time
            + (COALESCE(v_cutoffs.late_cutoff_mins, 45) * INTERVAL '1 minute');

        -- Connected to schedule auto-mark:
        -- On-time / early: PRESENT
        -- After grace period: LATE
        -- After late cutoff / after class: ABSENT (with tap recorded)
        IF v_scan_time <= v_present_grace_cutoff THEN
            v_calculated_status := 'present';
        ELSIF v_scan_time <= v_late_cutoff THEN
            v_calculated_status := 'late';
        ELSE
            v_calculated_status := 'absent';
        END IF;
    ELSE
        -- No schedule plotted today (Make-up class / unscheduled session)
        v_calculated_status := 'present';
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
                device_id = v_effective_device
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
                device_id = v_effective_device
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
                device_id = v_effective_device
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
        created_at
    ) VALUES (
        v_student_id,
        p_subject_offering_id,
        v_attendance_date,
        v_calculated_status,
        'RFID',
        v_scan_time,
        v_effective_device,
        NULL,
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

