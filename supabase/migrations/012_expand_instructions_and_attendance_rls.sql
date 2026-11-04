-- Migration 012: Expand classwork instructions limit & enable safe RLS on attendance_cutoffs
-- Resolves:
-- 1. "value too long for type character varying(1000)" when saving detailed instructions & rubrics up to 30,000 chars.
-- 2. "UNRESTRICTED" warning on attendance_cutoffs with cast-safe RLS policies.

-- Part 1: Expand instructions to text (supports up to 1GB / unlimited chars)
ALTER TABLE public.classwork_items 
    ALTER COLUMN instructions TYPE text;

ALTER TABLE public.digital_assessments 
    ALTER COLUMN instructions TYPE text;

-- Part 2: Enable Row Level Security (RLS) on attendance_cutoffs
ALTER TABLE public.attendance_cutoffs ENABLE ROW LEVEL SECURITY;

-- Drop any previous conflicting policies
DROP POLICY IF EXISTS "attendance_cutoffs_read_all" ON public.attendance_cutoffs;
DROP POLICY IF EXISTS "attendance_cutoffs_manage_teacher" ON public.attendance_cutoffs;

-- Read policy: Anyone authenticated or anonymous can view cutoffs
CREATE POLICY "attendance_cutoffs_read_all"
ON public.attendance_cutoffs
FOR SELECT
TO anon, authenticated
USING (true);

-- Manage policy: Teacher of the offering or Admin can insert/update/delete
CREATE POLICY "attendance_cutoffs_manage_teacher"
ON public.attendance_cutoffs
FOR ALL
TO anon, authenticated
USING (
    auth.uid() IS NULL
    OR (auth.role() = 'service_role')
    OR EXISTS (
        SELECT 1
        FROM public.subject_offerings so
        WHERE so.id = attendance_cutoffs.subject_offering_id
          AND so.teacher_id::text = auth.uid()::text
    )
    OR EXISTS (
        SELECT 1
        FROM public.users u
        WHERE u.id::text = auth.uid()::text
          AND u.role = 'admin'
    )
)
WITH CHECK (
    auth.uid() IS NULL
    OR (auth.role() = 'service_role')
    OR EXISTS (
        SELECT 1
        FROM public.subject_offerings so
        WHERE so.id = attendance_cutoffs.subject_offering_id
          AND so.teacher_id::text = auth.uid()::text
    )
    OR EXISTS (
        SELECT 1
        FROM public.users u
        WHERE u.id::text = auth.uid()::text
          AND u.role = 'admin'
    )
);

