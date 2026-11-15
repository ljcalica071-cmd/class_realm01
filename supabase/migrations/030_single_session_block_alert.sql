-- Add blocked_attempt_at column to user_session_logs for First-In-Wins
-- multi-device login protection and real-time security alert popup on the active device.
ALTER TABLE public.user_session_logs
ADD COLUMN IF NOT EXISTS blocked_attempt_at timestamp with time zone;
