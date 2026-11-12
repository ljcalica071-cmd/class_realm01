-- Migration 024: Fix classwork-materials storage bucket and RLS policies
-- Ensures public and authenticated users can insert, update (upsert), select, and delete attachments
-- in the classwork-materials bucket without encountering 403 RLS violation errors.

-- 1. Ensure bucket exists and has correct settings (public: true, 15MB limit)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'classwork-materials',
  'classwork-materials',
  true,
  15728640, -- 15MB limit
  NULL      -- permissive mime types to prevent browser-specific mime mismatch
)
ON CONFLICT (id) DO UPDATE SET 
  public = true,
  file_size_limit = 15728640,
  allowed_mime_types = NULL;

-- 2. Clean up old split/restrictive policies
DROP POLICY IF EXISTS "Public and Auth Read classwork-materials" ON storage.objects;
DROP POLICY IF EXISTS "Allow Uploads to classwork-materials" ON storage.objects;
DROP POLICY IF EXISTS "Allow Updates to classwork-materials" ON storage.objects;
DROP POLICY IF EXISTS "Allow Deletes from classwork-materials" ON storage.objects;
DROP POLICY IF EXISTS "Public Access classwork-materials" ON storage.objects;

-- 3. Create a single, unified permissive policy for classwork-materials
CREATE POLICY "Public Access classwork-materials" ON storage.objects
  FOR ALL
  TO public
  USING (bucket_id = 'classwork-materials')
  WITH CHECK (bucket_id = 'classwork-materials');

