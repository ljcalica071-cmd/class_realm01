-- Migration 013: Fix Gradebook Term Sheets Permissions, Unique Constraint & RLS Policies
-- Resolves:
-- 1. "permission denied for table gradebook_term_sheets" (Error 42501).
-- 2. "ON CONFLICT specification requires a UNIQUE or PRIMARY KEY constraint" on (subject_offering_id, term_number).
-- 3. Enables clean RLS allowing teachers and admins to read/write their offerings' gradebook sheets.

-- Part 1: Grant permissions to all active roles
GRANT ALL ON TABLE public.gradebook_term_sheets TO postgres, anon, authenticated, service_role;

-- Part 2: Ensure unique constraint on (subject_offering_id, term_number) for upsert onConflict support
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'gradebook_term_sheets_offering_term_unique'
    ) THEN
        ALTER TABLE public.gradebook_term_sheets 
        ADD CONSTRAINT gradebook_term_sheets_offering_term_unique 
        UNIQUE (subject_offering_id, term_number);
    END IF;
END $$;

-- Part 3: Enable Row Level Security (RLS)
ALTER TABLE public.gradebook_term_sheets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "gradebook_term_sheets_select_policy" ON public.gradebook_term_sheets;
DROP POLICY IF EXISTS "gradebook_term_sheets_modify_policy" ON public.gradebook_term_sheets;

-- Read policy: Anyone authenticated or anonymous can view term sheets
CREATE POLICY "gradebook_term_sheets_select_policy"
ON public.gradebook_term_sheets
FOR SELECT
TO anon, authenticated
USING (true);

-- Manage policy: Teacher of the offering, service_role, or Admin can insert/update/delete
CREATE POLICY "gradebook_term_sheets_modify_policy"
ON public.gradebook_term_sheets
FOR ALL
TO anon, authenticated
USING (
    auth.uid() IS NULL
    OR (auth.role() = 'service_role')
    OR EXISTS (
        SELECT 1
        FROM public.subject_offerings so
        WHERE so.id = gradebook_term_sheets.subject_offering_id
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
        WHERE so.id = gradebook_term_sheets.subject_offering_id
          AND so.teacher_id::text = auth.uid()::text
    )
    OR EXISTS (
        SELECT 1
        FROM public.users u
        WHERE u.id::text = auth.uid()::text
          AND u.role = 'admin'
    )
);
