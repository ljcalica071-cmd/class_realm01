-- Migration 016: 18+ Student Grade Privacy Controls & Parent Portal Teacher Directory Access
-- Adds granular grade visibility toggles for legal-age students (18+) in public.student_settings
-- and ensures parents can read student_settings privacy flags and teacher public contact settings.

-- 1. Add 18+ grade privacy columns to public.student_settings
ALTER TABLE public.student_settings
    ADD COLUMN IF NOT EXISTS hide_term_grades_from_parent boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS hide_final_grades_from_parent boolean NOT NULL DEFAULT false;

-- 2. Enforce 18+ age requirement at the database level via BEFORE INSERT OR UPDATE trigger
CREATE OR REPLACE FUNCTION public.enforce_student_18plus_grade_privacy()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_birthday date;
    v_age_years int;
BEGIN
    IF (NEW.hide_term_grades_from_parent = true OR NEW.hide_final_grades_from_parent = true) THEN
        SELECT birthday INTO v_birthday
        FROM public.student_profiles
        WHERE student_id = NEW.student_id;

        IF v_birthday IS NULL THEN
            NEW.hide_term_grades_from_parent := false;
            NEW.hide_final_grades_from_parent := false;
        ELSE
            v_age_years := EXTRACT(YEAR FROM AGE(CURRENT_DATE, v_birthday))::int;
            IF v_age_years < 18 THEN
                RAISE EXCEPTION 'Grade privacy controls are only available to students aged 18 and above.';
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_student_18plus_grade_privacy ON public.student_settings;
CREATE TRIGGER trg_enforce_student_18plus_grade_privacy
BEFORE INSERT OR UPDATE ON public.student_settings
FOR EACH ROW
EXECUTE FUNCTION public.enforce_student_18plus_grade_privacy();

-- 3. Grant select/update permissions so students and linked parents can read/update settings cleanly
GRANT SELECT, INSERT, UPDATE ON TABLE public.student_settings TO anon, authenticated, service_role;
GRANT SELECT ON TABLE public.teacher_settings TO anon, authenticated, service_role;
GRANT SELECT ON TABLE public.teacher_profiles TO anon, authenticated, service_role;
