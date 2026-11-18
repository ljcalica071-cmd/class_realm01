-- ============================================================================
-- Migration 036: Fix Teacher Notification Scoping & Unread Count RPC
-- 1. Tightens teacher notification scoping in get_user_notifications so that
--    student-targeted / parent-targeted alerts (such as grade alerts authored by
--    the teacher) are not included in the teacher's incoming notifications.
-- 2. Ensures notifications created by the user (n.created_by = p_user_id) are
--    never counted as unread incoming notifications for the creator in
--    get_user_unread_notification_count.
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
        OR n.student_id = p_user_id
        OR nr.user_id = p_user_id
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

CREATE OR REPLACE FUNCTION public.get_user_unread_notification_count(
    p_user_id varchar
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count integer;
BEGIN
  SELECT COUNT(*)::integer INTO v_count
  FROM public.get_user_notifications(p_user_id, 200) n
  WHERE (n.created_by IS NULL OR n.created_by != p_user_id)
    AND NOT EXISTS (
      SELECT 1 FROM public.notification_recipients nr
      WHERE nr.notification_id = n.id
        AND nr.user_id = p_user_id
        AND nr.read_at IS NOT NULL
    );
  RETURN COALESCE(v_count, 0);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_notifications(varchar, integer) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_user_unread_notification_count(varchar) TO anon, authenticated, service_role;
