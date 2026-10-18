-- Migration 003: Update user status constraints for teachers, students, and parents
-- Restrict valid statuses strictly to: 'pending_first_login', 'active', 'archived'

-- 1. Teacher Settings
ALTER TABLE public.teacher_settings DROP CONSTRAINT IF EXISTS teacher_settings_status_check;
UPDATE public.teacher_settings SET status = 'archived' WHERE status IN ('inactive', 'pending');
ALTER TABLE public.teacher_settings ADD CONSTRAINT teacher_settings_status_check CHECK (status::text = ANY (ARRAY['pending_first_login'::text, 'active'::text, 'archived'::text]));
ALTER TABLE public.teacher_settings ALTER COLUMN status SET DEFAULT 'pending_first_login';

-- 2. Student Settings
ALTER TABLE public.student_settings DROP CONSTRAINT IF EXISTS student_settings_status_check;
UPDATE public.student_settings SET status = 'archived' WHERE status IN ('inactive', 'pending');
ALTER TABLE public.student_settings ADD CONSTRAINT student_settings_status_check CHECK (status::text = ANY (ARRAY['pending_first_login'::text, 'active'::text, 'archived'::text]));
ALTER TABLE public.student_settings ALTER COLUMN status SET DEFAULT 'pending_first_login';

-- 3. Parent Profiles
ALTER TABLE public.parent_profiles DROP CONSTRAINT IF EXISTS parent_profiles_status_check;
UPDATE public.parent_profiles SET status = 'archived' WHERE status IN ('inactive', 'pending');
ALTER TABLE public.parent_profiles ADD CONSTRAINT parent_profiles_status_check CHECK (status::text = ANY (ARRAY['pending_first_login'::text, 'active'::text, 'archived'::text]));
ALTER TABLE public.parent_profiles ALTER COLUMN status SET DEFAULT 'pending_first_login';
