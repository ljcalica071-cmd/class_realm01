-- Migration 020: Allow 'quiz' and 'exam' classwork types and 'ex' grading category in classwork_items
-- Ensures Classwork and Gradebook share a single source of truth across Online and In-Person methods.

ALTER TABLE public.classwork_items
  DROP CONSTRAINT IF EXISTS classwork_items_classwork_type_check,
  ADD CONSTRAINT classwork_items_classwork_type_check
    CHECK ((classwork_type)::text = ANY ((ARRAY[
      'activity'::character varying,
      'assignment'::character varying,
      'performance_task'::character varying,
      'quiz'::character varying,
      'exam'::character varying
    ])::text[]));

ALTER TABLE public.classwork_items
  DROP CONSTRAINT IF EXISTS classwork_items_grading_category_check,
  ADD CONSTRAINT classwork_items_grading_category_check
    CHECK ((grading_category)::text = ANY ((ARRAY[
      'ww'::character varying,
      'pt'::character varying,
      'ex'::character varying
    ])::text[]));

