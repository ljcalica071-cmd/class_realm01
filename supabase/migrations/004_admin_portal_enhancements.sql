-- Migration 004: Admin Portal Enhancements, System Settings, User Session Logs, and Notifications
-- Supports Maintenance Mode gatekeeping, Consecutive School Year checks, and Real-time Activity Telemetry

-- 1. Singleton Global System Settings Table
CREATE TABLE IF NOT EXISTS public.system_settings (
  id boolean PRIMARY KEY DEFAULT true CHECK (id = true),
  is_maintenance_mode boolean NOT NULL DEFAULT false,
  maintenance_updated_at timestamp with time zone NOT NULL DEFAULT now(),
  maintenance_updated_by character varying REFERENCES public.users(id),
  school_year_updated_at timestamp with time zone DEFAULT now(),
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Seed singleton row if not exists
INSERT INTO public.system_settings (id, is_maintenance_mode)
VALUES (true, false)
ON CONFLICT (id) DO NOTHING;

-- Enable RLS on system_settings
ALTER TABLE public.system_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access to system_settings"
  ON public.system_settings
  FOR SELECT
  USING (true);

CREATE POLICY "Allow admin update access to system_settings"
  ON public.system_settings
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE public.users.id = auth.uid()::text
      AND public.users.role = 'admin'
    )
  );

-- 2. Database-Level Maintenance Mode RLS Helper Function (Edge Case #5)
CREATE OR REPLACE FUNCTION public.is_system_operational_for_user(p_user_id character varying)
RETURNS boolean AS $$
DECLARE
  v_is_maintenance boolean;
  v_role character varying;
BEGIN
  -- Read maintenance status
  SELECT is_maintenance_mode INTO v_is_maintenance 
  FROM public.system_settings 
  WHERE id = true;

  -- If not in maintenance mode, operational for everyone
  IF v_is_maintenance IS NOT TRUE THEN
    RETURN true;
  END IF;

  -- If in maintenance mode, operational ONLY for Admin
  SELECT role INTO v_role 
  FROM public.users 
  WHERE id = p_user_id;

  IF v_role = 'admin' THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Consecutive School Year CHECK Constraint (Edge Case #12)
ALTER TABLE public.school_years DROP CONSTRAINT IF EXISTS school_years_consecutive_check;
ALTER TABLE public.school_years
ADD CONSTRAINT school_years_consecutive_check
CHECK (
  school_year::text ~ '^[0-9]{4}-[0-9]{4}$'
  AND CAST(split_part(school_year, '-', 2) AS integer) = CAST(split_part(school_year, '-', 1) AS integer) + 1
);

-- 4. User Session Logs Table (Real-Time Usage & 30-Min Auto-Logout Tracking)
CREATE TABLE IF NOT EXISTS public.user_session_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id character varying NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  role character varying NOT NULL,
  session_date date NOT NULL DEFAULT CURRENT_DATE,
  login_at timestamp with time zone NOT NULL DEFAULT now(),
  last_active_at timestamp with time zone NOT NULL DEFAULT now(),
  logout_at timestamp with time zone,
  logout_reason character varying CHECK (logout_reason IN ('manual', 'inactivity_timeout', 'maintenance_forced', 'session_expired')),
  is_active boolean NOT NULL DEFAULT true,
  duration_seconds integer NOT NULL DEFAULT 0 CHECK (duration_seconds >= 0),
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_session_logs_user_date ON public.user_session_logs(user_id, session_date);
CREATE INDEX IF NOT EXISTS idx_user_session_logs_active ON public.user_session_logs(is_active);

ALTER TABLE public.user_session_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert and update their own session logs"
  ON public.user_session_logs
  FOR ALL
  USING (user_id = auth.uid()::text)
  WITH CHECK (user_id = auth.uid()::text);

CREATE POLICY "Admin can view all session logs"
  ON public.user_session_logs
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE public.users.id = auth.uid()::text
      AND public.users.role = 'admin'
    )
  );

-- 5. Notifications Enhancements
ALTER TABLE public.notifications 
ADD COLUMN IF NOT EXISTS target_audience character varying NOT NULL DEFAULT 'all';

ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_target_audience_check;
ALTER TABLE public.notifications 
ADD CONSTRAINT notifications_target_audience_check 
CHECK (target_audience IN ('all', 'teachers', 'students_parents'));

ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_title_length_check;
ALTER TABLE public.notifications 
ADD CONSTRAINT notifications_title_length_check 
CHECK (char_length(trim(title)) >= 3 AND char_length(title) <= 100);

ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_message_length_check;
ALTER TABLE public.notifications 
ADD CONSTRAINT notifications_message_length_check 
CHECK (char_length(trim(message)) >= 5 AND char_length(message) <= 1000);
