-- ============================================================================
-- Migration 017: Automated Absence Warning Notifications Pipeline (3, 6, 10 Absences)
-- Integrated with 11:59 PM Manila Time EOD Auto-Absent Cron and Real-Time Scoped Notifications
-- ============================================================================

-- 1. FUNCTION: Process Absence Warning Alerts (3, 6, 10 Absences per Offering)
CREATE OR REPLACE FUNCTION public.fn_process_absence_warning_alerts(
    p_student_id varchar,
    p_subject_offering_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_total_absences integer;
    v_threshold integer := 0;
    v_student_name text;
    v_subject_name text;
    v_section text;
    v_now_iso timestamptz := now();
    v_already_alerted boolean;
BEGIN
    -- 1. Count total unexcused absences for this student in this subject offering
    SELECT COUNT(*)::integer
    INTO v_total_absences
    FROM public.attendance_records
    WHERE student_id = p_student_id
      AND subject_offering_id = p_subject_offering_id
      AND status = 'absent';

    -- 2. Determine target warning threshold
    IF v_total_absences = 3 THEN
        v_threshold := 3;
    ELSIF v_total_absences = 6 THEN
        v_threshold := 6;
    ELSIF v_total_absences >= 10 THEN
        v_threshold := 10;
    ELSE
        RETURN;
    END IF;

    -- 3. Resolve Subject & Section Metadata (joining subjects and sections tables)
    SELECT 
        COALESCE(s.subject_name, 'Class'), 
        COALESCE(sec.section_name, 'General')
    INTO v_subject_name, v_section
    FROM public.subject_offerings so
    LEFT JOIN public.subjects s ON s.id = so.subject_id
    LEFT JOIN public.sections sec ON sec.id = so.section_id
    WHERE so.id = p_subject_offering_id;

    v_subject_name := COALESCE(v_subject_name, 'Class');
    v_section := COALESCE(v_section, 'General');

    -- 4. Anti-Duplicate Guard: Check if warning for this threshold already exists
    SELECT EXISTS (
        SELECT 1
        FROM public.notifications
        WHERE notification_type = 'attendance'
          AND title ILIKE '%' || v_threshold || ' Absences)%'
          AND message ILIKE '%' || v_subject_name || '%'
    ) INTO v_already_alerted;

    IF v_already_alerted THEN
        RETURN;
    END IF;

    -- 5. Resolve Student Display Name (Lastname, Firstname)
    SELECT COALESCE(sp.last_name || ', ' || sp.first_name, 'Student')
    INTO v_student_name
    FROM public.student_profiles sp
    WHERE sp.student_id = p_student_id;

    IF v_student_name IS NULL THEN
        v_student_name := 'Student';
    END IF;

    -- 6. Insert Distinct Scoped Notifications for Teacher, Student, and Parent
    IF v_threshold = 10 THEN
        -- Teacher
        INSERT INTO public.notifications (title, message, notification_type, target_audience, is_archived, created_at)
        VALUES (
            v_student_name || ' (10 Absences)',
            v_student_name || ' has accumulated 10 absences in ' || v_subject_name || ' (' || v_section || '). Critical SARDO drop-out risk; immediate academic intervention required.',
            'attendance',
            'teachers',
            false,
            v_now_iso
        );
        -- Student
        INSERT INTO public.notifications (title, message, notification_type, target_audience, is_archived, created_at)
        VALUES (
            v_subject_name || ' (10 Absences)',
            'Critical notice: You have reached 10 absences in ' || v_subject_name || ' (' || v_section || '). Please report to your teacher and school administration immediately.',
            'attendance',
            'students',
            false,
            v_now_iso
        );
        -- Parent
        INSERT INTO public.notifications (title, message, notification_type, target_audience, is_archived, created_at)
        VALUES (
            v_student_name || ' (10 Absences)',
            'Urgent: Your child ' || v_student_name || ' has reached 10 absences in ' || v_subject_name || ' (' || v_section || ') and is at imminent risk of dropping out. Immediate conference required.',
            'attendance',
            'parents',
            false,
            v_now_iso
        );
    ELSIF v_threshold = 6 THEN
        -- Teacher
        INSERT INTO public.notifications (title, message, notification_type, target_audience, is_archived, created_at)
        VALUES (
            v_student_name || ' (6 Absences)',
            v_student_name || ' has accumulated 6 absences in ' || v_subject_name || ' (' || v_section || '). Parent-Teacher conference required to arrange remediation.',
            'attendance',
            'teachers',
            false,
            v_now_iso
        );
        -- Student
        INSERT INTO public.notifications (title, message, notification_type, target_audience, is_archived, created_at)
        VALUES (
            v_subject_name || ' (6 Absences)',
            'You have accumulated 6 absences in ' || v_subject_name || ' (' || v_section || '). This significantly impacts your academic standing. Please consult your teacher.',
            'attendance',
            'students',
            false,
            v_now_iso
        );
        -- Parent
        INSERT INTO public.notifications (title, message, notification_type, target_audience, is_archived, created_at)
        VALUES (
            v_student_name || ' (6 Absences)',
            'Your child ' || v_student_name || ' has accumulated 6 absences in ' || v_subject_name || ' (' || v_section || '). Please schedule a conference with the subject teacher.',
            'attendance',
            'parents',
            false,
            v_now_iso
        );
    ELSE
        -- 3 Absences - 1st Warning
        -- Teacher
        INSERT INTO public.notifications (title, message, notification_type, target_audience, is_archived, created_at)
        VALUES (
            v_student_name || ' (3 Absences)',
            v_student_name || ' has reached 3 recorded absences in ' || v_subject_name || ' (' || v_section || '). Please initiate an early attendance check-in.',
            'attendance',
            'teachers',
            false,
            v_now_iso
        );
        -- Student
        INSERT INTO public.notifications (title, message, notification_type, target_audience, is_archived, created_at)
        VALUES (
            v_subject_name || ' (3 Absences)',
            'You have reached 3 absences in ' || v_subject_name || ' (' || v_section || '). Please coordinate with your teacher and submit excuse letters for missed sessions.',
            'attendance',
            'students',
            false,
            v_now_iso
        );
        -- Parent
        INSERT INTO public.notifications (title, message, notification_type, target_audience, is_archived, created_at)
        VALUES (
            v_student_name || ' (3 Absences)',
            'Your child ' || v_student_name || ' has missed 3 sessions in ' || v_subject_name || ' (' || v_section || '). Please assist in ensuring regular and punctual class attendance.',
            'attendance',
            'parents',
            false,
            v_now_iso
        );
    END IF;
END;
$$;

-- 2. UPDATED FUNCTION: fn_trigger_daily_auto_absent (Calls Warning Evaluation)
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
    r RECORD;
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

    -- 3. Insert 'absent' for enrolled students in offerings scheduled today without an attendance entry
    FOR r IN
        WITH scheduled_offerings AS (
            SELECT DISTINCT ts.subject_offering_id
            FROM public.teacher_schedule ts
            JOIN public.subject_offerings so
              ON so.id = ts.subject_offering_id
            WHERE ts.day_of_week = v_dow
              AND ts.is_active = true
              AND so.is_archived = false
        )
        INSERT INTO public.attendance_records (
            student_id,
            subject_offering_id,
            attendance_date,
            status,
            recording_method,
            remarks,
            created_at
        )
        SELECT
            se.student_id,
            se.subject_offering_id,
            p_target_date,
            'absent',
            'System',
            NULL,
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
        RETURNING student_id, subject_offering_id
    LOOP
        v_inserted_count := v_inserted_count + 1;
        -- Evaluate 3, 6, 10 threshold warnings automatically
        PERFORM public.fn_process_absence_warning_alerts(r.student_id, r.subject_offering_id);
    END LOOP;

    RETURN v_inserted_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_process_absence_warning_alerts(varchar, uuid) TO service_role, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_trigger_daily_auto_absent(date) TO service_role, authenticated;

