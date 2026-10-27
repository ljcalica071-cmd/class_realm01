-- 007_cleanup_logout_reasons.sql
-- Consolidate logout reasons to 3 standard types: 'manual', 'inactivity', 'terminated'

-- 1. Migrate existing non-standard logout reasons to 'terminated'
UPDATE public.user_session_logs
SET logout_reason = 'terminated'
WHERE logout_reason NOT IN ('manual', 'inactivity', 'terminated')
   OR logout_reason = 'session_superseded';

-- 2. Update trigger to use 'terminated'
CREATE OR REPLACE FUNCTION public.trg_user_session_logs_before_insert()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NEW.login_at IS NULL THEN
    NEW.login_at := NOW();
  END IF;

  IF NEW.last_active_at IS NULL THEN
    NEW.last_active_at := NEW.login_at;
  END IF;

  UPDATE user_session_logs
  SET
    is_active = false,
    logout_at = GREATEST(login_at, COALESCE(last_active_at, NOW())),
    logout_reason = COALESCE(logout_reason, 'terminated'),
    duration_seconds = GREATEST(
      COALESCE(duration_seconds, 0),
      EXTRACT(EPOCH FROM (GREATEST(login_at, COALESCE(last_active_at, NOW())) - login_at))::int
    )
  WHERE user_id = NEW.user_id AND is_active = true;

  RETURN NEW;
END;
$function$;

-- 3. Update table check constraint to strictly allow only 'manual', 'inactivity', 'terminated'
ALTER TABLE public.user_session_logs
  DROP CONSTRAINT IF EXISTS user_session_logs_logout_reason_check;

ALTER TABLE public.user_session_logs
  ADD CONSTRAINT user_session_logs_logout_reason_check
  CHECK (logout_reason IS NULL OR logout_reason IN ('manual', 'inactivity', 'terminated'));
