-- =========================================================================
-- Migration: 005_enterprise_rate_limits_and_otp.sql
-- Description: Unified 4-tier progressive rate limiting, OTP persistence,
--              admin operational cooldowns, and audit logging support.
-- =========================================================================

-- 1. Unified Progressive Rate Limits & Admin Cooldowns Table
CREATE TABLE IF NOT EXISTS public.auth_rate_limits (
  scope_key character varying NOT NULL,
  feature character varying NOT NULL CHECK (feature::text = ANY (ARRAY[
    'login_account'::character varying,
    'login_device'::character varying,
    'forgot_password'::character varying,
    'first_login_otp'::character varying,
    'admin_add_teacher_otp'::character varying,
    'admin_broadcast'::character varying,
    'admin_sy_switch'::character varying,
    'admin_maintenance_toggle'::character varying
  ]::text[])),
  device_id character varying NOT NULL,
  target_identifier character varying NOT NULL,
  failed_attempts integer NOT NULL DEFAULT 0 CHECK (failed_attempts >= 0),
  resend_count integer NOT NULL DEFAULT 0 CHECK (resend_count >= 0),
  window_started_at timestamp with time zone NOT NULL DEFAULT now(),
  lockout_tier smallint NOT NULL DEFAULT 0 CHECK (lockout_tier >= 0 AND lockout_tier <= 4),
  tier_escalated_at timestamp with time zone,
  locked_until timestamp with time zone,
  cooldown_until timestamp with time zone,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT auth_rate_limits_pkey PRIMARY KEY (scope_key)
);

CREATE INDEX IF NOT EXISTS idx_auth_rate_limits_device ON public.auth_rate_limits (device_id);
CREATE INDEX IF NOT EXISTS idx_auth_rate_limits_target ON public.auth_rate_limits (target_identifier);
CREATE INDEX IF NOT EXISTS idx_auth_rate_limits_feature ON public.auth_rate_limits (feature);

-- 2. Enhance admin_teacher_email_challenges for 4-tier lockout & max 4 resends
ALTER TABLE public.admin_teacher_email_challenges
  ADD COLUMN IF NOT EXISTS resend_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS window_started_at timestamp with time zone NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS lockout_tier smallint NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS tier_escalated_at timestamp with time zone;

-- 3. Enhance first_login_otp_verifications for 4-tier lockout & email tracking
ALTER TABLE public.first_login_otp_verifications
  ADD COLUMN IF NOT EXISTS email character varying,
  ADD COLUMN IF NOT EXISTS window_started_at timestamp with time zone NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS lockout_tier smallint NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS tier_escalated_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS locked_until timestamp with time zone;

-- 4. Server-side persistence table for Forgot Password OTPs
CREATE TABLE IF NOT EXISTS public.password_reset_otps (
  email character varying NOT NULL,
  code_hash text NOT NULL,
  expires_at timestamp with time zone NOT NULL,
  last_sent_at timestamp with time zone NOT NULL DEFAULT now(),
  resend_count integer NOT NULL DEFAULT 0,
  failed_attempts integer NOT NULL DEFAULT 0,
  window_started_at timestamp with time zone NOT NULL DEFAULT now(),
  lockout_tier smallint NOT NULL DEFAULT 0,
  tier_escalated_at timestamp with time zone,
  locked_until timestamp with time zone,
  is_verified boolean NOT NULL DEFAULT false,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT password_reset_otps_pkey PRIMARY KEY (email)
);

CREATE INDEX IF NOT EXISTS idx_password_reset_otps_expires ON public.password_reset_otps (expires_at);

-- 5. Enable Row Level Security (RLS) & Configure Access Policies
ALTER TABLE public.auth_rate_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.password_reset_otps ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'auth_rate_limits' AND policyname = 'allow_rate_limits_access'
  ) THEN
    CREATE POLICY allow_rate_limits_access ON public.auth_rate_limits
      FOR ALL TO anon, authenticated
      USING (true)
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'password_reset_otps' AND policyname = 'allow_password_reset_otps_access'
  ) THEN
    CREATE POLICY allow_password_reset_otps_access ON public.password_reset_otps
      FOR ALL TO anon, authenticated
      USING (true)
      WITH CHECK (true);
  END IF;
END $$;
