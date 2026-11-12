-- Migration 025: Enable RLS and Grant Policies for Submissions and Attachments
-- Ensures students can submit attachments and teachers can view all submission attachments.

-- 1. submission_attachments
ALTER TABLE public.submission_attachments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow select submission_attachments" ON public.submission_attachments;
CREATE POLICY "Allow select submission_attachments"
ON public.submission_attachments
FOR SELECT
TO authenticated, anon
USING (true);

DROP POLICY IF EXISTS "Allow insert submission_attachments" ON public.submission_attachments;
CREATE POLICY "Allow insert submission_attachments"
ON public.submission_attachments
FOR INSERT
TO authenticated, anon
WITH CHECK (true);

DROP POLICY IF EXISTS "Allow update submission_attachments" ON public.submission_attachments;
CREATE POLICY "Allow update submission_attachments"
ON public.submission_attachments
FOR UPDATE
TO authenticated, anon
USING (true)
WITH CHECK (true);

DROP POLICY IF EXISTS "Allow delete submission_attachments" ON public.submission_attachments;
CREATE POLICY "Allow delete submission_attachments"
ON public.submission_attachments
FOR DELETE
TO authenticated, anon
USING (true);

-- 2. classwork_attachments
ALTER TABLE public.classwork_attachments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow select classwork_attachments" ON public.classwork_attachments;
CREATE POLICY "Allow select classwork_attachments"
ON public.classwork_attachments
FOR SELECT
TO authenticated, anon
USING (true);

DROP POLICY IF EXISTS "Allow insert classwork_attachments" ON public.classwork_attachments;
CREATE POLICY "Allow insert classwork_attachments"
ON public.classwork_attachments
FOR INSERT
TO authenticated, anon
WITH CHECK (true);

DROP POLICY IF EXISTS "Allow update classwork_attachments" ON public.classwork_attachments;
CREATE POLICY "Allow update classwork_attachments"
ON public.classwork_attachments
FOR UPDATE
TO authenticated, anon
USING (true)
WITH CHECK (true);

DROP POLICY IF EXISTS "Allow delete classwork_attachments" ON public.classwork_attachments;
CREATE POLICY "Allow delete classwork_attachments"
ON public.classwork_attachments
FOR DELETE
TO authenticated, anon
USING (true);

-- 3. student_classwork_submissions
ALTER TABLE public.student_classwork_submissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow select student_classwork_submissions" ON public.student_classwork_submissions;
CREATE POLICY "Allow select student_classwork_submissions"
ON public.student_classwork_submissions
FOR SELECT
TO authenticated, anon
USING (true);

DROP POLICY IF EXISTS "Allow insert student_classwork_submissions" ON public.student_classwork_submissions;
CREATE POLICY "Allow insert student_classwork_submissions"
ON public.student_classwork_submissions
FOR INSERT
TO authenticated, anon
WITH CHECK (true);

DROP POLICY IF EXISTS "Allow update student_classwork_submissions" ON public.student_classwork_submissions;
CREATE POLICY "Allow update student_classwork_submissions"
ON public.student_classwork_submissions
FOR UPDATE
TO authenticated, anon
USING (true)
WITH CHECK (true);
