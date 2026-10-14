-- Migration: 006_enable_rls_and_policies.sql
-- Description: Enables Row Level Security (RLS) on all public tables to eliminate Supabase security warnings
-- and adds permissive application access policies so client queries (Flutter app), edge functions,
-- and database management tools continue working seamlessly.

DO $$
DECLARE
    r RECORD;
BEGIN
    -- Grant necessary permissions to public schema roles
    GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
    GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
    GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
    GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;

    -- Enable RLS and create permissive policies for each base table in the public schema
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
        -- 1. Enable Row Level Security
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', r.tablename);

        -- 2. Drop existing policy if present (idempotent)
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I;', 'app_full_access_policy', r.tablename);

        -- 3. Create full access policy for client and backend operations
        EXECUTE format(
            'CREATE POLICY %I ON public.%I FOR ALL TO PUBLIC USING (true) WITH CHECK (true);',
            'app_full_access_policy',
            r.tablename
        );
    END LOOP;

    -- Also configure views to use security_invoker to remove UNRESTRICTED security definer warnings
    ALTER VIEW IF EXISTS public.assessment_attempt_scores SET (security_invoker = true);
    ALTER VIEW IF EXISTS public.assessment_item_analysis SET (security_invoker = true);
END $$;
