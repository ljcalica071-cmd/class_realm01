-- Migration 028: Fix term_grades unique constraint to include term_number
-- The legacy constraint was UNIQUE (student_id, subject_offering_id), which prevented
-- storing multi-term grades for the same student and subject offering.
-- This replaces it with UNIQUE (student_id, subject_offering_id, term_number).

ALTER TABLE public.term_grades
    DROP CONSTRAINT IF EXISTS term_grades_unique_student_offering;

ALTER TABLE public.term_grades
    DROP CONSTRAINT IF EXISTS term_grades_unique_student_offering_term;

ALTER TABLE public.term_grades
    ADD CONSTRAINT term_grades_unique_student_offering_term 
    UNIQUE (student_id, subject_offering_id, term_number);

