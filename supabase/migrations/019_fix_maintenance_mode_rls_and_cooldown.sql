-- 1. Archive any legacy maintenance notifications so they do not appear in user notification tabs
UPDATE public.notifications
SET is_archived = true
WHERE title IN (
  'Scheduled System Maintenance Active',
  'System Maintenance Complete — Back Online'
);

-- 2. Fix RLS policies and table grants on public.system_settings
ALTER TABLE public.system_settings ENABLE ROW LEVEL SECURITY;

ALTER POLICY "Allow admin update access to system_settings"
ON public.system_settings
USING (true)
WITH CHECK (
  maintenance_updated_by IS NOT NULL
  AND EXISTS (
    SELECT 1
    FROM public.users u
    WHERE u.id::text = maintenance_updated_by::text
      AND u.role::text = 'admin'
      AND u.is_archived = false
  )
);

GRANT SELECT, INSERT, UPDATE ON TABLE public.system_settings TO anon, authenticated, service_role;

-- 3. Server-side RPC to get maintenance status + tamper-proof server cooldown remaining seconds
CREATE OR REPLACE FUNCTION public.get_system_maintenance_status()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.system_settings%ROWTYPE;
  v_elapsed numeric;
  v_remaining int := 0;
  v_rate_cd timestamptz;
  v_rate_rem int := 0;
BEGIN
  SELECT * INTO v_row FROM public.system_settings WHERE id = true LIMIT 1;

  IF NOT FOUND THEN
    INSERT INTO public.system_settings (id, is_maintenance_mode, maintenance_updated_at)
    VALUES (true, false, now() - interval '1 hour')
    RETURNING * INTO v_row;
  END IF;

  IF v_row.maintenance_updated_by IS NOT NULL AND v_row.maintenance_updated_at IS NOT NULL THEN
    v_elapsed := EXTRACT(EPOCH FROM (now() - v_row.maintenance_updated_at));
    IF v_elapsed >= 0 AND v_elapsed < 600 THEN
      v_remaining := CEIL(600 - v_elapsed)::int;
    END IF;
  END IF;

  SELECT cooldown_until INTO v_rate_cd
  FROM public.auth_rate_limits
  WHERE scope_key = 'admin_maintenance_toggle:global'
  LIMIT 1;

  IF v_rate_cd IS NOT NULL AND v_rate_cd > now() THEN
    v_rate_rem := CEIL(EXTRACT(EPOCH FROM (v_rate_cd - now())))::int;
    IF v_rate_rem > v_remaining THEN
      v_remaining := v_rate_rem;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'id', true,
    'is_maintenance_mode', v_row.is_maintenance_mode,
    'maintenance_updated_at', v_row.maintenance_updated_at,
    'maintenance_updated_by', v_row.maintenance_updated_by,
    'school_year_updated_at', v_row.school_year_updated_at,
    'server_now', now(),
    'cooldown_remaining_seconds', GREATEST(v_remaining, 0)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_system_maintenance_status() TO anon, authenticated, service_role;

-- 4. Server-side RPC to atomically toggle maintenance mode and enforce 10-minute (600s) cooldown
CREATE OR REPLACE FUNCTION public.set_system_maintenance_mode(
  p_enabled boolean,
  p_admin_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_admin boolean := false;
  v_row public.system_settings%ROWTYPE;
  v_elapsed numeric;
  v_remaining int := 0;
  v_rate_cd timestamptz;
  v_rate_rem int := 0;
  v_now timestamptz := now();
  v_cooldown_until timestamptz := v_now + interval '10 minutes';
BEGIN
  -- Verify admin exists and is active
  SELECT EXISTS (
    SELECT 1
    FROM public.users u
    WHERE u.id::text = p_admin_id
      AND u.role::text = 'admin'
      AND u.is_archived = false
  ) INTO v_is_admin;

  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'UNAUTHORIZED_ADMIN: Administrator access is required to toggle maintenance mode.';
  END IF;

  SELECT * INTO v_row FROM public.system_settings WHERE id = true FOR UPDATE;

  IF FOUND THEN
    IF v_row.maintenance_updated_by IS NOT NULL AND v_row.maintenance_updated_at IS NOT NULL THEN
      v_elapsed := EXTRACT(EPOCH FROM (v_now - v_row.maintenance_updated_at));
      IF v_elapsed >= 0 AND v_elapsed < 600 THEN
        v_remaining := CEIL(600 - v_elapsed)::int;
      END IF;
    END IF;
  END IF;

  SELECT cooldown_until INTO v_rate_cd
  FROM public.auth_rate_limits
  WHERE scope_key = 'admin_maintenance_toggle:global'
  LIMIT 1;

  IF v_rate_cd IS NOT NULL AND v_rate_cd > v_now THEN
    v_rate_rem := CEIL(EXTRACT(EPOCH FROM (v_rate_cd - v_now)))::int;
    IF v_rate_rem > v_remaining THEN
      v_remaining := v_rate_rem;
    END IF;
  END IF;

  IF v_remaining > 0 THEN
    RAISE EXCEPTION 'COOLDOWN_ACTIVE:%', v_remaining;
  END IF;

  INSERT INTO public.system_settings (
    id,
    is_maintenance_mode,
    maintenance_updated_at,
    maintenance_updated_by
  )
  VALUES (
    true,
    p_enabled,
    v_now,
    p_admin_id
  )
  ON CONFLICT (id) DO UPDATE
  SET is_maintenance_mode = EXCLUDED.is_maintenance_mode,
      maintenance_updated_at = EXCLUDED.maintenance_updated_at,
      maintenance_updated_by = EXCLUDED.maintenance_updated_by
  RETURNING * INTO v_row;

  -- Record global 10-minute cooldown in auth_rate_limits
  INSERT INTO public.auth_rate_limits (
    scope_key,
    feature,
    device_id,
    target_identifier,
    cooldown_until,
    updated_at
  )
  VALUES (
    'admin_maintenance_toggle:global',
    'admin_maintenance_toggle',
    'global',
    'global',
    v_cooldown_until,
    v_now
  )
  ON CONFLICT (scope_key) DO UPDATE
  SET cooldown_until = EXCLUDED.cooldown_until,
      updated_at = EXCLUDED.updated_at;

  -- Record audit log
  INSERT INTO public.audit_logs (
    user_id,
    action_type,
    description,
    logged_at
  )
  VALUES (
    p_admin_id,
    'admin_maintenance_toggle',
    'System maintenance mode was switched to ' || CASE WHEN p_enabled THEN 'ACTIVE (Lockdown).' ELSE 'OPERATIONAL.' END,
    v_now
  );

  RETURN jsonb_build_object(
    'id', true,
    'is_maintenance_mode', v_row.is_maintenance_mode,
    'maintenance_updated_at', v_row.maintenance_updated_at,
    'maintenance_updated_by', v_row.maintenance_updated_by,
    'school_year_updated_at', v_row.school_year_updated_at,
    'server_now', v_now,
    'cooldown_remaining_seconds', 600
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_system_maintenance_mode(boolean, text) TO anon, authenticated, service_role;
