-- ============================================================================
-- Migration 037: Fix Student Audience Check in get_user_notifications RPC
-- Ensures parent-only notifications (target_audience = 'parents') tied to a
-- student_id are never returned to the student or counted in the student's
-- unread notification badge.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_notifications(
    p_user_id varchar,
    p_limit integer DEFAULT 50
)
RETURNS SETOF public.notifications
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role character varying;
BEGIN
  -- 1. Identify user's role
  SELECT role INTO v_role FROM public.users WHERE id = p_user_id;
  
  IF v_role IS NULL THEN
    RETURN;
  END IF;

  IF v_role = 'teacher' THEN
    RETURN QUERY
    SELECT DISTINCT n.* FROM public.notifications n
    LEFT JOIN public.notification_recipients nr 
      ON nr.notification_id = n.id AND nr.user_id = p_user_id
    WHERE n.is_archived = false
      AND (
        -- Directly targeted to this teacher
        n.recipient_id = p_user_id
        OR nr.user_id = p_user_id
        -- Targeted to teachers or all
        OR (
          n.target_audience IN ('teachers', 'all')
          AND (
            -- Teacher of this offering
            (
              n.subject_offering_id IS NOT NULL 
              AND EXISTS (
                SELECT 1 FROM public.subject_offerings so 
                WHERE so.id = n.subject_offering_id 
                  AND so.teacher_id = p_user_id
              )
            )
            -- School-wide teacher broadcasts (MUST be explicitly school_wide with no class/student scope)
            OR (
              n.scope = 'school_wide'
              AND n.subject_offering_id IS NULL
              AND n.student_id IS NULL
              AND n.recipient_id IS NULL
            )
          )
        )
      )
    ORDER BY n.created_at DESC
    LIMIT p_limit;

  ELSIF v_role = 'student' THEN
    RETURN QUERY
    SELECT DISTINCT n.* FROM public.notifications n
    LEFT JOIN public.notification_recipients nr 
      ON nr.notification_id = n.id AND nr.user_id = p_user_id
    WHERE n.is_archived = false
      AND (
        -- Directly targeted to this student
        n.recipient_id = p_user_id
        OR nr.user_id = p_user_id
        -- Student-specific alert ONLY when audience includes students (never parent-only alerts)
        OR (
          n.student_id = p_user_id
          AND n.target_audience IN ('students', 'students_parents', 'all')
        )
        -- Class-scoped where student is enrolled
        OR (
          n.scope = 'class'
          AND n.subject_offering_id IS NOT NULL 
          AND (n.target_audience IN ('students', 'students_parents', 'all'))
          AND (n.student_id IS NULL OR n.student_id = p_user_id)
          AND EXISTS (
            SELECT 1 FROM public.student_enrollments se 
            WHERE se.subject_offering_id = n.subject_offering_id 
              AND se.student_id = p_user_id 
              AND LOWER(TRIM(se.status)) = 'enrolled'
          )
        )
        -- Genuine School-wide broadcasts ONLY (admin created, scope = 'school_wide', NO offering, NO student, NO individual recipient)
        OR (
          n.scope = 'school_wide'
          AND n.target_audience IN ('students', 'students_parents', 'all')
          AND n.recipient_id IS NULL
          AND n.subject_offering_id IS NULL
          AND n.student_id IS NULL
        )
      )
    ORDER BY n.created_at DESC
    LIMIT p_limit;

  ELSIF v_role = 'parent' THEN
    RETURN QUERY
    SELECT DISTINCT n.* FROM public.notifications n
    LEFT JOIN public.notification_recipients nr 
      ON nr.notification_id = n.id AND nr.user_id = p_user_id
    WHERE n.is_archived = false
      AND (
        -- Directly targeted to this parent
        n.recipient_id = p_user_id
        OR nr.user_id = p_user_id
        -- Targeted to parent's linked child
        OR (
          n.student_id IS NOT NULL 
          AND (n.target_audience IN ('parents', 'students_parents', 'all'))
          AND EXISTS (
            SELECT 1 FROM public.parent_student_links psl 
            WHERE psl.parent_id = p_user_id 
              AND psl.student_id = n.student_id
          )
        )
        -- Class-scoped where parent's linked child is enrolled
        OR (
          n.scope = 'class'
          AND n.subject_offering_id IS NOT NULL 
          AND (n.target_audience IN ('parents', 'students_parents', 'all'))
          AND (
            n.student_id IS NULL 
            OR EXISTS (
              SELECT 1 FROM public.parent_student_links psl
              WHERE psl.parent_id = p_user_id AND psl.student_id = n.student_id
            )
          )
          AND EXISTS (
            SELECT 1 FROM public.parent_student_links psl
            JOIN public.student_enrollments se ON se.student_id = psl.student_id
            WHERE psl.parent_id = p_user_id
              AND se.subject_offering_id = n.subject_offering_id
              AND LOWER(TRIM(se.status)) = 'enrolled'
          )
        )
        -- Genuine School-wide broadcasts ONLY
        OR (
          n.scope = 'school_wide'
          AND n.target_audience IN ('parents', 'students_parents', 'all')
          AND n.recipient_id IS NULL
          AND n.subject_offering_id IS NULL
          AND n.student_id IS NULL
        )
      )
    ORDER BY n.created_at DESC
    LIMIT p_limit;

  ELSIF v_role = 'admin' THEN
    RETURN QUERY
    SELECT * FROM public.notifications n
    WHERE n.is_archived = false
    ORDER BY n.created_at DESC
    LIMIT p_limit;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_notifications(varchar, integer) TO anon, authenticated, service_role;
