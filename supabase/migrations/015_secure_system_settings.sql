-- Keep maintenance state readable by the app while routing all writes through
-- the admin-maintenance-mode Edge Function.
ALTER TABLE public.system_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "system_settings_public_read" ON public.system_settings;
CREATE POLICY "system_settings_public_read"
ON public.system_settings
FOR SELECT
TO anon, authenticated
USING (true);

REVOKE INSERT, UPDATE, DELETE ON TABLE public.system_settings
FROM anon, authenticated;
GRANT SELECT ON TABLE public.system_settings TO anon, authenticated;
GRANT ALL ON TABLE public.system_settings TO service_role;
