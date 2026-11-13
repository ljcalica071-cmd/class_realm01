-- Migration 026: Publish / Unpublish Grades Feature
-- Adds is_published to public.term_grades (for term-level publication)
-- and is_final_grade_published to public.subject_offerings (for final-grade level publication).

ALTER TABLE public.term_grades
    ADD COLUMN IF NOT EXISTS is_published boolean NOT NULL DEFAULT false;

ALTER TABLE public.subject_offerings
    ADD COLUMN IF NOT EXISTS is_final_grade_published boolean NOT NULL DEFAULT false;

