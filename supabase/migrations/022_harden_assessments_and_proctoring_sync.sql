-- Migration 022: Harden Assessments, Proctoring Realtime Sync & Classwork Materials Storage RLS
-- 1. Assessment attempts enhancements (active_session_id, locked_submitted_at, status check)
ALTER TABLE public.assessment_attempts
  ADD COLUMN IF NOT EXISTS active_session_id text,
  ADD COLUMN IF NOT EXISTS locked_submitted_at timestamptz;

-- Update status check to include 'disqualified'
ALTER TABLE public.assessment_attempts 
  DROP CONSTRAINT IF EXISTS assessment_attempts_status_check;

ALTER TABLE public.assessment_attempts 
  ADD CONSTRAINT assessment_attempts_status_check 
  CHECK (status IN ('in_progress', 'submitted', 'auto_submitted', 'abandoned', 'disqualified'));

CREATE INDEX IF NOT EXISTS idx_assessment_attempts_student_status 
  ON public.assessment_attempts(student_id, status);

-- 2. Ensure Realtime Publication for assessment_attempts and anti_cheating_logs
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'assessment_attempts'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.assessment_attempts;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'anti_cheating_logs'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.anti_cheating_logs;
  END IF;
END $$;

-- 3. Storage bucket and RLS policies for classwork-materials
-- Ensure storage bucket exists
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'classwork-materials',
  'classwork-materials',
  true,
  15728640, -- 15MB limit
  ARRAY['application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document']
)
ON CONFLICT (id) DO UPDATE SET 
  public = true,
  file_size_limit = 15728640;

-- Enable RLS and setup permissive policies for student submissions & teacher materials
DO $$
BEGIN
  -- Read policy: Anyone can read from classwork-materials
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Public and Auth Read classwork-materials'
  ) THEN
    CREATE POLICY "Public and Auth Read classwork-materials"
      ON storage.objects FOR SELECT
      USING (bucket_id = 'classwork-materials');
  END IF;

  -- Insert policy: Authenticated and Anon can upload to classwork-materials
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Allow Uploads to classwork-materials'
  ) THEN
    CREATE POLICY "Allow Uploads to classwork-materials"
      ON storage.objects FOR INSERT
      WITH CHECK (bucket_id = 'classwork-materials');
  END IF;

  -- Update policy: Allow updating/upserting files
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Allow Updates to classwork-materials'
  ) THEN
    CREATE POLICY "Allow Updates to classwork-materials"
      ON storage.objects FOR UPDATE
      USING (bucket_id = 'classwork-materials');
  END IF;

  -- Delete policy: Allow deletion
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Allow Deletes from classwork-materials'
  ) THEN
    CREATE POLICY "Allow Deletes from classwork-materials"
      ON storage.objects FOR DELETE
      USING (bucket_id = 'classwork-materials');
  END IF;
END $$;
