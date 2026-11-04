-- =========================================================================
-- MIGRATION: 014_create_rfid_pending_scans.sql
-- PURPOSE: Staging table and Realtime broadcast for linking unregistered 
--          RFID cards scanned via standalone ESP32 hardware to students.
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.rfid_pending_scans (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rfid_uid varchar(64) NOT NULL,
    device_id varchar(64) DEFAULT 'HARDWARE_ESP32',
    scanned_at timestamptz NOT NULL DEFAULT now(),
    is_claimed boolean NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_rfid_pending_scans_uid 
    ON public.rfid_pending_scans (UPPER(TRIM(rfid_uid))) 
    WHERE is_claimed = false;

ALTER TABLE public.rfid_pending_scans ENABLE ROW LEVEL SECURITY;

-- Allow anon (ESP32) and authenticated (Teacher app) full read/write for card registration
DROP POLICY IF EXISTS "rfid_pending_scans_anon_insert" ON public.rfid_pending_scans;
CREATE POLICY "rfid_pending_scans_anon_insert"
    ON public.rfid_pending_scans
    FOR INSERT
    TO anon, authenticated
    WITH CHECK (true);

DROP POLICY IF EXISTS "rfid_pending_scans_read_all" ON public.rfid_pending_scans;
CREATE POLICY "rfid_pending_scans_read_all"
    ON public.rfid_pending_scans
    FOR SELECT
    TO anon, authenticated
    USING (true);

DROP POLICY IF EXISTS "rfid_pending_scans_update_claimed" ON public.rfid_pending_scans;
CREATE POLICY "rfid_pending_scans_update_claimed"
    ON public.rfid_pending_scans
    FOR UPDATE
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.rfid_pending_scans TO anon, authenticated, service_role;

-- Enable Supabase Realtime for this staging table
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
          AND schemaname = 'public' 
          AND tablename = 'rfid_pending_scans'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.rfid_pending_scans;
    END IF;
END $$;

