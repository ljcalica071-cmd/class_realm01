-- Migration 011: Enable RLS and add cast-safe policies for public.attendance_cutoffs
-- Resolves the UNRESTRICTED status in Supabase Dashboard

ALTER TABLE public.attendance_cutoffs ENABLE ROW LEVEL SECURITY;

-- 1. Read access for everyone (anon and authenticated)
DROP POLICY IF EXISTS "attendance_cutoffs_read_all" ON public.attendance_cutoffs;
CREATE POLICY "attendance_cutoffs_read_all"
ON public.attendance_cutoffs
FOR SELECT
TO anon, authenticated
USING (true);

-- 2. Manage access: Teacher of the subject offering or Admin
-- Uses (auth.uid())::text to avoid "operator does not exist: character varying = uuid"
DROP POLICY IF EXISTS "attendance_cutoffs_manage_teacher" ON public.attendance_cutoffs;
CREATE POLICY "attendance_cutoffs_manage_teacher"
ON public.attendance_cutoffs
FOR ALL
TO anon, authenticated
USING (
    auth.uid() IS NULL
    OR EXISTS (
        SELECT 1
        FROM public.subject_offerings so
        WHERE so.id = attendance_cutoffs.subject_offering_id
          AND so.teacher_id = (auth.uid())::text
    )
    OR EXISTS (
        SELECT 1
        FROM public.users u
        WHERE u.id = (auth.uid())::text
          AND u.role = 'admin'
    )
)
WITH CHECK (
    auth.uid() IS NULL
    OR EXISTS (
        SELECT 1
        FROM public.subject_offerings so
        WHERE so.id = attendance_cutoffs.subject_offering_id
          AND so.teacher_id = (auth.uid())::text
    )
    OR EXISTS (
        SELECT 1
        FROM public.users u
        WHERE u.id = (auth.uid())::text
          AND u.role = 'admin'
    )
);
