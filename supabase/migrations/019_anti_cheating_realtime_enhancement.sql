-- Migration 018: Anti-Cheating & Realtime Proctoring Enhancements
ALTER TABLE public.anti_cheating_logs
  ALTER COLUMN assessment_attempt_id DROP NOT NULL;

ALTER TABLE public.anti_cheating_logs
  ADD COLUMN IF NOT EXISTS assessment_id uuid REFERENCES public.digital_assessments(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS student_id text,
  ADD COLUMN IF NOT EXISTS details text;

CREATE INDEX IF NOT EXISTS idx_anti_cheating_logs_assessment_id ON public.anti_cheating_logs(assessment_id);
CREATE INDEX IF NOT EXISTS idx_anti_cheating_logs_student_id ON public.anti_cheating_logs(student_id);

-- Enable Supabase Realtime publication for anti_cheating_logs
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'anti_cheating_logs'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.anti_cheating_logs;
  END IF;
END $$;

