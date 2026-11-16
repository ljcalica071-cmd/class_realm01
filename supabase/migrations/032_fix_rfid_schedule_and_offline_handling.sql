-- ============================================================================
-- Migration 032: Strict Classroom Wall RFID Attendance with Idempotent Re-Tap
-- ============================================================================
-- 1. Strictly enforces the Classroom/Teacher Wall:
--    - The hardware scanner belongs to the active class/teacher offering.
--    - If a student is NOT enrolled in this teacher's class, it immediately
--      rejects with 'CROSS_SECTION_TAP' -> OLED: [ ENROLLMENT ] WRONG SECTION.
--    - Zero cross-contamination: students cannot cut class and tap at another room.
-- 2. Fixed Idempotency Re-Tap Bug:
--    - Uses 'IF v_existing.id IS NOT NULL' so re-taps properly trigger
--      'IDEMPOTENT_ALREADY_RECORDED' -> OLED: [ VERIFIED ] ALREADY MARKED.
-- 3. Fully preserves:
--    - Teacher RFID Linking Mode (Link-Only guard)
--    - School Holidays / Suspensions
--    - On-Time (Present), Grace Period, Late Cutoff, and Auto-Absent
--    - Too Early (Before Window) and Scans Closed (Class Ended)
-- ============================================================================

-- Ensure rfid_devices has subject_offering_id and assigned_teacher_id
ALTER TABLE public.rfid_devices 
ADD COLUMN IF NOT EXISTS subject_offering_id uuid REFERENCES public.subject_offerings(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS assigned_teacher_id varchar(30);

-- Drop existing overloads to ensure a clean function replacement
DROP FUNCTION IF EXISTS public.record_rfid_attendance(varchar, varchar, timestamptz, uuid);
DROP FUNCTION IF EXISTS public.record_rfid_attendance(varchar, uuid, timestamptz, varchar);
DROP FUNCTION IF EXISTS public.record_rfid_attendance(varchar, uuid, timestamptz);
DROP FUNCTION IF EXISTS public.record_rfid_attendance(uuid, varchar, timestamptz, varchar);

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
    v_effective_offering_id uuid := p_subject_offering_id;
    v_assigned_offering_id uuid;
    v_holiday_name varchar(120);
    v_student_id varchar(30);
    v_student_name text;
    v_is_linking_mode boolean := false;
    v_linking_target_id varchar(64);
    v_linking_target_name text;
    v_is_enrolled_in_passed boolean := false;
    v_schedule record;
    v_cutoffs record;
    v_existing record;
    v_present_open_time time;
    v_present_grace_cutoff time;
    v_late_cutoff time;
    v_calculated_status varchar(10);
BEGIN
    v_normalized_uid := UPPER(TRIM(COALESCE(p_rfid_uid, '')));
    v_hex_only_uid := REGEXP_REPLACE(v_normalized_uid, '[^0-9A-F]', '', 'g');

    -- Dynamic Device Ownership: If the physical hardware is currently claimed by
    -- a teacher who opened their attendance screen, bind to that teacher's class!
    BEGIN
        SELECT rd.subject_offering_id
        INTO v_assigned_offering_id
        FROM public.rfid_devices rd
        WHERE rd.device_uid = v_effective_device
          AND rd.is_active = true
          AND rd.subject_offering_id IS NOT NULL
        LIMIT 1;

        IF v_assigned_offering_id IS NOT NULL THEN
            v_effective_offering_id := v_assigned_offering_id;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    -- Update hardware device heartbeat if registered
    BEGIN
        UPDATE public.rfid_devices
        SET last_sync_at = now()
        WHERE device_uid = v_effective_device;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    -- 1. HOLIDAY CHECK ([ HOLIDAY ] NO CLASS)
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
            'message', 'Class Suspended / Active Holiday (' || v_holiday_name || ').'
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

    -- 2B. TEACHER RFID LINKING MODE GUARD (Strictly Link-Only)
    SELECT is_active, target_student_id
    INTO v_is_linking_mode, v_linking_target_id
    FROM public.rfid_linking_mode
    WHERE id = 'GLOBAL'
      AND is_active = true
      AND expires_at > now()
    LIMIT 1;

    IF COALESCE(v_is_linking_mode, false) = true THEN
        INSERT INTO public.rfid_pending_scans (rfid_uid, device_id, subject_offering_id, scanned_at, is_claimed)
        VALUES (v_normalized_uid, v_effective_device, p_subject_offering_id, now(), false);

        IF v_student_id IS NOT NULL THEN
            RETURN jsonb_build_object(
                'success', false,
                'code', 'CARD_ALREADY_OWNED',
                'rfid_uid', v_normalized_uid,
                'student_id', v_student_id,
                'student_name', v_student_name,
                'message', 'Wrong Card • Owned by ' || v_student_name
            );
        END IF;

        IF v_linking_target_id IS NOT NULL AND TRIM(v_linking_target_id) <> '' THEN
            UPDATE public.student_profiles
            SET rfid_uid = v_normalized_uid
            WHERE student_id = v_linking_target_id
            RETURNING TRIM(last_name || ', ' || first_name)
            INTO v_linking_target_name;

            UPDATE public.rfid_linking_mode
            SET is_active = false,
                updated_at = now()
            WHERE id = 'GLOBAL';

            IF v_linking_target_name IS NOT NULL THEN
                RETURN jsonb_build_object(
                    'success', true,
                    'code', 'CARD_LINKED_SUCCESS',
                    'rfid_uid', v_normalized_uid,
                    'student_id', v_linking_target_id,
                    'student_name', v_linking_target_name,
                    'message', 'Linked RFID card ' || v_normalized_uid || ' to ' || v_linking_target_name || '.'
                );
            END IF;
        END IF;

        RETURN jsonb_build_object(
            'success', false,
            'code', 'UNREGISTERED_CARD',
            'rfid_uid', v_normalized_uid,
            'message', 'UID: ' || v_normalized_uid || ' • Linked in Teacher App.'
        );
    END IF;

    -- Unregistered Card Scan (Broadcasts to Teacher UI for linking)
    IF v_student_id IS NULL THEN
        INSERT INTO public.rfid_pending_scans (rfid_uid, device_id, subject_offering_id, scanned_at, is_claimed)
        VALUES (v_normalized_uid, v_effective_device, p_subject_offering_id, now(), false);

        RETURN jsonb_build_object(
            'success', false,
            'code', 'UNREGISTERED_CARD',
            'rfid_uid', v_normalized_uid,
            'message', 'UID: ' || v_normalized_uid || ' • Ready to link in Teacher App.'
        );
    END IF;

    -- 3. STRICT SECTION & ENROLLMENT ENFORCEMENT (THE CLASSROOM WALL)
    -- Verify that the student is strictly enrolled in this scanner's active offering
    SELECT EXISTS (
        SELECT 1
        FROM public.student_enrollments se
        WHERE se.student_id = v_student_id
          AND se.subject_offering_id = v_effective_offering_id
          AND LOWER(TRIM(se.status)) = 'enrolled'
    ) INTO v_is_enrolled_in_passed;

    IF NOT v_is_enrolled_in_passed THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'CROSS_SECTION_TAP',
            'student_id', v_student_id,
            'student_name', v_student_name,
            'message', v_student_name || ' is not enrolled in this section.'
        );
    END IF;

    -- 4. LOAD ACTIVE SCHEDULE FOR RESOLVED OFFERING
    SELECT *
    INTO v_schedule
    FROM public.teacher_schedule ts
    WHERE ts.subject_offering_id = v_effective_offering_id
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
            'message', 'No class schedule set for this subject today.'
        );
    END IF;

    -- 5. CUTOFF WINDOW CALCULATION & AUTO STATUS DETERMINATION
    SELECT *
    INTO v_cutoffs
    FROM public.attendance_cutoffs ac
    WHERE ac.subject_offering_id = v_effective_offering_id
    LIMIT 1;

    v_present_open_time := v_schedule.start_time
        - (COALESCE(v_cutoffs.present_start_mins_before, 15) * INTERVAL '1 minute');
    v_present_grace_cutoff := v_schedule.start_time
        + (COALESCE(v_cutoffs.present_grace_mins, 15) * INTERVAL '1 minute');
    v_late_cutoff := v_schedule.start_time
        + (COALESCE(v_cutoffs.late_cutoff_mins, 45) * INTERVAL '1 minute');

    -- Rule 10: Too Early ([ SCHEDULE ] TOO EARLY)
    IF v_scan_time < v_present_open_time THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'BEFORE_WINDOW_OPENS',
            'student_id', v_student_id,
            'student_name', v_student_name,
            'open_time', to_char(v_present_open_time, 'HH12:MI AM'),
            'message', 'Attendance window opens at ' || to_char(v_present_open_time, 'HH12:MI AM') || '.'
        );
    END IF;

    -- Rule 11: Class Ended ([ SCHEDULE ] CLASS ENDED)
    IF v_schedule.end_time IS NOT NULL AND v_scan_time > v_schedule.end_time THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'AFTER_CLASS_ENDS',
            'student_id', v_student_id,
            'student_name', v_student_name,
            'end_time', to_char(v_schedule.end_time, 'HH12:MI AM'),
            'message', 'Class session ended • Scans are closed.'
        );
    END IF;

    -- Rule 1, 2, 3: On-Time Present, Late, or Past Cutoff (Marked Absent)
    IF v_scan_time <= v_present_grace_cutoff THEN
        v_calculated_status := 'present';
    ELSIF v_scan_time <= v_late_cutoff THEN
        v_calculated_status := 'late';
    ELSE
        v_calculated_status := 'absent';
    END IF;

    -- 6. DETERMINISTIC CONFLICT RESOLUTION (Anti-Cheat & Idempotency)
    SELECT *
    INTO v_existing
    FROM public.attendance_records ar
    WHERE ar.student_id = v_student_id
      AND ar.subject_offering_id = v_effective_offering_id
      AND ar.attendance_date = v_attendance_date
    FOR UPDATE;

    IF v_existing.id IS NOT NULL THEN
        -- Promote System Auto-Absent when delayed offline RFID tap arrives
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
                'message', v_student_name || ' • Recorded at ' || to_char(v_scan_time, 'HH12:MI AM')
            );
        END IF;

        -- Delayed offline sync: earlier physical tap wins if it was on-time
        IF v_existing.recording_method = 'RFID'
           AND v_existing.time_in IS NOT NULL
           AND v_scan_time < v_existing.time_in
           AND (
               (v_existing.status = 'late' AND v_calculated_status = 'present')
               OR (v_existing.status = 'absent' AND v_calculated_status IN ('present', 'late'))
               OR (v_existing.status = v_calculated_status)
           ) THEN
            UPDATE public.attendance_records
            SET status = v_calculated_status,
                time_in = v_scan_time,
                device_id = v_effective_device,
                updated_at = now()
            WHERE id = v_existing.id;

            RETURN jsonb_build_object(
                'success', true,
                'code', 'RECORDED_SUCCESS',
                'status', v_calculated_status,
                'student_id', v_student_id,
                'student_name', v_student_name,
                'time_in', to_char(v_scan_time, 'HH12:MI AM'),
                'message', v_student_name || ' • Recorded at ' || to_char(v_scan_time, 'HH12:MI AM')
            );
        END IF;

        -- Rule 8: Re-Tap on the same day ([ VERIFIED ] ALREADY MARKED)
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
            'message', v_student_name || ' was already recorded at ' || COALESCE(to_char(v_existing.time_in, 'HH12:MI AM'), to_char(v_scan_time, 'HH12:MI AM'))
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
        v_effective_offering_id,
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
        'message', CASE
            WHEN v_calculated_status = 'absent' THEN v_student_name || ' • Marked Absent (Past Cutoff)'
            ELSE v_student_name || ' • Recorded at ' || to_char(v_scan_time, 'HH12:MI AM')
        END
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_rfid_attendance(varchar, uuid, timestamptz, varchar) TO anon, authenticated, service_role;
